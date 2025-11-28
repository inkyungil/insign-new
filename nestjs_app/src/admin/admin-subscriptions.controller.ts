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
import { SubscriptionsService } from '../subscriptions/subscriptions.service';
import { UsersService } from '../users/users.service';
import { SubscriptionStatus, UserSubscription } from '../subscriptions/entities/user-subscription.entity';
import { AdminCreateSubscriptionDto } from '../subscriptions/dto/admin-create-subscription.dto';
import { AdminUpdateSubscriptionDto } from '../subscriptions/dto/admin-update-subscription.dto';
import { EncryptionService } from '../common/encryption.service';

const STATUS_META: Record<SubscriptionStatus, { label: string; badgeClass: string }> = {
  [SubscriptionStatus.ACTIVE]: { label: '활성', badgeClass: 'badge-success' },
  [SubscriptionStatus.PENDING]: { label: '대기', badgeClass: 'badge-warning' },
  [SubscriptionStatus.CANCELLED]: { label: '취소', badgeClass: 'badge-secondary' },
  [SubscriptionStatus.EXPIRED]: { label: '만료', badgeClass: 'badge-dark' },
};

function formatDateTime(value?: Date | string | null) {
  if (!value) {
    return '-';
  }
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) {
    return '-';
  }
  return date.toISOString().replace('T', ' ').slice(0, 19);
}

function formatInputDate(value?: Date | null) {
  if (!value) {
    return '';
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return '';
  }
  const local = new Date(date.getTime() - date.getTimezoneOffset() * 60000);
  return local.toISOString().slice(0, 16);
}

@Controller(`${ADMIN_ROUTE_PREFIX}/subscriptions`)
@ApiExcludeController()
@UseGuards(AuthenticatedGuard)
export class AdminSubscriptionsController {
  constructor(
    private readonly subscriptionsService: SubscriptionsService,
    private readonly usersService: UsersService,
    private readonly encryptionService: EncryptionService,
  ) {}

  @Get()
  @Render('admin/subscriptions')
  async index(@Req() request: Request, @Query() query: Record<string, any>) {
    const selectedId = this.parseId(query.subscriptionId);
    return this.renderPage({ request, query, selectedId });
  }

