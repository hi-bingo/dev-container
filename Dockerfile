# syntax=docker/dockerfile:1.7

FROM python:3.12-slim-bookworm

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG TARGETARCH
ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000
ARG NODE_VERSION=22.18.0
ARG CODEX_NPM_PACKAGE=@openai/codex@latest
ARG CLAUDE_NPM_PACKAGE=@anthropic-ai/claude-code@latest
ARG IMAGE_CREATED=unknown
ARG IMAGE_REVISION=unknown
ARG IMAGE_SOURCE=https://github.com/unknown/unknown
ARG IMAGE_DESCRIPTION=Personal development container with Python, Node.js, Codex, and Claude Code.

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
    NPM_CONFIG_UPDATE_NOTIFIER=false

RUN apt-get update \
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
        xz-utils \
        zsh \
    && rm -rf /var/lib/apt/lists/*

RUN arch="${TARGETARCH:-$(dpkg --print-architecture)}" \
    && case "${arch}" in \
        amd64) node_arch="x64" ;; \
        arm64) node_arch="arm64" ;; \
        *) echo "Unsupported TARGETARCH: ${arch}" >&2; exit 1 ;; \
    esac \
    && curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${node_arch}.tar.xz" -o /tmp/node.tar.xz \
    && tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 \
    && rm -f /tmp/node.tar.xz \
    && ln -sf /usr/local/bin/node /usr/local/bin/nodejs \
    && corepack enable

RUN groupadd --gid "${USER_GID}" "${USERNAME}" \
    && useradd --uid "${USER_UID}" --gid "${USER_GID}" --create-home --shell /bin/zsh "${USERNAME}" \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME} \
    && mkdir -p /workspace /home/${USERNAME}/.npm-global /home/${USERNAME}/.claude \
    && chown -R "${USERNAME}:${USERNAME}" /workspace /home/${USERNAME}

RUN git lfs install --system \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd

RUN python -m pip install --no-cache-dir --upgrade pip pipx uv

RUN npm install -g typescript tsx

RUN npm install -g "${CODEX_NPM_PACKAGE}"

RUN npm install -g "${CLAUDE_NPM_PACKAGE}"

USER ${USERNAME}
WORKDIR /workspace

ENV HOME=/home/${USERNAME} \
    NPM_CONFIG_PREFIX=/home/${USERNAME}/.npm-global \
    PATH=/home/${USERNAME}/.local/bin:/home/${USERNAME}/.npm-global/bin:/usr/local/bin:${PATH} \
    DISABLE_AUTOUPDATER=1

RUN printf '%s\n' \
        '{' \
        '  "autoUpdatesChannel": "stable",' \
        '  "env": {' \
        '    "DISABLE_AUTOUPDATER": "1"' \
        '  }' \
        '}' >"/home/${USERNAME}/.claude/settings.json"

RUN node --version \
    && npm --version \
    && python --version \
    && pip --version \
    && codex --version \
    && claude --version

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["zsh"]
