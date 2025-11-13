import { NestFactory } from "@nestjs/core";
import { AppModule } from "../app.module";
import { UsersService } from "../users/users.service";
import { EncryptionService } from "../common/encryption.service";
import { hashEmail, normalizeEmail } from "../users/email.utils";

async function main() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const usersService = app.get(UsersService);
  const encryptionService = app.get(EncryptionService);

  const testEmail = process.argv[2];
  if (!testEmail) {
    console.log("Usage: npm run check:user <email>");
    process.exit(1);
  }

  console.log("\n=== User Check ===");
  console.log("Input email:", testEmail);

  const normalizedEmail = normalizeEmail(testEmail);
  const emailHash = hashEmail(normalizedEmail);
  console.log("Normalized:", normalizedEmail);
  console.log("Email hash:", emailHash);

  try {
    const user = await usersService.findByEmail(testEmail);
    if (!user) {
      console.log("\n❌ User NOT FOUND");
      console.log("\nPossible reasons:");
      console.log("1. Email does not exist in database");
      console.log("2. User is not active (isActive = false)");
      console.log("3. Email hash mismatch (encryption issue)");
    } else {
      console.log("\n✅ User FOUND");
      console.log("ID:", user.id);
      console.log("Email:", user.email);
      console.log("Provider:", user.provider);
      console.log("isActive:", user.isActive);
      console.log("Has password:", !!user.passwordHash);
      console.log("Display name:", user.displayName);
      console.log("Last login:", user.lastLoginAt);

      if (user.provider !== "local") {
        console.log("\n⚠️ This user cannot login with email/password");
        console.log("Provider is:", user.provider);
      } else if (!user.passwordHash) {
        console.log("\n⚠️ This user has no password set");
      } else {
        console.log("\n✅ User can login with email/password");
      }
    }
  } catch (error) {
    console.error("\n❌ Error:", error instanceof Error ? error.message : String(error));
  }

  await app.close();
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
