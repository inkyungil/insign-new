import { Controller, Get, Post, Req, Res, UseGuards } from "@nestjs/common";
import { ApiExcludeController } from "@nestjs/swagger";
import { Request, Response } from "express";
import { LocalAuthGuard } from "./local-auth.guard";
import { ADMIN_BASE_PATH, ADMIN_ROUTE_PREFIX } from "../admin/admin.constants";

@Controller(ADMIN_ROUTE_PREFIX)
@ApiExcludeController()
export class AuthController {
  @Get("login")
  async loginForm(@Req() request: Request, @Res() response: Response) {
    if ((request as any).isAuthenticated?.()) {
      response.redirect(ADMIN_BASE_PATH);
      return;
    }

    const { error, redirectTo } = request.query as {
      error?: string;
      redirectTo?: string;
    };
    return response.render("login", {
      title: "관리자 로그인",
      error: error ? "아이디 또는 비밀번호가 올바르지 않습니다." : null,
      redirectTo: redirectTo ?? "",
    });
  }

  @UseGuards(LocalAuthGuard)
  @Post("login")
  async login(@Req() request: Request, @Res() response: Response) {
    if (!request.user) {
      return response.redirect(`${ADMIN_BASE_PATH}/login?error=invalid`);
    }

    await new Promise<void>((resolve, reject) => {
      const logIn = (request as any).logIn;
      if (typeof logIn === "function") {
        logIn.call(request, request.user, (err: unknown) => {
          if (err) {
            reject(err);
            return;
          }

          const session = (request as any).session;
          if (session && typeof session.save === "function") {
            session.save((saveErr: unknown) =>
              saveErr ? reject(saveErr) : resolve(),
            );
          } else {
            resolve();
          }
        });
      } else {
        resolve();
      }
    });

    const redirectTo =
      typeof request.body?.redirectTo === "string" &&
      request.body.redirectTo.startsWith("/")
        ? request.body.redirectTo
        : null;
    return response.redirect(redirectTo ?? `${ADMIN_BASE_PATH}/dashboard`);
  }

  @Post("logout")
  async logout(@Req() request: Request, @Res() response: Response) {
    await new Promise<void>((resolve, reject) => {
      const logout = (request as any).logout;
      if (typeof logout === "function") {
        logout.call(request, (err: unknown) => (err ? reject(err) : resolve()));
      } else {
        resolve();
      }
    });
    return response.redirect(`${ADMIN_BASE_PATH}/login`);
  }
}
