import { Injectable, NotFoundException, OnModuleInit } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import * as bcrypt from "bcrypt";
import { Admin } from "./admin.entity";

@Injectable()
export class AdminService implements OnModuleInit {
  constructor(
    @InjectRepository(Admin)
    private readonly adminRepository: Repository<Admin>,
  ) {}

  async onModuleInit() {
    const count = await this.adminRepository.count();
    if (count === 0) {
      const passwordHash = await bcrypt.hash("admin1234", 10);
      await this.adminRepository.save({
        username: "admin",
        passwordHash,
        isActive: true,
      });

      console.info(
        "[AdminService] seeded default admin account: admin/admin1234",
      );
    }
  }

  async getDashboardStats() {
    const [totalAdmins, activeAdmins] = await Promise.all([
      this.adminRepository.count(),
      this.adminRepository.count({ where: { isActive: true } }),
    ]);

    return {
      totalAdmins,
      activeAdmins,
    };
  }

  async findAllAdmins() {
    return this.adminRepository.find({ order: { id: "ASC" } });
  }

  async createAdmin(username: string, password: string) {
    const passwordHash = await bcrypt.hash(password, 10);
    const admin = this.adminRepository.create({
      username,
      passwordHash,
      isActive: true,
    });
    return this.adminRepository.save(admin);
  }

  async updateAdminPassword(adminId: number, password?: string) {
    const admin = await this.adminRepository.findOne({
      where: { id: adminId },
    });
    if (!admin) {
      throw new NotFoundException("관리자를 찾을 수 없습니다.");
    }

    if (password) {
      admin.passwordHash = await bcrypt.hash(password, 10);
    }

    return this.adminRepository.save(admin);
  }

  async toggleAdminStatus(adminId: number, isActive: boolean) {
    const admin = await this.adminRepository.findOne({
      where: { id: adminId },
    });
    if (!admin) {
      throw new NotFoundException("관리자를 찾을 수 없습니다.");
    }

    admin.isActive = isActive;
    return this.adminRepository.save(admin);
  }

  async deleteAdmin(adminId: number) {
    const admin = await this.adminRepository.findOne({
      where: { id: adminId },
    });
    if (!admin) {
      throw new NotFoundException("관리자를 찾을 수 없습니다.");
    }

    await this.adminRepository.remove(admin);
    return true;
  }
}
