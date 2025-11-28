import { Module } from "@nestjs/common";
import { JwtModule } from "@nestjs/jwt";
import { ConfigModule, ConfigService } from "@nestjs/config";
import { TypeOrmModule } from "@nestjs/typeorm";
import { ApiAuthService } from "./api-auth.service";
import { ApiAuthController } from "./api-auth.controller";
import { UsersModule } from "../users/users.module";
import { MailModule } from "../mail/mail.module";
import { Contract } from "../contracts/contract.entity";
import { PointsModule } from "../points/points.module";

@Module({
  imports: [
    ConfigModule,
    UsersModule,
    MailModule,
    PointsModule,
    TypeOrmModule.forFeature([Contract]),
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.get<string>("JWT_SECRET", "dev-secret"),
      }),
    }),
  ],
  providers: [ApiAuthService],
  controllers: [ApiAuthController],
})
export class ApiAuthModule {}
