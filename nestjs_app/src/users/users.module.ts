import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { UsersService } from "./users.service";
import { User } from "./user.entity";
import { UserDeletionLog } from "./user-deletion-log.entity";
import { EncryptionService } from "../common/encryption.service";

@Module({
  imports: [TypeOrmModule.forFeature([User, UserDeletionLog])],
  providers: [UsersService, EncryptionService],
  exports: [UsersService],
})
export class UsersModule {}
