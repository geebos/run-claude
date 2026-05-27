FROM node:22-bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV SHELL=/usr/bin/zsh
ENV PNPM_HOME=/home/node/.local/share/pnpm
ENV GOROOT=/usr/local/go
ENV GOPATH=/home/node/go
ENV PATH=${GOROOT}/bin:${GOPATH}/bin:${PNPM_HOME}:/home/node/.local/bin:${PATH}

# 安装基础工具
RUN apt-get update && apt-get install -y --no-install-recommends \
    zsh \
    git \
    curl \
    wget \
    ca-certificates \
    gnupg \
    jq \
    ripgrep \
    fd-find \
    less \
    nano \
    vim-tiny \
    unzip \
    zip \
    tar \
    xz-utils \
    procps \
    htop \
    tree \
    openssh-client \
    build-essential \
    python3 \
    python3-pip \
    python3-venv \
    sudo \
    rsync \
    tzdata \
  && rm -rf /var/lib/apt/lists/*

# 设置时区为 Asia/Shanghai
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Debian 里的 fd 命令叫 fdfind，补一个 fd 软链接
RUN ln -sf /usr/bin/fdfind /usr/local/bin/fd

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

# 启用 Corepack，并安装 pnpm
RUN corepack enable \
  && corepack prepare pnpm@latest --activate

# 安装 Claude Code
RUN npm install -g @anthropic-ai/claude-code
RUN npm i -g @colbymchenry/codegraph

USER node
WORKDIR /workspace

RUN mkdir -p \
    /home/node/.local/bin \
    /home/node/.local/share/pnpm \
    /home/node/.claude \
    /home/node/go

CMD ["zsh"]