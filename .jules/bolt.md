## 2023-11-20 - [Avoid Full-Grid DOM Redraws]
**Learning:** Full-grid DOM clearing and reconstruction (`world.innerHTML = ""`) triggers complete browser reflow and repaint cycles, destroys visual state/transitions unnecessarily, and has an O(N^2) complexity with grid size, causing potential scaling issues. Updating a single cell/tile locally retains the DOM tree and minimizes reflow/repaint to just the affected elements.
**Action:** Replace `world.innerHTML = ""` with localized element replacement (finding and updating the specific tile DOM element) during state changes.
