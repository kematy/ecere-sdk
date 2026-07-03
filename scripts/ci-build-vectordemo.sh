#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

make -j"$(nproc)" DISABLE_SSL=y ECERE_AUDIO=n

export PATH="$ROOT/obj/linux/bin:$PATH"
export LIBRARY_PATH="$ROOT/obj/linux/lib"
export LD_LIBRARY_PATH="$ROOT/obj/linux/lib"

cd samples/guiAndGfx/VectorDemo
epj2make -o VectorDemo.Makefile VectorDemo.epj
make -f VectorDemo.Makefile

test -f obj/debug.linux/VectorDemo
echo "VectorDemo build OK"
