## What does this PR do?

<!-- Describe the change and why it is needed. -->

## Type of change

- [ ] Infrastructure change (OpenTofu / OVH)
- [ ] Kubernetes / ArgoCD / Helm change
- [ ] CI / workflow change
- [ ] Bug fix
- [ ] Documentation

## Checklist

- [ ] Commit messages follow the conventional commits format
- [ ] The Trivy scans pass (or new CVEs are added to `.trivyignore.yaml` with a justification)

### If `.trivyignore.yaml` was touched

- [ ] Checked that all existing entries are still needed — run the Trivy scan without the ignore file and remove any CVE that no longer appears in the results
