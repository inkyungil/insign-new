import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { Contract } from "./contract.entity";
import { ContractMailLog } from "./contract-mail-log.entity";
import { CreateContractDto } from "./dto/create-contract.dto";
import { MailService } from "../mail/mail.service";
import { ConfigService } from "@nestjs/config";
import { createHash, randomBytes, randomUUID } from "crypto";
import { VerifyPerformerDto } from "./dto/verify-performer.dto";
import { CompleteSignatureDto } from "./dto/complete-signature.dto";
import { basename, join } from "path";
import { promises as fs } from "fs";
import { Template } from "../templates/template.entity";
import { EncryptionService } from "../common/encryption.service";
import { PushNotificationsService } from "../push-tokens/push-notifications.service";
import { ContractBlockchainService } from "../blockchain/contract-blockchain.service";
import { ContractPdfService } from "./contract-pdf.service";
import { VerifyPdfDto } from "./dto/verify-pdf.dto";
import { InboxService } from "../inbox/inbox.service";
import { UsersService } from "../users/users.service";

@Injectable()
export class ContractsService {
  constructor(
    @InjectRepository(Contract)
    private readonly contractsRepository: Repository<Contract>,
    @InjectRepository(ContractMailLog)
    private readonly mailLogRepository: Repository<ContractMailLog>,
    @InjectRepository(Template)
    private readonly templatesRepository: Repository<Template>,
    private readonly mailService: MailService,
    private readonly configService: ConfigService,
    private readonly encryptionService: EncryptionService,
    private readonly pushNotificationsService: PushNotificationsService,
    private readonly contractBlockchainService: ContractBlockchainService,
    private readonly contractPdfService: ContractPdfService,
    private readonly inboxService: InboxService,
    private readonly usersService: UsersService,
  ) {}

