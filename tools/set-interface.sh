#!/bin/sh
# Set the TOC Interface number to match your client.
# In game, type:  /dump (select(4, GetBuildInfo()))   and pass the number here.
# Usage: tools/set-interface.sh 16001
set -e
[ -n "$1" ] || { echo "usage: $0 <interface-number>"; exit 1; }
cd "$(dirname "$0")/.."
sed -i.bak "s/^## Interface:.*/## Interface: $1/" ForeverTouch/ForeverTouch.toc && rm -f ForeverTouch/ForeverTouch.toc.bak
grep '^## Interface' ForeverTouch/ForeverTouch.toc
