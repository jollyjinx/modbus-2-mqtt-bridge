---
title: "Container Builds"
description: "Maintainer workflow for building and publishing modbus2mqtt images to Gitmaster or GHCR."
audience:
  - maintainers
status: "active"
related:
  - "../README.md"
  - "../modbus2mqtt.product.dockerfile"
  - "../scripts/build_and_push_image.sh"
---

# Container Builds

## Build Locally

Build the current source for the host's native Linux architecture:

```bash
container build . \
  --file modbus2mqtt.product.dockerfile \
  --tag modbus2mqtt
```

The production build file uses architecture-specific BuildKit caches for SwiftPM downloads and
release products. It embeds the Git commit timestamp as an OCI version and the full commit as the
OCI revision when those values are supplied by the publish script.

## Build and Push

Select exactly one registry. With no architecture option, the script builds and pushes both AMD64
and ARM64 under one multi-platform tag:

```bash
./scripts/build_and_push_image.sh --github
./scripts/build_and_push_image.sh --gitmaster
```

The destinations are:

```text
ghcr.io/jollyjinx/modbus-2-mqtt-bridge:<tag>
gitmaster.jinx.eu/jnxpublic/modbus2mqtt:<tag>
```

The default tag is the current branch name, converted to lowercase and normalized for container
tag syntax. For example, `feature/mqtt-reconnect` becomes `feature-mqtt-reconnect`. Override it
with `--tag`:

```bash
./scripts/build_and_push_image.sh --github --tag jinx
```

For a faster single-platform build, select one architecture:

```bash
./scripts/build_and_push_image.sh --gitmaster --arm64 --tag jinx
./scripts/build_and_push_image.sh --github --amd64 --tag test-amd64
```

A single-platform publication replaces that registry tag with a single-platform manifest. Use an
architecture-specific tag if existing consumers still require the other architecture.

On macOS, the script uses Apple Container. On other systems it uses Docker Buildx. Authentication
is an operator prerequisite: use `container registry login` on macOS or `docker login` elsewhere.

Run `--help` for the complete interface:

```bash
./scripts/build_and_push_image.sh --help
```

## Image Metadata

`git_commit_version.sh` formats a commit timestamp as `YYYY.MM.DD.HHMMSS`. The publish script passes
that value as `MODBUS2MQTT_VERSION` and the full commit SHA as `VCS_REF`. The runtime image exposes
them through the `MODBUS2MQTT_VERSION` and `MODBUS2MQTT_REVISION` environment variables and matching
OCI image labels. A dirty worktree is called out and receives a `-dirty` revision suffix.