  async createContract(
    dto: CreateContractDto,
    createdByUserId?: number | null,
  ) {
    let usePoints = false;
    let contractsUsedBeforeCreation: number | null = null;
    let contractLimitAtCreation: number | null = null;
    let pointCost = 0;

    // 계약서 작성 제한 체크 (로그인한 사용자만)
    if (createdByUserId) {
      const canCreate = await this.usersService.canCreateContract(
        createdByUserId,
      );

      if (!canCreate.canCreate) {
        throw new BadRequestException(
          canCreate.reason || "계약서 작성 제한을 초과했습니다.",
        );
      }

      // 포인트 사용 여부 판단
      usePoints =
        canCreate.contractsLimit >= 0 &&
        canCreate.contractsUsed >= canCreate.contractsLimit;
      contractsUsedBeforeCreation = canCreate.contractsUsed;
      contractLimitAtCreation = canCreate.contractsLimit;
      pointCost = usePoints
        ? this.usersService.getContractPointCost()
        : 0;

      // 실제 작성 전에 카운트 증가 (나중에 실패해도 롤백하지 않음)
      await this.usersService.incrementContractUsage(createdByUserId, usePoints);
    }

    const templateId = await this.resolveTemplateId(dto.templateId ?? null);

    // 민감한 필드 암호화
    const performerContact = dto.performer?.performerContact?.trim() ?? null;
    const encryptedPerformerContact = performerContact
      ? this.encryptionService.encrypt(performerContact)
      : null;

    const clientContact = dto.clientContact?.trim() ?? null;
    const encryptedClientContact = clientContact
      ? this.encryptionService.encrypt(clientContact)
      : null;

    const clientEmail = dto.clientEmail?.trim() ?? null;
    const encryptedClientEmail = clientEmail
      ? this.encryptionService.encrypt(clientEmail)
      : null;

    const performerEmail = dto.performer?.performerEmail?.trim() ?? null;
    const encryptedPerformerEmail = performerEmail
      ? this.encryptionService.encrypt(performerEmail)
      : null;

    const metadata = dto.metadata ?? null;
    const encryptedMetadata = metadata
      ? this.encryptionService.encryptJSON(metadata)
      : null;

    const performerName = dto.performer?.performerName?.trim() ?? null;
    const encryptedPerformerName = performerName
      ? this.encryptionService.encrypt(performerName)
      : null;

    const clientName = dto.clientName.trim();
    const encryptedClientName = this.encryptionService.encrypt(clientName);

    const contract = this.contractsRepository.create({
      templateId,
      name: dto.name.trim(),
      clientName: encryptedClientName,
      clientContact: encryptedClientContact,
      clientEmail: encryptedClientEmail,
      performerName: encryptedPerformerName,
      performerEmail: encryptedPerformerEmail,
      performerContact: encryptedPerformerContact,
      startDate: dto.startDate ? new Date(dto.startDate) : null,
      endDate: dto.endDate ? new Date(dto.endDate) : null,
      amount: dto.amount ?? null,
      details: dto.details ?? null,
      metadata: encryptedMetadata,
      createdByUserId: createdByUserId ?? null,
      signatureToken: this.generateSignatureToken(),
      signatureTokenExpiresAt: this.generateTokenExpiry(),
      status: "draft",
      usedPointsForCreation: usePoints,
      pointsSpentForCreation: pointCost,
      contractsUsedBeforeCreation,
      contractLimitAtCreation,
      signatureDeclinedAt: null,
      signatureCompletedAt: null,
      signatureImage: null,
      signatureSource: null,
    });

    let savedContract = await this.contractsRepository.save(contract);

    if (savedContract.performerEmail) {
      savedContract = await this.dispatchSignatureRequest(savedContract, {
        refreshToken: true,
        strict: false,
      });
    }

    // 복호화 후 enrichTemplateMetadata를 호출하여 templateFormSchema 추가
    const decrypted = this.decryptContractFields(savedContract);
    const metadataBeforeEnrichment = decrypted.metadata;
    const enrichedContract = await this.enrichTemplateMetadata(decrypted);

    // metadata가 변경되었으면 다시 암호화하여 저장
    if (enrichedContract.metadata !== metadataBeforeEnrichment) {
      const encryptedMetadata = enrichedContract.metadata
        ? this.encryptionService.encryptJSON(enrichedContract.metadata)
        : null;

      await this.contractsRepository.update(enrichedContract.id, {
        metadata: encryptedMetadata,
      });
    }

    return enrichedContract;
  }

  async findAllByCreator(userId: number | null) {
    const contracts = userId
      ? await this.contractsRepository.find({
          where: { createdByUserId: userId },
          order: { createdAt: "DESC" },
        })
      : await this.contractsRepository.find({ order: { createdAt: "DESC" } });

    // 복호화 후 메타데이터 보강
    return Promise.all(
      contracts.map((contract) => {
        const decrypted = this.decryptContractFields(contract);
        return this.enrichTemplateMetadata(decrypted);
      }),
    );
  }

  async findOneById(id: number, userId: number | null) {
    const contract = await this.contractsRepository.findOne({ where: { id } });
    if (!contract) {
      throw new NotFoundException("계약을 찾을 수 없습니다.");
    }

    if (
      userId &&
      contract.createdByUserId &&
      contract.createdByUserId !== userId
    ) {
      throw new NotFoundException("계약을 찾을 수 없습니다.");
    }

    // 복호화 후 메타데이터 보강
    const decrypted = this.decryptContractFields(contract);
    return this.enrichTemplateMetadata(decrypted);
  }

  async findBySignatureToken(signatureToken: string) {
    const contract = await this.fetchContractBySignatureToken(signatureToken);

    // 복호화 후 메타데이터 보강
    const decrypted = this.decryptContractFields(contract);
    return this.enrichTemplateMetadata(decrypted);
  }

