import { Contract } from "../contract.entity";

export class ContractResponseDto {
  id!: number;
  templateId!: number | null;
  name!: string;
  clientName!: string;
  clientContact!: string | null;
  clientEmail!: string | null;
  performerName!: string | null;
  performerEmail!: string | null;
  performerContact!: string | null;
  startDate!: Date | null;
  endDate!: Date | null;
  amount!: string | null;
  details!: string | null;
  metadata!: Record<string, unknown> | null;
  status!: string;
  signatureDeclinedAt!: Date | null;
  signatureCompletedAt!: Date | null;
  signatureToken!: string | null;
  signatureSentAt!: Date | null;
  signatureImage!: string | null;
  signatureSource!: string | null;
  createdAt!: Date;
  updatedAt!: Date;
  blockchainHash!: string | null;
  blockchainTxHash!: string | null;
  blockchainTimestamp!: Date | null;
  blockchainNetwork!: string | null;
  pdfHash!: string | null;

  static fromEntity(entity: Contract): ContractResponseDto {
    const dto = new ContractResponseDto();
    dto.id = entity.id;
    dto.templateId = entity.templateId;
    dto.name = entity.name;
    dto.clientName = entity.clientName;
    dto.clientContact = entity.clientContact;
    dto.clientEmail = entity.clientEmail;
    dto.performerName = entity.performerName;
    dto.performerEmail = entity.performerEmail;
    dto.performerContact = entity.performerContact;
    dto.startDate = entity.startDate;
    dto.endDate = entity.endDate;
    dto.amount = entity.amount;
    dto.details = entity.details;
    dto.metadata = (typeof entity.metadata === 'object' && entity.metadata !== null)
      ? entity.metadata as Record<string, unknown>
      : null;
    dto.status = entity.status;
    dto.signatureDeclinedAt = entity.signatureDeclinedAt;
    dto.signatureCompletedAt = entity.signatureCompletedAt;
    dto.signatureToken = entity.signatureToken;
    dto.signatureSentAt = entity.signatureSentAt;
    dto.signatureImage = entity.signatureImage;
    dto.signatureSource = entity.signatureSource;
    dto.createdAt = entity.createdAt;
    dto.updatedAt = entity.updatedAt;
    dto.blockchainHash = entity.blockchainHash;
    dto.blockchainTxHash = entity.blockchainTxHash;
    dto.blockchainTimestamp = entity.blockchainTimestamp;
    dto.blockchainNetwork = entity.blockchainNetwork;
    dto.pdfHash = entity.pdfHash;
    return dto;
  }
}
