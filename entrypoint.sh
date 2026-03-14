#!/bin/bash
set -e

echo "============================================="
echo "  Oompa Loompa"
echo "  Claude Code | Copilot CLI | Codex CLI | Gemini CLI"
echo "============================================="
echo ""

# ---- Parse arguments ----
# Usage:
#   podman run ... oompa-loompa "build a todo app"                  # all authenticated agents
#   podman run ... oompa-loompa claude "build a todo app"           # claude only
#   podman run ... oompa-loompa codex "build a todo app"            # codex only
#   podman run ... oompa-loompa copilot "build a todo app"          # copilot only
#   podman run ... oompa-loompa gemini "build a todo app"           # gemini only
#   podman run ... oompa-loompa                                     # interactive, no prompt

TARGET="all"
PROMPT=""

case "$1" in
    claude|copilot|codex|gemini)
        TARGET="$1"
        shift
        PROMPT="$*"
        ;;
    *)
        PROMPT="$*"
        ;;
esac

# ---- Hydrate auth from env vars (no mounts needed) ----

# Codex: write auth.json from CODEX_AUTH env var (CLI needs the file on disk)
if [ -n "$CODEX_AUTH" ]; then
    mkdir -p ~/.codex
    echo "$CODEX_AUTH" > ~/.codex/auth.json
    chmod 600 ~/.codex/auth.json
    unset CODEX_AUTH
fi

# Copilot: write apps.json from COPILOT_APPS env var (IDE/extension OAuth tokens)
if [ -n "$COPILOT_APPS" ]; then
    mkdir -p ~/.config/github-copilot
    echo "$COPILOT_APPS" > ~/.config/github-copilot/apps.json
    chmod 600 ~/.config/github-copilot/apps.json
    unset COPILOT_APPS
fi

# Gemini: write oauth_creds.json + settings.json from env vars
if [ -n "$GEMINI_OAUTH" ]; then
    mkdir -p ~/.gemini
    echo "$GEMINI_OAUTH" > ~/.gemini/oauth_creds.json
    chmod 600 ~/.gemini/oauth_creds.json
    # settings.json tells the CLI to use oauth-personal auth
    [ ! -f ~/.gemini/settings.json ] && \
        echo '{"security":{"auth":{"selectedType":"oauth-personal"}}}' > ~/.gemini/settings.json
    unset GEMINI_OAUTH
fi
# Ensure ~/.gemini dir exists for projects.json etc.
mkdir -p ~/.gemini

# ---- Git credentials (SSH key + HTTPS tokens) ----

# SSH deploy key: pass a base64-encoded private key via GIT_SSH_KEY
# Generate: ssh-keygen -t ed25519 -f deploy_key -N ""
# Pass:     -e GIT_SSH_KEY="$(base64 < deploy_key)"
if [ -n "$GIT_SSH_KEY" ]; then
    mkdir -p ~/.ssh && chmod 700 ~/.ssh
    echo "$GIT_SSH_KEY" | base64 -d > ~/.ssh/id_ed25519
    chmod 600 ~/.ssh/id_ed25519
    # Generate public key from private key
    ssh-keygen -y -f ~/.ssh/id_ed25519 > ~/.ssh/id_ed25519.pub 2>/dev/null || true
    # Accept host keys automatically (container is ephemeral)
    [ ! -f ~/.ssh/config ] && cat > ~/.ssh/config <<'SSH'
Host *
    StrictHostKeyChecking accept-new
    UserKnownHostsFile ~/.ssh/known_hosts
SSH
    chmod 600 ~/.ssh/config
    unset GIT_SSH_KEY
fi

