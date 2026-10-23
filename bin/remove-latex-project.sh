#!/usr/bin/env bash

set -euo pipefail

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd -- "$(dirname -- "$SCRIPT_PATH")" && pwd)"
LATEX_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
PROJECTS_DIR="$LATEX_ROOT/projects"

error() {
    printf 'ERROR: %s\n' "$1" >&2
    exit 1
}

[[ $# -le 1 ]] || error "Usage: astex remove [name]"

# Do not follow a projects/ symlink to directories outside this environment.
[[ ! -L "$PROJECTS_DIR" ]] || error "projects/ がシンボリックリンクのため削除できません。"

if [[ ! -d "$PROJECTS_DIR" ]]; then
    echo "ローカルプロジェクトはありません。"
    exit 0
fi

if [[ $# -eq 1 ]]; then
    PROJECT_NAME="$1"
else
    mapfile -d '' -t PROJECTS < <(
        find "$PROJECTS_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\0' | sort -z
    )

    if [[ ${#PROJECTS[@]} -eq 0 ]]; then
        echo "ローカルプロジェクトはありません。"
        exit 0
    fi

    command -v fzf >/dev/null 2>&1 || error "fzf が見つかりません。setup/install-wsl.sh を実行してください。"

    mapfile -d '' -t SELECTED < <(
        printf '%s\0' "${PROJECTS[@]}" | fzf \
            --read0 --print0 \
            --prompt="Remove LaTeX project > " \
            --height=50% --layout=reverse --border --info=inline || true
    )

    if [[ ${#SELECTED[@]} -eq 0 ]]; then
        echo "Cancelled."
        exit 0
    fi
    PROJECT_NAME="${SELECTED[0]}"
fi

if [[ -z "$PROJECT_NAME" || "$PROJECT_NAME" == */* \
    || "$PROJECT_NAME" == "." || "$PROJECT_NAME" == ".." ]]; then
    error "無効なプロジェクト名です。projects/ 直下の名前を指定してください。"
fi

PROJECT_DIR="$PROJECTS_DIR/$PROJECT_NAME"
[[ ! -L "$PROJECT_DIR" ]] || error "シンボリックリンクは削除対象にできません。"
[[ -d "$PROJECT_DIR" ]] || error "プロジェクトが見つかりません: $PROJECT_NAME"

printf '\n削除対象: %s\n' "$PROJECT_DIR"
echo "未コミットの変更や未 push のコミットを含め、ディレクトリ全体を完全に削除します。"
echo "GitHub・Overleaf などのリモートは変更しません。"

if ! read -r -p "このローカルプロジェクトを削除しますか？ [y/N]: " ANSWER \
    || [[ ! "$ANSWER" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Recheck after confirmation in case the target was replaced while waiting.
[[ ! -L "$PROJECTS_DIR" && ! -L "$PROJECT_DIR" && -d "$PROJECT_DIR" ]] \
    || error "削除対象が変更されました。もう一度実行してください。"
rm -rf -- "$PROJECT_DIR"
printf 'Deleted: %s\n' "$PROJECT_NAME"
