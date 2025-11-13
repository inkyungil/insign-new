import { NestFactory } from "@nestjs/core";
import { AppModule } from "../app.module";
import { DataSource } from "typeorm";

type FieldSnapshot = {
  status: "ENCRYPTED" | "PLAIN" | "NULL";
  label: string;
  length: number;
  preview: string | null;
};

const ENCRYPTED_PATTERN = /^[0-9a-fA-F]+:[0-9a-fA-F]+:[0-9a-fA-F]+$/;
const ENCRYPTED_SQL_PATTERN = "^[0-9a-fA-F]+:[0-9a-fA-F]+:[0-9a-fA-F]+$";

type ContractRow = {
  id: number;
  name: string;
  client_contact: string | null;
  client_email: string | null;
  performer_contact: string | null;
  performer_email: string | null;
  metadata: string | null;
};

type StatsRow = {
  total: number;
  encrypted_client_contact: number;
  plain_client_contact: number;
  encrypted_client_email: number;
  plain_client_email: number;
  encrypted_performer_contact: number;
  plain_performer_contact: number;
  encrypted_performer_email: number;
  plain_performer_email: number;
  encrypted_metadata: number;
  plain_metadata: number;
};

function analyzeField(value: string | null): FieldSnapshot {
  if (!value) {
    return {
      status: "NULL",
      label: "⚪ NULL",
      length: 0,
      preview: null,
    };
  }

  const encrypted = ENCRYPTED_PATTERN.test(value.trim());
  return {
    status: encrypted ? "ENCRYPTED" : "PLAIN",
    label: encrypted ? "✅ 암호화됨" : "❌ 평문",
    length: value.length,
    preview: value.length > 60 ? `${value.slice(0, 60)}...` : value,
  };
}

function logField(label: string, snapshot: FieldSnapshot) {
  console.log(`  ${label}:`);
  console.log(`    - 상태: ${snapshot.label}`);
  console.log(`    - 길이: ${snapshot.length}자`);
  if (snapshot.preview) {
    console.log(`    - 미리보기: ${snapshot.preview}`);
  }
}

/**
 * 암호화 상태 확인 스크립트
 */
async function checkEncryption() {
  console.log("🔍 암호화 상태 확인 중...\n");

  const app = await NestFactory.createApplicationContext(AppModule);
  const dataSource = app.get(DataSource);

  try {
    const recentContracts = (await dataSource.query(`
      SELECT
        id,
        name,
        client_contact,
        client_email,
        performer_contact,
        performer_email,
        metadata
      FROM contracts
      ORDER BY id DESC
      LIMIT 5
    `)) as ContractRow[];

    console.log("=".repeat(100));
    console.log("📊 최근 5개 계약 암호화 상태");
    console.log("=".repeat(100));
    console.log("");

    recentContracts.forEach((contract) => {
      console.log(`[계약 ID ${contract.id}] ${contract.name}`);
      logField("clientContact", analyzeField(contract.client_contact));
      logField("clientEmail", analyzeField(contract.client_email));
      logField("performerContact", analyzeField(contract.performer_contact));
      logField("performerEmail", analyzeField(contract.performer_email));
      logField("metadata", analyzeField(contract.metadata));
      console.log("");
    });

    const [stats] = (await dataSource.query(`
      SELECT
        COUNT(*) as total,
        SUM(CASE WHEN client_contact REGEXP '${ENCRYPTED_SQL_PATTERN}' THEN 1 ELSE 0 END) as encrypted_client_contact,
        SUM(CASE WHEN client_contact IS NOT NULL AND client_contact NOT REGEXP '${ENCRYPTED_SQL_PATTERN}' THEN 1 ELSE 0 END) as plain_client_contact,
        SUM(CASE WHEN client_email REGEXP '${ENCRYPTED_SQL_PATTERN}' THEN 1 ELSE 0 END) as encrypted_client_email,
        SUM(CASE WHEN client_email IS NOT NULL AND client_email NOT REGEXP '${ENCRYPTED_SQL_PATTERN}' THEN 1 ELSE 0 END) as plain_client_email,
        SUM(CASE WHEN performer_contact REGEXP '${ENCRYPTED_SQL_PATTERN}' THEN 1 ELSE 0 END) as encrypted_performer_contact,
        SUM(CASE WHEN performer_contact IS NOT NULL AND performer_contact NOT REGEXP '${ENCRYPTED_SQL_PATTERN}' THEN 1 ELSE 0 END) as plain_performer_contact,
        SUM(CASE WHEN performer_email REGEXP '${ENCRYPTED_SQL_PATTERN}' THEN 1 ELSE 0 END) as encrypted_performer_email,
        SUM(CASE WHEN performer_email IS NOT NULL AND performer_email NOT REGEXP '${ENCRYPTED_SQL_PATTERN}' THEN 1 ELSE 0 END) as plain_performer_email,
        SUM(CASE WHEN metadata REGEXP '${ENCRYPTED_SQL_PATTERN}' THEN 1 ELSE 0 END) as encrypted_metadata,
        SUM(CASE WHEN metadata IS NOT NULL AND metadata NOT REGEXP '${ENCRYPTED_SQL_PATTERN}' THEN 1 ELSE 0 END) as plain_metadata
      FROM contracts
    `)) as StatsRow[];

    console.log("=".repeat(100));
    console.log("📈 전체 통계");
    console.log("=".repeat(100));
    console.log(`전체 계약: ${stats.total}개`);
    console.log("\nclientContact:");
    console.log(`  ✅ 암호화됨: ${stats.encrypted_client_contact}`);
    console.log(`  ❌ 평문: ${stats.plain_client_contact}`);
    console.log("\nclientEmail:");
    console.log(`  ✅ 암호화됨: ${stats.encrypted_client_email}`);
    console.log(`  ❌ 평문: ${stats.plain_client_email}`);
    console.log("\nperformerContact:");
    console.log(`  ✅ 암호화됨: ${stats.encrypted_performer_contact}`);
    console.log(`  ❌ 평문: ${stats.plain_performer_contact}`);
    console.log("\nperformerEmail:");
    console.log(`  ✅ 암호화됨: ${stats.encrypted_performer_email}`);
    console.log(`  ❌ 평문: ${stats.plain_performer_email}`);
    console.log("\nmetadata:");
    console.log(`  ✅ 암호화됨: ${stats.encrypted_metadata}`);
    console.log(`  ❌ 평문: ${stats.plain_metadata}`);
    console.log("=".repeat(100));
  } catch (error) {
    console.error("❌ 오류 발생:", error);
    process.exit(1);
  } finally {
    await app.close();
  }
}

checkEncryption()
  .then(() => {
    console.log("\n✨ 확인 완료!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("\n❌ 실패:", error);
    process.exit(1);
  });
