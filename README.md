# Homelab

Personal Kubernetes homelab deployed on an OVH VPS. Provisioned with OpenTofu, managed with GitOps via ArgoCD.

## Repository structure

```
Homelab/
├── terraform/       # OVH infrastructure provisioning
├── gitops/          # ArgoCD applications
└── BOOTSTRAP.md     # Step-by-step provisioning guide
```

## Getting started

See [BOOTSTRAP.md](BOOTSTRAP.md) for the full provisioning guide.

## Git hooks

Conventional commits are enforced locally via a `commit-msg` hook available in `.githooks/`. Run this once after cloning:

```bash
git config core.hooksPath .githooks
```
