import { Injectable } from "@nestjs/common";
import { promisify } from "util";

// libreoffice-convert는 CommonJS 모듈이므로 require 사용
const libre = require("libreoffice-convert");
const convertAsync = promisify(libre.convert);

@Injectable()
export class PdfConverterService {
  /**
   * DOCX Buffer를 PDF Buffer로 변환
   *
   * 주의: LibreOffice가 서버에 설치되어 있어야 합니다.
   * Ubuntu/Debian: sudo apt-get install libreoffice
   */
  async convertToPdf(docxBuffer: Buffer): Promise<Buffer> {
    try {
      const pdfBuffer = await convertAsync(
        docxBuffer,
        ".pdf",
        undefined,
      ) as Buffer;

      return pdfBuffer;
    } catch (error) {
      if (error instanceof Error) {
        throw new Error(`PDF 변환 실패: ${error.message}`);
      }
      throw new Error("PDF 변환 중 알 수 없는 오류 발생");
    }
  }

  /**
   * DOCX 파일 경로를 받아 PDF로 변환
   */
  async convertFileToPdf(docxBuffer: Buffer): Promise<Buffer> {
    return this.convertToPdf(docxBuffer);
  }
}
