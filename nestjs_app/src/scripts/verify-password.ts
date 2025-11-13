import { NestFactory } from "@nestjs/core";
import { AppModule } from "../app.module";
import { UsersService } from "../users/users.service";
import * as bcrypt from "bcrypt";

async function main() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const usersService = app.get(UsersService);

  const email = process.argv[2];
  const password = process.argv[3];

  if (!email || !password) {
    console.log("Usage: npm run verify:password <email> <password>");
    process.exit(1);
  }

  console.log("\n=== Password Verification ===");
  console.log("Email:", email);
  console.log("Password:", "*".repeat(password.length));

  try {
    const user = await usersService.findByEmail(email);

    if (!user) {
      console.log("\n❌ User NOT FOUND");
      process.exit(1);
    }

    console.log("\n✅ User Found");
    console.log("ID:", user.id);
    console.log("Provider:", user.provider);
    console.log("Has Password Hash:", !!user.passwordHash);
    console.log("Is Active:", user.isActive);

    if (user.provider !== "local") {
      console.log("\n❌ FAIL: User provider is not 'local'");
      console.log("This user must login with:", user.provider);
      process.exit(1);
    }

    if (!user.passwordHash) {
      console.log("\n❌ FAIL: User has no password hash");
      process.exit(1);
    }

    console.log("\n🔍 Verifying password...");
    const matches = await bcrypt.compare(password, user.passwordHash);

    if (matches) {
      console.log("\n✅ SUCCESS: Password is CORRECT");
      console.log("This user should be able to login.");
    } else {
      console.log("\n❌ FAIL: Password is INCORRECT");
      console.log("The password you provided does not match the stored hash.");
      console.log("\nStored hash (first 50 chars):", user.passwordHash.substring(0, 50));
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
