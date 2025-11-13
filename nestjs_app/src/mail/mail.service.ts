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
    const from = this.configService.get<string>("SMTP_FROM") ?? user;

    this.logger.debug("====== 메일 전송 시도 ======");
    this.logger.debug(`SMTP_HOST: ${this.configService.get("SMTP_HOST")}`);
    this.logger.debug(`SMTP_PORT: ${this.configService.get("SMTP_PORT")}`);
    this.logger.debug(`SMTP_USER: ${user}`);
    const pass = this.configService.get<string>("SMTP_PASS");
    this.logger.debug(`SMTP_PASS length: ${pass?.length ?? 0}`);

    try {
      const transporter = this.getTransporter();
      await transporter.sendMail({
        from,
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
}
