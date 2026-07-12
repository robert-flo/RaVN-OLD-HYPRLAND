#!/usr/bin/env bash
set -euo pipefail

RAVN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="${RAVN_ADMIN_HOST_REPORT_DIR:-${RAVN_DIR}/cache/admin-host-reports}"

die() {
  printf 'Error: %s\n' "$1" >&2
  exit 2
}

task=""
host_mode=false
approved=false
authorized=false
while (($# > 0)); do
  case $1 in
    --host)
      host_mode=true
      shift
      ;;
    --approve | --yes)
      approved=true
      shift
      ;;
    --authorize-host)
      authorized=true
      shift
      ;;
    --report-dir)
      (($# >= 2)) || die '--report-dir requires a path'
      REPORT_DIR=$2
      shift 2
      ;;
    -h | --help)
      printf '%s\n' 'Usage: test-task-admin-host.sh --host <task> --approve --authorize-host'
      exit 0
      ;;
    --*) die "unknown option: $1" ;;
    *)
      [[ -z $task ]] || die 'only one task can be selected'
      task=$1
      shift
      ;;
  esac
done

[[ $host_mode == true ]] || die 'host mode requires the explicit --host selector'
[[ -n $task ]] || die 'task is required'
[[ $approved == true ]] || {
  printf 'NOT_RUN: host Apply requires --approve\n'
  exit 3
}
[[ $authorized == true ]] || die 'non-interactive host mode requires --authorize-host'
[[ $task == ssh-config ]] || die "host task not supported: $task"
command -v ssh > /dev/null || die 'ssh is required for host verification'

task_file="${RAVN_DIR}/tasks/90-system/03-ssh-config.sh"
[[ -f $task_file ]] || die "task not found: $task"
mkdir -p "$REPORT_DIR"
report_file="${REPORT_DIR}/${task}-$(date +%Y%m%dT%H%M%S).json"
backup_dir="${XDG_STATE_HOME:-$HOME/.local/state}/ravn/backups/${task}"
mkdir -p "$backup_dir"
backup_file="${backup_dir}/config.$(date +%Y%m%dT%H%M%S).bak"

# shellcheck disable=SC1090
source "$task_file"
preflight="config=${SSH_CONFIG}; permissions=$(stat -c '%a' "${SSH_CONFIG}" 2> /dev/null || printf absent); backup=${backup_file}; recovery=restore backup and run ssh -G again"
printf 'Host preflight (read-only): %s\n' "$preflight"
admin_plan || die "preflight rejected: ${ADMIN_PLAN_CONFLICT:-task plan failed}"

if [[ -f $SSH_CONFIG ]]; then
  cp -p "$SSH_CONFIG" "$backup_file"
else
  : > "$backup_file"
fi
[[ -f $backup_file ]] || die 'backup was not created'
if [[ -f $SSH_CONFIG ]]; then
  cmp -s "$SSH_CONFIG" "$backup_file" || die 'backup verification failed'
fi

apply_status=applied
verify_status=verified
if ! admin_apply; then
  apply_status=failed
  verify_status=failed
elif ! admin_verify; then
  verify_status=partially-verified
fi

cat > "$report_file" << EOF
{
  "task": "${ADMIN_TASK_ID}",
  "mode": "host",
  "approved": true,
  "authorized": true,
  "apply": "${apply_status}",
  "result": "${verify_status}",
  "resource": "${SSH_CONFIG}",
  "backup": "${backup_file}",
  "activation_boundary": "${ADMIN_ACTIVATION_BOUNDARY}",
  "recovery": "restore backup and run ssh -G again",
  "evidence_scope": "host-reconciliation"
}
EOF
printf 'Task: %s\nMode: host\nApply: %s\nVerify: %s\nBackup: %s\nReport: %s\n' "$task" "$apply_status" "$verify_status" "$backup_file" "$report_file"
[[ $verify_status == verified ]]
