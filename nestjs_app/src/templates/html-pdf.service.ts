import { Injectable, OnModuleDestroy, Logger } from "@nestjs/common";
import puppeteer, { Browser, PaperFormat } from "puppeteer";

interface RenderOptions {
  margin?: {
    top?: string;
    bottom?: string;
    left?: string;
    right?: string;
  };
  format?: PaperFormat;
}

@Injectable()
export class HtmlPdfService implements OnModuleDestroy {
  private readonly logger = new Logger(HtmlPdfService.name);
  private browserPromise?: Promise<Browser | null>;

  private async getBrowser(): Promise<Browser> {
    if (!this.browserPromise) {
      this.browserPromise = puppeteer
        .launch({
          headless: true,
          args: ["--no-sandbox", "--disable-setuid-sandbox", "--font-render-hinting=none"],
        })
        .catch((error) => {
          this.logger.error(`Failed to launch Chromium for PDF rendering: ${error}`);
          return null;
        });
    }

    const browser = await this.browserPromise;
    if (!browser) {
      throw new Error("Chromium 실행에 실패했습니다. 서버의 Puppeteer 설정을 확인해 주세요.");
    }
    return browser;
  }

  async render(html: string, options: RenderOptions = {}): Promise<Buffer> {
    const browser = await this.getBrowser();
    const page = await browser.newPage();

    try {
      await page.setContent(html, { waitUntil: "networkidle0" });
      const pdf = await page.pdf({
        format: options.format ?? ("A4" as PaperFormat),
        printBackground: true,
        margin: {
          top: options.margin?.top ?? "14mm",
          bottom: options.margin?.bottom ?? "16mm",
          left: options.margin?.left ?? "14mm",
          right: options.margin?.right ?? "14mm",
        },
      });
      return Buffer.from(pdf);
    } finally {
      await page.close();
    }
  }

  async onModuleDestroy() {
    if (!this.browserPromise) {
      return;
    }
    try {
      const browser = await this.browserPromise;
      await browser?.close();
    } catch (error) {
      this.logger.warn(`Chromium shutdown failure: ${error}`);
    }
  }
}
