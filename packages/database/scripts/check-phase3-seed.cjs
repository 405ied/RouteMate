// Rolls back by default. Explicit --apply persists using the existing migration URL.
const fs = require("node:fs");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

try {
  const args = process.argv.slice(2);
  if (args.length > 1 || (args.length === 1 && args[0] !== "--apply")) {
    throw new Error("Only --apply is supported");
  }
  const config = require("dotenv").parse(
    fs.readFileSync(path.join(__dirname, "../.env")),
  );
  if (!config.DATABASE_URL) {
    console.error("Check failed: DATABASE_URL is missing from the database .env.");
    process.exitCode = 1;
  } else {
    const result = spawnSync(
      process.execPath,
      [path.join(__dirname, "seed-phase3.cjs"), ...args],
      {
        stdio: "inherit",
        env: {
          ...process.env,
          ROUTEMATE_BOOTSTRAP_DATABASE_URL: config.DATABASE_URL,
        },
      },
    );
    process.exitCode = result.status ?? 1;
  }
} catch {
  console.error(
    "Seed helper failed: verify the database .env is readable; use no arguments to validate or --apply to persist. No credentials logged.",
  );
  process.exitCode = 1;
}
