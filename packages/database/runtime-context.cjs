const { PrismaClient } = require("./generated/routemate-client");
const { PrismaPg } = require("@prisma/adapter-pg");

// Use only after authentication and authorization. Never pass request-body IDs directly.
function createRuntimeClient(
  connectionString = process.env.ROUTEMATE_RUNTIME_DATABASE_URL,
) {
  if (!connectionString)
    throw new Error("ROUTEMATE_RUNTIME_DATABASE_URL is required");
  const url = new URL(connectionString);
  if (
    [
      "postgres",
      "routemate_app",
      "routemate_platform_admin",
      "routemate_auth_owner",
    ].includes(decodeURIComponent(url.username))
  ) {
    throw new Error(
      "Use a separate restricted LOGIN principal inheriting routemate_app",
    );
  }
  return new PrismaClient({ adapter: new PrismaPg({ connectionString }) });
}

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
async function assertRuntimeRole(tx) {
  const [role] = await tx.$queryRaw`
    SELECT r.rolcanlogin, r.rolsuper, r.rolbypassrls, r.rolcreaterole, r.rolcreatedb, r.rolreplication,
      current_user = session_user AS direct_login,
      pg_has_role(current_user, 'routemate_app', 'USAGE') AS runtime,
      pg_has_role(current_user, 'routemate_platform_admin', 'MEMBER') AS platform,
      pg_has_role(current_user, 'routemate_auth_owner', 'MEMBER') AS auth_owner,
      EXISTS (SELECT 1 FROM pg_roles verification WHERE verification.rolname='routemate_verification_owner'
        AND pg_has_role(current_user,verification.oid,'MEMBER')) AS verification_owner,
      EXISTS (SELECT 1 FROM pg_roles elevated WHERE
        (elevated.rolsuper OR elevated.rolbypassrls OR elevated.rolcreaterole OR elevated.rolcreatedb OR elevated.rolreplication)
        AND pg_has_role(current_user,elevated.oid,'MEMBER')) AS elevated_membership,
      EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
        WHERE n.nspname IN ('public','routemate_security') AND pg_has_role(current_user,c.relowner,'MEMBER')) AS owns_objects
    FROM pg_roles r WHERE r.rolname = current_user`;
  if (
    !role?.rolcanlogin ||
    !role.direct_login ||
    !role.runtime ||
    role.platform ||
    role.auth_owner ||
    role.verification_owner ||
    role.rolsuper ||
    role.rolbypassrls ||
    role.rolcreaterole ||
    role.rolcreatedb ||
    role.rolreplication ||
    role.owns_objects ||
    role.elevated_membership
  ) {
    throw new Error("Unsafe runtime database identity or privileges");
  }
}
async function setRuntimeContext(tx, authorizedContext) {
  const keys = [
    "organizationId",
    "userId",
    "passengerId",
    "passengerSessionId",
  ];
  const values = keys.map((key) => authorizedContext[key] ?? "");
  if (
    values.some(
      (value) =>
        typeof value !== "string" || (value !== "" && !uuid.test(value)),
    )
  ) {
    throw new Error("Context IDs must be UUIDs");
  }
  // true = transaction local. Set EVERY value, including absent ones, on this connection.
  await tx.$queryRaw`
      SELECT set_config('app.organization_id', ${values[0]}, true),
             set_config('app.user_id', ${values[1]}, true),
             set_config('app.passenger_id', ${values[2]}, true),
             set_config('app.passenger_session_id', ${values[3]}, true)`;
}
async function withRuntimeContext(prisma, authorizedContext, operation) {
  return prisma.$transaction(
    async (tx) => {
      await assertRuntimeRole(tx);
      await setRuntimeContext(tx, authorizedContext);
      return operation(tx);
    },
    { maxWait: 5000, timeout: 10000 },
  );
}

module.exports = {
  createRuntimeClient,
  assertRuntimeRole,
  setRuntimeContext,
  withRuntimeContext,
};
