import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UserSubscription } from './entities/user-subscription.entity';
import { MonthlyUsage } from './entities/monthly-usage.entity';
import { SubscriptionPlan } from '../subscription-plans/entities/subscription-plan.entity';
import { User } from '../users/user.entity';
import { SubscriptionsService } from './subscriptions.service';
import { MonthlyUsageService } from './monthly-usage.service';
import { PointsModule } from '../points/points.module';
import { SubscriptionPlansModule } from '../subscription-plans/subscription-plans.module';
import { UsersModule } from '../users/users.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([UserSubscription, MonthlyUsage, SubscriptionPlan, User]),
    PointsModule,
    SubscriptionPlansModule,
    UsersModule,
  ],
  providers: [SubscriptionsService, MonthlyUsageService],
  exports: [SubscriptionsService, MonthlyUsageService],
})
export class SubscriptionsModule {}
