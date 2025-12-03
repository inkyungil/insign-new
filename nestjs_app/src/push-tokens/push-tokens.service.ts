import { BadRequestException, Injectable, Logger } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { ConfigService } from "@nestjs/config";
import { Repository } from "typeorm";
import { GoogleAuth, JWTInput } from "google-auth-library";
import { UserPushToken } from "./push-token.entity";

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
  private readonly googleAuth!: GoogleAuth;
  private readonly configuredProjectId?: string;
  private readonly initialized: boolean = false;

  constructor(
    @InjectRepository(UserPushToken)
    private readonly pushTokenRepository: Repository<UserPushToken>,
    private readonly configService: ConfigService,
  ) {
    try {
      const credentials = this.loadServiceAccountCredentials();
      if (!credentials) {
        this.logger.warn(
          "FCM 서비스 계정이 설정되지 않았습니다. 푸시 알림이 비활성화됩니다.",
        );
        return;
      }

      this.googleAuth = new GoogleAuth({
        credentials,
        scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
      });

      this.configuredProjectId =
        this.configService.get<string>("FCM_PROJECT_ID") ??
        credentials?.project_id;

      this.initialized = true;
      this.logger.log(
        `FCM 초기화 완료 (프로젝트: ${this.configuredProjectId})`,
      );
    } catch (error) {
      this.logger.error(`FCM 초기화 실패: ${error}`);
    }
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

  async findTokensByUserIds(userIds: number[]) {
    if (!userIds.length) {
      return [];
    }

    return this.pushTokenRepository.find({
      where: userIds.map((userId) => ({ userId })),
      order: { updatedAt: "DESC" },
    });
  }

  async removeTokens(tokens: string[]) {
    if (!tokens.length) {
      return;
    }

    await this.pushTokenRepository.delete(
      tokens.map((token) => ({ token })),
    );
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
    if (!this.initialized) {
      this.logger.debug(
        "FCM이 초기화되지 않았습니다. 푸시 전송을 처리할 수 없습니다.",
      );
      throw new BadRequestException(
        "푸시 알림이 비활성화된 환경입니다. 환경 설정을 확인해 주세요.",
      );
    }

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
    const invalidTokens: string[] = [];
    let lastErrorCode: string | undefined;

    const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

    const results = await Promise.allSettled(
      tokens.map(async (token) => {
        try {
          await authClient.request({
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
          });
          successes.push(token.id);
        } catch (error: any) {
          failures.push(token.id);

          const errorCode = error?.response?.data?.error?.status;
          lastErrorCode = errorCode ?? lastErrorCode;

          this.logger.warn(
            `푸시 전송 실패 (userId=${userId}, tokenId=${
              token.id
            }, token=${token.token.slice(0, 20)}...): ${errorCode ?? error}`,
          );

          if (this.isUnrecoverableError(errorCode)) {
            invalidTokens.push(token.token);
          }
        }
      }),
    );

    const failureCount = results.filter((result) => result.status === "rejected")
      .length;

    if (invalidTokens.length > 0) {
      await this.removeTokens(invalidTokens);
      this.logger.log(
        `${invalidTokens.length}개의 유효하지 않은 푸시 토큰을 제거했습니다.`,
      );
    }

    if (!successes.length) {
      if (invalidTokens.length > 0) {
        throw new BadRequestException(
          "유효한 푸시 토큰이 없습니다. 사용자가 앱에 다시 로그인하면 토큰이 재등록됩니다.",
        );
      }

      const reason = lastErrorCode
        ? ` (FCM 오류 코드: ${lastErrorCode})`
        : "";
      throw new BadRequestException(
        `푸시 메시지 전송에 실패했습니다.${reason}`,
      );
    }

    await this.pushTokenRepository.update(successes, { lastSeenAt: now });

    return {
      success: true,
      sent: successes.length,
      failure: failureCount,
    };
  }

  private loadServiceAccountCredentials(): JWTInput | undefined {
    const raw = this.configService.get<string>("FCM_SERVICE_ACCOUNT");
    if (!raw) {
      return undefined;
    }

    try {
      const parsed = this.tryParseServiceAccount(raw);
      if (!parsed.project_id) {
        this.logger.warn("서비스 계정 JSON에서 project_id를 찾을 수 없습니다.");
      }
      return parsed;
    } catch (error) {
      this.logger.error(`FCM 서비스 계정 파싱 실패: ${error}`);
      return undefined;
    }
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

    throw new Error("FCM 서비스 계정 JSON을 파싱할 수 없습니다.");
  }

  private isUnrecoverableError(errorCode?: string): boolean {
    if (!errorCode) {
      return false;
    }

    const unrecoverableErrors = [
      "NOT_FOUND",
      "INVALID_ARGUMENT",
      "UNREGISTERED",
    ];

    return unrecoverableErrors.includes(errorCode);
  }
}
