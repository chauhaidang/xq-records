#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
IMAGE_NAME="${IMAGE_NAME:-xq-records-db:latest}"

"$SCRIPT_DIR/prepare-docker-init.sh"

docker build -t "$IMAGE_NAME" "$PROJECT_DIR"

echo "Built Docker image: $IMAGE_NAME"
