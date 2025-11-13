import { BadRequestException, Injectable, Logger } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { ConfigService } from "@nestjs/config";
import { Repository } from "typeorm";
import { GoogleAuth, JWTInput } from "google-auth-library";
import { UserPushToken } from "./push-token.entity";
import { InboxService } from "../inbox/inbox.service";

const allowedPlatforms = new Set([
  "android",
  "ios",
  "macos",
  "windows",
  "linux",
  "fuchsia",
]);

@Injectable()
export class PushTokensService {
  private readonly logger = new Logger(PushTokensService.name);
  private readonly googleAuth: GoogleAuth;
  private readonly configuredProjectId?: string;

  constructor(
    @InjectRepository(UserPushToken)
    private readonly pushTokenRepository: Repository<UserPushToken>,
    private readonly configService: ConfigService,
    private readonly inboxService: InboxService,
  ) {
    const credentials = this.loadServiceAccountCredentials();
    this.googleAuth = new GoogleAuth({
      credentials,
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    });
    this.configuredProjectId = this.configService.get<string>("FCM_PROJECT_ID") ?? credentials?.project_id;
  }

  async registerToken(payload: {
    userId: number;
    token: string;
    platform?: string;
  }) {
    const normalizedToken = payload.token.trim();
    if (!normalizedToken) {
      throw new BadRequestException("유효한 FCM 토큰이 필요합니다.");
    }

    const normalizedPlatform = payload.platform
      ? payload.platform.trim().toLowerCase()
      : undefined;

    if (normalizedPlatform && !allowedPlatforms.has(normalizedPlatform)) {
      throw new BadRequestException("지원하지 않는 플랫폼입니다.");
    }

    const now = new Date();

    let existing = await this.pushTokenRepository.findOne({
      where: { token: normalizedToken },
    });

    if (!existing) {
      existing = this.pushTokenRepository.create({
        userId: payload.userId,
        token: normalizedToken,
        platform: normalizedPlatform ?? null,
        lastSeenAt: now,
      });
    } else {
      existing.userId = payload.userId;
      if (normalizedPlatform) {
        existing.platform = normalizedPlatform;
      }
      existing.lastSeenAt = now;
    }

    return this.pushTokenRepository.save(existing);
  }

  async removeToken(userId: number, token: string) {
    const normalizedToken = token.trim();
    if (!normalizedToken) {
      return;
    }

    await this.pushTokenRepository.delete({ userId, token: normalizedToken });
  }

  async findTokensByUserId(userId: number) {
    return this.pushTokenRepository.find({
      where: { userId },
      order: { updatedAt: "DESC" },
    });
  }

  async countTokensByUserIds(userIds: number[]) {
    if (!userIds.length) {
      return new Map<number, number>();
    }

    const rows = await this.pushTokenRepository
      .createQueryBuilder("token")
      .select("token.userId", "userId")
      .addSelect("COUNT(token.id)", "count")
      .where("token.userId IN (:...userIds)", { userIds })
      .groupBy("token.userId")
      .getRawMany();

    return rows.reduce((map, row) => {
      map.set(Number(row.userId), Number(row.count));
      return map;
    }, new Map<number, number>());
  }

  async sendPushMessage(
    userId: number,
    payload: {
      category: "general" | "contract";
      title: string;
      body: string;
      data?: Record<string, string>;
    },
  ) {
    const tokens = await this.findTokensByUserId(userId);
    if (!tokens.length) {
      throw new BadRequestException("등록된 푸시 토큰이 없습니다.");
    }

    const authClient = await this.googleAuth.getClient();
    const projectId = this.configuredProjectId ?? (await this.googleAuth.getProjectId());

    if (!projectId) {
      this.logger.error("FCM 프로젝트 ID를 확인할 수 없습니다.");
      throw new BadRequestException("FCM 프로젝트 ID가 설정되지 않았습니다.");
    }

    const now = new Date();
    const successes: number[] = [];
    const failures: number[] = [];

    const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

    const results = await Promise.allSettled(
      tokens.map((token) =>
        authClient.request({
          url,
          method: "POST",
          data: {
            message: {
              token: token.token,
              notification: {
                title: payload.title,
                body: payload.body,
              },
              data: {
                ...(payload.data ?? {}),
                category: payload.category,
              },
            },
          },
        }),
      ),
    );

    results.forEach((result, index) => {
      if (result.status === "fulfilled") {
        successes.push(tokens[index].id);
      } else {
        failures.push(tokens[index].id);
        this.logger.warn(
          `푸시 전송 실패 (userId=${userId}, tokenId=${tokens[index].id}): ${result.reason}`,
        );
      }
    });

    if (!successes.length) {
      throw new BadRequestException("푸시 메시지 전송에 실패했습니다.");
    }

    await this.pushTokenRepository.update(successes, { lastSeenAt: now });

    try {
      await this.inboxService.createForUser(userId, {
        kind: payload.category === "contract" ? "notice" : "system",
        title: payload.title,
        body: payload.body,
        tags: ["push", "admin", payload.category],
        metadata: {
          source: "admin",
          category: payload.category,
          sentTokenCount: successes.length,
          failedTokenCount: failures.length,
        },
      });
    } catch (error) {
      this.logger.warn(`푸시 메시지 인박스 기록 실패: ${error}`);
    }

    return {
      success: true,
      sent: successes.length,
      failure: failures.length,
    };
  }

  private loadServiceAccountCredentials(): JWTInput | undefined {
    const raw = this.configService.get<string>("FCM_SERVICE_ACCOUNT");
    if (!raw) {
      return undefined;
    }

    const parsed = this.tryParseServiceAccount(raw);
    if (!parsed.project_id) {
      this.logger.warn("서비스 계정 JSON에서 project_id를 찾을 수 없습니다.");
    }
    return parsed;
  }

  private tryParseServiceAccount(raw: string): JWTInput {
    const attempts = [raw.trim()];
    try {
      attempts.push(Buffer.from(raw.trim(), "base64").toString("utf8"));
    } catch {
      // ignore base64 decode failure
    }

    for (const candidate of attempts) {
      try {
        const json = JSON.parse(candidate);
        if (
          typeof json === "object" &&
          json !== null &&
          "private_key" in json &&
          typeof json.private_key === "string"
        ) {
          json.private_key = (json.private_key as string).replace(/\\n/g, "\n");
        }
        return json as JWTInput;
      } catch {
        // try next
      }
    }

    throw new BadRequestException("FCM 서비스 계정 JSON을 해석할 수 없습니다.");
  }
}
