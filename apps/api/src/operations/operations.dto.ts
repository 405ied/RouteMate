import { Type } from "class-transformer";
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsEnum,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Length,
  Matches,
  Max,
  Min,
  ValidateNested,
} from "class-validator";
import {
  ParkType,
  VehicleType,
} from "../../../../packages/database/generated/routemate-client";
export class PointDto {
  @IsNumber() @Min(-180) @Max(180) longitude!: number;
  @IsNumber() @Min(-90) @Max(90) latitude!: number;
}
export class CreateParkDto {
  @IsUUID() organizationUnitId!: string;
  @IsString() @Length(1, 255) name!: string;
  @IsOptional() @IsEnum(ParkType) parkType?: ParkType;
  @IsOptional() @IsInt() @Min(1) @Max(100000) capacity?: number;
  @IsOptional() @ValidateNested() @Type(() => PointDto) location?: PointDto;
}
export class CreateRouteDto {
  @IsUUID() parkId!: string;
  @IsString() @Length(1, 255) name!: string;
  @IsString() @Length(1, 255) originName!: string;
  @IsString() @Length(1, 255) destinationName!: string;
  @IsOptional()
  @IsArray()
  @ArrayMinSize(2)
  @ArrayMaxSize(1000)
  @ValidateNested({ each: true })
  @Type(() => PointDto)
  points?: PointDto[];
}
export class CreateDriverDto {
  @IsUUID() parkId!: string;
  @IsString() @Length(1, 100) firstName!: string;
  @IsString() @Length(1, 100) lastName!: string;
  @IsString() @Matches(/^\+?[0-9]{7,15}$/) phone!: string;
}
export class CreateVehicleDto {
  @IsUUID() parkId!: string;
  @IsString() @Matches(/^[A-Za-z0-9 -]{3,32}$/) plateNumber!: string;
  @IsEnum(VehicleType) vehicleType!: VehicleType;
  @IsInt() @Min(1) @Max(200) passengerCapacity!: number;
  @IsOptional() @IsString() @Length(1, 100) make?: string;
  @IsOptional() @IsString() @Length(1, 100) model?: string;
  @IsOptional() @IsString() @Length(1, 50) colour?: string;
}
export class DriverAssignmentDto {
  @IsUUID() driverId!: string;
}
export class RouteAssignmentDto {
  @IsUUID() routeId!: string;
}
export class IssueQrDto {
  @IsInt() @Min(1) @Max(365) expiresInDays = 30;
}
export class VerifyQrDto {
  @IsString() @Matches(/^[A-Za-z0-9_-]{43}$/) token!: string;
}
