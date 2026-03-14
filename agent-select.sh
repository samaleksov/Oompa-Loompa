#!/bin/bash
# Interactive agent selector - launches agents in named tmux sessions

echo ""
echo "  Select an AI agent to launch:"
echo ""
echo "    1) Claude Code       (tmux: claude)"
echo "    2) Copilot CLI       (tmux: copilot)"
echo "    3) OpenAI Codex CLI  (tmux: codex)"
echo "    4) Google Gemini CLI (tmux: gemini)"
echo "    5) Shell             (tmux: shell)"
echo "    6) List tmux sessions"
echo ""
read -rp "  Choice [1-6]: " choice

case "$choice" in
    1|claude)
        echo ""
        echo "  Launching Claude Code in tmux session 'claude'..."
        echo "  Tip: use --dangerously-skip-permissions for yolo mode"
        echo "  Detach: Ctrl+B D  |  Reattach: tmux a -t claude"
        echo ""
        tmux send-keys -t claude 'claude' Enter
        exec tmux a -t claude
        ;;
    2|copilot)
        echo ""
        echo "  Launching Copilot CLI in tmux session 'copilot'..."
        echo "  Detach: Ctrl+B D  |  Reattach: tmux a -t copilot"
        echo ""
        tmux send-keys -t copilot 'copilot' Enter
        exec tmux a -t copilot
        ;;
    3|codex)
        echo ""
        echo "  Launching Codex CLI in tmux session 'codex'..."
        echo "  Tip: use --full-auto for autonomous mode"
        echo "  Detach: Ctrl+B D  |  Reattach: tmux a -t codex"
        echo ""
        tmux send-keys -t codex 'codex' Enter
        exec tmux a -t codex
        ;;
    4|gemini)
        echo ""
        echo "  Launching Gemini CLI in tmux session 'gemini'..."
        echo "  Tip: use --yolo for autonomous mode"
        echo "  Detach: Ctrl+B D  |  Reattach: tmux a -t gemini"
        echo ""
        tmux send-keys -t gemini 'gemini' Enter
        exec tmux a -t gemini
        ;;
    5|shell)
        echo ""
        exec tmux a -t shell
        ;;
    6|list)
        echo ""
        tmux ls
        echo ""
        exec "$0"
        ;;
    *)
        echo "  Invalid choice. Try again."
        exec "$0"
        ;;
esac
