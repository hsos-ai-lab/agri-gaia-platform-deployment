# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-06-15

### Added

- **Docker package version pinning**: added `packages/preferences.d/docker` with baseline pins (`containerd.io` `1.6.*`, `docker-ce` / `docker-ce-cli` / `docker-ce-rootless-extras` `5:23.*`, `docker-buildx-plugin` `0.10.*`, `docker-compose-plugin` `2.16.*`). `packages/docker.sh` now applies these pins during Docker installation. (3a0319f, 2026-03-11)

### Changed

- **Ubuntu 22 + Ubuntu 24 dual-host support**: split the docker package pin file into `packages/preferences.d/docker.ubuntu-22` (existing pins) and `packages/preferences.d/docker.ubuntu-24` (new). The Ubuntu 24 pin file targets newer upstream Docker versions: `containerd.io` `1.7.*`, `docker-ce` / `docker-ce-cli` / `docker-ce-rootless-extras` `5:28.*`, `docker-buildx-plugin` `0.29.*`, `docker-compose-plugin` `2.40.*`. `packages/docker.sh` now detects the Ubuntu release at install time and applies the matching pin file. This aligns the deployment with the platform's bumped `DOCKER_VERSION=29.4.1`. (74f275e, 2026-05-18)
- **Project base URL length advisory** added to `setup-env.sh`: the prompt now reads *"Please enter the project base url, e.g. agri-gaia.example.com. Note: It must not be longer than 50 characters."* The 50-char ceiling comes from the issued/ACME wildcard certificate's CN-length limit — the longest subdomain (`minio-console.`) prefixes the base URL on the certificate, so a too-long base URL would push the SAN past the CA's limit. Paired with the EDC service rename in the platform repo, which shortened the previously over-limit `edc-provider-ids.*` subdomain. (5c2c76f)

### Host requirements

- **NVIDIA driver `575` (or newer)** is now required on GPU hosts. The platform's bumped Triton image (`nvcr.io/nvidia/tritonserver:24.09-py3`) needs CUDA 12.6, which is only supported by driver branch `>=575`. Older drivers will fail to start the Triton container. Verify with `nvidia-smi` before running `setup-host.sh` / `deploy.sh`.
