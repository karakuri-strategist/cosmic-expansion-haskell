import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const repoRoot = path.resolve(__dirname, "..", "..");
const distRoot = path.join(
  repoRoot,
  "cosmic-expansion-haskell",
  "dist-newstyle",
);
const outDir = path.join(
  repoRoot,
  "cosmic-expansion-ts",
  "public",
  "wasm",
);
const outFile = path.join(outDir, "cosmic-expansion-wasm.wasm");

async function walk(dir) {
  const entries = await fs.readdir(dir, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...(await walk(fullPath)));
    } else if (entry.isFile()) {
      files.push(fullPath);
    }
  }
  return files;
}

let candidates = [];
try {
  const files = await walk(distRoot);
  candidates = files.filter(
    (file) =>
      file.endsWith(".wasm") && file.includes("cosmic-expansion-wasm"),
  );
} catch (error) {
  console.error(`Failed to scan ${distRoot}: ${error.message}`);
  process.exit(1);
}

if (candidates.length === 0) {
  console.error(
    "No cosmic-expansion-wasm .wasm file found under dist-newstyle. " +
      "Build the wasm target first.",
  );
  process.exit(1);
}

const stats = await Promise.all(
  candidates.map(async (file) => ({ file, stat: await fs.stat(file) })),
);
stats.sort((a, b) => b.stat.mtimeMs - a.stat.mtimeMs);
const newest = stats[0].file;

await fs.mkdir(outDir, { recursive: true });
await fs.copyFile(newest, outFile);
console.log(`Copied ${newest} -> ${outFile}`);
