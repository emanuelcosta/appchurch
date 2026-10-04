import { Body, Controller, Post } from '@nestjs/common';
import { AttachmentsService } from './attachments.service';
import { CreateUploadSignatureDto } from './dto/create-upload-signature.dto';
import { ConfirmUploadDto } from './dto/confirm-upload.dto';

@Controller('attachments')
export class AttachmentsController {
  constructor(private readonly attachmentsService: AttachmentsService) {}

  @Post('upload-signature')
  createUploadSignature(@Body() input: CreateUploadSignatureDto) {
    return this.attachmentsService.createUploadSignature(input);
  }

  @Post('confirm')
  confirmUpload(@Body() input: ConfirmUploadDto) {
    return this.attachmentsService.confirmUpload(input);
  }
}
