#!/usr/bin/env bash
set -euo pipefail

SRC="/home/usereyebottle/projects/sat-lec-rec/"
DEST="/mnt/c/ws-workspace/sat-lec-rec/"

rsync -a --delete \
  --exclude '.git/' \
  --exclude 'build/' \
  --exclude '.dart_tool/' \
  --exclude '.claude/' \
  --exclude 'windows/flutter/ephemeral/' \
  --exclude '.vscode/settings.json' \
  "$SRC" "$DEST"
