#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# Configuration
# ============================================================

BASE_DIR="$HOME/docker_work/latex"
PROJECTS_DIR="$BASE_DIR/projects"
TEMPLATES_DIR="$BASE_DIR/templates"

DEVCONTAINER_TEMPLATE="$TEMPLATES_DIR/devcontainer"
GITIGNORE_TEMPLATE="$TEMPLATES_DIR/gitignore/latex.gitignore"
LATEXMKRC_DIR="$TEMPLATES_DIR/latexmkrc"


# ============================================================
# Utility functions
# ============================================================

die() {
    echo
    echo "ERROR: $*" >&2
    exit 1
}

info() {
    echo
    echo "==> $*"
}

ask_yes_no() {
    local prompt="$1"
    local default="${2:-y}"
    local answer

    if [[ "$default" == "y" ]]; then
        read -r -p "$prompt [Y/n]: " answer
        answer="${answer:-y}"
    else
        read -r -p "$prompt [y/N]: " answer
        answer="${answer:-n}"
    fi

    [[ "$answer" =~ ^[Yy]$ ]]
}


# ============================================================
# Dependency checks
# ============================================================

for cmd in git docker sed grep cp; do
    command -v "$cmd" >/dev/null 2>&1 \
        || die "'$cmd' が見つかりません。"
done

[[ -d "$DEVCONTAINER_TEMPLATE" ]] \
    || die "Dev Container template がありません: $DEVCONTAINER_TEMPLATE"

[[ -f "$DEVCONTAINER_TEMPLATE/devcontainer.json" ]] \
    || die "devcontainer.json がありません: $DEVCONTAINER_TEMPLATE/devcontainer.json"

[[ -f "$GITIGNORE_TEMPLATE" ]] \
    || die ".gitignore template がありません: $GITIGNORE_TEMPLATE"

for engine in pdflatex lualatex uplatex platex; do
    [[ -f "$LATEXMKRC_DIR/$engine" ]] \
        || die "latexmkrc template がありません: $LATEXMKRC_DIR/$engine"
done

mkdir -p "$PROJECTS_DIR"


# ============================================================
# Header
# ============================================================

echo
echo "=========================================="
echo " New LaTeX Project Setup"
echo "=========================================="
echo
echo "Projects directory:"
echo "  $PROJECTS_DIR"
echo


# ============================================================
# Project source
# ============================================================

echo "プロジェクトの作成方法を選択してください。"
echo
echo "  1) Overleaf Git から clone"
echo "  2) 新しいローカルプロジェクトを作成"
echo

while true; do
    read -r -p "選択 [1/2]: " source_type

    case "$source_type" in
        1|2)
            break
            ;;
        *)
            echo "1 または 2 を入力してください。"
            ;;
    esac
done


# ============================================================
# Project name
# ============================================================

echo
read -r -p "ローカルのプロジェクト名: " PROJECT_NAME

[[ -n "$PROJECT_NAME" ]] \
    || die "プロジェクト名が空です。"

