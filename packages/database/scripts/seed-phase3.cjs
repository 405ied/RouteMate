const { randomBytes, scrypt } = require("node:crypto");
const { promisify } = require("node:util");
const permissions = [
  "organization.view",
  "organization_unit.view",
  "organization_unit.create",
  "user.view",
  "role.view",
  "driver.create",
  "driver.view",
  "driver.update",
  "driver.suspend",
  "vehicle.create",
  "vehicle.view",
  "vehicle.update",
  "incident.view",
  "incident.assign",
  "incident.update",
  "platform.organization.manage",
  "park.view",
  "park.create",
  "route.view",
  "route.create",
  "driver.approve",
  "vehicle.approve",
  "vehicle.suspend",
  "assignment.view",
  "assignment.manage",
  "qr.issue",
  "qr.revoke",
];
const baselineRoles = {
  ORGANIZATION_ADMIN: {
    name: "Organization Admin",
    permissions: permissions.filter((p) => !p.startsWith("platform.")),
  },
  STATE_ADMIN: {
    name: "State Admin",
    permissions: [
      "organization_unit.view",
      "driver.view",
      "vehicle.view",
      "incident.view",
    ],
  },
  BRANCH_ADMIN: {
    name: "Branch Admin",
    permissions: [
      "organization_unit.view",
      "driver.view",
      "vehicle.view",
      "incident.view",
    ],
  },
  PARK_MANAGER: {
    name: "Park Manager",
    permissions: ["driver.view", "vehicle.view", "incident.view"],
  },
  REGISTRATION_OFFICER: {
    name: "Registration Officer",
    permissions: [
      "driver.create",
      "driver.view",
      "driver.update",
      "vehicle.create",
      "vehicle.view",
      "vehicle.update",
    ],
  },
  COMPLIANCE_OFFICER: {
    name: "Compliance Officer",
    permissions: ["driver.view", "driver.suspend", "vehicle.view"],
  },
  SAFETY_OFFICER: {
    name: "Safety Officer",
    permissions: [
      "driver.view",
      "vehicle.view",
      "incident.view",
      "incident.assign",
      "incident.update",
    ],
  },
};
async function seed(client, { organizationCode, email, password }) {
  if (typeof organizationCode !== "string" || !organizationCode)
    throw new Error("BOOTSTRAP_ORGANIZATION_CODE is missing");
  if (!/^[A-Za-z0-9_-]{1,30}$/.test(organizationCode))
    throw new Error(
      "BOOTSTRAP_ORGANIZATION_CODE must be 1-30 letters, digits, underscores or hyphens",
    );
  if (typeof email !== "string" || !email.trim())
    throw new Error("BOOTSTRAP_ADMIN_EMAIL is missing");
  if (typeof password !== "string" || !password)
    throw new Error("BOOTSTRAP_ADMIN_PASSWORD is missing");
  if (password.length < 12)
    throw new Error("BOOTSTRAP_ADMIN_PASSWORD must be at least 12 characters");
  if (Buffer.byteLength(password) > 256)
    throw new Error("BOOTSTRAP_ADMIN_PASSWORD exceeds the 256-byte limit");
  const salt = randomBytes(16);
  const hash = await promisify(scrypt)(password, salt, 64, {
    N: 32768,
    r: 8,
    p: 1,
    maxmem: 64 * 1024 * 1024,
  });
  const encoded = `scrypt$32768$8$1$${salt.toString("hex")}$${hash.toString("hex")}`;
  await client.query("SELECT pg_advisory_xact_lock(731003)");
  const permissionIds = {};
  for (const code of permissions) {
    const result = await client.query(
      `INSERT INTO permissions(code,name,updated_at) VALUES($1,$1,now())
      ON CONFLICT(code) DO UPDATE SET name=permissions.name RETURNING id`,
      [code],
    );
    permissionIds[code] = result.rows[0].id;
  }
  const organization = (
    await client.query(
      `INSERT INTO organizations(organization_code,name,organization_type,status,updated_at)
    VALUES($1,'RouteMate Development Union','TRANSPORT_UNION','ACTIVE',now())
    ON CONFLICT(organization_code) DO UPDATE SET name=organizations.name RETURNING id`,
      [organizationCode],
    )
  ).rows[0].id;
  const roleIds = {};
  for (const [code, role] of Object.entries(baselineRoles)) {
    const roleId = (
      await client.query(
        `INSERT INTO roles(organization_id,code,name,updated_at)
      VALUES($1,$2,$3,now()) ON CONFLICT(organization_id,code) DO UPDATE SET name=roles.name RETURNING id`,
        [organization, code, role.name],
      )
    ).rows[0].id;
    roleIds[code] = roleId;
    for (const permission of role.permissions)
      await client.query(
        `INSERT INTO role_permissions(role_id,permission_id,updated_at) VALUES($1,$2,now()) ON CONFLICT DO NOTHING`,
        [roleId, permissionIds[permission]],
      );
  }
  let platform = (
    await client.query(
      `SELECT id FROM roles WHERE organization_id IS NULL AND code='PLATFORM_ADMIN'`,
    )
  ).rows[0]?.id;
  if (!platform)
    platform = (
      await client.query(
        `INSERT INTO roles(code,name,is_system,updated_at) VALUES('PLATFORM_ADMIN','RouteMate Super Admin',true,now()) RETURNING id`,
      )
    ).rows[0].id;
  await client.query(
    `INSERT INTO role_permissions(role_id,permission_id,updated_at) VALUES($1,$2,now()) ON CONFLICT DO NOTHING`,
    [platform, permissionIds["platform.organization.manage"]],
  );
  const units = [];
  let parent = null;
  for (const [code, name, type] of [
    ["NATIONAL", "National Office", "NATIONAL"],
    ["STATE", "Development State", "STATE_CHAPTER"],
    ["BRANCH", "Development Branch", "BRANCH"],
  ]) {
    const id = (
      await client.query(
        `INSERT INTO organization_units(organization_id,code,name,unit_type,parent_unit_id,updated_at)
      VALUES($1,$2,$3,$4,$5,now()) ON CONFLICT(organization_id,code) DO UPDATE SET name=organization_units.name RETURNING id`,
        [organization, code, name, type, parent],
      )
    ).rows[0].id;
    units.push(id);
    parent = id;
  }
  const park = (
    await client.query(
      `INSERT INTO parks(organization_id,organization_unit_id,park_code,name,updated_at)
    VALUES($1,$2,$3,'Development Park',now()) ON CONFLICT(park_code) DO UPDATE SET name=parks.name RETURNING id`,
      [
        organization,
        parent,
        `DEV_${organization.replaceAll("-", "").slice(0, 26)}`,
      ],
    )
  ).rows[0].id;
  const normalized = email.trim().toLowerCase();
  let user = (
    await client.query(
      "SELECT id FROM users WHERE organization_id=$1 AND lower(btrim(email))=$2",
      [organization, normalized],
    )
  ).rows[0]?.id;
  if (!user)
    user = (
      await client.query(
        `INSERT INTO users(organization_id,first_name,last_name,email,password_hash,status,updated_at)
    VALUES($1,'Development','Admin',$2,$3,'ACTIVE',now()) RETURNING id`,
        [organization, normalized, encoded],
      )
    ).rows[0].id;
  await client.query(
    `INSERT INTO user_roles(organization_id,user_id,role_id,scope,updated_at)
    SELECT $1,$2,$3,'ORGANIZATION',now() WHERE NOT EXISTS
    (SELECT 1 FROM user_roles WHERE organization_id=$1 AND user_id=$2 AND role_id=$3 AND scope='ORGANIZATION' AND revoked_at IS NULL)`,
    [organization, user, roleIds.ORGANIZATION_ADMIN],
  );
  return { organization, user, units, park, roleIds };
}
module.exports = { seed, permissions, baselineRoles };
if (require.main === module) {
  (async () => {
    if (process.env.NODE_ENV !== "development")
      throw new Error("Bootstrap requires NODE_ENV=development");
    const { Client } = require("pg");
    const url = process.env.ROUTEMATE_BOOTSTRAP_DATABASE_URL;
    if (!url) throw new Error("ROUTEMATE_BOOTSTRAP_DATABASE_URL required");
    const target = new URL(url);
    if (
      !["localhost", "127.0.0.1", "[::1]"].includes(target.hostname) ||
      target.pathname !== "/routemate_db"
    )
      throw new Error(
        "Development bootstrap is restricted to local routemate_db",
      );
    const client = new Client({ connectionString: url });
    try {
      await client.connect();
      await client.query("BEGIN");
      await seed(client, {
        organizationCode: process.env.BOOTSTRAP_ORGANIZATION_CODE,
        email: process.env.BOOTSTRAP_ADMIN_EMAIL,
        password: process.env.BOOTSTRAP_ADMIN_PASSWORD || "",
      });
      await client.query(
        process.argv.includes("--apply") ? "COMMIT" : "ROLLBACK",
      );
      console.log(
        process.argv.includes("--apply")
          ? "Development seed applied; existing passwords preserved."
          : "Seed validated and rolled back. Use --apply to persist.",
      );
    } catch (error) {
      await client.query("ROLLBACK").catch(() => {});
      throw error;
    } finally {
      await client.end();
    }
  })().catch((error) => {
    // Only print messages authored here. Driver messages/details can contain secrets.
    const safeMessages = new Set([
      "Bootstrap requires NODE_ENV=development",
      "ROUTEMATE_BOOTSTRAP_DATABASE_URL required",
      "Development bootstrap is restricted to local routemate_db",
      "BOOTSTRAP_ORGANIZATION_CODE is missing",
      "BOOTSTRAP_ORGANIZATION_CODE must be 1-30 letters, digits, underscores or hyphens",
      "BOOTSTRAP_ADMIN_EMAIL is missing",
      "BOOTSTRAP_ADMIN_PASSWORD is missing",
      "BOOTSTRAP_ADMIN_PASSWORD must be at least 12 characters",
      "BOOTSTRAP_ADMIN_PASSWORD exceeds the 256-byte limit",
    ]);
    const safeCodes = {
      ERR_INVALID_URL: "Bootstrap database URL is malformed",
      ECONNREFUSED: "PostgreSQL connection refused",
      "28P01": "PostgreSQL password authentication failed",
      "42501": "Insufficient PostgreSQL privileges",
      "42P01": "Required database relation is missing; check migrations",
      "23505": "Seed conflicts with an existing unique value",
      "23502": "A required database value is missing",
      "23503": "A referenced database record is missing",
      "42703": "Required database column is missing; check migrations",
    };
    const reason = safeMessages.has(error?.message)
      ? error.message
      : Object.hasOwn(safeCodes, error?.code)
        ? safeCodes[error.code]
        : "Unclassified failure; inspect with credential-safe diagnostics";
    console.error(`Seed failed: ${reason}. No credentials logged.`);
    process.exitCode = 1;
  });
}
