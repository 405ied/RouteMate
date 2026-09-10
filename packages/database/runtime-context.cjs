const { PrismaClient } = require('./generated/routemate-client');
const { PrismaPg } = require('@prisma/adapter-pg');

// Use only after authentication and authorization. Never pass request-body IDs directly.
function createRuntimeClient() {
  const connectionString = process.env.ROUTEMATE_RUNTIME_DATABASE_URL;
  if (!connectionString) throw new Error('ROUTEMATE_RUNTIME_DATABASE_URL is required');
  const url = new URL(connectionString);
  if (decodeURIComponent(url.username) !== 'routemate_app') {
    throw new Error('Runtime connection must use routemate_app');
  }
  return new PrismaClient({ adapter: new PrismaPg({ connectionString }) });
}

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
async function withRuntimeContext(prisma, authorizedContext, operation) {
  const keys = ['organizationId','userId','passengerId','passengerSessionId'];
  const values = keys.map(key => authorizedContext[key] ?? '');
  if (values.some(value => typeof value !== 'string' || (value !== '' && !uuid.test(value)))) {
    throw new Error('Context IDs must be UUIDs');
  }
  return prisma.$transaction(async tx => {
    const [role] = await tx.$queryRaw`
      SELECT current_user AS name, rolsuper, rolbypassrls FROM pg_roles WHERE rolname = current_user`;
    if (role?.name !== 'routemate_app' || role.rolsuper || role.rolbypassrls) {
      throw new Error('Unsafe runtime database role');
    }
    // true = transaction local. Set EVERY value, including absent ones, on this connection.
    await tx.$queryRaw`
      SELECT set_config('app.organization_id', ${values[0]}, true),
             set_config('app.user_id', ${values[1]}, true),
             set_config('app.passenger_id', ${values[2]}, true),
             set_config('app.passenger_session_id', ${values[3]}, true)`;
    return operation(tx);
  });
}

module.exports = { createRuntimeClient, withRuntimeContext };
