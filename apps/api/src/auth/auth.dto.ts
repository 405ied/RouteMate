import { IsEmail, IsString, Length, MaxLength } from "class-validator";
export class LoginDto {
  @IsString() @Length(1, 30) organizationCode!: string;
  @IsEmail() @MaxLength(254) email!: string;
  @IsString() @Length(1, 256) password!: string;
}
export class RefreshDto {
  @IsString() @Length(1, 4096) refreshToken!: string;
}
