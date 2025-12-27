# A Toy Cosmological Expansion Simulation

This is a 2D simulation of cosmological expansion with Newtonian gravity continuously rescaled to fit the view so that the user can see the large scale structures develop. It's not a serious simulation, just a toy model to get a feel for how gravity and expansion can shape multi-body systems with a helpful vizualization. This version is written in Haskell. I'm working on an anologous project in Typescript to integrate into a personal website. When that's done I'll link that repo here.

The project uses the Haskell build tool Stack. To run, use `stack run`. To build use `stack build`. It uses the Haskell module Gloss for rendering the 2D vector graphics. You might need to install some of Gloss's OS‑level dependencies, OpenGL and GLUT.

## Deriving Equations from Comoving Coordinates and Newtonian Gravity

### 1. Conceptual Setup

We use comoving coordinates $\mathbf{x}$ so that physical positions are
$\mathbf{r}(t) = a(t) \mathbf{x}(t)$, where $a(t)$ is the scale factor.
This separates background expansion from peculiar motion. The peculiar velocity in comoving coordinates is $\dot{\mathbf{x}}$.

### 2. Equations of Motion

Starting from Newtonian gravity in physical coordinates (for the i-th planet affected by all others):

$$
\ddot{r_i} = -G\sum_{j \ne i} m_j \frac{r_i - r_j}{\lVert \mathbf{r}_i - \mathbf{r}_j \rVert^3}
$$

Then, substituting $\mathbf{r} = a\mathbf{x}$, you get:

$$
a\ddot{\mathbf{x}} + 2 \dot{a} \dot{\mathbf{x}} + \ddot{a} \mathbf{x}
= -\frac{G}{a^2} \sum_{j \ne i} m_j \frac{\mathbf{x}_i - \mathbf{x}_j}{\lVert \mathbf{x}_i - \mathbf{x}_j \rVert^3}
$$ 
 
 
  the comoving equation of motion takes the form:

$$
\ddot{\mathbf{x}} + 2 \frac{\dot{a}}{a} \dot{\mathbf{x}} + \frac{\ddot{a}}{a} \mathbf{x}
= -\frac{G}{a^3} \sum_{j \ne i} m_j \frac{\mathbf{x}_i - \mathbf{x}_j}{\lVert \mathbf{x}_i - \mathbf{x}_j \rVert^3}
$$

This yields two acceleration components used in the code:

$$
\mathbf{a}_{pos}(\mathbf{x}, t) = -\frac{G}{a^3} \sum_{j \ne i} m_j \frac{\mathbf{x}_i - \mathbf{x}_j}{\lVert \mathbf{x}_i - \mathbf{x}_j \rVert^3}
                              - \frac{\ddot{a}}{a} \mathbf{x}
$$

$$
\mathbf{a}_{drag}(\mathbf{v}, t) = -2 \frac{\dot{a}}{a} \mathbf{v}
$$


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

Part of this codebase was written by ChatGPT Codex and reviewed, edited, and approved by the repository owner.  