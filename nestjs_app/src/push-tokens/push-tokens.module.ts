import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { JwtModule } from "@nestjs/jwt";
import { ConfigModule, ConfigService } from "@nestjs/config";
import { UserPushToken } from "./push-token.entity";
import { PushTokensService } from "./push-tokens.service";
import { PushTokensController } from "./push-tokens.controller";
import { PushNotificationsService } from "./push-notifications.service";

@Module({
  imports: [
    TypeOrmModule.forFeature([UserPushToken]),
    ConfigModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.get<string>("JWT_SECRET", "dev-secret"),
      }),
    }),
  ],
  providers: [PushTokensService, PushNotificationsService],
  controllers: [PushTokensController],
  exports: [PushTokensService, PushNotificationsService],
})
export class PushTokensModule {}
