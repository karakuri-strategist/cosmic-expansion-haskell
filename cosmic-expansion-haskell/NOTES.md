## Haskell Runtime Checklist (Long-Running Sims)

- Prefer strict fields (`!`) in hot-path records.
- Force derived stats when computed (e.g., `let !x = ...`), especially if they may not be rendered.
- Use strict folds (`foldl'`, `V.foldl'`) in loops.
- Avoid building large lazy thunks in `map`/`zipWith` chains if values might not be consumed immediately.
- Skip debug-only work when disabled, or ensure those results are forced.
- Use `+RTS -s` to monitor `max residency` and allocation rate when performance drifts.
