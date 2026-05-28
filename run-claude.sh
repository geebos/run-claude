#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="claude-code-dev"

PROJECT_DIR="$PWD"
PROJECT_NAME="$(basename "$PROJECT_DIR")"
PROJECT_HASH="$(printf '%s' "$PROJECT_DIR" | sha1sum | cut -c1-8)"
CONTAINER_NAME="claude-code-dev-${PROJECT_NAME}-${PROJECT_HASH}"
HOST_PORT="3000"
PORT_SPECIFIED=false
BIND_PORT=true
ATTACH_CONTAINER=false

CLAUDE_VOL="claude-code-home-${PROJECT_NAME}-${PROJECT_HASH}"

SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
CLAUDE_JSON_FILE="$SCRIPT_DIR/.cache/.claude_${PROJECT_HASH}.json"
TEMPLATE_CLAUDE_JSON_FILE="$SCRIPT_DIR/template_claude.json"
TEMPLATE_CLAUDE_SETTINGS_FILE="$SCRIPT_DIR/template_claude_settings.json"

ENV_FILE="$SCRIPT_DIR/.env"

SKILLS_SRC="$HOME/.claude/skills"
SKILLS_REAL="$(readlink -f "$SKILLS_SRC" 2>/dev/null || true)"

usage() {
  cat <<EOF
Usage: run-claude [-p HOST_PORT] [-n] [-a]

Options:
  -p HOST_PORT  Host port to bind to container port 3000. Default: 3000
  -n            Do not bind a host port to container port 3000
  -a            Open zsh in the current project's running dev container
  -h            Show this help
EOF
}

while getopts ":anp:h" opt; do
  case "$opt" in
    a)
      ATTACH_CONTAINER=true
      ;;
    n)
      BIND_PORT=false
      ;;
    p)
      HOST_PORT="$OPTARG"
      PORT_SPECIFIED=true
      ;;
    h)
      usage
      exit 0
      ;;
    :)
      echo "Option -$OPTARG requires an argument"
      usage
      exit 1
      ;;
    \?)
      echo "Unknown option: -$OPTARG"
      usage
      exit 1
      ;;
  esac
done

shift $((OPTIND - 1))

if [ "$#" -ne 0 ]; then
  echo "Unexpected arguments: $*"
  usage
  exit 1
fi

if [ "$BIND_PORT" = false ] && [ "$PORT_SPECIFIED" = true ]; then
  echo "Options -n and -p cannot be used together"
  usage
  exit 1
fi

if [ "$BIND_PORT" = true ]; then
  case "$HOST_PORT" in
    ''|*[!0-9]*)
      echo "Invalid host port: $HOST_PORT"
      exit 1
      ;;
  esac

  if [ "$HOST_PORT" -lt 1 ] || [ "$HOST_PORT" -gt 65535 ]; then
    echo "Host port must be between 1 and 65535: $HOST_PORT"
    exit 1
  fi
fi

if [ "$ATTACH_CONTAINER" = true ]; then
  if ! docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    echo "Project container does not exist: $CONTAINER_NAME"
    echo "Start it first with: run-claude"
    exit 1
  fi

  if [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME")" != "true" ]; then
    echo "Project container is not running: $CONTAINER_NAME"
    exit 1
  fi

  exec docker exec -it -w /workspace "$CONTAINER_NAME" zsh
fi

if [ ! -f "$ENV_FILE" ]; then
  echo "Missing env file: $ENV_FILE"
  exit 1
fi

if [ -z "$SKILLS_REAL" ] || [ ! -d "$SKILLS_REAL" ]; then
  echo "Missing skills dir: $SKILLS_SRC"
  exit 1
fi

mkdir -p "$(dirname "$CLAUDE_JSON_FILE")"

if [ ! -s "$CLAUDE_JSON_FILE" ]; then
  if [ ! -f "$TEMPLATE_CLAUDE_JSON_FILE" ]; then
    echo "Missing Claude template file: $TEMPLATE_CLAUDE_JSON_FILE"
    exit 1
  fi

  cp "$TEMPLATE_CLAUDE_JSON_FILE" "$CLAUDE_JSON_FILE"
fi

if [ ! -f "$TEMPLATE_CLAUDE_SETTINGS_FILE" ]; then
  echo "Missing Claude settings template file: $TEMPLATE_CLAUDE_SETTINGS_FILE"
  exit 1
fi

docker volume create "$CLAUDE_VOL" >/dev/null

set --
if [ "$BIND_PORT" = true ]; then
  set -- -p "$HOST_PORT:3000"
fi

docker run --rm -it \
  --name "$CONTAINER_NAME" \
  --user node:node \
  --security-opt no-new-privileges=false \
  --env-file "$ENV_FILE" \
  -e CLAUDE_SETTINGS_TEMPLATE=/tmp/template_claude_settings.json \
  "$@" \
  -v "$PROJECT_DIR:/workspace" \
  -v "$CLAUDE_VOL:/home/node/.claude" \
  -v "$CLAUDE_JSON_FILE:/home/node/.claude.json" \
  -v "$TEMPLATE_CLAUDE_SETTINGS_FILE:/tmp/template_claude_settings.json:ro" \
  -v "$SKILLS_REAL:/home/node/.claude/skills" \
  -w /workspace \
  "$IMAGE_NAME" \
  claude \
  --dangerously-skip-permissions \
  --system-prompt "You are running inside a Docker container with the project mounted at /workspace. When starting a dev server that should be reachable from the host, bind it to 0.0.0.0 and use container port 3000. Use sudo only when it is necessary for permission issues."
