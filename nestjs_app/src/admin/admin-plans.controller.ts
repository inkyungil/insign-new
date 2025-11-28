import {
  Body,
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Query,
  Render,
  Req,
  Res,
  UseGuards,
  ValidationPipe,
} from '@nestjs/common';
import { ApiExcludeController } from '@nestjs/swagger';
import { Request, Response } from 'express';
import { URLSearchParams } from 'url';
import { AuthenticatedGuard } from '../auth/authenticated.guard';
import { ADMIN_ROUTE_PREFIX } from './admin.constants';
import { SubscriptionPlansService } from '../subscription-plans/subscription-plans.service';
import { AdminCreatePlanDto } from '../subscription-plans/dto/admin-create-plan.dto';
import { AdminUpdatePlanDto } from '../subscription-plans/dto/admin-update-plan.dto';

function formatDate(value?: Date | null) {
  if (!value) {
    return '-';
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return '-';
  }
  return date.toISOString().replace('T', ' ').slice(0, 19);
}

@Controller(`${ADMIN_ROUTE_PREFIX}/plans`)
@ApiExcludeController()
@UseGuards(AuthenticatedGuard)
export class AdminPlansController {
  constructor(private readonly subscriptionPlansService: SubscriptionPlansService) {}

  @Get()
  @Render('admin/plans')
  async index(@Req() request: Request, @Query('planId') planId?: string) {
    const selectedId = this.parseId(planId);
    return this.renderPage({ request, selectedId, query: request.query });
  }

  @Get(':id')
  @Render('admin/plans')
  async detail(@Req() request: Request, @Param('id', ParseIntPipe) id: number) {
    return this.renderPage({ request, selectedId: id, query: request.query });
  }

  @Post()
  async create(
    @Body(
      new ValidationPipe({
        transform: true,
        whitelist: true,
        forbidNonWhitelisted: true,
      }),
    )
    dto: AdminCreatePlanDto,
    @Res() response: Response,
  ) {
    try {
      const created = await this.subscriptionPlansService.createPlan(dto);
      const params = new URLSearchParams({ success: 'created' });
      return response.redirect(`/adm/plans/${created.id}?${params.toString()}`);
    } catch (error) {
      const params = new URLSearchParams({
        errorMessage: error instanceof Error ? error.message : '요금제 생성 중 오류가 발생했습니다.',
      });
      return response.redirect(`/adm/plans?${params.toString()}`);
    }
  }

  @Post(':id')
  async update(
    @Param('id', ParseIntPipe) id: number,
    @Body(
      new ValidationPipe({
        transform: true,
        whitelist: true,
        forbidNonWhitelisted: true,
      }),
    )
    dto: AdminUpdatePlanDto,
    @Res() response: Response,
  ) {
    try {
      await this.subscriptionPlansService.updatePlan(id, dto);
      const params = new URLSearchParams({ success: 'updated' });
      return response.redirect(`/adm/plans/${id}?${params.toString()}`);
    } catch (error) {
      const params = new URLSearchParams({
        errorMessage: error instanceof Error ? error.message : '요금제 수정 중 오류가 발생했습니다.',
      });
      return response.redirect(`/adm/plans/${id}?${params.toString()}`);
    }
  }

  @Post(':id/delete')
  async delete(@Param('id', ParseIntPipe) id: number, @Res() response: Response) {
    try {
      await this.subscriptionPlansService.deletePlan(id);
      const params = new URLSearchParams({ success: 'deleted' });
      return response.redirect(`/adm/plans?${params.toString()}`);
    } catch (error) {
      const params = new URLSearchParams({
        errorMessage: error instanceof Error ? error.message : '요금제를 삭제할 수 없습니다.',
      });
      return response.redirect(`/adm/plans/${id}?${params.toString()}`);
    }
  }

  private async renderPage(params: {
    request: Request;
    selectedId?: number;
    query: Record<string, any>;
  }) {
    const [plans, selectedPlan] = await Promise.all([
      this.subscriptionPlansService.listAll(true),
      params.selectedId ? this.safeFind(params.selectedId) : Promise.resolve(null),
    ]);

    const successMessage = this.resolveSuccessMessage(params.query);
    const errorMessage = this.resolveErrorMessage(params.query);

    return {
      user: params.request.user,
      plans: plans.map((plan) => this.serializePlanSummary(plan, params.selectedId)),
      selectedPlan: selectedPlan ? this.serializePlanDetail(selectedPlan) : null,
      successMessage,
      errorMessage,
      defaultForm: {
        tier: 'free',
        name: '무료',
        monthlyContractLimit: 4,
        monthlyPointsLimit: 12,
        initialPoints: 12,
        priceMonthly: 0,
        priceYearly: '',
      },
    };
  }

  private async safeFind(id: number) {
    try {
      return await this.subscriptionPlansService.findById(id);
    } catch {
      return null;
    }
  }

  private serializePlanSummary(plan: any, selectedId?: number) {
    return {
      id: plan.id,
      tier: plan.tier,
      name: plan.name,
      isActive: plan.isActive,
      displayOrder: plan.displayOrder,
      priceMonthly: plan.priceMonthly,
      priceYearly: plan.priceYearly,
      contracts: plan.monthlyContractLimit,
      points: plan.monthlyPointsLimit,
      isSelected: selectedId === plan.id,
    };
  }

  private serializePlanDetail(plan: any) {
    return {
      id: plan.id,
      tier: plan.tier,
      name: plan.name,
      description: plan.description ?? '',
      monthlyContractLimit: plan.monthlyContractLimit,
      monthlyPointsLimit: plan.monthlyPointsLimit,
      initialPoints: plan.initialPoints,
      priceMonthly: plan.priceMonthly,
      priceYearly: plan.priceYearly ?? '',
      isActive: plan.isActive,
      displayOrder: plan.displayOrder,
      createdAt: formatDate(plan.createdAt),
      updatedAt: formatDate(plan.updatedAt),
      featuresText: plan.features ? JSON.stringify(plan.features, null, 2) : '',
    };
  }

  private resolveSuccessMessage(query: Record<string, any>) {
    const success = typeof query.success === 'string' ? query.success : null;
    if (success === 'created') {
      return '새 요금제를 생성했습니다.';
    }
    if (success === 'updated') {
      return '요금제를 수정했습니다.';
    }
    if (success === 'deleted') {
      return '요금제를 삭제했습니다.';
    }
    return null;
  }

  private resolveErrorMessage(query: Record<string, any>) {
    const message = typeof query.errorMessage === 'string' ? query.errorMessage : null;
    return message || null;
  }

  private parseId(value?: string) {
    if (!value) {
      return undefined;
    }
    const parsed = Number(value);
    return Number.isNaN(parsed) ? undefined : parsed;
  }
}