  async verifyPerformerIdentity(
    signatureToken: string,
    performer: VerifyPerformerDto,
  ) {
    // findBySignatureToken에서 이미 복호화됨
    const contract = await this.findBySignatureToken(signatureToken);

    const normalizeText = (value: string | null) =>
      value ? value.trim().toLowerCase() : null;
    const normalizeContact = (value: string | null) =>
      value ? value.replace(/\D/g, "") : null;

    if (
      !contract.performerName ||
      !contract.performerEmail ||
      !contract.performerContact
    ) {
      throw new BadRequestException(
        "계약에 등록된 수행자 정보가 없어 열람할 수 없습니다. 관리자에게 문의해 주세요.",
      );
    }

    const expectedName = normalizeText(contract.performerName);
    const expectedEmail = normalizeText(contract.performerEmail);
    const expectedContact = normalizeContact(contract.performerContact);

    const providedName = normalizeText(performer.performerName);
    const providedEmail = normalizeText(performer.performerEmail);
    const providedContact = normalizeContact(performer.performerContact);

    if (
      expectedName !== providedName ||
      expectedEmail !== providedEmail ||
      expectedContact !== providedContact
    ) {
      throw new BadRequestException(
        "입력한 수행자 정보가 계약과 일치하지 않습니다.",
      );
    }

    return contract;
  }

  async declineSignature(signatureToken: string) {
    const contract = await this.fetchContractBySignatureToken(signatureToken);

    if (contract.signatureCompletedAt) {
      throw new BadRequestException("이미 서명이 완료된 계약입니다.");
    }

    contract.status = "signature_declined";
    if (!contract.signatureDeclinedAt) {
      contract.signatureDeclinedAt = new Date();
    }
    await this.removeSignatureAsset(contract.signatureImage);
    contract.signatureCompletedAt = null;
    contract.signatureImage = null;
    contract.signatureSource = null;

    const saved = await this.contractsRepository.save(contract);
    const decrypted = this.decryptContractFields(saved);
    return this.enrichTemplateMetadata(decrypted);
  }

  async verifyUploadedPdf(
    contractId: number,
    userId: number | null,
    dto: VerifyPdfDto,
  ) {
    const contract = await this.findOneById(contractId, userId);

    const encoded = dto.fileBase64?.trim();
    if (!encoded) {
      throw new BadRequestException(
        "검증할 PDF 데이터를 첨부해 주세요.",
      );
    }

    const pdfBuffer = this.decodePdfPayload(encoded);
    const computedHash = createHash("sha256").update(pdfBuffer).digest("hex");
    const storedHash = await this.ensurePdfHash(contract);

    if (!storedHash) {
      throw new BadRequestException(
        "저장된 계약서 파일이 없어 검증할 수 없습니다.",
      );
    }

    const matchesStoredPdf = computedHash === storedHash;
    const matchesBlockchain = contract.blockchainHash
      ? computedHash === contract.blockchainHash
      : matchesStoredPdf;

    return {
      success: true,
      matchesBlockchain,
      matchesStoredPdf,
      computedHash,
      blockchainHash: contract.blockchainHash,
      pdfHash: storedHash,
      blockchainTxHash: contract.blockchainTxHash,
      blockchainNetwork: contract.blockchainNetwork,
      blockchainTimestamp: contract.blockchainTimestamp,
    };
  }

