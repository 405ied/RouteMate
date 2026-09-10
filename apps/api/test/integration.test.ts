import "reflect-metadata";
import { test } from "node:test";
import assert from "node:assert/strict";
import { randomBytes, randomUUID, createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import path from "node:path";
import { Client } from "pg";
import request from "supertest";
import { Test } from "@nestjs/testing";
import { INestApplication } from "@nestjs/common";
import { DatabaseService } from "../src/database/database.service";
import { RbacService } from "../src/rbac/rbac.service";
import { hashPassword } from "../src/auth/password";
import { PrismaClient } from "../../../packages/database/generated/routemate-client";
import { PrismaPg } from "@prisma/adapter-pg";
import { withRuntimeContext } from "../../../packages/database/runtime-context.cjs";

const databaseRoot = path.resolve(__dirname, "../../../packages/database");
const migrationNames = [
  "0_init",
  "20260910150000_phase2_spatial_rls",
  "20260910170000_phase3_auth_sessions",
];
const { seed } = require(path.join(databaseRoot, "scripts/seed-phase3.cjs"));
test(
  "Phase 3 real PostgreSQL and HTTP integration (isolated temporary database)",
  { timeout: 180000 },
  async (t) => {
    const { parse } = require(path.join(databaseRoot, "node_modules/dotenv"));
    const adminUrl =
      process.env.TEST_DATABASE_ADMIN_URL ||
      parse(readFileSync(path.join(databaseRoot, ".env"))).DATABASE_URL;
    const parsed = new URL(adminUrl);
    assert.ok(
      ["localhost", "127.0.0.1", "[::1]"].includes(parsed.hostname),
      "Integration admin must be local",
    );
    assert.equal(parsed.port || "5432", "5432");
    const suffix = randomBytes(8).toString("hex");
    const dbName = `routemate_test_${suffix}`,
      loginName = `routemate_test_login_${suffix}`;
    assert.match(dbName, /^routemate_test_[a-f0-9]{16}$/);
    const admin = new Client({ connectionString: adminUrl });
    let fixture: Client | undefined,
      app: INestApplication | undefined,
      raw: Client | undefined;
    let createdDatabase = false,
      createdLogin = false;
    const createdPermissionRoles: string[] = [];
    let stage = "setup";
    const hashes = migrationNames.slice(0, 2).map((name) =>
      createHash("sha256")
        .update(
          readFileSync(
            path.join(databaseRoot, "prisma/migrations", name, "migration.sql"),
          ),
        )
        .digest("hex"),
    );
    try {
      await admin.connect();
      const appRoles = await admin.query(
        `SELECT rolname,rolcanlogin,rolsuper,rolbypassrls FROM pg_roles WHERE rolname IN ('routemate_app','routemate_platform_admin')`,
      );
      assert.equal(appRoles.rowCount, 2);
      for (const role of appRoles.rows)
        assert.ok(!role.rolcanlogin && !role.rolsuper && !role.rolbypassrls);
      await admin.query(`CREATE DATABASE ${dbName}`);
      createdDatabase = true;
      const fixtureUrl = new URL(adminUrl);
      fixtureUrl.pathname = `/${dbName}`;
      fixture = new Client({ connectionString: fixtureUrl.toString() });
      await fixture.connect();
      await fixture.query(
        "CREATE TABLE public._prisma_migrations(id text PRIMARY KEY)",
      );
      for (const name of migrationNames) {
        let sql = readFileSync(
          path.join(databaseRoot, "prisma/migrations", name, "migration.sql"),
          "utf8",
        );
        // Roles are cluster-wide. Reuse existing permission roles, never alter their attributes.
        // All table/policy/function DDL is replayed in the isolated database only.
        for (const match of [
          ...sql.matchAll(/CREATE ROLE (routemate_\w+)[^;]+;/g),
        ]) {
          const exists = (
            await admin.query("SELECT 1 FROM pg_roles WHERE rolname=$1", [
              match[1],
            ])
          ).rowCount;
          if (exists)
            sql = sql.replace(
              match[0],
              "-- Existing cluster permission role reused.",
            );
          else createdPermissionRoles.push(match[1]);
        }
        stage = `migration ${name}`;
        await fixture.query(sql);
      }
      const password = randomBytes(32).toString("hex");
      await admin.query(
        `CREATE ROLE ${loginName} LOGIN INHERIT NOSUPERUSER NOBYPASSRLS NOCREATEDB NOCREATEROLE NOREPLICATION PASSWORD '${password}'`,
      );
      createdLogin = true;
      await admin.query(
        `GRANT routemate_app TO ${loginName} WITH INHERIT TRUE, SET FALSE`,
      );
      const runtimeUrl = new URL(fixtureUrl);
      runtimeUrl.username = loginName;
      runtimeUrl.password = password;
      const staffPassword = randomBytes(24).toString("base64url");
      await fixture.query("BEGIN");
      const a = await seed(fixture, {
        organizationCode: "TEST_A",
        email: "admin-a@example.invalid",
        password: staffPassword,
      });
      const b = await seed(fixture, {
        organizationCode: "TEST_B",
        email: "admin-b@example.invalid",
        password: staffPassword,
      });
      const scopedUser = randomUUID();
      await fixture.query(
        `INSERT INTO users(id,organization_id,first_name,last_name,email,password_hash,status,updated_at)
      VALUES($1,$2,'Scoped','Staff','scoped@example.invalid',$3,'ACTIVE',now())`,
        [scopedUser, a.organization, await hashPassword(staffPassword)],
      );
      await fixture.query(
        `INSERT INTO user_roles(organization_id,user_id,role_id,scope,organization_unit_id,updated_at)
      VALUES($1,$2,$3,'UNIT',$4,now())`,
        [a.organization, scopedUser, a.roleIds.STATE_ADMIN, a.units[1]],
      );
      await fixture.query("COMMIT");
      Object.assign(process.env, {
        NODE_ENV: "test",
        ROUTEMATE_RUNTIME_DATABASE_URL: runtimeUrl.toString(),
        JWT_ACCESS_SECRET: randomBytes(48).toString("hex"),
        JWT_REFRESH_SECRET: randomBytes(48).toString("hex"),
        CORS_ORIGINS: "",
      });
      stage = "Nest application startup";
      const { AppModule } = await import("../src/app.module");
      const { configureHttp } = await import("../src/common/http");
      const module = await Test.createTestingModule({
        imports: [AppModule],
      }).compile();
      app = module.createNestApplication({ logger: false });
      configureHttp(app);
      await app.init();
      const http = request(app.getHttpServer());
      const login = (code: string, email: string, password = staffPassword) =>
        http
          .post("/api/v1/auth/login")
          .send({ organizationCode: code, email, password });
      let accessA = "",
        refreshA = "",
        accessB = "",
        scopedAccess = "";
      await t.test(
        "health, successful/failed login, safe errors and no credential fields",
        async () => {
          await http.get("/api/v1/health").expect(200);
          await http.get("/api/v1/health/ready").expect(200);
          const failed = await login(
            "TEST_A",
            "admin-a@example.invalid",
            "wrong",
          );
          assert.equal(failed.status, 401);
          assert.equal(
            (
              await fixture!.query(
                "SELECT failed_login_attempts FROM users WHERE id=$1",
                [a.user],
              )
            ).rows[0].failed_login_attempts,
            1,
          );
          const first = await login("TEST_A", "ADMIN-A@example.invalid");
          assert.equal(first.status, 200);
          accessA = first.body.accessToken;
          refreshA = first.body.refreshToken;
          assert.ok(accessA && refreshA);
          assert.equal(first.headers["cache-control"], "no-store");
          assert.equal(JSON.stringify(first.body).includes("password"), false);
          accessB = (await login("TEST_B", "admin-b@example.invalid")).body
            .accessToken;
          scopedAccess = (await login("TEST_A", "scoped@example.invalid")).body
            .accessToken;
          assert.equal(
            (
              await fixture!.query(
                "SELECT failed_login_attempts FROM users WHERE id=$1",
                [a.user],
              )
            ).rows[0].failed_login_attempts,
            0,
          );
          await http.get("/api/v1/users").expect(401);
        },
      );
      await t.test(
        "tenant identity comes from JWT; cross-tenant IDs/body cannot change scope",
        async () => {
          const own = await http
            .get("/api/v1/organizations/current")
            .set("Authorization", `Bearer ${accessA}`)
            .query({ organization_id: b.organization })
            .expect(200);
          assert.equal(own.body.id, a.organization);
          const users = await http
            .get("/api/v1/users")
            .set("Authorization", `Bearer ${accessA}`)
            .expect(200);
          assert.ok(users.body.every((u: { id: string }) => u.id !== b.user));
          assert.equal(
            JSON.stringify(users.body).includes("passwordHash"),
            false,
          );
          await http
            .get(`/api/v1/organization-units/${b.units[0]}`)
            .set("Authorization", `Bearer ${accessA}`)
            .expect(404);
          await http
            .post("/api/v1/organization-units")
            .set("Authorization", `Bearer ${accessA}`)
            .send({
              organizationId: b.organization,
              code: "bad",
              name: "bad",
              unitType: "BRANCH",
            })
            .expect(400);
          const created = await http
            .post("/api/v1/organization-units")
            .set("Authorization", `Bearer ${accessA}`)
            .send({
              code: "new",
              name: "New branch",
              unitType: "BRANCH",
              parentUnitId: a.units[1],
            })
            .expect(201);
          assert.equal(
            (
              await fixture!.query(
                "SELECT organization_id FROM organization_units WHERE id=$1",
                [created.body.id],
              )
            ).rows[0].organization_id,
            a.organization,
          );
          await http
            .get("/api/v1/organizations/current")
            .set("Authorization", `Bearer ${accessB}`)
            .expect(200);
        },
      );
      await t.test(
        "granular RBAC allows org admin, confines unit grants and rejects revoked/expired grants",
        async () => {
          await http
            .get("/api/v1/roles")
            .set("Authorization", `Bearer ${accessA}`)
            .expect(200);
          await http
            .get("/api/v1/roles/permissions")
            .set("Authorization", `Bearer ${accessA}`)
            .expect(200);
          await fixture!.query(
            `UPDATE roles SET code='RENAMED_ADMIN',name='Unrelated display name' WHERE id=$1`,
            [a.roleIds.ORGANIZATION_ADMIN],
          );
          await http
            .get("/api/v1/users")
            .set("Authorization", `Bearer ${accessA}`)
            .expect(200);
          await http
            .get("/api/v1/users")
            .set("Authorization", `Bearer ${scopedAccess}`)
            .expect(403);
          await http
            .post("/api/v1/organization-units")
            .set("Authorization", `Bearer ${scopedAccess}`)
            .send({ code: "denied", name: "Denied", unitType: "BRANCH" })
            .expect(403);
          const units = await http
            .get("/api/v1/organization-units")
            .set("Authorization", `Bearer ${scopedAccess}`)
            .expect(200);
          assert.ok(
            units.body.some((u: { id: string }) => u.id === a.units[2]),
          );
          assert.ok(
            !units.body.some((u: { id: string }) => u.id === a.units[0]),
          );
          await http
            .get(`/api/v1/organization-units/${a.units[0]}`)
            .set("Authorization", `Bearer ${scopedAccess}`)
            .expect(403);
          await fixture!.query(
            "UPDATE user_roles SET valid_until=now()-interval '1 second' WHERE user_id=$1",
            [scopedUser],
          );
          await http
            .get(`/api/v1/organization-units/${a.units[1]}`)
            .set("Authorization", `Bearer ${scopedAccess}`)
            .expect(403);
          await fixture!.query(
            "UPDATE user_roles SET valid_until=NULL,revoked_at=now() WHERE user_id=$1",
            [scopedUser],
          );
          await http
            .get(`/api/v1/organization-units/${a.units[1]}`)
            .set("Authorization", `Bearer ${scopedAccess}`)
            .expect(403);
          await fixture!.query(
            "UPDATE user_roles SET revoked_at=NULL,scope='PARK',organization_unit_id=NULL,park_id=$2 WHERE user_id=$1",
            [scopedUser, a.park],
          );
          await http
            .get(`/api/v1/organization-units/${a.units[2]}`)
            .set("Authorization", `Bearer ${scopedAccess}`)
            .expect(403);
        },
      );
      await t.test(
        "RLS rejects cross-tenant reads/writes and missing context with a real LOGIN principal",
        async () => {
          raw = new Client({ connectionString: runtimeUrl.toString() });
          await raw.connect();
          assert.equal(
            (await raw.query("SELECT id FROM organization_units")).rowCount,
            0,
          );
          await raw.query("BEGIN");
          await raw.query(`SELECT set_config('app.organization_id',$1,true)`, [
            a.organization,
          ]);
          assert.equal(
            (await raw.query("SELECT id FROM staff_sessions")).rowCount,
            0,
            "Sessions require user context as well as tenant",
          );
          assert.equal(
            (
              await raw.query(
                "SELECT id FROM organization_units WHERE organization_id=$1",
                [b.organization],
              )
            ).rowCount,
            0,
          );
          assert.equal(
            (
              await raw.query(
                "UPDATE organization_units SET name='denied' WHERE id=$1",
                [b.units[0]],
              )
            ).rowCount,
            0,
          );
          await assert.rejects(
            raw.query(
              `INSERT INTO organization_units(organization_id,code,name,unit_type,updated_at) VALUES($1,'denied','Denied','BRANCH',now())`,
              [b.organization],
            ),
            (e: any) => e.code === "42501",
          );
          await raw.query("ROLLBACK");
          await assert.rejects(
            raw.query("SET ROLE routemate_platform_admin"),
            (e: any) => e.code === "42501",
          );
          await assert.rejects(
            raw.query("SET ROLE routemate_auth_owner"),
            (e: any) => e.code === "42501",
          );
          await assert.rejects(
            raw.query("UPDATE users SET password_hash='denied'"),
            (e: any) => e.code === "42501",
          );
          assert.equal(
            (
              await raw.query(
                `SELECT nullif(current_setting('app.organization_id',true),'') IS NULL AS clean`,
              )
            ).rows[0].clean,
            true,
          );
        },
      );
      await t.test(
        "pooled Prisma context resets after commit, rollback and concurrent tenants",
        async () => {
          const prisma = new PrismaClient({
            adapter: new PrismaPg({
              connectionString: runtimeUrl.toString(),
              max: 1,
            }),
          });
          try {
            const values = await Promise.all(
              [a, b, a, b].map((tenant) =>
                withRuntimeContext(
                  prisma,
                  { organizationId: tenant.organization },
                  async (tx) => {
                    const rows = await tx.organizationUnit.findMany({
                      select: { organizationId: true },
                    });
                    assert.ok(
                      rows.length > 0 &&
                        rows.every(
                          (r) => r.organizationId === tenant.organization,
                        ),
                    );
                    return tenant.organization;
                  },
                ),
              ),
            );
            assert.equal(values.length, 4);
            await assert.rejects(
              withRuntimeContext(
                prisma,
                { organizationId: a.organization },
                async () => {
                  throw new Error("rollback");
                },
              ),
            );
            assert.equal(
              (
                await prisma.$queryRaw<
                  { clean: boolean }[]
                >`SELECT nullif(current_setting('app.organization_id',true),'') IS NULL AS clean`
              )[0].clean,
              true,
            );
          } finally {
            await prisma.$disconnect();
          }
        },
      );
      await t.test(
        "rotation invalidates replay, logout revokes access immediately",
        async () => {
          const rotated = await http
            .post("/api/v1/auth/refresh")
            .send({ refreshToken: refreshA })
            .expect(200);
          assert.notEqual(rotated.body.refreshToken, refreshA);
          await http
            .post("/api/v1/auth/refresh")
            .send({ refreshToken: refreshA })
            .expect(401);
          await http
            .get("/api/v1/auth/me")
            .set("Authorization", `Bearer ${rotated.body.accessToken}`)
            .expect(401);
          await http
            .post("/api/v1/auth/refresh")
            .send({ refreshToken: rotated.body.refreshToken })
            .expect(401);
          await http
            .post("/api/v1/auth/logout")
            .set("Authorization", `Bearer ${accessB}`)
            .expect(200);
          await http
            .get("/api/v1/auth/me")
            .set("Authorization", `Bearer ${accessB}`)
            .expect(401);
        },
      );
      await t.test(
        "disabled, locked, MFA and suspended-organization accounts are denied",
        async () => {
          await fixture!.query(
            `UPDATE users SET status='DISABLED' WHERE id=$1`,
            [b.user],
          );
          assert.equal(
            (await login("TEST_B", "admin-b@example.invalid")).status,
            401,
          );
          await fixture!.query(
            `UPDATE users SET status='ACTIVE',locked_until=now()+interval '1 minute' WHERE id=$1`,
            [b.user],
          );
          assert.equal(
            (await login("TEST_B", "admin-b@example.invalid")).status,
            401,
          );
          await fixture!.query(
            `UPDATE users SET locked_until=NULL,mfa_enabled=true WHERE id=$1`,
            [b.user],
          );
          assert.equal(
            (await login("TEST_B", "admin-b@example.invalid")).status,
            401,
          );
          await fixture!.query(
            `UPDATE users SET mfa_enabled=false WHERE id=$1`,
            [b.user],
          );
          await fixture!.query(
            `UPDATE organizations SET status='SUSPENDED' WHERE id=$1`,
            [b.organization],
          );
          assert.equal(
            (await login("TEST_B", "admin-b@example.invalid")).status,
            401,
          );
        },
      );
      assert.deepEqual(
        migrationNames.slice(0, 2).map((name) =>
          createHash("sha256")
            .update(
              readFileSync(
                path.join(
                  databaseRoot,
                  "prisma/migrations",
                  name,
                  "migration.sql",
                ),
              ),
            )
            .digest("hex"),
        ),
        hashes,
      );
    } catch (error) {
      // Do not print pg query details, URLs, rows, credentials or token bodies.
      if (error instanceof assert.AssertionError) throw error;
      throw new Error(
        `Integration failed at ${stage}: ${typeof error === "object" && error && "code" in error ? String(error.code) : "application error"}`,
      );
    } finally {
      await app?.close();
      await raw?.end();
      await fixture?.end();
      if (createdDatabase) {
        assert.match(dbName, /^routemate_test_[a-f0-9]{16}$/);
        await admin.query(`DROP DATABASE ${dbName}`);
      }
      if (createdLogin) await admin.query(`DROP ROLE ${loginName}`);
      for (const role of createdPermissionRoles.reverse())
        await admin.query(`DROP ROLE ${role}`);
      await admin.end();
    }
  },
);
