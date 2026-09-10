import "reflect-metadata";
import { test } from "node:test";
import assert from "node:assert/strict";
import { ConfigService } from "@nestjs/config";
import { JwtService } from "@nestjs/jwt";
import { randomBytes, randomUUID } from "node:crypto";
import { hashPassword, verifyPassword } from "../src/auth/password";
import { TokenService } from "../src/auth/token.service";
import { validateEnvironment } from "../src/config/environment";
test("scrypt salts passwords, verifies correct secret and rejects wrong/malformed hashes", async () => {
  const password = randomBytes(24).toString("base64url");
  const first = await hashPassword(password),
    second = await hashPassword(password);
  assert.notEqual(first, second);
  assert.equal(await verifyPassword(password, first), true);
  assert.equal(await verifyPassword("incorrect", first), false);
  assert.equal(await verifyPassword(password, null), false);
  assert.equal(
    await verifyPassword(password, "scrypt$999999999$8$1$bad$bad"),
    false,
  );
});
test("environment rejects superuser connections, weak/shared JWT secrets and unsafe origins", () => {
  const valid = {
    ROUTEMATE_RUNTIME_DATABASE_URL:
      "postgresql://runtime@localhost/routemate_db",
    JWT_ACCESS_SECRET: randomBytes(48).toString("hex"),
    JWT_REFRESH_SECRET: randomBytes(48).toString("hex"),
  };
  assert.equal(validateEnvironment(valid).PORT, 3000);
  assert.throws(() =>
    validateEnvironment({
      ...valid,
      ROUTEMATE_RUNTIME_DATABASE_URL:
        "postgresql://postgres@localhost/routemate_db",
    }),
  );
  assert.throws(() =>
    validateEnvironment({
      ...valid,
      JWT_REFRESH_SECRET: valid.JWT_ACCESS_SECRET,
    }),
  );
  assert.throws(() =>
    validateEnvironment({ ...valid, JWT_ACCESS_SECRET: "short" }),
  );
  assert.throws(() =>
    validateEnvironment({
      ...valid,
      NODE_ENV: "production",
      CORS_ORIGINS: "http://example.com",
    }),
  );
});
test("JWT validates signature, purpose, issuer, expiry and UUID identities", async () => {
  const config = new ConfigService({
    JWT_ACCESS_SECRET: randomBytes(48).toString("hex"),
    JWT_REFRESH_SECRET: randomBytes(48).toString("hex"),
    JWT_ISSUER: "test",
    JWT_AUDIENCE: "staff",
    ACCESS_TOKEN_SECONDS: 60,
  });
  const tokens = new TokenService(new JwtService(), config);
  const identity = {
    userId: randomUUID(),
    organizationId: randomUUID(),
    sessionId: randomUUID(),
  };
  const pair = await tokens.issue(identity, new Date(Date.now() + 300000));
  assert.deepEqual(await tokens.verify(pair.accessToken, "access"), identity);
  await assert.rejects(tokens.verify(pair.refreshToken, "access"));
  await assert.rejects(tokens.verify(pair.accessToken + "x", "access"));
  const expired = new JwtService().sign(
    {
      sub: identity.userId,
      org: identity.organizationId,
      sid: identity.sessionId,
      kind: "access",
    },
    { secret: config.get("JWT_ACCESS_SECRET"), expiresIn: -1 },
  );
  await assert.rejects(tokens.verify(expired, "access"));
});
