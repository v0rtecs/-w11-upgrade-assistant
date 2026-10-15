import { copyFile, mkdir, rm } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const desktopRoot = resolve(here, '..');
const repoRoot = resolve(desktopRoot, '..');
const outDir = resolve(desktopRoot, 'web');

await rm(outDir, { recursive: true, force: true });
await mkdir(outDir, { recursive: true });

for (const name of ['index.html', 'manifest.webmanifest', 'icon-192.png', 'icon-512.png']) {
  await copyFile(resolve(repoRoot, name), resolve(outDir, name));
}

console.log('Frontend copiato in desktop/web');
