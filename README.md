# dev-container

面向个人开发环境的基础镜像，预装：

- Ubuntu 24.04
- Python 3.12（`python`, `pip`, `venv`, `pipx`, `uv`）
- Node.js 22
- TypeScript / Node CLI（`typescript`, `tsx`, `corepack`）
- Bun
- `codex`
- `claude`
- 默认启用 `zsh`，内置基础补全
- 常用终端工具：`git`, `git-lfs`, `ripgrep`, `fd`, `jq`, `tmux`, `tree`, `htop`, `sqlite3`, `zsh`, `vim`

## 仓库建议结构

```bash
.
├── .github/workflows/publish.yml
├── .env.example
├── .gitignore
├── compose.yaml
└── Dockerfile
```

## 本地构建

仓库维护者如果要手动验证镜像，可以直接本地构建：

```bash
docker build -t dev-container:local .
```

或者直接：

```bash
docker compose build
```

如需覆盖默认版本，可以使用 build args：

```bash
docker build \
  --build-arg NODE_VERSION=22.18.0 \
  --build-arg BUN_VERSION=1.1.38 \
  -t dev-container:local .
```

## 本地运行

先准备环境变量文件：

```bash
cp .env.example .env
```

`compose.yaml` 默认按使用方场景配置，会直接从 GHCR 拉镜像：

```bash
docker compose pull
docker compose run --rm dev
```

默认镜像地址是：

```text
ghcr.io/hi-bingo/dev-container:latest
```

如需固定版本或切换标签，修改 `.env` 里的 `DEV_CONTAINER_IMAGE` 即可，例如：

```bash
DEV_CONTAINER_IMAGE=ghcr.io/hi-bingo/dev-container:v1.0.0
WORKSPACE_DIR=.
```

## Claude / Codex 认证

- `codex` 通过 `.env` 提供 `OPENAI_API_KEY`，容器启动时会把 `CODEX_OPENAI_BASE_URL` 和 `CODEX_MODEL` 写入 `~/.codex/config.toml`
- `claude` 通过 `.env` 提供 `ANTHROPIC_BASE_URL` 与 `ANTHROPIC_API_KEY` 或 `ANTHROPIC_AUTH_TOKEN`
- 容器默认以 `root` 用户运行，`HOME` 是 `/root`
- `compose.yaml` 会挂载当前工作目录到 `/workspace`
- `compose.yaml` 会把宿主机 `${HOME}/.ssh` 只读挂到容器内 `/root/.ssh`，直接复用主机 SSH 配置与密钥
- `compose.yaml` 会把宿主机 `${HOME}/.gitconfig` 挂到容器内 `/root/.gitconfig`，直接复用主机上的 Git 用户名、邮箱和别名配置
- `compose.yaml` 会把宿主机 `${HOME}/.codex`、`${HOME}/.claude`、`${HOME}/.cc-connect` 挂到容器内 `/root` 下，直接复用这些工具的配置和状态目录

中转站示例：

```env
OPENAI_API_KEY=sk-...
CODEX_OPENAI_BASE_URL=https://your-openai-relay.example.com/v1
CODEX_MODEL=gpt-5-codex

ANTHROPIC_BASE_URL=https://your-anthropic-relay.example.com
ANTHROPIC_AUTH_TOKEN=sk-litellm-...
```

## GitHub 配置

在 GitHub 上需要确认两件事：

1. 仓库已启用 GitHub Actions
2. 组织或个人账户允许发布到 GHCR

如果仓库是私有的，首次 push 后通常还需要在 GitHub 的 package 页面把包可见性和访问权限确认一遍。

## GHCR 发布

workflow 会在以下场景自动构建：

- push 到 `main` 或 `master`
- push `v*` tag
- 手动触发 `workflow_dispatch`

镜像地址默认是：

```text
ghcr.io/<owner>/<repo>
```

拉取示例：

```bash
docker pull ghcr.io/<owner>/<repo>:latest
```

手动发版示例：

```bash
git tag v1.0.0
git push origin main
git push origin v1.0.0
```

常见镜像标签：

- `latest`
- `main` 或 `master`
- `sha-<commit>`
- `v1.0.0`
