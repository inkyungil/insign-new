import {
  Body,
  Controller,
  Headers,
  HttpCode,
  HttpStatus,
  Post,
  UnauthorizedException,
} from "@nestjs/common";
import { ValidationPipe } from "@nestjs/common/pipes";
import { ApiTags } from "@nestjs/swagger";
import { ApiAuthService } from "./api-auth.service";
import { RegisterDto } from "./dto/register.dto";
import { LoginDto } from "./dto/login.dto";
import { GoogleLoginDto } from "./dto/google-login.dto";
import { DeleteAccountDto } from "./dto/delete-account.dto";
import { ChangePasswordDto } from "./dto/change-password.dto";
import { JwtService } from "@nestjs/jwt";

const validationPipe = new ValidationPipe({
  whitelist: true,
  forbidNonWhitelisted: true,
  transform: true,
});

@Controller("api/auth")
@ApiTags("auth")
export class ApiAuthController {
  constructor(
    private readonly apiAuthService: ApiAuthService,
    private readonly jwtService: JwtService,
  ) {}

  @Post("register")
  async register(@Body(validationPipe) dto: RegisterDto) {
    return this.apiAuthService.register(dto);
  }

  @Post("login")
  @HttpCode(HttpStatus.OK)
  async login(@Body(validationPipe) dto: LoginDto) {
    return this.apiAuthService.login(dto);
  }

  @Post("logout")
  @HttpCode(HttpStatus.NO_CONTENT)
  async logout() {
    await this.apiAuthService.logout();
  }

  @Post("google")
  async loginWithGoogle(@Body(validationPipe) dto: GoogleLoginDto) {
    return this.apiAuthService.loginWithGoogle(dto);
  }

  @Post("delete-account")
  @HttpCode(HttpStatus.NO_CONTENT)
  async deleteAccount(
    @Headers("authorization") authorization: string | undefined,
    @Body(validationPipe) dto: DeleteAccountDto,
  ) {
    const userId = await this.extractUserId(authorization);
    if (!userId) {
      throw new UnauthorizedException("인증이 필요합니다.");
    }

    await this.apiAuthService.deleteAccount(userId, dto);
  }

  @Post("change-password")
  @HttpCode(HttpStatus.NO_CONTENT)
  async changePassword(
    @Headers("authorization") authorization: string | undefined,
    @Body(validationPipe) dto: ChangePasswordDto,
  ) {
    const userId = await this.extractUserId(authorization);
    if (!userId) {
      throw new UnauthorizedException("인증이 필요합니다.");
    }

    await this.apiAuthService.changePassword(userId, dto);
  }

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
}
