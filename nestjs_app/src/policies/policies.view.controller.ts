import { Controller, Get, NotFoundException, Render } from "@nestjs/common";
import { PoliciesService } from "./policies.service";
import { PolicyType } from "./dto/create-policy.dto";

@Controller("policies")
export class PoliciesViewController {
  constructor(private readonly policiesService: PoliciesService) {}

  @Get("privacy")
  @Render("policies/privacy")
  async privacy() {
    const policy = await this.policiesService.findByType(PolicyType.PRIVACY_POLICY);
    if (!policy) {
      throw new NotFoundException("등록된 개인정보 처리방침이 없습니다.");
    }

    return {
      title: policy.title,
      version: policy.version,
      updatedAt: policy.updatedAt,
      content: policy.content,
      type: "privacy",
    };
  }

  @Get("terms")
  @Render("policies/terms")
  async terms() {
    const policy = await this.policiesService.findByType(PolicyType.TERMS_OF_SERVICE);
    if (!policy) {
      throw new NotFoundException("등록된 이용약관이 없습니다.");
    }

    return {
      title: policy.title,
      version: policy.version,
      updatedAt: policy.updatedAt,
      content: policy.content,
      type: "terms",
    };
  }
}
