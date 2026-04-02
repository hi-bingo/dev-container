# dev-container

一个面向个人开发环境的 `dev-container` 模板，默认以 `root` 用户运行，预装常用开发工具，并内置：

- `codex`
- `claude`
- `cc-connect`
- Python 3.12 / `pipx` / `uv`
- Node.js 22 / `corepack` / TypeScript / `tsx`
- Bun
- `git` / `git-lfs` / `ripgrep` / `fd` / `jq` / `tmux` / `tree` / `htop` / `sqlite3` / `vim` / `zsh`

## 目标

- 容器内统一使用 `root`
- 复用宿主机的 `~/.ssh`、`~/.gitconfig`、`~/.codex`、`~/.claude`、`~/.cc-connect`
- 其中 `~/.ssh` 和 `~/.gitconfig` 只读挂载
- GitHub Actions 自动构建镜像并推送到 GHCR
- GHCR 只保留最新 3 个 image version

## 目录

```text
.
├── .github/workflows/publish.yml
├── .env.example
├── compose.yaml
├── config.example.toml
├── Dockerfile
└── scripts/
```

## 本地构建

```bash
docker build -t dev-container:local .
```

也可以直接让 Compose 使用本地构建：

```bash
docker compose build
```

## 本地运行

先准备环境变量：

```bash
cp .env.example .env
```

然后启动交互式开发环境：

```bash
docker compose pull
docker compose run --rm --service-ports dev
```

容器启动后默认工作目录是 `/workspace`，挂载自 `.env` 里的 `WORKSPACE_DIR`。

如果只想把容器作为常驻开发环境运行，也可以：

```bash
docker compose up -d
docker compose exec dev zsh
```

## 宿主机目录复用

`compose.yaml` 已经配置了以下挂载：

- `${HOME}/.ssh:/root/.ssh:ro`
- `${HOME}/.gitconfig:/root/.gitconfig:ro`
- `${HOME}/.codex:/root/.codex`
- `${HOME}/.claude:/root/.claude`
- `${HOME}/.cc-connect:/root/.cc-connect`

其中 `ssh` 和 `gitconfig` 为只读，其余目录读写复用，便于在容器内延续宿主机上的登录状态、配置和运行数据。

## SSH 访问

镜像内已启用 `sshd`，Compose 默认把宿主机 `2828` 映射到容器 `22`：

- `2828:22`

容器仅允许基于公钥的 `root` 登录，不启用密码登录，并复用宿主机挂载进容器的 `~/.ssh`。确保宿主机的 `~/.ssh/authorized_keys` 已包含你要使用的公钥后，可以这样连接：

```bash
ssh -p 2828 root@localhost
```

如果使用 `docker compose run`，要带上 `--service-ports`，否则不会发布 `2828` 端口。

## Codex / Claude / cc-connect

- `codex` 和 `claude` 已预装在镜像中
- `cc-connect` 已预装在镜像中
- 如果容器首次启动时 `/root/.cc-connect/config.toml` 不存在，会自动从仓库内的 [`config.example.toml`](./config.example.toml) 初始化
- 如果 `/root/.codex/config.toml` 不存在，且设置了 `CODEX_MODEL` 或 `CODEX_OPENAI_BASE_URL`，启动脚本会生成一个最小配置
- 如果宿主机目录里已经有这些配置，启动脚本不会覆盖

`.env.example` 里保留了常用变量：

```env
DEV_CONTAINER_IMAGE=ghcr.io/your-github-username/dev-container:latest
WORKSPACE_DIR=.

OPENAI_API_KEY=
CODEX_OPENAI_BASE_URL=
CODEX_MODEL=

ANTHROPIC_BASE_URL=
ANTHROPIC_API_KEY=
ANTHROPIC_AUTH_TOKEN=
```

## cc-connect 配置

推荐把真实配置放在宿主机的 `~/.cc-connect/config.toml`，这样进入容器后会直接映射到 `/root/.cc-connect/config.toml`。

仓库内提供了模板文件 [`config.example.toml`](./config.example.toml)，默认示例使用：

- agent: `codex`
- `work_dir = "/workspace"`
- mode: `suggest`

你可以按需改成 `claudecode`、`codex` 的其他模式，或增加 Telegram / Feishu / Discord 等平台配置。

## GitHub Actions 发布到 GHCR

工作流文件是 [`publish.yml`](./.github/workflows/publish.yml)。

触发条件：

- push 到 `main` 或 `master`
- push `v*` tag
- 手动触发 `workflow_dispatch`

发布行为：

- 构建 `linux/amd64` 和 `linux/arm64`
- 推送到 `ghcr.io/<owner>/<repo>`
- 默认打上分支、tag、`sha-*` 和默认分支上的 `latest`
- 构建完成后自动清理 GHCR，只保留最新 3 个 image version

## 使用建议

- 把仓库名保持为 `dev-container`，这样默认镜像地址和工作流配置更直观
- 把个人敏感配置放在宿主机目录，不要提交 `config.toml` 或 `.cc-connect/`
- 如果只想拉 GHCR 上的镜像，执行 `docker compose pull`
- 如果想验证 Dockerfile 改动，执行 `docker compose build`
