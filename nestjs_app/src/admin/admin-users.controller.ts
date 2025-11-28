import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Query,
  Render,
  Req,
  UseGuards,
  ValidationPipe,
} from "@nestjs/common";
import { ApiExcludeController } from "@nestjs/swagger";
import { Request } from "express";
import { AuthenticatedGuard } from "../auth/authenticated.guard";
import { UsersService } from "../users/users.service";
import { User } from "../users/user.entity";
import { PushTokensService } from "../push-tokens/push-tokens.service";
import { UserPushToken } from "../push-tokens/push-token.entity";
import { SendPushMessageDto } from "../push-tokens/dto/send-push-message.dto";
import { ADMIN_ROUTE_PREFIX } from "./admin.constants";

function formatDate(value?: Date | null) {
  if (!value) {
    return "-";
  }
  return new Date(value).toISOString().replace("T", " ").slice(0, 19);
}

function mapPushTokens(tokens: UserPushToken[]) {
  return tokens.map((token) => ({
    id: token.id,
    token: token.token,
    platform: token.platform ?? "-",
    createdAt: formatDate(token.createdAt),
    updatedAt: formatDate(token.updatedAt),
    lastSeenAt: formatDate(token.lastSeenAt ?? null),
  }));
}

function summarizeUser(user: User, pushTokenCount = 0) {
  return {
    id: user.id,
    email: user.email,
    displayName: user.displayName ?? "-",
    provider: user.provider,
    providerLabel: user.provider === "google" ? "Google" : "일반",
    isActive: user.isActive,
    createdAt: formatDate(user.createdAt),
    lastLoginAt: formatDate(user.lastLoginAt ?? null),
    pushTokenCount,
  };
}

function detailUser(user: User, tokens: UserPushToken[]) {
  return {
    ...summarizeUser(user, tokens.length),
    avatarUrl: user.avatarUrl ?? null,
    googleId: user.googleId ?? null,
    updatedAt: formatDate(user.updatedAt),
    pushTokens: mapPushTokens(tokens),
  };
}

@Controller(`${ADMIN_ROUTE_PREFIX}/users`)
@ApiExcludeController()
@UseGuards(AuthenticatedGuard)
export class AdminUsersController {
  constructor(
    private readonly usersService: UsersService,
    private readonly pushTokensService: PushTokensService,
  ) {}

  @Get()
  @Render("admin/users")
  async index(@Req() request: Request) {
    const users = await this.usersService.findAllUsers();
    const counts = await this.pushTokensService.countTokensByUserIds(
      users.map((user) => user.id),
    );

    return {
      user: request.user,
      users: users.map((item) =>
        summarizeUser(item, counts.get(item.id) ?? 0),
      ),
    };
  }

  @Get(":id/json")
  async detailJson(@Param("id", ParseIntPipe) id: number) {
    const [selected, tokens] = await Promise.all([
      this.usersService.findOneById(id),
      this.pushTokensService.findTokensByUserId(id),
    ]);
    return detailUser(selected, tokens);
  }

  @Post(":id/password")
  async updatePassword(
    @Param("id", ParseIntPipe) id: number,
    @Body("password") password?: string,
  ) {
    if (!password || password.trim().length < 8) {
      throw new BadRequestException("비밀번호는 8자 이상 입력해 주세요.");
    }

    await this.usersService.updateUserPassword(id, password.trim());
    return { message: "비밀번호가 변경되었습니다." };
  }

  @Post(":id/push")
  async sendPushMessage(
    @Param("id", ParseIntPipe) id: number,
    @Body(new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }))
    dto: SendPushMessageDto,
  ) {
    const trimmed = {
      category: dto.category,
      title: dto.title.trim(),
      body: dto.body.trim(),
    };

    if (!trimmed.title || !trimmed.body) {
      throw new BadRequestException("제목과 메시지를 모두 입력하세요.");
    }

    await this.pushTokensService.sendPushMessage(id, trimmed);
    return { message: "푸시 메시지를 발송했습니다." };
  }
}
