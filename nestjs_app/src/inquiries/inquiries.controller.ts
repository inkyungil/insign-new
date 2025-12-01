import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Headers,
  UnauthorizedException,
} from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import { InquiriesService } from "./inquiries.service";
import { CreateInquiryDto } from "./dto/create-inquiry.dto";

@Controller("api/inquiries")
export class InquiriesController {
  constructor(
    private readonly inquiriesService: InquiriesService,
    private readonly jwtService: JwtService,
  ) {}

  private async extractUserId(authorization: string | undefined) {
    if (authorization?.startsWith("Bearer ")) {
      const token = authorization.slice("Bearer ".length);
      try {
        const payload = await this.jwtService.verifyAsync<{ sub: number }>(
          token,
        );
        return payload?.sub ?? null;
      } catch {
        return null;
      }
    }
    return null;
  }

  @Post()
  async create(
    @Headers("authorization") authorization: string,
    @Body() dto: CreateInquiryDto,
  ) {
    const userId = await this.extractUserId(authorization);
    if (!userId) {
      throw new UnauthorizedException("인증이 필요합니다.");
    }
    return this.inquiriesService.create(userId, dto);
  }

  @Get("my")
  async findMy(@Headers("authorization") authorization: string) {
    const userId = await this.extractUserId(authorization);
    if (!userId) {
      throw new UnauthorizedException("인증이 필요합니다.");
    }
    return this.inquiriesService.findByUser(userId);
  }

  @Get(":id")
  async findOne(
    @Headers("authorization") authorization: string,
    @Param("id") id: string,
  ) {
    const userId = await this.extractUserId(authorization);
    if (!userId) {
      throw new UnauthorizedException("인증이 필요합니다.");
    }
    return this.inquiriesService.findOne(+id);
  }
}
