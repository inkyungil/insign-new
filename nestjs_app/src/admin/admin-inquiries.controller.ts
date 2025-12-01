import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Render,
  Req,
  UseGuards,
  Redirect,
} from "@nestjs/common";
import { ApiExcludeController } from "@nestjs/swagger";
import { Request } from "express";
import { AuthenticatedGuard } from "../auth/authenticated.guard";
import { InquiriesService } from "../inquiries/inquiries.service";
import { ADMIN_ROUTE_PREFIX } from "./admin.constants";
import { InquiryStatus } from "../inquiries/inquiry.entity";
import { EncryptionService } from "../common/encryption.service";

function formatDate(value?: Date | null): string {
  if (!value) {
    return "-";
  }
  return new Date(value).toISOString().replace("T", " ").slice(0, 19);
}

function getCategoryLabel(category: string): string {
  const labels: Record<string, string> = {
    contract: "계약 관련",
    payment: "결제/포인트",
    account: "계정/로그인",
    technical: "기술 지원",
    other: "기타",
  };
  return labels[category] || category;
}

function getStatusLabel(status: string): string {
  const labels: Record<string, string> = {
    pending: "대기 중",
    in_progress: "처리 중",
    answered: "답변 완료",
    closed: "종료",
  };
  return labels[status] || status;
}

function getStatusBadgeClass(status: string): string {
  const classes: Record<string, string> = {
    pending: "badge-warning",
    in_progress: "badge-info",
    answered: "badge-success",
    closed: "badge-secondary",
  };
  return classes[status] || "badge-secondary";
}

@Controller(`${ADMIN_ROUTE_PREFIX}/inquiries`)
@ApiExcludeController()
@UseGuards(AuthenticatedGuard)
export class AdminInquiriesController {
  constructor(
    private readonly inquiriesService: InquiriesService,
    private readonly encryptionService: EncryptionService,
  ) {}

  @Get()
  @Render("admin/inquiries/index")
  async index(@Req() request: Request, @Query("page") page?: string) {
    const currentPage = page ? parseInt(page, 10) : 1;
    const [inquiries, total] = await this.inquiriesService.findAll(
      currentPage,
      20,
    );

    return {
      user: request.user,
      inquiries: inquiries.map((inquiry) => ({
        ...inquiry,
        user: inquiry.user
          ? {
              ...inquiry.user,
              email: this.encryptionService.decrypt(inquiry.user.email),
            }
          : null,
        categoryLabel: getCategoryLabel(inquiry.category),
        statusLabel: getStatusLabel(inquiry.status),
        statusBadgeClass: getStatusBadgeClass(inquiry.status),
        createdAtFormatted: formatDate(inquiry.createdAt),
        answeredAtFormatted: formatDate(inquiry.answeredAt),
      })),
      currentPage,
      totalPages: Math.ceil(total / 20),
      total,
    };
  }

  @Get(":id")
  @Render("admin/inquiries/detail")
  async detail(@Req() request: Request, @Param("id") id: string) {
    const inquiry = await this.inquiriesService.findOne(+id);

    return {
      user: request.user,
      inquiry: {
        ...inquiry,
        user: inquiry.user
          ? {
              ...inquiry.user,
              email: this.encryptionService.decrypt(inquiry.user.email),
            }
          : null,
        categoryLabel: getCategoryLabel(inquiry.category),
        statusLabel: getStatusLabel(inquiry.status),
        statusBadgeClass: getStatusBadgeClass(inquiry.status),
        createdAtFormatted: formatDate(inquiry.createdAt),
        answeredAtFormatted: formatDate(inquiry.answeredAt),
      },
      statuses: Object.values(InquiryStatus),
      getStatusLabel,
    };
  }

  @Post(":id/status")
  @Redirect("back")
  async updateStatus(
    @Param("id") id: string,
    @Body("status") status: InquiryStatus,
    @Body("adminNote") adminNote?: string,
  ) {
    await this.inquiriesService.updateStatus(+id, { status, adminNote });
    return {};
  }

  @Post(":id/respond")
  @Redirect("back")
  async respond(
    @Param("id") id: string,
    @Body("message") message: string,
  ) {
    await this.inquiriesService.sendResponse(+id, { message });
    return {};
  }
}
