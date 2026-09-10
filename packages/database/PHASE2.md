# RouteMate Phase 2 database

> Phase 3 supersedes the role-provisioning and runtime-helper instructions below. Keep `routemate_app` and `routemate_platform_admin` **NOLOGIN**. Use separate login principals as described in [Phase 3](../../docs/architecture/phase3-backend.md) and `infrastructure/postgres/phase3-principals.sql`. The runtime helper now checks inherited privileges and rejects DBA impersonation; Phase 3 integration tests exercise real login principals. The remainder records Phase 2's original implementation.

## Execution result — 2026-09-10

Applied successfully with Prisma migrate deploy to the canonical local database. Both `0_init` and `20260910150000_phase2_spatial_rls` are recorded as applied; migrate status reports up to date. Prisma 7.10.0 schema validation and client generation passed. Migration rollback rehearsal and post-deployment security tests passed, including the real Prisma runtime wrapper and commit/rollback cleanup on a one-connection pool. Verification left zero application rows; all fixtures were rolled back. The baseline migration hash is unchanged. No password or existing connection configuration was changed. Runtime credential provisioning and application wiring remain required before NestJS can use the restricted login.

Canonical workspace: `C:\RouteMate`. Database: `routemate_db` on `localhost:5432`.
Migration: `prisma/migrations/20260910150000_phase2_spatial_rls/migration.sql`.
`0_init` is preserved, SHA-256 `0372829fc09c576e64265d4e8848f8f7d0c98427d53aa4f140da7ac38ec90da6`.

## Native spatial inventory

All are nullable, WGS84 SRID 4326, longitude before latitude, and have individual GiST indexes.

| Table | Column | Native type |
|---|---|---|
| administrative_areas | geometry | geometry(MultiPolygon,4326) |
| organization_units | location | geography(Point,4326) |
| parks | location | geography(Point,4326) |
| routes | origin_location | geography(Point,4326) |
| routes | destination_location | geography(Point,4326) |
| routes | route_geometry | geometry(LineString,4326) |
| route_stops | location | geography(Point,4326) |
| verification_scans | location | geography(Point,4326) |
| journeys | boarding_location | geography(Point,4326) |
| journeys | ending_location | geography(Point,4326) |
| journey_events | location | geography(Point,4326) |
| incidents | location | geography(Point,4326) |

Polygon inputs become MultiPolygon without coordinate changes. Conversion rejects malformed JSON, JSON null, Features, wrong geometry types/SRID, empty geometry, extra dimensions, invalid topology and coordinates outside longitude ±180 / latitude ±90. SQL NULL stays NULL. Invalid data aborts the entire transaction; no automatic repair, coordinate relabeling, or deletion occurs. GiST indexes and native typmods persist; the migration-only conversion helper is removed. Validate geometry and ranges in all future write paths too: geography casts can normalize invalid coordinates.

The LineString is geometry for route analysis (interpolation, locating points, intersections). Geometry lengths in 4326 are degrees; cast to geography for meter distances/lengths or transform to a suitable local metric projection. A geography expression may require a separate expression index if its query plan needs one.

## Active uniqueness

`driver_vehicle_assignments_one_active_primary` reserves `(organization_id, vehicle_id)` when `status='ACTIVE' AND assignment_type='PRIMARY'`.
`vehicle_qr_codes_one_active` reserves `(organization_id, vehicle_id)` when `status='ACTIVE'`.
These intentionally include ACTIVE records with end/revocation timestamps: status must transition before replacement. Expiry is checked at runtime; clock time never changes a partial-index predicate. Rotate within one transaction, locking the vehicle and changing the old status before inserting the replacement. Existing duplicates cause an atomic failure, not cleanup.

## Roles and access boundaries

