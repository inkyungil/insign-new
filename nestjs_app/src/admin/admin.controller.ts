import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Post,
  Redirect,
  Render,
  Req,
  UseGuards,
} from "@nestjs/common";
import { ApiExcludeController } from "@nestjs/swagger";
import { Request } from "express";
import { AdminService } from "./admin.service";
import { AuthenticatedGuard } from "../auth/authenticated.guard";
import { ADMIN_BASE_PATH, ADMIN_ROUTE_PREFIX } from "./admin.constants";

function formatDate(value?: Date | null): string {
  if (!value) {
    return "-";
  }
  return new Date(value).toISOString().replace("T", " ").slice(0, 19);
}

@Controller(ADMIN_ROUTE_PREFIX)
@ApiExcludeController()
@UseGuards(AuthenticatedGuard)
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Get()
  @Render("admin/dashboard")
  async dashboard(@Req() request: Request) {
    const stats = await this.adminService.getDashboardStats();
    return {
      user: request.user,
      stats,
    };
  }

  @Get("dashboard")
  @Redirect(ADMIN_BASE_PATH)
  dashboardRedirect() {
    return {};
  }

  @Get("list")
  @Render("admin/list")
  async list(@Req() request: Request) {
    const admins = await this.adminService.findAllAdmins();
    return {
      user: request.user,
      admins: admins.map((admin) => ({
        ...admin,
        createdAt: formatDate(admin.createdAt),
        updatedAt: formatDate(admin.updatedAt),
      })),
    };
  }

  @Post("create")
  async createAdmin(
    @Body("username") username: string,
    @Body("password") password: string,
  ) {
    await this.adminService.createAdmin(username, password);
    return { message: "관리자가 추가되었습니다." };
  }

  @Get(":adminId/json")
  async getAdmin(@Param("adminId", ParseIntPipe) adminId: number) {
    const admin = await this.adminService.findAdminById(adminId);
    return {
      id: admin.id,
      username: admin.username,
    };
  }

  @Post("update/:adminId")
  async updateAdmin(
    @Param("adminId", ParseIntPipe) adminId: number,
    @Body("password") password?: string,
  ) {
    await this.adminService.updateAdminPassword(adminId, password);
    return { message: "관리자 정보가 수정되었습니다." };
  }

  @Post("toggle/:adminId")
  async toggleStatus(
    @Param("adminId", ParseIntPipe) adminId: number,
    @Body("isActive") isActive?: string,
  ) {
    const normalized = ["true", "1", "yes", "y"].includes(
      (isActive ?? "").toLowerCase(),
    );
    await this.adminService.toggleAdminStatus(adminId, normalized);
    return {
      message: `관리자가 ${normalized ? "활성화" : "비활성화"} 되었습니다.`,
    };
  }

  @Post("delete/:adminId")
  async delete(@Param("adminId", ParseIntPipe) adminId: number) {
    await this.adminService.deleteAdmin(adminId);
    return { message: "관리자가 삭제되었습니다." };
  }
}
