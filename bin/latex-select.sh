#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
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
    read -r -p "Authenticate with GitHub now? [Y/n]: " answer
    answer="${answer:-Y}"

    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        return 1
    fi

    if gh auth login \
        --hostname github.com \
        --git-protocol https \
        --web; then

        gh auth setup-git --hostname github.com

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

if [[ -d ".git" ]]; then

    if [[ -n "$(git status --porcelain)" ]]; then

        warn "Local changesがあります:"
        echo
        git status --short
        echo

        read -r -p \
            "git pullせずにVS Codeを開きますか？ [y/N]: " \
            ANSWER

        if [[ ! "$ANSWER" =~ ^[Yy]$ ]]; then
            echo "Cancelled."
            exit 0
        fi

    elif git remote get-url origin >/dev/null 2>&1; then

        ORIGIN_URL="$(git remote get-url origin)"

        # GitHub HTTPS repositories use gh as credential helper.
        if [[ "$ORIGIN_URL" == "$GITHUB_HTTPS_PREFIX"* ]]; then

            if ! ensure_github_auth; then

                echo
                read -r -p \
                    "Continue with git pull using existing Git credentials? [y/N]: " \
                    ANSWER

                if [[ ! "$ANSWER" =~ ^[Yy]$ ]]; then
                    echo "Cancelled."
                    exit 0
                fi

            fi

        fi

        info "Updating from origin"

        if git pull --rebase; then
            ok "Repository updated"
        else
            error "git pull --rebase failed."
            exit 1
        fi

    else

        info "Git remote is not configured"
        echo "    pull skipped"

    fi

else

    info "Not a Git repository"
    echo "    pull skipped"

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