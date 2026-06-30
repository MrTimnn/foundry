import { drizzle, BetterSQLite3Database } from "drizzle-orm/better-sqlite3";

import Database from "better-sqlite3";
import type { Database as DatabaseType } from "better-sqlite3";

let _sqlite: DatabaseType | null = null;
let _db: BetterSQLite3Database | null = null;

export function getDb(): BetterSQLite3Database {
  if (!_sqlite) {
    _sqlite = new Database("src/lib/database/sqlite.db");
    _db = drizzle(_sqlite);
  }
  return _db!;
}