- `postgres`: DBA and migration work only. It bypasses RLS, including FORCE, and must never be the NestJS runtime connection.
- `routemate_app`: restricted runtime role; no superuser, BYPASSRLS, ownership, role creation, database creation or replication. Created NOLOGIN until a DBA provisions its secret.
- `routemate_platform_admin`: separate NOLOGIN role with explicit cross-tenant policies; no superuser or BYPASSRLS. No membership is granted to `routemate_app`. Provision a dedicated administrative login and grant this role only to that login. Its service explicitly uses `SET LOCAL ROLE routemate_platform_admin` inside a transaction after authenticating and authorizing a platform operator. Keep that credential out of the normal application process; audit actor, reason, action and outcome. An application role label or `app.is_platform_admin` setting grants no database elevation.

All 45 Prisma tables ENABLE and FORCE RLS. Runtime access is:

| Data | Runtime rule |
|---|---|
| Tables with organization_id | Exact authorized tenant, USING and WITH CHECK; NULL organization rows denied |
| organizations | Read own organization only; provisioning/editing through platform service |
| users, roles, user_roles | Read own tenant only; identity and authorization writes through controlled platform service |
| role_permissions | Read only where parent role is visible; platform manages grants |
| administrative_areas, permissions | Shared read-only reference data |
| passengers | Own authenticated passenger ID |
| trusted_contacts | Own authenticated passenger ID |
| passenger_sessions | Own passenger, or authenticated session ID with compatible passenger ownership |
| system_settings | Platform only |

Runtime logs, scans, status history, journey events, case updates and evidence receive SELECT/INSERT only; ordinary runtime cannot update/delete them. Platform administration retains maintenance access. No runtime TRUNCATE, DDL, migration-history access or automatic grants on future tables. Future migrations must explicitly classify tables and grant access after adding RLS. Public schema CREATE and PUBLIC application-table privileges are revoked.

RLS here is a tenant boundary for a trusted backend, not per-user RBAC. `app.user_id` records trusted actor context for application use; it is not itself a policy authorization check. A role holding arbitrary SQL access can set custom context variables: these are not signed credentials. Never expose this DB login, arbitrary SQL, or caller-selected tenant IDs to clients. Authorize tenant membership before starting a transaction. Passenger/public endpoints must not receive unrestricted tenant-scoped repositories; implement narrow server-authorized projections and operations. Do not expose driver contacts, identity documents or global passenger/session tables through public QR/share endpoints. Tenant staff do not automatically receive global passenger data.

## Credential transition (no passwords in files)

The existing `.env` and `DATABASE_URL` remain unchanged for Prisma migration work. `prisma.config.ts` continues to use that migration connection. The normal runtime helper deliberately reads **only** `ROUTEMATE_RUNTIME_DATABASE_URL` and refuses a different role name; no fallback to the migration URL.

In an interactive DBA `psql` session connected to this database, provision the role without putting secrets in shell history or SQL files:

```sql
ALTER ROLE routemate_app LOGIN;
\password routemate_app
GRANT CONNECT ON DATABASE routemate_db TO routemate_app;
```

Use `\password` to enter the generated secret interactively. Store the resulting runtime connection URL in the deployment secret manager as `ROUTEMATE_RUNTIME_DATABASE_URL`, with URI-encoded credentials; never commit it. Restart the NestJS service using that secret and verify `current_user='routemate_app'`, `rolsuper=false`, `rolbypassrls=false`. Do not enable the app using postgres while waiting for provisioning. Configure PostgreSQL host authentication appropriately; this migration does not edit `pg_hba.conf`.

For platform access, the DBA creates a separately named restricted login, provisions its password interactively and grants `routemate_platform_admin`. Keep NOINHERIT and use an explicit transaction-local role switch. Never grant that role to routemate_app. The migration intentionally fails if either managed role already exists so an unexpected privilege configuration cannot silently be reused.

## Prisma / NestJS integration

`runtime-context.cjs` exports `createRuntimeClient()` and `withRuntimeContext()`. Inject the client into a NestJS provider and call the wrapper only with IDs derived from verified authentication and membership. It validates IDs, checks the effective DB role and sets all four context keys with parameterized `set_config(..., true)` on the same interactive transaction connection.

