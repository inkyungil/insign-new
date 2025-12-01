import {
  Injectable,
  NotFoundException,
  BadRequestException,
  Logger,
} from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { Inquiry, InquiryStatus } from "./inquiry.entity";
import { CreateInquiryDto } from "./dto/create-inquiry.dto";
import { UpdateInquiryStatusDto } from "./dto/update-inquiry-status.dto";
import { SendInquiryResponseDto } from "./dto/send-inquiry-response.dto";
import { MailService } from "../mail/mail.service";

@Injectable()
export class InquiriesService {
  private readonly logger = new Logger(InquiriesService.name);

  constructor(
    @InjectRepository(Inquiry)
    private readonly inquiryRepository: Repository<Inquiry>,
    private readonly mailService: MailService,
  ) {}

  async create(userId: number, dto: CreateInquiryDto): Promise<Inquiry> {
    const inquiry = this.inquiryRepository.create({
      userId,
      category: dto.category,
      subject: dto.subject,
      content: dto.content,
      attachmentUrls: dto.attachmentUrls || null,
      status: InquiryStatus.PENDING,
    });

    const saved = await this.inquiryRepository.save(inquiry);
    this.logger.log(`문의 접수 완료: ID=${saved.id}, User=${userId}`);

    return saved;
  }

  async findAll(page = 1, limit = 20): Promise<[Inquiry[], number]> {
    const skip = (page - 1) * limit;

    return this.inquiryRepository.findAndCount({
      relations: ["user"],
      order: { createdAt: "DESC" },
      skip,
      take: limit,
    });
  }

  async findByUser(userId: number): Promise<Inquiry[]> {
    return this.inquiryRepository.find({
      where: { userId },
      order: { createdAt: "DESC" },
    });
  }

  async findOne(id: number): Promise<Inquiry> {
    const inquiry = await this.inquiryRepository.findOne({
      where: { id },
      relations: ["user"],
    });

    if (!inquiry) {
      throw new NotFoundException("문의를 찾을 수 없습니다.");
    }

    return inquiry;
  }

  async updateStatus(
    id: number,
    dto: UpdateInquiryStatusDto,
  ): Promise<Inquiry> {
    const inquiry = await this.findOne(id);

    if (dto.status) {
      inquiry.status = dto.status;

      if (dto.status === InquiryStatus.ANSWERED) {
        inquiry.answeredAt = new Date();
      }
    }

    if (dto.adminNote !== undefined) {
      inquiry.adminNote = dto.adminNote;
    }

    return this.inquiryRepository.save(inquiry);
  }

  async sendResponse(id: number, dto: SendInquiryResponseDto): Promise<void> {
    const inquiry = await this.findOne(id);

    if (!inquiry.user?.email) {
      throw new BadRequestException("사용자 이메일을 찾을 수 없습니다.");
    }

    // 이메일 발송 (기존 MailService 확장 필요)
    await this.mailService.sendInquiryResponseMail({
      to: inquiry.user.email,
      inquirySubject: inquiry.subject,
      inquiryContent: inquiry.content,
      responseMessage: dto.message,
    });

    // 상태 업데이트
    await this.updateStatus(id, {
      status: InquiryStatus.ANSWERED,
    });

    this.logger.log(`문의 답변 발송 완료: ID=${id}`);
  }

  async remove(id: number): Promise<void> {
    const inquiry = await this.findOne(id);
    await this.inquiryRepository.remove(inquiry);
    this.logger.log(`문의 삭제: ID=${id}`);
  }
}
