import { NestFactory } from "@nestjs/core";
import { AppModule } from "../app.module";
import { UsersService } from "../users/users.service";

async function main() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const usersService = app.get(UsersService);

  const email = process.argv[2];
  const newPassword = process.argv[3];

  if (!email || !newPassword) {
    console.log("Usage: npm run reset:password <email> <new_password>");
    console.log("\nExample:");
    console.log('  npm run reset:password "user@example.com" "newpassword123"');
    process.exit(1);
  }

  console.log("\n=== Password Reset ===");
  console.log("Email:", email);
  console.log("New Password:", "*".repeat(newPassword.length));

  try {
    const user = await usersService.findByEmail(email);

    if (!user) {
      console.log("\n❌ User NOT FOUND");
      process.exit(1);
    }

    console.log("\n✅ User Found");
    console.log("ID:", user.id);
    console.log("Provider:", user.provider);

    if (user.provider !== "local") {
      console.log("\n⚠️ Warning: User provider is", user.provider);
      console.log("This will convert the user to local provider.");
    }

    console.log("\n🔄 Updating password...");
    await usersService.updateUserPassword(user.id, newPassword);

    console.log("\n✅ SUCCESS: Password has been reset");
    console.log("\nYou can now login with:");
    console.log("Email:", email);
    console.log("Password:", newPassword);
  } catch (error) {
    console.error("\n❌ Error:", error instanceof Error ? error.message : String(error));
    process.exit(1);
  }

  await app.close();
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
