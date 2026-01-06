# WASM build notes

This is a minimal JS/WASM bridge for the simulation core. The wasm build targets the `cosmic-expansion-wasm`
executable.

## Build

1) Install the wasm GHC toolchain from `ghc-wasm-meta`. I use Nix and run inside a Nix shell with

```
nix shell 'gitlab:haskell-wasm/ghc-wasm-meta?host=gitlab.haskell.org'
```


2) Build with the wasm project file:

```bash
cabal build --project-file=cabal.project.wasm cosmic-expansion-wasm
```

The `.wasm` artifact will be under `dist-newstyle/` for the wasm build.

## JS usage

```js
import { initSim } from "./wasm-glue.js";

const sim = await initSim("/path/to/cosmic-expansion-wasm.wasm", 120);
function frame(dtSeconds) {
  sim.step(dtSeconds);
  // sim.positions is [x0,y0,x1,y1,...] as Float64Array
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);
```

## Exported WASM functions

- `initState(count) -> StablePtr`
- `stepState(state, dtSeconds)`
- `applyBlastState(state, scale, x, y)`
- `warpState(state, mode, scale, x, y)` (mode: 1 expand, -1 compress, else no-op)
- `writePositions(state)`
- `positionsPtr(state) -> ptr`
- `stateCount(state) -> count`
- `freeState(state)`