```js
const { createRuntimeClient, withRuntimeContext } = require('./runtime-context.cjs');
const prisma = createRuntimeClient();
const rows = await withRuntimeContext(prisma, authorizedContext, async tx => {
  return tx.$queryRaw`
    SELECT id, name, ST_AsGeoJSON(location::geometry)::jsonb AS location
    FROM parks
    WHERE organization_id = ${authorizedContext.organizationId}::uuid`;
});
```

Use **only `tx`** within the callback, including spatial raw SQL and nested services. Never set session-global context or set it on one pooled connection and query another. Transaction-local values disappear on commit/rollback; reset every optional identity on every call. Keep transactions short, avoid external network calls within them, and use transaction pooling (not statement pooling). Apply the same wrapper for jobs. The callback must not override context or escape through the root Prisma client. Disconnect the client on service shutdown.

All native fields are `Unsupported(...)` in schema.prisma. Read them as GeoJSON/text and write using tagged `$queryRaw`/`$executeRaw` with validated coordinates and PostGIS constructors; do not return raw geometry/geography to Prisma's decoder. They are omitted from ordinary generated CRUD inputs/results.

## Migration and validation workflow

From `C:\RouteMate\packages\database`, with the existing DBA migration environment:

```powershell
npx --no-install prisma validate
npx --no-install prisma generate
node scripts/verify-phase2.cjs --dry-run
npx --no-install prisma migrate deploy
node scripts/verify-phase2.cjs
npx --no-install prisma migrate status
```

Dry-run is only for the pre-Phase-2 state; it executes migration DDL and security tests in a transaction then rolls everything back. Verification after deployment rolls back test fixtures and checks the unchanged baseline hash, native types/indexes, forced RLS coverage, missing/malformed context, tenant CRUD and rejected cross-tenant writes, owner privacy, attempted platform spoofing/role switching, partial uniqueness and connection-context cleanup. Requires a DBA connection because fixtures span tenants and verification switches roles. Errors suppress row/credential details. The runner restricts its target to local routemate_db:5432.

Apply through `migrate deploy`, not raw execution, so Prisma records the migration. The migration has explicit BEGIN/COMMIT, a 10-second lock timeout and a 5-minute statement timeout. Type conversions and regular index creation acquire locks; plan a maintenance window for populated deployments and take a verified backup. If it fails, transaction changes roll back. Investigate and correct the cause; only after confirming rollback use `prisma migrate resolve --rolled-back 20260910150000_phase2_spatial_rls`, then retry deploy. Never reset the DB or edit an applied migration.

For future changes use reviewed SQL migrations. `Unsupported` preserves type declarations but does not model policies, grants or all native indexes. Never use `db push` against this database; never apply an automatically generated diff without reviewing it for removed native features. Do not use `migrate dev` against routemate_db. Test migration replay in an isolated disposable database/cluster with required extensions and roles; these CREATE ROLE statements are cluster-wide and require fresh role names/state. Extension tables are not Prisma application tables.

## Remaining integration and hardening

Credential provisioning and NestJS wiring are deployment steps; there are currently no application files in `apps` to wire. Identity bootstrap, narrowly scoped public QR/share endpoints, platform authorization/auditing, per-user RBAC, remaining UUID-only reference consistency triggers, hierarchy/temporal constraints, additional Phase-1 backlog indexes, immutable audit triggers for privileged paths, and full-text search are outside this requested migration. Tenant equality does not validate every linked reporter/driver/vehicle relationship. The schema's existing backlog comments remain to track those items; they must not be interpreted as completed protections.

References: [PostgreSQL row security](https://www.postgresql.org/docs/current/ddl-rowsecurity.html), [PostGIS geometry validation](https://postgis.net/docs/reference.html), [Prisma 7 Unsupported/raw spatial fields](https://www.prisma.io/docs/orm/v7/prisma-client/using-raw-sql/safeql).
