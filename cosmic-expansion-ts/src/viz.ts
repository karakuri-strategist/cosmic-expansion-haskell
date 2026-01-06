export type CosmicVizOptions = {
  width?: number;
  height?: number;
  background?: string;
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
  background: "#0b0e1a"
};

export function createCosmicViz(options: CosmicVizOptions = {}): CosmicVizInstance {
  let svg: SVGSVGElement | null = null;
  let rootEl: HTMLElement | null = null;
  const opts: ResolvedOptions = { ...defaultOptions, ...options };

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

    const circle = document.createElementNS(SVG_NS, "circle");
    circle.setAttribute("cx", String(opts.width / 2));
    circle.setAttribute("cy", String(opts.height / 2));
    circle.setAttribute("r", "28");
    circle.setAttribute("fill", "#66d9ff");
    circle.setAttribute("filter", "url(#cosmic-glow)");

    svg.appendChild(circle);
    rootEl.appendChild(svg);
  }

  function destroy() {
    if (svg && svg.parentElement) {
      svg.parentElement.removeChild(svg);
    }
    svg = null;
  }

  function getSvgElement() {
    return svg;
  }

  return { mount, destroy, getSvgElement };
}
