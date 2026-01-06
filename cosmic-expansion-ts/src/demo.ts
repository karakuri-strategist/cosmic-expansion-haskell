import { createCosmicViz } from "./viz";

const container = document.getElementById("viz");

if (container) {
  const viz = createCosmicViz({ width: 900, height: 520 });
  viz.mount(container);
}
