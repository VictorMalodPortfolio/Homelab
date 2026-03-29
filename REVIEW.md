# DevOps Review — DockerTooling & Homelab

> Reviewed on 2026-03-30.

---

## DockerTooling

### Strengths

- **Version pinning with Renovate annotations** — every tool has a `# renovate: datasource=` comment, making automated updates clean and auditable.
- **Single RUN layer for base deps** — minimizes image layers correctly.
- **Non-root user** — proper security posture.
- **CI pipeline quality** — conventional commit enforcement, automated CHANGELOG, GHCR push all in one workflow.
- **Local commit hook** — `.githooks/commit-msg` brings the same validation locally.
- **`.bashrc`** — thoughtful shell setup: completions, k8s context in the prompt, sensible aliases.

### Issues

#### `latest`-only tagging

The image is always pushed as `latest`. If a bad Renovate PR gets merged, there's no rollback — the previous image is gone. Tagging with the git SHA or a version alongside `latest` gives you a recovery point.

#### No image vulnerability scanning

The CI builds and pushes but never scans the image. Homelab's CI has Trivy for IaC — the same should apply to the Docker image. A `trivy image` step before the push would catch CVEs in installed tools.

#### `docker-compose.yml` doesn't mount anything useful

There's no volume mount for `~/.kube`, `~/.ssh`, `~/.config/sops`, or a workspace directory. After the `WORKDIR` change to `/home/tooling/workspace`, users need to bind-mount their work there or the container starts in an empty directory. The compose file should document or provide these mounts.

#### No `.dockerignore`

Without it, the entire build context (including `.git`, any local secrets) gets sent to the Docker daemon on every build.

#### Image name inconsistency

`docker-compose.yml` builds `k8s-tooling:latest` locally, but CI pushes `ghcr.io/victormalodportfolio/k8s-tooling:latest`. These are different images with different names — a `docker compose pull` won't pull the GHCR image.

---

## Homelab

### Strengths

- **App of Apps pattern** — clean, idiomatic ArgoCD structure.
- **SOPS + age** — secrets are encrypted at rest in git, key management is simple and correct.
- **`BOOTSTRAP.md`** — step-by-step, reproducible, explains *why* (e.g. the Traefik disable flag warning). This is often skipped and it's genuinely valuable.
- **Terraform for DNS + provisioning** — DNS records and k3s install are codified, not manual.
- **Wildcard TLS with DNS-01** — correct approach for a private cluster; no need to expose HTTP-01 challenges.
- **Trivy IaC scanning in CI** — proactive security posture.
- **`selfHeal: true` + `prune: true`** on all apps — proper drift prevention.

### Issues

#### `.terraform.lock.hcl` is gitignored — this is a bug

The lockfile pins exact provider checksums for reproducibility. Ignoring it means `tofu init` can silently pull different provider versions on different machines. It should be committed. Remove it from `.gitignore`.

#### k3s and ArgoCD are not version-pinned

- k3s install uses `curl -sfL https://get.k3s.io | sh -` with no `INSTALL_K3S_VERSION` — whatever is `stable` at run time gets installed.
- ArgoCD bootstrap uses `.../argo-cd/stable/manifests/install.yaml` — same problem.

Both should pin to a specific version. Renovate could track k3s via a `# renovate:` comment in the bootstrap doc or a dedicated file.

#### ArgoCD is not self-managed

ArgoCD manages everything except itself. Upgrades require a manual `kubectl apply`. Consider adding ArgoCD as an ArgoCD Application pointing to the official Helm chart, making upgrades a GitOps PR like everything else.

#### `ovh-credentials` secret is imperative

Step 7 of the bootstrap creates the secret with `kubectl create secret` — outside of GitOps. If the cluster is rebuilt, this step must be remembered and repeated manually. Options to fix this:

- Use [External Secrets Operator](https://external-secrets.io) with a SOPS backend.
- Or use a bootstrap Job that reads from a SOPS-encrypted file in the repo.

#### `null_resource` for k3s provisioning is not idempotent

Terraform's `null_resource` + `remote-exec` won't re-run on `tofu apply` if the resource already exists, but it also can't detect actual drift (e.g. if k3s was uninstalled). For a homelab this is acceptable, but the idempotency gap is worth knowing about.

#### ArgoCD runs in insecure mode with no documented rationale

`server.insecure: "true"` is the right call when Traefik handles TLS termination, but Traefik → ArgoCD traffic is then plain HTTP inside the cluster. For a homelab this is acceptable, but the intent should be documented with a comment so it doesn't look like an oversight.

#### Port 6443 (k3s API) is open to the internet

The firewall allows `6443/tcp` from anywhere. The k8s API requires a valid certificate to do anything useful, but it's still an exposed surface. Restricting it to your home IP or a VPN would be a meaningful improvement.

#### `gitops/apps/` and `gitops/core/` are empty scaffolding

Decide whether to use this structure or collapse everything into `argocd/`. Dead directories create confusion.

#### No local commit hooks

DockerTooling has `.githooks/commit-msg`. Homelab enforces conventional commits in CI but has no local hook — non-conforming commits only fail after a push.

---

## Cross-cutting

Both repos are well above the homelab average. The tooling choices (SOPS, ArgoCD, OpenTofu, Renovate, conventional commits, CHANGELOG automation) form a coherent, professional stack.

The main gaps are:

| Priority | Item |
|---|---|
| Bug | `.terraform.lock.hcl` should be committed, not ignored |
| High | Image tagging — add SHA/version tag alongside `latest` |
| High | Pin k3s and ArgoCD to specific versions |
| Medium | Make ArgoCD self-managed via Helm |
| Medium | Replace imperative `ovh-credentials` secret with a declarative approach |
| Low | Add Trivy image scan to DockerTooling CI |
| Low | Add `.dockerignore` to DockerTooling |
| Low | Fix `docker-compose.yml` image name and add volume mounts |
| Low | Add local commit hook to Homelab |
| Low | Document ArgoCD insecure mode intent inline |
| Low | Restrict k3s API port to known IPs |
