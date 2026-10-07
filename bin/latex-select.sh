#!/usr/bin/env bash

set -euo pipefail

PROJECTS_DIR="$HOME/docker_work/latex/projects"

# ------------------------------------------------------------
# Check dependencies
# ------------------------------------------------------------

command -v fzf >/dev/null 2>&1 || {
    echo "ERROR: fzf が見つかりません。"
    echo
    echo "以下でインストールしてください:"
    echo "  sudo apt install fzf"
    exit 1
}

command -v code >/dev/null 2>&1 || {
    echo "ERROR: VS Code の code コマンドが見つかりません。"
    exit 1
}

[[ -d "$PROJECTS_DIR" ]] || {
    echo "ERROR: Projects directory がありません:"
    echo "  $PROJECTS_DIR"
    exit 1
}

# ------------------------------------------------------------
# Project selection
# ------------------------------------------------------------

PROJECT_NAME=$(
    find "$PROJECTS_DIR" \
        -mindepth 1 \
        -maxdepth 1 \
        -type d \
        -printf '%f\n' \
        | sort \
        | fzf \
            --prompt="LaTeX project > " \
            --height=50% \
            --layout=reverse \
            --border \
            --info=inline
)

# ESC / Ctrl-C でキャンセルした場合
if [[ -z "${PROJECT_NAME:-}" ]]; then
    echo "Cancelled."
    exit 0
fi

PROJECT_DIR="$PROJECTS_DIR/$PROJECT_NAME"

echo
echo "Selected:"
echo "  $PROJECT_NAME"
echo

cd "$PROJECT_DIR"

# ------------------------------------------------------------
# Git sync
# ------------------------------------------------------------

if [[ -d ".git" ]]; then

    if [[ -n "$(git status --porcelain)" ]]; then

        echo "WARNING: Local changesがあります:"
        echo
        git status --short
        echo

        read -r -p "git pullせずにVS Codeを開きますか？ [y/N]: " ANSWER

        if [[ ! "$ANSWER" =~ ^[Yy]$ ]]; then
            echo "Cancelled."
            exit 0
        fi

    elif git remote get-url origin >/dev/null 2>&1; then

        echo "Updating from remote..."
        git pull --rebase

    else

        echo "Git remoteがないためpullをスキップします。"

    fi

else

    echo "Git repositoryではないためpullをスキップします."

fi

# ------------------------------------------------------------
# VS Code
# ------------------------------------------------------------

echo
echo "Opening VS Code..."

code "$PROJECT_DIR"

echo
echo "VS Codeで:"
echo "  Ctrl + Shift + P"
echo "  -> Dev Containers: Reopen in Container"
echo
echo "Now you can close this terminal."