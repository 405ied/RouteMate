import { Injectable, UnauthorizedException } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { JwtService } from "@nestjs/jwt";
import { randomUUID } from "node:crypto";
import { z } from "zod";
const claimsSchema = z.object({
  sub: z.string().uuid(),
  org: z.string().uuid(),
  sid: z.string().uuid(),
  kind: z.enum(["access", "refresh"]),
  exp: z.number(),
  jti: z.string().uuid(),
});
export type Identity = {
  userId: string;
  organizationId: string;
  sessionId: string;
};
@Injectable()
export class TokenService {
  constructor(
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}
  async issue(identity: Identity, expiresAt: Date) {
    const remaining = Math.floor((expiresAt.getTime() - Date.now()) / 1000);
    if (remaining < 1) throw new UnauthorizedException("Session expired");
    const accessSeconds = Math.min(
      this.config.getOrThrow<number>("ACCESS_TOKEN_SECONDS"),
      remaining,
    );
    const sign = (kind: "access" | "refresh", seconds: number) =>
      this.jwt.signAsync(
        {
          sub: identity.userId,
          org: identity.organizationId,
          sid: identity.sessionId,
          kind,
        },
        {
          secret: this.config.getOrThrow<string>(
            kind === "access" ? "JWT_ACCESS_SECRET" : "JWT_REFRESH_SECRET",
          ),
          algorithm: "HS256",
          issuer: this.config.getOrThrow<string>("JWT_ISSUER"),
          audience: this.config.getOrThrow<string>("JWT_AUDIENCE"),
          expiresIn: seconds,
          jwtid: randomUUID(),
        },
      );
    return {
      accessToken: await sign("access", accessSeconds),
      refreshToken: await sign("refresh", remaining),
      tokenType: "Bearer",
      expiresIn: accessSeconds,
    };
  }
  async verify(token: string, kind: "access" | "refresh"): Promise<Identity> {
    try {
      const claims = claimsSchema.parse(
        await this.jwt.verifyAsync(token, {
          secret: this.config.getOrThrow<string>(
            kind === "access" ? "JWT_ACCESS_SECRET" : "JWT_REFRESH_SECRET",
          ),
          algorithms: ["HS256"],
          issuer: this.config.getOrThrow<string>("JWT_ISSUER"),
          audience: this.config.getOrThrow<string>("JWT_AUDIENCE"),
        }),
      );
      if (claims.kind !== kind) throw new Error("Wrong token kind");
      return {
        userId: claims.sub,
        organizationId: claims.org,
        sessionId: claims.sid,
      };
    } catch {
      throw new UnauthorizedException("Invalid or expired token");
    }
  }
}
