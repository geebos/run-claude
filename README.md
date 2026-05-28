# Claude Code Docker

基于 Docker 的 Claude Code 开发环境，在容器中运行 Claude Code CLI，隔离环境、统一配置。

## 项目作用

- **环境隔离**：Claude Code 及所有工具链（Node.js、pnpm、ripgrep、fd 等）运行在 Docker 容器内，不污染宿主机
- **统一配置**：通过 `.env` 文件管理 API token、模型配置等，团队成员共享一致的运行环境
- **数据持久化**：Docker Volume 保存 Claude 配置，项目依赖和构建产物留在项目目录中
- **Skills 挂载**：将宿主机 `~/.claude/skills` 直接挂载到容器内
- **Plugins 自动安装**：启动时让容器内 Claude CLI 自动安装模板里启用的插件
- **一条命令启动**：安装后只需在项目目录下执行 `run-claude` 即可进入 Claude Code 会话

## 原理

`run-claude` 本质是执行一条 `docker run` 命令：

```
项目目录  ──bind mount──▶ 容器内 /workspace
Docker Volume ─────────▶ 容器内 /home/node/.claude（Claude 配置持久化）
.env 文件 ─────────────▶ 容器内环境变量（API token、模型配置）
~/.claude/skills ──────▶ 容器内 skills 目录（bind mount）
template_claude_settings.json ─▶ 容器内 Claude settings 和插件安装清单
```

- 项目代码通过 **bind mount** 进入容器，改动实时同步
- `node_modules`、`.next`、`.pnpm-store` 等目录不再额外挂 Docker Volume，容器内命令会直接读写 `/workspace` 中的项目文件
- 首次启动某个项目时，会从 `template_claude.json` 复制一份初始 `/home/node/.claude.json`，预设 onboarding 和项目 trust 确认状态
- 容器内首次缺少 `/home/node/.claude/settings.json` 时，会从 `template_claude_settings.json` 初始化主题和危险模式声明确认
- 镜像入口脚本 `docker-entrypoint.sh` 会在容器启动时读取 `template_claude_settings.json` 中启用的插件，并通过 `claude plugin marketplace add` / `claude plugin install --scope user` 安装到 Docker Volume
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

脚本会将当前目录挂载到容器的 `/workspace`，启动 Claude Code 交互会话，并默认暴露宿主机 `3000` 到容器 `3000`。

常用选项：

```bash
run-claude -p 3001  # 将宿主机 3001 映射到容器 3000
run-claude -n       # 不绑定宿主机端口
run-claude -a       # 进入当前项目已运行的开发容器 /workspace
```

`-n` 和 `-p` 不能同时使用；如果禁用端口绑定，容器里的 dev 服务不会暴露到宿主机。

`-a` 会根据当前项目目录定位同一个运行中的开发容器；如果容器不存在或未运行，会直接报错。

需要启动项目 dev 服务时，先在一个终端运行 `run-claude` 保持容器运行，再在另一个终端执行：

```bash
run-claude -a
pnpm dev
```

然后通过宿主机访问 `http://localhost:3000`。如果你的 dev server 默认只监听容器内 localhost，需要让它监听 `0.0.0.0`，例如 `pnpm dev -- --host 0.0.0.0`。

## 文件说明

| 文件 | 作用 |
|------|------|
| `Dockerfile` | Docker 镜像定义，包含 Node.js 22、pnpm、Claude Code CLI、CodeGraph 等 |
| `docker-entrypoint.sh` | 容器启动入口，负责初始化 Claude settings、补装插件、配置 git identity |
| `run-claude.sh` | 启动容器并运行 Claude Code 的主脚本 |
| `template_claude.json` | 新项目首次启动时复制到 `.cache/.claude_<项目hash>.json` 的 Claude 状态模板 |
| `template_claude_settings.json` | 容器内 Claude settings 缺失时复制到 `/home/node/.claude/settings.json` 的偏好模板 |
| `install.sh` | 安装脚本，将 `run-claude` alias 写入 shell 配置文件 |
| `.env.example` | 环境变量模板，复制为 `.env` 后填写实际配置 |
| `.gitignore` | Git 忽略规则 |

## 自定义

### Skills

宿主机 `~/.claude/skills/` 会直接挂载到容器的 `/home/node/.claude/skills/`，容器内 Claude Code 读取和写入的 skills 文件会和宿主机保持一致。

### Plugins

插件不再从宿主机 `~/.claude/plugins/` 挂载。需要默认安装的插件写在 `template_claude_settings.json` 的 `enabledPlugins` 中；容器启动时会让 Claude Code 自己安装，并保存在项目对应的 Docker Volume 里。

### 模型配置

所有 Claude Code 模型均通过 `.env` 配置，支持自定义 API 地址和模型名称。
