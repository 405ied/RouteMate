import { randomBytes, scrypt, timingSafeEqual } from "node:crypto";
const options = { N: 32768, r: 8, p: 1, maxmem: 64 * 1024 * 1024 };
function derive(password: string, salt: Buffer): Promise<Buffer> {
  return new Promise((resolve, reject) =>
    scrypt(password, salt, 64, options, (error, key) =>
      error ? reject(error) : resolve(key),
    ),
  );
}
export async function hashPassword(password: string) {
  if (password.length < 12 || Buffer.byteLength(password) > 256)
    throw new Error("Password must contain 12 to 256 bytes");
  const salt = randomBytes(16);
  return `scrypt$32768$8$1$${salt.toString("hex")}$${(await derive(password, salt)).toString("hex")}`;
}
// Fixed format and work factor prevent attacker-controlled parameters exhausting resources.
const pattern = /^scrypt\$32768\$8\$1\$([a-f0-9]{32})\$([a-f0-9]{128})$/;
export async function verifyPassword(password: string, encoded: string | null) {
  const match = encoded?.match(pattern);
  const key = await derive(
    password,
    Buffer.from(match?.[1] ?? "00".repeat(16), "hex"),
  );
  return !!match && timingSafeEqual(key, Buffer.from(match[2], "hex"));
}
