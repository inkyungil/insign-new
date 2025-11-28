import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { GoogleAuth, JWTInput } from 'google-auth-library';
import { PushTokensService } from './push-tokens.service';

interface InboxNotificationPayload {
  userIds: number[];
  title: string;
  body: string;
  messageIds: number[];
  kind: string;
}

interface ContractNotificationPayload {
  userId: number;
  title: string;
  body: string;
  contractId: number;
  contractName: string;
}

@Injectable()
export class PushNotificationsService {
  private readonly logger = new Logger(PushNotificationsService.name);
  private readonly googleAuth!: GoogleAuth;
  private readonly configuredProjectId?: string;
  private readonly initialized: boolean = false;

  constructor(
    private readonly configService: ConfigService,
    private readonly pushTokensService: PushTokensService,
  ) {
    try {
      const credentials = this.loadServiceAccountCredentials();
      if (!credentials) {
        this.logger.warn(
          'FCM 서비스 계정이 설정되지 않았습니다. 푸시 알림이 비활성화됩니다.',
        );
        return;
      }

      this.googleAuth = new GoogleAuth({
        credentials,
        scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
      });

      this.configuredProjectId =
        this.configService.get<string>('FCM_PROJECT_ID') ??
        credentials?.project_id;

      this.initialized = true;
      this.logger.log(
        `FCM 초기화 완료 (프로젝트: ${this.configuredProjectId})`,
      );
    } catch (error) {
      this.logger.error(`FCM 초기화 실패: ${error}`);
    }
  }

  async sendContractCompletedNotification(payload: ContractNotificationPayload) {
    if (!this.initialized) {
      this.logger.debug('FCM이 초기화되지 않았습니다. 푸시 전송을 건너뜁니다.');
      return;
    }

    const tokens = await this.pushTokensService.findTokensByUserIds([
      payload.userId,
    ]);

    if (!tokens.length) {
      this.logger.debug('등록된 FCM 토큰이 없습니다.');
      return;
    }

    const trimmedBody =
      payload.body.length > 128
        ? `${payload.body.slice(0, 125)}...`
        : payload.body;

    const authClient = await this.googleAuth.getClient();
    const projectId =
      this.configuredProjectId ?? (await this.googleAuth.getProjectId());

    if (!projectId) {
      this.logger.error('FCM 프로젝트 ID를 확인할 수 없습니다.');
      return;
    }

    const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
    const invalidTokens: string[] = [];
    let successCount = 0;

    const results = await Promise.allSettled(
      tokens.map(async (token) => {
        try {
          await authClient.request({
            url,
            method: 'POST',
            data: {
              message: {
                token: token.token,
                notification: {
                  title: payload.title,
                  body: trimmedBody,
                },
                data: {
                  type: 'contract_completed',
                  contractId: payload.contractId.toString(),
                  contractName: payload.contractName,
                },
                android: {
                  priority: 'high',
                  notification: {
                    channelId: 'contract_updates',
                    sound: 'default',
                  },
                },
                apns: {
                  payload: {
                    aps: {
                      sound: 'default',
                      'content-available': 1,
                    },
                  },
                },
              },
            },
          });
          successCount++;
        } catch (error: any) {
          const errorCode = error?.response?.data?.error?.status;
          this.logger.warn(
            `푸시 전송 실패 (token: ${token.token.slice(0, 20)}...): ${errorCode}`,
          );

          if (this.isUnrecoverableError(errorCode)) {
            invalidTokens.push(token.token);
          }

          throw error;
        }
      }),
    );

    if (invalidTokens.length > 0) {
      await this.pushTokensService.removeTokens(invalidTokens);
      this.logger.log(`${invalidTokens.length}개의 유효하지 않은 토큰을 제거했습니다.`);
    }

    const failureCount = results.filter((r) => r.status === 'rejected').length;

    this.logger.log(
      `계약서 완료 푸시 전송: 성공 ${successCount}, 실패 ${failureCount}`,
    );

    return {
      success: successCount > 0,
      sent: successCount,
      failed: failureCount,
    };
  }