  @Get(':id')
  @Render('admin/subscriptions')
  async detail(
    @Req() request: Request,
    @Param('id', ParseIntPipe) id: number,
    @Query() query: Record<string, any>,
  ) {
    return this.renderPage({ request, query, selectedId: id });
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
    dto: AdminCreateSubscriptionDto,
    @Res() response: Response,
  ) {
    try {
      const created = await this.subscriptionsService.createSubscriptionForAdmin(dto);
      const successQuery = new URLSearchParams({ success: 'created' });
      return response.redirect(`/adm/subscriptions/${created.id}?${successQuery.toString()}`);
    } catch (error) {
      const message =
        error instanceof Error
          ? error.message
          : '구독 생성 중 오류가 발생했습니다.';
      const params = new URLSearchParams({ errorMessage: message });
      return response.redirect(`/adm/subscriptions?${params.toString()}`);
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
    dto: AdminUpdateSubscriptionDto,
    @Res() response: Response,
  ) {
    try {
      await this.subscriptionsService.updateSubscriptionForAdmin(id, dto);
      const params = new URLSearchParams({ success: 'updated' });
      return response.redirect(`/adm/subscriptions/${id}?${params.toString()}`);
    } catch (error) {
      const message =
        error instanceof Error
          ? error.message
          : '구독 수정 중 오류가 발생했습니다.';
      const params = new URLSearchParams({ errorMessage: message });
      return response.redirect(`/adm/subscriptions/${id}?${params.toString()}`);
    }
  }

  private async renderPage(params: {
    request: Request;
    query: Record<string, any>;
    selectedId?: number;
  }) {
    const filters = await this.resolveFilters(params.query);
    const [subscriptions, summary, plans] = await Promise.all([
      this.subscriptionsService.listSubscriptionsForAdmin({
        status: filters.status,
        planId: filters.planId,
        userId: filters.userId,
        keyword: filters.keyword,
        take: 80,
      }),
      this.subscriptionsService.getSubscriptionStatusSummary(),
      this.subscriptionsService.listPlansForAdmin(true),
    ]);

    let selected: UserSubscription | null = null;
    let detailError: string | null = null;
    if (params.selectedId) {
      try {
        selected = await this.subscriptionsService.findSubscriptionWithRelations(
          params.selectedId,
        );
      } catch (error) {
        detailError = '선택한 구독을 찾을 수 없습니다.';
      }
    }

    let stats: Awaited<ReturnType<typeof this.subscriptionsService.getUserSubscriptionStats>> | null =
      null;
    if (selected) {
      try {
        stats = await this.subscriptionsService.getUserSubscriptionStats(
          selected.userId,
        );
      } catch {
        stats = null;
      }
    }

    const successMessage = this.resolveSuccessMessage(params.query);
    const errorMessage = this.resolveErrorMessage(params.query);
    const listItems = subscriptions.map((item) =>
      this.buildSubscriptionRow(item, selected?.id ?? null),
    );

    return {
      user: params.request.user,
      summary,
      subscriptions: listItems,
      selectedSubscription: selected
        ? this.buildSubscriptionDetail(selected, stats)
        : null,
      selectedSubscriptionId: selected?.id ?? null,
      detailError,
      filters,
      statusOptions: this.getStatusOptions(),
      plans: plans.map((plan) => ({
        id: plan.id,
        name: plan.name,
        tier: plan.tier,
        monthlyContractLimit: plan.monthlyContractLimit,
        monthlyPointsLimit: plan.monthlyPointsLimit,
        isActive: plan.isActive,
      })),
      defaultStartedAtInput: formatInputDate(new Date()),
      successMessage,
      errorMessage,
    };
  }

  private async resolveFilters(query: Record<string, any>) {
    const filters: {
      status?: SubscriptionStatus;
      planId?: number;
      keyword?: string;
      keywordInput?: string;
      userId?: number;
      queryString: string;
      notice?: string | null;
    } = {
      keywordInput: '',
      queryString: '',
    };

    const rawStatus = typeof query.status === 'string' ? query.status : undefined;
    if (rawStatus && Object.values(SubscriptionStatus).includes(rawStatus as SubscriptionStatus)) {
      filters.status = rawStatus as SubscriptionStatus;
    }

    const rawPlanId = typeof query.planId === 'string' ? Number(query.planId) : NaN;
    if (!Number.isNaN(rawPlanId) && rawPlanId > 0) {
      filters.planId = rawPlanId;
    }

    const keyword = typeof query.keyword === 'string' ? query.keyword.trim() : '';
    if (keyword) {
      filters.keywordInput = keyword;
      if (keyword.includes('@')) {
        try {
          const user = await this.usersService.findByEmailIncludingInactive(keyword);
          if (user) {
            filters.userId = user.id;
          } else {
            filters.notice = '해당 이메일 사용자를 찾을 수 없습니다.';
          }
        } catch {
          filters.notice = '해당 이메일 사용자를 찾을 수 없습니다.';
        }
      } else {
        filters.keyword = keyword.toLowerCase();
      }
    }

    const params = new URLSearchParams();
    if (filters.status) {
      params.set('status', filters.status);
    }
    if (filters.planId) {
      params.set('planId', String(filters.planId));
    }
    if (filters.keywordInput) {
      params.set('keyword', filters.keywordInput);
    }

    filters.queryString = params.toString();
    return filters;
  }

  private resolveSuccessMessage(query: Record<string, any>) {
    const success = typeof query.success === 'string' ? query.success : null;
    if (success === 'created') {
      return '새 구독을 생성했습니다.';
    }
    if (success === 'updated') {
      return '구독 정보를 업데이트했습니다.';
    }
    return null;
  }

  private resolveErrorMessage(query: Record<string, any>) {
    const errorText = typeof query.errorMessage === 'string' ? query.errorMessage : null;
    return errorText || null;
  }

  private buildSubscriptionRow(subscription: UserSubscription, selectedId: number | null) {
    const meta = STATUS_META[subscription.status] ?? STATUS_META[SubscriptionStatus.PENDING];
    const userEmail = this.decryptEmail(subscription.user?.email);
    return {
      id: subscription.id,
      isSelected: selectedId === subscription.id,
      userId: subscription.userId,
      userEmail,
      userName: subscription.user?.displayName ?? '-',
      planName: subscription.plan?.name ?? '-',
      planTier: subscription.plan?.tier ?? '-',
      statusLabel: meta.label,
      statusBadgeClass: meta.badgeClass,
      status: subscription.status,
      startedAt: formatDateTime(subscription.startedAt),
      expiresAt: formatDateTime(subscription.expiresAt ?? null),
      autoRenew: subscription.autoRenew,
      amountPaid: subscription.amountPaid,
    };
  }

  private buildSubscriptionDetail(
    subscription: UserSubscription,
    stats: Awaited<ReturnType<typeof this.subscriptionsService.getUserSubscriptionStats>> | null,
  ) {
    const meta = STATUS_META[subscription.status] ?? STATUS_META[SubscriptionStatus.PENDING];
    const userEmail = this.decryptEmail(subscription.user?.email);
    const statsView = stats
      ? {
          subscription: {
            ...stats.subscription,
            startedAt: formatDateTime(stats.subscription.startedAt),
            expiresAt: formatDateTime(stats.subscription.expiresAt),
          },
          usage: stats.usage,
          points: stats.points,
        }
      : null;
    return {
      id: subscription.id,
      userId: subscription.userId,
      userEmail,
      userName: subscription.user?.displayName ?? '-',
      status: subscription.status,
      statusLabel: meta.label,
      statusBadgeClass: meta.badgeClass,
      planName: subscription.plan?.name ?? '-',
      planTier: subscription.plan?.tier ?? '-',
      contractLimit: subscription.plan?.monthlyContractLimit ?? null,
      pointsLimit: subscription.plan?.monthlyPointsLimit ?? null,
      startedAt: formatDateTime(subscription.startedAt),
      expiresAt: formatDateTime(subscription.expiresAt ?? null),
      createdAt: formatDateTime(subscription.createdAt),
      updatedAt: formatDateTime(subscription.updatedAt),
      autoRenew: subscription.autoRenew,
      paymentMethod: subscription.paymentMethod ?? '-',
      paymentId: subscription.paymentId ?? '-',
      amountPaid: subscription.amountPaid,
      cancelReason: subscription.cancelReason ?? null,
      expiresAtInput: formatInputDate(subscription.expiresAt ?? null),
      stats: statsView,
    };
  }

  private getStatusOptions() {
    return Object.entries(STATUS_META).map(([value, meta]) => ({
      value,
      label: meta.label,
    }));
  }

  private decryptEmail(value?: string | null) {
    if (!value) {
      return '-';
    }
    try {
      return this.encryptionService.decrypt(value);
    } catch {
      return value;
    }
  }

  private parseId(value: unknown) {
    if (typeof value !== 'string') {
      return undefined;
    }
    const parsed = Number(value);
    if (Number.isNaN(parsed) || parsed <= 0) {
      return undefined;
    }
    return parsed;
  }
}
