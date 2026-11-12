# Keep in sync with the ArgoCD install manifest version in BOOTSTRAP.md (step 5).
FROM quay.io/argoproj/argocd:v3.5.6

# renovate: datasource=github-releases depName=jkroepke/helm-secrets extractVersion=^v(?<version>.+)$
ARG HELM_SECRETS_VERSION=4.7.11
# renovate: datasource=github-releases depName=getsops/sops extractVersion=^v(?<version>.+)$
ARG SOPS_VERSION=3.13.3
# renovate: datasource=github-releases depName=FiloSottile/age extractVersion=^v(?<version>.+)$
ARG AGE_VERSION=1.3.2

USER root

# CI passes the date, so this layer runs again every day instead of staying
# frozen in the build cache with yesterday's packages.
ARG APT_REFRESH=manual
# Upgrade: Ubuntu's security fixes land between ArgoCD releases, and the CI gate
# fails on any OS package CVE that has a fix.
# pebble comes with the Ubuntu base image. ArgoCD never runs it, and its Go
# dependencies only add CVEs to the scan.
RUN echo "apt refresh: ${APT_REFRESH}" \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/* \
    && rm -f /usr/bin/pebble

# sops
RUN curl -fsSL "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.amd64" -o /tmp/sops \
    && CHECKSUM=$(curl -fsSL "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.checksums.txt" \
        | grep "sops-v${SOPS_VERSION}.linux.amd64$" | awk '{print $1}') \
    && echo "${CHECKSUM}  /tmp/sops" | sha256sum -c \
    && install -m 0755 /tmp/sops /usr/local/bin/sops \
    && rm /tmp/sops

# age — no SHA checksum published; .proof files are a custom transparency log format
# incompatible with cosign. Download integrity relies on TLS only.
RUN curl -fsSL "https://github.com/FiloSottile/age/releases/download/v${AGE_VERSION}/age-v${AGE_VERSION}-linux-amd64.tar.gz" -o /tmp/age.tar.gz \
    && tar -xz -C /usr/local/bin --strip-components=1 age/age -f /tmp/age.tar.gz \
    && chmod 0755 /usr/local/bin/age \
    && rm /tmp/age.tar.gz

# UID 999 = argocd user in the base image
# Numeric form required by runAsNonRoot security context
# https://github.com/argoproj/argo-cd/blob/v3.5.6/Dockerfile
USER 999

ENV HELM_PLUGINS="/home/argocd/.local/share/helm/plugins"

# helm-secrets — Helm 4 (bundled since ArgoCD 3.5) splits it into three plugins
# and drops `helm plugin install --version`, so each one is installed from its
# release tarball. Helm 4 checks every tarball against its .prov signature; the
# keyring is the author's GPG key, the one helm-secrets' docs point to.
RUN curl -fsSL https://github.com/jkroepke.gpg | gpg --dearmor > /tmp/helm-secrets-keyring.gpg \
    && for plugin in secrets secrets-getter secrets-post-renderer; do \
         helm plugin install --keyring /tmp/helm-secrets-keyring.gpg \
           "https://github.com/jkroepke/helm-secrets/releases/download/v${HELM_SECRETS_VERSION}/${plugin}-${HELM_SECRETS_VERSION}.tgz" \
         || exit 1; \
       done \
    && rm /tmp/helm-secrets-keyring.gpg

# Wrapper script — found before /usr/local/bin/helm on PATH,
# intercepts helm calls to decrypt secrets:// value files
ENV PATH="/home/argocd/.local/bin:${PATH}"
RUN mkdir -p /home/argocd/.local/bin \
    && ln -sf "${HELM_PLUGINS}/secrets/scripts/wrapper/helm.sh" /home/argocd/.local/bin/helm