if [[ "$PROJECT_NAME" == */* ]]; then
    die "プロジェクト名には '/' を使用しないでください。"
fi

PROJECT_DIR="$PROJECTS_DIR/$PROJECT_NAME"

[[ ! -e "$PROJECT_DIR" ]] \
    || die "既に存在します: $PROJECT_DIR"


# ============================================================
# Clone / initialize
# ============================================================

if [[ "$source_type" == "1" ]]; then

    echo
    read -r -p "Overleaf Git URL: " OVERLEAF_URL

    [[ -n "$OVERLEAF_URL" ]] \
        || die "Overleaf Git URL が空です。"

    info "Overleafからcloneします"

    git clone "$OVERLEAF_URL" "$PROJECT_DIR"

else

    info "新しいローカルGit repositoryを作成します"

    mkdir -p "$PROJECT_DIR"

    git -C "$PROJECT_DIR" init -b master
fi

cd "$PROJECT_DIR"


# ============================================================
# Dev Container
# ============================================================

info "Dev Container設定を追加します"

if [[ -e "$PROJECT_DIR/.devcontainer" ]]; then

    echo
    echo "既存の .devcontainer/ を検出しました。"

    if ask_yes_no "テンプレートの .devcontainer/ で置き換えますか？" "n"; then
        rm -rf "$PROJECT_DIR/.devcontainer"
        cp -R "$DEVCONTAINER_TEMPLATE" "$PROJECT_DIR/.devcontainer"
    else
        echo "既存の .devcontainer/ をそのまま使用します。"
    fi

else

    cp -R "$DEVCONTAINER_TEMPLATE" "$PROJECT_DIR/.devcontainer"

fi


# ============================================================
# .gitignore
# ============================================================

info ".gitignoreを設定します"

if [[ ! -f "$PROJECT_DIR/.gitignore" ]]; then

    cp "$GITIGNORE_TEMPLATE" "$PROJECT_DIR/.gitignore"

else

    echo "既存の .gitignore を検出しました。"
    echo "LaTeX用テンプレートの内容を追加します。"

    echo >> "$PROJECT_DIR/.gitignore"
    echo "# --- Local LaTeX environment ---" >> "$PROJECT_DIR/.gitignore"

    while IFS= read -r line || [[ -n "$line" ]]; do

        # Empty lines are harmless but do not need duplicate insertion.
        if [[ -z "$line" ]]; then
            continue
        fi

        if ! grep -Fxq "$line" "$PROJECT_DIR/.gitignore"; then
            echo "$line" >> "$PROJECT_DIR/.gitignore"
        fi

    done < "$GITIGNORE_TEMPLATE"

fi


# ============================================================
# latexmkrc
# ============================================================

echo

HAS_LATEXMKRC=false

if [[ -f "$PROJECT_DIR/latexmkrc" ]]; then
    HAS_LATEXMKRC=true
fi

if [[ -f "$PROJECT_DIR/.latexmkrc" ]]; then
    HAS_LATEXMKRC=true
fi

if [[ "$HAS_LATEXMKRC" == true ]]; then

    echo "既存の latexmkrc を検出しました。"

    if [[ -f "$PROJECT_DIR/latexmkrc" ]]; then
        echo "  - latexmkrc"
    fi

    if [[ -f "$PROJECT_DIR/.latexmkrc" ]]; then
        echo "  - .latexmkrc"
    fi

    if [[ -f "$PROJECT_DIR/latexmkrc" \
       && -f "$PROJECT_DIR/.latexmkrc" ]]; then

        echo
        echo "WARNING:"
        echo "  latexmkrc と .latexmkrc の両方が存在します。"
        echo "  設定競合の可能性があるため確認してください。"

    fi

    echo
    echo "既存のlatexmk設定は変更しません。"

else

    echo "latexmkrc がないため、LaTeXエンジンを選択してください。"
    echo
    echo "  1) pdfLaTeX"
    echo "  2) LuaLaTeX"
    echo "  3) upLaTeX"
    echo "  4) pLaTeX"
    echo

    while true; do

        read -r -p "選択 [1-4]: " engine_choice

        case "$engine_choice" in
            1)
                ENGINE="pdflatex"
                break
                ;;
            2)
                ENGINE="lualatex"
                break
                ;;
            3)
                ENGINE="uplatex"
                break
                ;;
            4)
                ENGINE="platex"
                break
                ;;
            *)
                echo "1〜4を入力してください。"
                ;;
        esac

    done

    cp "$LATEXMKRC_DIR/$ENGINE" "$PROJECT_DIR/latexmkrc"

    echo
    echo "latexmkrcを作成しました:"
    echo "  $ENGINE"

fi


# ============================================================
# TeX Live Docker image pinning
# ============================================================

echo

DEVCONTAINER_JSON="$PROJECT_DIR/.devcontainer/devcontainer.json"

if [[ ! -f "$DEVCONTAINER_JSON" ]]; then
    die "devcontainer.json がありません: $DEVCONTAINER_JSON"
fi

if ask_yes_no "TeX Live Docker imageを現在のdigestに固定しますか？" "y"; then

    info "texlive/texlive:latest を取得します"

    docker pull texlive/texlive:latest

    IMAGE_REF=$(
        docker image inspect texlive/texlive:latest \
            --format '{{index .RepoDigests 0}}'
    )

    [[ -n "$IMAGE_REF" ]] \
        || die "Docker image digestを取得できませんでした。"

    echo
    echo "固定するDocker image:"
    echo "  $IMAGE_REF"

    # Replace:
    #   texlive/texlive:latest
    #   texlive/texlive:<tag>
    #   texlive/texlive@sha256:<digest>
    #
    # with the currently pulled digest.

    sed -i -E \
        "s#\"image\"[[:space:]]*:[[:space:]]*\"texlive/texlive(:[^\"]+|@sha256:[^\"]+)\"#\"image\": \"$IMAGE_REF\"#" \
        "$DEVCONTAINER_JSON"

    if ! grep -Fq "$IMAGE_REF" "$DEVCONTAINER_JSON"; then

        echo
        echo "現在の devcontainer.json:"
        grep '"image"' "$DEVCONTAINER_JSON" || true

        die "devcontainer.json のDocker image書き換えに失敗しました。"

    fi

else

    echo
    echo "Docker imageはテンプレートの設定をそのまま使用します。"

fi


# ============================================================
# Summary
# ============================================================

echo
echo "=========================================="
echo " Setup completed"
echo "=========================================="
echo

echo "Project:"
echo "  $PROJECT_DIR"
echo

echo "Dev Container:"
echo "  $PROJECT_DIR/.devcontainer/devcontainer.json"
echo "  (Git管理対象)"
echo

echo "Docker image:"
grep '"image"' "$DEVCONTAINER_JSON" \
    | sed 's/^[[:space:]]*/  /'
echo

if [[ -f "$PROJECT_DIR/latexmkrc" ]]; then

    echo "latexmkrc:"
    echo "  $PROJECT_DIR/latexmkrc"
    echo

elif [[ -f "$PROJECT_DIR/.latexmkrc" ]]; then

    echo "latexmkrc:"
    echo "  $PROJECT_DIR/.latexmkrc"
    echo

fi

echo "Git status:"
git status --short --branch || true

echo
echo "次の操作:"
echo
echo "  1. VS Codeでプロジェクトを開く"
echo "  2. Dev Containers: Reopen in Container"
echo "  3. LaTeX Workshop または"
echo "     latexmk -outdir=build <main.tex>"
echo "     でコンパイル"
echo "  4. 動作確認後、必要なファイルをcommit/push"
echo


# ============================================================
# Open VS Code
# ============================================================

if command -v code >/dev/null 2>&1; then

    if ask_yes_no "VS Codeでこのプロジェクトを開きますか？" "y"; then

        info "VS Codeを起動します"

        code "$PROJECT_DIR"

    fi

else

    echo "VS Codeの 'code' コマンドが見つからないため、"
    echo "自動起動をスキップします。"

fi