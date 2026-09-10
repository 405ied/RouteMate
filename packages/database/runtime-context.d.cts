import { Prisma, PrismaClient } from "./generated/routemate-client";
export interface RuntimeContext {
  organizationId?: string;
  userId?: string;
  passengerId?: string;
  passengerSessionId?: string;
}
export function createRuntimeClient(connectionString?: string): PrismaClient;
export function assertRuntimeRole(tx: Prisma.TransactionClient): Promise<void>;
export function setRuntimeContext(
  tx: Prisma.TransactionClient,
  context: RuntimeContext,
): Promise<void>;
export function withRuntimeContext<T>(
  client: PrismaClient,
  context: RuntimeContext,
  operation: (tx: Prisma.TransactionClient) => Promise<T>,
): Promise<T>;
