import { Body, Controller, Get, HttpCode, Post, Req } from "@nestjs/common";
import { Throttle } from "@nestjs/throttler";
import { AuthService } from "./auth.service";
import { LoginDto, RefreshDto } from "./auth.dto";
import { Public, StaffRequest } from "./auth.guard";
@Controller("auth")
export class AuthController {
  constructor(private readonly auth: AuthService) {}
  @Public()
  @Post("login")
  @HttpCode(200)
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  login(@Body() input: LoginDto) {
    return this.auth.login(input);
  }
  @Public()
  @Post("refresh")
  @HttpCode(200)
  @Throttle({ default: { limit: 20, ttl: 60000 } })
  refresh(@Body() input: RefreshDto) {
    return this.auth.refresh(input.refreshToken);
  }
  @Post("logout")
  @HttpCode(200)
  logout(@Req() request: StaffRequest) {
    return this.auth.logout(request.identity);
  }
  @Get("me")
  me(@Req() request: StaffRequest) {
    return request.identity;
  }
}
