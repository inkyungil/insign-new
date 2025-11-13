import { Injectable } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { existsSync, promises as fs } from "fs";
import { join } from "path";
import PDFDocument = require("pdfkit");
import { Contract } from "./contract.entity";
import { Template } from "../templates/template.entity";
import { DocxTemplateService } from "../templates/docx-template.service";
import { PdfConverterService } from "../templates/pdf-converter.service";
import { HtmlPdfService } from "../templates/html-pdf.service";

@Injectable()
export class ContractPdfService {
  constructor(
    @InjectRepository(Template)
    private readonly templateRepository: Repository<Template>,
    private readonly docxTemplateService: DocxTemplateService,
    private readonly pdfConverterService: PdfConverterService,
    private readonly htmlPdfService: HtmlPdfService,
  ) {}

  async generate(contract: Contract): Promise<Buffer> {
    let template: Template | null = null;
    if (contract.templateId) {
      template = await this.templateRepository.findOne({
        where: { id: contract.templateId },
      });

      if (template?.filePath) {
        return this.generateFromDocx(contract, template);
      }
    }

    const metadata = this.extractMetadata(contract);
    const htmlContent = await this.resolveHtmlContent(contract, template, metadata);
    if (htmlContent) {
      return this.generateFromHtml(htmlContent);
    }

    return this.generateLegacy(contract);
  }

  private async resolveHtmlContent(
    contract: Contract,
    template: Template | null,
    metadata: ReturnType<typeof this.extractMetadata>,
  ): Promise<string | null> {
    const metadataContent = this.readString(contract.metadata, "templateRawContent");
    const templateContent = template?.content ?? null;
    const detailsContent = contract.details ?? null;

    const raw = metadataContent ?? templateContent ?? detailsContent;
    if (!raw || !raw.trim()) {
      return null;
    }

    const placeholders = await this.buildHtmlPlaceholders(contract, metadata);
    const filled = this.replacePlaceholders(raw, placeholders);
    return this.wrapHtmlDocument(filled);
  }

  /**
   * DOCX 템플릿으로 PDF 생성
   */
  private async generateFromDocx(
    contract: Contract,
    template: Template,
  ): Promise<Buffer> {
    try {
      // 플레이스홀더에 채울 데이터 준비
      const data = this.prepareTemplateData(contract);

      // DOCX 파일에 데이터 채우기
      const docxBuffer = await this.docxTemplateService.fillTemplate(
        template.filePath!,
        data,
      );

      // DOCX → PDF 변환
      const pdfBuffer = await this.pdfConverterService.convertToPdf(docxBuffer);

      return pdfBuffer;
    } catch (error) {
      if (error instanceof Error) {
        throw new Error(`DOCX 템플릿 PDF 생성 실패: ${error.message}`);
      }
      throw new Error("PDF 생성 중 알 수 없는 오류 발생");
    }
  }

  private async generateFromHtml(html: string): Promise<Buffer> {
    try {
      return await this.htmlPdfService.render(html, {
        format: "A4",
        margin: { top: "8mm", bottom: "18mm", left: "16mm", right: "16mm" },
      });
    } catch (error) {
      if (error instanceof Error) {
        throw new Error(`HTML 템플릿 PDF 생성 실패: ${error.message}`);
      }
      throw new Error("HTML 템플릿 PDF 생성 중 알 수 없는 오류 발생");
    }
  }

