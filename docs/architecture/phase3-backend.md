# Phase 3: NestJS authentication, tenant context and permissions

The API lives in `apps/api` and imports the existing generated Prisma 7.10 client and runtime helpers from `packages/database`. No detached project or duplicate database package is used. `0_init` and the Phase 2 migration remain unchanged. Keep the repository layout when deploying: the compiled API resolves `packages/database/generated/routemate-client` and `runtime-context.cjs` from the repository root.

## Authentication

Staff log in with an organization code, email and password. The organization code only locates a candidate at login; protected routes never accept a caller-selected tenant. Passwords use Node's scrypt, N=32768, r=8, p=1, a random 16-byte salt and a 64-byte derived key, compared in constant time. Bootstrap passwords must be at least 12 characters and at most 256 UTF-8 bytes. Unknown identities execute the same password-derivation work. Existing unsupported password formats fail closed; there is no plaintext fallback.

`staff_login_candidate` locks the candidate row during authentication. Password verification, failure counters and session creation use the same transaction. Five failed attempts lock the account for 15 minutes. Failures commit counters before an HTTP 401 is returned. Disabled/deleted staff, inactive/deleted organizations, locked accounts and MFA-enabled accounts are rejected. MFA is deliberately fail-closed until a second-factor challenge exists.

Successful login returns a short-lived HS256 access JWT and a refresh JWT, signed with separate secrets and checked for issuer, audience, explicit algorithm, token kind, expiry and UUID claims. Tokens contain only staff ID, organization ID, session ID, purpose and standard token metadata, never permissions or sensitive staff data. Permissions are read fresh from the database. The maximum access lifetime is 15 minutes; refresh/session lifetime defaults to seven days and does not slide on rotation.

The new `staff_sessions` table persists only a SHA-256 hash of the refresh JWT, not the bearer token. Each refresh locks the session, compares the hash, replaces it and issues a fresh token ID. Reusing an old valid refresh token revokes that session, including its newly issued tokens. Concurrent refresh requests therefore require client-side serialization. An invalid signature does not select or revoke a session. Logout revokes the current session. Every protected request checks session revocation/expiry and current user/organization status, so revocation is effective immediately. Administrative revocation can set `revoked_at` on all sessions for a user through the separate platform service/DB role; sessions are retained for controlled cleanup rather than deleted by the API.

Use HTTPS. Responses use `Cache-Control: no-store`; tokens are returned in JSON for an API client, not placed in cookies. A future browser client should use a secure BFF/HttpOnly-cookie design with CSRF protection rather than storing refresh tokens in localStorage. Password reset, MFA enrollment/challenge and invitation flows are not exposed in this foundation.

## Database roles and pre-authentication access

| Identity | Purpose |
|---|---|
| postgres | DBA/migrations only; never API runtime |
| routemate_app | NOLOGIN permission role, normal RLS-enforced grants |
| routemate_api (example) | Separate LOGIN principal inheriting routemate_app, without ability to SET ROLE to it |
| routemate_platform_admin | NOLOGIN permission role with explicit platform policies |
| routemate_platform_operator (example) | Separate controlled LOGIN principal, NOINHERIT, explicitly SET LOCAL ROLE routemate_platform_admin |
| routemate_auth_owner | NOLOGIN, no membership granted; owns only two narrowly scoped authentication functions |

`infrastructure/postgres/phase3-principals.sql` provides interactive psql provisioning commands. It creates separate logins without passwords in source, then uses `\password` to prompt securely. Do not place secrets in shell arguments, checked-in .env files or SQL literals. Keep the permission roles NOLOGIN. This supersedes Phase 2's suggestion to enable LOGIN on routemate_app. SQL role names are not passwords.

The API reads **only** `ROUTEMATE_RUNTIME_DATABASE_URL`; there is no fallback to the migration `DATABASE_URL`. Startup and each unit of work verify that the effective role is the authenticated LOGIN identity, inherits routemate_app privileges, has no elevated attributes/memberships, owns no application objects, and is not a member of the platform or authentication-owner role. Superuser connections with `SET ROLE routemate_app` are rejected. The runtime identity may not create roles/databases, replicate or bypass RLS. Future grants must preserve that contract.

