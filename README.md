# Homelab

[![CI](https://img.shields.io/github/actions/workflow/status/VictorMalodPortfolio/Homelab/ci.yml?branch=main&label=CI&style=for-the-badge)](https://github.com/VictorMalodPortfolio/Homelab/actions/workflows/ci.yml)
[![Platform](https://img.shields.io/badge/k3s-OVH%20VPS-FFC61C?logo=k3s&logoColor=black&style=for-the-badge)](https://k3s.io)
[![GitOps](https://img.shields.io/badge/GitOps-ArgoCD-EF7B4D?logo=argo&logoColor=white&style=for-the-badge)](https://argo-cd.readthedocs.io)
[![IaC](https://img.shields.io/badge/IaC-OpenTofu-623CE4?logo=opentofu&logoColor=white&style=for-the-badge)](https://opentofu.org)
[![TLS](https://img.shields.io/badge/TLS-Let's%20Encrypt-003A70?logo=letsencrypt&logoColor=white&style=for-the-badge)](https://letsencrypt.org)
[![Trivy](https://img.shields.io/badge/Trivy-IaC%20scan-1904DA?logo=aquasecurity&logoColor=white&style=for-the-badge)](https://github.com/VictorMalodPortfolio/Homelab/security/code-scanning)
[![Renovate](https://img.shields.io/badge/Renovate-enabled-1A1F6C?logo=renovatebot&logoColor=white&style=for-the-badge)](https://github.com/renovatebot/renovate)
[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-FE5196?logo=conventionalcommits&logoColor=white&style=for-the-badge)](https://conventionalcommits.org)
[![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)](LICENSE)

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
            helm_secrets["helm-secrets\n+ SOPS + age"]
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
    argocd -->|"decrypts secrets"| helm_secrets
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
├── docker/               # Custom Docker images
│   └── argocd-repo-server/  # ArgoCD repo-server with helm-secrets, sops, age
├── terraform/            # OpenTofu — OVH VPS, DNS, k3s provisioning
├── argocd/               # ArgoCD Application manifests (App of Apps)
├── helm/                 # Helm charts and values per app
│   ├── argocd-config/    # ArgoCD server config (insecure mode, helm-secrets, IngressRoute)
│   ├── cert-manager/
│   ├── cert-manager-webhook-ovh/
│   ├── cluster-issuers/
│   ├── ovh-credentials/  # OVH API secret (SOPS-encrypted values)
│   └── traefik/
├── bootstrap/            # One-time bootstrap manifests and patches
└── BOOTSTRAP.md          # Step-by-step provisioning guide
```

## Getting started

See [BOOTSTRAP.md](BOOTSTRAP.md) for the full provisioning guide.

## Git hooks

Conventional commits are enforced locally via a `commit-msg` hook available in `.githooks/`. Run this once after cloning:

```bash
git config core.hooksPath .githooks
```
