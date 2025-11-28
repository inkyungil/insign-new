import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PointsLedger } from './entities/points-ledger.entity';
import { PointsService } from './points.service';

@Module({
  imports: [TypeOrmModule.forFeature([PointsLedger])],
  providers: [PointsService],
  exports: [PointsService],
})
export class PointsModule {}
