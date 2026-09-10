import { Injectable, OnModuleDestroy, OnModuleInit } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { Prisma } from "../../../../packages/database/generated/routemate-client";
import {
  createRuntimeClient,
  withRuntimeContext,
  setRuntimeContext,
  RuntimeContext,
} from "../../../../packages/database/runtime-context.cjs";

export type Transaction = Prisma.TransactionClient;
@Injectable()
export class DatabaseService implements OnModuleInit, OnModuleDestroy {
  private readonly client;
  constructor(config: ConfigService) {
    this.client = createRuntimeClient(
      config.getOrThrow<string>("ROUTEMATE_RUNTIME_DATABASE_URL"),
    );
  }
  async onModuleInit() {
    await this.run({}, async (tx) => {
      await tx.$queryRaw`SELECT 1`;
    });
  }
  async onModuleDestroy() {
    await this.client.$disconnect();
  }
  run<T>(context: RuntimeContext, work: (tx: Transaction) => Promise<T>) {
    return withRuntimeContext(this.client, context, work);
  }
  // Only authentication may establish identity after verifying credentials on this transaction.
  establishAuthenticatedContext(tx: Transaction, context: RuntimeContext) {
    return setRuntimeContext(tx, context);
  }
}
