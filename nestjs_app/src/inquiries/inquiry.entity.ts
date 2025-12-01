import {
  Column,
  CreateDateColumn,
  Entity,
  ManyToOne,
  JoinColumn,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from "typeorm";
import { User } from "../users/user.entity";

export enum InquiryCategory {
  CONTRACT = "contract", // 계약 관련
  PAYMENT = "payment", // 결제/포인트
  ACCOUNT = "account", // 계정/로그인
  TECHNICAL = "technical", // 기술 지원
  OTHER = "other", // 기타
}

export enum InquiryStatus {
  PENDING = "pending", // 대기 중
  IN_PROGRESS = "in_progress", // 처리 중
  ANSWERED = "answered", // 답변 완료
  CLOSED = "closed", // 종료
}

@Entity({ name: "inquiries" })
export class Inquiry {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ name: "user_id", type: "int" })
  userId!: number;

  @ManyToOne(() => User)
  @JoinColumn({ name: "user_id" })
  user!: User;

  @Column({
    type: "enum",
    enum: InquiryCategory,
    default: InquiryCategory.OTHER,
  })
  category!: InquiryCategory;

  @Column({ type: "varchar", length: 200 })
  subject!: string;

  @Column({ type: "text" })
  content!: string;

  @Column({
    name: "attachment_urls",
    type: "json",
    nullable: true,
  })
  attachmentUrls?: string[] | null;

  @Column({
    type: "enum",
    enum: InquiryStatus,
    default: InquiryStatus.PENDING,
  })
  status!: InquiryStatus;

  @Column({ name: "admin_note", type: "text", nullable: true })
  adminNote?: string | null;

  @Column({ name: "answered_at", type: "datetime", nullable: true })
  answeredAt?: Date | null;

  @CreateDateColumn({ name: "created_at" })
  createdAt!: Date;

  @UpdateDateColumn({ name: "updated_at" })
  updatedAt!: Date;
}
