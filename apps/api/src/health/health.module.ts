import {
  Controller,
  Get,
  Module,
  ServiceUnavailableException,
} from "@nestjs/common";
import { Public } from "../auth/auth.guard";
import { DatabaseService } from "../database/database.service";
@Controller("health")
class HealthController {
  constructor(private readonly db: DatabaseService) {}
  @Public()
  @Get()
  live() {
    return { status: "ok" };
  }
  @Public()
  @Get("ready")
  async ready() {
    try {
      await this.db.run({}, async (tx) => {
        await tx.$queryRaw`SELECT 1`;
      });
      return { status: "ready" };
    } catch {
      throw new ServiceUnavailableException("Not ready");
    }
  }
}
@Module({ controllers: [HealthController] })
export class HealthModule {}
