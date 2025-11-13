import { InboxMessage } from "../inbox-message.entity";

export class InboxMessageResponseDto {
  static fromEntity(entity: InboxMessage) {
    return {
      id: entity.id,
      kind: entity.kind,
      title: entity.title,
      body: entity.body,
      tags: entity.tags ?? [],
      isRead: Boolean(entity.isRead),
      readAt: entity.readAt ? entity.readAt.toISOString() : null,
      createdAt: entity.createdAt.toISOString(),
      updatedAt: entity.updatedAt.toISOString(),
      metadata: entity.metadata ?? null,
    };
  }
}
