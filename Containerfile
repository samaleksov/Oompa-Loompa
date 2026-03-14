# =============================================================================
# Oompa Loompa
# Desktop GUI (noVNC) + Claude Code + Copilot CLI + Codex CLI + Gemini CLI
# =============================================================================
FROM node:22-bookworm

LABEL maintainer="neuromancer"
LABEL description="Oompa Loompa - multi-agent AI coding workstation with desktop GUI"

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1
ENV VNC_PORT=5900
ENV NOVNC_PORT=6080
ENV RESOLUTION=1920x1080x24

# -----------------------------------------------------------------------------
# System dependencies + Desktop environment
# -----------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core tools
    git curl wget jq ripgrep fd-find fzf tmux vim neovim \
    openssh-client gnupg ca-certificates build-essential \
    python3 python3-pip sudo \
    # Virtual display + VNC
    xvfb x11vnc xterm \
    # Lightweight window manager
    fluxbox \
    # noVNC (web-based VNC client)
    novnc websockify \
    # Browsers
    chromium chromium-sandbox \
    firefox-esr \
    # Misc GUI/X11 utilities
    xdg-utils dbus-x11 libnotify-bin \
    # Process manager
    supervisor \
    # For Playwright system deps
    libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 \
    libxkbcommon0 libxcomposite1 libxdamage1 libxrandr2 libgbm1 \
    libpango-1.0-0 libcairo2 libasound2 libatspi2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# GitHub CLI (for `gh copilot`)
# -----------------------------------------------------------------------------
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# -----------------------------------------------------------------------------
# Create non-root user 'dev' with sudo (before CLI installs so we can
# switch to dev for tools that download runtime artifacts)
# -----------------------------------------------------------------------------
RUN useradd -m -s /bin/bash dev \
    && echo "dev ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && mkdir -p /workspace && chown dev:dev /workspace

# -----------------------------------------------------------------------------
# CLI agents (global npm installs — puts binaries on PATH for all users)
# -----------------------------------------------------------------------------
RUN npm install -g \
    @anthropic-ai/claude-code \
    @github/copilot \
    @openai/codex \
    @google/gemini-cli \
    playwright

# -----------------------------------------------------------------------------
# Playwright browsers — installed as dev so they land in ~dev/.cache/
# (agents run as dev; installing as root puts them in /root/.cache which
# is inaccessible and forces agents to re-download at runtime)
# -----------------------------------------------------------------------------
USER dev
RUN npx playwright install chromium
USER root

# -----------------------------------------------------------------------------
# Fluxbox config (dark theme, right-click menu with terminals + browsers)
# -----------------------------------------------------------------------------
RUN mkdir -p /home/dev/.fluxbox && chown -R dev:dev /home/dev/.fluxbox
COPY fluxbox-menu /home/dev/.fluxbox/menu
COPY fluxbox-init /home/dev/.fluxbox/init
RUN chown -R dev:dev /home/dev/.fluxbox

# -----------------------------------------------------------------------------
# Supervisor config + scripts
# -----------------------------------------------------------------------------
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chmod=755 agent-select.sh /usr/local/bin/agent-select

# -----------------------------------------------------------------------------
# Ports: 6080 = noVNC (browser), 5900 = VNC, 3000-3009 = dev servers
# -----------------------------------------------------------------------------
EXPOSE 6080 5900 3000 3001 3002 3003 3004 3005

USER dev
WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD []
