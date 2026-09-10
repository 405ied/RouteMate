import {
  CanActivate,
  ExecutionContext,
  Injectable,
  SetMetadata,
  UnauthorizedException,
} from "@nestjs/common";
import { Reflector } from "@nestjs/core";
import { Request } from "express";
import { AuthService } from "./auth.service";
import { Identity } from "./token.service";
export const Public = () => SetMetadata("public", true);
export type StaffRequest = Request & { identity: Identity; requestId: string };
@Injectable()
export class AuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly auth: AuthService,
  ) {}
  async canActivate(context: ExecutionContext) {
    if (
      this.reflector.getAllAndOverride<boolean>("public", [
        context.getHandler(),
        context.getClass(),
      ])
    )
      return true;
    const request = context.switchToHttp().getRequest<StaffRequest>();
    const match = request.headers.authorization?.match(/^Bearer ([^ ]+)$/);
    if (!match || match[1].length > 4096)
      throw new UnauthorizedException("Bearer token required");
    request.identity = await this.auth.authenticate(match[1]);
    return true;
  }
}