  async completeSignature(signatureToken: string, dto: CompleteSignatureDto) {
    const contract = await this.fetchContractBySignatureToken(signatureToken);

    if (contract.signatureDeclinedAt) {
      throw new BadRequestException(
        "서명이 거절된 계약입니다. 다시 요청해 주세요.",
      );
    }

    if (!contract.performerEmail) {
      throw new BadRequestException(
        "수행자 이메일이 없어 서명을 완료할 수 없습니다.",
      );
    }

    const storedPath = await this.persistSignatureImage(
      contract,
      dto.imageData,
    );
    await this.removeSignatureAsset(contract.signatureImage);
    contract.signatureImage = storedPath;
    contract.signatureSource = dto.source ?? "draw";
    contract.signatureCompletedAt = new Date();
    contract.status = "signature_completed";
    contract.signatureDeclinedAt = null;

    if (dto.recipientFormValues && Object.keys(dto.recipientFormValues).length > 0) {
      const currentMetadata = this.extractMetadataSnapshot(contract.metadata);
      const updatedMetadata = {
        ...currentMetadata,
        recipientFormValues: dto.recipientFormValues,
      };
      contract.metadata = this.encryptionService.encryptJSON(
        updatedMetadata,
      );
    }

    const saved = await this.contractsRepository.save(contract);
    const decrypted = this.decryptContractFields(saved);
    const contractForPdf = await this.enrichTemplateMetadata(decrypted);

    // 서명 완료 알림 전송 (갑/작성자에게)
    if (saved.createdByUserId) {
      try {
        const notificationTitle = '계약서 서명 완료';
        const notificationBody = `${contractForPdf.performerName || '수행자'}님이 "${contractForPdf.name}" 계약서에 서명했습니다.`;

        // 1. Inbox에 메시지 저장
        await this.inboxService.createForUser(saved.createdByUserId, {
          kind: 'alert',
          title: notificationTitle,
          body: notificationBody,
          tags: ['push/admin/contract', 'signature_completed'],
          metadata: {
            contractId: saved.id,
            contractName: contractForPdf.name,
            type: 'contract_completed',
          },
        });

        // 2. Push 알림 전송
        await this.pushNotificationsService.sendContractCompletedNotification({
          userId: saved.createdByUserId,
          title: notificationTitle,
          body: notificationBody,
          contractId: saved.id,
          contractName: contractForPdf.name,
        });
      } catch (error) {
        // 알림 실패는 무시 (계약서 저장은 성공)
        console.error('알림 전송 실패:', error);
      }
    }

    try {
      console.log('📄 PDF 파일 생성 중...');
      const pdfBuffer = await this.contractPdfService.generate(contractForPdf);

      await this.removePdfFile(saved.pdfFilePath);
      const storedPdfPath = await this.savePdfFile(saved.id, pdfBuffer);
      saved.pdfFilePath = storedPdfPath;

      const storedBuffer = await this.loadPdfFromStorage(storedPdfPath);
      const bufferForHash = storedBuffer ?? pdfBuffer;

      const pdfHash = this.contractBlockchainService.generatePdfHash(bufferForHash);
      saved.pdfHash = pdfHash;
      console.log(`🔐 PDF 해시 생성 완료: ${pdfHash}`);

      if (this.contractBlockchainService.isEnabled()) {
        const blockchainResult = await this.contractBlockchainService.registerContractToBlockchain(
          contractForPdf,
          pdfHash,
        );

        if (blockchainResult.success) {
          saved.blockchainHash = pdfHash;
          saved.blockchainTxHash = blockchainResult.txHash ?? null;
          saved.blockchainTimestamp = new Date();
          saved.blockchainNetwork = blockchainResult.network ?? 'kaia-testnet';

          console.log(`✅ 블록체인 등록 완료 - 계약서 ID: ${saved.id}, TX: ${saved.blockchainTxHash}`);
          console.log(`🔐 문서 해시: ${pdfHash}`);

          // 블록체인에 등록되었으므로 PDF 파일 삭제 (스토리지 절약)
          await this.removePdfFile(saved.pdfFilePath);
          saved.pdfFilePath = null;
          console.log('🗑️  PDF 파일 삭제 완료 - 블록체인 해시로 검증 가능');
        } else {
          console.error('⚠️ 블록체인 등록 실패:', blockchainResult.error);
          console.log('💾 PDF 파일은 저장되었으며, 파일 해시로 검증 가능');
        }
      } else {
        console.log('ℹ️ 블록체인 기능이 비활성화되어 있습니다.');
      }

      await this.contractsRepository.save(saved);
    } catch (error) {
      console.error('⚠️ 계약서 PDF 해시 생성/블록체인 등록 중 오류:', error);
    }

    return contractForPdf;
  }

