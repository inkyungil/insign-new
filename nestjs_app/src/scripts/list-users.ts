import { NestFactory } from "@nestjs/core";
import { AppModule } from "../app.module";
import { UsersService } from "../users/users.service";

async function main() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const usersService = app.get(UsersService);

  console.log("\n=== All Users ===\n");

  const users = await usersService.findAllUsers();

  if (users.length === 0) {
    console.log("No users found in database");
  } else {
    users.forEach((user, index) => {
      console.log(`${index + 1}. User ID: ${user.id}`);
      console.log(`   Email: ${user.email}`);
      console.log(`   Provider: ${user.provider}`);
      console.log(`   Active: ${user.isActive}`);
      console.log(`   Has Password: ${!!user.passwordHash}`);
      console.log(`   Display Name: ${user.displayName || "(none)"}`);
      console.log(`   Last Login: ${user.lastLoginAt || "(never)"}`);
      console.log("");
    });

    console.log(`Total users: ${users.length}`);

    const activeLocal = users.filter(u => u.isActive && u.provider === "local" && u.passwordHash);
    console.log(`Can login with email/password: ${activeLocal.length}`);
  }

  await app.close();
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
