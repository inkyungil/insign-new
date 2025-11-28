import {
  Body,
  Controller,
  Get,
  Headers,
  Param,
  ParseIntPipe,
  Post,
  Res,
  UnauthorizedException,
} from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import { Response } from "express";
import { ContractsService } from "./contracts.service";
import { CreateContractDto } from "./dto/create-contract.dto";
import { ContractResponseDto } from "./dto/contract-response.dto";
import { ContractTokenResponseDto } from "./dto/contract-token-response.dto";
import { VerifyPerformerDto } from "./dto/verify-performer.dto";
import { CompleteSignatureDto } from "./dto/complete-signature.dto";
import { VerifyPdfDto } from "./dto/verify-pdf.dto";
import { ContractPdfService } from "./contract-pdf.service";

@Controller("api/contracts")
export class ContractsController {
  constructor(
    private readonly contractsService: ContractsService,
    private readonly jwtService: JwtService,
    private readonly contractPdfService: ContractPdfService,
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

  @Get()
  async list(@Headers("authorization") authorization: string | undefined) {
    const userId = await this.extractUserId(authorization);
    const contracts = await this.contractsService.findAllByCreator(userId);
    return contracts.map(ContractResponseDto.fromEntity);
  }

  @Post()
  async create(
    @Headers("authorization") authorization: string | undefined,
    @Body() dto: CreateContractDto,
  ) {
    const createdBy = await this.extractUserId(authorization);
    const contract = await this.contractsService.createContract(dto, createdBy);
    return ContractResponseDto.fromEntity(contract);
  }

  @Get("sign/:token")
  verifyToken() {
    throw new UnauthorizedException(
      "수행자 정보를 인증한 후 열람할 수 있습니다.",
    );
  }

  @Post("sign/:token/verify")
  async verifyTokenWithPerformer(
    @Param("token") token: string,
    @Body() performer: VerifyPerformerDto,
  ) {
    const contract = await this.contractsService.verifyPerformerIdentity(
      token,
      performer,
    );
    return ContractTokenResponseDto.fromEntity(contract);
  }

  @Post("sign/:token/complete")
  async completeSignature(
    @Param("token") token: string,
    @Body() body: CompleteSignatureDto,
  ) {
    const contract = await this.contractsService.completeSignature(token, body);
    return ContractTokenResponseDto.fromEntity(contract);
  }

  @Post("sign/:token/decline")
  async declineSignature(@Param("token") token: string) {
    const contract = await this.contractsService.declineSignature(token);
    return ContractTokenResponseDto.fromEntity(contract);
  }

  @Get(":id")
  async detail(
    @Headers("authorization") authorization: string | undefined,
    @Param("id", ParseIntPipe) id: number,
  ) {
    const userId = await this.extractUserId(authorization);
    const contract = await this.contractsService.findOneById(id, userId);
    return ContractResponseDto.fromEntity(contract);
  }

  @Post(":id/verify-pdf")
  async verifyPdf(
    @Headers("authorization") authorization: string | undefined,
    @Param("id", ParseIntPipe) id: number,
    @Body() dto: VerifyPdfDto,
  ) {
    const userId = await this.extractUserId(authorization);
    return this.contractsService.verifyUploadedPdf(id, userId, dto);
  }

  @Post(":id/resend")
  async resend(
    @Headers("authorization") authorization: string | undefined,
    @Param("id", ParseIntPipe) id: number,
  ) {
    const userId = await this.extractUserId(authorization);
    await this.contractsService.resendSignatureRequest(id, userId);
    return { success: true };
  }

  @Get(":id/pdf")
  async downloadPdf(
    @Headers("authorization") authorization: string | undefined,
    @Param("id", ParseIntPipe) id: number,
    @Res() res: Response,
  ) {
    const userId = await this.extractUserId(authorization);
    const contract = await this.contractsService.findOneById(id, userId);

    // 저장된 PDF 파일을 먼저 시도
    let pdfBuffer = await this.contractsService.getStoredPdfBuffer(contract);

    // 저장된 파일이 없으면 새로 생성 (하위 호환성)
    if (!pdfBuffer) {
      console.warn(`계약 ID ${contract.id}: 저장된 PDF가 없어 새로 생성합니다.`);
      pdfBuffer = await this.contractPdfService.generate(contract);
    }

    this.setPdfHeaders(res, contract.name, contract.id);
    res.send(pdfBuffer);
  }

  @Get("sign/:token/pdf")
  async downloadPdfByToken(
    @Param("token") token: string,
    @Res() res: Response,
  ) {
    const contract = await this.contractsService.findBySignatureToken(token);

    // 저장된 PDF 파일을 먼저 시도
    let pdfBuffer = await this.contractsService.getStoredPdfBuffer(contract);

    // 저장된 파일이 없으면 새로 생성 (하위 호환성)
    if (!pdfBuffer) {
      console.warn(`계약 ID ${contract.id}: 저장된 PDF가 없어 새로 생성합니다.`);
      pdfBuffer = await this.contractPdfService.generate(contract);
    }

    this.setPdfHeaders(res, contract.name, contract.id);
    res.send(pdfBuffer);
  }

  private setPdfHeaders(res: Response, name: string, id: number) {
    const rawName = `${name}-${id}.pdf`;
    const fallback = rawName
      .normalize("NFKD")
      .replace(/[\u0300-\u036f]/g, "")
      .replace(/[^\x20-\x7E]+/g, "")
      .replace(/[^A-Za-z0-9._-]+/g, "-")
      .replace(/-+/g, "-")
      .replace(/^-|-$/g, "");
    const fallbackName = (fallback ? fallback : `contract-${id}.pdf`).slice(0, 80);
    const encoded = encodeURIComponent(rawName);
    const disposition = `attachment; filename="${fallbackName}"; filename*=UTF-8''${encoded}`;

    res.setHeader("Content-Type", "application/pdf");
    res.setHeader("Content-Disposition", disposition);
  }
}
