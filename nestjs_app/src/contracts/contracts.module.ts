import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { JwtModule } from "@nestjs/jwt";
import { ConfigModule, ConfigService } from "@nestjs/config";
import { Contract } from "./contract.entity";
import { ContractMailLog } from "./contract-mail-log.entity";
import { ContractsService } from "./contracts.service";
import { ContractsController } from "./contracts.controller";
import { ContractPdfService } from "./contract-pdf.service";
import { MailModule } from "../mail/mail.module";
import { TemplatesModule } from "../templates/templates.module";
import { Template } from "../templates/template.entity";
import { EncryptionService } from "../common/encryption.service";
import { PushTokensModule } from "../push-tokens/push-tokens.module";
import { BlockchainModule } from "../blockchain/blockchain.module";
import { InboxModule } from "../inbox/inbox.module";
import { UsersModule } from "../users/users.module";

@Module({
  imports: [
    TypeOrmModule.forFeature([Contract, ContractMailLog, Template]),
    ConfigModule,
    MailModule,
    TemplatesModule,
    PushTokensModule,
    BlockchainModule,
    InboxModule,
    UsersModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.get<string>("JWT_SECRET", "dev-secret"),
      }),
    }),
  ],
  providers: [ContractsService, ContractPdfService, EncryptionService],
  controllers: [ContractsController],
  exports: [ContractsService, ContractPdfService],
})
export class ContractsModule {}
