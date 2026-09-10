# Phase 3 delivery — 2026-09-10

Implemented directly on branch `main` in `C:\RouteMate`. No detached copies or commits were created.

## Delivered

- NestJS/TypeScript API in apps/api with validated configuration, structured errors/request logging, health, security headers and throttling.
- Existing Prisma 7 client plus PostgreSQL adapter, transaction-bound RLS context and strict checks for a separate restricted login principal.
- Scrypt staff authentication, distinct access/refresh JWT secrets, hashed refresh persistence, serialized rotation/replay revocation, logout and live account/session checks.
- Tenant-derived context, granular RBAC guards and scoped unit queries; foundation users, roles/permissions, organizations and organization-units endpoints.
- Safe development seed for permissions, baseline roles, organization/unit/park hierarchy and an environment-provided administrator.
- Separate runtime/platform principal provisioning SQL; existing permission roles remain NOLOGIN.

## Database result

New migration `20260910170000_phase3_auth_sessions` was rehearsed with rollback, then applied via Prisma migrate deploy to localhost:5432/routemate_db. All three migrations are recorded as applied and status reports up to date. The new table is staff_sessions; a normalized tenant/email index and narrow authentication functions/policies were added. All 46 application tables force RLS. The three permission/function-owner roles are NOLOGIN, non-superuser and NOBYPASSRLS.

`0_init` and `20260910150000_phase2_spatial_rls` have no Git diff. Existing migration .env and prisma.config.ts were not edited. The canonical database contains zero application rows after validation; no bootstrap account or test data was persisted there.

## Commands and checks

| Command/check | Result |
|---|---|
| npm install --no-audit --no-fund (apps/api) | Installed dependencies and lockfile; sandbox registry denial resolved with approved elevated installation |
| npm run build | Passed |
| npm run lint | Passed; this script performs TypeScript no-emit checking |
| npm run format / npm run format:check | Applied formatting; check passed |
| npm test | 3 unit tests passed |
| npm run test:integration | 7 integration groups passed; Node reports 8 including the enclosing suite |
| prisma validate / prisma generate | Passed using existing local Prisma 7.10.0 |
| New migration rollback rehearsal | Passed without retaining changes |
| prisma migrate deploy / prisma migrate status | Applied new migration; up to date |
| node scripts/verify-phase2.cjs | Passed: 12 native spatial columns/GiST, partial uniqueness, 46 forced RLS tables, tenant/owner isolation and rejection of DBA impersonation |
| git status / git diff of both earlier migrations | Changes remain uncommitted; earlier migrations unchanged |
| git diff --check | Passed after normalizing whitespace on newly generated TypeScript declaration lines |

Integration checks use a fresh temporary database and real restricted login, verify login success/failure, account status/lock/MFA restrictions, tenant reads/writes, RBAC independent of role name, unit descendants/park confinement, expired/revoked grants, pooled context cleanup, token rotation/replay and logout. Tests delete only their own isolated resources. The final seed and park-scope changes were included in the passing integration run. Final cleanup checks found zero remaining temporary test databases and zero temporary test login roles.

## Manual setup remaining

No implementation blocker remains. Before starting the API, a DBA must provision the separate persistent login(s), supply passwords interactively, and inject the runtime connection plus two independent JWT secrets. The example configuration contains no secrets. The API is not left running with a superuser or temporary test credential.

Run the reviewed [principal provisioning script](C:/RouteMate/infrastructure/postgres/phase3-principals.sql) in interactive psql with ON_ERROR_STOP enabled, or follow its individual commands. It uses `\password` prompts; never change the NOLOGIN permission roles into logins. Inject the variables documented in [Phase 3 architecture](C:/RouteMate/docs/architecture/phase3-backend.md), then run the documented seed rehearsal/explicit apply with bootstrap credentials if a development administrator is wanted. No real bootstrap password was supplied, so the persistent seed was not run.

The foundation intentionally leaves privileged identity/grant mutations and platform HTTP service implementation separate. Drivers, vehicles, routes, QR, public passenger endpoints, MFA challenges and password reset are later phases. Multi-instance deployments also need shared rate-limit storage and trusted-ingress configuration, as documented.

## Created and modified files