# HTTPS token auth via git-credential-store
# Supports GitHub, GitLab (configurable URL), and generic git hosts.
# Uses GIT_TOKEN as the credential for all configured hosts.
#
# Env vars:
#   GIT_TOKEN    - personal access token (fine-grained recommended)
#   GITHUB_URL   - GitHub base URL (default: https://github.com)
#   GITLAB_URL   - GitLab base URL (default: https://gitlab.com)
#   GIT_HOST     - additional git host URL (e.g. https://gitea.example.com)
if [ -n "$GIT_TOKEN" ]; then
    CRED_FILE=~/.git-credentials
    : > "$CRED_FILE"
    chmod 600 "$CRED_FILE"

    _github_host=$(echo "${GITHUB_URL:-https://github.com}" | sed 's|https\?://||; s|/.*||')
    echo "https://x-access-token:${GIT_TOKEN}@${_github_host}" >> "$CRED_FILE"

    _gitlab_host=$(echo "${GITLAB_URL:-https://gitlab.com}" | sed 's|https\?://||; s|/.*||')
    echo "https://oauth2:${GIT_TOKEN}@${_gitlab_host}" >> "$CRED_FILE"

    if [ -n "$GIT_HOST" ]; then
        _git_host=$(echo "$GIT_HOST" | sed 's|https\?://||; s|/.*||')
        echo "https://token:${GIT_TOKEN}@${_git_host}" >> "$CRED_FILE"
    fi

    git config --global credential.helper "store --file $CRED_FILE"

    # Export GIT_TOKEN as GITHUB_TOKEN so CLI agents (Claude Code, etc.)
    # recognize that git push credentials are available.
    # Only set if not already provided by the user.
    [ -z "$GITHUB_TOKEN" ] && export GITHUB_TOKEN="$GIT_TOKEN"

    unset GIT_TOKEN _github_host _gitlab_host _git_host
fi

# Git user identity (optional, for commits)
[ -n "$GIT_USER_NAME" ] && git config --global user.name "$GIT_USER_NAME"
[ -n "$GIT_USER_EMAIL" ] && git config --global user.email "$GIT_USER_EMAIL"
git config --global --add safe.directory /workspace

# ---- Pre-configure trust & onboarding (skip interactive prompts) ----
# Only write defaults when no user-provided config exists (preserves mounts).

# Claude Code: skip first-run theme picker
if [ ! -f ~/.claude.json ]; then
    echo '{"hasCompletedOnboarding":true}' > ~/.claude.json
fi

# Copilot: pre-trust /workspace
mkdir -p ~/.copilot
if [ ! -f ~/.copilot/config.json ]; then
    echo '{"trusted_folders":["/workspace"]}' > ~/.copilot/config.json
elif ! grep -q '"/workspace"' ~/.copilot/config.json 2>/dev/null; then
    # Merge /workspace into existing trusted_folders using jq if available
    if command -v jq &>/dev/null; then
        tmp=$(jq '.trusted_folders = (.trusted_folders // []) + ["/workspace"] | .trusted_folders |= unique' ~/.copilot/config.json)
        echo "$tmp" > ~/.copilot/config.json
    fi
fi

# Codex: pre-trust /workspace and set default model to skip interactive prompts
mkdir -p ~/.codex
if [ ! -f ~/.codex/config.toml ] || ! grep -q 'projects."/workspace"' ~/.codex/config.toml 2>/dev/null; then
    cat >> ~/.codex/config.toml <<'TOML'
model = "gpt-5.4"

[projects."/workspace"]
trust_level = "trusted"
TOML
fi

# Gemini: pre-trust /workspace
mkdir -p ~/.gemini
if [ ! -f ~/.gemini/trustedFolders.json ]; then
    echo '{"/workspace":"TRUST_FOLDER"}' > ~/.gemini/trustedFolders.json
elif ! grep -q '"/workspace"' ~/.gemini/trustedFolders.json 2>/dev/null; then
    if command -v jq &>/dev/null; then
        tmp=$(jq '. + {"/workspace":"TRUST_FOLDER"}' ~/.gemini/trustedFolders.json)
        echo "$tmp" > ~/.gemini/trustedFolders.json
    fi
fi

# Claude Code: optionally init git in /workspace to skip workspace trust prompt
# (the trust prompt only appears in non-git directories — known Claude Code bug)
if [ "$INIT_GIT" = "true" ] && [ ! -d /workspace/.git ]; then
    git init -q /workspace 2>/dev/null || true
fi

