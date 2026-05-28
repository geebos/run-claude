ARG UV_VERSION=latest
FROM ghcr.io/astral-sh/uv:${UV_VERSION} AS uv-bin

FROM node:22-bookworm-slim AS base

ENV DEBIAN_FRONTEND=noninteractive
ENV SHELL=/usr/bin/zsh
ENV PNPM_HOME=/home/node/.local/share/pnpm
ENV NPM_CONFIG_PREFIX=/home/node/.local
ENV COREPACK_HOME=/home/node/.cache/corepack
ENV GOROOT=/usr/local/go
ENV GOPATH=/home/node/go
ENV PATH=${GOROOT}/bin:${GOPATH}/bin:${PNPM_HOME}:/home/node/.local/bin:${PATH}

# 安装系统依赖。
# 新增 apt 软件依赖时加到这个列表里，避免重复 apt-get update。
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    fd-find \
    git \
    gnupg \
    htop \
    jq \
    less \
    nano \
    openssh-client \
    procps \
    python3 \
    python3-pip \
    python3-venv \
    ripgrep \
    rsync \
    sudo \
    tar \
    tree \
    tzdata \
    unzip \
    vim-tiny \
    wget \
    xz-utils \
    zip \
    zsh \
  && rm -rf /var/lib/apt/lists/*

# 设置时区为 Asia/Shanghai
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 安装 Go（官方 tarball，版本比 apt 新）
ARG GO_VERSION=1.26.0
RUN ARCH=$(dpkg --print-architecture) \
  && case "$ARCH" in \
       amd64) GOARCH=amd64 ;; \
       arm64) GOARCH=arm64 ;; \
       *)     echo "unsupported arch: $ARCH"; exit 1 ;; \
     esac \
  && curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${GOARCH}.tar.gz" -o /tmp/go.tar.gz \
  && tar -C /usr/local -xzf /tmp/go.tar.gz \
  && rm /tmp/go.tar.gz

# 让 node 用户可以 sudo；不想要 sudo 的话可以删掉 sudo 包和这两行
RUN echo "node ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/node \
  && chmod 0440 /etc/sudoers.d/node \
  && chsh -s /usr/bin/zsh node

# 安装 uv/uvx（官方镜像里提供静态二进制）
COPY --from=uv-bin /uv /uvx /usr/local/bin/

# Debian 里的 fd 命令叫 fdfind，补一个 fd 软链接
RUN ln -sf /usr/bin/fdfind /usr/local/bin/fd

RUN mkdir -p \
    /home/node/.cache/corepack \
    /home/node/.claude \
    /home/node/.local/bin \
    /home/node/.local/share/pnpm \
    /home/node/go \
  && chown -R node:node /home/node

FROM base AS runtime

USER node
WORKDIR /workspace

# 启用 Corepack，并安装 pnpm
RUN corepack enable --install-directory /home/node/.local/bin \
  && corepack prepare pnpm@latest --activate

# 安装 Claude Code
RUN npm install -g @anthropic-ai/claude-code
RUN npm i -g @colbymchenry/codegraph

USER root

COPY docker-entrypoint.sh /usr/local/bin/claude-entrypoint
RUN chmod 0755 /usr/local/bin/claude-entrypoint

USER node

ENTRYPOINT ["/usr/local/bin/claude-entrypoint"]
CMD ["zsh"]
