import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
} from "typeorm";
import { PolicyType } from "./dto/create-policy.dto";

@Entity("policies")
export class Policy {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({
    type: "enum",
    enum: PolicyType,
  })
  type!: PolicyType;

  @Column({ length: 255 })
  title!: string;

  @Column({ type: "text" })
  content!: string;

  @Column({ type: "varchar", nullable: true, length: 50 })
  version!: string | null;

  @Column({ type: "boolean", default: false })
  isActive!: boolean;

  @CreateDateColumn()
  createdAt!: Date;

  @UpdateDateColumn()
  updatedAt!: Date;
}
