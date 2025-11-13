import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { Admin } from "./admin.entity";
import { AdminService } from "./admin.service";
import { AdminController } from "./admin.controller";
import { TemplateAdminController } from "./template-admin.controller";
import { AuthModule } from "../auth/auth.module";
import { TemplatesModule } from "../templates/templates.module";
import { UsersModule } from "../users/users.module";
import { ContractsModule } from "../contracts/contracts.module";
import { InboxModule } from "../inbox/inbox.module";
import { PoliciesModule } from "../policies/policies.module";
import { AdminInboxController } from "./admin-inbox.controller";
import { AdminUsersController } from "./admin-users.controller";
import { AdminContractsController } from "./admin-contracts.controller";
import { AdminPoliciesController } from "./admin-policies.controller";
import { PushTokensModule } from "../push-tokens/push-tokens.module";

@Module({
  imports: [
    TypeOrmModule.forFeature([Admin]),
    AuthModule,
    TemplatesModule,
    UsersModule,
    ContractsModule,
    InboxModule,
    PoliciesModule,
    PushTokensModule,
  ],
  providers: [AdminService],
  controllers: [
    AdminController,
    TemplateAdminController,
    AdminUsersController,
    AdminContractsController,
    AdminInboxController,
    AdminPoliciesController,
  ],
  exports: [AdminService],
})
export class AdminModule {}
