#!/usr/bin/env bash
# Imperative Vault setup for the gitea-admin secret chain.
# Dev-mode Vault loses all state on pod restart — re-run this after any
# cluster/Vault restart. Idempotent.
set -euo pipefail

NS_VAULT=vault
APP_NS=gitops-vault-secrets
ROLE=gitea
POLICY=gitea-admin-read
SECRET_PATH=secret/gitea/admin

kubectl -n "$NS_VAULT" exec vault-0 -- sh -e <<SH
export VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root

vault auth list | grep -q '^kubernetes/' || vault auth enable kubernetes
vault write auth/kubernetes/config kubernetes_host=https://kubernetes.default.svc

vault policy write $POLICY - <<POL
path "secret/data/gitea/admin" { capabilities = ["read"] }
POL

vault write auth/kubernetes/role/$ROLE \
  bound_service_account_names=vault-auth \
  bound_service_account_namespaces=$APP_NS \
  policies=$POLICY audience=vault ttl=1h

# Only seed the secret if it does not exist yet (don't clobber a rotation).
vault kv get $SECRET_PATH >/dev/null 2>&1 || \
  vault kv put $SECRET_PATH username=gitea_admin password=DevAdminPass_2026
SH
echo "Vault configured. Secret at $SECRET_PATH, role $ROLE bound to $APP_NS/vault-auth."
