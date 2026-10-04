import { BadRequestException, Injectable, ServiceUnavailableException } from '@nestjs/common';
import { v2 as cloudinary } from 'cloudinary';
import { randomUUID } from 'node:crypto';
import { CreateUploadSignatureDto } from './dto/create-upload-signature.dto';
import { ConfirmUploadDto } from './dto/confirm-upload.dto';

const MAX_FILE_SIZE = 10 * 1024 * 1024;

@Injectable()
export class AttachmentsService {
  private readonly configured: boolean;

  constructor() {
    const cloudName = process.env.CLOUDINARY_CLOUD_NAME;
    const apiKey = process.env.CLOUDINARY_API_KEY;
    const apiSecret = process.env.CLOUDINARY_API_SECRET;
    this.configured = Boolean(cloudName && apiKey && apiSecret);

    if (this.configured) {
      cloudinary.config({ cloud_name: cloudName, api_key: apiKey, api_secret: apiSecret });
    }
  }

  createUploadSignature(input: CreateUploadSignatureDto) {
    this.ensureConfigured();
    if (input.bytes > MAX_FILE_SIZE) {
      throw new BadRequestException('O comprovante não pode exceder 10 MB.');
    }

    const resourceType = input.mimeType === 'application/pdf' ? 'raw' : 'image';
    const extension = input.mimeType === 'application/pdf' ? 'pdf' : 'jpg';
    const timestamp = Math.floor(Date.now() / 1000);
    const folder = `${process.env.CLOUDINARY_UPLOAD_FOLDER ?? 'tesouraria'}/financial-proofs`;
    const publicId = `${folder}/${input.entityId}-${randomUUID()}`;
    const paramsToSign = { public_id: publicId, timestamp };

    return {
      cloudName: process.env.CLOUDINARY_CLOUD_NAME,
      apiKey: process.env.CLOUDINARY_API_KEY,
      timestamp,
      signature: cloudinary.utils.api_sign_request(paramsToSign, process.env.CLOUDINARY_API_SECRET!),
      publicId,
      resourceType,
      format: extension,
      maxBytes: MAX_FILE_SIZE,
    };
  }

  confirmUpload(input: ConfirmUploadDto) {
    this.ensureConfigured();
    const folder = `${process.env.CLOUDINARY_UPLOAD_FOLDER ?? 'tesouraria'}/financial-proofs/`;
    if (!input.publicId.startsWith(folder) || input.bytes > MAX_FILE_SIZE) {
      throw new BadRequestException('Anexo inválido ou fora do escopo da congregação.');
    }

    return {
      entityId: input.entityId,
      publicId: input.publicId,
      resourceType: input.resourceType,
      format: input.format,
      bytes: input.bytes,
      status: 'CONFIRMED',
    };
  }

  private ensureConfigured(): void {
    if (!this.configured) {
      throw new ServiceUnavailableException('Cloudinary não está configurado neste ambiente.');
    }
  }
}