  async resendSignatureRequest(contractId: number, userId: number | null) {
    const contract = await this.contractsRepository.findOne({
      where: { id: contractId },
    });
    if (!contract) {
      throw new NotFoundException("계약을 찾을 수 없습니다.");
    }

    if (
      userId &&
      contract.createdByUserId &&
      contract.createdByUserId !== userId
    ) {
      throw new NotFoundException("계약을 찾을 수 없습니다.");
    }

    await this.dispatchSignatureRequest(contract, {
      refreshToken: true,
      strict: true,
    });
  }

  private generateSignatureToken() {
    return randomBytes(32).toString("hex");
  }

  private async resolveTemplateId(providedId: number | null) {
    if (providedId) {
      const template = await this.templatesRepository.findOne({
        where: { id: providedId },
      });
      if (template) {
        return template.id;
      }
    }

    const configured = this.configService.get<string | number>(
      "DEFAULT_TEMPLATE_ID",
    );
    if (configured !== undefined && configured !== null) {
      const parsed = Number(configured);
      if (!Number.isNaN(parsed)) {
        const template = await this.templatesRepository.findOne({
          where: { id: parsed },
        });
        if (template) {
          return template.id;
        }
      }
    }

    const byName = await this.templatesRepository.findOne({
      where: { name: "기본 자유 계약서" },
    });
    if (byName) {
      return byName.id;
    }

    const byCategory = await this.templatesRepository.findOne({
      where: { category: "기본" },
      order: { id: "ASC" },
    });
    return byCategory?.id ?? null;
  }

  private generateTokenExpiry() {
    const expires = new Date();
    expires.setDate(expires.getDate() + 7);
    return expires;
  }

  private async dispatchSignatureRequest(
    contract: Contract,
    options: { refreshToken?: boolean; strict?: boolean } = {},
  ) {
    const { refreshToken = false, strict = false } = options;

    if (contract.signatureCompletedAt) {
      throw new BadRequestException(
        "이미 서명이 완료된 계약은 재전송할 수 없습니다.",
      );
    }

    const performerEmailPlain = this.safeDecrypt(contract.performerEmail);

    if (!performerEmailPlain) {
      if (strict) {
        throw new BadRequestException(
          "수행자 이메일이 없어 서명 요청을 보낼 수 없습니다.",
        );
      }
      return contract;
    }

    if (refreshToken || !contract.signatureToken) {
      contract.signatureToken = this.generateSignatureToken();
    }

    contract.signatureTokenExpiresAt = this.generateTokenExpiry();
    contract.signatureSentAt = new Date();
    contract.signatureDeclinedAt = null;
    await this.removeSignatureAsset(contract.signatureImage);
    contract.signatureImage = null;
    contract.signatureSource = null;
    contract.signatureCompletedAt = null;
    contract.status = "active";

    const updatedContract = await this.contractsRepository.save(contract);

    const baseUrl = this.configService.get<string>(
      "APP_CLIENT_URL",
      "https://example.com",
    );
    const link = `${baseUrl.replace(/\/$/, "")}/sign/${updatedContract.signatureToken}`;

    const encryptedRecipientEmail = this.encryptionService.encrypt(
      performerEmailPlain,
    );

    // 갑(의뢰인) 이름 복호화
    const clientNamePlain = this.safeDecrypt(updatedContract.clientName);

    try {
      await this.mailService.sendContractSignatureMail({
        to: performerEmailPlain,
        contractName: updatedContract.name,
        link,
        senderName: clientNamePlain ?? undefined,
      });

      await this.mailLogRepository.save(
        this.mailLogRepository.create({
          contractId: updatedContract.id,
          recipientEmail: encryptedRecipientEmail,
          mailType: "signature-request",
          status: "success",
          errorMessage: null,
        }),
      );
    } catch (error) {
      await this.mailLogRepository.save(
        this.mailLogRepository.create({
          contractId: updatedContract.id,
          recipientEmail: encryptedRecipientEmail,
          mailType: "signature-request",
          status: "failed",
          errorMessage: error instanceof Error ? error.message : String(error),
        }),
      );
      throw error;
    }

    return updatedContract;
  }

