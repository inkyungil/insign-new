import { Injectable } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";

@Injectable()
export class AppService {
  constructor(private readonly configService: ConfigService) {}

  getHealth() {
    return {
      status: "ok",
      timestamp: new Date().toISOString(),
    };
  }

  getAppUpdateInfo() {
    return {
      android: this.buildPlatformInfo("ANDROID"),
      ios: this.buildPlatformInfo("IOS"),
      message:
        this.configService.get<string>("APP_FORCE_UPDATE_MESSAGE") ??
        "최신 버전으로 업데이트 후 이용해 주세요.",
    };
  }

  private buildPlatformInfo(platform: "ANDROID" | "IOS") {
    const prefix = platform.toUpperCase();
    const fallbackVersion = "1.0.0";
    const fallbackStoreUrl =
      platform === "ANDROID"
        ? "https://play.google.com/store/apps/details?id=com.insign.app"
        : "https://apps.apple.com/kr/app";

    return {
      minimumSupportedVersion:
        this.configService.get<string>(`${prefix}_MIN_VERSION`) ?? fallbackVersion,
      latestVersion:
        this.configService.get<string>(`${prefix}_LATEST_VERSION`) ?? fallbackVersion,
      storeUrl:
        this.configService.get<string>(`${prefix}_STORE_URL`) ?? fallbackStoreUrl,
    };
  }
}
