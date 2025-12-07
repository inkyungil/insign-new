import { NestFactory } from "@nestjs/core";
import { AppModule } from "../app.module";
import { DataSource } from "typeorm";
import { Contract } from "../contracts/contract.entity";
import { EncryptionService } from "../common/encryption.service";

async function main() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const dataSource = app.get(DataSource);
  const encryptionService = app.get(EncryptionService);

  console.log("\n=== Updating Contract Metadata Width from 794px to 100% ===\n");

  try {
    const contractRepository = dataSource.getRepository(Contract);

    // Find all contracts with metadata
    const contracts = await contractRepository.find();

    if (contracts.length === 0) {
      console.log("No contracts found in database");
      await app.close();
      return;
    }

    console.log(`Found ${contracts.length} contracts\n`);

    let updatedCount = 0;
    let errorCount = 0;

    for (const contract of contracts) {
      try {
        if (!contract.metadata) {
          console.log(`Contract ${contract.id}: No metadata, skipping`);
          continue;
        }

        let metadata: any;

        // Decrypt metadata if it's encrypted (string format)
        if (typeof contract.metadata === "string") {
          const metaStr = contract.metadata as string;

          // Check if it's encrypted (format: hex:hex:hex)
          if (metaStr.match(/^[0-9a-f]+:[0-9a-f]+:[0-9a-f]+/i)) {
            try {
              metadata = encryptionService.decryptJSON(metaStr);
              console.log(`Contract ${contract.id}: Decrypted metadata`);
            } catch (error) {
              console.log(`Contract ${contract.id}: Failed to decrypt metadata, skipping`);
              errorCount++;
              continue;
            }
          } else {
            // Try to parse as JSON
            try {
              metadata = JSON.parse(metaStr);
            } catch (error) {
              console.log(`Contract ${contract.id}: Invalid metadata format, skipping`);
              errorCount++;
              continue;
            }
          }
        } else {
          metadata = contract.metadata;
        }

        if (!metadata.templateRawContent) {
          console.log(`Contract ${contract.id}: No templateRawContent, skipping`);
          continue;
        }

        const originalContent = metadata.templateRawContent;

        // Replace width:794px with width:100%
        const updatedContent = originalContent.replace(/width:\s*794px/gi, "width:100%");

        if (originalContent !== updatedContent) {
          metadata.templateRawContent = updatedContent;

          // Re-encrypt the metadata
          const encryptedMetadata = encryptionService.encryptJSON(metadata);
          contract.metadata = encryptedMetadata as any;

          await contractRepository.save(contract);
          updatedCount++;
          console.log(`✓ Contract ${contract.id} (${contract.name}): Updated and re-encrypted`);
        } else {
          console.log(`  Contract ${contract.id} (${contract.name}): No changes needed`);
        }
      } catch (error) {
        errorCount++;
        console.error(`Contract ${contract.id}: Error -`, error);
      }
    }

    console.log(`\n=== Update Complete ===`);
    console.log(`Total contracts: ${contracts.length}`);
    console.log(`Updated: ${updatedCount}`);
    console.log(`Errors: ${errorCount}`);
    console.log(`Skipped: ${contracts.length - updatedCount - errorCount}`);

  } catch (error) {
    console.error("Error updating contracts:", error);
    throw error;
  } finally {
    await app.close();
  }
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
