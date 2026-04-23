# syntax=docker/dockerfile:1.7

FROM ubuntu:24.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG TARGETARCH
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
        ncurses-bin \
        openssh-server \
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

RUN usermod --shell /usr/bin/zsh root

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
    && npm install -g \
        typescript \
        tsx \
        "${CODEX_NPM_PACKAGE}" \
        "${CLAUDE_NPM_PACKAGE}"

RUN mkdir -p /workspace /root/.npm-global /root/.claude /root/.codex /root/.local/bin

COPY scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY scripts/zshrc /usr/local/share/dev-container/zshrc
COPY terminfo/xterm-ghostty.terminfo /usr/local/share/dev-container/terminfo/xterm-ghostty.terminfo

RUN chmod +x /usr/local/bin/docker-entrypoint.sh \
    && tic -x -o /usr/share/terminfo /usr/local/share/dev-container/terminfo/xterm-ghostty.terminfo \
    && mkdir -p /run/sshd \
    && printf '%s\n' \
        'Port 22' \
        'Protocol 2' \
        'PermitRootLogin prohibit-password' \
        'PasswordAuthentication no' \
        'KbdInteractiveAuthentication no' \
        'UsePAM yes' \
        'PubkeyAuthentication yes' \
        'AuthorizedKeysFile .ssh/authorized_keys' \
        'X11Forwarding no' \
        'PrintMotd no' \
        'Subsystem sftp /usr/lib/openssh/sftp-server' \
        >/etc/ssh/sshd_config

WORKDIR /workspace

ENV HOME=/root \
    NPM_CONFIG_PREFIX=/root/.npm-global \
    PATH=/root/.local/bin:/root/.npm-global/bin:/usr/local/bin:${PATH} \
    DISABLE_AUTOUPDATER=1

RUN printf '%s\n' \
        '{' \
        '  "autoUpdatesChannel": "stable",' \
        '  "env": {' \
        '    "DISABLE_AUTOUPDATER": "1"' \
        '  }' \
        '}' >/root/.claude/settings.json

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
    && claude --version \
    && infocmp xterm-ghostty >/dev/null

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
CMD ["zsh"]
