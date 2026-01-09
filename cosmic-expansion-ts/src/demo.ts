import { createCosmicViz, type CosmicVizInstance } from "./viz";

const container = document.getElementById("viz");

if (container) {
  // Update container layout to stack controls and sim
  container.style.display = "flex";
  container.style.flexDirection = "column";

  // Create UI Controls (Dropdown)
  const details = document.createElement("details");
  details.style.marginBottom = "0"; // Reset margin since it's in flex container
  details.style.padding = "8px"; // Add some padding
  details.style.color = "#e6e6e6";
  details.style.fontFamily = "system-ui, sans-serif";
  details.style.zIndex = "20"; // Ensure above sim if needed
  
  const summary = document.createElement("summary");
  summary.textContent = "Controls";
  summary.style.cursor = "pointer";
  summary.style.fontWeight = "bold";
  summary.style.userSelect = "none";
  details.appendChild(summary);

  const controls = document.createElement("div");
  controls.style.marginTop = "8px";
  controls.style.backgroundColor = "rgba(11, 14, 26, 0.8)";
  controls.style.padding = "12px";
  controls.style.borderRadius = "8px";
  controls.style.border = "1px solid #333";
  controls.style.display = "flex";
  controls.style.gap = "16px";
  controls.style.alignItems = "center";
  controls.style.flexWrap = "wrap";

  // Body Count Control
  const bodyCountGroup = document.createElement("div");
  bodyCountGroup.style.display = "flex";
  bodyCountGroup.style.gap = "8px";
  bodyCountGroup.style.alignItems = "center";

  const label = document.createElement("label");
  label.innerText = "Bodies: ";
  label.style.fontSize = "14px";

  const input = document.createElement("input");
  input.type = "number";
  input.value = "120";
  input.min = "10";
  input.max = "5000";
  input.style.backgroundColor = "#1a1d2d";
  input.style.border = "1px solid #444";
  input.style.color = "white";
  input.style.padding = "4px 8px";
  input.style.borderRadius = "4px";
  input.style.width = "80px";
  
  bodyCountGroup.appendChild(label);
  bodyCountGroup.appendChild(input);

  // Outlier Control
  const outlierGroup = document.createElement("div");
  outlierGroup.style.display = "flex";
  outlierGroup.style.gap = "8px";
  outlierGroup.style.alignItems = "center";
  
  const outlierLabel = document.createElement("label");
  outlierLabel.innerText = "Ignore Outliers";
  outlierLabel.style.fontSize = "14px";
  outlierLabel.style.cursor = "pointer";
  outlierLabel.htmlFor = "outlier-check";
  
  const outlierCheck = document.createElement("input");
  outlierCheck.type = "checkbox";
  outlierCheck.id = "outlier-check";
  outlierCheck.checked = true;
  outlierCheck.style.cursor = "pointer";
  
  outlierGroup.appendChild(outlierCheck);
  outlierGroup.appendChild(outlierLabel);

  const button = document.createElement("button");
  button.innerText = "Restart";
  button.style.backgroundColor = "#2563eb";
  button.style.color = "white";
  button.style.border = "none";
  button.style.padding = "5px 12px";
  button.style.borderRadius = "4px";
  button.style.cursor = "pointer";
  button.style.fontSize = "14px";
  button.style.fontWeight = "500";
  
  button.onmouseover = () => button.style.backgroundColor = "#1d4ed8";
  button.onmouseout = () => button.style.backgroundColor = "#2563eb";

  controls.appendChild(bodyCountGroup);
  controls.appendChild(outlierGroup);
  controls.appendChild(button);
  details.appendChild(controls);
  container.appendChild(details);

  // Create Simulation Container
  const simElement = document.createElement("div");
  simElement.id = "sim";
  simElement.style.flex = "1";
  simElement.style.width = "100%";
  simElement.style.overflow = "hidden";
  container.appendChild(simElement);

  // Simulation Logic
  let viz: CosmicVizInstance | null = null;

  const startSim = (bodyCount: number) => {
    if (viz) {
      viz.destroy();
    }
    
    // We use simElement dimensions. If they are 0 (e.g. initially), fallback to container or default.
    const width = simElement.clientWidth || container.clientWidth || 900;
    const height = simElement.clientHeight || container.clientHeight || 520;

    viz = createCosmicViz({ 
      width, 
      height,
      bodyCount,
      ignoreOutliers: outlierCheck.checked
    });
    viz.mount(simElement);
  };

  // Event Listeners
  button.onclick = () => {
    const count = parseInt(input.value, 10);
    if (!isNaN(count) && count > 0) {
      startSim(count);
    }
  };
  
  outlierCheck.onchange = () => {
    if (viz) {
      viz.setIgnoreOutliers(outlierCheck.checked);
    }
  };

  // Initial Start
  // Use setTimeout to allow flex layout to settle if needed, though usually not strictly necessary
  requestAnimationFrame(() => startSim(120));
}
