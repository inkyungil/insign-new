import { Injectable } from "@nestjs/common";
import { readFileSync } from "fs";
import { join } from "path";
import Docxtemplater from "docxtemplater";
import PizZip from "pizzip";

@Injectable()
export class DocxTemplateService {
  /**
   * DOCX 템플릿에 데이터를 채워서 Buffer로 반환
   */
  async fillTemplate(
    templatePath: string,
    data: Record<string, unknown>,
  ): Promise<Buffer> {
    try {
      // 템플릿 파일 읽기
      const fullPath = join(process.cwd(), "public", templatePath);
      const content = readFileSync(fullPath, "binary");

      // PizZip으로 압축 해제
      const zip = new PizZip(content);

      // Docxtemplater 생성
      const doc = new Docxtemplater(zip, {
        paragraphLoop: true,
        linebreaks: true,
      });

      // 데이터 채우기
      doc.render(data);

      // 결과를 Buffer로 생성
      const buffer = doc.getZip().generate({
        type: "nodebuffer",
        compression: "DEFLATE",
      });

      return buffer;
    } catch (error) {
      if (error instanceof Error) {
        throw new Error(`DOCX 템플릿 처리 실패: ${error.message}`);
      }
      throw new Error("DOCX 템플릿 처리 중 알 수 없는 오류 발생");
    }
  }

  /**
   * 데이터 정규화 (null, undefined 처리)
   */
  normalizeData(data: Record<string, unknown>): Record<string, string> {
    const normalized: Record<string, string> = {};

    for (const [key, value] of Object.entries(data)) {
      if (value === null || value === undefined) {
        normalized[key] = "";
      } else if (typeof value === "object") {
        normalized[key] = JSON.stringify(value);
      } else {
        normalized[key] = String(value);
      }
    }

    return normalized;
  }
}
