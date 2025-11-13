import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Query,
  Redirect,
  Render,
  Req,
  UseGuards,
} from "@nestjs/common";
import { ApiExcludeController } from "@nestjs/swagger";
import { Request } from "express";
import { URLSearchParams } from "url";
import { AuthenticatedGuard } from "../auth/authenticated.guard";
import { InboxService } from "../inbox/inbox.service";
import { UsersService } from "../users/users.service";
import { InboxMessageKind } from "../inbox/inbox-message.entity";
import { ADMIN_BASE_PATH, ADMIN_ROUTE_PREFIX } from "./admin.constants";

const KIND_LABELS: Record<InboxMessageKind, string> = {
  notice: "공지",
  alert: "알림",
  news: "뉴스",
  report: "리포트",
  system: "시스템",
};

const KIND_BADGES: Record<InboxMessageKind, string> = {
  notice: "badge-info",
  alert: "badge-warning",
  news: "badge-primary",
  report: "badge-success",
  system: "badge-danger",
};

function normalizeAudience(value?: string): "all" | "single" {
  return value === "single" ? "single" : "all";
}

function formatDateTime(value?: Date | null) {
  if (!value) {
    return "-";
  }
  return new Date(value).toISOString().replace("T", " ").slice(0, 19);
}

function summarizeBody(body: string) {
  if (!body) {
    return "";
  }
  return body.length > 80 ? `${body.slice(0, 80)}…` : body;
}

function normalizeKind(value: string | undefined): InboxMessageKind | "all" {
  if (!value) {
    return "all";
  }
  const normalized = value.toLowerCase() as InboxMessageKind;
  return normalized in KIND_LABELS ? normalized : "all";
}

function normalizeStatus(value: string | undefined): "all" | "read" | "unread" {
  if (!value) {
    return "all";
  }
  const normalized = value.toLowerCase();
  if (normalized === "read" || normalized === "unread") {
    return normalized;
  }
  return "all";
}

@Controller(`${ADMIN_ROUTE_PREFIX}/inbox`)
@ApiExcludeController()
@UseGuards(AuthenticatedGuard)
export class AdminInboxController {
  constructor(
    private readonly inboxService: InboxService,
    private readonly usersService: UsersService,
  ) {}

  @Get()
  @Render("admin/inbox")
  async index(
    @Req() request: Request,
    @Query("search") search?: string,
    @Query("kind") rawKind?: string,
    @Query("status") rawStatus?: string,
    @Query("flash") flashCode?: string,
    @Query("error") errorMessage?: string,
  ) {
    const kindFilter = normalizeKind(rawKind);
    const readFilter = normalizeStatus(rawStatus);
    const trimmedSearch = search?.trim() ?? "";

    const [messages, summary, activeUserCount] = await Promise.all([
      this.inboxService.findAllForAdmin({
        search: trimmedSearch || undefined,
        kind: kindFilter,
        isRead: readFilter,
        limit: 200,
      }),
      this.inboxService.countSummary(),
      this.usersService.countActiveUsers(),
    ]);

    const formattedMessages = messages.map((message) => ({
      id: message.id,
      userEmail: message.user?.email ?? "-",
      userName: message.user?.displayName ?? "-",
      kind: message.kind,
      kindLabel: KIND_LABELS[message.kind] ?? message.kind,
      kindBadgeClass: KIND_BADGES[message.kind] ?? "badge-secondary",
      title: message.title,
      bodyPreview: summarizeBody(message.body),
      tags: Array.isArray(message.tags) ? message.tags : [],
      isRead: Boolean(message.isRead),
      readAt: formatDateTime(message.readAt ?? null),
      createdAt: formatDateTime(message.createdAt),
      metadata: message.metadata ?? null,
    }));

    const successMessage = this.resolveSuccessMessage(
      flashCode,
      request.query as Record<string, unknown>,
    );
    const normalizedError = errorMessage && errorMessage.trim().length ? errorMessage : null;

    const inboxPath = `${ADMIN_BASE_PATH}/inbox`;
    const currentUrl = request.originalUrl?.startsWith(inboxPath)
      ? request.originalUrl
      : inboxPath;

    return {
      user: request.user,
      messages: formattedMessages,
      summary,
      filters: {
        search: trimmedSearch,
        kind: kindFilter,
        status: readFilter,
      },
      kindOptions: [
        { value: "all", label: "전체" },
        ...Object.entries(KIND_LABELS).map(([value, label]) => ({ value, label })),
      ],
      statusOptions: [
        { value: "all", label: "전체" },
        { value: "unread", label: "읽지 않음" },
        { value: "read", label: "읽음" },
      ],
      flashMessage: successMessage,
      errorMessage: normalizedError,
      currentUrl,
      activeUserCount,
      activeUserCountLabel: activeUserCount.toLocaleString("ko-KR"),
    };
  }

