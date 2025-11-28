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
import { VerifyEmailDto } from "./dto/verify-email.dto";
import { ResendVerificationDto } from "./dto/resend-verification.dto";
import { CompleteRegistrationDto } from "./dto/complete-registration.dto";
import { JwtService } from "@nestjs/jwt";
import { UsersService } from "../users/users.service";
import { PointsService } from "src/points/points.service";
import { Get, Query, ParseIntPipe } from "@nestjs/common";

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
    private readonly usersService: UsersService,
    private readonly pointsService: PointsService,
  ) {}

  @Post("register")
  async register(@Body(validationPipe) dto: RegisterDto) {
    return this.apiAuthService.register(dto);
  }
  
  @Get("check-in-history")
  async getCheckInHistory(
    @Headers("authorization") authorization: string | undefined,
    @Query("year", ParseIntPipe) year: number,
    @Query("month", ParseIntPipe) month: number,
  ) {
    const userId = await this.extractUserId(authorization);
    if (!userId) {
      throw new UnauthorizedException("인증이 필요합니다.");
    }
    return this.pointsService.getCheckInHistory(userId, year, month);
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

  @Post("verify-email")
  @HttpCode(HttpStatus.OK)
  async verifyEmail(@Body(validationPipe) dto: VerifyEmailDto) {
    await this.apiAuthService.verifyEmail(dto.token);
    return { message: "이메일 인증이 완료되었습니다." };
  }

  @Post("resend-verification")
  @HttpCode(HttpStatus.OK)
  async resendVerification(@Body(validationPipe) dto: ResendVerificationDto) {
    await this.apiAuthService.resendVerificationEmail(dto.email);
    return { message: "인증 메일을 재발송했습니다." };
  }

  @Post("complete-registration")
  @HttpCode(HttpStatus.OK)
  async completeRegistration(
    @Headers("authorization") authorization: string | undefined,
    @Body(validationPipe) dto: CompleteRegistrationDto,
  ) {
    const userId = await this.extractUserId(authorization);
    if (!userId) {
      throw new UnauthorizedException("인증이 필요합니다.");
    }

    return this.apiAuthService.completeRegistration(userId, dto);
  }

  @Post("check-in")
  @HttpCode(HttpStatus.OK)
  async checkIn(@Headers("authorization") authorization: string | undefined) {
    const userId = await this.extractUserId(authorization);
    if (!userId) {
      throw new UnauthorizedException("인증이 필요합니다.");
    }

    return this.usersService.checkIn(userId);
  }

  @Post("stats")
  @HttpCode(HttpStatus.OK)
  async getUserStats(@Headers("authorization") authorization: string | undefined) {
    const userId = await this.extractUserId(authorization);
    if (!userId) {
      throw new UnauthorizedException("인증이 필요합니다.");
    }

    return this.usersService.getUserStats(userId);
  }

  @Post("add-points-from-ad")
  @HttpCode(HttpStatus.OK)
  async addPointsFromAd(
    @Headers("authorization") authorization: string | undefined,
    @Body() body: { points?: number },
  ) {
    const userId = await this.extractUserId(authorization);
    if (!userId) {
      throw new UnauthorizedException("인증이 필요합니다.");
    }

    const pointsToAdd = body.points ?? 1;
    return this.usersService.addPointsFromAd(userId, pointsToAdd);
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