# ---- Clean stale state (needed when relaunching a committed image) ----
sudo rm -f /var/run/supervisord.pid
sudo rm -f /tmp/.X1-lock
sudo rm -rf /tmp/.X11-unix/X1

# Start supervisor (Xvfb + Fluxbox + VNC + noVNC) as root via sudo
echo "[*] Starting desktop environment..."
sudo mkdir -p /var/log/supervisor
sudo --preserve-env=DISPLAY,RESOLUTION,VNC_PORT,NOVNC_PORT \
  /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf &

# Wait for display to be ready
sleep 2
echo "[*] Desktop ready"
echo "    http://localhost:6080/vnc.html"
echo ""

# ---- Auth detection ----
CLAUDE_AUTH=false
COPILOT_AUTH_OK=false
CODEX_AUTH_OK=false
GEMINI_AUTH_OK=false

if [ -n "$ANTHROPIC_API_KEY" ] || [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ] || [ -f ~/.claude/.credentials.json ] 2>/dev/null; then
    CLAUDE_AUTH=true
fi

if gh auth status &>/dev/null || [ -n "$COPILOT_GITHUB_TOKEN" ] || [ -n "$GH_TOKEN" ] || [ -n "$GITHUB_TOKEN" ]; then
    COPILOT_AUTH_OK=true
fi

if [ -f ~/.codex/auth.json ] 2>/dev/null || [ -n "$OPENAI_API_KEY" ]; then
    CODEX_AUTH_OK=true
fi

if [ -n "$GEMINI_API_KEY" ] || [ -n "$GOOGLE_API_KEY" ] || [ -f ~/.gemini/oauth_creds.json ] 2>/dev/null; then
    GEMINI_AUTH_OK=true
fi

# ---- Launch agents in background sessions (yolo/autonomous mode) ----
echo "[*] Launching agents..."

if [ -n "$PROMPT" ]; then
    echo "    Prompt: $PROMPT"
fi
if [ "$TARGET" != "all" ]; then
    echo "    Target: $TARGET"
fi
if [ -n "$MODEL" ]; then
    echo "    Model:  $MODEL"
fi
echo ""

# Internal: tmux sessions keep agents alive and shareable across connections.
# Users never need to interact with tmux directly.
tmux new-session -d -s shell -c /workspace 2>/dev/null || true

# -- Claude Code: --dangerously-skip-permissions (yolo mode) --
CLAUDE_LAUNCHED=false
tmux new-session -d -s claude -c /workspace 2>/dev/null || true
if [ "$CLAUDE_AUTH" = true ] && [ "$TARGET" = "all" -o "$TARGET" = "claude" ]; then
    CLAUDE_CMD="claude --dangerously-skip-permissions"
    if [ -n "$MODEL" ]; then
        CLAUDE_CMD="$CLAUDE_CMD --model $(printf '%q' "$MODEL")"
    fi
    if [ -n "$PROMPT" ]; then
        CLAUDE_CMD="$CLAUDE_CMD -p $(printf '%q' "$PROMPT")"
    fi
    tmux send-keys -t claude "$CLAUDE_CMD" Enter
    # Auto-accept startup prompts (Claude Code bug #28506:
    # --dangerously-skip-permissions doesn't bypass trust/confirm prompts).
    # Prompt 1: "trust this folder" (Enter — default is "Yes, I trust")
    # Prompt 2: "bypass permissions" (Down to select "Yes", then Enter)
    (sleep 5 && tmux send-keys -t claude Enter \
     && sleep 4 && tmux send-keys -t claude Down \
     && sleep 1 && tmux send-keys -t claude Enter) &
    CLAUDE_LAUNCHED=true
    echo "    Claude Code:   running"
elif [ "$TARGET" = "claude" ] && [ "$CLAUDE_AUTH" = false ]; then
    echo "    Claude Code:   ERROR - not authenticated"
else
    echo "    Claude Code:   skipped"
fi