  async sendInboxNotification(payload: InboxNotificationPayload) {
    if (!this.initialized) {
      this.logger.debug('FCM이 초기화되지 않았습니다. 푸시 전송을 건너뜁니다.');
      return;
    }

    const tokens = await this.pushTokensService.findTokensByUserIds(
      payload.userIds,
    );

    if (!tokens.length) {
      this.logger.debug('등록된 FCM 토큰이 없습니다.');
      return;
    }

    const trimmedBody =
      payload.body.length > 128
        ? `${payload.body.slice(0, 125)}...`
        : payload.body;

    const authClient = await this.googleAuth.getClient();
    const projectId =
      this.configuredProjectId ?? (await this.googleAuth.getProjectId());

    if (!projectId) {
      this.logger.error('FCM 프로젝트 ID를 확인할 수 없습니다.');
      return;
    }

    const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
    const invalidTokens: string[] = [];
    let successCount = 0;

    const results = await Promise.allSettled(
      tokens.map(async (token) => {
        try {
          await authClient.request({
            url,
            method: 'POST',
            data: {
              message: {
                token: token.token,
                notification: {
                  title: payload.title,
                  body: trimmedBody,
                },
                data: {
                  type: 'inbox',
                  kind: payload.kind,
                  messageIds: payload.messageIds.join(','),
                },
                android: {
                  priority: 'high',
                  notification: {
                    channelId: 'default',
                    sound: 'default',
                  },
                },
                apns: {
                  payload: {
                    aps: {
                      sound: 'default',
                      'content-available': 1,
                    },
                  },
                },
              },
            },
          });
          successCount++;
        } catch (error: any) {
          const errorCode = error?.response?.data?.error?.status;
          this.logger.warn(
            `푸시 전송 실패 (token: ${token.token.slice(0, 20)}...): ${errorCode}`,
          );

          // 복구 불가능한 에러인 경우 토큰 제거
          if (this.isUnrecoverableError(errorCode)) {
            invalidTokens.push(token.token);
          }

          throw error;
        }
      }),
    );

    // 유효하지 않은 토큰 제거
    if (invalidTokens.length > 0) {
      await this.pushTokensService.removeTokens(invalidTokens);
      this.logger.log(`${invalidTokens.length}개의 유효하지 않은 토큰을 제거했습니다.`);
    }

    const failureCount = results.filter((r) => r.status === 'rejected').length;

    this.logger.log(
      `푸시 전송 완료: 성공 ${successCount}, 실패 ${failureCount}`,
    );

    return {
      success: successCount > 0,
      sent: successCount,
      failed: failureCount,
    };
  }

  private loadServiceAccountCredentials(): JWTInput | undefined {
    const raw = this.configService.get<string>('FCM_SERVICE_ACCOUNT');
    if (!raw) {
      return undefined;
    }

    try {
      return this.tryParseServiceAccount(raw);
    } catch (error) {
      this.logger.error(`FCM 서비스 계정 파싱 실패: ${error}`);
      return undefined;
    }
  }

  private tryParseServiceAccount(raw: string): JWTInput {
    const attempts = [raw.trim()];

    // Base64 디코딩 시도
    try {
      const decoded = Buffer.from(raw.trim(), 'base64').toString('utf8');
      attempts.push(decoded);
    } catch {
      // Base64 디코딩 실패 무시
    }

    for (const candidate of attempts) {
      try {
        const json = JSON.parse(candidate);

        if (
          typeof json === 'object' &&
          json !== null &&
          'private_key' in json &&
          typeof json.private_key === 'string'
        ) {
          // 개행 문자 정규화
          json.private_key = (json.private_key as string).replace(
            /\\n/g,
            '\n',
          );
        }

        if (!json.project_id) {
          this.logger.warn(
            '서비스 계정 JSON에서 project_id를 찾을 수 없습니다.',
          );
        }

        return json as JWTInput;
      } catch {
        // 다음 시도
      }
    }

    throw new Error('FCM 서비스 계정 JSON을 파싱할 수 없습니다.');
  }

  private isUnrecoverableError(errorCode?: string): boolean {
    if (!errorCode) {
      return false;
    }

    const unrecoverableErrors = [
      'NOT_FOUND',
      'INVALID_ARGUMENT',
      'UNREGISTERED',
    ];

    return unrecoverableErrors.includes(errorCode);
  }
}
