import { drizzle, BetterSQLite3Database } from "drizzle-orm/better-sqlite3";

import Database from "better-sqlite3";
import { getManifest } from "@/lib/api/destinyManifest";
import { inventoryItems } from "@/lib/database/schemas/schema";

let _sqlite: any = null;
let _db: BetterSQLite3Database | null = null;
let _seedPromise: Promise<void> | null = null;

async function seedManifestIfNeeded(db: BetterSQLite3Database) {
  const row = db
    .select({ count: inventoryItems.id })
    .from(inventoryItems)
    .limit(1)
    .all();

  if (row.length > 0) {
    return;
  }

  const manifest = await getManifest();
  const inventory = manifest.DestinyInventoryItemDefinition ?? {};
  const entries = Object.entries(inventory).map(([id, value]) => ({
    id: Number(id),
    json: value,
  }));

  if (entries.length === 0) {
    return;
  }

  db.insert(inventoryItems).values(entries).run();
}

export function getDb(): BetterSQLite3Database {
  if (!_sqlite) {
    _sqlite = new Database("src/lib/database/sqlite.db");
    _sqlite.exec(`
      CREATE TABLE IF NOT EXISTS "DestinyInventoryItemDefinition" (
        "id" integer PRIMARY KEY NOT NULL,
        "json" text NOT NULL
      )
    `);
    _db = drizzle(_sqlite);
  }
  if (!_seedPromise) {
    _seedPromise = seedManifestIfNeeded(_db!);
  }
  return _db!;
}
