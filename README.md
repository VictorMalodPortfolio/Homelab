# Homelab

[![CI](https://github.com/VictorMalodPortfolio/Homelab/actions/workflows/ci.yml/badge.svg)](https://github.com/VictorMalodPortfolio/Homelab/actions/workflows/ci.yml)
[![Security](https://img.shields.io/badge/security-trivy-blue)](https://github.com/VictorMalodPortfolio/Homelab/security/code-scanning)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A personal lab where I experiment with cloud infrastructure in a dedicated environment I fully control through OVH — provisioned with OpenTofu, orchestrated with k3s, and managed end-to-end via GitOps.

## Architecture

```mermaid
graph TD
    dev["💻 Developer"]

    subgraph local["Local Machine"]
        tooling["DockerTooling\nkubectl · helm · tofu · sops"]
        age["age key"]
        kubeconfig["kubeconfig"]
    end

    subgraph github["GitHub"]
        homelab_repo["Homelab repo\n(this repo)"]
        docker_repo["DockerTooling repo"]
        ghcr["GHCR\nk8s-tooling image"]
    end

    subgraph ovh["OVH"]
        dns["DNS\n*.victor-malod.ovh"]
        s3["Object Storage\nTofu state"]

        subgraph vps["VPS · Ubuntu 24.04 · k3s"]
            argocd["ArgoCD\n(App of Apps)"]
            cert_manager["cert-manager\n+ OVH webhook"]
            traefik["Traefik\n(ingress)"]
            tls_secret["Wildcard TLS cert"]
        end
    end

    subgraph letsencrypt["Let's Encrypt"]
        acme["ACME v2"]
    end

    dev -->|"push"| homelab_repo
    dev -->|"push"| docker_repo
    docker_repo -->|"CI builds & pushes"| ghcr
    age -->|"decrypt secrets"| tooling
    kubeconfig -->|"cluster access"| tooling
    tooling -->|"tofu apply"| vps
    tooling -->|"tofu apply"| dns
    tooling -->|"state"| s3
    homelab_repo -->|"GitOps sync"| argocd
    argocd -->|"deploys"| cert_manager
    argocd -->|"deploys"| traefik
    cert_manager -->|"DNS-01 via OVH API"| dns
    acme -->|"verifies TXT"| dns
    acme -->|"issues cert"| cert_manager
    cert_manager -->|"stores"| tls_secret
    traefik -->|"serves TLS"| tls_secret
```

## Repository structure

```
Homelab/
├── terraform/        # OpenTofu — OVH VPS, DNS, k3s provisioning
├── argocd/           # ArgoCD Application manifests (App of Apps)
├── helm/             # Helm values files per app
│   ├── cert-manager/
│   ├── cert-manager-webhook-ovh/
│   ├── cluster-issuers/
│   └── traefik/
├── bootstrap/        # One-time bootstrap manifests (root ArgoCD app)
└── BOOTSTRAP.md      # Step-by-step provisioning guide
```

## Getting started

See [BOOTSTRAP.md](BOOTSTRAP.md) for the full provisioning guide.

## Git hooks

Conventional commits are enforced locally via a `commit-msg` hook available in `.githooks/`. Run this once after cloning:

```bash
git config core.hooksPath .githooks
```
