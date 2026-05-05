# syntax=docker/dockerfile:1
FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000

# ── Base system packages ──────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash-completion \
    build-essential \
    ca-certificates \
    curl \
    dnsutils \
    git \
    gnupg \
    iputils-ping \
    jq \
    less \
    lsb-release \
    nano \
    netcat-openbsd \
    software-properties-common \
    sudo \
    unzip \
    vim \
    wget \
    && rm -rf /var/lib/apt/lists/*

# ── Node.js 20 ────────────────────────────────────────────────────────────────
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# ── Python 3 + pip + Ansible ──────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/* \
    && pip3 install --break-system-packages ansible

# ── Terraform ────────────────────────────────────────────────────────────────
# Note: echo "deb ..." is kept on one line intentionally — line continuations
# inside a quoted string add the indentation whitespace to the apt source entry.
RUN wget -qO- https://apt.releases.hashicorp.com/gpg \
    | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list \
    && apt-get update && apt-get install -y terraform \
    && rm -rf /var/lib/apt/lists/*

# ── gcloud CLI ───────────────────────────────────────────────────────────────
RUN curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
    | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee /etc/apt/sources.list.d/google-cloud-sdk.list \
    && apt-get update && apt-get install -y google-cloud-cli \
    && rm -rf /var/lib/apt/lists/*

# ── Docker CLI (no daemon — uses the socket mounted from the OrbStack host) ───
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && chmod a+r /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list \
    && apt-get update && apt-get install -y docker-ce-cli docker-buildx-plugin docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# ── kubectl (v1.31) ──────────────────────────────────────────────────────────
RUN curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key \
    | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list \
    && apt-get update && apt-get install -y kubectl \
    && rm -rf /var/lib/apt/lists/*

# ── Helm (official binary — reliable across networks; avoids baltocdn/apt edge cases)
ARG HELM_VERSION=3.16.3
RUN set -eux; \
    ARCH="$(dpkg --print-architecture)"; \
    case "$ARCH" in \
      amd64) HARCH=amd64 ;; \
      arm64) HARCH=arm64 ;; \
      *) echo "unsupported arch: $ARCH" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-${HARCH}.tar.gz" \
      | tar xz -C /tmp; \
    mv "/tmp/linux-${HARCH}/helm" /usr/local/bin/helm; \
    chmod 0755 /usr/local/bin/helm; \
    rm -rf "/tmp/linux-${HARCH}"

# ── Non-root user ─────────────────────────────────────────────────────────────
# Ubuntu 24.04 images often ship uid/gid 1000 as the default "ubuntu" user; remove
# it so we can create the devcontainer user as vscode:1000:1000.
RUN set -eux; \
    if getent passwd ubuntu >/dev/null; then userdel -r ubuntu; fi; \
    if getent group "$USER_GID" >/dev/null; then \
      gname="$(getent group "$USER_GID" | cut -d: -f1)"; \
      if [ "$gname" != "$USERNAME" ]; then groupdel "$gname"; fi; \
    fi; \
    groupadd --gid "$USER_GID" "$USERNAME" \
    && useradd --uid "$USER_UID" --gid "$USER_GID" -m "$USERNAME" \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$USERNAME" \
    && chmod 0440 "/etc/sudoers.d/$USERNAME"

# Docker socket access — the docker group is created by docker-ce-cli; -f is safe if it exists.
RUN groupadd -f docker && usermod -aG docker "$USERNAME"

# ── Bash completions ──────────────────────────────────────────────────────────
RUN kubectl completion bash > /etc/bash_completion.d/kubectl \
    && helm completion bash > /etc/bash_completion.d/helm \
    && echo 'complete -C /usr/bin/terraform terraform' > /etc/bash_completion.d/terraform \
    && echo 'source /usr/share/bash-completion/bash_completion' >> "/home/$USERNAME/.bashrc"

# ── Custom PS1 (inline — no COPY; works even when .dockerignore excludes dot dirs)
RUN <<'INSTALL_PROMPT'
set -e
install -d /usr/local/share
cat <<'PROMPT' > /usr/local/share/devcontainer-prompt.sh
#!/usr/bin/env bash
# Devcontainer shell prompt.
# Sourced by ~/.bashrc — sets a PS1 of the form:
#   git_repo | git_branch | /current/path $
# Outside a git repo both fields show a dash.

__ps1_repo() {
  local top
  top="$(git rev-parse --show-toplevel 2>/dev/null)" || { printf '-'; return; }
  basename "$top"
}

__ps1_branch() {
  local branch
  branch="$(git branch --show-current 2>/dev/null)"
  if [ -n "$branch" ]; then
    printf '%s' "$branch"
  elif git rev-parse --git-dir >/dev/null 2>&1; then
    # Detached HEAD — show the short SHA instead
    printf '%.7s' "$(git rev-parse HEAD 2>/dev/null)"
  else
    printf '-'
  fi
}

# cyan repo | yellow branch | green path
PS1='\[\e[0;36m\]$(__ps1_repo)\[\e[0m\] | \[\e[0;33m\]$(__ps1_branch)\[\e[0m\] | \[\e[0;32m\]\w\[\e[0m\] \$ '
PROMPT
chmod 0644 /usr/local/share/devcontainer-prompt.sh
INSTALL_PROMPT
RUN echo '. /usr/local/share/devcontainer-prompt.sh' >> "/home/$USERNAME/.bashrc"

USER $USERNAME
WORKDIR /workspace
