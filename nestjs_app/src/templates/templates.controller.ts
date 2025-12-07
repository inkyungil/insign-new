import {
  Controller,
  Get,
  Headers,
  NotFoundException,
  Param,
  ParseIntPipe,
  Res,
  UnauthorizedException,
} from "@nestjs/common";
import { ApiTags } from "@nestjs/swagger";
import { TemplatesService } from "./templates.service";
import { TemplateResponseDto } from "./dto/template-response.dto";
import { JwtService } from "@nestjs/jwt";
import { Response } from "express";

@Controller("api/templates")
@ApiTags("templates")
export class TemplatesController {
  constructor(
    private readonly templatesService: TemplatesService,
    private readonly jwtService: JwtService,
  ) {}

  private async ensureAuthenticated(authorization: string | undefined) {
    if (authorization?.startsWith("Bearer ")) {
      const token = authorization.slice("Bearer ".length);
      try {
        await this.jwtService.verifyAsync(token);
        return;
      } catch (error) {
        if (error instanceof Error && error.name === "TokenExpiredError") {
          throw new UnauthorizedException(
            "로그인 세션이 만료되었습니다. 다시 로그인해 주세요.",
          );
        }

        throw new UnauthorizedException("유효하지 않은 인증 토큰입니다.");
      }
    }

    throw new UnauthorizedException("로그인이 필요합니다.");
  }

  @Get()
  async list(@Headers("authorization") authorization: string | undefined) {
    await this.ensureAuthenticated(authorization);
    const templates = await this.templatesService.findAllActive();
    return templates.map(TemplateResponseDto.fromEntity);
  }

  @Get("default/id")
  async getDefaultTemplateId(
    @Headers("authorization") authorization: string | undefined,
  ) {
    await this.ensureAuthenticated(authorization);
    const templateId = await this.templatesService.getDefaultTemplateId();
    if (!templateId) {
      throw new NotFoundException("기본 템플릿을 찾을 수 없습니다.");
    }
    return { defaultTemplateId: templateId };
  }

  @Get(":id")
  async detail(
    @Headers("authorization") authorization: string | undefined,
    @Param("id", ParseIntPipe) id: number,
  ) {
    await this.ensureAuthenticated(authorization);
    const template = await this.templatesService.findOne(id);
    if (!template) {
      throw new NotFoundException("템플릿을 찾을 수 없습니다.");
    }
    return TemplateResponseDto.fromEntity(template);
  }

  @Get(":id/preview-pdf")
  async previewPdf(
    @Headers("authorization") authorization: string | undefined,
    @Param("id", ParseIntPipe) id: number,
    @Res() res: Response,
  ) {
    await this.ensureAuthenticated(authorization);

    const pdfBuffer = await this.templatesService.generatePreviewPdf(id);
    if (!pdfBuffer) {
      throw new NotFoundException("템플릿을 찾을 수 없습니다.");
    }

    res.setHeader("Content-Type", "application/pdf");
    res.setHeader(
      "Content-Disposition",
      'inline; filename="template-preview.pdf"',
    );
    res.send(pdfBuffer);
  }
}
