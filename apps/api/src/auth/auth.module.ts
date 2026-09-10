import { Global, Module } from "@nestjs/common";
import { JwtModule } from "@nestjs/jwt";
import { AuthService } from "./auth.service";
import { TokenService } from "./token.service";
import { AuthController } from "./auth.controller";
@Global()
@Module({
  imports: [JwtModule.register({})],
  providers: [AuthService, TokenService],
  controllers: [AuthController],
  exports: [AuthService, TokenService],
})
export class AuthModule {}
