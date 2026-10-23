#!/usr/bin/env bash

set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd -- "$(dirname -- "$SCRIPT_PATH")" && pwd)"
LATEX_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

PROJECTS_DIR="$LATEX_ROOT/projects"

GITHUB_HTTPS_PREFIX="https:"'//github.com/'


# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------

info() {
    printf '\n\033[1;34m==>\033[0m %s\n' "$1"
}

ok() {
    printf '    \033[1;32mOK\033[0m   %s\n' "$1"
}

warn() {
    printf '    \033[1;33mWARN\033[0m %s\n' "$1"
}

error() {
    printf '    \033[1;31mERROR\033[0m %s\n' "$1" >&2
}


# ------------------------------------------------------------
# GitHub authentication
# ------------------------------------------------------------

ensure_github_auth() {

    if ! command -v gh >/dev/null 2>&1; then
        warn "GitHub CLI (gh) is not installed."
        echo
        echo "      GitHub private repositories are easier to use"
        echo "      after running:"
        echo
        echo "        $LATEX_ROOT/setup/install-wsl.sh"
        echo
        return 1
    fi

    if gh auth status --hostname github.com >/dev/null 2>&1; then
        gh auth setup-git --hostname github.com >/dev/null 2>&1 || true
        return 0
    fi

    warn "GitHub authentication is not configured."
    echo

    local answer
    if ! read -r -p "Authenticate with GitHub now? [Y/n]: " answer; then
        return 1
    fi
    answer="${answer:-Y}"

    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        return 1
    fi

    if gh auth login \
        --hostname github.com \
        --git-protocol https \
        --web; then

        if ! gh auth setup-git --hostname github.com; then
            warn "Git credential helper setup failed."
            return 1
        fi

        ok "GitHub authentication configured"
        return 0
    fi

    warn "GitHub authentication failed."
    return 1
}


# ------------------------------------------------------------
# Dependencies
# ------------------------------------------------------------

for command in git fzf code; do
    if ! command -v "$command" >/dev/null 2>&1; then
        error "'$command' is required."
        exit 1
    fi
done


# ------------------------------------------------------------
# Project directory
# ------------------------------------------------------------

if [[ ! -d "$PROJECTS_DIR" ]]; then
    error "Projects directory does not exist:"
    echo "      $PROJECTS_DIR"
    exit 1
fi


# ------------------------------------------------------------
# Select project
# ------------------------------------------------------------

PROJECT_NAME="$(
    {
        find "$PROJECTS_DIR" \
            -mindepth 1 \
            -maxdepth 1 \
            -type d \
            -printf '%f\n' \
            | sort
    } | fzf \
        --prompt="LaTeX project > " \
        --height=50% \
        --layout=reverse \
        --border \
        --info=inline \
        || true
)"

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

sync_project() {
    local status origin_url answer

    if [[ ! -e ".git" ]]; then
        info "Not a Git repository"
        echo "    pull skipped"
        return 0
    fi

    if ! status="$(git status --porcelain)"; then
        warn "Git の状態を取得できないため、自動 pull をスキップします。"
        return 1
    fi

    if [[ -n "$status" ]]; then

        warn "Local changesがあります:"
        echo
        git status --short || true
        echo

        return 1

    elif git remote get-url origin >/dev/null 2>&1; then

        if ! origin_url="$(git remote get-url origin)"; then
            warn "origin の URL を取得できませんでした。"
            return 1
        fi

        # GitHub HTTPS repositories use gh as credential helper.
        if [[ "$origin_url" == "$GITHUB_HTTPS_PREFIX"* ]]; then

            if ! ensure_github_auth; then

                echo
                if ! read -r -p \
                    "Continue with git pull using existing Git credentials? [y/N]: " \
                    answer || [[ ! "$answer" =~ ^[Yy]$ ]]; then
                    return 1
                fi

            fi

        fi

        info "Updating from origin"

        if git pull --rebase; then
            ok "Repository updated"
        else
            warn "git pull --rebase failed."
            echo "    競合などで rebase が途中の場合は、VS Code のターミナルで Git の状態を確認してください。"
            return 1
        fi

    else

        info "Git remote is not configured"
        echo "    pull skipped"

    fi

    return 0
}

if ! sync_project; then
    echo
    if ! read -r -p \
        "同期せずにローカルのプロジェクトを VS Code で開きますか？ [y/N]: " \
        ANSWER || [[ ! "$ANSWER" =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
fi


# ------------------------------------------------------------
# Open VS Code
# ------------------------------------------------------------

echo
echo "Opening VS Code..."

code "$PROJECT_DIR"

echo
echo "VS Codeで:"
echo "  Ctrl + Shift + P"
echo "  -> Dev Containers: Reopen in Container"
echo
echo "準備ができたらこのターミナルは閉じて構いません。"
echo