  @Post("send")
  @Redirect()
  async send(
    @Body("email") email: string,
    @Body("audience") rawAudience: string,
    @Body("kind") rawKind: string,
    @Body("title") title: string,
    @Body("body") body: string,
    @Body("tags") rawTags?: string,
    @Body("metadata") rawMetadata?: string,
    @Body("redirectTo") redirectTo?: string,
  ) {
    const redirectUrl = this.buildRedirectUrl(redirectTo);

    try {
      const normalizedKind = normalizeKind(rawKind);
      if (normalizedKind === "all") {
        throw new BadRequestException("메시지 유형을 선택해 주세요.");
      }

      const normalizedTitle = title?.trim() ?? "";
      const normalizedBody = body?.trim() ?? "";

      if (!normalizedTitle) {
        throw new BadRequestException("제목을 입력해 주세요.");
      }

      if (!normalizedBody) {
        throw new BadRequestException("메시지 내용을 입력해 주세요.");
      }

      const audience = normalizeAudience(rawAudience);

      const tags = (rawTags ?? "")
        .split(",")
        .map((tag) => tag.trim())
        .filter((tag) => Boolean(tag));

      const metadata = this.parseMetadata(rawMetadata);
      const payload = {
        kind: normalizedKind as InboxMessageKind,
        title: normalizedTitle,
        body: normalizedBody,
        tags,
        metadata,
      };

      if (audience === "all") {
        const activeUsers = await this.usersService.findActiveUsers();
        if (!activeUsers.length) {
          throw new BadRequestException(
            "발송할 활성 사용자를 찾을 수 없습니다.",
          );
        }
        await this.inboxService.createForUsers(
          activeUsers.map((user) => user.id),
          payload,
        );

        return {
          url: this.withStatus(redirectUrl, {
            flash: "sent_all",
            count: String(activeUsers.length),
          }),
        };
      }

      if (!email || !email.trim()) {
        throw new BadRequestException("수신자 이메일을 입력해 주세요.");
      }

      const user = await this.usersService.findByEmailIncludingInactive(email);
      if (!user) {
        throw new BadRequestException("입력한 이메일의 사용자를 찾을 수 없습니다.");
      }

      await this.inboxService.createForUser(user.id, payload);

      return {
        url: this.withStatus(redirectUrl, {
          flash: "sent_single",
          recipient: user.email,
        }),
      };
    } catch (error) {
      const message = this.extractErrorMessage(error, "메시지를 발송하지 못했습니다.");
      return {
        url: this.withStatus(redirectUrl, { flash: "error", error: message }),
      };
    }
  }

  @Post(":id/read")
  @Redirect()
  async updateReadState(
    @Param("id", ParseIntPipe) id: number,
    @Body("isRead") isReadRaw: string,
    @Body("redirectTo") redirectTo?: string,
  ) {
    const redirectUrl = this.buildRedirectUrl(redirectTo);

    try {
      const normalized = this.parseBoolean(isReadRaw);
      await this.inboxService.setReadState(id, normalized);
      return {
        url: this.withStatus(redirectUrl, { flash: "updated" }),
      };
    } catch (error) {
      const message = this.extractErrorMessage(error, "읽음 상태를 변경하지 못했습니다.");
      return {
        url: this.withStatus(redirectUrl, { flash: "error", error: message }),
      };
    }
  }

