# A Toy Cosmological Expansion Simulation

This version is written in Haskell. I'm working on an anologous project in Typescript to integrate into a personal website. When that's done I'll link that repo here.

The project uses the Haskell build tool Stack. To run, use `stack run`. To build use `stack build`. It uses the Haskell module Gloss for rendering the 2D vector graphics. You might need to install some of Gloss's OS‑level dependencies, OpenGL and GLUT.

## Integration Method

This project uses a velocity-Verlet-style update with a split acceleration:
position-dependent forces are integrated with the Verlet scheme, while the
velocity-dependent drag term is applied explicitly.

$$
\mathbf{a}(\mathbf{x}, \mathbf{v}, t) = \mathbf{a}_{pos}(\mathbf{x}, t) + \mathbf{a}_{drag}(\mathbf{v}, t)
$$

$$
\mathbf{x}_{n+1} = \mathbf{x}_n + \mathbf{v}_n \Delta t + \tfrac{1}{2}\mathbf{a}_{pos}(\mathbf{x}_n, t_n) \Delta t^2
$$

$$
\mathbf{v}_{n+1} = \mathbf{v}_n + \tfrac{1}{2}(\mathbf{a}_{pos}(\mathbf{x}_n, t_n) + \mathbf{a}_{pos}(\mathbf{x}_{n+1}, t_{n+1})) \Delta t
                + \mathbf{a}_{drag}(\mathbf{v}_n, t_n) \Delta t
$$

