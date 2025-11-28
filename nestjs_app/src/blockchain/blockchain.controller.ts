import { Controller, Get, Param, ParseIntPipe } from '@nestjs/common';
import { ContractBlockchainService } from './contract-blockchain.service';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Contract } from '../contracts/contract.entity';

/**
 * 블록체인 검증 API 컨트롤러
 */
@Controller('api/blockchain')
export class BlockchainController {
  constructor(
    private readonly blockchainService: ContractBlockchainService,
    @InjectRepository(Contract)
    private readonly contractRepository: Repository<Contract>,
  ) {}

  /**
   * 블록체인 기능 상태 확인
   */
  @Get('status')
  getStatus() {
    const isEnabled = this.blockchainService.isEnabled();
    return {
      success: true,
      blockchain_enabled: isEnabled,
      message: isEnabled
        ? '블록체인 기능이 활성화되어 있습니다.'
        : '블록체인 기능이 비활성화되어 있습니다.',
    };
  }

  /**
   * 계약서 블록체인 검증
   *
   * GET /api/blockchain/verify/:contractId
   */
  @Get('verify/:contractId')
  async verifyContract(@Param('contractId', ParseIntPipe) contractId: number) {
    // 계약서 조회
    const contract = await this.contractRepository.findOne({
      where: { id: contractId },
    });

    if (!contract) {
      return {
        success: false,
        error: '계약서를 찾을 수 없습니다.',
      };
    }

    // 블록체인 등록 여부 확인
    if (!contract.blockchainHash || !contract.blockchainTxHash) {
      return {
        success: false,
        error: '이 계약서는 블록체인에 등록되지 않았습니다.',
        contract_id: contractId,
        blockchain_registered: false,
      };
    }

    // PDF 해시가 없으면 검증 불가
    if (!contract.pdfHash) {
      return {
        success: false,
        error: 'PDF 해시가 생성되지 않았습니다.',
        contract_id: contractId,
      };
    }

    // DB에 저장된 해시를 블록체인 해시와 비교
    const currentHash = contract.pdfHash;

    // 블록체인 검증
    const verificationResult = await this.blockchainService.verifyContractFromBlockchain(
      contractId,
      contract.blockchainHash,
    );

    // 해시 일치 여부 확인
    const hashMatch = currentHash === contract.blockchainHash;

    return {
      success: true,
      contract_id: contractId,
      blockchain_registered: true,
      verification: {
        is_valid: verificationResult.isValid && hashMatch,
        hash_match: hashMatch,
        current_hash: currentHash,
        blockchain_hash: contract.blockchainHash,
        tx_hash: contract.blockchainTxHash,
        blockchain_timestamp: contract.blockchainTimestamp?.toISOString() ?? null,
        blockchain_network: contract.blockchainNetwork,
      },
      message: hashMatch
        ? '✅ 계약서가 위조/변조되지 않았습니다.'
        : '⚠️ 계약서가 변경되었을 가능성이 있습니다.',
    };
  }

  /**
   * 계약서 블록체인 정보 조회
   *
   * GET /api/blockchain/info/:contractId
   */
  @Get('info/:contractId')
  async getContractBlockchainInfo(@Param('contractId', ParseIntPipe) contractId: number) {
    const contract = await this.contractRepository.findOne({
      where: { id: contractId },
    });

    if (!contract) {
      return {
        success: false,
        error: '계약서를 찾을 수 없습니다.',
      };
    }

    return {
      success: true,
      contract_id: contractId,
      blockchain_info: {
        registered: !!contract.blockchainHash,
        hash: contract.blockchainHash,
        tx_hash: contract.blockchainTxHash,
        timestamp: contract.blockchainTimestamp?.toISOString() ?? null,
        network: contract.blockchainNetwork,
        explorer_url: contract.blockchainTxHash
          ? `https://kairos.kaiascan.io/tx/${contract.blockchainTxHash}`
          : null,
      },
    };
  }
}
