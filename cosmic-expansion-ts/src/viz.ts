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
};

export type CosmicVizInstance = {
  mount: (el: HTMLElement) => void;
  destroy: () => void;
  getSvgElement: () => SVGSVGElement | null;
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
  autoScalePadding: 0.12,
  autoScaleSmoothing: 0.08,
  maxColorDistPx: 90
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
  let timeLabel: SVGTextElement | null = null;
  let warpMode = 0;
  let mouseWorldPos: { x: number; y: number } | null = null;
  let onMouseMove: ((event: MouseEvent) => void) | null = null;
  let onMouseDown: ((event: MouseEvent) => void) | null = null;
  let onMouseUp: ((event: MouseEvent) => void) | null = null;
  let onMouseLeave: (() => void) | null = null;
  let onContextMenu: ((event: MouseEvent) => void) | null = null;


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

    const centerX = opts.width / 2;
    const centerY = opts.height / 2;
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
      if (opts.autoScale) {
        let maxAbs = 0.001;
        for (let i = 0; i < sim.count; i += 1) {
          const x = positions[i * 2];
          const y = positions[i * 2 + 1];
          maxAbs = Math.max(maxAbs, Math.abs(x), Math.abs(y));
        }
        const padded = maxAbs * (1 + opts.autoScalePadding);
        const targetScale = Math.min(centerX, centerY) / padded;
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
      detachMouseHandlers(svg);
      svg.parentElement.removeChild(svg);
    }
    svg = null;
    timeLabel = null;
  }

  function getSvgElement() {
    return svg;
  }

  function attachMouseHandlers(target: SVGSVGElement) {
    onMouseMove = (event) => {
      mouseWorldPos = getWorldPos(target, event.clientX, event.clientY);
    };
    onMouseDown = (event) => {
      if (event.button === 0) {
        warpMode = -1;
      } else if (event.button === 2) {
        warpMode = 1;
      } else if (event.button === 1) {
        const pos = getWorldPos(target, event.clientX, event.clientY);
        mouseWorldPos = pos;
        if (sim && pos) {
          sim.applyBlast(dynamicScale, pos.x, pos.y);
        }
      }
    };
    onMouseUp = () => {
      warpMode = 0;
    };
    onMouseLeave = () => {
      warpMode = 0;
      mouseWorldPos = null;
    };
    onContextMenu = (event) => {
      event.preventDefault();
    };
    target.addEventListener("mousemove", onMouseMove);
    target.addEventListener("mousedown", onMouseDown);
    target.addEventListener("mouseup", onMouseUp);
    target.addEventListener("mouseleave", onMouseLeave);
    target.addEventListener("contextmenu", onContextMenu);
  }

  function detachMouseHandlers(target: SVGSVGElement) {
    if (onMouseMove) {
      target.removeEventListener("mousemove", onMouseMove);
    }
    if (onMouseDown) {
      target.removeEventListener("mousedown", onMouseDown);
    }
    if (onMouseUp) {
      target.removeEventListener("mouseup", onMouseUp);
    }
    if (onMouseLeave) {
      target.removeEventListener("mouseleave", onMouseLeave);
    }
    if (onContextMenu) {
      target.removeEventListener("contextmenu", onContextMenu);
    }
    onMouseMove = null;
    onMouseDown = null;
    onMouseUp = null;
    onMouseLeave = null;
    onContextMenu = null;
  }

  function getWorldPos(target: SVGSVGElement, clientX: number, clientY: number) {
    const rect = target.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) {
      return null;
    }
    const x = ((clientX - rect.left) / rect.width) * opts.width;
    const y = ((clientY - rect.top) / rect.height) * opts.height;
    const worldX = (x - opts.width / 2) / dynamicScale;
    const worldY = (y - opts.height / 2) / dynamicScale;
    return { x: worldX, y: worldY };
  }

  return { mount, destroy, getSvgElement };
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
