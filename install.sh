#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RUN_CLAUDE_PATH="${SCRIPT_DIR}/run-claude.sh"

# 确保 run-claude.sh 可执行
chmod +x "$RUN_CLAUDE_PATH"

# --- 检测当前 shell ---
detect_shell() {
  # 优先用 SHELL 环境变量，否则用当前进程名
  local sh
  sh="$(basename "${SHELL:-}" 2>/dev/null)"
  if [ -n "$sh" ]; then
    echo "$sh"
    return
  fi
  sh="$(ps -p $$ -o comm= 2>/dev/null | sed 's/^-//')"
  echo "$sh"
}

CURRENT_SHELL="$(detect_shell)"

# shell → rc 文件映射
get_rc_file() {
  case "$1" in
    zsh)  echo "$HOME/.zshrc" ;;
    bash) echo "$HOME/.bashrc" ;;
    *)    echo "" ;;
  esac
}

RC_FILE="$(get_rc_file "$CURRENT_SHELL")"

echo "Current shell : $CURRENT_SHELL"
echo "RC file       : ${RC_FILE:-N/A}"
echo "Alias         : run-claude -> ${RUN_CLAUDE_PATH}"
echo ""

if [ -z "$RC_FILE" ]; then
  echo "Unsupported shell: $CURRENT_SHELL"
  echo "Manually add:  alias run-claude='${RUN_CLAUDE_PATH}'"
  exit 1
fi

# --- 写入 alias ---
if grep -qF "alias run-claude=" "$RC_FILE" 2>/dev/null; then
  echo "[skip] alias already exists in $RC_FILE"
else
  # 确保文件末尾有换行
  if [ -f "$RC_FILE" ] && [ -s "$RC_FILE" ]; then
    if [ "$(tail -c1 "$RC_FILE" | wc -l)" -eq 0 ]; then
      echo "" >> "$RC_FILE"
    fi
  fi
  echo "alias run-claude='${RUN_CLAUDE_PATH}'" >> "$RC_FILE"
  echo "[done] added alias to $RC_FILE"
fi

# --- source 对应的 rc 文件 ---
if [ -f "$RC_FILE" ]; then
  echo ""
  echo "Sourcing $RC_FILE ..."
  source "$RC_FILE"
  echo "[done] $RC_FILE sourced."
fi
