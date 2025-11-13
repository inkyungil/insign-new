import { Injectable, Logger } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { createCipheriv, createDecipheriv, randomBytes } from "crypto";

/**
 * 암호화/복호화 서비스
 * AES-256-GCM 알고리즘을 사용하여 민감한 데이터를 암호화합니다.
 */
@Injectable()
export class EncryptionService {
  private readonly logger = new Logger(EncryptionService.name);
  private readonly algorithm = "aes-256-gcm";
  private readonly key: Buffer;

  constructor(private readonly configService: ConfigService) {
    const keyString = this.configService.get<string>("ENCRYPTION_KEY");

    if (!keyString) {
      throw new Error(
        "ENCRYPTION_KEY is not set in environment variables. " +
          "Generate one using: node -e \"console.log(require('crypto').randomBytes(32).toString('hex'))\"",
      );
    }

    // 64 hex characters = 32 bytes
    if (keyString.length !== 64) {
      throw new Error(
        "ENCRYPTION_KEY must be exactly 64 hex characters (32 bytes). " +
          "Current length: " +
          keyString.length,
      );
    }

    this.key = Buffer.from(keyString, "hex");
    this.logger.log("EncryptionService initialized successfully");
  }

  /**
   * 문자열을 암호화합니다.
   * @param plainText 암호화할 평문
   * @returns 암호화된 문자열 (iv:authTag:encrypted 형식)
   */
  encrypt(plainText: string): string {
    if (!plainText) {
      return plainText;
    }

    try {
      // 16바이트 랜덤 초기화 벡터 (IV) 생성
      const iv = randomBytes(16);

      // Cipher 생성
      const cipher = createCipheriv(this.algorithm, this.key, iv);

      // 암호화 수행
      let encrypted = cipher.update(plainText, "utf8", "hex");
      encrypted += cipher.final("hex");

      // 인증 태그 가져오기 (GCM 모드에서 데이터 무결성 보장)
      const authTag = cipher.getAuthTag();

      // iv:authTag:encrypted 형식으로 반환
      return (
        iv.toString("hex") +
        ":" +
        authTag.toString("hex") +
        ":" +
        encrypted
      );
    } catch (error) {
      this.logger.error("Encryption failed", error);
      throw new Error("암호화 중 오류가 발생했습니다.");
    }
  }

  /**
   * 암호화된 문자열을 복호화합니다.
   * @param encryptedData 암호화된 문자열 (iv:authTag:encrypted 형식)
   * @returns 복호화된 평문
   */
  decrypt(encryptedData: string): string {
    if (!encryptedData) {
      return encryptedData;
    }

    // 이미 복호화된 데이터인지 확인 (: 구분자가 없으면 평문으로 간주)
    if (!encryptedData.includes(":")) {
      return encryptedData;
    }

    try {
      const parts = encryptedData.split(":");

      // 올바른 형식인지 확인
      if (parts.length !== 3) {
        this.logger.warn("Invalid encrypted data format, returning as-is");
        return encryptedData;
      }

      const iv = Buffer.from(parts[0], "hex");
      const authTag = Buffer.from(parts[1], "hex");
      const encrypted = parts[2];

      // Decipher 생성
      const decipher = createDecipheriv(this.algorithm, this.key, iv);
      decipher.setAuthTag(authTag);

      // 복호화 수행
      let decrypted = decipher.update(encrypted, "hex", "utf8");
      decrypted += decipher.final("utf8");

      return decrypted;
    } catch (error) {
      this.logger.error("Decryption failed", error);
      throw new Error("복호화 중 오류가 발생했습니다.");
    }
  }

  /**
   * JSON 객체를 암호화합니다.
   * @param data JSON 직렬화 가능한 객체
   * @returns 암호화된 문자열
   */
  encryptJSON(data: any): string {
    if (!data) {
      return data;
    }
    const jsonString = JSON.stringify(data);
    return this.encrypt(jsonString);
  }

  /**
   * 암호화된 문자열을 JSON 객체로 복호화합니다.
   * @param encryptedData 암호화된 문자열
   * @returns 복호화된 JSON 객체
   */
  decryptJSON<T = any>(encryptedData: string): T | null {
    if (!encryptedData) {
      return null;
    }
    const decrypted = this.decrypt(encryptedData);
    try {
      return JSON.parse(decrypted);
    } catch (error) {
      this.logger.error("Failed to parse decrypted JSON", error);
      throw new Error("복호화된 데이터를 파싱할 수 없습니다.");
    }
  }
}
