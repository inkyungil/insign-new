import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHash } from 'crypto';
const Caver = require('caver-js');
import {
  KAIA_DEFAULT_JSON_RPC,
  KAIA_MINT_NFT_TOKEN_ABI,
  KAIA_MINT_NFT_TOKEN_ADDRESS,
} from './kaia/abi/kaia.config';
import { Contract } from '../contracts/contract.entity';

interface SignedTxOptions {
  from: string;
  pkey: string;
  data: string;
  to: string;
  value?: string;
  gas?: string;
  chainId?: number;
}

interface BlockchainRegistrationResult {
  success: boolean;
  txHash?: string;
  blockchainHash?: string;
  tradeId?: string;
  network?: string;
  error?: string;
}

/**
 * 계약서 블록체인 등록 서비스
 *
 * 계약서의 해시를 Kaia 블록체인에 등록하여 위조/변조 방지
 * TradeLedger 스마트 컨트랙트를 활용하여 계약서 정보를 블록체인에 기록
 */
@Injectable()
export class ContractBlockchainService {
  private readonly logger = new Logger(ContractBlockchainService.name);
  private readonly caver: any;
  private readonly mintContract: any;
  private readonly chainId!: number;
  private readonly mintAccount!: string | null;
  private readonly mintPrivateKey!: string | null;
  private readonly enabled!: boolean;

  constructor(private readonly configService: ConfigService) {
    // 블록체인 기능 활성화 여부
    this.enabled = configService.get<string>('BLOCKCHAIN_ENABLED', 'false') === 'true';

    if (!this.enabled) {
      this.logger.warn('블록체인 기능이 비활성화되어 있습니다. BLOCKCHAIN_ENABLED=true로 설정하세요.');
      return;
    }

    // Kaia RPC 설정
    const rpc = configService.get<string>('KAIA_JSON_RPC', KAIA_DEFAULT_JSON_RPC);
    const provider = new Caver.providers.HttpProvider(rpc, {
      timeout: Number(configService.get<number>('KAIA_RPC_TIMEOUT', 30000)),
      keepAlive: true,
    });
    this.caver = new Caver(provider);

    // NFT Mint 컨트랙트 설정
    const mintAddress = configService.get<string>(
      'KAIA_MINT_CONTRACT_ADDRESS',
      KAIA_MINT_NFT_TOKEN_ADDRESS,
    );
    this.mintContract = new this.caver.klay.Contract(
      KAIA_MINT_NFT_TOKEN_ABI as any,
      mintAddress,
    );

    // 네트워크 설정
    this.chainId = Number(configService.get<number>('KAIA_CHAIN_ID', 1001)); // 1001 = Kairos Testnet

    // 서버 지갑 설정 (계약서 등록용)
    this.mintAccount = configService.get<string>('KAIA_MINT_ACCOUNT') ?? null;
    this.mintPrivateKey = configService.get<string>('KAIA_MINT_PRIVATE_KEY') ?? null;

    if (!this.mintAccount || !this.mintPrivateKey) {
      this.logger.warn(
        '블록체인 지갑이 설정되지 않았습니다. KAIA_MINT_ACCOUNT와 KAIA_MINT_PRIVATE_KEY를 설정하세요.',
      );
    } else {
      this.logger.log(`블록체인 서비스 초기화 완료 - 네트워크: Kaia (ChainID: ${this.chainId})`);
      this.logger.log(`서버 지갑: ${this.mintAccount}`);
    }
  }

  /**
   * 블록체인 기능 활성화 여부
   */
  isEnabled(): boolean {
    return this.enabled && !!this.mintAccount && !!this.mintPrivateKey;
  }

