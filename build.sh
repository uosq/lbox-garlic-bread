#!/bin/bash
set -euo pipefail

luabundler bundle "src/main.lua" -p "?.lua" -o "build/garlic-bread.lua"

sed -i -e "s/local moveMsg = clc_Move()/local moveMsg <close> = clc_Move()/g" build/garlic-bread.lua