  /**
   * 계약서 데이터를 템플릿 플레이스홀더 형식으로 변환
   */
  private prepareTemplateData(contract: Contract): Record<string, unknown> {
    const metadata = this.extractMetadata(contract);

    const baseData: Record<string, unknown> = {
      // 계약서 기본 정보
      contractId: contract.id,
      contractName: contract.name,
      contractStatus: metadata.statusLabel,
      createdAt: this.formatDate(contract.createdAt),
      updatedAt: this.formatDate(contract.updatedAt),

      // 고객 정보
      clientName: contract.clientName,
      clientEmail: contract.clientEmail,
      clientContact: contract.clientContact,

      // 수행자 정보
      performerName: contract.performerName,
      performerEmail: contract.performerEmail,
      performerContact: contract.performerContact,

      // 서명 정보
      signatureSentAt: this.formatDate(contract.signatureSentAt),
      signatureCompletedAt: this.formatDate(contract.signatureCompletedAt),
      signatureDeclinedAt: this.formatDate(contract.signatureDeclinedAt),

      // 템플릿 정보
      templateName: metadata.templateName,
      templateSchemaVersion: metadata.templateSchemaVersion,
    };

    // 사용자 입력 데이터 병합 (contract.metadata)
    const metadataRecord = this.parseRecord(contract.metadata);
    if (metadataRecord) {
      this.propagateSignatureAliasesUnknown(metadataRecord);

      const recipientValues = this.parseRecord(metadataRecord["recipientFormValues"]);
      if (recipientValues) {
        Object.assign(baseData, recipientValues);
      }

      const templateValues = this.parseRecord(metadataRecord["templateFormValues"]);
      if (templateValues) {
        Object.assign(baseData, templateValues);
      }

      Object.entries(metadataRecord).forEach(([key, value]) => {
        if (/signature/i.test(key) && value !== undefined) {
          baseData[key] = value;
        }
      });
    }

    this.propagateSignatureAliasesUnknown(baseData);

    // 데이터 정규화 (null, undefined 처리)
    return this.docxTemplateService.normalizeData(baseData);
  }

  private async buildHtmlPlaceholders(
    contract: Contract,
    metadata: ReturnType<typeof this.extractMetadata>,
  ): Promise<Record<string, string>> {
    const basePlaceholders = this.buildPlaceholderMap(contract, metadata);
    const result = { ...basePlaceholders };

    const templateValues = this.readObject(contract.metadata, "templateFormValues");
    const recipientValues = this.readObject(contract.metadata, "recipientFormValues");
    const metadataObject = this.parseRecord(contract.metadata);

    this.mergeContractPartyPlaceholders(result, contract);

    await this.injectSignaturePlaceholders(result, [
      metadataObject,
      templateValues,
      recipientValues,
    ]);

    const performerTag = await this.resolveSignatureTag(contract.signatureImage);
    if (performerTag) {
      const performerKeys = [
        "signatureImage",
        "performerSignature",
        "performerSignatureImage",
        "borrowerSignature",
        "borrowerSignatureImage",
      ];
      performerKeys.forEach((key) => {
        result[key] = performerTag;
      });
    }

    this.propagateSignatureAliasesStrings(result);

    return result;
  }

  private mergeContractPartyPlaceholders(
    target: Record<string, string>,
    contract: Contract,
  ) {
    const metadataRecord = this.parseRecord(contract.metadata);

    const assign = (key: string, value: unknown) => {
      const normalized = this.normalizePlaceholderValue(value);
      if (normalized !== null) {
        target[key] = normalized;
      }
    };

    assign("contractName", contract.name);
    assign("clientName", contract.clientName);
    assign("clientContact", contract.clientContact);
    assign("clientEmail", contract.clientEmail);
    assign("performerName", contract.performerName);
    assign("performerContact", contract.performerContact);
    assign("performerEmail", contract.performerEmail);

    assign("lenderName", contract.clientName);
    assign("lenderContact", contract.clientContact);
    assign("lenderEmail", contract.clientEmail);
    assign("borrowerName", contract.performerName);
    assign("borrowerContact", contract.performerContact);
    assign("borrowerEmail", contract.performerEmail);

    const clientSignedAt = this.firstNonEmpty([
      this.lookupString(metadataRecord, [
        "clientSignatureDate",
        "clientSignDate",
        "lenderSignDate",
        "employerSignDate",
      ]),
      this.normalizePlaceholderValue(contract.signatureCompletedAt),
    ]);
    if (clientSignedAt) {
      assign("clientSignatureDate", clientSignedAt);
      assign("clientSignDate", clientSignedAt);
      assign("lenderSignDate", clientSignedAt);
      assign("employerSignDate", clientSignedAt);
    }

    const performerSignedAt = this.firstNonEmpty([
      this.lookupString(metadataRecord, [
        "employeeSignatureDate",
        "employeeSignDate",
        "performerSignDate",
        "borrowerSignDate",
      ]),
      this.normalizePlaceholderValue(contract.signatureCompletedAt),
    ]);
    if (performerSignedAt) {
      assign("employeeSignatureDate", performerSignedAt);
      assign("employeeSignDate", performerSignedAt);
      assign("performerSignDate", performerSignedAt);
      assign("borrowerSignDate", performerSignedAt);
    }

    this.propagateSignatureAliasesStrings(target);
  }

