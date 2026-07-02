# Ecere SDK Sandbox

This directory is a small console sandbox for trying eC code inside the Ecere SDK
source tree.

## Files

- `Sandbox.ec` - starter eC program.
- `Sandbox.epj` - Ecere project file that can be opened from the Ecere IDE.

## Usage

Open `Sandbox.epj` with the Ecere IDE, or build it with the Ecere project tools
after building/installing the SDK.

From this directory, the intended workflow is:

```sh
ecp Sandbox.epj
./Sandbox
```

## Windows

From an Ecere SDK / MinGW command prompt in this directory:

```bat
ecp Sandbox.epj
Sandbox.exe
```

Or open `Sandbox.epj` in the Ecere IDE and use the build/run actions.

If the tools are not found, make sure the SDK has been built/installed and that
its `bin` directory is on your `PATH`. See `docs/BUILD-Windows.md` for building
the SDK on Windows.

## What to try next

- Print more output or read `argv` arguments (already demonstrated).
- Add `import "ecere"` features such as file access, containers, or JSON.
- Copy an existing sample (for example `../HelloWorld`) and experiment.
