import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { KaiaService } from './kaia.service';

@Module({
  imports: [ConfigModule],
  providers: [KaiaService],
  exports: [KaiaService],
})
export class KaiaModule {}
