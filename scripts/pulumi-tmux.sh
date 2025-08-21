#!/bin/sh
# Pulumi tmux session setup for FreeBSD
# Creates an interactive tmux environment for Pulumi operations

SESSION_NAME="pulumi-lab"
PULUMI_DIR="${HOME}/ghq/github.com/aygp-dr/pulumi-lab"

# Check if tmux is installed
if ! command -v tmux >/dev/null 2>&1; then
    echo "tmux is not installed. Install with: pkg install tmux"
    exit 1
fi

# Check if session already exists
if tmux has-session -t ${SESSION_NAME} 2>/dev/null; then
    echo "Session ${SESSION_NAME} already exists. Attaching..."
    tmux attach-session -t ${SESSION_NAME}
    exit 0
fi

echo "Creating new tmux session: ${SESSION_NAME}"

# Create new session with main window
tmux new-session -d -s ${SESSION_NAME} -n main -c "${PULUMI_DIR}"

# Set up environment in main window
tmux send-keys -t ${SESSION_NAME}:main "export PATH=\$HOME/.local/bin:\$PATH" C-m
tmux send-keys -t ${SESSION_NAME}:main "# Pulumi CLI ready - FreeBSD with Linux compatibility" C-m
tmux send-keys -t ${SESSION_NAME}:main "pulumi version" C-m
tmux send-keys -t ${SESSION_NAME}:main "pulumi login --local" C-m

# Create second window for experiments
tmux new-window -t ${SESSION_NAME} -n experiments -c "${PULUMI_DIR}/experiments"
tmux send-keys -t ${SESSION_NAME}:experiments "export PATH=\$HOME/.local/bin:\$PATH" C-m
tmux send-keys -t ${SESSION_NAME}:experiments "ls -la" C-m

# Create third window for LocalStack
tmux new-window -t ${SESSION_NAME} -n localstack -c "${PULUMI_DIR}"
tmux send-keys -t ${SESSION_NAME}:localstack "# LocalStack setup for AWS testing" C-m
tmux send-keys -t ${SESSION_NAME}:localstack "export AWS_ENDPOINT=http://localhost:4566" C-m
tmux send-keys -t ${SESSION_NAME}:localstack "export AWS_ACCESS_KEY_ID=test" C-m
tmux send-keys -t ${SESSION_NAME}:localstack "export AWS_SECRET_ACCESS_KEY=test" C-m
tmux send-keys -t ${SESSION_NAME}:localstack "export AWS_REGION=us-east-1" C-m
tmux send-keys -t ${SESSION_NAME}:localstack "# Run 'gmake localstack-start' to start LocalStack" C-m

# Create fourth window for monitoring
tmux new-window -t ${SESSION_NAME} -n monitor -c "${PULUMI_DIR}"
tmux split-window -h -t ${SESSION_NAME}:monitor

# Left pane: Stack status
tmux send-keys -t ${SESSION_NAME}:monitor.0 "export PATH=\$HOME/.local/bin:\$PATH" C-m
tmux send-keys -t ${SESSION_NAME}:monitor.0 "# Run 'watch -n 2 pulumi stack' to monitor stack" C-m

# Right pane: System monitoring
tmux send-keys -t ${SESSION_NAME}:monitor.1 "# System monitoring" C-m
tmux send-keys -t ${SESSION_NAME}:monitor.1 "top -P" C-m

# Create fifth window for Hy REPL
tmux new-window -t ${SESSION_NAME} -n hy-repl -c "${PULUMI_DIR}"
tmux send-keys -t ${SESSION_NAME}:hy-repl "# Hy REPL for testing" C-m
tmux send-keys -t ${SESSION_NAME}:hy-repl "hy" C-m

# Set default window
tmux select-window -t ${SESSION_NAME}:main

# Display session info
echo ""
echo "tmux session '${SESSION_NAME}' created with windows:"
echo "  main       - Pulumi CLI (main directory)"
echo "  experiments - Experiments directory"
echo "  localstack - LocalStack AWS emulation setup"
echo "  monitor    - Stack and system monitoring (split)"
echo "  hy-repl    - Hy interactive REPL"
echo ""
echo "Useful tmux commands:"
echo "  Ctrl-b c    - Create new window"
echo "  Ctrl-b n/p  - Next/previous window"
echo "  Ctrl-b 0-4  - Switch to window by number"
echo "  Ctrl-b %    - Split pane vertically"
echo "  Ctrl-b \"    - Split pane horizontally"
echo "  Ctrl-b d    - Detach from session"
echo "  Ctrl-b ?    - Show all keybindings"
echo ""

# Attach to session
tmux attach-session -t ${SESSION_NAME}