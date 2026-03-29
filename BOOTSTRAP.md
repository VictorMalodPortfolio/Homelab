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
- The DockerTooling image built: `docker compose build` (from `DockerTooling/`)

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
- k3s on the VPS (Traefik disabled)
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

---

## 6. Next steps

- Deploy Traefik via ArgoCD
- Deploy cert-manager via ArgoCD
- Configure wildcard TLS with Let's Encrypt + OVH DNS challenge
