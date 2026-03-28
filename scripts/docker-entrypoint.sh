#!/usr/bin/env bash

set -euo pipefail

if [[ ! -d "${HOME}" ]]; then
  echo "Error: ${HOME} does not exist inside the container." >&2
  exit 1
fi

if [[ ! -w "${HOME}" ]]; then
  echo "Error: ${HOME} is not writable by the current user." >&2
  exit 1
fi

mkdir -p "${HOME}/.codex" "${HOME}/.claude" "${HOME}/.cc-connect"

if [[ ! -f "${HOME}/.zshrc" ]]; then
  cp /usr/local/share/dev-container/zshrc "${HOME}/.zshrc"
fi

if [[ ! -f "${HOME}/.cc-connect/config.toml" && -f /usr/local/share/dev-container/config.example.toml ]]; then
  cp /usr/local/share/dev-container/config.example.toml "${HOME}/.cc-connect/config.toml"
fi

if [[ ! -f "${HOME}/.codex/config.toml" && ( -n "${CODEX_OPENAI_BASE_URL:-}" || -n "${CODEX_MODEL:-}" ) ]]; then
  {
    echo 'model_provider = "openai"'
    if [[ -n "${CODEX_MODEL:-}" ]]; then
      printf 'model = "%s"\n' "${CODEX_MODEL}"
    fi
    if [[ -n "${CODEX_OPENAI_BASE_URL:-}" ]]; then
      printf 'openai_base_url = "%s"\n' "${CODEX_OPENAI_BASE_URL}"
    fi
  } > "${HOME}/.codex/config.toml"
fi

exec "$@"
