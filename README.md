Vault (dev mode) + Vault Secrets Operator, deployed via ArgoCD.
An app's secret lives in Vault; VSO syncs it into a native Kubernetes
Secret; Gitea consumes it via `existingSecret`. Only pointers live in git.
