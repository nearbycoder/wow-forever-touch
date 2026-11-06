#!/bin/sh
# Runs the mock-client suite in every click mode the addon supports.
set -e
cd "$(dirname "$0")/.."
for f in ForeverTouch/*.lua; do luac5.1 -p "$f"; done
lua5.1 tests/run.lua
lua5.1 tests/run.lua legacy
sed 's/ActionButtonUseKeyDown = "1"/ActionButtonUseKeyDown = "0"/' tests/mock_wow.lua > tests/.mock_release.lua
LUA_PATH="./tests/?.lua;;" lua5.1 -e 'package.preload.mock_wow = function() return dofile("tests/.mock_release.lua") end' tests/run.lua
rm -f tests/.mock_release.lua
