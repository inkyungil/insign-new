import { Controller, Get, Redirect } from "@nestjs/common";
import { ApiTags } from "@nestjs/swagger";
import { AppService } from "./app.service";
import { ADMIN_BASE_PATH } from "./admin/admin.constants";

@ApiTags("root")
@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get()
  @Redirect(ADMIN_BASE_PATH, 302)
  root() {
    return { message: `Redirecting to ${ADMIN_BASE_PATH}` };
  }

  @Get("health")
  getHealth() {
    return this.appService.getHealth();
  }
}
