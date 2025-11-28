import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ContractBlockchainService } from './contract-blockchain.service';
import { KaiaService } from './kaia/kaia.service';
import { BlockchainController } from './blockchain.controller';
import { Contract } from '../contracts/contract.entity';

@Module({
  imports: [
    ConfigModule,
    TypeOrmModule.forFeature([Contract]),
  ],
  controllers: [BlockchainController],
  providers: [ContractBlockchainService, KaiaService],
  exports: [ContractBlockchainService, KaiaService],
})
export class BlockchainModule {}
