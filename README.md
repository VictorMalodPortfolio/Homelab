# Homelab

Personal Kubernetes homelab deployed on an OVH VPS. Provisioned with OpenTofu, managed with GitOps via ArgoCD.

## Architecture

```mermaid
graph TD
    dev["💻 Developer"]

    subgraph local["Local Machine"]
        tooling["DockerTooling container\nkubectl · helm · tofu · sops"]
        age["age key\n~/.config/sops/age/key.txt"]
        kubeconfig["kubeconfig\n~/.kube/config"]
    end

    subgraph github["GitHub"]
        homelab_repo["Homelab repo\n(this repo)"]
        docker_repo["DockerTooling repo"]
        ghcr["GHCR\nghcr.io/victormalodportfolio/k8s-tooling"]
    end

    subgraph ovh["OVH"]
        dns["DNS\nvictor-malod.ovh\n*.victor-malod.ovh"]
        s3["Object Storage\nOpenTofu state backend"]

        subgraph vps["VPS · Ubuntu 24.04"]
            k3s["k3s v1.35"]

            subgraph argocd_ns["argocd"]
                argocd["ArgoCD\n(App of Apps)"]
            end

            subgraph cert_manager_ns["cert-manager"]
                cert_manager["cert-manager"]
                webhook["aureq OVH webhook"]
                ovh_secret["Secret: ovh-credentials"]
            end

            subgraph traefik_ns["traefik"]
                traefik["Traefik\n(ingress)"]
                tls_secret["Secret: wildcard TLS cert"]
            end
        end
    end

    subgraph letsencrypt["Let's Encrypt"]
        acme["ACME v2"]
    end

    dev -->|"push"| homelab_repo
    dev -->|"push"| docker_repo
    docker_repo -->|"CI builds image"| ghcr
    homelab_repo -->|"GitOps sync"| argocd
    argocd -->|"deploys"| cert_manager
    argocd -->|"deploys"| webhook
    argocd -->|"deploys"| traefik

    tooling -->|"tofu apply"| vps
    tooling -->|"tofu apply"| dns
    tooling -->|"state"| s3
    age -->|"decrypt secrets"| tooling
    kubeconfig -->|"cluster access"| tooling

    webhook -->|"reads"| ovh_secret
    webhook -->|"creates TXT record"| dns
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
