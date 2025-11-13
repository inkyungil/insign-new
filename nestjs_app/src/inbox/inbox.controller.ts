import {
  Body,
  Controller,
  Delete,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  UnauthorizedException,
  ValidationPipe,
} from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import { InboxService } from "./inbox.service";
import { CreateInboxMessageDto } from "./dto/create-inbox-message.dto";
import { UpdateInboxReadDto } from "./dto/update-inbox-read.dto";
import { InboxMessageResponseDto } from "./dto/inbox-message-response.dto";

const validationPipe = new ValidationPipe({
  whitelist: true,
  forbidNonWhitelisted: true,
  transform: true,
});

@Controller("api/inbox")
export class InboxController {
  constructor(
    private readonly inboxService: InboxService,
    private readonly jwtService: JwtService,
  ) {}

  private async extractUserId(authorization: string | undefined) {
    if (authorization?.startsWith("Bearer ")) {
      const token = authorization.slice("Bearer ".length);
      try {
        const payload = await this.jwtService.verifyAsync<{ sub: number }>(token);
        return payload?.sub ?? null;
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
    const userId = await this.extractUserId(authorization);
    if (!userId) {
      throw new UnauthorizedException("로그인이 필요합니다.");
    }
    const messages = await this.inboxService.findAllForUser(userId);
    return messages.map(InboxMessageResponseDto.fromEntity);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  async create(
    @Headers("authorization") authorization: string | undefined,
    @Body(validationPipe) dto: CreateInboxMessageDto,
  ) {
    const userId = await this.extractUserId(authorization);
    if (!userId) {
      throw new UnauthorizedException("로그인이 필요합니다.");
    }
    const message = await this.inboxService.createForUser(userId, dto);
    return InboxMessageResponseDto.fromEntity(message);
  }

  @Patch(":id/read")
  async markRead(
    @Headers("authorization") authorization: string | undefined,
    @Param("id", ParseIntPipe) id: number,
    @Body(validationPipe) dto: UpdateInboxReadDto,
  ) {
    const userId = await this.extractUserId(authorization);
    if (!userId) {
      throw new UnauthorizedException("로그인이 필요합니다.");
    }
    const message = await this.inboxService.markRead(id, userId, dto);
    return InboxMessageResponseDto.fromEntity(message);
  }

  @Delete(":id")
  @HttpCode(HttpStatus.NO_CONTENT)
  async remove(
    @Headers("authorization") authorization: string | undefined,
    @Param("id", ParseIntPipe) id: number,
  ) {
    const userId = await this.extractUserId(authorization);
    if (!userId) {
      throw new UnauthorizedException("로그인이 필요합니다.");
    }
    await this.inboxService.remove(id, userId);
  }
}
