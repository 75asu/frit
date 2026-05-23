#!/usr/bin/env python3
"""
Lightning SDK wrapper — called by Makefile targets.
Reads LIGHTNING_API_KEY, LIGHTNING_USER_ID from environment (via .env).

Usage:
  python3 scripts/studio.py run "nvidia-smi"
  python3 scripts/studio.py sync
  python3 scripts/studio.py status
  python3 scripts/studio.py start
  python3 scripts/studio.py stop
"""
import os
import sys

STUDIO_NAME   = os.environ.get("STUDIO_NAME", "frit")
TEAMSPACE     = os.environ["STUDIO_TEAMSPACE"]
USER          = os.environ["STUDIO_USER"]
REMOTE_DIR    = os.environ.get("STUDIO_DIR", "/teamspace/studios/this_studio") + "/" + STUDIO_NAME
STUDIO_MACHINE = os.environ.get("STUDIO_MACHINE", "T4")

def get_studio():
    from lightning_sdk import Studio
    return Studio(name=STUDIO_NAME, teamspace=TEAMSPACE, user=USER)

def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "status":
        s = get_studio()
        print(s.status)

    elif cmd == "start":
        from lightning_sdk.machine import Machine
        s = get_studio()
        if s.status != "Running":
            machine = getattr(Machine, STUDIO_MACHINE)
            print(f"Starting studio on {STUDIO_MACHINE}...")
            s.start(machine=machine)
            print("Studio running.")
        else:
            print("Already running.")

    elif cmd == "stop":
        s = get_studio()
        s.stop()
        print("Studio stopped.")

    elif cmd == "run":
        if len(sys.argv) < 3:
            print("Usage: studio.py run <command>")
            sys.exit(1)
        s = get_studio()
        remote_cmd = sys.argv[2]
        # Ensure remote dir exists, then run command inside it
        out = s.run(f"mkdir -p {REMOTE_DIR} && cd {REMOTE_DIR} && {remote_cmd}")
        if out:
            print(out, end="")

    elif cmd == "sync":
        import pathlib
        s = get_studio()
        repo_root = pathlib.Path(__file__).parent.parent
        print(f"Syncing {repo_root} → {REMOTE_DIR} ...")
        s.run(f"mkdir -p {REMOTE_DIR}")
        s.upload_folder(str(repo_root), REMOTE_DIR)
        print("Sync complete.")

    elif cmd == "ssh-user":
        s = get_studio()
        print(f"s_{s._studio.id}")

    else:
        print(f"Unknown command: {cmd}")
        sys.exit(1)

if __name__ == "__main__":
    main()
