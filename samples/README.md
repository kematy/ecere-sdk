# Ecere SDK Samples

This directory contains example projects demonstrating the eC language and the
Ecere runtime library (GUI, 2D/3D graphics, networking, audio, databases, and
more).

## Getting started

If you are new to eC and Ecere, start with the console samples under `eC/`:

1. `eC/HelloWorld` - the smallest possible eC program.
2. `eC/Sandbox` - a starter project meant for experimenting with eC and Ecere APIs.
3. `eC/FindPrime`, `eC/fibonacci` - small algorithmic examples.

Each sample is an Ecere project (`.epj`). You can open a `.epj` file in the
Ecere IDE, or build it from the command line once the SDK toolchain is
installed:

```sh
ecp <project>.epj      # build
./<TargetFileName>     # run (see the .epj "TargetFileName")
```

On Windows, run the equivalent commands from an Ecere SDK command prompt, or use
the build/run actions in the Ecere IDE.

## Categories

- **eC/** - core language demos and starter projects (best entry point).
- **guiAndGfx/** - GUI toolkit and 2D graphics: controls, forms, skinning,
  fractals, notepad-style apps, and more (largest sample set).
- **3D/** - 3D graphics: OpenGL, model viewers, raytracer, terrain, cubes.
- **games/** - complete small games: chess, cards, tetrominoes, tic-tac-toe,
  TilesRPG, and others.
- **net/** - networking: sockets, HTTP server/browser, DCOM, SMTP, IRC, XML.
- **db/** - Ecere Data Access (EDA) database examples.
- **audio/** - audio playback: piano, sine tone, WAV, S3M module player.
- **threads/** - multi-threading examples.
- **bindings/** - using eC/Ecere from C, C++, and Python (FFI examples).
- **android/** - Android deployment example.
- **scanning/** - WIA scanning (Windows).
- **misc/** - miscellaneous samples such as licensing.

## Notes

- On Unix you may need to copy a sample into a writable directory before
  building, if the SDK is installed system-wide.
- Some samples require the full `ecere` library; the smallest console samples
  only need `ecereCOM` (see the `Libraries` option in each `.epj`).
