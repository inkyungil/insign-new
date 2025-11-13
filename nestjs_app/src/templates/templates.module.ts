import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { Template } from "./template.entity";
import { TemplatesService } from "./templates.service";
import { TemplatesController } from "./templates.controller";
import { DocxTemplateService } from "./docx-template.service";
import { PdfConverterService } from "./pdf-converter.service";
import { HtmlPdfService } from "./html-pdf.service";
import { JwtModule } from "@nestjs/jwt";
import { ConfigModule, ConfigService } from "@nestjs/config";

@Module({
  imports: [
    TypeOrmModule.forFeature([Template]),
    ConfigModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (config: ConfigService) => ({
        secret: config.get<string>("JWT_SECRET", "dev-secret"),
      }),
    }),
  ],
  providers: [
    TemplatesService,
    DocxTemplateService,
    PdfConverterService,
    HtmlPdfService,
  ],
  controllers: [TemplatesController],
  exports: [
    TemplatesService,
    DocxTemplateService,
    PdfConverterService,
    HtmlPdfService,
  ],
})
export class TemplatesModule {}
