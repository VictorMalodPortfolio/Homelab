locals {
  secrets  = yamldecode(data.sops_file.secrets.raw)
  vps_ipv4 = one([for ip in data.ovh_vps.main.ips : ip if !strcontains(ip, ":")])
}

data "sops_file" "secrets" {
  source_file = "${path.module}/secrets.sops.yaml"
}

# ── VPS ────────────────────────────────────────────────────────────────────────

data "ovh_vps" "main" {
  service_name = var.vps_name
}

# ── DNS ────────────────────────────────────────────────────────────────────────

resource "ovh_domain_zone_record" "root" {
  zone      = var.domain
  fieldtype = "A"
  subdomain = ""
  ttl       = 300
  target    = local.vps_ipv4
}

resource "ovh_domain_zone_record" "wildcard" {
  depends_on = [ovh_domain_zone_record.root]

  zone      = var.domain
  fieldtype = "A"
  subdomain = "*"
  ttl       = 300
  target    = local.vps_ipv4
}

# ── k3s install ────────────────────────────────────────────────────────────────

resource "null_resource" "k3s_install" {
  connection {
    type        = "ssh"
    host        = local.vps_ipv4
    user        = "ubuntu"
    private_key = file("~/.ssh/homelab")
  }

  provisioner "remote-exec" {
    inline = [
      # Install k3s without Traefik
      # Note: curl|sh is acceptable for a homelab — in production, verify the checksum first
      "curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC='--disable traefik' sh -",

      # Firewall — allow only what is needed, deny everything else
      # SSH rule is added first so we cannot lock ourselves out
      "sudo ufw allow 22/tcp comment 'SSH'",
      "sudo ufw allow 80/tcp comment 'HTTP'",
      "sudo ufw allow 443/tcp comment 'HTTPS'",
      "sudo ufw allow 6443/tcp comment 'k3s API'",
      "sudo ufw default deny incoming",
      "sudo ufw default allow outgoing",
      "sudo ufw --force enable"
    ]
  }
}

