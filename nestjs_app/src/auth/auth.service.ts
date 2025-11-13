import { Injectable } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import * as bcrypt from "bcrypt";
import { Admin } from "../admin/admin.entity";

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(Admin)
    private readonly adminRepository: Repository<Admin>,
  ) {}

  async validateUser(username: string, password: string) {
    const admin = await this.adminRepository.findOne({
      where: { username, isActive: true },
    });

    if (!admin) {
      console.warn("[AuthService] 로그인 실패 - 사용자 없음 또는 비활성화", {
        username,
      });
      return null;
    }

    const passwordMatches = await bcrypt.compare(password, admin.passwordHash);
    if (!passwordMatches) {
      console.warn("[AuthService] 로그인 실패 - 비밀번호 불일치", { username });
      return null;
    }

    console.info("[AuthService] 로그인 성공", { username });
    return {
      id: admin.id,
      username: admin.username,
    };
  }
}
