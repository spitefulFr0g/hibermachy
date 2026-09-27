#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
bash -n "$root/hardware/iptsd/hibermachy-iptsd-guard" "$root/hardware/iptsd/manage"
python3 "$root/tests/iptsd_workaround.py"
