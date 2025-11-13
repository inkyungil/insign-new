import { Body, Controller, Headers, Post, UnauthorizedException } from "@nestjs/common";
import { ValidationPipe } from "@nestjs/common/pipes";
import { JwtService } from "@nestjs/jwt";
import { RegisterPushTokenDto } from "./dto/register-push-token.dto";
import { RemovePushTokenDto } from "./dto/remove-push-token.dto";
import { PushTokensService } from "./push-tokens.service";

const validationPipe = new ValidationPipe({
  whitelist: true,
  forbidNonWhitelisted: true,
  transform: true,
});

@Controller("api/push-tokens")
export class PushTokensController {
  constructor(
    private readonly pushTokensService: PushTokensService,
    private readonly jwtService: JwtService,
  ) {}

  private async extractUserId(authorization: string | undefined) {
    if (authorization?.startsWith("Bearer ")) {
      const token = authorization.slice("Bearer ".length);
      try {
        const payload = await this.jwtService.verifyAsync<{ sub: number }>(token);
        return payload?.sub ?? null;
      } catch {
        return null;
      }
    }
    return null;
  }

  @Post()
  async register(
    @Headers("authorization") authorization: string | undefined,
    @Body(validationPipe) dto: RegisterPushTokenDto,
  ) {
    const userId = await this.extractUserId(authorization);
    if (!userId) {
      throw new UnauthorizedException("인증이 필요합니다.");
    }

    await this.pushTokensService.registerToken({
      userId,
      token: dto.token,
      platform: dto.platform,
    });

    return { success: true };
  }

  @Post("remove")
  async remove(
    @Headers("authorization") authorization: string | undefined,
    @Body(validationPipe) dto: RemovePushTokenDto,
  ) {
    const userId = await this.extractUserId(authorization);
    if (!userId) {
      throw new UnauthorizedException("인증이 필요합니다.");
    }

    await this.pushTokensService.removeToken(userId, dto.token);
    return { success: true };
  }
}
