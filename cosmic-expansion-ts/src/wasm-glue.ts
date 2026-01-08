import {WASI} from "@bjorn3/browser_wasi_shim";

export type WasmSim = {
  positions: Float64Array;
  neighborDistances: Float64Array;
  count: number;
  step: (dtSeconds: number) => void;
  applyBlast: (scale: number, x: number, y: number) => void;
  warp: (mode: number, scale: number, x: number, y: number) => void;
  free: () => void;
};

type WasmExports = {
  hsInit: () => void;
  hsExit: () => void;
  hs_init: (argcPtr: number, argvPtr: number) => void;
  hs_exit: () => void;
  __heap_base: WebAssembly.Global;
  initState: (count: number) => number;
  stepState: (state: number, dtSeconds: number) => void;
  applyBlastState: (state: number, scale: number, x: number, y: number) => void;
  warpState: (state: number, mode: number, scale: number, x: number, y: number) => void;
  writePositions: (state: number) => void;
  writeNeighborDistances: (state: number) => void;
  positionsPtr: (state: number) => number;
  neighborDistancesPtr: (state: number) => number;
  stateCount: (state: number) => number;
  freeState: (state: number) => void;
  memory: WebAssembly.Memory;
};

export async function initSim(wasmUrl: string, bodyCount: number): Promise<WasmSim> {
  const wasi = new WASI([], [], []);
  const wasm = await WebAssembly.compileStreaming(fetch(wasmUrl));

  const instance = await WebAssembly.instantiate(wasm, {
    wasi_snapshot_preview1: wasi.wasiImport
  });
  const exports = instance.exports as Record<string, unknown>;
  const exportKeys = Object.keys(exports);

  function resolveExport<T>(name: string): T {
    if (name in exports) {
      return exports[name] as T;
    }
    const suffixMatch = exportKeys.find((key) => key.endsWith(name));
    if (suffixMatch) {
      return exports[suffixMatch] as T;
    }
    const containsMatch = exportKeys.find((key) => key.includes(name));
    if (containsMatch) {
      return exports[containsMatch] as T;
    }
    throw new Error(`Missing wasm export "${name}". Available: ${exportKeys.join(", ")}`);
  }

  function resolveOptionalExport<T>(name: string): T | undefined {
    if (name in exports) {
      return exports[name] as T;
    }
    const suffixMatch = exportKeys.find((key) => key.endsWith(name));
    if (suffixMatch) {
      return exports[suffixMatch] as T;
    }
    const containsMatch = exportKeys.find((key) => key.includes(name));
    if (containsMatch) {
      return exports[containsMatch] as T;
    }
    return undefined;
  }

  const hsInit = resolveOptionalExport<WasmExports["hsInit"]>("hsInit");
  const hsExit = resolveOptionalExport<WasmExports["hsExit"]>("hsExit");
  const hsInitRaw = resolveOptionalExport<WasmExports["hs_init"]>("hs_init");
  const hsExitRaw = resolveOptionalExport<WasmExports["hs_exit"]>("hs_exit");
  const heapBase = resolveOptionalExport<WasmExports["__heap_base"]>("__heap_base");
  const initState = resolveExport<WasmExports["initState"]>("initState");
  const stepState = resolveExport<WasmExports["stepState"]>("stepState");
  const applyBlastState = resolveExport<WasmExports["applyBlastState"]>("applyBlastState");
  const warpState = resolveExport<WasmExports["warpState"]>("warpState");
  const writePositions = resolveExport<WasmExports["writePositions"]>("writePositions");
  const writeNeighborDistances =
    resolveExport<WasmExports["writeNeighborDistances"]>("writeNeighborDistances");
  const positionsPtr = resolveExport<WasmExports["positionsPtr"]>("positionsPtr");
  const neighborDistancesPtr =
    resolveExport<WasmExports["neighborDistancesPtr"]>("neighborDistancesPtr");
  const stateCount = resolveExport<WasmExports["stateCount"]>("stateCount");
  const freeState = resolveExport<WasmExports["freeState"]>("freeState");
  const memory = resolveExport<WasmExports["memory"]>("memory");

  wasi.initialize(instance as { exports: { memory: WebAssembly.Memory; _initialize?: () => unknown } });

  if (hsInitRaw && heapBase) {
    const heapBaseValue =
      heapBase instanceof WebAssembly.Global
        ? Number(heapBase.value)
        : (heapBase as unknown as number);
    const argcPtr = heapBaseValue;
    const argvPtr = heapBaseValue + 4;
    new DataView(memory.buffer).setUint32(argcPtr, 0, true);
    new DataView(memory.buffer).setUint32(argvPtr, 0, true);
    hsInitRaw(argcPtr, argvPtr);
  } else if (hsInit) {
    hsInit();
  } else if (hsInitRaw) {
    hsInitRaw(0, 0);
  } else {
    throw new Error("Missing wasm export for hs_init/hsInit");
  }
  const state = initState(bodyCount);
  const count = stateCount(state);
  const ptr = positionsPtr(state);
  const neighborPtr = neighborDistancesPtr(state);
  let positions = new Float64Array(memory.buffer, ptr, count * 2);
  let neighborDistances = new Float64Array(memory.buffer, neighborPtr, count);
  function refreshView() {
    if (positions.buffer !== memory.buffer) {
      positions = new Float64Array(memory.buffer, ptr, count * 2);
      neighborDistances = new Float64Array(memory.buffer, neighborPtr, count);
    }
  }

  function writeAndRefresh() {
    writePositions(state);
    writeNeighborDistances(state);
    refreshView();
  }

  writeAndRefresh();

  return {
    get positions() {
      return positions;
    },
    get neighborDistances() {
      return neighborDistances;
    },
    count,
    step(dtSeconds: number) {
      stepState(state, dtSeconds);
      writeAndRefresh();
    },
    applyBlast(scale: number, x: number, y: number) {
      applyBlastState(state, scale, x, y);
      writeAndRefresh();
    },
    warp(mode: number, scale: number, x: number, y: number) {
      warpState(state, mode, scale, x, y);
      writeAndRefresh();
    },
    free() {
      freeState(state);
      if (hsExitRaw) {
        hsExitRaw();
      } else if (hsExit) {
        hsExit();
      }
    }
  };
}
