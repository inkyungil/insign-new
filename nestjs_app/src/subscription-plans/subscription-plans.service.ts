import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DeepPartial, Repository } from 'typeorm';
import { SubscriptionPlan } from './entities/subscription-plan.entity';
import { AdminCreatePlanDto } from './dto/admin-create-plan.dto';
import { AdminUpdatePlanDto } from './dto/admin-update-plan.dto';

@Injectable()
export class SubscriptionPlansService {
  constructor(
    @InjectRepository(SubscriptionPlan)
    private readonly planRepository: Repository<SubscriptionPlan>,
  ) {}

  async listAll(includeInactive = true) {
    return this.planRepository.find({
      where: includeInactive ? {} : { isActive: true },
      order: { displayOrder: 'ASC', id: 'ASC' },
    });
  }

  async findById(id: number) {
    const plan = await this.planRepository.findOne({ where: { id } });
    if (!plan) {
      throw new NotFoundException('요금제를 찾을 수 없습니다.');
    }
    return plan;
  }

  async createPlan(dto: AdminCreatePlanDto) {
    await this.ensureUniqueTier(dto.tier);
    const payload: DeepPartial<SubscriptionPlan> = {
      tier: dto.tier.trim(),
      name: dto.name.trim(),
      description: dto.description?.trim() || null,
      monthlyContractLimit: dto.monthlyContractLimit,
      monthlyPointsLimit: dto.monthlyPointsLimit,
      initialPoints: dto.initialPoints,
      priceMonthly: dto.priceMonthly,
      priceYearly: dto.priceYearly ?? null,
      features: this.parseFeatures(dto.features),
      isActive: dto.isActive ?? true,
      displayOrder: dto.displayOrder ?? 0,
    };

    const plan = this.planRepository.create(payload);

    return this.planRepository.save(plan);
  }

  async updatePlan(id: number, dto: AdminUpdatePlanDto) {
    const plan = await this.findById(id);

    if (dto.tier && dto.tier !== plan.tier) {
      await this.ensureUniqueTier(dto.tier, id);
      plan.tier = dto.tier.trim();
    }

    if (dto.name !== undefined) {
      plan.name = dto.name?.trim() || plan.name;
    }

    if (dto.description !== undefined) {
      plan.description = dto.description?.trim() || null;
    }

    if (dto.monthlyContractLimit !== undefined) {
      plan.monthlyContractLimit = dto.monthlyContractLimit;
    }

    if (dto.monthlyPointsLimit !== undefined) {
      plan.monthlyPointsLimit = dto.monthlyPointsLimit;
    }

    if (dto.initialPoints !== undefined) {
      plan.initialPoints = dto.initialPoints;
    }

    if (dto.priceMonthly !== undefined) {
      plan.priceMonthly = dto.priceMonthly;
    }

    if (dto.priceYearly !== undefined) {
      plan.priceYearly = dto.priceYearly;
    }

    if (dto.features !== undefined) {
      plan.features = this.parseFeatures(dto.features);
    }

    if (dto.isActive !== undefined) {
      plan.isActive = dto.isActive;
    }

    if (dto.displayOrder !== undefined) {
      plan.displayOrder = dto.displayOrder;
    }

    return this.planRepository.save(plan);
  }

  async deletePlan(id: number) {
    const plan = await this.findById(id);
    const result = await this.planRepository.delete({ id: plan.id });
    if (!result.affected) {
      throw new BadRequestException('요금제를 삭제할 수 없습니다.');
    }
  }

  private async ensureUniqueTier(tier: string, ignoreId?: number) {
    const existing = await this.planRepository.findOne({ where: { tier } });
    if (existing && existing.id !== ignoreId) {
      throw new BadRequestException('이미 사용 중인 티어입니다.');
    }
  }

  private parseFeatures(raw?: string | object | null) {
    if (raw === undefined) {
      return undefined;
    }
    if (raw === null || raw === '') {
      return null;
    }

    if (typeof raw === 'object') {
      return raw;
    }

    const trimmed = raw.trim();
    if (!trimmed) {
      return null;
    }

    try {
      return JSON.parse(trimmed);
    } catch (error) {
      throw new BadRequestException('features 필드는 유효한 JSON 이어야 합니다.');
    }
  }
}
