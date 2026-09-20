#!/usr/bin/env bash
#
# External hibernation checkpoint for the Hibermachy attended hardware gate
# (issue #26 AC4, requirement HBR-REQ-075).
#
# This tool is deliberately independent of Hibermachy. Hibermachy's own sleep
# evidence observer hardcodes hibernationConfirmed=false and AC4 states that a
# Hibermachy "Completed" result and free-form journal text cannot certify
# hibernation. So the checkpoint half of that evidence has to come from outside
# the product. Nothing in this script reads Hibermachy state, config or logs.
#
# It answers exactly one question:
#
#   Did this machine come back from a sleep interval into the SAME session it
#   went down in?
#
# It does NOT claim to tell hibernation apart from ordinary suspend. Both look
# identical to every signal available here. Only the operator's external
# observation of a genuinely powered-down machine distinguishes them, which is
# why AC4 requires that observation separately. Read "Scope" below before
# pasting any of this into an evidence record.
#
# Runs as an ordinary user. Requires no root, no sudo, and no privileged read.
# Mutates nothing except its own state directory and one file under /dev/shm.
# It never initiates, requests or schedules sleep.

set -euo pipefail

readonly PROGRAM=${0##*/}
readonly MARKER=HBR-T26-CHECKPOINT
readonly SHM_PREFIX=/dev/shm/hibermachy-checkpoint

# Minimum observed sleep interval, in seconds, below which a verify is reported
# INDETERMINATE rather than confirmed. A real staged-sleep cycle is minutes;
# a couple of seconds of drift is not evidence of anything.
MIN_SLEEP_SECONDS=${MIN_SLEEP_SECONDS:-60}

usage() {
  cat <<'USAGE'
External same-session restoration checkpoint for the attended hardware gate.

  hibernation-checkpoint.sh record <label> [state-dir]
  hibernation-checkpoint.sh verify <label> [state-dir]

  record   Take a pre-sleep checkpoint. Run immediately BEFORE the operator
           triggers staged sleep. Writes <state-dir>/<label>.pre and a nonce
           under /dev/shm.
  verify   Compare the live system against that checkpoint. Run immediately
           AFTER the machine has resumed. Writes <state-dir>/<label>.post.

  <label>       Short identifier, e.g. cycle-1 (letters, digits, dot, dash).
  <state-dir>   Defaults to ./checkpoints relative to the current directory.

Exit status from verify:
  0  CONFIRMED      same session, and a real sleep interval elapsed
  1  BROKEN         the session did not survive; this is not a resume
  2  INDETERMINATE  session intact but no meaningful sleep interval observed
  3  usage or environment error

Environment:
  MIN_SLEEP_SECONDS   override the 60s floor for a "real" sleep interval
USAGE
}

fail() {
  printf '%s ERROR: %s\n' "$MARKER" "$*" >&2
  exit 3
}

# Clock readings come from python3 because only clock_gettime exposes
# CLOCK_BOOTTIME, and the MONOTONIC/BOOTTIME pair is the whole measurement:
#
#   CLOCK_MONOTONIC  stops while the system is suspended or hibernated
#   CLOCK_BOOTTIME   keeps counting through both
#
# so (BOOTTIME - MONOTONIC) is the total time this boot has spent asleep, read
# straight from the kernel. Differencing that across a cycle gives the sleep
# interval without trusting a log line, a timestamp, or the product.
read_clocks() {
  python3 - <<'PY'
import time
for name in ("REALTIME", "MONOTONIC", "BOOTTIME"):
    print(f"{name.lower()}={time.clock_gettime(getattr(time, 'CLOCK_' + name)):.3f}")
PY
}

# Identity-bearing values are hashed before they are ever written or printed.
# The runbook requires boot IDs and session identifiers to be sanitized, and an
# evidence record is meant to be publishable. A truncated digest still compares
# exactly, which is all the comparison needs.
digest() {
  printf '%s' "$1" | sha256sum | cut -c1-16
}

require_label() {
  [[ $1 =~ ^[A-Za-z0-9][A-Za-z0-9.-]{0,63}$ ]] \
    || fail "label must be 1-64 chars of letters, digits, dot or dash: $1"
}

# A checkpoint is four independent facts. They fail in different ways on
# purpose, so a broken result says which assumption actually broke.
collect() {
  local nonce_path=$1 clocks

  clocks=$(read_clocks) || fail "could not read system clocks"
  eval "$clocks"

  # 1. boot_id. Survives suspend and hibernation. Changes on any reboot,
  #    including the hard power-off that a failed hibernation leaves behind.
  local boot_id
  boot_id=$(< /proc/sys/kernel/random/boot_id) || fail "cannot read boot_id"

  # 2. PID 1 start time, in jiffies since boot. Proves the same init instance,
  #    independently of boot_id.
  local pid1_start
  pid1_start=$(awk '{print $22}' /proc/1/stat) || fail "cannot read /proc/1/stat"

  # 3. The /dev/shm nonce, read back if present. tmpfs lives in RAM, so it is
  #    written into the hibernation image and restored with it, and it is gone
  #    after any power cycle that did not restore an image. This is the single
  #    strongest discriminator between "resumed" and "rebooted into a fresh
  #    session that merely looks similar".
  local nonce_digest=absent
  if [[ -f $nonce_path ]]; then
    nonce_digest=$(digest "$(< "$nonce_path")")
  fi

  # 4. Swap free, in kB. Corroborating only. The hibernation image is released
  #    back to swap on resume, so this is never proof on its own.
  local swap_free
  swap_free=$(awk '/^SwapFree:/ {print $2}' /proc/meminfo)

  printf 'boot_id_digest=%s\n' "$(digest "$boot_id")"
  printf 'pid1_start_jiffies=%s\n' "$pid1_start"
  printf 'nonce_digest=%s\n' "$nonce_digest"
  printf 'swap_free_kb=%s\n' "$swap_free"
  printf 'clock_realtime=%s\n' "$realtime"
  printf 'clock_monotonic=%s\n' "$monotonic"
  printf 'clock_boottime=%s\n' "$boottime"
  # Time this boot had already spent asleep at the moment of the reading.
  printf 'slept_total_seconds=%s\n' "$(python3 -c "print(f'{$boottime - $monotonic:.3f}')")"
}

cmd_record() {
  local label=$1 state_dir=$2
  require_label "$label"

  local pre=$state_dir/$label.pre
  local nonce_path=$SHM_PREFIX-$label

  mkdir -p "$state_dir" || fail "cannot create state dir: $state_dir"

  # Refuse to silently overwrite. A pre-checkpoint is evidence; clobbering one
  # would quietly destroy the record of a cycle that may have already failed.
  if [[ -e $pre ]]; then
    fail "checkpoint already exists: $pre (choose a new label, or move it aside)"
  fi

  # The nonce is random and never leaves this machine in raw form.
  ( umask 077; head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' > "$nonce_path" ) \
    || fail "cannot write nonce to $nonce_path"

  {
    printf '%s RECORD\n' "$MARKER"
    printf 'label=%s\n' "$label"
    printf 'recorded_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    collect "$nonce_path"
  } > "$pre"

  cat "$pre"
  printf '\n%s pre-sleep checkpoint written: %s\n' "$MARKER" "$pre"
  printf '%s trigger staged sleep now. Do not reboot, and do not delete %s\n' \
    "$MARKER" "$nonce_path"
}

cmd_verify() {
  local label=$1 state_dir=$2
  require_label "$label"

  local pre=$state_dir/$label.pre
  local post=$state_dir/$label.post
  local nonce_path=$SHM_PREFIX-$label

  [[ -f $pre ]] || fail "no pre-sleep checkpoint at $pre; record one before sleeping"

  # Load the pre-sleep values under a pre_ prefix.
  local pre_boot_id_digest pre_pid1_start_jiffies pre_nonce_digest
  local pre_clock_monotonic pre_clock_boottime pre_clock_realtime
  local key value
  while IFS='=' read -r key value; do
    case $key in
      boot_id_digest)      pre_boot_id_digest=$value ;;
      pid1_start_jiffies)  pre_pid1_start_jiffies=$value ;;
      nonce_digest)        pre_nonce_digest=$value ;;
      clock_monotonic)     pre_clock_monotonic=$value ;;
      clock_boottime)      pre_clock_boottime=$value ;;
      clock_realtime)      pre_clock_realtime=$value ;;
    esac
  done < "$pre"

  local now
  now=$(collect "$nonce_path")
  eval "$now"

  # Deltas. awake is time the system actually ran; elapsed includes sleep; the
  # difference is the sleep interval itself.
  local awake elapsed slept wall
  awake=$(python3 -c "print(f'{$clock_monotonic - $pre_clock_monotonic:.3f}')")
  elapsed=$(python3 -c "print(f'{$clock_boottime - $pre_clock_boottime:.3f}')")
  slept=$(python3 -c "print(f'{$elapsed - $awake:.3f}')")
  wall=$(python3 -c "print(f'{$clock_realtime - $pre_clock_realtime:.3f}')")

  local session_intact=yes reasons=()

  if [[ $boot_id_digest != "$pre_boot_id_digest" ]]; then
    session_intact=no
    reasons+=("boot_id changed: the machine rebooted rather than resumed")
  fi
  if [[ $pid1_start_jiffies != "$pre_pid1_start_jiffies" ]]; then
    session_intact=no
    reasons+=("PID 1 restarted: this is a different init instance")
  fi
  if [[ $nonce_digest == absent ]]; then
    session_intact=no
    reasons+=("/dev/shm nonce is gone: RAM contents were not restored")
  elif [[ $nonce_digest != "$pre_nonce_digest" ]]; then
    session_intact=no
    reasons+=("/dev/shm nonce changed: RAM contents were not the ones saved")
  fi

  local verdict status
  if [[ $session_intact == no ]]; then
    verdict=BROKEN
    status=1
  elif (( $(python3 -c "print(1 if $slept >= $MIN_SLEEP_SECONDS else 0)") )); then
    verdict=CONFIRMED
    status=0
  else
    verdict=INDETERMINATE
    status=2
  fi

  {
    printf '%s VERIFY %s\n' "$MARKER" "$verdict"
    printf 'label=%s\n' "$label"
    printf 'verified_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'boot_id_digest_match=%s\n' \
      "$([[ $boot_id_digest == "$pre_boot_id_digest" ]] && echo yes || echo no)"
    printf 'pid1_start_match=%s\n' \
      "$([[ $pid1_start_jiffies == "$pre_pid1_start_jiffies" ]] && echo yes || echo no)"
    printf 'shm_nonce_match=%s\n' \
      "$([[ $nonce_digest != absent && $nonce_digest == "$pre_nonce_digest" ]] && echo yes || echo no)"
    printf 'awake_seconds=%s\n' "$awake"
    printf 'elapsed_seconds=%s\n' "$elapsed"
    printf 'sleep_interval_seconds=%s\n' "$slept"
    printf 'wall_clock_delta_seconds=%s\n' "$wall"
    printf 'min_sleep_seconds=%s\n' "$MIN_SLEEP_SECONDS"
    for reason in "${reasons[@]+"${reasons[@]}"}"; do
      printf 'reason=%s\n' "$reason"
    done
  } > "$post"

  cat "$post"

  printf '\n'
  case $verdict in
    CONFIRMED)
      printf '%s Same-session restoration confirmed across a %s second sleep interval.\n' \
        "$MARKER" "$slept"
      printf '%s This does NOT by itself establish hibernation rather than suspend.\n' "$MARKER"
      printf '%s AC4 still requires the operator external powered-down observation.\n' "$MARKER"
      ;;
    INDETERMINATE)
      printf '%s Session intact, but only %s seconds of sleep were observed\n' "$MARKER" "$slept"
      printf '%s (floor is %s). Record this cycle as INDETERMINATE, not a pass.\n' \
        "$MARKER" "$MIN_SLEEP_SECONDS"
      ;;
    BROKEN)
      printf '%s The session did NOT survive. This is not a same-session resume.\n' "$MARKER"
      for reason in "${reasons[@]+"${reasons[@]}"}"; do
        printf '%s   - %s\n' "$MARKER" "$reason"
      done
      printf '%s Record the cycle as FAIL, investigate, and restart the count at zero.\n' "$MARKER"
      ;;
  esac

  # The nonce has served its purpose; leaving it would let a later cycle match
  # a stale value and report a resume that never happened.
  rm -f -- "$nonce_path"

  return "$status"
}

main() {
  case ${1:-} in
    record|verify) ;;
    -h|--help|help|'') usage; exit 0 ;;
    *) usage >&2; exit 3 ;;
  esac

  local mode=$1
  [[ $# -ge 2 ]] || { usage >&2; exit 3; }
  local label=$2
  local state_dir=${3:-./checkpoints}

  command -v python3 >/dev/null 2>&1 || fail "python3 is required for clock_gettime"

  case $mode in
    record) cmd_record "$label" "$state_dir" ;;
    verify) cmd_verify "$label" "$state_dir" ;;
  esac
}

main "$@"
