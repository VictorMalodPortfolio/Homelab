FROM quay.io/argoproj/argocd:v3.3.6

# renovate: datasource=github-releases depName=jkroepke/helm-secrets extractVersion=^v(?<version>.+)$
ARG HELM_SECRETS_VERSION=4.7.6
# renovate: datasource=github-releases depName=getsops/sops extractVersion=^v(?<version>.+)$
ARG SOPS_VERSION=3.12.2
# renovate: datasource=github-releases depName=FiloSottile/age extractVersion=^v(?<version>.+)$
ARG AGE_VERSION=1.3.1

USER root

RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

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

USER argocd

ENV HELM_PLUGINS="/home/argocd/.local/share/helm/plugins"

RUN helm plugin install "https://github.com/jkroepke/helm-secrets" --version "${HELM_SECRETS_VERSION}"
