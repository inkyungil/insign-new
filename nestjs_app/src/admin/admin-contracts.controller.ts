import {
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Query,
  Render,
  Req,
  Res,
  UseGuards,
} from "@nestjs/common";
import { ApiExcludeController } from "@nestjs/swagger";
import { Request } from "express";
import { AuthenticatedGuard } from "../auth/authenticated.guard";
import { ContractsService } from "../contracts/contracts.service";
import { Contract } from "../contracts/contract.entity";
import { ContractPdfService } from "../contracts/contract-pdf.service";
import { Response } from "express";
import { ADMIN_ROUTE_PREFIX } from "./admin.constants";

function formatDateTime(value?: Date | string | null) {
  if (!value) {
    return "-";
  }
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) {
    return "-";
  }
  return date.toISOString().replace("T", " ").slice(0, 19);
}

function ensureRecord(value: unknown): value is Record<string, any> {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function resolveStatus(status: string) {
  switch (status) {
    case "draft":
      return { label: "작성 중", badgeClass: "badge-secondary" };
    case "active":
      return { label: "서명 대기", badgeClass: "badge-info" };
    case "signature_completed":
      return { label: "서명 완료", badgeClass: "badge-success" };
    case "signature_declined":
      return { label: "서명 거절", badgeClass: "badge-danger" };
    default:
      return { label: status, badgeClass: "badge-dark" };
  }
}

function extractMetadata(contract: Contract) {
  if (!ensureRecord(contract.metadata)) {
    return {
      raw: null,
      templateName: "-",
      templateSchemaVersion: null as number | null,
      templateValues: {} as Record<string, string>,
      templateRawContent: null as string | null,
      recipientFormEntries: [] as Array<{ key: string; value: string }>,
    };
  }

  const metadata = contract.metadata as Record<string, any>;
  const templateName = typeof metadata.templateName === "string" ? metadata.templateName : "-";
  const templateSchemaVersion =
    typeof metadata.templateSchemaVersion === "number"
      ? metadata.templateSchemaVersion
      : metadata.templateSchemaVersion && typeof metadata.templateSchemaVersion === "string"
      ? Number(metadata.templateSchemaVersion)
      : null;

  const templateValuesSource = ensureRecord(metadata.templateFormValues)
    ? (metadata.templateFormValues as Record<string, unknown>)
    : null;
  const templateValues: Record<string, string> = templateValuesSource
    ? Object.entries(templateValuesSource).reduce((acc, [key, value]) => {
        const normalized = normalizePlaceholderValue(value);
        if (normalized !== null) {
          acc[key] = normalized;
        }
        return acc;
      }, {} as Record<string, string>)
    : {};

  const recipientForm = ensureRecord(metadata.recipientFormValues)
    ? (metadata.recipientFormValues as Record<string, unknown>)
    : null;

  const recipientFormEntries = recipientForm
    ? Object.entries(recipientForm).map(([key, value]) => ({
        key,
        value: value === null || value === undefined ? "" : String(value),
      }))
    : [];

  const templateRawContent =
    typeof metadata.templateRawContent === "string"
      ? metadata.templateRawContent
      : null;

  return {
    raw: JSON.stringify(metadata, null, 2),
    templateName,
    templateSchemaVersion,
    templateValues,
    templateRawContent,
    recipientFormEntries,
  };
}

function summarizeContract(contract: Contract) {
  const status = resolveStatus(contract.status);
  const metadata = extractMetadata(contract);

  return {
    id: contract.id,
    name: contract.name,
    clientName: contract.clientName,
    performerName: contract.performerName ?? "-",
    status: contract.status,
    statusLabel: status.label,
    statusBadgeClass: status.badgeClass,
    templateName: metadata.templateName,
    createdAt: formatDateTime(contract.createdAt),
    updatedAt: formatDateTime(contract.updatedAt),
  };
}

function buildDetail(contract: Contract) {
  const status = resolveStatus(contract.status);
  const metadata = extractMetadata(contract);
  const placeholders = buildPlaceholderMap(contract, metadata, status.label);

  const detailSource = contract.details ?? metadata.templateRawContent ?? null;
  const detailsHtml = detailSource
    ? replacePlaceholders(detailSource, placeholders)
    : null;

  const detailsPlain = detailsHtml ? stripHtml(detailsHtml) : null;

  const signatureImage = contract.signatureImage ?? null;
  const signatureImageHint = signatureImage
    ? signatureImage.startsWith("data:")
      ? "data-url"
      : signatureImage.startsWith("http") || signatureImage.startsWith("/")
      ? "link"
      : "embedded"
    : null;

  return {
    ...summarizeContract(contract),
    clientContact: contract.clientContact ?? "-",
    clientEmail: contract.clientEmail ?? "-",
    performerEmail: contract.performerEmail ?? "-",
    performerContact: contract.performerContact ?? "-",
    startDate: formatDateTime(contract.startDate ?? null),
    endDate: formatDateTime(contract.endDate ?? null),
    templateSchemaVersion: metadata.templateSchemaVersion,
    detailsHtml,
    detailsPlain,
    metadataJson: metadata.raw,
    recipientFormEntries: metadata.recipientFormEntries,
    signatureToken: contract.signatureToken ?? "-",
    signatureSentAt: formatDateTime(contract.signatureSentAt ?? null),
    signatureCompletedAt: formatDateTime(contract.signatureCompletedAt ?? null),
    signatureDeclinedAt: formatDateTime(contract.signatureDeclinedAt ?? null),
    signatureSource: contract.signatureSource ?? "-",
    signatureImage,
    signatureImageHint,
    statusLabel: status.label,
    statusBadgeClass: status.badgeClass,
  };
}

function buildPlaceholderMap(
  contract: Contract,
  metadata: ReturnType<typeof extractMetadata>,
  statusLabel: string,
) {
  const map: Record<string, string> = {};

  const set = (key: string, value: unknown) => {
    const normalized = normalizePlaceholderValue(value);
    if (normalized !== null) {
      map[key] = normalized;
    }
  };

  set("contractId", contract.id);
  set("contractName", contract.name);
  set("templateName", metadata.templateName);
  set("templateSchemaVersion", metadata.templateSchemaVersion);
  set("status", contract.status);
  set("statusLabel", statusLabel);
  set("clientName", contract.clientName);
  set("clientEmail", contract.clientEmail);
  set("clientContact", contract.clientContact);
  set("performerName", contract.performerName);
  set("performerEmail", contract.performerEmail);
  set("performerContact", contract.performerContact);
  set("startDate", formatDateTime(contract.startDate ?? null));
  set("endDate", formatDateTime(contract.endDate ?? null));
  set("amount", contract.amount);
  set("signatureToken", contract.signatureToken);
  set("signatureSentAt", formatDateTime(contract.signatureSentAt ?? null));
  set(
    "signatureCompletedAt",
    formatDateTime(contract.signatureCompletedAt ?? null),
  );
  set("signatureDeclinedAt", formatDateTime(contract.signatureDeclinedAt ?? null));
  set("signatureSource", contract.signatureSource);

  Object.entries(metadata.templateValues).forEach(([key, value]) => set(key, value));
  metadata.recipientFormEntries.forEach(({ key, value }) => set(key, value));

  return map;
}

function replacePlaceholders(text: string, placeholders: Record<string, string>) {
  if (!text || !text.includes("{{")) {
    return text;
  }
  return text.replace(/{{\s*([^{}]+?)\s*}}/g, (match, key) => {
    const normalizedKey = key.trim();
    const value = placeholders[normalizedKey];
    return value !== undefined ? value : "";
  });
}

function stripHtml(value: string) {
  return value
    .replace(/<\s*br\s*\/?\s*>/gi, "\n")
    .replace(/<\/(p|div|li|tr|table|h[1-6])>/gi, "\n")
    .replace(/<[^>]+>/g, "")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

function normalizePlaceholderValue(value: unknown): string | null {
  if (value === null || value === undefined) {
    return null;
  }
  if (value instanceof Date) {
    return formatDateTime(value);
  }
  if (typeof value === "number" || typeof value === "bigint") {
    return String(value);
  }
  if (typeof value === "boolean") {
    return value ? "Y" : "N";
  }
  if (typeof value === "string") {
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : null;
  }
  return null;
}

@Controller(`${ADMIN_ROUTE_PREFIX}/contracts`)
@ApiExcludeController()
@UseGuards(AuthenticatedGuard)
export class AdminContractsController {
  constructor(
    private readonly contractsService: ContractsService,
    private readonly contractPdfService: ContractPdfService,
  ) {}

  @Get()
  @Render("admin/contracts")
  async index(@Req() request: Request, @Query("contractId") rawContractId?: string) {
    const contracts = await this.contractsService.findAllByCreator(null);

    let selectedContract = null;
    let errorMessage: string | null = null;

    if (rawContractId) {
      const parsedId = Number(rawContractId);
      if (Number.isNaN(parsedId)) {
        errorMessage = "잘못된 계약 ID 입니다.";
      } else {
        try {
          const found = await this.contractsService.findOneById(parsedId, null);
          selectedContract = buildDetail(found);
        } catch (error) {
          errorMessage = "선택한 계약을 찾을 수 없습니다.";
        }
      }
    }

    return {
      user: request.user,
      contracts: contracts.map(summarizeContract),
      selectedContract,
      errorMessage,
    };
  }

  @Get(":id")
  @Render("admin/contracts")
  async detail(@Req() request: Request, @Param("id", ParseIntPipe) id: number) {
    const [contracts, selected] = await Promise.all([
      this.contractsService.findAllByCreator(null),
      this.contractsService.findOneById(id, null),
    ]);

    return {
      user: request.user,
      contracts: contracts.map(summarizeContract),
      selectedContract: buildDetail(selected),
      errorMessage: null,
    };
  }

  @Get(":id/pdf")
  async downloadPdf(
    @Param("id", ParseIntPipe) id: number,
    @Res() res: Response,
  ) {
    const contract = await this.contractsService.findOneById(id, null);
    const pdfBuffer = await this.contractPdfService.generate(contract);
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
