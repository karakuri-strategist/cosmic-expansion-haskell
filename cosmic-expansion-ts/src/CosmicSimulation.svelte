<script lang="ts">
  import { onMount, onDestroy } from 'svelte';
  import { createCosmicViz, type CosmicVizInstance } from './viz';

  let vizContainer: HTMLDivElement;
  let viz: CosmicVizInstance | null = null;

  let bodyCount = 120;
  let ignoreOutliers = true;

  function initViz() {
    if (viz) viz.destroy();
    if (!vizContainer) return;

    // Use current dimensions or defaults
    const width = vizContainer.clientWidth || 900;
    const height = vizContainer.clientHeight || 520;

    viz = createCosmicViz({
      width,
      height,
      bodyCount,
      ignoreOutliers
    });
    viz.mount(vizContainer);
  }

  function handleRestart() {
    initViz();
  }

  function handleOutlierChange() {
    if (viz) {
      viz.setIgnoreOutliers(ignoreOutliers);
    }
  }

  onMount(() => {
    // Small delay to ensure layout is settled
    requestAnimationFrame(() => initViz());
  });

  onDestroy(() => {
    if (viz) viz.destroy();
  });
</script>

<div class="app-container">
  <details>
    <summary>Controls</summary>
    <div class="controls">
      <div class="control-group">
        <label for="bodies">Bodies:</label>
        <input 
          id="bodies" 
          type="number" 
          bind:value={bodyCount} 
          min="10" 
          max="5000" 
        />
      </div>
      
      <div class="control-group">
        <label class="checkbox-label">
          <input 
            type="checkbox" 
            bind:checked={ignoreOutliers} 
            onchange={handleOutlierChange} 
          />
          Ignore Outliers
        </label>
      </div>

      <button onclick={handleRestart}>Restart</button>
    </div>
  </details>

  <div class="sim-container" bind:this={vizContainer}></div>
</div>

<style>
  :global(body) {
    margin: 0;
    background: #0a0a0a;
    font-family: "IBM Plex Sans", "Segoe UI", sans-serif;
    color: #e8e8e8;
  }

  .app-container {
    width: 100%;
    height: 100%;
    display: flex;
    flex-direction: column;
    /* Ensure it fills the parent provided by index.html */
    min-height: 100vh; 
  }

  details {
    padding: 8px;
    background: #0a0a0a;
    z-index: 20;
  }

  summary {
    cursor: pointer;
    font-weight: bold;
    user-select: none;
    margin-bottom: 8px;
    color: #e6e6e6;
  }

  .controls {
    margin-top: 8px;
    background-color: rgba(11, 14, 26, 0.8);
    padding: 12px;
    border-radius: 8px;
    border: 1px solid #333;
    display: flex;
    gap: 16px;
    align-items: left;
    flex-wrap: wrap;
    flex-direction: column;
  }

  .control-group {
    display: flex;
    gap: 8px;
    align-items: center;
  }

  label {
    font-size: 14px;
    color: #e6e6e6;
  }

  input[type="number"] {
    background-color: #1a1d2d;
    border: 1px solid #444;
    color: white;
    padding: 4px 8px;
    border-radius: 4px;
    width: 80px;
  }

  .checkbox-label {
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 6px;
  }

  input[type="checkbox"] {
    cursor: pointer;
  }

  button {
    background-color: #2563eb;
    color: white;
    border: none;
    padding: 5px 12px;
    border-radius: 4px;
    cursor: pointer;
    font-size: 14px;
    font-weight: 500;
    transition: background-color 0.2s;
  }

  button:hover {
    background-color: #1d4ed8;
  }

  .sim-container {
    flex: 0;
    width: min(90vw, 960px);
    margin: 0 auto; /* Center it */
    overflow: hidden;
    position: relative;
    border: 1px solid #223;
    border-radius: 12px;
    aspect-ratio: 16 / 9;
    box-shadow: 0 30px 80px rgba(0, 0, 0, 0.45);
  }

  @media (orientation: portrait) {
    .sim-container { aspect-ratio: 9 / 16; }
  }
</style>
