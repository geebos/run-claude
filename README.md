# Claude Code Docker

基于 Docker 的 Claude Code 开发环境，在容器中运行 Claude Code CLI，隔离环境、统一配置。

## 项目作用

- **环境隔离**：Claude Code 及所有工具链（Node.js、pnpm、ripgrep、fd 等）运行在 Docker 容器内，不污染宿主机
- **统一配置**：通过 `.env` 文件管理 API token、模型配置等，团队成员共享一致的运行环境
- **数据持久化**：Docker Volume 保存 Claude 配置、node_modules、pnpm store 等，重启容器不丢失数据
- **Skills 同步**：自动将宿主机 `~/.claude/skills` 同步到容器内
- **一条命令启动**：安装后只需在项目目录下执行 `run-claude` 即可进入 Claude Code 会话

## 原理

`run-claude` 本质是执行一条 `docker run` 命令：

```
项目目录  ──bind mount──▶ 容器内 /workspace
Docker Volume ─────────▶ 容器内 /workspace/node_modules、.next 等
Docker Volume ─────────▶ 容器内 /home/node/.claude（Claude 配置持久化）
.env 文件 ─────────────▶ 容器内环境变量（API token、模型配置）
~/.claude/skills ──────▶ 容器内 skills 目录（rsync 同步）
```

- 项目代码通过 **bind mount** 进入容器，改动实时同步
- node_modules、.next 等巨型目录通过 **Docker Volume** 挂载，避免 bind mount 的性能损耗，同时跨容器复用
- Claude 的登录态、设置等保存在 Volume 中，容器销毁后不丢失
- 每次启动用 `--rm`，容器退出后自动清理，不留残留

## 前置要求

- [Docker](https://docs.docker.com/get-docker/) 已安装并运行

## 安装教程

### 1. 构建 Docker 镜像

```bash
docker build -t claude-code-dev .
```

### 2. 配置环境变量

```bash
cp .env.example .env
```

编辑 `.env` 文件，填写你的 API 配置：

```bash
ANTHROPIC_AUTH_TOKEN=sk-xxx      # 替换为你的 API token
ANTHROPIC_BASE_URL=http://host.docker.internal:9001   # API 地址
ANTHROPIC_MODEL=deepseek-v4-pro[1m]                  # 默认模型
# ... 其他模型配置
```

### 3. 安装 run-claude 命令

```bash
chmod +x run-claude.sh install.sh
./install.sh
```

`install.sh` 会自动：
- 检测当前使用的 shell（zsh / bash）
- 将 `alias run-claude` 写入对应的 rc 文件（`~/.zshrc` 或 `~/.bashrc`）
- 立即 source rc 文件使 alias 生效

### 4. 使用

在任意项目目录下运行：

```bash
run-claude
```

脚本会将当前目录挂载到容器的 `/workspace`，启动 Claude Code 交互会话。

## 文件说明

| 文件 | 作用 |
|------|------|
| `Dockerfile` | Docker 镜像定义，包含 Node.js 22、pnpm、Claude Code CLI、CodeGraph 等 |
| `run-claude.sh` | 启动容器并运行 Claude Code 的主脚本 |
| `install.sh` | 安装脚本，将 `run-claude` alias 写入 shell 配置文件 |
| `.env.example` | 环境变量模板，复制为 `.env` 后填写实际配置 |
| `.gitignore` | Git 忽略规则 |

## 自定义

### Skills

将你的 Claude Code skills 放到 `~/.claude/skills/` 目录，每次启动时脚本会自动同步到容器内。

### 模型配置

所有 Claude Code 模型均通过 `.env` 配置，支持自定义 API 地址和模型名称。
