# k8s-gitops-vault-secrets

Vault (dev mode) + Vault Secrets Operator, deployed via ArgoCD.
An app's secret lives in Vault; VSO syncs it into a native Kubernetes
Secret; Gitea consumes it via `existingSecret`. Only pointers live in git.

## Flow

```
 Vault (dev mode)          VaultStaticSecret          k8s Secret          Gitea Pod
 secret/gitea/admin  ---->  (VSO controller)   ---->  gitea-admin  ---->  existingSecret
 (kv-v2, in-memory)         reads every ~30s          (refreshAfter: 30s)  mount
```

VSO authenticates to Vault via Kubernetes auth (`VaultAuth` → ServiceAccount
`vault-auth`, role `gitea`). No secret material ever touches git.

## Prerequisites
- A Kubernetes cluster with ArgoCD installed (shared setup, once per
  cluster).

## Deploy
```bash
kubectl apply -f argocd/root.yaml
```
The app-of-apps root watches `argocd/` and adopts every other Application
manifest there automatically (Vault, VSO, the VSO manifests, Gitea).

Vault dev mode loses all state on pod restart (including after a cluster
rebuild) — re-run the imperative setup once Vault is up:
```bash
./scripts/configure-vault.sh
```
It's idempotent: safe to re-run any time, won't clobber a rotated secret.

## Rotate the secret
```bash
kubectl -n vault exec vault-0 -- sh -c \
  "VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root \
   vault kv put secret/gitea/admin username=gitea_admin password='<new-password>'"
```
VSO picks up the change within `refreshAfter` (~30s) and updates the
`gitea-admin` Secret; restart Gitea to pick it up:
```bash
kubectl -n gitops-vault-secrets rollout restart deploy/gitea-vault
```

## Gotchas
- ArgoCD caches the Helm render for an Application — after editing an
  Application's `spec.source.helm.valuesObject`, force a re-template with:
  ```bash
  kubectl -n argocd annotate application <name> argocd.argoproj.io/refresh=hard --overwrite
  ```
- Gitea uses `strategy: Recreate`, not `RollingUpdate` — two pods sharing
  the RWO PVC's leveldb queue deadlock under a rolling update.
