# Cosmic Expansion - Agent Guidelines

This repository contains a hybrid Haskell and TypeScript project simulating cosmic expansion. The core physics engine is written in Haskell (targeting both native and WASM), while the visualization frontend is built with TypeScript and Vite.

## Project Structure

- `cosmic-expansion-haskell/`: Core logic, physics simulation, and WASM bindings.
- `cosmic-expansion-ts/`: Frontend visualization using the compiled WASM module.
- `flake.nix`: Nix development environment configuration.

---

## 1. Build, Lint, and Test Commands

### Environment Setup
This project uses **Nix** for reproducible builds. Ensure you are inside the nix shell:
```bash
nix develop
# OR for WASM support (required for frontend)
nix develop .#wasm
```

### Haskell (`cosmic-expansion-haskell`)

**Build:**
```bash
cd cosmic-expansion-haskell
# Native build
stack build
# OR
cabal build

# WASM build (requires .#wasm shell)
cabal build --project-file=cabal.project.wasm cosmic-expansion-wasm
```

**Test:**
Run the full test suite:
```bash
stack test
# OR
cabal test
```

**Run a Single Test:**
To run a specific test case (e.g., matching "Collision"):
```bash
# Stack
stack test --test-arguments "-m Collision"

# Cabal
cabal test --test-options="-p /Collision/"
```

**Lint & Format:**
- Use `hlint` (available in nix shell) for linting.
- Use `fourmolu` or `ormolu` for formatting if available, otherwise follow existing indentation.
- `package.yaml` is the source of truth for Cabal metadata. **Do not edit `.cabal` files directly**; edit `package.yaml` and run `hpack`.

### TypeScript (`cosmic-expansion-ts`)

**Build:**
```bash
cd cosmic-expansion-ts
pnpm install
pnpm build
```

**Build WASM & Frontend:**
This script builds the Haskell WASM backend and copies it to the frontend:
```bash
pnpm run wasm:build
```

**Dev Server:**
```bash
pnpm dev
```

---

## 2. Code Style & Conventions

### General
- **Functional Core:** logic should be pure functions where possible.
- **Safety:** Prefer types that make illegal states unrepresentable.

### Haskell Guidelines

**Imports:**
- Use explicit import lists for clarity.
- Qualified imports for common libraries like `Vector`.
```haskell
import Data.Vector (Vector)
import qualified Data.Vector as V
import qualified Data.Vector.Mutable as MV
```

**Types & Data:**
- Use `newtype` for type safety (e.g., `Time`, `Mass`).
- Use strict fields (`!`) and `{-# UNPACK #-}` for performance-critical data structures, especially in the physics loop.
- Record syntax is preferred for data types.

**Performance:**
- This is a simulation engine; performance matters.
- Use `BangPatterns` for strict accumulation.
- Prefer `Data.Vector.Mutable` for in-place updates in the hot loop.
- Be mindful of allocations in the simulation step (`velocityVerlet`).

**Naming:**
- `camelCase` for functions and variables.
- `PascalCase` for types and constructors.
- Descriptive names for physics constants (`gravityG`).

**Error Handling:**
- Avoid partial functions (`head`, `tail`).
- Use `Maybe` or `Either` for fallible operations.
- In `IO` code (sim loop), exceptions are acceptable but should be documented.

### TypeScript Guidelines

**Style:**
- Use **TypeScript** strict mode.
- Prefer `const` over `let`.
- 2-space indentation.
- Semicolons required.

**Viz/DOM:**
- The visualization (`viz.ts`) currently uses direct DOM/SVG manipulation for performance and fine-grained control.
- Avoid heavy framework abstractions in the render loop.
- Use `requestAnimationFrame` for the game loop.

**WASM Interop:**
- `wasm-glue.ts` handles the boundary.
- Be careful with memory management; explicitly free WASM resources if required (`sim.free()`).

### Git & Workflow
- **Commit Messages:** clear and descriptive.
- **Testing:** Always run tests before pushing changes to core logic.