Because ordinary RLS cannot identify a staff member before login, the new migration adds two SECURITY DEFINER functions owned by the restricted `routemate_auth_owner`. It has explicit RLS policies and SELECT on users/organizations, and column-level UPDATE on login counters/timestamps only. It has no BYPASSRLS, login, app-table ownership or password-update privilege. Functions fix `search_path` to trusted schemas, fully qualify table names, use no dynamic SQL, and revoke PUBLIC execution. Only routemate_app can invoke the candidate lookup and result recorder. The backend is trusted to supply the verified result; these functions and the runtime DB credential must never be exposed as a public SQL interface.

Tenant policies from Phase 2 remain unchanged. Staff sessions add forced RLS requiring **both** organization and staff identity. Existing identity and grant tables remain read-only to routemate_app. API account/grant editing is intentionally not provided; privileged provisioning uses controlled DBA/platform tooling, not broad runtime UPDATE grants.

## Tenant context and connection pooling

`DatabaseService.run(context, callback)` wraps an interactive Prisma transaction using `@prisma/adapter-pg`. It validates UUIDs, verifies runtime privileges, and calls parameterized `set_config(..., true)` for all of:

- `app.organization_id`
- `app.user_id`
- `app.passenger_id`
- `app.passenger_session_id`

Every key is set, including empty values for absent identities. Only the transaction client is passed to the callback; no root Prisma client is exposed by DatabaseService. All queries and scoped authorization checks for an operation use that client. Commit and rollback clear local context before the pooled connection is reused. Use a transaction pooler, never statement pooling. Avoid external network calls in database transactions. The authentication hashing step is bounded and deliberately holds the user lock to serialize failure-counter changes.

Normal endpoints derive tenant/user context from a verified staff token and a live session. Body/query organization IDs cannot establish context; unknown body properties are rejected. Passenger context is supported by the shared helper for future authenticated passenger flows, but there are no public passenger/QR endpoints yet. Custom PostgreSQL settings are trusted-backend context, not cryptographic credentials; arbitrary SQL access could change them. SQL injection prevention, server-side authentication and credential isolation remain essential.

## Permission and scope evaluation

The seed defines granular strings including `driver.create`, `driver.view`, `driver.update`, `driver.suspend`, `vehicle.create`, `incident.assign` and foundation read/create permissions. Role names/codes are labels, not authorization logic. The guard and service join user_roles → roles → role_permissions → permissions, checking exact tenant equality, active/nondeleted roles, valid grant times, no revocation, and valid scope shape. Platform/global role grants cannot authorize tenant routes.

Organization-wide endpoints require an ORGANIZATION grant. UNIT grants authorize the unit and its descendants for unit reads; recursive traversal uses UNION to terminate even if legacy data contains a cycle. Unit lists are filtered to allowed IDs and limited to 100 rows. PARK grants confer no organization- or unit-wide access; future park resource handlers must evaluate the exact park scope. State/Branch Admin templates are intended for UNIT grants, Park Manager for PARK grants. No scope is inferred from a role's label.

`@RequirePermission` provides a guard. Services also recheck permissions inside the database transaction before accessing a resource. Organization Admin is seeded with an ORGANIZATION grant. The other baseline roles are State Admin, Branch Admin, Park Manager, Registration Officer, Compliance Officer and Safety Officer. They are created without assigning them to users. A global RouteMate Super Admin/platform role template is seeded without a platform user or database-login membership. Database-role membership is never derived from an HTTP token or role string.

Platform administration is separated by credential and policy. The normal API does not load a platform credential and exposes no platform endpoint; global operators cannot log in through the tenant staff flow. Future platform HTTP handlers must run in a separate trusted service with explicit authentication, granular platform authorization and audited actions, using transaction-local SET ROLE. Do not add an `isAdmin` bypass to tenant code.

## Configuration and startup

From the canonical repository:

```powershell
cd C:\RouteMate\packages\database
npm ci
npx --no-install prisma validate
npx --no-install prisma generate
npx --no-install prisma migrate deploy
cd C:\RouteMate\apps\api
npm ci
npm run build
npm start
```

Before starting, provision the runtime login with the DBA psql script and inject the variables in `apps/api/.env.example`. The example contains no secret values. Keep the database package's existing migration .env unchanged.

