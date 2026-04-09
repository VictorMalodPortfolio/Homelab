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

From inside the tooling container (launched from the Homelab directory):

```bash
sops workspace/terraform/secrets.sops.yaml
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
sops exec-env secrets.sops.yaml 'tofu init'
sops exec-env secrets.sops.yaml 'tofu apply'
```

> Both `tofu init` and `tofu apply` need the S3 backend credentials from sops.

This provisions:
- DNS records (`victor-malod.ovh` + wildcard → VPS IP)
- k3s on the VPS (Traefik disabled)
- ufw firewall (ports 22, 80, 443, 6443)

---

## 4. Fetch kubeconfig

Find the VPS IP in the OVH console or via `tofu state show data.ovh_vps.main`.

```bash
ssh -i ~/.ssh/homelab ubuntu@<VPS_IP> "sudo cat /etc/rancher/k3s/k3s.yaml" \
    | sed 's/127.0.0.1/<VPS_IP>/g' \
    > ~/.kube/config
```

Verify inside the tooling container:

```bash
kubectl get nodes
```

---

## 5. Bootstrap ArgoCD

Inside the tooling container:

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl get pods -n argocd -w
```

Wait until all 7 pods are `Running`.

### 5a. Enable helm-secrets on the repo-server

Create the age key secret (used by helm-secrets to decrypt SOPS-encrypted values):

```bash
kubectl create secret generic helm-secrets-private-keys \
  --namespace argocd \
  --from-file=key.txt=$HOME/.config/sops/age/key.txt
```

Patch the repo-server to use the custom image and mount the age key:

```bash
kubectl patch deployment argocd-repo-server -n argocd \
  --type strategic \
  --patch-file workspace/bootstrap/helm-secrets-patch.yaml
kubectl rollout status deployment argocd-repo-server -n argocd
```

> The custom image (`ghcr.io/victormalodportfolio/argocd-repo-server`) is built by CI from `docker/argocd-repo-server/Dockerfile` and includes helm-secrets, sops, and age.

---

## 6. Connect ArgoCD to the Homelab repo

Generate a deploy key on the host:

```bash
ssh-keygen -t ed25519 -C "argocd-homelab" -f ~/.ssh/argocd-homelab -N ""
cat ~/.ssh/argocd-homelab.pub
```

Add the public key as a read-only deploy key in GitHub:
**Homelab repo → Settings → Deploy keys → Add deploy key** (read-only).

Register the repo in ArgoCD (inside the tooling container — the key is visible via the `~/.ssh` mount):

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

## 7. Encrypt OVH credentials for GitOps

The OVH credentials are managed declaratively via helm-secrets. Create the encrypted values file (if it doesn't already exist):

```bash
cd workspace/helm/ovh-credentials
cp secrets.example.yaml secrets.sops.yaml
sops secrets.sops.yaml
```

Fill in the real OVH credentials, save, and exit. SOPS encrypts the file automatically using the age key from `.sops.yaml`.

> The encrypted `secrets.sops.yaml` must be committed to Git. ArgoCD decrypts it at sync time using the age key deployed in step 5a.

---

## 8. Deploy everything via App of Apps

Apply the root ArgoCD Application (one-time manual step — after this, everything is GitOps):

```bash
kubectl apply -f workspace/bootstrap/root-app.yaml
kubectl get applications -n argocd -w
```

ArgoCD will automatically deploy cert-manager, Traefik, the OVH webhook, decrypt and create the OVH credentials secret, and request a wildcard TLS certificate for `*.victor-malod.ovh`.

Once `argocd-config` is synced, restart the ArgoCD server to pick up the insecure mode ConfigMap:

```bash
kubectl rollout restart deployment argocd-server -n argocd
```

ArgoCD is then available at `https://argocd.victor-malod.ovh`.

---

## 9. Save ArgoCD admin password

Retrieve the initial admin password and save it to sops:

```bash
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath='{.data.password}' | base64 -d
```

```bash
sops workspace/terraform/secrets.sops.yaml
```

Add:

```yaml
argocd_admin_password: "..."
```

---

## Upgrading k3s

k3s upgrades are in-place and preserve all running workloads.
**Always pass `INSTALL_K3S_EXEC='--disable traefik'`** — omitting it re-enables k3s's bundled Traefik on top of ours.

```bash
# SSH into the VPS
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=<target-version> INSTALL_K3S_EXEC='--disable traefik' sh -
kubectl get nodes
kubectl get pods -A
```
