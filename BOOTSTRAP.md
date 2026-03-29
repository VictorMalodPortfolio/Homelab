# Bootstrap

Step-by-step guide to provision the homelab from scratch.

## Prerequisites

- OVH account with:
  - A VPS (Ubuntu 24.04 LTS)
  - A domain (`victor-malod.ovh`)
  - An Object Storage bucket (`healthy-charpak`, region GRA)
  - API credentials (Application Key, Application Secret, Consumer Key)
  - Object Storage credentials (Access Key, Secret Key)
- An SSH key pair at `~/.ssh/homelab` registered on the VPS
- An age key at `~/.config/sops/age/key.txt`
- Docker Desktop running
- The DockerTooling image (pulled automatically from GHCR on first run)

---

## 1. Fill in secrets

From inside the tooling container, edit the encrypted secrets file:

```bash
sops terraform/secrets.sops.yaml
```

Ensure the following keys are present:

```yaml
ovh_application_key: "..."
ovh_application_secret: "..."
ovh_consumer_key: "..."
AWS_ACCESS_KEY_ID: "..."
AWS_SECRET_ACCESS_KEY: "..."
```

---

## 2. Fill in variables

Edit `terraform/terraform.tfvars`:

```hcl
vps_name = "vps-XXXXXXXX.vps.ovh.net"
```

---

## 3. Provision infrastructure

From inside the tooling container (launched from the Homelab directory):

```bash
cd workspace/terraform
tofu init
sops exec-env secrets.sops.yaml 'tofu apply'
```

This provisions:
- DNS records (`victor-malod.ovh` + wildcard → VPS IP)
- k3s on the VPS (Traefik disabled, version pinned in `main.tf`)
- ufw firewall (ports 22, 80, 443, 6443)

---

## 4. Fetch kubeconfig

From PowerShell on the host:

```powershell
ssh -i "$env:USERPROFILE\.ssh\homelab" ubuntu@<VPS_IP> "sudo cat /etc/rancher/k3s/k3s.yaml" `
    | ForEach-Object { $_ -replace '127.0.0.1', '<VPS_IP>' } `
    | Set-Content -Force "$env:USERPROFILE\.kube\config"
```

Verify:

```bash
kubectl get nodes
```

---

## 5. Bootstrap ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl get pods -n argocd -w
```

Wait until all 7 pods are `Running`.

---

## 6. Connect ArgoCD to the Homelab repo

Generate a deploy key for the Homelab repo:

```bash
ssh-keygen -t ed25519 -C "argocd-homelab" -f ~/.ssh/argocd-homelab -N ""
```

Add the public key as a read-only deploy key in GitHub:
**Homelab repo → Settings → Deploy keys → Add deploy key** (read-only).

Register the repo in ArgoCD:

```bash
kubectl create secret generic homelab-repo \
  --namespace argocd \
  --from-literal=type=git \
  --from-literal=url=git@github.com:VictorMalodPortfolio/Homelab.git \
  --from-file=sshPrivateKey=$HOME/.ssh/argocd-homelab
kubectl label secret homelab-repo -n argocd \
  argocd.argoproj.io/secret-type=repository
```

---

## 7. Deploy cert-manager

Create `argocd/cert-manager.yaml` in this repo, then:

```bash
kubectl apply -f argocd/cert-manager.yaml
```

Wait for cert-manager pods to be ready before proceeding.

---

## 8. Deploy Traefik

Create `argocd/traefik.yaml` in this repo, then:

```bash
kubectl apply -f argocd/traefik.yaml
```

---

## 9. Next steps

- Configure wildcard TLS with Let's Encrypt + OVH DNS challenge
- Expose ArgoCD UI via Traefik ingress

---

## Upgrading k3s

k3s upgrades are in-place and preserve all running workloads.
**Always pass `INSTALL_K3S_EXEC='--disable traefik'`** — omitting it re-enables k3s's bundled Traefik on top of ours.

```bash
# SSH into the VPS
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.35.2+k3s1 INSTALL_K3S_EXEC='--disable traefik' sh -
kubectl get nodes
kubectl get pods -A
```
