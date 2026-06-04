#!/usr/bin/env bash
# Render inventory/hosts.yaml from the connection vars in .env. Emits a single
# host named "frit" so the playbooks (which target hosts: all) work unchanged.
#
# Two modes (see .env.example):
#   1) GCP VM   -- GCP_PROJECT/GCP_ZONE/GCP_VM_NAME set; live external IP from gcloud
#   2) any host -- TARGET_HOST=<alias|ip> (ssh_config alias, or ip + user/key)
#
# No secrets in the repo: gcloud creds stay in ~/.config/gcloud, the SSH key in
# ~/.ssh; .env (non-secret coords) and the rendered inventory are gitignored.
set -euo pipefail

cd "$(dirname "$0")/.."                       # -> frit/
ENV_FILE="${ENV_FILE:-.env}"
[ -f "$ENV_FILE" ] && { set -a; . "$ENV_FILE"; set +a; }

# Resolve a GCP VM's live external IP (Spot IPs change on every stop/start, so we
# never hardcode it). Falls back to an explicit TARGET_HOST for any other host.
if [ -z "${TARGET_HOST:-}" ] && [ -n "${GCP_VM_NAME:-}" ]; then
  TARGET_HOST="$(gcloud compute instances describe "$GCP_VM_NAME" \
    --project "${GCP_PROJECT:?set GCP_PROJECT in .env}" --zone "${GCP_ZONE:?set GCP_ZONE in .env}" \
    --format='value(networkInterfaces[0].accessConfigs[0].natIP)' 2>/dev/null || true)"
  [ -z "$TARGET_HOST" ] && { echo "ERROR: '$GCP_VM_NAME' has no external IP -- is it running? (make up)"; exit 1; }
fi
: "${TARGET_HOST:?Set TARGET_HOST in .env (ssh alias or IP), or GCP_VM_NAME/GCP_PROJECT/GCP_ZONE to resolve it live}"
mkdir -p ansible/inventory

ssh_args=(
  -F "$HOME/.ssh/config"
  -o StrictHostKeyChecking=accept-new
  -o ConnectTimeout=15
  -o ServerAliveInterval=15
  -o ServerAliveCountMax=4
)
[ -n "${SSH_JUMP:-}" ] && ssh_args+=( -o "ProxyJump=$SSH_JUMP" )

{
  echo "# Auto-generated from $ENV_FILE by bin/render-inventory.sh -- do not edit by hand."
  echo "all:"
  echo "  hosts:"
  echo "    frit:"
  echo "      ansible_host: ${TARGET_HOST}"
  [ -n "${TARGET_USER:-}" ]  && echo "      ansible_user: ${TARGET_USER}"
  [ -n "${TARGET_PORT:-}" ]  && echo "      ansible_port: ${TARGET_PORT}"
  [ -n "${SSH_KEY_PATH:-}" ] && echo "      ansible_ssh_private_key_file: ${SSH_KEY_PATH}"
  echo "      ansible_python_interpreter: auto_silent"
  echo "      ansible_ssh_common_args: '${ssh_args[*]}'"
} > ansible/inventory/hosts.yaml

echo "wrote ansible/inventory/hosts.yaml  (frit -> ${TARGET_HOST})"
