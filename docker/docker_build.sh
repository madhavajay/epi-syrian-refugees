#!/bin/bash
set -e

cd "$(dirname "$0")/.."
export DOCKER_BUILDKIT=1

[[ "$1" == "--clean" ]] && docker builder prune -af

docker build --platform=linux/amd64 -t epi-syrian-refugees:latest -f docker/Dockerfile .