  private firstNonEmpty(values: Array<string | null>): string | null {
    for (const value of values) {
      if (value && value.trim().length > 0 && value !== "-") {
        return value;
      }
    }
    return null;
  }

  private lookupString(
    source: Record<string, unknown> | null,
    keys: string[],
  ): string | null {
    if (!source) {
      return null;
    }
    for (const key of keys) {
      const value = source[key];
      const normalized = this.normalizePlaceholderValue(value);
      if (normalized !== null) {
        return normalized;
      }
    }
    return null;
  }

  private propagateSignatureAliasesStrings(target: Record<string, string>) {
    const groups = [
      [
        "authorSignature",
        "authorSignatureImage",
        "clientSignature",
        "clientSignatureImage",
        "lenderSignature",
        "lenderSignatureImage",
        "employerSignature",
        "employerSignatureImage",
      ],
      [
        "employeeSignature",
        "employeeSignatureImage",
        "performerSignature",
        "performerSignatureImage",
        "borrowerSignature",
        "borrowerSignatureImage",
      ],
    ];

    for (const group of groups) {
      const sourceValue = group
        .map((key) => target[key])
        .find((value) => value && value.trim().length > 0);

      if (!sourceValue) {
        continue;
      }

      for (const key of group) {
        if (!target[key] || target[key].trim().length === 0) {
          target[key] = sourceValue;
        }
      }
    }
  }

  private propagateSignatureAliasesUnknown(target: Record<string, unknown>) {
    const groups = [
      [
        "authorSignature",
        "authorSignatureImage",
        "clientSignature",
        "clientSignatureImage",
        "lenderSignature",
        "lenderSignatureImage",
        "employerSignature",
        "employerSignatureImage",
      ],
      [
        "employeeSignature",
        "employeeSignatureImage",
        "performerSignature",
        "performerSignatureImage",
        "borrowerSignature",
        "borrowerSignatureImage",
      ],
    ];

    for (const group of groups) {
      const sourceEntry = group
        .map((key) => target[key])
        .find(
          (value) =>
            typeof value === "string" && value.trim().length > 0,
        ) as string | undefined;

      if (!sourceEntry) {
        continue;
      }

      for (const key of group) {
        const current = target[key];
        if (typeof current !== "string" || current.trim().length === 0) {
          target[key] = sourceEntry;
        }
      }
    }
  }

  private async injectSignaturePlaceholders(
    target: Record<string, string>,
    sources: Array<Record<string, unknown> | null>,
  ) {
    const signaturePattern = /signature/i;

    for (const source of sources) {
      if (!source) {
        continue;
      }

      for (const [key, value] of Object.entries(source)) {
        if (!signaturePattern.test(key)) {
          continue;
        }
        const tag = await this.resolveSignatureTag(value);
        if (tag) {
          target[key] = tag;
        }
      }
    }
  }

  private async resolveSignatureTag(value: unknown): Promise<string | null> {
    const dataUrl = await this.resolveSignatureDataUrl(value);
    if (!dataUrl) {
      if (typeof value === "string" && value.trim().startsWith("<img")) {
        return value.trim();
      }
      return null;
    }
    return this.signatureImgTag(dataUrl);
  }

  private async resolveSignatureDataUrl(value: unknown): Promise<string | null> {
    if (!value) {
      return null;
    }

    const queue: unknown[] = [value];

    while (queue.length > 0) {
      const current = queue.shift();
      if (!current) {
        continue;
      }

      if (typeof current === "string") {
        const trimmed = current.trim();
        if (!trimmed) {
          continue;
        }

        if (trimmed.startsWith("<img")) {
          const match = trimmed.match(/src\s*=\s*"([^"]+)"/i);
          if (match?.[1]) {
            return match[1].trim();
          }
          continue;
        }

        if (trimmed.startsWith("data:image/")) {
          return trimmed;
        }

        if (trimmed.startsWith("{") && trimmed.endsWith("}")) {
          try {
            const parsed = JSON.parse(trimmed);
            queue.push(parsed);
            continue;
          } catch {
            // ignore invalid JSON and keep fallback behaviour
          }
        }

        if (/^[A-Za-z0-9+/=\s]+$/.test(trimmed) && trimmed.length > 40) {
          const normalized = trimmed.replace(/\s+/g, "");
          return `data:image/png;base64,${normalized}`;
        }

        if (/^https?:\/\//i.test(trimmed)) {
          return trimmed;
        }

        const dataUrl = await this.readPublicAssetAsDataUrl(trimmed);
        if (dataUrl) {
          return dataUrl;
        }

        continue;
      }

      if (Array.isArray(current)) {
        queue.push(...current);
        continue;
      }

      if (typeof current === "object") {
        const record = current as Record<string, unknown>;
        for (const key of Object.keys(record)) {
          queue.push(record[key]);
        }
        const candidate = await this.extractKnownSignatureProps(record);
        if (candidate) {
          return candidate;
        }
      }
    }

