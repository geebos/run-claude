#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="claude-code-dev"

PROJECT_DIR="$PWD"
PROJECT_NAME="$(basename "$PROJECT_DIR")"
PROJECT_HASH="$(printf '%s' "$PROJECT_DIR" | sha1sum | cut -c1-8)"

CLAUDE_VOL="claude-code-home-${PROJECT_NAME}-${PROJECT_HASH}"
NODE_MODULES_VOL="claude-node-modules-${PROJECT_NAME}-${PROJECT_HASH}"
NEXT_VOL="claude-next-${PROJECT_NAME}-${PROJECT_HASH}"
PNPM_STORE_VOL="claude-pnpm-store-${PROJECT_NAME}-${PROJECT_HASH}"

SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
CLAUDE_JSON_FILE="$SCRIPT_DIR/.cache/.claude_${PROJECT_HASH}.json"

ENV_FILE="$SCRIPT_DIR/.env"

SKILLS_SRC="$HOME/.claude/skills"
SKILLS_REAL="$(readlink -f "$SKILLS_SRC" 2>/dev/null || true)"
SKILLS_CACHE="$SCRIPT_DIR/.cache/skills"

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing env file: $ENV_FILE"
  exit 1
fi

if [ -z "$SKILLS_REAL" ] || [ ! -d "$SKILLS_REAL" ]; then
  echo "Missing skills dir: $SKILLS_SRC"
  exit 1
fi

mkdir -p "$SKILLS_CACHE"

# 在宿主机解析 ~/.claude/skills 里的软链接，生成真实文件缓存
if command -v rsync >/dev/null 2>&1; then
  rsync -aL --delete "$SKILLS_REAL"/ "$SKILLS_CACHE"/
else
  rm -rf "$SKILLS_CACHE"
  mkdir -p "$SKILLS_CACHE"
  cp -aL "$SKILLS_REAL"/. "$SKILLS_CACHE"/
fi

mkdir -p "$(dirname "$CLAUDE_JSON_FILE")"
touch "$CLAUDE_JSON_FILE"

docker volume create "$CLAUDE_VOL" >/dev/null
docker volume create "$NODE_MODULES_VOL" >/dev/null
docker volume create "$NEXT_VOL" >/dev/null
docker volume create "$PNPM_STORE_VOL" >/dev/null

docker run --rm -it \
  --user 1000:1000 \
  --security-opt no-new-privileges=false \
  --env-file "$ENV_FILE" \
  -v "$PROJECT_DIR:/workspace" \
  -v "$NODE_MODULES_VOL:/workspace/node_modules" \
  -v "$NEXT_VOL:/workspace/.next" \
  -v "$PNPM_STORE_VOL:/workspace/.pnpm-store" \
  -v "$CLAUDE_VOL:/home/node/.claude" \
  -v "$CLAUDE_JSON_FILE:/home/node/.claude.json" \
  -v "$SKILLS_CACHE:/home/node/.claude/skills:ro" \
  -w /workspace \
  "$IMAGE_NAME" \
  bash -lc '
    set -euo pipefail

    # 配置 git user 和 email（从环境变量读取）
    if [ -n "${GIT_USER:-}" ]; then
      git config --global user.name "$GIT_USER"
      echo "git user.name set to: $GIT_USER"
    fi
    if [ -n "${GIT_EMAIL:-}" ]; then
      git config --global user.email "$GIT_EMAIL"
      echo "git user.email set to: $GIT_EMAIL"
    fi

    exec claude --dangerously-skip-permissions --system-prompt "Always use sudo when executing shell commands (e.g. npm install, mkdir, rm, chown, etc.). The workspace directories are owned by root so most file operations require sudo."
  '