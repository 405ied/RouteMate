import { Injectable, UnauthorizedException } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { createHash, randomUUID, timingSafeEqual } from "node:crypto";
import { DatabaseService, Transaction } from "../database/database.service";
import { Identity, TokenService } from "./token.service";
import { verifyPassword } from "./password";
import { LoginDto } from "./auth.dto";
const digest = (value: string) =>
  createHash("sha256").update(value).digest("hex");
type Candidate = {
  id: string;
  organization_id: string;
  password_hash: string | null;
  status: string;
  locked_until: Date | null;
  mfa_enabled: boolean;
  organization_status: string;
};
@Injectable()
export class AuthService {
  constructor(
    private readonly db: DatabaseService,
    private readonly tokens: TokenService,
    private readonly config: ConfigService,
  ) {}
  async login(input: LoginDto) {
    const result = await this.db.run({}, async (tx) => {
      const [user] = await tx.$queryRaw<
        Candidate[]
      >`SELECT * FROM routemate_security.staff_login_candidate(${input.organizationCode},${input.email})`;
      const valid = await verifyPassword(
        input.password,
        user?.password_hash ?? null,
      );
      const eligible =
        user &&
        user.status === "ACTIVE" &&
        user.organization_status === "ACTIVE" &&
        !user.mfa_enabled &&
        (!user.locked_until || user.locked_until <= new Date());
      if (!valid || !eligible) {
        if (user)
          await tx.$queryRaw`SELECT routemate_security.staff_login_result(${user.id}::uuid,false)::text`;
        return null; // Commit failed-attempt counters before returning HTTP 401.
      }
      const identity = {
        userId: user.id,
        organizationId: user.organization_id,
        sessionId: randomUUID(),
      };
      await this.db.establishAuthenticatedContext(tx, identity);
      const expiresAt = new Date(
        Date.now() +
          this.config.getOrThrow<number>("REFRESH_TOKEN_SECONDS") * 1000,
      );
      const pair = await this.tokens.issue(identity, expiresAt);
      await tx.staffSession.create({
        data: {
          id: identity.sessionId,
          organizationId: identity.organizationId,
          userId: identity.userId,
          expiresAt,
          refreshTokenHash: digest(pair.refreshToken),
        },
      });
      await tx.$queryRaw`SELECT routemate_security.staff_login_result(${user.id}::uuid,true)::text`;
      return pair;
    });
    if (!result)
      throw new UnauthorizedException(
        "Invalid credentials or account unavailable",
      );
    return result;
  }
  async requireActive(tx: Transaction, identity: Identity) {
    const user = await tx.user.findFirst({
      where: {
        id: identity.userId,
        organizationId: identity.organizationId,
        status: "ACTIVE",
        deletedAt: null,
        mfaEnabled: false,
      },
      select: {
        id: true,
        lockedUntil: true,
        organization: { select: { status: true, deletedAt: true } },
      },
    });
    if (
      !user ||
      (user.lockedUntil && user.lockedUntil > new Date()) ||
      user.organization?.status !== "ACTIVE" ||
      user.organization.deletedAt
    )
      throw new UnauthorizedException("Account unavailable");
    const session = await tx.staffSession.findFirst({
      where: {
        id: identity.sessionId,
        userId: identity.userId,
        revokedAt: null,
        expiresAt: { gt: new Date() },
      },
    });
    if (!session) throw new UnauthorizedException("Session unavailable");
    return session;
  }
  async authenticate(accessToken: string) {
    const identity = await this.tokens.verify(accessToken, "access");
    await this.db.run(identity, (tx) => this.requireActive(tx, identity));
    return identity;
  }
  async refresh(refreshToken: string) {
    const identity = await this.tokens.verify(refreshToken, "refresh");
    const pair = await this.db.run(identity, async (tx) => {
      // Serialize rotations: replay of an old token revokes the whole session.
      await tx.$queryRaw`SELECT id FROM staff_sessions WHERE id=${identity.sessionId}::uuid FOR UPDATE`;
      const session = await this.requireActive(tx, identity);
      if (
        !timingSafeEqual(
          Buffer.from(session.refreshTokenHash, "hex"),
          Buffer.from(digest(refreshToken), "hex"),
        )
      ) {
        await tx.staffSession.update({
          where: { id: session.id },
          data: { revokedAt: new Date() },
        });
        return null;
      }
      const next = await this.tokens.issue(identity, session.expiresAt);
      await tx.staffSession.update({
        where: { id: session.id },
        data: { refreshTokenHash: digest(next.refreshToken) },
      });
      return next;
    });
    if (!pair)
      throw new UnauthorizedException("Refresh token reuse; session revoked");
    return pair;
  }
  logout(identity: Identity) {
    return this.db.run(identity, async (tx) => {
      await tx.staffSession.updateMany({
        where: {
          id: identity.sessionId,
          userId: identity.userId,
          revokedAt: null,
        },
        data: { revokedAt: new Date() },
      });
      return { revoked: true };
    });
  }
}