  @Post(":id/delete")
  @Redirect()
  async delete(
    @Param("id", ParseIntPipe) id: number,
    @Body("redirectTo") redirectTo?: string,
  ) {
    const redirectUrl = this.buildRedirectUrl(redirectTo);

    try {
      await this.inboxService.removeById(id);
      return {
        url: this.withStatus(redirectUrl, { flash: "deleted" }),
      };
    } catch (error) {
      const message = this.extractErrorMessage(error, "메시지를 삭제하지 못했습니다.");
      return {
        url: this.withStatus(redirectUrl, { flash: "error", error: message }),
      };
    }
  }

  private parseMetadata(rawMetadata?: string) {
    if (!rawMetadata || !rawMetadata.trim()) {
      return null;
    }

    const trimmed = rawMetadata.trim();
    try {
      const parsed = JSON.parse(trimmed);
      if (parsed && typeof parsed === "object") {
        return parsed as Record<string, unknown>;
      }
      throw new Error("metadata must be object");
    } catch (error) {
      throw new BadRequestException("메타데이터는 올바른 JSON 형식이어야 합니다.");
    }
  }

  private parseBoolean(value: string | undefined): boolean {
    const normalized = (value ?? "").toLowerCase();
    return ["true", "1", "yes", "y", "on"].includes(normalized);
  }

  private buildRedirectUrl(redirectTo?: string) {
    if (redirectTo && redirectTo.startsWith(`${ADMIN_BASE_PATH}/inbox`)) {
      return redirectTo;
    }
    return `${ADMIN_BASE_PATH}/inbox`;
  }

  private withStatus(url: string, params: Record<string, string>) {
    const [path, queryString] = url.split("?");
    const searchParams = new URLSearchParams(queryString ?? "");
    ["flash", "error", "count", "recipient"].forEach((key) =>
      searchParams.delete(key),
    );

    Object.entries(params).forEach(([key, value]) => {
      if (value === undefined || value === null) {
        searchParams.delete(key);
      } else {
        searchParams.set(key, value);
      }
    });

    const query = searchParams.toString();
    return query ? `${path}?${query}` : path;
  }

  private resolveSuccessMessage(
    code?: string,
    params?: Record<string, unknown>,
  ) {
    if (!code || code === "error") {
      return null;
    }

    const extractParam = (key: string) => {
      const value = params?.[key];
      if (Array.isArray(value)) {
        return typeof value[0] === "string" ? value[0] : undefined;
      }
      return typeof value === "string" ? value : undefined;
    };

    switch (code) {
      case "sent_single": {
        const recipient = extractParam("recipient");
        return recipient
          ? `${recipient} 사용자에게 메시지를 발송했습니다.`
          : "선택한 사용자에게 메시지를 발송했습니다.";
      }
      case "sent_all": {
        const countParam = extractParam("count");
        const count = countParam ? Number(countParam) : NaN;
        const label = Number.isFinite(count)
          ? count.toLocaleString("ko-KR")
          : "여러";
        return `활성 사용자 ${label}명에게 메시지를 발송했습니다.`;
      }
      case "deleted":
        return "메시지를 삭제했습니다.";
      case "updated":
        return "읽음 상태를 변경했습니다.";
      default:
        return null;
    }
  }

  private extractErrorMessage(error: unknown, fallback: string) {
    if (error instanceof BadRequestException) {
      const response = error.getResponse();
      if (typeof response === "string") {
        return response;
      }
      if (response && typeof response === "object" && "message" in response) {
        const payload = (response as { message?: unknown }).message;
        if (Array.isArray(payload)) {
          return payload.join(", ");
        }
        if (typeof payload === "string") {
          return payload;
        }
      }
      return fallback;
    }
    return fallback;
  }
}
