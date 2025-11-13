import { Injectable, NotFoundException } from "@nestjs/common";
import { InjectRepository } from "@nestjs/typeorm";
import { Repository } from "typeorm";
import { Policy } from "./policy.entity";
import { CreatePolicyDto, PolicyType } from "./dto/create-policy.dto";
import { UpdatePolicyDto } from "./dto/update-policy.dto";

@Injectable()
export class PoliciesService {
  constructor(
    @InjectRepository(Policy)
    private readonly policiesRepository: Repository<Policy>,
  ) {}

  async findAll(): Promise<Policy[]> {
    return this.policiesRepository.find({
      order: { updatedAt: "DESC" },
    });
  }

  async findOne(id: number): Promise<Policy | null> {
    return this.policiesRepository.findOne({ where: { id } });
  }

  async findByType(type: PolicyType): Promise<Policy | null> {
    return this.policiesRepository.findOne({
      where: { type, isActive: true },
      order: { updatedAt: "DESC" },
    });
  }

  async create(createPolicyDto: CreatePolicyDto): Promise<Policy> {
    // 같은 타입의 정책을 active로 설정하면 기존 active 정책을 비활성화
    if (createPolicyDto.isActive) {
      await this.policiesRepository.update(
        { type: createPolicyDto.type, isActive: true },
        { isActive: false },
      );
    }

    const policy = this.policiesRepository.create(createPolicyDto);
    return this.policiesRepository.save(policy);
  }

  async update(id: number, updatePolicyDto: UpdatePolicyDto): Promise<Policy> {
    const policy = await this.findOne(id);
    if (!policy) {
      throw new NotFoundException(`정책 ID ${id}를 찾을 수 없습니다.`);
    }

    // 같은 타입의 정책을 active로 설정하면 기존 active 정책을 비활성화
    if (updatePolicyDto.isActive) {
      await this.policiesRepository.update(
        { type: policy.type, isActive: true },
        { isActive: false },
      );
    }

    Object.assign(policy, updatePolicyDto);
    return this.policiesRepository.save(policy);
  }

  async delete(id: number): Promise<void> {
    const result = await this.policiesRepository.delete(id);
    if (result.affected === 0) {
      throw new NotFoundException(`정책 ID ${id}를 찾을 수 없습니다.`);
    }
  }

  async setActive(id: number): Promise<Policy> {
    const policy = await this.findOne(id);
    if (!policy) {
      throw new NotFoundException(`정책 ID ${id}를 찾을 수 없습니다.`);
    }

    // 같은 타입의 기존 active 정책을 비활성화
    await this.policiesRepository.update(
      { type: policy.type, isActive: true },
      { isActive: false },
    );

    policy.isActive = true;
    return this.policiesRepository.save(policy);
  }
}