| Variable | Requirement |
|---|---|
| ROUTEMATE_RUNTIME_DATABASE_URL | Separate restricted API login; required |
| JWT_ACCESS_SECRET / JWT_REFRESH_SECRET | Independent random secrets, at least 48 characters each; required |
| JWT_ISSUER / JWT_AUDIENCE | Defaults routemate-api / routemate-staff |
| ACCESS_TOKEN_SECONDS | 60–900, default 900 |
| REFRESH_TOKEN_SECONDS | 300–2592000, default 604800 |
| NODE_ENV | development, test or production |
| PORT | Default 3000 |
| CORS_ORIGINS | Comma-separated exact origins; empty disables cross-origin browser access, HTTPS required in production |

Use Node 22+ (tested on the installed Node 26.7.0) and PostgreSQL 18 with existing PostGIS extensions. Build and startup must run from apps/api. Enable TLS at the ingress; do not expose PostgreSQL publicly. The API uses Helmet, strict DTO validation, JSON structured request logs with generated request IDs, sanitized errors, global throttling and lower authentication limits. It logs route templates/status/timing, not headers, request bodies, URLs with query strings, credentials or tokens. Default throttling is in-memory and the default proxy trust is off: configure a trusted ingress and shared rate-limit storage before running multiple instances. List endpoints are bounded foundation reads; cursor pagination is future work.

## Development bootstrap

The seed runs only with `NODE_ENV=development` and a local routemate_db URL. Supply these through a temporary process environment or secret manager:

`ROUTEMATE_BOOTSTRAP_DATABASE_URL` (DBA connection), `BOOTSTRAP_ORGANIZATION_CODE`, `BOOTSTRAP_ADMIN_EMAIL`, `BOOTSTRAP_ADMIN_PASSWORD`.

```powershell
cd C:\RouteMate\packages\database
node scripts/seed-phase3.cjs
node scripts/seed-phase3.cjs --apply
```

The first command rehearses and rolls back. The explicit `--apply` persists permissions, role templates, one development organization with national/state/branch hierarchy, one park and one admin. A transaction advisory lock serializes seeds. Existing passwords are never overwritten; no real password is embedded or printed. No production admin or platform login is created. Securely remove the bootstrap environment afterward. Review the target and grant changes before using this development tool against an existing organization. Production provisioning needs a separately reviewed workflow.

## Migration and verification

`20260910170000_phase3_auth_sessions` adds staff_sessions and its RLS/indexes, normalized per-tenant email uniqueness and the constrained authentication owner/functions. It uses an explicit transaction, 10-second lock timeout and five-minute statement timeout. Existing case-insensitive email collisions cause an atomic failure rather than deletion/merging. Use migrate deploy, never db push/reset, and review future SQL diffs for preservation of native spatial indexes, policies and grants.

Tests:

```powershell
cd C:\RouteMate\apps\api
npm run lint
npm run format:check
npm test
npm run test:integration
cd C:\RouteMate\packages\database
node scripts/verify-phase2.cjs
```

Integration tests use `TEST_DATABASE_ADMIN_URL` or the existing database-package .env solely for local DBA setup. They create a randomly named `routemate_test_<hex>` database and restricted LOGIN with an in-memory random password, replay migrations, and exercise the real HTTP API and PostgreSQL RLS. Existing cluster-wide permission roles are reused without changing their attributes; a missing authentication-owner role is created for the test and removed afterward. Test fixtures never enter routemate_db. Cleanup only drops the test database/login and any permission role the test itself created; it does not reset or truncate the canonical database. A crash may leave test resources for DBA inspection; never delete objects by a broad prefix without reviewing their ownership.

Covered behavior includes password success/failure, account flags, safe responses, cross-tenant HTTP and direct SQL reads/writes, permission allow/deny independent of role name, scope and grant expiry/revocation, missing identity context, single-connection concurrent tenant use, rollback cleanup, refresh rotation/reuse detection and immediate logout revocation. The Phase 2 verifier continues to check spatial types/GiST/uniqueness and now expects all 46 application tables to force RLS. It also verifies that DBA impersonation is rejected by the new runtime helper.

References: [NestJS authentication](https://docs.nestjs.com/security/authentication), [PostgreSQL role inheritance](https://www.postgresql.org/docs/18/role-membership.html), [Prisma 7 transactions](https://docs.prisma.io/docs/orm/v7/prisma-client/queries/transactions).
