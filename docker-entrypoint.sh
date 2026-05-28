#!/usr/bin/env bash
set -euo pipefail

CLAUDE_HOME="${CLAUDE_HOME:-/home/node/.claude}"
CLAUDE_SETTINGS_TEMPLATE="${CLAUDE_SETTINGS_TEMPLATE:-/tmp/template_claude_settings.json}"
CLAUDE_SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$CLAUDE_HOME/skills}"

chown_claude_home() {
  if [ ! -d "$CLAUDE_HOME" ]; then
    mkdir -p "$CLAUDE_HOME"
  fi

  sudo find "$CLAUDE_HOME" \
    -path "$CLAUDE_SKILLS_DIR" -prune \
    -o -exec chown node:node {} +
}

init_claude_settings() {
  if [ ! -s "$CLAUDE_SETTINGS_TEMPLATE" ]; then
    echo "Warning: missing Claude settings template: $CLAUDE_SETTINGS_TEMPLATE" >&2
    return 0
  fi

  if [ ! -s "$CLAUDE_HOME/settings.json" ]; then
    cp "$CLAUDE_SETTINGS_TEMPLATE" "$CLAUDE_HOME/settings.json"
  fi
}

ensure_claude_marketplace() {
  local name="$1"
  local repo="$2"
  local source_url="$3"
  local marketplaces

  marketplaces="$(claude plugin marketplace list --json 2>/dev/null || printf "[]")"
  if jq -e --arg name "$name" --arg repo "$repo" --arg source_url "$source_url" '
    any(.[]; (.name // "") == $name or (.repo // "") == $repo or (.url // "") == $source_url or (.source // "") == $source_url)
  ' <<< "$marketplaces" >/dev/null; then
    return 0
  fi

  echo "Installing Claude plugin marketplace: $source_url"
  if ! claude plugin marketplace add --scope user "$source_url"; then
    echo "Warning: failed to install Claude plugin marketplace: $source_url" >&2
  fi
}

install_or_enable_claude_plugin() {
  local plugin="$1"
  local plugins

  plugins="$(claude plugin list --json 2>/dev/null || printf "[]")"
  if jq -e --arg plugin "$plugin" '
    any(.[]; .id == $plugin and .enabled == true)
  ' <<< "$plugins" >/dev/null; then
    return 0
  fi

  if jq -e --arg plugin "$plugin" '
    any(.[]; .id == $plugin)
  ' <<< "$plugins" >/dev/null; then
    echo "Enabling Claude plugin: $plugin"
    if ! claude plugin enable --scope user "$plugin"; then
      echo "Warning: failed to enable Claude plugin: $plugin" >&2
    fi
    return 0
  fi

  echo "Installing Claude plugin: $plugin"
  if ! claude plugin install --scope user "$plugin"; then
    echo "Warning: failed to install Claude plugin: $plugin" >&2
  fi
}

install_template_plugins() {
  if [ ! -s "$CLAUDE_SETTINGS_TEMPLATE" ]; then
    return 0
  fi

  ensure_claude_marketplace \
    "claude-plugins-official" \
    "anthropics/claude-plugins-official" \
    "https://github.com/anthropics/claude-plugins-official.git"

  while IFS=$'\t' read -r marketplace_name marketplace_repo; do
    [ -n "$marketplace_name" ] || continue
    [ -n "$marketplace_repo" ] || continue
    ensure_claude_marketplace "$marketplace_name" "$marketplace_repo" "https://github.com/${marketplace_repo}.git"
  done < <(jq -r '
    .extraKnownMarketplaces // {}
    | to_entries[]
    | .value.source as $source
    | select(($source.source // "") == "github" and ($source.repo // "") != "")
    | [.key, $source.repo]
    | @tsv
  ' "$CLAUDE_SETTINGS_TEMPLATE")

  while IFS= read -r plugin; do
    [ -n "$plugin" ] || continue
    install_or_enable_claude_plugin "$plugin"
  done < <(jq -r '
    .enabledPlugins // {}
    | to_entries[]
    | select(.value == true)
    | .key
  ' "$CLAUDE_SETTINGS_TEMPLATE")
}

configure_git_identity() {
  if [ -n "${GIT_USER:-}" ]; then
    git config --global user.name "$GIT_USER"
    echo "git user.name set to: $GIT_USER"
  fi

  if [ -n "${GIT_EMAIL:-}" ]; then
    git config --global user.email "$GIT_EMAIL"
    echo "git user.email set to: $GIT_EMAIL"
  fi
}

chown_claude_home
init_claude_settings
install_template_plugins
configure_git_identity

exec "$@"
