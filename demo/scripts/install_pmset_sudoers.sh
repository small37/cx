#!/usr/bin/env bash
set -euo pipefail

RULE_FILE="/etc/sudoers.d/sleepguard-pmset"
USER_NAME="${SUDO_USER:-$USER}"

if [[ -z "${USER_NAME}" ]]; then
  echo "无法识别当前用户名" >&2
  exit 1
fi

TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

cat >"$TMP_FILE" <<RULE
${USER_NAME} ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -a disablesleep 0
RULE

if [[ ! -d /etc/sudoers.d ]]; then
  echo "缺少 /etc/sudoers.d 目录" >&2
  exit 1
fi

sudo /usr/sbin/visudo -cf "$TMP_FILE"
sudo install -o root -g wheel -m 0440 "$TMP_FILE" "$RULE_FILE"
sudo /usr/sbin/visudo -cf "$RULE_FILE"

echo "已安装 sudoers 白名单: $RULE_FILE"
echo "验证命令: sudo -n /usr/bin/pmset -a disablesleep 1 && sudo -n /usr/bin/pmset -a disablesleep 0"
