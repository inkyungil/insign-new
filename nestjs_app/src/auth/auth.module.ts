import { Module } from "@nestjs/common";
import { PassportModule } from "@nestjs/passport";
import { TypeOrmModule } from "@nestjs/typeorm";
import { Admin } from "../admin/admin.entity";
import { AuthService } from "./auth.service";
import { LocalStrategy } from "./local.strategy";
import { SessionSerializer } from "./session.serializer";
import { AuthController } from "./auth.controller";
import { LocalAuthGuard } from "./local-auth.guard";
import { AuthenticatedGuard } from "./authenticated.guard";

@Module({
  imports: [
    PassportModule.register({ session: true }),
    TypeOrmModule.forFeature([Admin]),
  ],
  controllers: [AuthController],
  providers: [
    AuthService,
    LocalStrategy,
    SessionSerializer,
    LocalAuthGuard,
    AuthenticatedGuard,
  ],
  exports: [AuthenticatedGuard],
})
export class AuthModule {}
