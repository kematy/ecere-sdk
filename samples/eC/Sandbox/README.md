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

On Windows, run the equivalent commands from an Ecere SDK command prompt, or open
the project in the IDE and use the build/run actions.
