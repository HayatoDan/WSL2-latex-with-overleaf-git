#!/usr/bin/env bash

set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd -- "$(dirname -- "$SCRIPT_PATH")" && pwd)"

# ------------------------------------------------------------
# Check dependencies
# ------------------------------------------------------------

if ! command -v fzf >/dev/null 2>&1; then
    echo "ERROR: fzf が見つかりません。"
    echo
    echo "Run:"
    echo "  ./setup/install-wsl.sh"
    exit 1
fi

# ------------------------------------------------------------
# Menu
# ------------------------------------------------------------

CHOICE="$(
    {
        printf '%s\n' \
            "New project" \
            "Open existing project" \
            "Remove local project"
    } | fzf \
        --prompt="LaTeX > " \
        --height=40% \
        --layout=reverse \
        --border \
        --info=hidden \
        || true
)"

if [[ -z "${CHOICE:-}" ]]; then
    echo "Cancelled."
    exit 0
fi

case "$CHOICE" in
    "New project")
        exec "$SCRIPT_DIR/astex" newproj
        ;;

    "Open existing project")
        exec "$SCRIPT_DIR/astex" list
        ;;

    "Remove local project")
        exec "$SCRIPT_DIR/astex" remove
        ;;

    *)
        echo "ERROR: Unknown selection."
        exit 1
        ;;
esac
