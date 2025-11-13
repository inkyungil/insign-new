import { Module } from "@nestjs/common";
import { TypeOrmModule } from "@nestjs/typeorm";
import { Policy } from "./policy.entity";
import { PoliciesService } from "./policies.service";
import { PoliciesController } from "./policies.controller";
import { PoliciesViewController } from "./policies.view.controller";

@Module({
  imports: [TypeOrmModule.forFeature([Policy])],
  controllers: [PoliciesController, PoliciesViewController],
  providers: [PoliciesService],
  exports: [PoliciesService],
})
export class PoliciesModule {}
