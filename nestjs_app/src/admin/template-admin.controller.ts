import {
  BadRequestException,
  Body,
  Controller,
  Get,
  NotFoundException,
  Param,
  ParseIntPipe,
  Post,
  Redirect,
  Render,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from "@nestjs/common";
import { FileInterceptor } from "@nestjs/platform-express";
import { ApiExcludeController } from "@nestjs/swagger";
import { Request } from "express";
import { diskStorage } from "multer";
import { extname, join } from "path";
import { TemplatesService } from "../templates/templates.service";
import { AuthenticatedGuard } from "../auth/authenticated.guard";
import {
  TemplateFormSchema,
  isTemplateFormSchema,
} from "../templates/template-form.types";
import { ADMIN_BASE_PATH, ADMIN_ROUTE_PREFIX } from "./admin.constants";

@Controller(`${ADMIN_ROUTE_PREFIX}/templates`)
@ApiExcludeController()
@UseGuards(AuthenticatedGuard)
export class TemplateAdminController {
  constructor(private readonly templatesService: TemplatesService) {}

  @Get()
  @Render("admin/templates/index")
  async list(@Req() request: Request) {
    const templates = await this.templatesService.findAll();
    return { templates, user: request.user };
  }

  @Get("new")
  @Render("admin/templates/new")
  newForm(@Req() request: Request) {
    return { user: request.user };
  }

  @Post("create")
  @UseInterceptors(
    FileInterceptor("templateFile", {
      storage: diskStorage({
        destination: join(process.cwd(), "public", "templates"),
        filename: (req, file, callback) => {
          const uniqueSuffix = Date.now() + "-" + Math.round(Math.random() * 1e9);
          const ext = extname(file.originalname);
          callback(null, `template-${uniqueSuffix}${ext}`);
        },
      }),
      fileFilter: (req, file, callback) => {
        if (file.mimetype === "application/vnd.openxmlformats-officedocument.wordprocessingml.document") {
          callback(null, true);
        } else {
          callback(new BadRequestException("DOCX 파일만 업로드 가능합니다."), false);
        }
      },
      limits: {
        fileSize: 10 * 1024 * 1024, // 10MB
      },
    }),
  )
  @Redirect(`${ADMIN_BASE_PATH}/templates`, 302)
  async create(
    @Body("name") name: string,
    @Body("category") category: string,
    @Body("description") description: string,
    @Body("formSchema") rawFormSchema: string,
    @Body("samplePayload") rawSamplePayload: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    if (!file) {
      throw new BadRequestException("템플릿 파일을 업로드해주세요.");
    }

    const { formSchema, samplePayload } = this.parseSchemaPayload(
      rawFormSchema,
      rawSamplePayload,
    );

    // DOCX 파일 업로드 시에는 content가 null이므로 검증 건너뜀
    // (추후 DOCX 파일 파싱 후 검증 가능)

    await this.templatesService.createTemplate({
      name: name?.trim() ?? "",
      category: category?.trim() ?? "",
      description: description?.trim() ?? "",
      content: null,
      filePath: `/templates/${file.filename}`,
      fileName: file.filename,
      originalFileName: file.originalname,
      formSchema: formSchema ?? null,
      samplePayload: samplePayload ?? null,
    });
  }

  @Get(":id/edit")
  @Render("admin/templates/edit")
  async editForm(
    @Req() request: Request,
    @Param("id", ParseIntPipe) id: number,
  ) {
    const template = await this.templatesService.findOne(id);
    if (!template) {
      throw new NotFoundException("템플릿을 찾을 수 없습니다.");
    }
    return { template, user: request.user };
  }

  @Post(":id/update")
  @UseInterceptors(
    FileInterceptor("templateFile", {
      storage: diskStorage({
        destination: join(process.cwd(), "public", "templates"),
        filename: (req, file, callback) => {
          const uniqueSuffix = Date.now() + "-" + Math.round(Math.random() * 1e9);
          const ext = extname(file.originalname);
          callback(null, `template-${uniqueSuffix}${ext}`);
        },
      }),
      fileFilter: (req, file, callback) => {
        if (file.mimetype === "application/vnd.openxmlformats-officedocument.wordprocessingml.document") {
          callback(null, true);
        } else {
          callback(new BadRequestException("DOCX 파일만 업로드 가능합니다."), false);
        }
      },
      limits: {
        fileSize: 10 * 1024 * 1024, // 10MB
      },
    }),
  )
  @Redirect(`${ADMIN_BASE_PATH}/templates`, 302)
  async update(
    @Param("id", ParseIntPipe) id: number,
    @Body("name") name: string,
    @Body("category") category: string,
    @Body("description") description: string,
    @Body("isActive") isActiveRaw: string,
    @Body("content") bodyContent: string,
    @Body("formSchema") rawFormSchema: string,
    @Body("samplePayload") rawSamplePayload: string,
    @UploadedFile() file: Express.Multer.File | undefined,
  ) {
    // 디버깅: 받은 content 데이터 로깅
    console.log('[DEBUG] Template Update - ID:', id);
    console.log('[DEBUG] Content length:', bodyContent?.length ?? 0);
    console.log('[DEBUG] Content preview:', bodyContent?.substring(0, 200) ?? 'empty');
    console.log('[DEBUG] File uploaded:', !!file);
    const { formSchema, samplePayload } = this.parseSchemaPayload(
      rawFormSchema,
      rawSamplePayload,
    );

    const updatePayload: {
      name: string;
      category: string;
      description: string;
      isActive?: boolean;
      content?: string | null;
      filePath?: string | null;
      fileName?: string | null;
      originalFileName?: string | null;
      formSchema?: TemplateFormSchema | null;
      samplePayload?: Record<string, unknown> | null;
    } = {
      name: name?.trim() ?? "",
      category: category?.trim() ?? "",
      description: description?.trim() ?? "",
    };

    if (typeof isActiveRaw === "string") {
      updatePayload.isActive = isActiveRaw === "true";
    }

    // 새 파일이 업로드된 경우
    if (file) {
      updatePayload.filePath = `/templates/${file.filename}`;
      updatePayload.fileName = file.filename;
      updatePayload.originalFileName = file.originalname;
      updatePayload.content = null; // DOCX 사용 시 content는 null
    } else {
      updatePayload.content = bodyContent?.trim().length ? bodyContent.trim() : null;
    }

    if (formSchema !== undefined) {
      updatePayload.formSchema = formSchema;
    }
    if (samplePayload !== undefined) {
      updatePayload.samplePayload = samplePayload;
    }

    // content가 있고 formSchema가 있을 때만 플레이스홀더 검증
    if (updatePayload.content && formSchema) {
      const validation = this.templatesService.validateTemplatePlaceholders(
        updatePayload.content,
        formSchema,
      );
      if (!validation.valid && validation.missingFields) {
        throw new BadRequestException(
          `템플릿 본문에 정의되지 않은 필드가 사용되었습니다: ${validation.missingFields.join(', ')}. formSchema에 해당 필드를 추가하거나 본문에서 제거해주세요.`,
        );
      }
    }

    // 디버깅: 업데이트할 payload 로깅
    console.log('[DEBUG] Update payload content length:', updatePayload.content?.length ?? 0);
    console.log('[DEBUG] Update payload content preview:', updatePayload.content?.substring(0, 200) ?? 'null');

    const updated = await this.templatesService.updateTemplate(id, updatePayload);

    if (!updated) {
      throw new NotFoundException("템플릿을 찾을 수 없습니다.");
    }

    console.log('[DEBUG] Template updated successfully. New content length:', updated.content?.length ?? 0);
  }

  @Post(":id/toggle-active")
  @Redirect(`${ADMIN_BASE_PATH}/templates`, 302)
  async toggleActive(@Param("id", ParseIntPipe) id: number) {
    const updated = await this.templatesService.toggleTemplateActive(id);
    if (!updated) {
      throw new NotFoundException("템플릿을 찾을 수 없습니다.");
    }
  }

  @Post(":id/delete")
  @Redirect(`${ADMIN_BASE_PATH}/templates`, 302)
  async delete(@Param("id", ParseIntPipe) id: number) {
    await this.templatesService.deleteTemplate(id);
  }

  private parseSchemaPayload(
    rawFormSchema: string,
    rawSamplePayload: string,
  ): {
    formSchema?: TemplateFormSchema | null;
    samplePayload?: Record<string, unknown> | null;
  } {
    const trimmedSchema = rawFormSchema?.trim() ?? "";
    let formSchema: TemplateFormSchema | null | undefined = undefined;

    if (trimmedSchema) {
      try {
        const parsed = JSON.parse(trimmedSchema);
        if (!isTemplateFormSchema(parsed)) {
          throw new Error("invalid schema");
        }
        formSchema = parsed;
      } catch (error) {
        throw new BadRequestException("폼 스키마가 올바르지 않습니다.");
      }
    }

    const trimmedSample = rawSamplePayload?.trim() ?? "";
    let samplePayload: Record<string, unknown> | null | undefined = undefined;
    if (trimmedSample) {
      try {
        const parsed = JSON.parse(trimmedSample);
        if (parsed && typeof parsed === "object") {
          samplePayload = parsed as Record<string, unknown>;
        }
      } catch (error) {
        throw new BadRequestException("샘플 데이터가 올바르지 않습니다.");
      }
    }

    return { formSchema, samplePayload };
  }
}
