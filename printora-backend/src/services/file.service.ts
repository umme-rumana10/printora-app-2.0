import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { PDFDocument } from 'pdf-lib';
import jwt from 'jsonwebtoken';
import { config } from '../config';
import { FileRecord } from '../types';
import { SupabaseService } from './supabase.service';

export class FileService {
  private static instance: FileService;
  private db: SupabaseService;
  private uploadDir: string;

  private constructor() {
    this.db = SupabaseService.getInstance();
    this.uploadDir = path.resolve(__dirname, '../../uploads');
    if (!fs.existsSync(this.uploadDir)) {
      fs.mkdirSync(this.uploadDir, { recursive: true });
    }
  }

  public static getInstance(): FileService {
    if (!FileService.instance) {
      FileService.instance = new FileService();
    }
    return FileService.instance;
  }

  public calculateSha256(buffer: Buffer): string {
    return crypto.createHash('sha256').update(buffer).digest('hex');
  }

  public async processUpload(
    fileBuffer: Buffer,
    originalFilename: string,
    mimeType: string
  ): Promise<FileRecord> {
    const fileId = crypto.randomUUID();
    let finalPdfBuffer = fileBuffer;
    let convertedPath: string | undefined = undefined;

    // Convert Image (JPG/PNG) to PDF if required
    if (mimeType.startsWith('image/') || /\.(jpg|jpeg|png)$/i.test(originalFilename)) {
      const pdfDoc = await PDFDocument.create();
      let image;
      if (mimeType.includes('png') || originalFilename.toLowerCase().endsWith('.png')) {
        image = await pdfDoc.embedPng(fileBuffer);
      } else {
        image = await pdfDoc.embedJpg(fileBuffer);
      }
      const page = pdfDoc.addPage([image.width, image.height]);
      page.drawImage(image, {
        x: 0,
        y: 0,
        width: image.width,
        height: image.height
      });
      finalPdfBuffer = Buffer.from(await pdfDoc.save());
      convertedPath = path.join(this.uploadDir, `${fileId}_converted.pdf`);
      fs.writeFileSync(convertedPath, finalPdfBuffer);
    }

    // Save primary file locally
    const storagePath = path.join(this.uploadDir, `${fileId}_${originalFilename}`);
    fs.writeFileSync(storagePath, finalPdfBuffer);

    // Compute SHA-256 Checksum
    const sha256 = this.calculateSha256(finalPdfBuffer);

    // Count PDF Pages
    let pageCount = 1;
    try {
      const pdfDoc = await PDFDocument.load(finalPdfBuffer, { ignoreEncryption: true });
      pageCount = pdfDoc.getPageCount();
    } catch (e: any) {
      console.warn(`[FileService] Could not parse page count from PDF, defaulting to 1: ${e.message}`);
      pageCount = 1;
    }

    const fileRecord: FileRecord = {
      id: fileId,
      storage_path: storagePath,
      converted_pdf_path: convertedPath,
      sha256,
      page_count: pageCount,
      original_filename: originalFilename,
      mime_type: 'application/pdf',
      file_size: finalPdfBuffer.length,
      created_at: new Date().toISOString()
    };

    await this.db.saveFileRecord(fileRecord);
    return fileRecord;
  }

  public generateShortLivedDownloadToken(fileId: string, jobId: string, machineId: string): { token: string; expiresAt: string } {
    const expiresAt = new Date(Date.now() + config.jwt.downloadUrlExpiresSeconds * 1000);
    const token = jwt.sign(
      {
        fileId,
        jobId,
        machineId,
        type: 'download_auth'
      },
      config.jwt.secret,
      { expiresIn: config.jwt.downloadUrlExpiresSeconds }
    );
    return { token, expiresAt: expiresAt.toISOString() };
  }

  public verifyDownloadToken(token: string): { fileId: string; jobId: string; machineId: string } {
    try {
      const decoded = jwt.verify(token, config.jwt.secret) as any;
      if (decoded.type !== 'download_auth') {
        throw new Error('Invalid token type');
      }
      return { fileId: decoded.fileId, jobId: decoded.jobId, machineId: decoded.machineId };
    } catch (err: any) {
      throw new Error(`Token verification failed: ${err.message}`);
    }
  }

  public async getFileBuffer(fileRecord: FileRecord): Promise<Buffer> {
    const filePath = fileRecord.converted_pdf_path || fileRecord.storage_path;
    if (!fs.existsSync(filePath)) {
      throw new Error(`Physical file missing at path: ${filePath}`);
    }
    return fs.readFileSync(filePath);
  }

  public async cleanupJobFiles(fileRecord: FileRecord): Promise<void> {
    try {
      if (fileRecord.converted_pdf_path && fs.existsSync(fileRecord.converted_pdf_path)) {
        fs.unlinkSync(fileRecord.converted_pdf_path);
      }
      if (fileRecord.storage_path && fs.existsSync(fileRecord.storage_path)) {
        fs.unlinkSync(fileRecord.storage_path);
      }
      console.log(`🧹 [FileService] Cleaned up file storage for file ${fileRecord.id}`);
    } catch (err: any) {
      console.error(`[FileService] Cleanup error: ${err.message}`);
    }
  }
}
