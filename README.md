# Oompa Loompa

> Oompa Loompa, do-ba-dee-doo. Put four AI agents in a container for you. Claude, Copilot, Codex, Gemini too -- they'll code your app while you go get food.

**Included agents:** Claude Code, GitHub Copilot CLI, OpenAI Codex CLI, Google Gemini CLI
**Desktop:** Fluxbox + noVNC (access via browser) + Chromium + Firefox
**Runtime:** Podman (rootless)

---

## Quick Start

### 1. Build

```bash
podman build -t oompa-loompa -f Containerfile .
```

### 2. Run (interactive)

```bash
podman run -it --rm \
  -p 6080:6080 \
  -p 5900:5900 \
  -p 3000:3000 \
  # Workspace - mount current directory
  -v "$(pwd)":/workspace \
  # Claude Code - OAuth token (from: claude setup-token)
  -e CLAUDE_CODE_OAUTH_TOKEN="sk-..." \
  # Copilot CLI - apps.json with extension OAuth tokens
  -v ~/.config/github-copilot:/home/dev/.config/github-copilot:ro \
  # Codex CLI - auth.json with ChatGPT session
  -v ~/.codex:/home/dev/.codex:ro \
  # Gemini CLI - OAuth credentials
  -v ~/.gemini:/home/dev/.gemini:ro \
  oompa-loompa
```