  private getSignatureStorage() {
    const directory = (
      this.configService.get<string>("SIGNATURE_STORAGE_DIR", "signatures") ??
      "signatures"
    ).replace(/^\/+|\/+$/g, "");
    const publicPrefixConfigured = this.configService.get<string>(
      "SIGNATURE_PUBLIC_PREFIX",
      `/static/${directory}`,
    );
    const publicPrefix = (
      publicPrefixConfigured ?? `/static/${directory}`
    ).replace(/\/$/, "");
    const absoluteDir = join(process.cwd(), "public", directory);

    const maxBytes = Number(
      this.configService.get<string>(
        "SIGNATURE_MAX_BYTES",
        `${5 * 1024 * 1024}`,
      ),
    );
    const resolvedMaxBytes = Number.isNaN(maxBytes)
      ? 5 * 1024 * 1024
      : maxBytes;

    return {
      directory,
      publicPrefix,
      absoluteDir,
      maxBytes: resolvedMaxBytes,
    };
  }

  private async persistSignatureImage(contract: Contract, imageData: string) {
    const trimmed = imageData.trim();
    if (!trimmed) {
      throw new BadRequestException("유효한 서명 이미지를 첨부해 주세요.");
    }

    const { absoluteDir, publicPrefix, maxBytes } = this.getSignatureStorage();
    await fs.mkdir(absoluteDir, { recursive: true });

    const { buffer, extension } = this.extractImageBuffer(trimmed);
    if (buffer.length === 0) {
      throw new BadRequestException("빈 서명 이미지는 저장할 수 없습니다.");
    }

    if (buffer.length > maxBytes) {
      const limitMb = Math.max(1, Math.round(maxBytes / (1024 * 1024)));
      throw new BadRequestException(
        `서명 이미지가 너무 큽니다. 최대 ${limitMb}MB 이하로 업로드해 주세요.`,
      );
    }

    const filename = `contract-${contract.id}-${Date.now()}.${extension}`;
    const filePath = join(absoluteDir, filename);
    await fs.writeFile(filePath, buffer);

    return `${publicPrefix}/${filename}`;
  }

  private extractImageBuffer(data: string) {
    const dataUrlPattern = /^data:(image\/(?:png|jpeg|jpg));base64,(.+)$/i;
    let base64 = data;
    let mime = "image/png";

    const match = data.match(dataUrlPattern);
    if (match) {
      mime = match[1].toLowerCase();
      base64 = match[2];
    }

    const allowed = new Map<string, string>([
      ["image/png", "png"],
      ["image/jpeg", "jpg"],
      ["image/jpg", "jpg"],
    ]);

    if (!allowed.has(mime)) {
      throw new BadRequestException(
        "PNG 또는 JPG 형식의 서명 이미지만 업로드할 수 있습니다.",
      );
    }

    try {
      const buffer = Buffer.from(base64, "base64");
      return { buffer, extension: allowed.get(mime)! };
    } catch {
      throw new BadRequestException(
        "서명 이미지를 처리하지 못했습니다. 다시 시도해 주세요.",
      );
    }
  }

  private async removeSignatureAsset(currentPath: string | null) {
    if (!currentPath) {
      return;
    }

    const { absoluteDir } = this.getSignatureStorage();
    const filename = basename(currentPath);
    if (!filename) {
      return;
    }

    const filePath = join(absoluteDir, filename);
    try {
      await fs.unlink(filePath);
    } catch (error: unknown) {
      const err = error as NodeJS.ErrnoException;
      if (err?.code !== "ENOENT") {
        // swallow unexpected errors to avoid blocking main flows
      }
    }
  }

