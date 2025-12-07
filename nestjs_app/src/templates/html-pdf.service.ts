import { Injectable, OnModuleDestroy, Logger } from "@nestjs/common";
import puppeteer, { Browser, LaunchOptions, PaperFormat } from "puppeteer";
import PDFDocument = require("pdfkit");

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

  private getLaunchOptions(): LaunchOptions {
    const executablePath = process.env.CHROMIUM_PATH ?? process.env.PUPPETEER_EXECUTABLE_PATH;
    return {
      headless: true,
      executablePath: executablePath?.trim() ? executablePath : undefined,
      args: [
        "--no-sandbox",
        "--disable-setuid-sandbox",
        "--disable-dev-shm-usage",
        "--disable-accelerated-2d-canvas",
        "--disable-gpu",
        "--no-zygote",
        "--single-process",
        "--font-render-hinting=none",
      ],
    };
  }

  private async launchBrowser(): Promise<Browser | null> {
    try {
      return await puppeteer.launch(this.getLaunchOptions());
    } catch (error) {
      this.logger.error(`Failed to launch Chromium for PDF rendering: ${error}`);
      return null;
    }
  }

  private async getBrowser(): Promise<Browser> {
    if (!this.browserPromise) {
      this.browserPromise = this.launchBrowser();
    }

    const browser = await this.browserPromise;
    if (!browser) {
      throw new Error("Chromium 실행에 실패했습니다. 서버의 Puppeteer 설정을 확인해 주세요.");
    }
    return browser;
  }

  private async resetBrowser(): Promise<void> {
    if (!this.browserPromise) {
      return;
    }
    try {
      const browser = await this.browserPromise;
      await browser?.close();
    } catch (error) {
      this.logger.warn(`Chromium shutdown failure: ${error}`);
    } finally {
      this.browserPromise = undefined;
    }
  }

  async render(html: string, options: RenderOptions = {}): Promise<Buffer> {
    try {
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
        await page.close().catch((closeError) => {
          this.logger.debug(
            `Failed to close Puppeteer page gracefully: ${closeError}`,
          );
        });
      }
    } catch (error) {
      if (
        error instanceof Error &&
        /Protocol error|Target closed|Page crashed/i.test(error.message)
      ) {
        this.logger.warn(
          `Chromium page closed unexpectedly while generating PDF. Restarting browser... (${error.message})`,
        );
        await this.resetBrowser();
        this.logger.warn(
          `Falling back to simple PDF rendering due to Chromium page crash: ${error.message}`,
        );
        return this.renderFallback(html, options);
      }

      if (
        error instanceof Error &&
        /Failed to launch the browser process/i.test(error.message)
      ) {
        this.logger.warn(
          `Chromium failed to launch. Using fallback PDF renderer. (${error.message})`,
        );
        await this.resetBrowser();
        return this.renderFallback(html, options);
      }

      this.logger.error(
        `Unexpected error while generating PDF: ${error}`,
      );
      throw error;
    }
  }

  private async renderFallback(
    html: string,
    options: RenderOptions = {},
  ): Promise<Buffer> {
    this.logger.warn("Using HtmlPdfService fallback renderer (PDFKit).");

    const doc = new PDFDocument({
      size: options.format ?? ("A4" as PaperFormat),
      margin: 40,
    });

    const chunks: Buffer[] = [];

    return new Promise<Buffer>((resolve, reject) => {
      doc.on("data", (chunk) => {
        chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
      });

      doc.on("end", () => {
        resolve(Buffer.concat(chunks));
      });

      doc.on("error", (err) => {
        this.logger.error(`Fallback PDF rendering failed: ${err}`);
        reject(err);
      });

      const text = this.normalizeHtmlToText(html);

      doc.fontSize(11);
      doc.text(text, {
        width: 500,
        align: "left",
      });

      doc.end();
    });
  }

  private normalizeHtmlToText(html: string): string {
    if (!html) {
      return "";
    }

    let text = html;

    text = text.replace(/<br\s*\/?>/gi, "\n");
    text = text.replace(/<\/p>/gi, "\n\n");
    text = text.replace(/<\/h[1-6]>/gi, "\n\n");

    text = text.replace(/<style[\s\S]*?<\/style>/gi, "");
    text = text.replace(/<script[\s\S]*?<\/script>/gi, "");

    text = text.replace(/<[^>]+>/g, "");

    text = text.replace(/&nbsp;/gi, " ");
    text = text.replace(/&amp;/gi, "&");
    text = text.replace(/&lt;/gi, "<");
    text = text.replace(/&gt;/gi, ">");
    text = text.replace(/&quot;/gi, '"');
    text = text.replace(/&#39;/gi, "'");

    return text.trim();
  }

  async onModuleDestroy() {
    await this.resetBrowser();
  }
}
