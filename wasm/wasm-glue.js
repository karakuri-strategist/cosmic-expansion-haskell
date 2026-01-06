export async function initSim(wasmUrl, bodyCount) {
  const response = await fetch(wasmUrl);
  const bytes = await response.arrayBuffer();
  const { instance } = await WebAssembly.instantiate(bytes, {});
  const {
    initState,
    stepState,
    applyBlastState,
    warpState,
    writePositions,
    positionsPtr,
    stateCount,
    freeState,
    memory
  } = instance.exports;

  const state = initState(bodyCount);
  const count = stateCount(state);
  const ptr = positionsPtr(state);
  let positions = new Float64Array(memory.buffer, ptr, count * 2);

  function refreshView() {
    if (positions.buffer !== memory.buffer) {
      positions = new Float64Array(memory.buffer, ptr, count * 2);
    }
  }

  return {
    positions,
    count,
    step(dtSeconds) {
      stepState(state, dtSeconds);
      writePositions(state);
      refreshView();
    },
    applyBlast(scale, x, y) {
      applyBlastState(state, scale, x, y);
    },
    warp(mode, scale, x, y) {
      warpState(state, mode, scale, x, y);
    },
    free() {
      freeState(state);
    }
  };
}