# -- Copilot CLI: --allow-all --no-ask-user (yolo mode) --
COPILOT_LAUNCHED=false
tmux new-session -d -s copilot -c /workspace 2>/dev/null || true
if [ "$COPILOT_AUTH_OK" = true ] && [ "$TARGET" = "all" -o "$TARGET" = "copilot" ]; then
    COPILOT_CMD="copilot --allow-all --no-ask-user"
    if [ -n "$MODEL" ]; then
        COPILOT_CMD="$COPILOT_CMD --model $(printf '%q' "$MODEL")"
    fi
    if [ -n "$PROMPT" ]; then
        COPILOT_CMD="$COPILOT_CMD -p $(printf '%q' "$PROMPT")"
    fi
    tmux send-keys -t copilot "$COPILOT_CMD" Enter
    COPILOT_LAUNCHED=true
    echo "    Copilot CLI:   running"
elif [ "$TARGET" = "copilot" ] && [ "$COPILOT_AUTH_OK" = false ]; then
    echo "    Copilot CLI:   ERROR - not authenticated"
else
    echo "    Copilot CLI:   skipped"
fi

# -- Codex CLI: --dangerously-bypass-approvals-and-sandbox (yolo mode) --
CODEX_LAUNCHED=false
tmux new-session -d -s codex -c /workspace 2>/dev/null || true
if [ "$CODEX_AUTH_OK" = true ] && [ "$TARGET" = "all" -o "$TARGET" = "codex" ]; then
    CODEX_CMD="codex --dangerously-bypass-approvals-and-sandbox"
    if [ -n "$MODEL" ]; then
        CODEX_CMD="$CODEX_CMD --model $(printf '%q' "$MODEL")"
    fi
    if [ -n "$PROMPT" ]; then
        CODEX_CMD="$CODEX_CMD $(printf '%q' "$PROMPT")"
    fi
    tmux send-keys -t codex "$CODEX_CMD" Enter
    CODEX_LAUNCHED=true
    echo "    Codex CLI:     running"
elif [ "$TARGET" = "codex" ] && [ "$CODEX_AUTH_OK" = false ]; then
    echo "    Codex CLI:     ERROR - not authenticated"
else
    echo "    Codex CLI:     skipped"
fi

# -- Gemini CLI: --yolo (yolo mode) --
GEMINI_LAUNCHED=false
tmux new-session -d -s gemini -c /workspace 2>/dev/null || true
if [ "$GEMINI_AUTH_OK" = true ] && [ "$TARGET" = "all" -o "$TARGET" = "gemini" ]; then
    GEMINI_CMD="gemini --yolo"
    if [ -n "$MODEL" ]; then
        GEMINI_CMD="$GEMINI_CMD --model $(printf '%q' "$MODEL")"
    fi
    if [ -n "$PROMPT" ]; then
        GEMINI_CMD="$GEMINI_CMD -p $(printf '%q' "$PROMPT")"
    fi
    tmux send-keys -t gemini "$GEMINI_CMD" Enter
    GEMINI_LAUNCHED=true
    echo "    Gemini CLI:    running"
elif [ "$TARGET" = "gemini" ] && [ "$GEMINI_AUTH_OK" = false ]; then
    echo "    Gemini CLI:    ERROR - not authenticated"
else
    echo "    Gemini CLI:    skipped"
fi

echo ""
echo "[*] Ready."
echo ""

# ---- Determine which session to attach to ----
ATTACH_TO=""
if [ "$TARGET" != "all" ]; then
    # User specified a target -- attach to that one
    ATTACH_TO="$TARGET"
elif [ "$CLAUDE_LAUNCHED" = true ]; then
    ATTACH_TO="claude"
elif [ "$COPILOT_LAUNCHED" = true ]; then
    ATTACH_TO="copilot"
elif [ "$CODEX_LAUNCHED" = true ]; then
    ATTACH_TO="codex"
elif [ "$GEMINI_LAUNCHED" = true ]; then
    ATTACH_TO="gemini"
fi

# If TTY is attached, connect to the agent
if [ -t 0 ]; then
    if [ -n "$ATTACH_TO" ]; then
        exec tmux a -t "$ATTACH_TO"
    else
        exec bash
    fi
else
    # Keep container alive
    wait
fi