  private resolvePdfAbsolutePath(pdfFilePath: string) {
    const filename = basename(pdfFilePath);
    const absoluteDir = join(process.cwd(), 'public', 'contracts');
    return join(absoluteDir, filename);
  }

  private async loadPdfFromStorage(
    pdfFilePath: string | null,
  ): Promise<Buffer | null> {
    if (!pdfFilePath) {
      return null;
    }
    try {
      const absolutePath = this.resolvePdfAbsolutePath(pdfFilePath);
      return await fs.readFile(absolutePath);
    } catch (error) {
      const err = error as NodeJS.ErrnoException;
      if (err?.code !== 'ENOENT') {
        console.warn(
          `Failed to read stored PDF file (${pdfFilePath}): ${err?.message}`,
        );
      }
      return null;
    }
  }

  private async removePdfFile(currentPath: string | null) {
    if (!currentPath) {
      return;
    }
    try {
      const absolutePath = this.resolvePdfAbsolutePath(currentPath);
      await fs.unlink(absolutePath);
    } catch (error) {
      const err = error as NodeJS.ErrnoException;
      if (err?.code !== 'ENOENT') {
        console.warn(
          `Failed to remove stored PDF file (${currentPath}): ${err?.message}`,
        );
      }
    }
  }

  private async savePdfFile(contractId: number, pdfBuffer: Buffer): Promise<string> {
    const absoluteDir = join(process.cwd(), 'public', 'contracts');
    await fs.mkdir(absoluteDir, { recursive: true });

    const filename = `contract-${contractId}-${Date.now()}-${randomUUID()}.pdf`;
    const filePath = join(absoluteDir, filename);
    await fs.writeFile(filePath, pdfBuffer);

    return `/static/contracts/${filename}`;
  }

  async getStoredPdfBuffer(contract: Contract): Promise<Buffer | null> {
    return this.loadPdfFromStorage(contract.pdfFilePath);
  }

  private async ensurePdfHash(contract: Contract): Promise<string | null> {
    if (contract.pdfHash) {
      return contract.pdfHash;
    }
    const stored = await this.loadPdfFromStorage(contract.pdfFilePath);
    if (!stored) {
      return null;
    }
    const computed = createHash('sha256').update(stored).digest('hex');
    await this.contractsRepository.update(contract.id, { pdfHash: computed });
    contract.pdfHash = computed;
    return computed;
  }

  /**
   * 계약의 암호화된 필드를 복호화합니다.
   * @param contract 복호화할 계약
   * @returns 복호화된 계약
   */
  private decryptContractFields(contract: Contract): Contract {
    if (!contract) {
      return contract;
    }

    const decrypted = { ...contract } as Contract;

    // clientContact 복호화
    if (decrypted.clientContact) {
      try {
        decrypted.clientContact = this.encryptionService.decrypt(
          decrypted.clientContact,
        );
      } catch {
        // 복호화 실패 시 원본 유지 (마이그레이션 중 평문 데이터 대응)
      }
    }

    // clientEmail 복호화
    if (decrypted.clientEmail) {
      try {
        decrypted.clientEmail = this.encryptionService.decrypt(
          decrypted.clientEmail,
        );
      } catch {
        // 복호화 실패 시 원본 유지
      }
    }

    // clientName 복호화
    if (decrypted.clientName) {
      try {
        decrypted.clientName = this.encryptionService.decrypt(
          decrypted.clientName,
        );
      } catch {
        // 복호화 실패 시 원본 유지
      }
    }

    // performerEmail 복호화
    if (decrypted.performerEmail) {
      try {
        decrypted.performerEmail = this.encryptionService.decrypt(
          decrypted.performerEmail,
        );
      } catch {
        // 복호화 실패 시 원본 유지
      }
    }

    // performerName 복호화
    if (decrypted.performerName) {
      try {
        decrypted.performerName = this.encryptionService.decrypt(
          decrypted.performerName,
        );
      } catch {
        // 복호화 실패 시 원본 유지
      }
    }

    // performerContact 복호화
    if (decrypted.performerContact) {
      try {
        decrypted.performerContact = this.encryptionService.decrypt(
          decrypted.performerContact,
        );
      } catch {
        // 복호화 실패 시 원본 유지
      }
    }

    // metadata 복호화
    if (decrypted.metadata) {
      try {
        // metadata가 문자열이면 암호화된 것으로 간주
        if (typeof decrypted.metadata === "string") {
          decrypted.metadata = this.encryptionService.decryptJSON(
            decrypted.metadata,
          );
        }
      } catch {
        // 복호화 실패 시 원본 유지
      }
    }

    return decrypted;
  }