Then open **http://localhost:6080/vnc.html** in your browser to access the full desktop.
See the [Authentication](#authentication) section for all auth options (env vars, mounts, or interactive login).

### 3. Run with a prompt (non-interactive)

Pass a prompt as the command argument to run all authenticated agents in autonomous mode:

```bash
# Run all authenticated agents with a prompt
podman run -it --rm \
  -e ANTHROPIC_API_KEY="..." \
  -e OPENAI_API_KEY="..." \
  oompa-loompa "build a todo app in React"

# Target a specific agent
podman run -it --rm -e ANTHROPIC_API_KEY="..." oompa-loompa claude "build a todo app"
podman run -it --rm -e GITHUB_TOKEN="..." oompa-loompa copilot "build a todo app"
podman run -it --rm -e OPENAI_API_KEY="..." oompa-loompa codex "build a todo app"
podman run -it --rm -e GEMINI_API_KEY="..." oompa-loompa gemini "build a todo app"
```

The first argument selects the agent (`claude`, `copilot`, `codex`, `gemini`). Everything after is the prompt. If no agent is specified, all authenticated agents run in parallel.

### 4. Run with podman-compose

```bash
podman-compose up -d
podman-compose exec agent bash
```

---

## Authentication

Each agent uses your own subscription. You can either pass env vars at launch or authenticate interactively inside the container.

### Claude Code

On macOS and Windows, Claude Code stores OAuth tokens in the system credential store (Keychain / Credential Manager), not on disk. Use `setup-token` to extract a portable token.

| Platform | Config dir | Credential store |
|----------|-----------|-----------------|
| macOS | `~/.claude/` | Keychain |
| Linux | `~/.claude/` | `~/.claude/.credentials.json` (plaintext) |
| Windows | `%USERPROFILE%\.claude\` | Windows Credential Manager |

**Option A - OAuth token (recommended, no mount):**
```bash
# On host (any platform), run once:
claude setup-token
# Copy the sk-* token it outputs

# Pass to container:
podman run -it --rm -e CLAUDE_CODE_OAUTH_TOKEN="sk-..." ... oompa-loompa
```

**Option B - API key (uses API credits, not subscription):**
```bash
podman run -it --rm -e ANTHROPIC_API_KEY="sk-ant-..." ... oompa-loompa
```

**Option C - Mount (Linux hosts where ~/.claude/.credentials.json exists):**
```bash
podman run -it --rm -v ~/.claude:/home/dev/.claude:ro ... oompa-loompa
```

**Option D - Interactive (inside container):**
```bash
claude
# Follow the browser-based auth flow
```

Requires a Claude Pro ($20/mo) or higher plan.

### GitHub Copilot CLI

On macOS and Windows, `gh` stores tokens in the system credential store. Use `gh auth token` to extract.

| Platform | gh config | Copilot config | Credential store |
|----------|----------|---------------|-----------------|
| macOS | `~/.config/gh/` | `~/.config/github-copilot/` | Keychain |
| Linux | `~/.config/gh/` | `~/.config/github-copilot/` | plaintext `hosts.yml` |
| Windows | `%APPDATA%\GitHub CLI\` | `%LOCALAPPDATA%\github-copilot\` | Windows Credential Manager |

**Option A - Token env var (recommended, no mount):**
```bash
# On host (any platform):
gh auth token
# Copy the token it outputs

# Pass to container (checked in order: COPILOT_GITHUB_TOKEN > GH_TOKEN > GITHUB_TOKEN):
podman run -it --rm -e COPILOT_GITHUB_TOKEN="gho_..." ... oompa-loompa
```

**Option B - Pass `apps.json` (Copilot extension OAuth, no mount):**
```bash
# Linux/macOS:
podman run -it --rm \
  -e COPILOT_APPS="$(cat ~/.config/github-copilot/apps.json)" \
  ... oompa-loompa

# Windows (PowerShell):
# podman run -it --rm -e COPILOT_APPS="$(Get-Content $env:LOCALAPPDATA\github-copilot\apps.json)" ... oompa-loompa
```
The entrypoint writes it to `~/.config/github-copilot/apps.json` inside the container, then unsets the var.

**Option C - Mount (Linux hosts with plaintext token storage):**
```bash
podman run -it --rm \
  -v ~/.config/gh:/home/dev/.config/gh:ro \
  -v ~/.copilot:/home/dev/.copilot:ro \
  ... oompa-loompa
```

**Option D - Interactive (inside container):**
```bash
gh auth login
# Follow the device code flow
copilot
```

Requires an active GitHub Copilot subscription (Free, Pro, Pro+, Business, or Enterprise).

### OpenAI Codex CLI

Codex stores OAuth tokens in plaintext on all platforms.

| Platform | Config dir |
|----------|-----------|
| macOS / Linux | `~/.codex/` |
| Windows | `%USERPROFILE%\.codex\` |

**Option A - Pass `auth.json` as env var (recommended, no mount):**
```bash
# Linux/macOS:
podman run -it --rm -e CODEX_AUTH="$(cat ~/.codex/auth.json)" ... oompa-loompa

# Windows (PowerShell):
# podman run -it --rm -e CODEX_AUTH="$(Get-Content $env:USERPROFILE\.codex\auth.json)" ... oompa-loompa
```
The entrypoint writes it to `~/.codex/auth.json` inside the container, then unsets the var.
This uses your ChatGPT subscription (Plus/Pro/Team/Enterprise).

**Option B - API key (uses API credits, not ChatGPT subscription):**
```bash
podman run -it --rm -e OPENAI_API_KEY="sk-..." ... oompa-loompa
```

**Option C - Mount:**
```bash
podman run -it --rm -v ~/.codex:/home/dev/.codex:ro ... oompa-loompa
```

**Option D - Interactive (inside container):**
```bash
codex
# Select "Sign in with ChatGPT" and follow the flow
```

Requires a ChatGPT Plus, Pro, Team, Edu, or Enterprise plan.

### Google Gemini CLI

Gemini supports API key or OAuth authentication.

| Platform | Config dir |
|----------|-----------|
| macOS / Linux | `~/.gemini/` |
| Windows | `%USERPROFILE%\.gemini\` |

**Option A - API key (recommended):**
```bash
# From Google AI Studio (https://aistudio.google.com/apikey)
podman run -it --rm -e GEMINI_API_KEY="AIza..." ... oompa-loompa
# or:
podman run -it --rm -e GOOGLE_API_KEY="AIza..." ... oompa-loompa
```

**Option B - OAuth credentials (uses your Google account):**
```bash
# Linux/macOS:
podman run -it --rm \
  -e GEMINI_OAUTH="$(cat ~/.gemini/oauth_creds.json)" \
  ... oompa-loompa

# Windows (PowerShell):
# podman run -it --rm -e GEMINI_OAUTH="$(Get-Content $env:USERPROFILE\.gemini\oauth_creds.json)" ... oompa-loompa
```
The entrypoint writes `oauth_creds.json` and `settings.json` inside the container, then unsets the var.

**Option C - Mount:**
```bash
podman run -it --rm -v ~/.gemini:/home/dev/.gemini:ro ... oompa-loompa
```

**Option D - Interactive (inside container):**
```bash
gemini
# Follow the browser-based auth flow
```

Requires a Google AI Studio API key or a Google account with Gemini access.

---

## Git Access

Give agents access to clone, pull, and push to your repositories. Use fine-grained tokens with minimal permissions.

### Option 1 - SSH deploy key

Generate a per-repo deploy key and pass it base64-encoded:

```bash
# Generate (once):
ssh-keygen -t ed25519 -f deploy_key -N ""
# Add deploy_key.pub to your repo's deploy keys (GitHub/GitLab settings)

# Pass to container:
podman run -it --rm \
  -e GIT_SSH_KEY="$(base64 < deploy_key)" \
  ... oompa-loompa
```

The entrypoint writes it to `~/.ssh/id_ed25519`, generates the public key, and configures SSH to auto-accept new host keys (the container is ephemeral). Deploy keys are scoped to a single repo -- enable write access only if needed.

### Option 2 - HTTPS token (fine-grained PAT)

Pass a personal access token via `GIT_TOKEN`. The entrypoint configures `git-credential-store` for GitHub and GitLab automatically.

```bash
# GitHub only:
podman run -it --rm \
  -e GIT_TOKEN="github_pat_..." \
  ... oompa-loompa

# GitHub + GitLab:
podman run -it --rm \
  -e GIT_TOKEN="glpat-..." \
  -e GITLAB_URL="https://gitlab.example.com" \
  ... oompa-loompa

# GitHub + GitLab + custom host:
podman run -it --rm \
  -e GIT_TOKEN="token_..." \
  -e GIT_HOST="https://gitea.example.com" \
  ... oompa-loompa
```

The token is stored in `~/.git-credentials` (mode 600) and used transparently by git. The env var is unset after setup.

**Creating fine-grained tokens:**

| Platform | Where | Recommended scopes |
|----------|-------|--------------------|
| GitHub | Settings > Developer settings > Fine-grained tokens | `Contents: Read & Write`, `Pull requests: Read & Write` -- scope to specific repos |
| GitLab | Settings > Access Tokens | `read_repository`, `write_repository` -- scope to specific project(s), set expiry |

### Git identity (optional)

Set author name and email for commits made inside the container:

```bash
podman run -it --rm \
  -e GIT_USER_NAME="Your Name" \
  -e GIT_USER_EMAIL="you@example.com" \
  ... oompa-loompa
```

### Defaults

| Variable | Default |
|----------|---------|
| `GITHUB_URL` | `https://github.com` |
| `GITLAB_URL` | `https://gitlab.com` |
| `GIT_HOST` | *(none -- only added if set)* |

Override `GITHUB_URL` or `GITLAB_URL` for GitHub Enterprise or self-hosted GitLab.

---

## Desktop Access

| Method | URL / Address |
|--------|---------------|
| noVNC (browser) | `http://localhost:6080/vnc.html` |
| VNC client | `localhost:5900` |

The desktop uses Fluxbox. Right-click anywhere for a menu with:
- Agent launchers (Claude, Copilot, Codex, Gemini)
- Browsers (Chromium, Firefox)
- Terminals

---

## Connecting from the Host

You can attach to any agent's tmux session from the host without using the VNC desktop:

```bash
podman exec -it oompa-loompa tmux a -t claude    # Claude Code
podman exec -it oompa-loompa tmux a -t copilot   # Copilot CLI
podman exec -it oompa-loompa tmux a -t codex     # Codex CLI
podman exec -it oompa-loompa tmux a -t gemini    # Gemini CLI
podman exec -it oompa-loompa tmux a -t shell     # Plain shell
```

Detach with `Ctrl+B D`. The agent continues running in the background.

---

## Environment Variables

| Variable | Description |
|----------|-------------|
| `ANTHROPIC_API_KEY` | Claude Code API key |
| `CLAUDE_CODE_OAUTH_TOKEN` | Claude Code OAuth token (from `claude setup-token`) |
| `COPILOT_GITHUB_TOKEN` | GitHub token for Copilot CLI |
| `COPILOT_APPS` | Content of `~/.config/github-copilot/apps.json` |
| `GITHUB_TOKEN` | GitHub token (fallback for Copilot) |
| `CODEX_AUTH` | Content of `~/.codex/auth.json` |
| `OPENAI_API_KEY` | OpenAI API key for Codex |
| `GEMINI_API_KEY` | Google AI Studio API key |
| `GOOGLE_API_KEY` | Google API key (alternative for Gemini) |
| `GEMINI_OAUTH` | Content of `~/.gemini/oauth_creds.json` |
| `MODEL` | Override the model for whichever agent is launched |
| `GIT_SSH_KEY` | Base64-encoded SSH deploy key |
| `GIT_TOKEN` | HTTPS personal access token for git operations |
| `GITHUB_URL` | GitHub base URL (default `https://github.com`) |
| `GITLAB_URL` | GitLab base URL (default `https://gitlab.com`) |
| `GIT_HOST` | Additional git host URL (e.g. `https://gitea.example.com`) |
| `GIT_USER_NAME` | Git commit author name |
| `GIT_USER_EMAIL` | Git commit author email |
| `INIT_GIT` | Set to `true` to `git init` /workspace (skips Claude trust prompt) |
| `RESOLUTION` | Desktop resolution (default `1920x1080x24`) |

---

## Agent Autonomous Modes

When a prompt is passed, agents are launched in fully autonomous mode automatically. You can also invoke them manually:

```bash
# Claude Code - skip all permission prompts
claude --dangerously-skip-permissions

# Copilot CLI - allow all tools, no confirmation
copilot --allow-all --no-ask-user

# Codex CLI - bypass all approvals and sandboxing
codex --dangerously-bypass-approvals-and-sandbox

# Gemini CLI - auto-approve all tool calls
gemini --yolo
```

---

## Running Multiple Instances

### Method 1: podman-compose scale
```bash
podman-compose up -d --scale agent=3
```
Note: with scaling, only the first instance gets mapped ports. For independent port access, use method 2.

### Method 2: Named instances (recommended)

Uncomment the second service in `podman-compose.yml`, or run manually:

```bash
# Instance 1
podman run -d --name oompa-loompa-1 -p 6080:6080 -p 5900:5900 -p 3000:3000 oompa-loompa

# Instance 2
podman run -d --name oompa-loompa-2 -p 6081:6080 -p 5901:5900 -p 3010:3000 oompa-loompa

# Instance 3
podman run -d --name oompa-loompa-3 -p 6082:6080 -p 5902:5900 -p 3020:3000 oompa-loompa
```

Then access each desktop at:
- Instance 1: `http://localhost:6080/vnc.html`
- Instance 2: `http://localhost:6081/vnc.html`
- Instance 3: `http://localhost:6082/vnc.html`

---

## Snapshotting an Authenticated Image

Authenticate once interactively, then commit the container as a new image so you never have to log in again:

```bash
# 1. Start a container (without --rm so it persists)
podman run -it --name oompa-setup -p 6080:6080 oompa-loompa

# 2. Inside the container, authenticate each agent:
claude          # follow browser auth flow
gh auth login   # follow device code flow
codex           # sign in with ChatGPT
gemini          # follow browser auth flow

# 3. Exit the container (Ctrl+D or `exit`)

# 4. Commit the authenticated container as a new image
podman commit oompa-setup oompa-loompa-auth

# 5. Clean up the setup container
podman rm oompa-setup

# 6. Launch from the pre-authenticated image
podman run -it --rm -p 6080:6080 -p 3000:3000 oompa-loompa-auth
```

The desktop environment (Xvfb, Fluxbox, VNC, noVNC) starts fresh on every launch -- the entrypoint cleans stale PID files and X11 locks before starting supervisord, so committed images relaunch cleanly.

**Note:** OAuth tokens expire. Claude Code tokens need refreshing every ~6 hours (use `claude setup-token` for a long-lived token instead). Codex refreshes tokens automatically during active sessions. If a snapshot's tokens expire, just re-authenticate and commit again, or switch to env-var-based auth.

**Note:** If you mount your own home folder configs (e.g., `-v ~/.claude:/home/dev/.claude`), the entrypoint will not overwrite existing config files. Your mounts take precedence.

---

## Project Structure

```
oompa-loompa/
  Containerfile          # Image definition
  supervisord.conf       # Process manager (Xvfb, VNC, noVNC, Fluxbox)
  entrypoint.sh          # Container entrypoint (auth, trust, agent launch)
  agent-select.sh        # Interactive agent picker
  fluxbox-menu           # Desktop right-click menu
  fluxbox-init           # Fluxbox window manager config
  podman-compose.yml     # Multi-instance orchestration
  workspace/             # Mounted into /workspace in the container
```

---

## Customization

**Resolution:** Set `RESOLUTION` env var (default `1920x1080x24`)
```bash
podman run -it --rm -e RESOLUTION=2560x1440x24 ... oompa-loompa
```

**Model override:** Pass a model name to any agent:
```bash
podman run -it --rm -e MODEL=claude-sonnet-4-20250514 -e ANTHROPIC_API_KEY="..." oompa-loompa claude "hello"
```

**Additional tools:** Add to the Containerfile and rebuild.

**VNC password:** By default there is no VNC password (container-local only). To add one, modify the x11vnc command in `supervisord.conf`:
```
command=x11vnc ... -passwd yourpassword
```
