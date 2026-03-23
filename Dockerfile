# syntax=docker/dockerfile:1.7

FROM node:22-bookworm-slim AS node-runtime

FROM python:3.12-slim-bookworm

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000
ARG CLAUDE_CHANNEL=stable
ARG CODEX_NPM_PACKAGE=@openai/codex@latest
ARG CC_CONNECT_NPM_PACKAGE=cc-connect@latest
ARG IMAGE_CREATED=unknown
ARG IMAGE_REVISION=unknown
ARG IMAGE_SOURCE=https://github.com/unknown/unknown
ARG IMAGE_DESCRIPTION=Personal development container with Python, Node.js, Codex, Claude Code, and cc-connect.

LABEL org.opencontainers.image.created="${IMAGE_CREATED}" \
      org.opencontainers.image.revision="${IMAGE_REVISION}" \
      org.opencontainers.image.source="${IMAGE_SOURCE}" \
      org.opencontainers.image.description="${IMAGE_DESCRIPTION}"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    NPM_CONFIG_UPDATE_NOTIFIER=false \
    HOME=/home/${USERNAME} \
    PATH=/home/${USERNAME}/.local/bin:/home/${USERNAME}/.npm-global/bin:/usr/local/bin:${PATH}

COPY --from=node-runtime /usr/local/bin/node /usr/local/bin/node
COPY --from=node-runtime /usr/local/bin/npm /usr/local/bin/npm
COPY --from=node-runtime /usr/local/bin/npx /usr/local/bin/npx
COPY --from=node-runtime /usr/local/bin/corepack /usr/local/bin/corepack
COPY --from=node-runtime /usr/local/include/node /usr/local/include/node
COPY --from=node-runtime /usr/local/lib/node_modules /usr/local/lib/node_modules

RUN ln -sf /usr/local/bin/node /usr/local/bin/nodejs \
    && mkdir -p /usr/local/share/man/man1 \
    && groupadd --gid "${USER_GID}" "${USERNAME}" \
    && useradd --uid "${USER_UID}" --gid "${USER_GID}" --create-home --shell /bin/zsh "${USERNAME}" \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        bash \
        build-essential \
        ca-certificates \
        curl \
        fd-find \
        git \
        git-lfs \
        jq \
        less \
        openssh-client \
        pkg-config \
        procps \
        ripgrep \
        sudo \
        tini \
        unzip \
        vim \
        wget \
        zsh \
    && rm -rf /var/lib/apt/lists/* \
    && git lfs install --system \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
    && python -m pip install --no-cache-dir --upgrade pip pipx uv \
    && npm install -g typescript tsx "${CODEX_NPM_PACKAGE}" "${CC_CONNECT_NPM_PACKAGE}" \
    && corepack enable \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME} \
    && mkdir -p /workspace /home/${USERNAME}/.npm-global /home/${USERNAME}/.claude \
    && chown -R "${USERNAME}:${USERNAME}" /workspace /home/${USERNAME}

USER ${USERNAME}
WORKDIR /workspace
ENV NPM_CONFIG_PREFIX=/home/${USERNAME}/.npm-global

RUN curl -fsSL -o /tmp/install-claude.sh https://claude.ai/install.sh \
    && bash /tmp/install-claude.sh "${CLAUDE_CHANNEL}" \
    && rm -f /tmp/install-claude.sh \
    && printf '%s\n' \
        '{' \
        '  "autoUpdatesChannel": "stable",' \
        '  "env": {' \
        '    "DISABLE_AUTOUPDATER": "1"' \
        '  }' \
        '}' >"/home/${USERNAME}/.claude/settings.json" \
    && node --version \
    && npm --version \
    && python --version \
    && pip --version \
    && codex --version \
    && cc-connect --version \
    && claude --version

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["zsh"]
