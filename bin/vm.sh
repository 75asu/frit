#!/usr/bin/env bash
# GCP VM lifecycle for the lab box. Reads GCP_PROJECT / GCP_ZONE / GCP_VM_NAME
# (and TARGET_USER / SSH_KEY_PATH for `ssh`) from .env.
#
# No secrets live in this repo: gcloud credentials are in ~/.config/gcloud and the
# SSH private key in ~/.ssh -- neither is read into or written to the repo. .env
# (which holds only non-secret coords + paths) is gitignored.
set -euo pipefail

cd "$(dirname "$0")/.."
ENV_FILE="${ENV_FILE:-.env}"
[ -f "$ENV_FILE" ] && { set -a; . "$ENV_FILE"; set +a; }
: "${GCP_PROJECT:?set GCP_PROJECT in .env}"
: "${GCP_ZONE:?set GCP_ZONE in .env}"
: "${GCP_VM_NAME:?set GCP_VM_NAME in .env}"

g() { gcloud compute instances "$@" --project "$GCP_PROJECT" --zone "$GCP_ZONE"; }
ip() { g describe "$GCP_VM_NAME" --format='value(networkInterfaces[0].accessConfigs[0].natIP)' 2>/dev/null; }
st() { g describe "$GCP_VM_NAME" --format='value(status)' 2>/dev/null; }

case "${1:-}" in
  start)
    [ "$(st)" = "RUNNING" ] && { echo "$GCP_VM_NAME already RUNNING (ip $(ip))"; exit 0; }
    echo "starting $GCP_VM_NAME ..."; g start "$GCP_VM_NAME" -q >/dev/null
    echo "RUNNING   ip: $(ip)" ;;
  stop)
    echo "stopping $GCP_VM_NAME (billing stops; the 200GB disk persists ~\$20/mo) ..."
    g stop "$GCP_VM_NAME" -q >/dev/null; echo "status: $(st)" ;;
  status) echo "$GCP_VM_NAME: $(st)   ip: $(ip)" ;;
  ip) ip ;;
  ssh)
    [ "$(st)" = "RUNNING" ] || { echo "not running -- starting first ..."; g start "$GCP_VM_NAME" -q >/dev/null; }
    : "${TARGET_USER:?set TARGET_USER in .env}"; : "${SSH_KEY_PATH:?set SSH_KEY_PATH in .env}"
    key="${SSH_KEY_PATH/#\~/$HOME}"
    exec ssh -i "$key" -o StrictHostKeyChecking=accept-new "${TARGET_USER}@$(ip)" ;;
  autostop)
    region="${GCP_ZONE%-*}"; pol="${GCP_VM_NAME}-nightly-stop"
    echo "ensuring daily auto-stop schedule '$pol' (21:00 IST / 15:30 UTC) in $region ..."
    gcloud compute resource-policies create instance-schedule "$pol" \
      --project "$GCP_PROJECT" --region "$region" \
      --vm-stop-schedule="30 15 * * *" --timezone=UTC 2>&1 | tail -1 || true
    gcloud compute instances add-resource-policies "$GCP_VM_NAME" \
      --project "$GCP_PROJECT" --zone "$GCP_ZONE" --resource-policies="$pol" 2>&1 | tail -1 || true
    echo "done -- VM auto-stops nightly even if you forget to." ;;
  *) echo "usage: bin/vm.sh {start|stop|status|ip|ssh|autostop}"; exit 1 ;;
esac
