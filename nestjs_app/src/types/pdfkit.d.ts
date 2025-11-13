declare module "pdfkit" {
  import type { Readable } from "stream";

  interface PDFDocumentOptions {
    size?: string | [number, number];
    margins?: { top?: number; left?: number; right?: number; bottom?: number };
    margin?: number;
    layout?: "portrait" | "landscape";
  }

  class PDFDocument extends Readable {
    constructor(options?: PDFDocumentOptions);
    font(font: string | Buffer): this;
    fontSize(size: number): this;
    text(text: string, options?: any): this;
    moveDown(lines?: number): this;
    moveUp(lines?: number): this;
    addPage(options?: PDFDocumentOptions): this;
    image(
      src: string | Buffer,
      x?: number | Record<string, any>,
      y?: number | Record<string, any>,
      options?: any,
    ): this;
    fillColor(color: string): this;
    strokeColor(color: string): this;
    lineWidth(width: number): this;
    rect(x: number, y: number, width: number, height: number): this;
    stroke(): this;
    end(): this;
  }

  export = PDFDocument;
}
