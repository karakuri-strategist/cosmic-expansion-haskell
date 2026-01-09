export type CosmicVizOptions = {
  width?: number;
  height?: number;
  background?: string;
  bodyCount?: number;
  wasmUrl?: string;
  worldScale?: number;
  timeScale?: number;
  autoScale?: boolean;
  autoScalePadding?: number;
  autoScaleSmoothing?: number;
  maxColorDistPx?: number;
  ignoreOutliers?: boolean;
};

export type CosmicVizInstance = {
  mount: (el: HTMLElement) => void;
  destroy: () => void;
  getSvgElement: () => SVGSVGElement | null;
  setIgnoreOutliers: (ignore: boolean) => void;
};

const SVG_NS = "http://www.w3.org/2000/svg";

type ResolvedOptions = Required<CosmicVizOptions>;

const defaultOptions: ResolvedOptions = {
  width: 640,
  height: 360,
  background: "#0b0e1a",
  bodyCount: 120,
  wasmUrl: "/wasm/cosmic-expansion-wasm.wasm",
  worldScale: 180,
  timeScale: 1,
  autoScale: true,
  autoScalePadding: 0.06,
  autoScaleSmoothing: 0.08,
  maxColorDistPx: 90,
  ignoreOutliers: true
};

export function createCosmicViz(options: CosmicVizOptions = {}): CosmicVizInstance {
  let svg: SVGSVGElement | null = null;
  let rootEl: HTMLElement | null = null;
  let running = false;
  let frameId: number | null = null;
  let sim: import("./wasm-glue").WasmSim | null = null;
  let lastTime = 0;
  const opts: ResolvedOptions = { ...defaultOptions, ...options };
  let dynamicScale = opts.worldScale;
  let elapsedSeconds = 0;
  let ignoreOutliers = opts.ignoreOutliers;
  let sortBuffer: Float64Array | null = null;
  let timeLabel: SVGTextElement | null = null;
  let warpMode = 0;
  let mouseWorldPos: { x: number; y: number } | null = null;
  let viewWidth = opts.width;
  let viewHeight = opts.height;
  let resizeObserver: ResizeObserver | null = null;
  let onPointerDown: ((event: PointerEvent) => void) | null = null;
  let onPointerMove: ((event: PointerEvent) => void) | null = null;
  let onPointerUp: ((event: PointerEvent) => void) | null = null;
  let onPointerCancel: ((event: PointerEvent) => void) | null = null;
  let onContextMenu: ((event: MouseEvent) => void) | null = null;
  const pointerState = new Map<number, { x: number; y: number; t: number }>();


  function mount(el: HTMLElement) {
    destroy();
    rootEl = el;

    svg = document.createElementNS(SVG_NS, "svg");
    svg.setAttribute("width", String(opts.width));
    svg.setAttribute("height", String(opts.height));
    svg.setAttribute("viewBox", `0 0 ${opts.width} ${opts.height}`);
    svg.setAttribute("preserveAspectRatio", "xMidYMid meet");
    svg.style.display = "block";
    svg.style.width = "100%";
    svg.style.height = "100%";
    svg.style.background = opts.background;

    const defs = document.createElementNS(SVG_NS, "defs");
    const filter = document.createElementNS(SVG_NS, "filter");
    filter.setAttribute("id", "cosmic-glow");
    filter.setAttribute("x", "-50%");
    filter.setAttribute("y", "-50%");
    filter.setAttribute("width", "200%");
    filter.setAttribute("height", "200%");

    const merge = document.createElementNS(SVG_NS, "feMerge");
    const mergeNode1 = document.createElementNS(SVG_NS, "feMergeNode");
    mergeNode1.setAttribute("in", "blur");
    const mergeNode2 = document.createElementNS(SVG_NS, "feMergeNode");
    mergeNode2.setAttribute("in", "SourceGraphic");

    const blurResult = document.createElementNS(SVG_NS, "feGaussianBlur");
    blurResult.setAttribute("in", "SourceGraphic");
    blurResult.setAttribute("stdDeviation", "12");
    blurResult.setAttribute("result", "blur");

    merge.appendChild(mergeNode1);
    merge.appendChild(mergeNode2);

    filter.appendChild(blurResult);
    filter.appendChild(merge);
    defs.appendChild(filter);
    svg.appendChild(defs);

    const particleLayer = document.createElementNS(SVG_NS, "g");
    particleLayer.setAttribute("id", "particles");
    svg.appendChild(particleLayer);

    timeLabel = document.createElementNS(SVG_NS, "text");
    timeLabel.setAttribute("x", String(opts.width - 14));
    timeLabel.setAttribute("y", "24");
    timeLabel.setAttribute("text-anchor", "end");
    timeLabel.setAttribute("fill", "#e6e6e6");
    timeLabel.setAttribute("font-size", "12");
    timeLabel.setAttribute("font-family", "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, \"Liberation Mono\", \"Courier New\", monospace");
    timeLabel.textContent = "t 0.00s";
    svg.appendChild(timeLabel);

    rootEl.appendChild(svg);
    attachResizeObserver(rootEl);
    attachMouseHandlers(svg);

    void initWasm(particleLayer);
  }

  async function initWasm(layer: SVGGElement) {
    if (!svg) {
      return;
    }
    const { initSim } = await import("./wasm-glue");
    sim = await initSim(opts.wasmUrl, opts.bodyCount);
    const circles = Array.from({ length: sim.count }, () => {
      const circle = document.createElementNS(SVG_NS, "circle");
      circle.setAttribute("r", "3.5");
      circle.setAttribute("fill", "#66d9ff");
      circle.setAttribute("filter", "url(#cosmic-glow)");
      layer.appendChild(circle);
      return circle;
    });

    running = true;
    lastTime = performance.now();
    elapsedSeconds = 0;

    dynamicScale = opts.worldScale;

    const tick = (now: number) => {
      if (!running || !sim) {
        return;
      }
      const dt = Math.min(0.05, (now - lastTime) / 1000);
      lastTime = now;
      const scaledDt = dt * opts.timeScale;
      sim.step(scaledDt);
      if (warpMode !== 0 && mouseWorldPos) {
        sim.warp(warpMode, dynamicScale, mouseWorldPos.x, mouseWorldPos.y);
      }
      elapsedSeconds += scaledDt;
      const positions = sim.positions;
      const centerX = viewWidth / 2;
      const centerY = viewHeight / 2;
      if (opts.autoScale) {
        let targetScale = dynamicScale;
        
        if (ignoreOutliers) {
          if (!sortBuffer || sortBuffer.length !== sim.count) {
            sortBuffer = new Float64Array(sim.count);
          }
          for (let i = 0; i < sim.count; i++) {
             const x = positions[i * 2];
             const y = positions[i * 2 + 1];
             // Use max coordinate for bounds to keep aspect ratio 1:1 square
             sortBuffer[i] = Math.max(Math.abs(x), Math.abs(y));
          }
          sortBuffer.sort();
          // Use 95th percentile
          const idx = Math.floor((sim.count - 1) * 0.95);
          const val = sortBuffer[idx];
          // Ensure we don't scale to infinity if everything is at 0
          const maxAbs = val > 0.001 ? val : 0.001;
          const padded = maxAbs * (1 + opts.autoScalePadding);
          targetScale = Math.min(centerX, centerY) / padded;
        } else {
          let maxAbs = 0.001;
          for (let i = 0; i < sim.count; i += 1) {
            const x = positions[i * 2];
            const y = positions[i * 2 + 1];
            maxAbs = Math.max(maxAbs, Math.abs(x), Math.abs(y));
          }
          const padded = maxAbs * (1 + opts.autoScalePadding);
          targetScale = Math.min(centerX, centerY) / padded;
        }

        dynamicScale += (targetScale - dynamicScale) * opts.autoScaleSmoothing;
      } else {
        dynamicScale = opts.worldScale;
      }
      const colorDistWorld = opts.maxColorDistPx / dynamicScale;
      const colorDistInv = colorDistWorld > 0 ? 1 / colorDistWorld : 0;
      for (let i = 0; i < sim.count; i += 1) {
        const x = positions[i * 2] * dynamicScale + centerX;
        const y = positions[i * 2 + 1] * dynamicScale + centerY;
        circles[i].setAttribute("cx", x.toFixed(2));
        circles[i].setAttribute("cy", y.toFixed(2));
        const d2 = sim.neighborDistances[i];
        const d = d2 < 0 ? Number.POSITIVE_INFINITY : Math.sqrt(d2);
        const t = clamp01(1 - d * colorDistInv);
        circles[i].setAttribute("fill", mixColor(warmColor, coolColor, t));
      }
      if (timeLabel) {
        timeLabel.textContent = `t ${elapsedSeconds.toFixed(2)}s`;
      }
      frameId = requestAnimationFrame(tick);
    };

    frameId = requestAnimationFrame(tick);
  }

  function destroy() {
    running = false;
    if (frameId !== null) {
      cancelAnimationFrame(frameId);
      frameId = null;
    }
    if (sim) {
      sim.free();
      sim = null;
    }
    if (svg && svg.parentElement) {
      detachResizeObserver();
      detachMouseHandlers(svg);
      svg.parentElement.removeChild(svg);
    }
    svg = null;
    timeLabel = null;
  }

  function getSvgElement() {
    return svg;
  }

  function attachResizeObserver(container: HTMLElement) {
    updateViewSize(container);
    if ("ResizeObserver" in window) {
      resizeObserver = new ResizeObserver(() => {
        updateViewSize(container);
      });
      resizeObserver.observe(container);
    } else {
      (window as Window).addEventListener("resize", handleWindowResize);
    }
  }

  function detachResizeObserver() {
    if (resizeObserver) {
      resizeObserver.disconnect();
      resizeObserver = null;
    } else {
      (window as Window).removeEventListener("resize", handleWindowResize);
    }
  }

  function handleWindowResize() {
    if (rootEl) {
      updateViewSize(rootEl);
    }
  }

  function updateViewSize(container: HTMLElement) {
    if (!svg) {
      return;
    }
    const rect = container.getBoundingClientRect();
    if (rect.width > 0 && rect.height > 0) {
      viewWidth = rect.width;
      viewHeight = rect.height;
    } else {
      viewWidth = opts.width;
      viewHeight = opts.height;
    }
    svg.setAttribute("viewBox", `0 0 ${viewWidth} ${viewHeight}`);
    if (timeLabel) {
      timeLabel.setAttribute("x", String(viewWidth - 14));
    }
  }

  function attachMouseHandlers(target: SVGSVGElement) {
    onPointerMove = (event) => {
      mouseWorldPos = getWorldPos(target, event.clientX, event.clientY);
      if (pointerState.has(event.pointerId) && mouseWorldPos) {
        const entry = pointerState.get(event.pointerId);
        if (entry) {
          entry.x = mouseWorldPos.x;
          entry.y = mouseWorldPos.y;
        }
      }
    };
    onPointerDown = (event) => {
      target.setPointerCapture(event.pointerId);
      const pos = getWorldPos(target, event.clientX, event.clientY);
      if (pos) {
        pointerState.set(event.pointerId, { x: pos.x, y: pos.y, t: performance.now() });
        mouseWorldPos = pos;
      }
      if (event.pointerType === "mouse") {
        if (event.button === 2) {
          warpMode = 1;
        } else if (event.button === 0) {
          warpMode = -1;
        } else if (event.button === 1 && sim && pos) {
          sim.applyBlast(dynamicScale, pos.x, pos.y);
        }
      } else {
        warpMode = pointerState.size > 1 ? 1 : -1;
      }
    };
    onPointerUp = (event) => {
      const entry = pointerState.get(event.pointerId);
      pointerState.delete(event.pointerId);
      if (event.pointerType !== "mouse" && entry && sim) {
        const elapsed = performance.now() - entry.t;
        if (elapsed < 250) {
          sim.applyBlast(dynamicScale, entry.x, entry.y);
        }
      }
      warpMode = pointerState.size > 1 ? 1 : pointerState.size === 1 ? -1 : 0;
    };
    onPointerCancel = (event) => {
      pointerState.delete(event.pointerId);
      warpMode = pointerState.size > 1 ? 1 : pointerState.size === 1 ? -1 : 0;
    };
    onContextMenu = (event) => {
      event.preventDefault();
    };
    target.addEventListener("pointermove", onPointerMove);
    target.addEventListener("pointerdown", onPointerDown);
    target.addEventListener("pointerup", onPointerUp);
    target.addEventListener("pointercancel", onPointerCancel);
    target.addEventListener("contextmenu", onContextMenu);
  }

  function detachMouseHandlers(target: SVGSVGElement) {
    if (onPointerMove) {
      target.removeEventListener("pointermove", onPointerMove);
    }
    if (onPointerDown) {
      target.removeEventListener("pointerdown", onPointerDown);
    }
    if (onPointerUp) {
      target.removeEventListener("pointerup", onPointerUp);
    }
    if (onPointerCancel) {
      target.removeEventListener("pointercancel", onPointerCancel);
    }
    if (onContextMenu) {
      target.removeEventListener("contextmenu", onContextMenu);
    }
    onPointerMove = null;
    onPointerDown = null;
    onPointerUp = null;
    onPointerCancel = null;
    onContextMenu = null;
    pointerState.clear();
  }

  function getWorldPos(target: SVGSVGElement, clientX: number, clientY: number) {
    const rect = target.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) {
      return null;
    }
    const x = ((clientX - rect.left) / rect.width) * viewWidth;
    const y = ((clientY - rect.top) / rect.height) * viewHeight;
    const worldX = (x - viewWidth / 2) / dynamicScale;
    const worldY = (y - viewHeight / 2) / dynamicScale;
    return { x: worldX, y: worldY };
  }

  function setIgnoreOutliers(ignore: boolean) {
    ignoreOutliers = ignore;
  }

  return { mount, destroy, getSvgElement, setIgnoreOutliers };
}

const warmColor = { r: 1.0, g: 0.6, b: 0.2 };
const coolColor = { r: 0.35, g: 0.7, b: 1.0 };

function mixColor(
  warm: { r: number; g: number; b: number },
  cool: { r: number; g: number; b: number },
  t: number
) {
  const r = warm.r * t + cool.r * (1 - t);
  const g = warm.g * t + cool.g * (1 - t);
  const b = warm.b * t + cool.b * (1 - t);
  return `rgb(${Math.round(r * 255)}, ${Math.round(g * 255)}, ${Math.round(
    b * 255
  )})`;
}

function clamp01(value: number) {
  if (value < 0) {
    return 0;
  }
  if (value > 1) {
    return 1;
  }
  return value;
}