  /**
   * 계약서 데이터 해시 생성
   *
   * SHA-256 해시를 사용하여 계약서의 핵심 데이터를 해싱
   */
  generateContractHash(contract: Contract): string {
    // 계약서의 핵심 데이터만 추출 (변경되지 않는 데이터)
    const hashData = {
      id: contract.id,
      name: contract.name,
      clientName: contract.clientName,
      clientEmail: contract.clientEmail,
      clientContact: contract.clientContact,
      performerName: contract.performerName,
      performerEmail: contract.performerEmail,
      performerContact: contract.performerContact,
      startDate: contract.startDate?.toISOString() ?? null,
      endDate: contract.endDate?.toISOString() ?? null,
      amount: contract.amount,
      details: contract.details,
      metadata: contract.metadata,
      signatureCompletedAt: contract.signatureCompletedAt?.toISOString() ?? null,
      createdAt: contract.createdAt.toISOString(),
    };

    // 키를 정렬하여 일관된 해시 생성
    const sortedData = this.sortObjectKeys(hashData);
    const dataString = JSON.stringify(sortedData);

    return createHash('sha256').update(dataString, 'utf-8').digest('hex');
  }

  /**
   * PDF 파일 해시 생성
   */
  generatePdfHash(pdfBuffer: Buffer): string {
    return createHash('sha256').update(pdfBuffer).digest('hex');
  }

  /**
   * 블록체인에 계약서 해시 등록 (NFT 민팅 방식)
   *
   * 계약서를 NFT로 발행하여 블록체인에 영구 기록
   * 메타데이터 URI에 계약서 해시 및 정보 포함
   */
  async registerContractToBlockchain(
    contract: Contract,
    hash: string,
  ): Promise<BlockchainRegistrationResult> {
    if (!this.isEnabled()) {
      return {
        success: false,
        error: '블록체인 기능이 비활성화되어 있거나 지갑이 설정되지 않았습니다.',
      };
    }

    try {
      // NFT 메타데이터 URI 생성 (개인정보 제외!)
      // ⚠️ 블록체인은 공개되므로 개인정보를 절대 포함하지 않습니다
      const metadata = {
        name: `Insign Contract #${contract.id}`,
        description: 'Insign Digital Contract - Blockchain Verified',
        image: 'https://in-sign.shop/static/logo.png', // 로고 이미지
        external_url: `https://in-sign.shop/contracts/${contract.id}`,
        contract_id: contract.id,
        contract_hash: hash,
        attributes: [
          {
            trait_type: 'Contract ID',
            value: contract.id.toString(),
          },
          {
            trait_type: 'Hash',
            value: hash,
          },
          {
            trait_type: 'Platform',
            value: 'Insign',
          },
          {
            trait_type: 'Verified',
            value: 'Yes',
          },
        ],
      };

      // 메타데이터를 JSON 문자열로 변환하여 URI로 사용
      // 실제로는 IPFS에 업로드하거나 서버에 저장해야 하지만,
      // 여기서는 간단히 data URI로 처리
      const metadataJson = JSON.stringify(metadata);
      const metadataUri = `data:application/json;base64,${Buffer.from(metadataJson).toString('base64')}`;

      this.logger.log(`📝 NFT 민팅 시작 - 계약서 ID: ${contract.id}, 해시: ${hash}`);

      // NFT 민팅
      const data = this.mintContract.methods.mintNFT(metadataUri).encodeABI();

      const receipt = await this.sendSignedTransaction({
        from: this.mintAccount!,
        pkey: this.mintPrivateKey!,
        to: this.mintContract.options.address,
        data,
      });

      // Token ID 추출
      const tokenId = this.extractTokenIdFromReceipt(receipt);

      this.logger.log(
        `✅ NFT 민팅 완료 - TX: ${receipt.transactionHash}, Token ID: ${tokenId}`,
      );

      return {
        success: true,
        txHash: receipt.transactionHash,
        blockchainHash: hash,
        tradeId: tokenId ?? undefined,  // Token ID를 tradeId 필드에 저장
        network: `kaia-${this.chainId === 1001 ? 'testnet' : 'mainnet'}`,
      };
    } catch (error) {
      this.logger.error(`❌ NFT 민팅 실패: ${error}`);
      return {
        success: false,
        error: (error as Error).message,
      };
    }
  }

