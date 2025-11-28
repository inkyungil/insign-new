import { Injectable, InternalServerErrorException, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
const Caver = require('caver-js');
import axios from 'axios';
import {
  KAIA_GET_NFT_TOKEN_ABI,
  KAIA_GET_NFT_TOKEN_ADDRESS,
  KAIA_DEFAULT_JSON_RPC,
  KAIA_MINT_NFT_TOKEN_ABI,
  KAIA_MINT_NFT_TOKEN_ADDRESS,
  KAIA_SALE_NFT_TOKEN_ABI,
  KAIA_SALE_NFT_TOKEN_ADDRESS,
  KAIA_TRADE_LEDGER_CONTRACT_ABI,
  KAIA_TRADE_LEDGER_CONTRACT_ADDRESS,
} from './abi/kaia.config';
import {
  KaiaApprovalStateDto,
  KaiaBalanceRequestDto,
  KaiaBuyNftDto,
  KaiaMintNftDto,
  KaiaMyNftDto,
  KaiaNftDetailDto,
  KaiaOnSaleDto,
  KaiaOnSaleListDto,
  KaiaSetApprovalForAllDto,
  KaiaTradeGetDto,
  KaiaTradeListByTraderDto,
  KaiaTradeRecordForDto,
  KaiaTradeRecordMyDto,
  KaiaTradeSetReceiptUriDto,
  KaiaTradeTradesOfDto,
  KaiaBurnNftDto,
} from './dto/kaia.dto';

interface SignedTxOptions {
  from: string;
  pkey: string;
  data: string;
  to: string;
  value?: string;
  gas?: string;
  chainId?: number;
}

@Injectable()
export class KaiaService {
  private readonly logger = new Logger(KaiaService.name);
  private readonly caver: any;
  private readonly mintContract: any;
  private readonly saleContract: any;
  private readonly getterContract: any;
  private readonly tradeContract: any;
  private readonly chainId: number;
  private readonly ipfsGateway: string;
  private readonly mintAccount: string | null;
  private readonly mintPrivateKey: string | null;

  constructor(private readonly configService: ConfigService) {
    const rpc = configService.get<string>('KAIA_JSON_RPC', KAIA_DEFAULT_JSON_RPC);
    const provider = new Caver.providers.HttpProvider(rpc, {
      timeout: Number(configService.get<number>('KAIA_RPC_TIMEOUT', 30000)),
      keepAlive: true,
    });
    this.caver = new Caver(provider);

    const mintAddress = configService.get<string>('KAIA_MINT_CONTRACT_ADDRESS', KAIA_MINT_NFT_TOKEN_ADDRESS);
    const saleAddress = configService.get<string>('KAIA_SALE_CONTRACT_ADDRESS', KAIA_SALE_NFT_TOKEN_ADDRESS);
    const getterAddress = configService.get<string>('KAIA_GET_CONTRACT_ADDRESS', KAIA_GET_NFT_TOKEN_ADDRESS);
    const tradeAddress = configService.get<string>('KAIA_TRADE_LEDGER_ADDRESS', KAIA_TRADE_LEDGER_CONTRACT_ADDRESS);

    this.mintContract = new this.caver.klay.Contract(KAIA_MINT_NFT_TOKEN_ABI as any, mintAddress);
    this.saleContract = new this.caver.klay.Contract(KAIA_SALE_NFT_TOKEN_ABI as any, saleAddress);
    this.getterContract = new this.caver.klay.Contract(KAIA_GET_NFT_TOKEN_ABI as any, getterAddress);
    this.tradeContract = new this.caver.klay.Contract(KAIA_TRADE_LEDGER_CONTRACT_ABI as any, tradeAddress);

    this.chainId = Number(configService.get<number>('KAIA_CHAIN_ID', 1001));
    this.ipfsGateway = configService.get<string>('IPFS_GATEWAY', 'https://ipfs.io/ipfs/');
    this.mintAccount = configService.get<string>('KAIA_MINT_ACCOUNT') ?? null;
    this.mintPrivateKey = configService.get<string>('KAIA_MINT_PRIVATE_KEY') ?? null;
  }

  private normalizeIpfs(uri?: string | null) {
    if (!uri) return uri ?? undefined;
    if (uri.startsWith('ipfs://')) {
      return uri.replace('ipfs://', this.ipfsGateway);
    }
    return uri;
  }

  private async fetchIpfsMetadata(uri: string) {
    try {
      const url = this.normalizeIpfs(uri);
      if (!url) return {};
      const { data } = await axios.get(url, {
        responseType: 'json',
        timeout: 15000,
      });
      if (data && typeof data === 'object' && 'image' in data && typeof data.image === 'string') {
        data.image = this.normalizeIpfs(data.image);
      }
      return data ?? {};
    } catch (error) {
      this.logger.warn(`Failed to load IPFS metadata: ${error}`);
      return {};
    }
  }

  private async sendSignedTransaction({ from, pkey, to, data, value = '0x0', gas = '3000000', chainId = this.chainId }: SignedTxOptions) {
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

    const numericKeys = Object.keys(values).filter((key) => /^\d+$/.test(key));
    for (const key of numericKeys) {
      const candidate = values[key];
      if (candidate !== undefined && candidate !== null) {
        return String(candidate);
      }
    }

    return null;
  }

  private decimalToIntString(value: string | number | undefined, decimals: number | undefined) {
    if (value === undefined || value === null) return undefined;
    const str = String(value).trim();
    if (str.length === 0) return undefined;

    const d = Number(decimals ?? 0);
    if (Number.isNaN(d) || d <= 0) {
      return str.includes('.') ? str.replace(/\./g, '') : str;
    }

    const [head, tailRaw = ''] = str.split('.');
    const tail = `${tailRaw}${'0'.repeat(d)}`.slice(0, d);
    return `${head || '0'}${tail}`;
  }

  private async extractTradeIdFromReceipt(receipt: any) {
    const events = receipt?.events ?? {};
    if (events.TradeRecorded) {
      const candidate = Array.isArray(events.TradeRecorded) ? events.TradeRecorded[0] : events.TradeRecorded;
      if (candidate?.returnValues?.id !== undefined) {
        return String(candidate.returnValues.id);
      }
    }

    for (const key of Object.keys(events)) {
      const raw = events[key];
      const list = Array.isArray(raw) ? raw : [raw];
      for (const item of list) {
        if (item?.event === 'TradeRecorded' && item?.returnValues?.id !== undefined) {
          return String(item.returnValues.id);
        }
      }
    }

    try {
      const total = await this.tradeContract.methods.totalTrades().call();
      return String(Number(total) - 1);
    } catch (error) {
      this.logger.warn(`Fallback trade id lookup failed: ${error}`);
      return null;
    }
  }

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
    if (events.Transfer) {
      const tokenId = extractFromSource(events.Transfer);
      if (tokenId) return tokenId;
    }

    for (const key of Object.keys(events)) {
      const tokenId = extractFromSource(events[key]);
      if (tokenId) {
        return tokenId;
      }
    }

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

  private async resolveTokenIdByMetadata(uri: string): Promise<string | null> {
    if (!this.mintAccount) {
      return null;
    }

    try {
      const list = await this.getterContract.methods.getNftTokens(this.mintAccount).call();
      const match = list.find((item: any) => {
        const candidate = typeof item?.nftTokenURI === 'string' ? item.nftTokenURI : '';
        return candidate.trim().toLowerCase() === uri.trim().toLowerCase();
      });

      if (match?.nftTokenId !== undefined && match.nftTokenId !== null) {
        return String(match.nftTokenId);
      }
    } catch (error) {
      this.logger.warn(`resolveTokenIdByMetadata failed: ${error}`);
    }

    return null;
  }

  async getBalance({ from }: KaiaBalanceRequestDto) {
    try {
      const balancePeb =
        (await this.caver.rpc.kaia?.getBalance?.(from)) ??
        (await this.caver.rpc.klay.getBalance(from));

      return {
        success: true,
        result: this.caver.utils.convertFromPeb(balancePeb),
      };
    } catch (error) {
      this.logger.error(`getBalance failed`, error as Error);
      return { success: false, result: (error as Error).message };
    }
  }

  async getApprovalState({ from }: KaiaApprovalStateDto) {
    try {
      const approved = await this.mintContract.methods.isApprovedForAll(from, this.saleContract.options.address).call();
      return { success: true, result: approved };
    } catch (error) {
      return { success: false, result: (error as Error).message };
    }
  }

  async toggleApproval({ from, pkey }: KaiaSetApprovalForAllDto) {
    try {
      const current = await this.mintContract.methods.isApprovedForAll(from, this.saleContract.options.address).call();
      const next = !current;
      const data = this.mintContract.methods.setApprovalForAll(this.saleContract.options.address, next).encodeABI();
      const receipt = await this.sendSignedTransaction({ from, pkey, to: this.mintContract.options.address, data });
      return { success: true, result: receipt };
    } catch (error) {
      return { success: false, result: (error as Error).message };
    }
  }

  async getTotalSupply() {
    try {
      const total_cnt = await this.mintContract.methods.totalSupply().call();
      return { success: true, total_cnt };
    } catch (error) {
      throw new InternalServerErrorException((error as Error).message);
    }
  }

  async myNfts({ from }: KaiaMyNftDto) {
    try {
      const list = await this.getterContract.methods.getNftTokens(from).call();
      const mapped = list.map((item: any) => ({
        pubkey: from,
        nftTokenId: item.nftTokenId,
        nftTokenURI: item.nftTokenURI,
        price: this.caver.utils.convertFromPeb(item.price),
      }));
      return { success: true, jData: mapped };
    } catch (error) {
      this.logger.error(`mynft failed`, error as Error);
      throw new InternalServerErrorException((error as Error).message);
    }
  }

  async mintNft({ metadata_uri, recipient }: KaiaMintNftDto) {
    if (!this.mintAccount || !this.mintPrivateKey) {
      return { success: false, result: 'Mint account is not configured on the server.' };
    }

    const normalizedRecipient = recipient?.trim() || this.mintAccount;
    const normalizedMetadataUri = metadata_uri.trim();

    try {
      const balanceBeforeRaw = await this.mintContract.methods.balanceOf(this.mintAccount).call();
      const balanceBefore = Number(balanceBeforeRaw ?? 0);

      const data = this.mintContract.methods.mintNFT(normalizedMetadataUri).encodeABI();
      const mintReceipt = await this.sendSignedTransaction({
        from: this.mintAccount,
        pkey: this.mintPrivateKey,
        to: this.mintContract.options.address,
        data,
      });

      let tokenId = this.extractTokenIdFromReceipt(mintReceipt);

      if (tokenId === null) {
        tokenId = await this.resolveTokenIdByMetadata(normalizedMetadataUri);
      }

      if (tokenId === null) {
        try {
          const balanceAfterRaw = await this.mintContract.methods.balanceOf(this.mintAccount).call();
          const balanceAfter = Number(balanceAfterRaw ?? 0);
          if (balanceAfter > balanceBefore) {
            const newestIndex = balanceAfter - 1;
            const candidate = await this.mintContract.methods
              .tokenOfOwnerByIndex(this.mintAccount, newestIndex)
              .call();
            if (candidate !== undefined && candidate !== null) {
              tokenId = String(candidate);
            }
          }
        } catch (fallbackError) {
          this.logger.warn(`tokenId balance fallback failed: ${fallbackError}`);
        }
      }

      let transferReceipt: any = null;
      if (
        tokenId !== null &&
        normalizedRecipient.toLowerCase() !== this.mintAccount.toLowerCase()
      ) {
        const transferData = this.mintContract.methods
          .safeTransferFrom(this.mintAccount, normalizedRecipient, tokenId)
          .encodeABI();

        transferReceipt = await this.sendSignedTransaction({
          from: this.mintAccount,
          pkey: this.mintPrivateKey,
          to: this.mintContract.options.address,
          data: transferData,
        });
      }
      if (tokenId === null) {
        this.logger.warn('Minted NFT but tokenId could not be resolved; asset remains in mint account.');
      }

      return {
        success: true,
        result: {
          mintTx: mintReceipt,
          transferTx: transferReceipt,
          tokenId,
          recipient: normalizedRecipient,
        },
      };
    } catch (error) {
      this.logger.error('mintNft failed', error as Error);
      return { success: false, result: (error as Error).message };
    }
  }

  async registerSale({ from, tokenId, price, pkey }: KaiaOnSaleDto) {
    try {
      const approved = await this.mintContract.methods.isApprovedForAll(from, this.saleContract.options.address).call();
      const owner = await this.mintContract.methods.ownerOf(tokenId).call();

      if (owner.toLowerCase() !== from.toLowerCase()) {
        return { success: false, result: 'Only the owner can list an NFT for sale.' };
      }
      if (!approved) {
        return { success: false, result: 'Grant marketplace approval before listing.' };
      }

      const data = this.saleContract.methods
        .setSaleNftToken(tokenId, this.caver.utils.convertToPeb(price, 'KLAY'))
        .encodeABI();
      const receipt = await this.sendSignedTransaction({
        from,
        pkey,
        to: this.saleContract.options.address,
        data,
      });
      return { success: true, result: receipt };
    } catch (error) {
      return { success: false, result: (error as Error).message ?? 'Unknown error' };
    }
  }

  async saleList({ sfl, stx }: KaiaOnSaleListDto) {
    try {
      const list = await this.getterContract.methods.getSaleNftTokens().call();
      const mapped = await Promise.all(
        list.map(async (item: any) => {
          const meta = await this.fetchIpfsMetadata(item.nftTokenURI);
          return {
            nftTokenId: item.nftTokenId,
            nftTokenURI: item.nftTokenURI,
            ipfsName: meta?.name ?? '',
            ipfsAttributes: Array.isArray(meta?.attributes) && meta.attributes[0]
              ? (meta.attributes[0].value ?? '')
              : '',
            ipfsDescription: meta?.description ?? '',
            ipfsimage: meta?.image ?? '',
            price: this.caver.utils.convertFromPeb(item.price, 'KLAY'),
          };
        })
      );

      const result = sfl && stx ? mapped.filter((entry) => String(entry.nftTokenId) === String(stx)) : mapped;
      return { success: true, jData: result };
    } catch (error) {
      return { success: false, result: (error as Error).message ?? 'Listing failed.' };
    }
  }

  async nftDetail({ tokenId }: KaiaNftDetailDto) {
    try {
      const uri = await this.mintContract.methods.tokenURI(tokenId).call();
      return { success: true, result: uri };
    } catch (error) {
      return { success: false, result: (error as Error).message };
    }
  }

  async buyNft({ from, tokenId, price, pkey }: KaiaBuyNftDto) {
    try {
      const approved = await this.mintContract.methods.isApprovedForAll(from, this.saleContract.options.address).call();
      const owner = await this.mintContract.methods.ownerOf(tokenId).call();

      if (owner.toLowerCase() === from.toLowerCase()) {
        return { success: false, result: 'Owner cannot purchase their own NFT.' };
      }
      if (!approved) {
        return { success: false, result: 'Grant marketplace approval before purchasing.' };
      }

      const data = this.saleContract.methods.buyNftToken(tokenId).encodeABI();
      const value = this.caver.utils.convertToPeb(price, 'KLAY');
      const receipt = await this.sendSignedTransaction({
        from,
        pkey,
        to: this.saleContract.options.address,
        data,
        value,
      });
      return { success: true, result: receipt };
    } catch (error) {
      return { success: false, result: (error as Error).message };
    }
  }

  async burnNft({ from, tokenId, pkey }: KaiaBurnNftDto) {
    try {
      const owner = await this.mintContract.methods.ownerOf(tokenId).call();
      if (owner.toLowerCase() !== from.toLowerCase()) {
        return { success: false, result: 'Only the owner can burn an NFT.' };
      }
      const data = this.saleContract.methods.burn(tokenId).encodeABI();
      const receipt = await this.sendSignedTransaction({
        from,
        pkey,
        to: this.saleContract.options.address,
        data,
      });
      return { success: true, result: receipt };
    } catch (error) {
      return { success: false, result: (error as Error).message };
    }
  }

  async tradeRecordMy(payload: KaiaTradeRecordMyDto) {
    try {
      const qInt = payload.quantity ?? this.decimalToIntString(payload.quantityRaw, payload.quantityDecimals);
      const pInt = payload.price ?? this.decimalToIntString(payload.priceRaw, payload.priceDecimals);

      if (!qInt || !pInt) {
        return { success: false, result: 'quantity/price input missing' };
      }

      const data = this.tradeContract.methods
        .recordMyTrade(
          String(payload.symbol),
          Number(payload.sideValue),
          Number(payload.currencyValue),
          String(qInt),
          Number(payload.quantityDecimals ?? 0),
          String(pInt),
          Number(payload.priceDecimals ?? 0),
          Number(payload.timestamp ?? 0),
        )
        .encodeABI();

      const receipt = await this.sendSignedTransaction({
        from: payload.from,
        pkey: payload.pkey,
        to: this.tradeContract.options.address,
        data,
      });

      const tradeId = await this.extractTradeIdFromReceipt(receipt);
      let uriTx = null;
      if (tradeId !== null && payload.receiptURI) {
        const data2 = this.tradeContract.methods
          .setTradeReceiptURI(String(tradeId), String(payload.receiptURI))
          .encodeABI();
        uriTx = await this.sendSignedTransaction({
          from: payload.from,
          pkey: payload.pkey,
          to: this.tradeContract.options.address,
          data: data2,
        });
      }

      return {
        success: true,
        result: {
          tx_record: receipt,
          tx_setReceiptURI: uriTx,
          tradeId,
        },
      };
    } catch (error) {
      return { success: false, result: (error as Error).message };
    }
  }

  async tradeRecordFor(payload: KaiaTradeRecordForDto) {
    try {
      const data = this.tradeContract.methods
        .recordTrade(
          String(payload.trader),
          String(payload.symbol),
          Number(payload.sideValue),
          Number(payload.currencyValue),
          String(payload.quantity),
          Number(payload.quantityDecimals ?? 0),
          String(payload.price),
          Number(payload.priceDecimals ?? 0),
          Number(payload.timestamp ?? 0),
        )
        .encodeABI();

      const receipt = await this.sendSignedTransaction({
        from: payload.ownerFrom,
        pkey: payload.ownerPkey,
        to: this.tradeContract.options.address,
        data,
      });

      const tradeId = await this.extractTradeIdFromReceipt(receipt);
      let uriTx = null;
      if (tradeId !== null && payload.receiptURI) {
        const data2 = this.tradeContract.methods
          .setTradeReceiptURI(String(tradeId), String(payload.receiptURI))
          .encodeABI();
        uriTx = await this.sendSignedTransaction({
          from: payload.ownerFrom,
          pkey: payload.ownerPkey,
          to: this.tradeContract.options.address,
          data: data2,
        });
      }

      return {
        success: true,
        result: {
          tx_record: receipt,
          tx_setReceiptURI: uriTx,
          tradeId,
        },
      };
    } catch (error) {
      return { success: false, result: (error as Error).message };
    }
  }

  async tradeGet({ id }: KaiaTradeGetDto) {
    try {
      const trade = await this.tradeContract.methods.getTrade(String(id)).call();
      return { success: true, result: trade };
    } catch (error) {
      return { success: false, result: (error as Error).message };
    }
  }

  async tradeListByTrader({ trader, start = 0, count = 10 }: KaiaTradeListByTraderDto) {
    try {
      const list = await this.tradeContract.methods
        .getTradesByTrader(String(trader), String(start), String(count))
        .call();
      return { success: true, list };
    } catch (error) {
      return { success: false, result: (error as Error).message };
    }
  }

  async tradeTradesOf({ trader }: KaiaTradeTradesOfDto) {
    try {
      const count = await this.tradeContract.methods.tradesOf(String(trader)).call();
      return { success: true, count };
    } catch (error) {
      return { success: false, result: (error as Error).message };
    }
  }

  async tradeTotalTrades() {
    try {
      const total = await this.tradeContract.methods.totalTrades().call();
      return { success: true, total };
    } catch (error) {
      return { success: false, result: (error as Error).message };
    }
  }

  async tradeSetReceiptUri({ from, pkey, tradeId, receiptURI }: KaiaTradeSetReceiptUriDto) {
    try {
      const data = this.tradeContract.methods
        .setTradeReceiptURI(String(tradeId), String(receiptURI ?? ''))
        .encodeABI();
      const receipt = await this.sendSignedTransaction({
        from,
        pkey,
        to: this.tradeContract.options.address,
        data,
      });
      return { success: true, result: receipt };
    } catch (error) {
      return { success: false, result: (error as Error).message };
    }
  }
}
