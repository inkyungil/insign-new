import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { SubscriptionPlan } from './entities/subscription-plan.entity';
import { SubscriptionPlansService } from './subscription-plans.service';

@Module({
  imports: [TypeOrmModule.forFeature([SubscriptionPlan])],
  providers: [SubscriptionPlansService],
  exports: [TypeOrmModule, SubscriptionPlansService],
})
export class SubscriptionPlansModule {}
