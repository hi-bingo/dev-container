# syntax=docker/dockerfile:1.7

FROM ubuntu:24.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG TARGETARCH
ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000
ARG NODE_VERSION=22.18.0
ARG BUN_VERSION=1.1.38
ARG CODEX_NPM_PACKAGE=@openai/codex@latest
ARG CLAUDE_NPM_PACKAGE=@anthropic-ai/claude-code@latest
ARG IMAGE_CREATED=unknown
ARG IMAGE_REVISION=unknown
ARG IMAGE_SOURCE=https://github.com/unknown/unknown
ARG IMAGE_DESCRIPTION=Ubuntu 24.04 development container with Python, Node.js, Bun, Codex, and Claude Code.

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
        bash-completion \
        bubblewrap \
        build-essential \
        ca-certificates \
        curl \
        dnsutils \
        fd-find \
        git \
        git-lfs \
        htop \
        iproute2 \
        jq \
        less \
        nano \
        net-tools \
        openssh-client \
        pkg-config \
        procps \
        python-is-python3 \
        python3 \
        python3-dev \
        python3-pip \
        python3-venv \
        pipx \
        ripgrep \
        rsync \
        shellcheck \
        sqlite3 \
        sudo \
        tini \
        tmux \
        tree \
        unzip \
        vim \
        wget \
        xz-utils \
        zip \
        zsh \
    && rm -rf /var/lib/apt/lists/*

RUN ln -sf /usr/bin/fdfind /usr/local/bin/fd \
    && ln -sf /usr/bin/pip3 /usr/local/bin/pip

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

RUN arch="${TARGETARCH:-$(dpkg --print-architecture)}" \
    && case "${arch}" in \
        amd64) bun_arch="x64" ;; \
        arm64) bun_arch="aarch64" ;; \
        *) echo "Unsupported TARGETARCH: ${arch}" >&2; exit 1 ;; \
    esac \
    && curl -fsSL "https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/bun-linux-${bun_arch}.zip" -o /tmp/bun.zip \
    && unzip -q /tmp/bun.zip -d /opt/bun \
    && rm -f /tmp/bun.zip \
    && ln -sf "/opt/bun/bun-linux-${bun_arch}/bun" /usr/local/bin/bun \
    && ln -sf /usr/local/bin/bun /usr/local/bin/bunx

RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh

RUN git lfs install --system \
    && npm install -g typescript tsx "${CODEX_NPM_PACKAGE}" "${CLAUDE_NPM_PACKAGE}"

RUN set -eux; \
    if getent group "${USERNAME}" >/dev/null; then \
        user_group="${USERNAME}"; \
    elif getent group "${USER_GID}" >/dev/null; then \
        user_group="$(getent group "${USER_GID}" | cut -d: -f1)"; \
    else \
        groupadd --gid "${USER_GID}" "${USERNAME}"; \
        user_group="${USERNAME}"; \
    fi; \
    if id -u "${USERNAME}" >/dev/null 2>&1; then \
        usermod --uid "${USER_UID}" --gid "${user_group}" --shell /bin/zsh "${USERNAME}"; \
    elif getent passwd "${USER_UID}" >/dev/null; then \
        existing_user="$(getent passwd "${USER_UID}" | cut -d: -f1)"; \
        usermod --login "${USERNAME}" --home "/home/${USERNAME}" --move-home --gid "${user_group}" --shell /bin/zsh "${existing_user}"; \
    else \
        useradd --uid "${USER_UID}" --gid "${user_group}" --create-home --shell /bin/zsh "${USERNAME}"; \
    fi; \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/${USERNAME}; \
    chmod 0440 /etc/sudoers.d/${USERNAME}; \
    mkdir -p /workspace "/home/${USERNAME}/.npm-global" "/home/${USERNAME}/.claude" "/home/${USERNAME}/.local/bin"; \
    chown -R "${USERNAME}:${user_group}" /workspace "/home/${USERNAME}"

COPY scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY scripts/zshrc /usr/local/share/dev-container/zshrc

RUN chmod +x /usr/local/bin/docker-entrypoint.sh

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
    && corepack --version \
    && bun --version \
    && python --version \
    && pip --version \
    && pipx --version \
    && uv --version \
    && tsc --version \
    && tsx --version \
    && codex --version \
    && claude --version

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["zsh"]
