import { mount } from 'svelte';
import CosmicSimulation from './CosmicSimulation.svelte';

const container = document.getElementById("viz");

if (container) {
  mount(CosmicSimulation, {
    target: container,
    props: {
      options: {
        wasmUrl: '/wasm/cosmic-expansion-wasm.wasm'
      }
    }
  });
}