    return null;
  }

  private async extractKnownSignatureProps(
    obj: Record<string, unknown>,
  ): Promise<string | null> {
    const candidates = [
      obj.dataUrl,
      obj.dataURL,
      obj.data_uri,
      obj.data,
      obj.value,
      obj.canvas,
      obj.image,
      obj.src,
      obj.path,
      obj.url,
    ];

    for (const candidate of candidates) {
      if (typeof candidate !== "string") {
        continue;
      }
      const trimmed = candidate.trim();
      if (!trimmed) {
        continue;
      }
      if (trimmed.startsWith("data:image/")) {
        return trimmed;
      }
      if (trimmed.startsWith("<img")) {
        const match = trimmed.match(/src\s*=\s*"([^"]+)"/i);
        if (match?.[1]) {
          return match[1].trim();
        }
        continue;
      }
      if (/^https?:\/\//i.test(trimmed)) {
        return trimmed;
      }
      const dataUrl = await this.readPublicAssetAsDataUrl(trimmed);
      if (dataUrl) {
        return dataUrl;
      }
    }

    return null;
  }

  private async readPublicAssetAsDataUrl(pathLike: string): Promise<string | null> {
    if (!pathLike || typeof pathLike !== "string") {
      return null;
    }

    const trimmed = pathLike.trim();
    if (!trimmed || trimmed.startsWith("data:")) {
      return null;
    }

    if (/^https?:\/\//i.test(trimmed)) {
      return trimmed; // allow external URLs as-is
    }

    let relative = trimmed.replace(/^\/+/, "");
    if (relative.startsWith("static/")) {
      relative = relative.slice("static/".length);
    }

    const absolutePath = join(process.cwd(), "public", relative);
    try {
      const buffer = await fs.readFile(absolutePath);
      const extension = relative.split(".").pop()?.toLowerCase();
      const mime =
        extension === "jpg" || extension === "jpeg"
          ? "image/jpeg"
          : "image/png";
      return `data:${mime};base64,${buffer.toString("base64")}`;
    } catch {
      return null;
    }
  }

  private signatureImgTag(dataUrl: string) {
    return `<div style="width:100%;padding:6px 0;text-align:center;">` +
      `<img src="${dataUrl}" style="display:inline-block;width:100%;max-width:220px !important;height:auto !important;object-fit:contain;" />` +
      `</div>`;
  }

  private wrapHtmlDocument(content: string): string {
    const trimmed = content.trim();
    const hasHtmlTag = /<html[\s>]/i.test(trimmed);
    if (hasHtmlTag) {
      return trimmed;
    }

    const baseCss = `body{margin:0;padding:12px 18px 20px;font-family:'Pretendard','Noto Sans KR',sans-serif;color:#1b2733;font-size:13px;line-height:1.65;} body .contract-page{margin-top:0 !important;} body .contract-page header:first-of-type{padding-top:8px !important;margin-top:0 !important;} img{max-width:100%;height:auto;display:block;} table{border-collapse:collapse;width:100%;}`;
    const htmlContent = /<[^>]+>/.test(trimmed)
      ? trimmed
      : `<pre style="white-space:pre-wrap;font-family:inherit;">${trimmed.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")}</pre>`;

    return `<!DOCTYPE html><html lang="ko"><head><meta charset="utf-8" /><style>${baseCss}</style></head><body>${htmlContent}</body></html>`;
  }

  /**
   * 기존 PDFKit 방식 (레거시)
   */
  private async generateLegacy(contract: Contract): Promise<Buffer> {
    return new Promise<Buffer>((resolve, reject) => {
      const doc = new PDFDocument({ size: "A4", margin: 56 });
      const chunks: Buffer[] = [];

      doc.on("data", (chunk) => chunks.push(chunk as Buffer));
      doc.on("end", () => resolve(Buffer.concat(chunks)));
      doc.on("error", reject);

      this.renderDocument(doc, contract);
      doc.end();
    });
  }

  private renderDocument(doc: PDFDocument, contract: Contract) {
    const metadata = this.extractMetadata(contract);
    const placeholders = this.buildPlaceholderMap(contract, metadata);

    this.applyFont(doc);

    doc.fontSize(18).text(this.replacePlaceholders("계약서", placeholders), {
      align: "center",
    });
    doc.moveDown(0.5);
    doc
      .fontSize(16)
      .text(this.replacePlaceholders(contract.name ?? "", placeholders), {
        align: "center",
      });
    doc.moveDown(1.5);

    doc.fontSize(11);
    doc.text(
      this.replacePlaceholders(`계약 ID: ${contract.id}`, placeholders),
    );
    const templateLine = `템플릿: ${metadata.templateName}${
      metadata.templateSchemaVersion
        ? ` (v${metadata.templateSchemaVersion})`
        : ""
    }`;
    doc.text(this.replacePlaceholders(templateLine, placeholders));
    doc.text(
      this.replacePlaceholders(`상태: ${metadata.statusLabel}`, placeholders),
    );
    doc.text(
      this.replacePlaceholders(
        `작성일: ${this.formatDate(contract.createdAt)}`,
        placeholders,
      ),
    );
    doc.text(
      this.replacePlaceholders(
        `수정일: ${this.formatDate(contract.updatedAt)}`,
        placeholders,
      ),
    );
    doc.moveDown();

    this.renderPartySection(
      doc,
      "고객",
      {
        name: contract.clientName,
        email: contract.clientEmail,
        contact: contract.clientContact,
      },
      placeholders,
    );
    doc.moveDown(0.5);
    this.renderPartySection(
      doc,
      "수행자",
      {
        name: contract.performerName,
        email: contract.performerEmail,
        contact: contract.performerContact,
      },
      placeholders,
    );
    doc.moveDown();

    doc.text(
      this.replacePlaceholders(
        `서명 토큰: ${contract.signatureToken ?? "-"}`,
        placeholders,
      ),
    );
    doc.text(
      this.replacePlaceholders(
        `서명 요청: ${this.formatDate(contract.signatureSentAt)}`,
        placeholders,
      ),
    );
    doc.text(
      this.replacePlaceholders(
        `서명 완료: ${this.formatDate(contract.signatureCompletedAt)}`,
        placeholders,
      ),
    );
    doc.text(
      this.replacePlaceholders(
        `서명 거절: ${this.formatDate(contract.signatureDeclinedAt)}`,
        placeholders,
      ),
    );
    doc.text(
      this.replacePlaceholders(
        `서명 방식: ${contract.signatureSource ?? "-"}`,
        placeholders,
      ),
    );
    doc.moveDown();

    if (metadata.recipientEntries.length) {
      doc
        .fontSize(12)
        .text(this.replacePlaceholders("추가 입력값", placeholders), {
          underline: true,
        });
      doc.moveDown(0.3);
      metadata.recipientEntries.forEach(({ key, value }) => {
        doc
          .fontSize(10)
          .text(
            this.replacePlaceholders(`${key}: ${value}`, placeholders),
          );
      });
      doc.moveDown();
    }

    if (contract.details) {
      doc
        .fontSize(12)
        .text(this.replacePlaceholders("계약 본문", placeholders), {
          underline: true,
        });
      doc.moveDown(0.3);
      const plain = this.htmlToPlainText(contract.details, placeholders);
      doc.fontSize(10).text(plain, {
        align: "left",
      });
      doc.moveDown();
    }

    const signatureData = this.extractSignatureImage(contract.signatureImage ?? null);
    if (signatureData) {
      doc.addPage();
      doc
        .fontSize(14)
        .text(this.replacePlaceholders("서명 이미지", placeholders), {
          underline: true,
        });
      doc.moveDown();
      try {
        doc.image(signatureData.buffer, {
          fit: [400, 200],
          align: "left",
        });
      } catch {
        doc
          .fontSize(10)
          .text(
            this.replacePlaceholders(
              "서명 이미지를 불러오지 못했습니다.",
              placeholders,
            ),
          );
      }
      doc.moveDown();
      doc
        .fontSize(10)
        .text(
          this.replacePlaceholders(
            `원본 형식: ${signatureData.mime}`,
            placeholders,
          ),
        );
    }
  }

  private renderPartySection(
    doc: PDFDocument,
    title: string,
    party: {
      name: string | null | undefined;
      email: string | null | undefined;
      contact: string | null | undefined;
    },
    placeholders: Record<string, string>,
  ) {
    doc
      .fontSize(12)
      .text(this.replacePlaceholders(title, placeholders), { underline: true });
    doc.moveDown(0.2);
    doc
      .fontSize(10)
      .text(
        this.replacePlaceholders(`이름: ${party.name ?? "-"}`, placeholders),
      );
    doc
      .fontSize(10)
      .text(
        this.replacePlaceholders(
          `이메일: ${party.email ?? "-"}`,
          placeholders,
        ),
      );
    doc
      .fontSize(10)
      .text(
        this.replacePlaceholders(
          `연락처: ${party.contact ?? "-"}`,
          placeholders,
        ),
      );
  }

  private htmlToPlainText(
    html: string,
    placeholders: Record<string, string>,
  ): string {
    const plain = html
      .replace(/[\r\n]+/g, "\n")
      .replace(/<\s*br\s*\/?\s*>/gi, "\n")
      .replace(/<\/(p|div|li|tr|table|h[1-6])>/gi, "\n")
      .replace(/<[^>]+>/g, "")
      .replace(/&nbsp;/gi, " ")
      .replace(/&amp;/gi, "&")
      .replace(/&lt;/gi, "<")
      .replace(/&gt;/gi, ">")
      .replace(/&quot;/gi, '"')
      .replace(/&#39;/gi, "'")
      .replace(/\u00a0/g, " ")
      .replace(/\n{3,}/g, "\n\n")
      .trim();

    return this.replacePlaceholders(plain, placeholders);
  }

  private applyFont(doc: PDFDocument) {
    const candidates = [
      join(process.cwd(), "public", "fonts", "NotoSansKR-Regular.otf"),
      join(process.cwd(), "public", "fonts", "NotoSansKR-Regular.ttf"),
      join(process.cwd(), "public", "fonts", "Pretendard-Regular.otf"),
      join(process.cwd(), "public", "fonts", "Pretendard-Regular.ttf"),
      join(process.cwd(), "fonts", "NotoSansKR-Regular.otf"),
      join(process.cwd(), "fonts", "NotoSansKR-Regular.ttf"),
    ];

    const found = candidates.find((path) => existsSync(path));
    if (found) {
      doc.font(found);
    } else {
      console.warn(
        "[ContractPdfService] 한글 폰트를 찾지 못했습니다. public/fonts/NotoSansKR-Regular.otf 등을 추가해 주세요.",
      );
      doc.font("Helvetica");
    }
  }

  private buildPlaceholderMap(
    contract: Contract,
    metadata: ReturnType<typeof this.extractMetadata>,
  ) {
    const placeholders: Record<string, string> = {};
    const set = (key: string, value: unknown) => {
      const normalized = this.normalizePlaceholderValue(value);
      if (normalized !== null) {
        placeholders[key] = normalized;
      }
    };

    set("contractId", contract.id);
    set("contractName", contract.name);
    set("templateName", metadata.templateName);
    set("templateSchemaVersion", metadata.templateSchemaVersion);
    set("status", contract.status);
    set("statusLabel", metadata.statusLabel);
    set("clientName", contract.clientName);
    set("clientEmail", contract.clientEmail);
    set("clientContact", contract.clientContact);
    set("performerName", contract.performerName);
    set("performerEmail", contract.performerEmail);
    set("performerContact", contract.performerContact);
    set("startDate", this.formatDate(contract.startDate ?? null));
    set("endDate", this.formatDate(contract.endDate ?? null));
    set("amount", contract.amount);
    set("signatureToken", contract.signatureToken);
    set("signatureSentAt", this.formatDate(contract.signatureSentAt));
    set(
      "signatureCompletedAt",
      this.formatDate(contract.signatureCompletedAt),
    );
    set("signatureDeclinedAt", this.formatDate(contract.signatureDeclinedAt));
    set("signatureSource", contract.signatureSource);
    set("details", contract.details);

    Object.entries(metadata.templateValues).forEach(([key, value]) =>
      set(key, value),
    );
    metadata.recipientEntries.forEach(({ key, value }) => set(key, value));

    this.mergeContractPartyPlaceholders(placeholders, contract);

    return placeholders;
  }

  private replacePlaceholders(
    text: string,
    placeholders: Record<string, string>,
  ) {
    if (!text || !text.includes("{{")) {
      return text;
    }
    return text.replace(/{{\s*([^{}]+?)\s*}}/g, (match, key) => {
      const normalizedKey = key.trim();
      const value = placeholders[normalizedKey];
      return value !== undefined ? value : "";
    });
  }

  private normalizePlaceholderValue(value: unknown): string | null {
    if (value === null || value === undefined) {
      return null;
    }
    if (value instanceof Date) {
      return this.formatDate(value);
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

  private extractSignatureImage(signatureImage: string | null) {
    if (!signatureImage) {
      return null;
    }
    const dataUrlPattern = /^data:(image\/(?:png|jpeg|jpg));base64,(.+)$/i;
    const match = signatureImage.match(dataUrlPattern);
    if (match) {
      const [, mime, data] = match;
      try {
        return {
          mime,
          buffer: Buffer.from(data, "base64"),
        };
      } catch {
        return null;
      }
    }

    return null;
  }

  private formatDate(value?: Date | string | null) {
    if (!value) {
      return "-";
    }
    const date = value instanceof Date ? value : new Date(value);
    if (Number.isNaN(date.getTime())) {
      return "-";
    }
    try {
      return date.toISOString().replace("T", " ").slice(0, 19);
    } catch {
      return date.toLocaleString();
    }
  }

  private extractMetadata(contract: Contract) {
    const statusLabelMap: Record<string, string> = {
      draft: "작성 중",
      active: "서명 대기",
      signature_completed: "서명 완료",
      signature_declined: "서명 거절",
    };

    const templateName = this.readString(contract.metadata, "templateName") ?? "-";
    const templateSchemaVersion = this.readNumber(contract.metadata, "templateSchemaVersion");

    const templateValuesSource = this.readObject(
      contract.metadata,
      "templateFormValues",
    );
    const templateValues: Record<string, string> = templateValuesSource
      ? Object.entries(templateValuesSource).reduce((acc, [key, value]) => {
          const normalized = this.normalizePlaceholderValue(value);
          if (normalized !== null) {
            acc[key] = normalized;
          }
          return acc;
        }, {} as Record<string, string>)
      : {};

    const recipientEntries = this.readObject(
      contract.metadata,
      "recipientFormValues",
    );
    const formattedEntries = recipientEntries
      ? Object.entries(recipientEntries).map(([key, value]) => ({
          key,
          value: value === null || value === undefined ? "" : String(value),
        }))
      : [];

    return {
      templateName,
      templateSchemaVersion,
      statusLabel: statusLabelMap[contract.status] ?? contract.status,
      templateValues,
      recipientEntries: formattedEntries,
    };
  }

  private readString(source: unknown, key: string) {
    if (!source || typeof source !== "object") {
      return null;
    }
    const value = (source as Record<string, unknown>)[key];
    return typeof value === "string" && value.trim() ? value : null;
  }

  private readNumber(source: unknown, key: string) {
    if (!source || typeof source !== "object") {
      return null;
    }
    const value = (source as Record<string, unknown>)[key];
    if (typeof value === "number") {
      return value;
    }
    if (typeof value === "string") {
      const parsed = Number(value);
      return Number.isFinite(parsed) ? parsed : null;
    }
    return null;
  }

  private readObject(source: unknown, key: string) {
    const container = this.parseRecord(source);
    if (!container) {
      return null;
    }
    const value = container[key];
    return this.parseRecord(value);
  }

  private parseRecord(value: unknown): Record<string, unknown> | null {
    if (!value) {
      return null;
    }
    if (typeof value === "object" && !Array.isArray(value)) {
      return value as Record<string, unknown>;
    }
    if (typeof value === "string") {
      const trimmed = value.trim();
      if (!trimmed.startsWith("{") || !trimmed.endsWith("}")) {
        return null;
      }
      try {
        const parsed = JSON.parse(trimmed);
        if (parsed && typeof parsed === "object" && !Array.isArray(parsed)) {
          return parsed as Record<string, unknown>;
        }
      } catch {
        return null;
      }
    }
    return null;
  }
}
