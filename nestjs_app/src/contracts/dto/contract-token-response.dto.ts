import { Contract } from "../contract.entity";

export class ContractTokenResponseDto {
  id!: number;
  templateId!: number | null;
  name!: string;
  clientName!: string;
  clientContact!: string | null;
  clientEmail!: string | null;
  performerName!: string | null;
  performerEmail!: string | null;
  performerContact!: string | null;
  details!: string | null;
  metadata!: Record<string, any> | null;
  startDate!: Date | null;
  endDate!: Date | null;
  signatureToken!: string | null;
  signatureTokenExpiresAt!: Date | null;
  signatureSentAt!: Date | null;
  signatureDeclinedAt!: Date | null;
  signatureCompletedAt!: Date | null;
  signatureImage!: string | null;
  signatureSource!: string | null;
  status!: string;
  blockchainHash!: string | null;
  blockchainTxHash!: string | null;
  blockchainTimestamp!: Date | null;
  blockchainNetwork!: string | null;
  pdfHash!: string | null;

  static fromEntity(entity: Contract): ContractTokenResponseDto {
    const dto = new ContractTokenResponseDto();
    dto.id = entity.id;
    dto.templateId = entity.templateId;
    dto.name = entity.name;
    dto.clientName = entity.clientName;
    dto.clientContact = entity.clientContact;
    dto.clientEmail = entity.clientEmail;
    dto.performerName = entity.performerName;
    dto.performerEmail = entity.performerEmail;
    dto.performerContact = entity.performerContact;
    dto.details = entity.details;
    dto.metadata = (typeof entity.metadata === 'object' && entity.metadata !== null)
      ? entity.metadata as Record<string, any>
      : null;
    dto.startDate = entity.startDate;
    dto.endDate = entity.endDate;
    dto.signatureToken = entity.signatureToken;
    dto.signatureTokenExpiresAt = entity.signatureTokenExpiresAt;
    dto.signatureSentAt = entity.signatureSentAt;
    dto.signatureDeclinedAt = entity.signatureDeclinedAt;
    dto.signatureCompletedAt = entity.signatureCompletedAt;
    dto.signatureImage = entity.signatureImage;
    dto.signatureSource = entity.signatureSource;
    dto.status = entity.status;
    dto.blockchainHash = entity.blockchainHash;
    dto.blockchainTxHash = entity.blockchainTxHash;
    dto.blockchainTimestamp = entity.blockchainTimestamp;
    dto.blockchainNetwork = entity.blockchainNetwork;
    dto.pdfHash = entity.pdfHash;
    return dto;
  }
}
