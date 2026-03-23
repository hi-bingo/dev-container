# dev-container

面向个人开发环境的基础镜像，预装：

- Python 3.12
- Node.js 22
- TypeScript CLI (`typescript`, `tsx`)
- `uv`, `pipx`
- `codex`
- `claude`
- `cc-connect`
- 常用终端工具：`git`, `git-lfs`, `ripgrep`, `fd`, `jq`, `zsh`, `vim`

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

```bash
docker build -t dev-container:local .
```

或者直接：

```bash
docker compose build
```

## 本地运行

先准备环境变量文件：

```bash
cp .env.example .env
```

然后启动：

```bash
docker compose run --rm dev
```

## Claude / Codex 认证

- `codex` 通过 `.env` 提供 `OPENAI_API_KEY`，容器启动时会把 `CODEX_OPENAI_BASE_URL` 和 `CODEX_MODEL` 写入 `~/.codex/config.toml`
- `claude` 通过 `.env` 提供 `ANTHROPIC_BASE_URL` 与 `ANTHROPIC_API_KEY` 或 `ANTHROPIC_AUTH_TOKEN`
- `compose.yaml` 只保留 `~/.ssh` 挂载，agent 配置不再依赖宿主机的 `~/.codex` 或 `~/.claude`

中转站示例：

```env
OPENAI_API_KEY=sk-...
CODEX_OPENAI_BASE_URL=https://your-openai-relay.example.com/v1
CODEX_MODEL=gpt-5-codex

ANTHROPIC_BASE_URL=https://your-anthropic-relay.example.com
ANTHROPIC_AUTH_TOKEN=sk-litellm-...
```

## 后续扩展

- `cc-connect` 已预装；你后续只需要在容器内或项目内补它自己的平台配置

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
