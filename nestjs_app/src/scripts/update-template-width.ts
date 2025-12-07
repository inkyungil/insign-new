import { NestFactory } from "@nestjs/core";
import { AppModule } from "../app.module";
import { DataSource } from "typeorm";
import { Template } from "../templates/template.entity";

async function main() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const dataSource = app.get(DataSource);

  console.log("\n=== Updating Template Width from 794px to 100% ===\n");

  try {
    const templateRepository = dataSource.getRepository(Template);

    // Find all templates
    const templates = await templateRepository.find();

    if (templates.length === 0) {
      console.log("No templates found in database");
      await app.close();
      return;
    }

    console.log(`Found ${templates.length} templates\n`);

    let updatedCount = 0;

    for (const template of templates) {
      if (!template.content) {
        console.log(`Template ${template.id} (${template.name}): No content, skipping`);
        continue;
      }

      const originalContent = template.content;

      // Replace width:794px with width:100%
      const updatedContent = originalContent.replace(/width:\s*794px/gi, "width:100%");

      if (originalContent !== updatedContent) {
        template.content = updatedContent;
        await templateRepository.save(template);
        updatedCount++;
        console.log(`✓ Template ${template.id} (${template.name}): Updated`);
      } else {
        console.log(`  Template ${template.id} (${template.name}): No changes needed`);
      }
    }

    console.log(`\n=== Update Complete ===`);
    console.log(`Total templates: ${templates.length}`);
    console.log(`Updated: ${updatedCount}`);
    console.log(`Skipped: ${templates.length - updatedCount}`);

  } catch (error) {
    console.error("Error updating templates:", error);
    throw error;
  } finally {
    await app.close();
  }
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
