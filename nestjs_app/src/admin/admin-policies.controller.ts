import {
  Controller,
  Get,
  Post,
  Body,
  Param,
  Render,
  Res,
  UseGuards,
} from "@nestjs/common";
import { Response } from "express";
import { AuthenticatedGuard } from "../auth/authenticated.guard";
import { PoliciesService } from "../policies/policies.service";
import { CreatePolicyDto } from "../policies/dto/create-policy.dto";
import { UpdatePolicyDto } from "../policies/dto/update-policy.dto";
import { ValidationPipe } from "@nestjs/common";
import { ADMIN_BASE_PATH, ADMIN_ROUTE_PREFIX } from "./admin.constants";

const validationPipe = new ValidationPipe({
  whitelist: true,
  forbidNonWhitelisted: true,
  transform: true,
});

@Controller(`${ADMIN_ROUTE_PREFIX}/policies`)
@UseGuards(AuthenticatedGuard)
export class AdminPoliciesController {
  constructor(private readonly policiesService: PoliciesService) {}

  @Get()
  @Render("admin/policies/index")
  async list() {
    const policies = await this.policiesService.findAll();
    return {
      policies,
      title: "약관 및 정책 관리",
    };
  }

  @Get("new")
  @Render("admin/policies/new")
  newForm() {
    return {
      title: "새 약관/정책 작성",
    };
  }

  @Post()
  async create(
    @Body(validationPipe) createPolicyDto: CreatePolicyDto,
    @Res() res: Response,
  ) {
    try {
      await this.policiesService.create(createPolicyDto);
      res.redirect(`${ADMIN_BASE_PATH}/policies`);
    } catch (error: any) {
      res.status(400).send(error.message);
    }
  }

  @Get(":id/edit")
  @Render("admin/policies/edit")
  async editForm(@Param("id") id: string) {
    const policy = await this.policiesService.findOne(+id);
    if (!policy) {
      throw new Error("정책을 찾을 수 없습니다.");
    }
    return {
      policy,
      title: "약관/정책 수정",
    };
  }

  @Post(":id")
  async update(
    @Param("id") id: string,
    @Body(validationPipe) updatePolicyDto: UpdatePolicyDto,
    @Res() res: Response,
  ) {
    try {
      await this.policiesService.update(+id, updatePolicyDto);
      res.redirect(`${ADMIN_BASE_PATH}/policies`);
    } catch (error: any) {
      res.status(400).send(error.message);
    }
  }

  @Post(":id/activate")
  async setActive(@Param("id") id: string, @Res() res: Response) {
    try {
      await this.policiesService.setActive(+id);
      res.redirect(`${ADMIN_BASE_PATH}/policies`);
    } catch (error: any) {
      res.status(400).send(error.message);
    }
  }

  @Post(":id/delete")
  async delete(@Param("id") id: string, @Res() res: Response) {
    try {
      await this.policiesService.delete(+id);
      res.redirect(`${ADMIN_BASE_PATH}/policies`);
    } catch (error: any) {
      res.status(400).send(error.message);
    }
  }
}
