import {
  Injectable,
  InternalServerErrorException,
  Logger,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
import * as nodemailer from "nodemailer";

interface ContractSignatureMail {
  to: string;
  contractName: string;
  link: string;
  senderName?: string;
}

interface EmailVerificationMail {
  to: string;
  verificationLink: string;
}

@Injectable()
export class MailService {
  private readonly logger = new Logger(MailService.name);
  private transporter: nodemailer.Transporter | null = null;

  constructor(private readonly configService: ConfigService) {}

  private getTransporter() {
    if (this.transporter) {
      return this.transporter;
    }

    const host = this.configService.get<string>("SMTP_HOST");
    const port = Number(this.configService.get<string>("SMTP_PORT", "465"));
    const user = this.configService.get<string>("SMTP_USER");
    const pass = this.configService.get<string>("SMTP_PASS");

    if (!host || !user || !pass) {
      this.logger.error("SMTP 설정이 올바르지 않습니다.");
      throw new InternalServerErrorException("메일 서버 설정이 필요합니다.");
    }

    this.transporter = nodemailer.createTransport({
      host,
      port,
      secure: port === 465,
      auth: {
        user,
        pass,
      },
    });

    return this.transporter;
  }

  async sendContractSignatureMail(payload: ContractSignatureMail) {
    const user = this.configService.get<string>("SMTP_USER");
    const fromEmail = this.configService.get<string>("SMTP_FROM") ?? user;

    // 발신자 이름 설정: "갑 이름(인싸인)" <이메일>
    const senderName = payload.senderName
      ? `"${payload.senderName}(인싸인)" <${fromEmail}>`
      : `"인싸인" <${fromEmail}>`;

    this.logger.debug("====== 메일 전송 시도 ======");
    this.logger.debug(`SMTP_HOST: ${this.configService.get("SMTP_HOST")}`);
    this.logger.debug(`SMTP_PORT: ${this.configService.get("SMTP_PORT")}`);
    this.logger.debug(`SMTP_USER: ${user}`);
    this.logger.debug(`발신자 이름: ${senderName}`);
    const pass = this.configService.get<string>("SMTP_PASS");
    this.logger.debug(`SMTP_PASS length: ${pass?.length ?? 0}`);

    try {
      const transporter = this.getTransporter();
      await transporter.sendMail({
        from: senderName,
        to: payload.to,
        subject: `[인싸인] ${payload.contractName} 서명 요청`,
        html: `
          <p>안녕하세요,</p>
          <p><strong>${payload.contractName}</strong> 계약서에 대한 서명 요청이 도착했습니다.</p>
          <p>아래 버튼을 눌러 계약 내용을 확인하고 서명해 주세요.</p>
          <p><a href="${payload.link}" style="display:inline-block;padding:12px 20px;background:#4F46E5;color:#fff;border-radius:8px;text-decoration:none;">계약서 확인</a></p>
          <p>위 링크가 열리지 않는 경우 다음 주소를 복사해 브라우저에 붙여넣으세요.<br />${payload.link}</p>
        `,
      });
    } catch (error) {
      this.logger.error("서명 요청 메일 발송 실패", error as Error);
      throw new InternalServerErrorException("메일 발송에 실패했습니다.");
    }
  }

  async sendEmailVerificationMail(payload: EmailVerificationMail) {
    const user = this.configService.get<string>("SMTP_USER");
    const from = this.configService.get<string>("SMTP_FROM") ?? user;

    this.logger.debug("====== 이메일 인증 메일 전송 시도 ======");
    this.logger.debug(`수신자: ${payload.to}`);

    try {
      const transporter = this.getTransporter();
      await transporter.sendMail({
        from,
        to: payload.to,
        subject: "[인싸인] 이메일 인증을 완료해 주세요",
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #4F46E5;">인싸인 이메일 인증</h2>
            <p>안녕하세요,</p>
            <p>인싸인 서비스에 가입해 주셔서 감사합니다.</p>
            <p>아래 버튼을 클릭하여 이메일 인증을 완료해 주세요.</p>
            <div style="margin: 30px 0; text-align: center;">
              <a href="${payload.verificationLink}"
                 style="display:inline-block;padding:14px 28px;background:#4F46E5;color:#fff;border-radius:8px;text-decoration:none;font-weight:bold;">
                이메일 인증하기
              </a>
            </div>
            <p style="color: #666; font-size: 14px;">
              위 버튼이 작동하지 않는 경우 다음 링크를 복사해 브라우저에 붙여넣으세요:<br />
              <a href="${payload.verificationLink}" style="color: #4F46E5;">${payload.verificationLink}</a>
            </p>
            <p style="color: #999; font-size: 12px; margin-top: 30px; border-top: 1px solid #eee; padding-top: 20px;">
              이 링크는 24시간 동안 유효합니다.<br />
              본인이 요청하지 않은 경우 이 메일을 무시하셔도 됩니다.
            </p>
          </div>
        `,
      });
      this.logger.log(`이메일 인증 메일 발송 성공: ${payload.to}`);
    } catch (error) {
      this.logger.error("이메일 인증 메일 발송 실패", error as Error);
      throw new InternalServerErrorException("메일 발송에 실패했습니다.");
    }
  }
}
