import {
  Column,
  CreateDateColumn,
  Entity,
  Index,
  PrimaryGeneratedColumn,
  UpdateDateColumn,
} from "typeorm";

@Entity({ name: "users" })
export class User {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ type: "varchar", length: 255 })
  email!: string;

  @Index({ unique: true })
  @Column({ name: "email_hash", type: "char", length: 64 })
  emailHash!: string;

  @Column({
    name: "password_hash",
    type: "varchar",
    length: 255,
    nullable: true,
  })
  passwordHash?: string | null;

  @Column({
    name: "display_name",
    type: "varchar",
    length: 120,
    nullable: true,
  })
  displayName?: string | null;

  @Column({ type: "varchar", length: 20, default: "local" })
  provider!: "local" | "google";

  @Column({
    name: "google_id",
    type: "varchar",
    length: 64,
    nullable: true,
    unique: true,
  })
  googleId?: string | null;

  @Column({ name: "avatar_url", type: "varchar", length: 255, nullable: true })
  avatarUrl?: string | null;

  @Column({ name: "is_active", type: "tinyint", default: true })
  isActive!: boolean;

  @Column({ name: "last_login_at", type: "datetime", nullable: true })
  lastLoginAt?: Date | null;

  @CreateDateColumn({ name: "created_at" })
  createdAt!: Date;

  @UpdateDateColumn({ name: "updated_at" })
  updatedAt!: Date;
}
