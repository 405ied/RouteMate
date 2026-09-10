import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  INestApplication,
  Logger,
  ValidationPipe,
} from "@nestjs/common";
import { Request, Response, NextFunction } from "express";
import { randomUUID } from "node:crypto";
import helmet from "helmet";
import { ConfigService } from "@nestjs/config";
@Catch()
export class HttpErrorFilter implements ExceptionFilter {
  catch(error: unknown, host: ArgumentsHost) {
    const context = host.switchToHttp();
    const response = context.getResponse<Response>();
    const request = context.getRequest<Request & { requestId: string }>();
    const code =
      typeof error === "object" && error && "code" in error
        ? String(error.code)
        : "";
    const status =
      error instanceof HttpException
        ? error.getStatus()
        : code === "P2025"
          ? 404
          : ["P2002", "P2003"].includes(code)
            ? 409
            : 500;
    const detail =
      error instanceof HttpException ? error.getResponse() : undefined;
    const message =
      typeof detail === "object" && detail && "message" in detail
        ? detail.message
        : status === 500
          ? "Internal server error"
          : status === 404
            ? "Not found"
            : status === 409
              ? "Record conflict"
              : "Request failed";
    response
      .status(status)
      .json({ error: { status, message, requestId: request.requestId } });
  }
}
export function configureHttp(app: INestApplication) {
  const config = app.get(ConfigService);
  app.setGlobalPrefix("api/v1");
  app.use(helmet());
  app.use(
    (
      request: Request & { requestId: string },
      response: Response,
      next: NextFunction,
    ) => {
      const start = Date.now();
      request.requestId = randomUUID();
      response.setHeader("X-Request-Id", request.requestId);
      response.setHeader("Cache-Control", "no-store");
      response.on("finish", () =>
        Logger.log(
          {
            event: "http_request",
            requestId: request.requestId,
            method: request.method,
            route: request.route?.path || "unmatched",
            status: response.statusCode,
            durationMs: Date.now() - start,
          },
          "HTTP",
        ),
      );
      next();
    },
  );
  const origins = config
    .getOrThrow<string>("CORS_ORIGINS")
    .split(",")
    .filter(Boolean);
  if (origins.length)
    app.enableCors({
      origin: origins,
      credentials: false,
      methods: ["GET", "POST"],
      allowedHeaders: ["Authorization", "Content-Type"],
    });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      validationError: { target: false, value: false },
    }),
  );
  app.useGlobalFilters(new HttpErrorFilter());
  app.enableShutdownHooks();
}
