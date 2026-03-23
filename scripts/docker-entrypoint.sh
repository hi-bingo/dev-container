#!/usr/bin/env bash

set -euo pipefail

mkdir -p "${HOME}/.codex" "${HOME}/.claude"

if [[ -n "${CODEX_OPENAI_BASE_URL:-}" || -n "${CODEX_MODEL:-}" ]]; then
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
