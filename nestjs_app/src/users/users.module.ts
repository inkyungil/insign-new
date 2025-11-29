import { Module } from "@nestjs/common";
import { ConfigModule } from "@nestjs/config";
import { TypeOrmModule } from "@nestjs/typeorm";
import { UsersService } from "./users.service";
import { User } from "./user.entity";
import { UserDeletionLog } from "./user-deletion-log.entity";
import { EncryptionService } from "../common/encryption.service";
import { PointsModule } from "../points/points.module";

@Module({
  imports: [
    TypeOrmModule.forFeature([User, UserDeletionLog]),
    ConfigModule,
    PointsModule,
  ],
  providers: [UsersService, EncryptionService],
  exports: [UsersService],
})
export class UsersModule {}
