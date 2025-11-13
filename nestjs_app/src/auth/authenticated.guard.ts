import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from "@nestjs/common";
import { ADMIN_BASE_PATH } from "../admin/admin.constants";

@Injectable()
export class AuthenticatedGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest();
    const isAuthenticated = (request as any).isAuthenticated?.();

    if (isAuthenticated) {
      return true;
    }

    const response = context.switchToHttp().getResponse();

    if (request.method === "GET") {
      const next = encodeURIComponent(
        request.originalUrl ?? request.url ?? "/",
      );
      response.redirect(`${ADMIN_BASE_PATH}/login?redirectTo=${next}`);
      return false;
    }

    throw new UnauthorizedException("로그인이 필요합니다.");
  }
}
