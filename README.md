# dev-container

一个面向个人开发环境的 `dev-container` 模板，默认以 `root` 用户运行，预装常用开发工具，并内置：

- `codex`
- `claude`
- Python 3.12 / `pipx` / `uv`
- Node.js 22 / `corepack` / TypeScript / `tsx`
- Bun
- `git` / `git-lfs` / `ripgrep` / `fd` / `jq` / `tmux` / `tree` / `htop` / `sqlite3` / `vim` / `zsh`
- `sudo` / `bash-completion` / `man-db` / `manpages`
- `cmake` / `ninja-build` / `gdb` / `strace` / `lsof` / `patch` / `file`
- `dnsutils` / `iputils-ping` / `net-tools` / `gnupg`

## 目标

- 容器内统一使用 `root`
- 复用宿主机的 `~/.ssh`、`~/.gitconfig`、`~/.codex`、`~/.claude`
- 其中 `~/.ssh` 和 `~/.gitconfig` 只读挂载
- GitHub Actions 自动构建镜像并推送到 GHCR
- GHCR 只保留最新 10 个 image version

## 目录

```text
.
├── .github/workflows/publish.yml
├── .env.example
├── compose.yaml
├── compose.local.yaml
├── Dockerfile
└── scripts/
```

## 远程镜像运行

默认的 [compose.yaml](./compose.yaml) 面向“远程机器直接拉取 GHCR 镜像运行”这个场景：

```bash
docker compose pull
docker compose run --rm --service-ports dev
```

如果只想把容器作为常驻开发环境运行，也可以：

```bash
docker compose up -d
docker compose exec dev zsh
```

`compose.yaml` 会始终优先拉取 `${DEV_CONTAINER_IMAGE}`，适合远程主机长期跟随最新镜像。

## 本地构建

```bash
docker build -t dev-container:local .
```

如果要直接用 Compose 构建并运行本地 Dockerfile，叠加 [compose.local.yaml](./compose.local.yaml)：

```bash
docker compose -f compose.yaml -f compose.local.yaml build
docker compose -f compose.yaml -f compose.local.yaml run --rm --service-ports dev
```

本地常驻运行同理：

```bash
docker compose -f compose.yaml -f compose.local.yaml up -d --build
docker compose -f compose.yaml -f compose.local.yaml exec dev zsh
```

`compose.local.yaml` 会切换到本地 `build:`，并使用 `${DEV_CONTAINER_LOCAL_IMAGE}` 作为本地镜像名。

不要对叠加了 `compose.local.yaml` 的配置执行 `docker compose pull`。Docker Compose 会尝试为带 `build:` 的服务拉取镜像，这时本地标签通常并不存在于远端仓库，可能出现 `manifest unknown`。本地场景请使用：

```bash
docker compose -f compose.yaml -f compose.local.yaml build
docker compose -f compose.yaml -f compose.local.yaml up -d --build
```

如果只是想在叠加本地配置时跳过这些可构建服务的拉取，可以使用：

```bash
docker compose -f compose.yaml -f compose.local.yaml pull --ignore-buildable
```

## 环境变量

先准备环境变量：

```bash
cp .env.example .env
```

容器启动后默认工作目录是 `/workspace`，并把 `.env` 里的 `WORKSPACE_DIR` 挂载到这里。

镜像默认将 `root` 的登录 shell 设为 `zsh`；通过 `ssh` 登录容器时会直接进入 `zsh`。

## Root / sudo

容器默认以 `root` 用户运行，见 [compose.yaml](./compose.yaml)。因此大多数情况下可以直接执行系统级命令，不需要额外写 `sudo`。

镜像内仍然保留了 `sudo`，主要是为了兼容一些现成脚本、安装说明和习惯性写法；即使执行了 `sudo <command>`，本质上也还是以 `root` 身份运行。

## 宿主机目录复用

`compose.yaml` 已经配置了以下挂载：

- `${HOME}/.ssh:/root/.ssh:ro`
- `${HOME}/.gitconfig:/root/.gitconfig:ro`
- `${HOME}/.config/gh:/root/.config/gh:ro`
- `${HOME}/.codex:/root/.codex`
- `${HOME}/.claude:/root/.claude`

其中 `ssh` 和 `gitconfig` 为只读，其余目录读写复用，便于在容器内延续宿主机上的登录状态、配置和运行数据。

## SSH 访问

镜像内已启用 `sshd`，Compose 默认把宿主机 `8022` 映射到容器 `22`：

- `8022:22`

容器仅允许基于公钥的 `root` 登录，不启用密码登录，并复用宿主机挂载进容器的 `~/.ssh`。确保宿主机的 `~/.ssh/authorized_keys` 已包含你要使用的公钥后，可以这样连接：

```bash
ssh -p 8022 root@localhost
```

如果使用 `docker compose run`，要带上 `--service-ports`，否则不会发布 `8022` 端口。

### Ghostty

镜像内已预装 `xterm-ghostty` terminfo。使用 Ghostty 通过 SSH 进入容器时，可以保留默认的 `TERM=xterm-ghostty`，`reset`、`tmux`、删除键和方向键等终端行为应能正常工作。

## Codex / Claude

- `codex` 和 `claude` 已预装在镜像中
- 如果 `/root/.codex/config.toml` 不存在，且设置了 `CODEX_MODEL` 或 `CODEX_OPENAI_BASE_URL`，启动脚本会生成一个最小配置
- 如果宿主机目录里已经有这些配置，启动脚本不会覆盖

`.env.example` 里保留了常用变量：

```env
DEV_CONTAINER_IMAGE=ghcr.io/imbingox/dev-container:latest
WORKSPACE_DIR=./workspace
DEV_CONTAINER_LOCAL_IMAGE=dev-container:local

```

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
- 构建完成后自动清理 GHCR，只保留最新 10 个 image version

## 使用建议

- 把仓库名保持为 `dev-container`，这样默认镜像地址和工作流配置更直观
- 如果只想拉 GHCR 上的镜像，执行 `docker compose pull`
- 如果主要在远程机器上用，直接使用默认的 `compose.yaml`
- 如果想验证 Dockerfile 改动，执行 `docker compose -f compose.yaml -f compose.local.yaml build`
