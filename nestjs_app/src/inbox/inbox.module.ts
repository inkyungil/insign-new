import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { JwtModule } from "@nestjs/jwt";
import { ConfigModule, ConfigService } from "@nestjs/config";
import { InboxMessage } from "./inbox-message.entity";
import { InboxService } from "./inbox.service";
import { InboxController } from "./inbox.controller";
import { EncryptionService } from "../common/encryption.service";

@Module({
  imports: [
    TypeOrmModule.forFeature([InboxMessage]),
    ConfigModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.get<string>("JWT_SECRET", "dev-secret"),
      }),
    }),
  ],
  providers: [InboxService, EncryptionService],
  controllers: [InboxController],
  exports: [InboxService],
})
export class InboxModule {}
