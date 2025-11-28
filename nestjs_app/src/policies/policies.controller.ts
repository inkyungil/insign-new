import { Controller, Get, Param, ParseIntPipe } from "@nestjs/common";
import { ApiTags } from "@nestjs/swagger";
import { PoliciesService } from "./policies.service";
import { Policy } from "./policy.entity";
import { PolicyType } from "./dto/create-policy.dto";

@Controller("api/policies")
@ApiTags("policies")
export class PoliciesController {
  constructor(private readonly policiesService: PoliciesService) {}

  @Get("privacy-policy")
  async getPrivacyPolicy(): Promise<Policy | null> {
    return this.policiesService.findByType(PolicyType.PRIVACY_POLICY);
  }

  @Get("terms-of-service")
  async getTermsOfService(): Promise<Policy | null> {
    return this.policiesService.findByType(PolicyType.TERMS_OF_SERVICE);
  }

  @Get(":id")
  async findOne(@Param("id", ParseIntPipe) id: number): Promise<Policy | null> {
    return this.policiesService.findOne(id);
  }
}
