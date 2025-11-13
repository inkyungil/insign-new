import { Test, TestingModule } from "@nestjs/testing";
import { AppController } from "./app.controller";
import { AppService } from "./app.service";
import { ADMIN_BASE_PATH } from "./admin/admin.constants";

describe("AppController", () => {
  let appController: AppController;

  beforeEach(async () => {
    const app: TestingModule = await Test.createTestingModule({
      controllers: [AppController],
      providers: [AppService],
    }).compile();

    appController = app.get<AppController>(AppController);
  });

  it("should redirect root to /adm", () => {
    expect(appController.root()).toEqual({
      message: `Redirecting to ${ADMIN_BASE_PATH}`,
    });
  });

  it("should return health payload", () => {
    const health = appController.getHealth();
    expect(health.status).toBe("ok");
  });
});
