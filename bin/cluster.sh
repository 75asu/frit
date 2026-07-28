#!/usr/bin/env bash
# frit multi-node cluster helper.
#   T4 (asu-sandbox) = k3s SERVER (control-plane); other GPU VMs join as AGENTS (workers).
# Server coords come from .env.t4; the AGENT is the active .env (or ENV_FILE=...).
# No secrets in the repo: node-token is fetched live over SSH, never written to disk here.
set -euo pipefail
cd "$(dirname "$0")/.."

SERVER_ENV=".env.t4"
AGENT_ENV="${ENV_FILE:-.env}"

# read the server's gcloud coords from .env.t4 (subshell so it doesn't clobber the agent env)
server_coords() {
  [ -f "$SERVER_ENV" ] || { echo "missing $SERVER_ENV (the T4 server config) -- create it first (make use-t4 flow)"; exit 1; }
  ( set -a; . "$SERVER_ENV"; set +a
    printf '%s %s %s %s %s\n' "$GCP_PROJECT" "$GCP_ZONE" "$GCP_VM_NAME" "$TARGET_USER" "${SSH_KEY_PATH/#\~/$HOME}" )
}

case "${1:-}" in
  firewall)
    read -r P Z VM U K < <(server_coords)
    SUBNET=$(gcloud compute networks subnets describe default --project "$P" --region "${Z%-*}" \
             --format="value(ipCidrRange)" 2>/dev/null || echo "10.160.0.0/20")
    echo ">>> firewall 'frit-k3s-internal': allow tcp:6443,tcp:10250,udp:8472 from ${SUBNET} (k3s node-to-node)"
    gcloud compute firewall-rules create frit-k3s-internal \
      --project "$P" --network=default --direction=INGRESS --action=ALLOW \
      --rules=tcp:6443,tcp:10250,udp:8472 --source-ranges="$SUBNET" 2>&1 | tail -2 \
      || echo "(rule already exists -- ok)"
    ;;

  join)
    read -r P Z VM U K < <(server_coords)
    echo ">>> server=${VM}: ensuring it is RUNNING (control-plane must be up to join an agent) ..."
    [ "$(gcloud compute instances describe "$VM" --project "$P" --zone "$Z" --format='value(status)')" = "RUNNING" ] \
      || gcloud compute instances start "$VM" --project "$P" --zone "$Z" -q >/dev/null
    SRV_INT=$(gcloud compute instances describe "$VM" --project "$P" --zone "$Z" \
              --format='value(networkInterfaces[0].networkIP)')
    SRV_EXT=$(gcloud compute instances describe "$VM" --project "$P" --zone "$Z" \
              --format='value(networkInterfaces[0].accessConfigs[0].natIP)')
    echo ">>> server internal IP = ${SRV_INT} (stable across restarts); fetching node-token over SSH ..."
    TOKEN=$(ssh -i "$K" -o StrictHostKeyChecking=accept-new "${U}@${SRV_EXT}" \
            "sudo cat /var/lib/rancher/k3s/server/node-token")
    [ -n "${TOKEN:-}" ] || { echo "ERROR: could not read node-token from the server -- is k3s running there?"; exit 1; }

    echo ">>> agent = active ${AGENT_ENV}: install GPU driver, then join k3s as an agent ..."
    ENV_FILE="$AGENT_ENV" bin/render-inventory.sh
    ansible-playbook ansible/playbooks/gpu.yaml
    ansible-playbook ansible/playbooks/k3s-agent.yaml \
      -e "k3s_url=https://${SRV_INT}:6443" -e "k3s_token=${TOKEN}"
    echo ">>> agent join issued. Verify from the SERVER: 'make use-t4 && make tunnel' then 'kubectl --context frit-t4 get nodes' (agent Ready in ~60s)."
    ;;

  *) echo "usage: bin/cluster.sh {firewall|join}"; exit 1 ;;
esac
