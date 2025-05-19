# Physics

A lightweight Metal-based macOS playground that demonstrates a simple 2‑D ragdoll skeleton driven by a basic physics solver. It renders a collection of bones and muscles using Metal and lets you experiment with muscle contractions and simulation parameters in real time.

## Building

1. Open `Physics.xcodeproj` with Xcode (15 or later recommended).
2. Build and run the **Physics** target. No extra dependencies are required besides the macOS SDK and Metal support.

## Controls

- **Arrow Keys** – contract quadriceps/hamstrings on the left and right legs.
- **D** – toggle debug logging of bone positions.
- **M** – toggle display of muscles.
- **+ / -** – adjust simulation speed.
- **Pause** – pause or resume the simulation.
- **Reset** – restore the skeleton to the initial pose.

The application starts with a simple two‑legged skeleton standing on a ground plane. Use the controls to explore how the muscles and constraints interact.

## Development
Run `scripts/format.sh` before committing to ensure consistent style.