- [apps/api/.env.example](C:/RouteMate/apps/api/.env.example)
- [apps/api/package-lock.json](C:/RouteMate/apps/api/package-lock.json)
- [apps/api/package.json](C:/RouteMate/apps/api/package.json)
- [apps/api/src/app.module.ts](C:/RouteMate/apps/api/src/app.module.ts)
- [apps/api/src/auth/auth.controller.ts](C:/RouteMate/apps/api/src/auth/auth.controller.ts)
- [apps/api/src/auth/auth.dto.ts](C:/RouteMate/apps/api/src/auth/auth.dto.ts)
- [apps/api/src/auth/auth.guard.ts](C:/RouteMate/apps/api/src/auth/auth.guard.ts)
- [apps/api/src/auth/auth.module.ts](C:/RouteMate/apps/api/src/auth/auth.module.ts)
- [apps/api/src/auth/auth.service.ts](C:/RouteMate/apps/api/src/auth/auth.service.ts)
- [apps/api/src/auth/password.ts](C:/RouteMate/apps/api/src/auth/password.ts)
- [apps/api/src/auth/token.service.ts](C:/RouteMate/apps/api/src/auth/token.service.ts)
- [apps/api/src/common/http.ts](C:/RouteMate/apps/api/src/common/http.ts)
- [apps/api/src/config/environment.ts](C:/RouteMate/apps/api/src/config/environment.ts)
- [apps/api/src/database/database.module.ts](C:/RouteMate/apps/api/src/database/database.module.ts)
- [apps/api/src/database/database.service.ts](C:/RouteMate/apps/api/src/database/database.service.ts)
- [apps/api/src/health/health.module.ts](C:/RouteMate/apps/api/src/health/health.module.ts)
- [apps/api/src/main.ts](C:/RouteMate/apps/api/src/main.ts)
- [apps/api/src/organization-units/organization-units.module.ts](C:/RouteMate/apps/api/src/organization-units/organization-units.module.ts)
- [apps/api/src/organizations/organizations.module.ts](C:/RouteMate/apps/api/src/organizations/organizations.module.ts)
- [apps/api/src/rbac/permission.guard.ts](C:/RouteMate/apps/api/src/rbac/permission.guard.ts)
- [apps/api/src/rbac/rbac.module.ts](C:/RouteMate/apps/api/src/rbac/rbac.module.ts)
- [apps/api/src/rbac/rbac.service.ts](C:/RouteMate/apps/api/src/rbac/rbac.service.ts)
- [apps/api/src/roles/roles.module.ts](C:/RouteMate/apps/api/src/roles/roles.module.ts)
- [apps/api/src/users/users.module.ts](C:/RouteMate/apps/api/src/users/users.module.ts)
- [apps/api/test/integration.test.ts](C:/RouteMate/apps/api/test/integration.test.ts)
- [apps/api/test/unit.test.ts](C:/RouteMate/apps/api/test/unit.test.ts)
- [apps/api/tsconfig.json](C:/RouteMate/apps/api/tsconfig.json)
- [docs/api/phase3-endpoints.md](C:/RouteMate/docs/api/phase3-endpoints.md)
- [docs/architecture/phase3-backend.md](C:/RouteMate/docs/architecture/phase3-backend.md)
- [docs/architecture/phase3-delivery.md](C:/RouteMate/docs/architecture/phase3-delivery.md)
- [infrastructure/postgres/phase3-principals.sql](C:/RouteMate/infrastructure/postgres/phase3-principals.sql)
- [packages/database/PHASE2.md](C:/RouteMate/packages/database/PHASE2.md)
- [packages/database/generated/routemate-client/edge.js](C:/RouteMate/packages/database/generated/routemate-client/edge.js)
- [packages/database/generated/routemate-client/index-browser.js](C:/RouteMate/packages/database/generated/routemate-client/index-browser.js)
- [packages/database/generated/routemate-client/index.d.ts](C:/RouteMate/packages/database/generated/routemate-client/index.d.ts)
- [packages/database/generated/routemate-client/index.js](C:/RouteMate/packages/database/generated/routemate-client/index.js)
- [packages/database/generated/routemate-client/package.json](C:/RouteMate/packages/database/generated/routemate-client/package.json)
- [packages/database/generated/routemate-client/schema.prisma](C:/RouteMate/packages/database/generated/routemate-client/schema.prisma)
- [packages/database/prisma/migrations/20260910170000_phase3_auth_sessions/migration.sql](C:/RouteMate/packages/database/prisma/migrations/20260910170000_phase3_auth_sessions/migration.sql)
- [packages/database/prisma/schema.prisma](C:/RouteMate/packages/database/prisma/schema.prisma)
- [packages/database/runtime-context.cjs](C:/RouteMate/packages/database/runtime-context.cjs)
- [packages/database/runtime-context.d.cts](C:/RouteMate/packages/database/runtime-context.d.cts)
- [packages/database/scripts/seed-phase3.cjs](C:/RouteMate/packages/database/scripts/seed-phase3.cjs)
- [packages/database/scripts/verify-phase2.cjs](C:/RouteMate/packages/database/scripts/verify-phase2.cjs)
