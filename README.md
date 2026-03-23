# dev-container

面向个人开发环境的基础镜像，预装：

- Python 3.12
- Node.js 22
- TypeScript CLI (`typescript`, `tsx`)
- `uv`, `pipx`
- `codex`
- `claude`
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

- `codex` 首次运行时可走 ChatGPT 登录或 `OPENAI_API_KEY`
- `claude` 首次运行时需要 Claude Code 账户登录，或使用 Anthropic / Bedrock / Vertex 等 provider
- `compose.yaml` 默认会挂载 `~/.codex`、`~/.claude`、`~/.ssh`，这样本机登录态可以复用到容器内

## 后续扩展

- `cc-connect` 目前未预装，等主线镜像稳定后再单独加回去更稳妥

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
