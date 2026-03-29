# DevOps Review — DockerTooling & Homelab

> Reviewed on 2026-03-30.

---

## DockerTooling

### Strengths

- **Version pinning with Renovate annotations** — every tool has a `# renovate: datasource=` comment above its version number. This tells Renovate (the automated dependency update bot) exactly where to look for new releases, so it can open a PR automatically when a new version is available.
- **Single RUN layer for base deps** — in Docker, each `RUN` instruction creates a new "layer" that adds to the final image size. Grouping all package installs into one `RUN` keeps the image smaller.
- **Non-root user** — by default, processes inside a container run as `root` (the administrator). Creating a dedicated `tooling` user means a compromised process has fewer privileges.
- **CI pipeline quality** — conventional commit enforcement, automated CHANGELOG, GHCR push all in one workflow. GHCR (GitHub Container Registry) is GitHub's built-in place to store Docker images.
- **Local commit hook** — a commit hook is a small script that runs automatically before or after a git commit. `.githooks/commit-msg` checks your commit message format locally before it even reaches GitHub.
- **`.bashrc`** — thoughtful shell setup: completions (tab-completion for kubectl, helm, etc.), k8s context in the prompt (so you always know which cluster you're pointing at), and sensible aliases.

### Issues

#### `latest`-only tagging

Docker images can be tagged with a name like `latest`, a version number (`v1.2.3`), or a git commit hash (SHA). Here only `latest` is used, which always gets overwritten. If a bad Renovate PR gets merged, there's no rollback — the previous image is gone. Tagging with the git SHA or a version number alongside `latest` gives you a recovery point.

#### No image vulnerability scanning

The CI builds and pushes the image but never scans it for known security vulnerabilities (CVEs — publicly disclosed security flaws in software packages). Homelab's CI already uses Trivy for this on infrastructure files — the same tool could scan the Docker image before it's pushed.

#### `docker-compose.yml` doesn't mount anything useful

Docker Compose can "mount" (share) folders from your host machine into the container, so files are accessible inside it. Right now there's no mount for `~/.kube` (kubeconfig — the file kubectl uses to connect to the cluster), `~/.ssh` (SSH keys), `~/.config/sops` (age decryption key), or a workspace directory. After the `WORKDIR` change to `/home/tooling/workspace`, the container starts in an empty directory unless you add these mounts.

#### No `.dockerignore`

A `.dockerignore` file works like `.gitignore` but for Docker builds — it tells Docker which files to exclude from the build context (the set of files sent to Docker when building the image). Without it, everything including `.git` and any local secrets gets sent to the Docker daemon on every build, which is slower and potentially risky.

#### Image name inconsistency

`docker-compose.yml` builds an image named `k8s-tooling:latest` locally, but CI pushes `ghcr.io/victormalodportfolio/k8s-tooling:latest` to GitHub's registry. These are two separate image names — running `docker compose pull` won't fetch the remotely built image because the names don't match.

---

## Homelab

### Strengths

- **App of Apps pattern** — an ArgoCD pattern where one "root" Application manages all the others. Instead of manually deploying each app, you deploy just the root and ArgoCD takes care of everything else automatically.
- **SOPS + age** — SOPS is a tool that encrypts secrets (passwords, API keys) so they can be safely committed to git. `age` is the encryption key format used here. The encrypted files are in the repo; only someone with the private key can decrypt them.
- **`BOOTSTRAP.md`** — step-by-step, reproducible, explains *why* (e.g. the Traefik disable flag warning). Runbooks like this are often skipped and are genuinely valuable when rebuilding from scratch.
- **Terraform (OpenTofu) for DNS + provisioning** — instead of clicking through the OVH console to create DNS records or set up the server, everything is described in code (`providers.tf`, `main.tf`) and applied with one command. OpenTofu is the open-source fork of Terraform.
- **Wildcard TLS with DNS-01** — TLS is the protocol behind HTTPS. A wildcard certificate covers `*.victor-malod.ovh` (all subdomains at once). DNS-01 is a certificate challenge type where you prove domain ownership by creating a DNS record — this works even for services that aren't publicly reachable, unlike the HTTP-01 alternative.
- **Trivy IaC scanning in CI** — IaC (Infrastructure as Code) scanning checks your Terraform and Kubernetes files for misconfigurations and security issues before they're applied.
- **`selfHeal: true` + `prune: true`** on all ArgoCD apps — `selfHeal` means ArgoCD will automatically fix any manual change made directly on the cluster (reverting it to match git). `prune` means resources deleted from git are also deleted from the cluster. Together they enforce that git is always the source of truth.

### Issues

#### `.terraform.lock.hcl` is gitignored — this is a bug

The lock file (`.terraform.lock.hcl`) is automatically generated by OpenTofu and records the exact version and checksum of each provider (plugin) used — like `ovh`, `hashicorp/local`, etc. Committing it ensures everyone uses the exact same provider versions. Ignoring it means `tofu init` can silently install a different version on a different machine, which could cause unexpected behaviour. It should be committed to git. Remove `.terraform.lock.hcl` from `.gitignore`.

#### k3s and ArgoCD are not version-pinned

- k3s (the lightweight Kubernetes distribution used here) is installed with `curl -sfL https://get.k3s.io | sh -` — no version is specified, so it installs whatever is marked as `stable` on that day.
- ArgoCD is bootstrapped from a URL ending in `.../argo-cd/stable/manifests/install.yaml` — same problem.

If you rebuild the cluster six months from now, you'll get different versions than today. Both should reference a specific version number. Renovate could automate update PRs for these too.

#### ArgoCD is not self-managed

ArgoCD is the tool that deploys and updates everything else, but it doesn't manage its own installation. Upgrading ArgoCD requires a manual `kubectl apply` (running a command directly against the cluster, outside of GitOps). The fix is to add ArgoCD itself as an ArgoCD Application using its official Helm chart — then upgrading it becomes a normal git PR like any other app update.

> **Helm chart**: a packaged, reusable Kubernetes application template. Think of it like an installer for Kubernetes apps — you provide configuration values and Helm generates all the necessary Kubernetes resources.

#### `ovh-credentials` secret is imperative

Step 7 of the bootstrap creates the Kubernetes Secret (an object that stores sensitive data like passwords) by running a `kubectl create secret` command by hand. This is "imperative" (you do it manually) rather than "declarative" (defined in a file in git). If the cluster is rebuilt, this step must be remembered and repeated. Options to fix this:

- Use [External Secrets Operator](https://external-secrets.io) — a Kubernetes add-on that can read from a SOPS-encrypted file in the repo and automatically create the Secret for you.
- Or use a bootstrap Job (a one-time Kubernetes task) that reads the encrypted file and creates the Secret on first install.

#### `null_resource` for k3s provisioning is not idempotent

In Terraform, a `null_resource` with `remote-exec` runs a shell script over SSH on the server. The problem is that Terraform won't re-run it if it already ran once — it has no way to check whether k3s is actually installed or not. If k3s gets uninstalled for any reason, `tofu apply` won't fix it. This is called a lack of *idempotency* (the ability to run something multiple times and always reach the same result). For a homelab this is an acceptable trade-off, but it's worth knowing about.

#### ArgoCD runs in insecure mode with no documented rationale

The ArgoCD ConfigMap sets `server.insecure: "true"`, which disables TLS on ArgoCD's own HTTP server. This is intentional here — Traefik (the ingress/reverse proxy) handles TLS before traffic reaches ArgoCD, so there's no double-encryption needed. However, traffic between Traefik and ArgoCD inside the cluster is plain HTTP. For a homelab this is fine, but the intent should be explained with a comment in the file so it doesn't look like a security oversight.

> **Ingress / reverse proxy**: a component that sits in front of your services and routes incoming HTTP/HTTPS traffic to the right one. Traefik plays this role here.

#### Port 6443 (k3s API) is open to the internet

The firewall (`ufw`) allows connections on port 6443 from any IP address. This is the Kubernetes API port — it's what `kubectl` talks to. While a valid certificate is required to do anything useful, exposing it publicly increases the attack surface. Restricting it to your home IP address (or routing it through a VPN) would meaningfully reduce exposure.

#### `gitops/apps/` and `gitops/core/` are empty scaffolding

These directories exist but contain nothing. Either use them (move apps there and add an ArgoCD Application pointing to each) or remove them. Empty directories with no clear purpose create confusion about where new things should go.

#### No local commit hooks

DockerTooling has `.githooks/commit-msg` which validates commit message format before the commit is even created. Homelab enforces the same rule in CI, but only after a push — so a badly formatted commit message only fails once it's already in the remote repository.

---

## Cross-cutting

Both repos are well above the homelab average. The tooling choices (SOPS, ArgoCD, OpenTofu, Renovate, conventional commits, CHANGELOG automation) form a coherent, professional stack.

The main gaps are:

| Priority | Item |
|---|---|
| Bug | `.terraform.lock.hcl` should be committed, not ignored |
| High | Image tagging — add SHA/version tag alongside `latest` |
| High | Pin k3s and ArgoCD to specific versions |
| Medium | Make ArgoCD self-managed via its Helm chart |
| Medium | Replace imperative `ovh-credentials` secret with a declarative approach |
| Low | Add Trivy image scan to DockerTooling CI |
| Low | Add `.dockerignore` to DockerTooling |
| Low | Fix `docker-compose.yml` image name and add volume mounts |
| Low | Add local commit hook to Homelab |
| Low | Document ArgoCD insecure mode intent inline |
| Low | Restrict k3s API port to known IPs |
