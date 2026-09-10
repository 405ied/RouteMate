import "reflect-metadata";
import { ConsoleLogger, Logger } from "@nestjs/common";
import { NestFactory } from "@nestjs/core";
import { ConfigService } from "@nestjs/config";
import { AppModule } from "./app.module";
import { configureHttp } from "./common/http";
async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    logger: new ConsoleLogger({ json: true }),
    bodyParser: true,
  });
  configureHttp(app);
  await app.listen(app.get(ConfigService).getOrThrow<number>("PORT"));
}
bootstrap().catch(() => {
  Logger.error("API startup failed; verify configuration and database role.");
  process.exitCode = 1;
});