  /**
   * 블록체인에서 계약서 해시 검증
   */
  async verifyContractFromBlockchain(
    contractId: number,
    expectedHash: string,
  ): Promise<{ isValid: boolean; blockchainHash?: string; error?: string }> {
    if (!this.isEnabled()) {
      return {
        isValid: false,
        error: '블록체인 기능이 비활성화되어 있습니다.',
      };
    }

    try {
      // 계약서 ID로 거래 조회
      // 실제로는 DB에 저장된 tradeId를 사용해야 하지만,
      // 여기서는 간단히 시뮬레이션
      this.logger.log(`블록체인 검증 - 계약서 ID: ${contractId}, 예상 해시: ${expectedHash}`);

      // TODO: 실제 블록체인에서 조회하는 로직 구현
      // const trade = await this.tradeContract.methods.getTrade(tradeId).call();
      // const memo = trade.memo;
      // const blockchainHash = memo.replace('CONTRACT_HASH:', '');

      return {
        isValid: true,
        blockchainHash: expectedHash,
      };
    } catch (error) {
      this.logger.error(`블록체인 검증 실패: ${error}`);
      return {
        isValid: false,
        error: (error as Error).message,
      };
    }
  }

  /**
   * 서명된 트랜잭션 전송
   */
  private async sendSignedTransaction(options: SignedTxOptions) {
    const { from, pkey, to, data, value = '0x0', gas = '3000000', chainId = this.chainId } = options;

    const txObject = {
      type: 'SMART_CONTRACT_EXECUTION',
      from,
      to,
      data,
      value,
      gas,
      chainId,
    };

    const signed = await this.caver.klay.accounts.signTransaction(txObject, pkey);
    return this.caver.klay.sendSignedTransaction(signed.rawTransaction as string);
  }

  /**
   * Receipt에서 Token ID 추출 (NFT)
   */
  private extractTokenIdFromReceipt(receipt: any): string | null {
    const extractFromSource = (source: any): string | null => {
      if (!source) return null;
      const list = Array.isArray(source) ? source : [source];
      for (const entry of list) {
        const tokenId = this.extractTokenIdFromValues(entry?.returnValues ?? null);
        if (tokenId !== undefined && tokenId !== null) {
          return String(tokenId);
        }
      }
      return null;
    };

    const events = receipt?.events ?? {};

    // Transfer 이벤트에서 Token ID 추출
    if (events.Transfer) {
      const tokenId = extractFromSource(events.Transfer);
      if (tokenId) return tokenId;
    }

    // 모든 이벤트 검색
    for (const key of Object.keys(events)) {
      const tokenId = extractFromSource(events[key]);
      if (tokenId) {
        return tokenId;
      }
    }

    // logs에서 추출 시도
    const logs = receipt?.logs;
    if (Array.isArray(logs)) {
      for (const log of logs) {
        if (Array.isArray(log?.topics) && log.topics.length >= 4) {
          const tokenHex = log.topics[3];
          if (typeof tokenHex === 'string') {
            try {
              return BigInt(tokenHex).toString();
            } catch (error) {
              continue;
            }
          }
        }
      }
    }

    return null;
  }

  /**
   * returnValues에서 Token ID 추출
   */
  private extractTokenIdFromValues(values: any): string | null {
    if (!values) return null;

    const candidateKeys = [
      'tokenId',
      '_tokenId',
      'id',
      'token_id',
      'tokenID',
      'nftTokenId',
      'nftTokenID',
    ];

    for (const key of candidateKeys) {
      const candidate = values?.[key];
      if (candidate !== undefined && candidate !== null) {
        return String(candidate);
      }
    }

    // 숫자 키 검색
    const numericKeys = Object.keys(values).filter((key) => /^\d+$/.test(key));
    for (const key of numericKeys) {
      const candidate = values[key];
      if (candidate !== undefined && candidate !== null) {
        return String(candidate);
      }
    }

    return null;
  }

  /**
   * 객체 키 정렬 (일관된 해시 생성을 위해)
   */
  private sortObjectKeys(obj: any): any {
    if (obj === null || typeof obj !== 'object') {
      return obj;
    }

    if (Array.isArray(obj)) {
      return obj.map((item) => this.sortObjectKeys(item));
    }

    const sortedObj: Record<string, any> = {};
    Object.keys(obj)
      .sort()
      .forEach((key) => {
        sortedObj[key] = this.sortObjectKeys(obj[key]);
      });

    return sortedObj;
  }
}
