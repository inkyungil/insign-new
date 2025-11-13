import { Module } from "@nestjs/common";
import { ConfigModule, ConfigService } from "@nestjs/config";
import { TypeOrmModule } from "@nestjs/typeorm";
import { PassportModule } from "@nestjs/passport";
import { AppController } from "./app.controller";
import { AppService } from "./app.service";
import { AdminModule } from "./admin/admin.module";
import { AuthModule } from "./auth/auth.module";
import { Admin } from "./admin/admin.entity";
import { User } from "./users/user.entity";
import { Template } from "./templates/template.entity";
import { Contract } from "./contracts/contract.entity";
import { ContractMailLog } from "./contracts/contract-mail-log.entity";
import { InboxMessage } from "./inbox/inbox-message.entity";
import { Policy } from "./policies/policy.entity";
import { UsersModule } from "./users/users.module";
import { ApiAuthModule } from "./api-auth/api-auth.module";
import { TemplatesModule } from "./templates/templates.module";
import { ContractsModule } from "./contracts/contracts.module";
import { MailModule } from "./mail/mail.module";
import { InboxModule } from "./inbox/inbox.module";
import { PoliciesModule } from "./policies/policies.module";
import { PushTokensModule } from "./push-tokens/push-tokens.module";
import { UserPushToken } from "./push-tokens/push-token.entity";
import { UserDeletionLog } from "./users/user-deletion-log.entity";

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        type: "mysql",
        host: config.get<string>("DB_HOST", "localhost"),
        port: Number(config.get<string>("DB_PORT", "3306")),
        username: config.get<string>("DB_USERNAME", "root"),
        password: config.get<string>("DB_PASSWORD", ""),
        database: config.get<string>("DB_NAME", "insign"),
        entities: [
          Admin,
          User,
          Template,
          Contract,
          ContractMailLog,
          InboxMessage,
          Policy,
          UserPushToken,
          UserDeletionLog,
        ],
        synchronize: config.get("DB_SYNCHRONIZE", "true") !== "false",
      }),
    }),
    PassportModule.register({ session: true }),
    AuthModule,
    AdminModule,
    UsersModule,
    ApiAuthModule,
    TemplatesModule,
    ContractsModule,
    MailModule,
    InboxModule,
    PoliciesModule,
    PushTokensModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
