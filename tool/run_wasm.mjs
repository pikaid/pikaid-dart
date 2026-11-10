// Runs a dart2wasm-compiled Dart program under Node.
//
// A dart2wasm build produces `<output>.wasm` (the module) and `<output>.mjs`
// (the generated loader, which exposes `compile` and `compileStreaming`).
// Node 22+ has WebAssembly GC builtins enabled, so the module can be compiled
// and instantiated directly from a buffer.
//
// Usage: node tool/run_wasm.mjs <loader.mjs> <module.wasm>

import {readFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';

const [loaderPath, modulePath] = process.argv.slice(2);
if (!loaderPath || !modulePath) {
  console.error('usage: node tool/run_wasm.mjs <loader.mjs> <module.wasm>');
  process.exit(2);
}

const {compile} = await import(pathToFileURL(resolve(loaderPath)).href);
const module = await readFile(resolve(modulePath));
const app = await (await compile(module)).instantiate({}, {});
app.invokeMain();
