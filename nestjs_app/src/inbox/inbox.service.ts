import { Injectable, NotFoundException } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Brackets, Repository } from "typeorm";
import { InboxMessage } from "./inbox-message.entity";
import { CreateInboxMessageDto } from "./dto/create-inbox-message.dto";
import { UpdateInboxReadDto } from "./dto/update-inbox-read.dto";
import { EncryptionService } from "../common/encryption.service";
import { hashEmail, looksLikeEmail, normalizeEmail } from "../users/email.utils";

@Injectable()
export class InboxService {
  constructor(
    @InjectRepository(InboxMessage)
    private readonly inboxRepository: Repository<InboxMessage>,
    private readonly encryptionService: EncryptionService,
  ) {}

  async createForUser(userId: number, dto: CreateInboxMessageDto) {
    const [message] = await this.createForUsers([userId], dto);
    if (!message) {
      throw new Error("메시지를 생성하지 못했습니다.");
    }
    return message;
  }

  async createForUsers(userIds: number[], dto: CreateInboxMessageDto) {
    if (!userIds.length) {
      return [] as InboxMessage[];
    }

    const normalizedTitle = dto.title.trim();
    const normalizedBody = dto.body.trim();
    const tags = dto.tags?.length ? dto.tags : [];
    const metadata = dto.metadata ?? null;

    const entities = userIds.map((userId) =>
      this.inboxRepository.create({
        userId,
        kind: dto.kind,
        title: normalizedTitle,
        body: normalizedBody,
        tags,
        metadata,
        isRead: false,
        readAt: null,
      }),
    );

    const saved = await this.inboxRepository.save(entities);
    return saved.map((message) => this.decryptMessageUser(message));
  }

  async findAllForUser(userId: number) {
    const messages = await this.inboxRepository.find({
      where: { userId },
      order: { createdAt: "DESC" },
    });
    return messages.map((message) => this.decryptMessageUser(message));
  }

  async findAllForAdmin(options: {
    userId?: number;
    search?: string;
    kind?: InboxMessage["kind"] | "all";
    isRead?: "all" | "read" | "unread";
    limit?: number;
    offset?: number;
  }) {
    const qb = this.inboxRepository
      .createQueryBuilder("message")
      .leftJoinAndSelect("message.user", "user")
      .orderBy("message.createdAt", "DESC");

    if (options.userId) {
      qb.andWhere("message.userId = :userId", { userId: options.userId });
    }

    if (options.kind && options.kind !== "all") {
      qb.andWhere("message.kind = :kind", { kind: options.kind });
    }

    if (options.isRead === "read") {
      qb.andWhere("message.isRead = true");
    } else if (options.isRead === "unread") {
      qb.andWhere("message.isRead = false");
    }

    if (options.search) {
      const trimmed = options.search.trim();
      if (trimmed) {
        const wildcard = `%${trimmed}%`;
        qb.andWhere(
          new Brackets((expr) => {
            expr
              .where("message.title LIKE :search", { search: wildcard })
              .orWhere("message.body LIKE :search", { search: wildcard });

            if (looksLikeEmail(trimmed)) {
              expr.orWhere("user.emailHash = :emailHash", {
                emailHash: hashEmail(normalizeEmail(trimmed)),
              });
            }
          }),
        );
      }
    }

    if (typeof options.limit === "number" && options.limit > 0) {
      qb.take(options.limit);
    }

    if (typeof options.offset === "number" && options.offset >= 0) {
      qb.skip(options.offset);
    }

    const messages = await qb.getMany();
    return messages.map((message) => this.decryptMessageUser(message));
  }

  async countSummary() {
    const [total, unread] = await Promise.all([
      this.inboxRepository.count(),
      this.inboxRepository.count({ where: { isRead: false } }),
    ]);

    return { total, unread };
  }

  async markRead(id: number, userId: number, dto: UpdateInboxReadDto) {
    const entity = await this.inboxRepository.findOne({
      where: { id, userId },
    });

    if (!entity) {
      throw new NotFoundException("메시지를 찾을 수 없습니다.");
    }

    entity.isRead = dto.isRead;
    entity.readAt = dto.isRead ? new Date() : null;

    const saved = await this.inboxRepository.save(entity);
    return this.decryptMessageUser(saved);
  }

  async remove(id: number, userId: number) {
    const entity = await this.inboxRepository.findOne({
      where: { id, userId },
    });

    if (!entity) {
      throw new NotFoundException("메시지를 찾을 수 없습니다.");
    }

    await this.inboxRepository.remove(entity);
  }

  async setReadState(id: number, isRead: boolean) {
    const entity = await this.inboxRepository.findOne({ where: { id } });

    if (!entity) {
      throw new NotFoundException("메시지를 찾을 수 없습니다.");
    }

    entity.isRead = isRead;
    entity.readAt = isRead ? new Date() : null;

    const saved = await this.inboxRepository.save(entity);
    return this.decryptMessageUser(saved);
  }

  async removeById(id: number) {
    const entity = await this.inboxRepository.findOne({ where: { id } });

    if (!entity) {
      throw new NotFoundException("메시지를 찾을 수 없습니다.");
    }

    await this.inboxRepository.remove(entity);
  }

  private decryptMessageUser(message: InboxMessage): InboxMessage {
    if (message.user?.email) {
      try {
        message.user.email = this.encryptionService.decrypt(message.user.email);
      } catch {
        // ignore legacy values that cannot be decrypted
      }
    }
    return message;
  }
}