  private async fetchContractBySignatureToken(
    signatureToken: string,
  ): Promise<Contract> {
    const contract = await this.contractsRepository.findOne({
      where: { signatureToken },
    });
    if (!contract) {
      throw new NotFoundException("유효하지 않은 서명 링크입니다.");
    }

    if (
      contract.signatureTokenExpiresAt &&
      contract.signatureTokenExpiresAt < new Date()
    ) {
      throw new BadRequestException(
        "서명 링크가 만료되었습니다. 다시 요청해 주세요.",
      );
    }

    return contract;
  }

  private extractMetadataSnapshot(
    metadata: Contract["metadata"],
  ): Record<string, unknown> {
    if (!metadata) {
      return {};
    }

    if (typeof metadata === "string") {
      try {
        return (
          this.encryptionService.decryptJSON<Record<string, unknown>>(metadata) ??
          {}
        );
      } catch {
        return {};
      }
    }

    if (typeof metadata === "object") {
      return { ...(metadata as Record<string, unknown>) };
    }

    return {};
  }

  private safeDecrypt(value: string | null): string | null {
    if (!value) {
      return null;
    }

    try {
      return this.encryptionService.decrypt(value);
    } catch {
      return null;
    }
  }

  private async enrichTemplateMetadata(contract: Contract): Promise<Contract> {
    if (!contract.templateId) {
      return contract;
    }

    const currentMetadata = (typeof contract.metadata === 'object' && contract.metadata !== null)
      ? contract.metadata
      : {};
    const hasSchema = Object.prototype.hasOwnProperty.call(
      currentMetadata,
      "templateFormSchema",
    );

    if (hasSchema && (currentMetadata as Record<string, unknown>).templateFormSchema) {
      return contract;
    }

    const template = await this.templatesRepository.findOne({
      where: { id: contract.templateId },
    });

    if (!template) {
      return contract;
    }

    const nextMetadata = {
      ...(currentMetadata as Record<string, unknown>),
    } as Record<string, unknown> & {
      templateFormSchema?: unknown;
      templateName?: unknown;
      templateSchemaVersion?: unknown;
    };

    nextMetadata.templateFormSchema = template.formSchema ?? null;

    if (!nextMetadata.templateName) {
      nextMetadata.templateName = template.name;
    }

    if (
      !nextMetadata.templateSchemaVersion &&
      template.formSchema?.version !== undefined
    ) {
      nextMetadata.templateSchemaVersion = template.formSchema.version;
    }

    contract.metadata = nextMetadata;
    return contract;
  }

  private decodePdfPayload(encoded: string): Buffer {
    const trimmed = encoded.trim();
    const base64 = trimmed.includes(",")
      ? trimmed.substring(trimmed.lastIndexOf(",") + 1)
      : trimmed;

    try {
      return Buffer.from(base64, "base64");
    } catch {
      throw new BadRequestException(
        "유효한 PDF 파일을 업로드해 주세요.",
      );
    }
  }
}
