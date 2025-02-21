#!/bin/bash
set -euo pipefail

luabundler bundle "src/main.lua" -p "?.lua" -o "build/garlic-bread.lua"

# hacky stuff to go around Luabundler only going up to Lua 5.3 syntax!
# sed -i -e "s/local moveMsg = clc_Move()/local moveMsg <close> = clc_Move()/g" build/garlic-bread.lua

sed -i '1i--[[ Made by navet ]]' build/garlic-bread.lua
