import { z } from "zod";

export const environmentSchema = z
  .object({
    NODE_ENV: z
      .enum(["development", "test", "production"])
      .default("development"),
    PORT: z.coerce.number().int().min(1).max(65535).default(3000),
    ROUTEMATE_RUNTIME_DATABASE_URL: z
      .string()
      .url()
      .refine((value) => {
        const url = new URL(value);
        return (
          ["postgres:", "postgresql:"].includes(url.protocol) &&
          ![
            "postgres",
            "routemate_app",
            "routemate_platform_admin",
            "routemate_auth_owner",
          ].includes(decodeURIComponent(url.username))
        );
      }),
    JWT_ACCESS_SECRET: z.string().min(48),
    JWT_REFRESH_SECRET: z.string().min(48),
    JWT_ISSUER: z.string().min(1).default("routemate-api"),
    JWT_AUDIENCE: z.string().min(1).default("routemate-staff"),
    ACCESS_TOKEN_SECONDS: z.coerce.number().int().min(60).max(900).default(900),
    REFRESH_TOKEN_SECONDS: z.coerce
      .number()
      .int()
      .min(300)
      .max(2592000)
      .default(604800),
    CORS_ORIGINS: z.string().default(""),
  })
  .refine((env) => env.JWT_ACCESS_SECRET !== env.JWT_REFRESH_SECRET, {
    message: "JWT secrets must differ",
  });

export function validateEnvironment(input: Record<string, unknown>) {
  const parsed = environmentSchema.safeParse(input);
  if (!parsed.success)
    throw new Error(
      `Invalid environment configuration: ${parsed.error.issues.map((i) => i.path.join(".") || "JWT secrets").join(", ")}`,
    );
  for (const origin of parsed.data.CORS_ORIGINS.split(",").filter(Boolean)) {
    let url: URL;
    try {
      url = new URL(origin);
    } catch {
      throw new Error("Invalid CORS_ORIGINS");
    }
    if (
      url.origin !== origin ||
      (parsed.data.NODE_ENV === "production" && url.protocol !== "https:")
    )
      throw new Error("Invalid CORS_ORIGINS");
  }
  return parsed.data;
}
