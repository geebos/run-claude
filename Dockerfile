FROM node:22-bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV SHELL=/usr/bin/zsh
ENV PNPM_HOME=/home/node/.local/share/pnpm
ENV PATH=${PNPM_HOME}:/home/node/.local/bin:${PATH}

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
    go \
  && rm -rf /var/lib/apt/lists/*

# Debian 里的 fd 命令叫 fdfind，补一个 fd 软链接
RUN ln -sf /usr/bin/fdfind /usr/local/bin/fd

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
    /home/node/.claude

CMD ["zsh"]