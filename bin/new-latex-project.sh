#!/usr/bin/env bash

set -euo pipefail


# ============================================================
# Paths
# ============================================================

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LATEX_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

PROJECTS_DIR="$LATEX_ROOT/projects"

DEVCONTAINER_TEMPLATE="$LATEX_ROOT/templates/devcontainer"
GITIGNORE_TEMPLATE="$LATEX_ROOT/templates/gitignore/latex.gitignore"
LATEXMKRC_DIR="$LATEX_ROOT/templates/latexmkrc"


# ============================================================
# Helpers
# ============================================================

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


# ============================================================
# Dependencies
# ============================================================

for command in git docker sed grep cp fzf; do
    if ! command -v "$command" >/dev/null 2>&1; then
        error "'$command' is required."
        exit 1
    fi
done


# ============================================================
# Template checks
# ============================================================

[[ -d "$DEVCONTAINER_TEMPLATE" ]] || {
    error "Dev Container template not found:"
    echo "      $DEVCONTAINER_TEMPLATE"
    exit 1
}

[[ -f "$GITIGNORE_TEMPLATE" ]] || {
    error ".gitignore template not found:"
    echo "      $GITIGNORE_TEMPLATE"
    exit 1
}

for engine in pdflatex lualatex platex uplatex; do
    [[ -f "$LATEXMKRC_DIR/$engine" ]] || {
        error "latexmkrc template not found:"
        echo "      $LATEXMKRC_DIR/$engine"
        exit 1
    }
done

mkdir -p "$PROJECTS_DIR"


# ============================================================
# Select project source
# ============================================================

SOURCE_TYPE="$(
    printf '%s\n' \
        "Clone from Overleaf" \
        "Clone from Git repository" \
        "Create local project" \
    | fzf \
        --prompt="New LaTeX project > " \
        --height=45% \
        --layout=reverse \
        --border \
        --info=hidden
)"

if [[ -z "${SOURCE_TYPE:-}" ]]; then
    echo "Cancelled."
    exit 0
fi


# ============================================================
# Helper: derive repository name
# ============================================================

derive_repo_name() {
    local url="$1"
    local name

    name="${url%/}"
    name="${name##*/}"
    name="${name%.git}"

    # Handles SCP-like SSH URLs:
    # git@github.com:user/repository.git
    name="${name##*:}"

    printf '%s' "$name"
}


# ============================================================
# Create / clone project
# ============================================================

case "$SOURCE_TYPE" in

    "Clone from Overleaf")

        echo
        read -r -p "Overleaf Git URL: " GIT_URL

        if [[ -z "$GIT_URL" ]]; then
            error "Git URL is required."
            exit 1
        fi

        if [[ "$GIT_URL" != *"git.overleaf.com"* ]]; then
            warn "This URL does not look like an Overleaf Git URL."
            read -r -p "Continue anyway? [y/N]: " ANSWER

            if [[ ! "$ANSWER" =~ ^[Yy]$ ]]; then
                exit 0
            fi
        fi

        DEFAULT_NAME="$(derive_repo_name "$GIT_URL")"

        read -r -p "Local project name [$DEFAULT_NAME]: " PROJECT_NAME
        PROJECT_NAME="${PROJECT_NAME:-$DEFAULT_NAME}"

        ;;

    "Clone from Git repository")

        echo
        read -r -p "Git repository URL: " GIT_URL

        if [[ -z "$GIT_URL" ]]; then
            error "Git URL is required."
            exit 1
        fi

        DEFAULT_NAME="$(derive_repo_name "$GIT_URL")"

        read -r -p "Local project name [$DEFAULT_NAME]: " PROJECT_NAME
        PROJECT_NAME="${PROJECT_NAME:-$DEFAULT_NAME}"

        ;;

    "Create local project")

        echo
        read -r -p "Project name: " PROJECT_NAME

        if [[ -z "$PROJECT_NAME" ]]; then
            error "Project name is required."
            exit 1
        fi

        ;;

esac


# ============================================================
# Validate project name
# ============================================================

if [[ "$PROJECT_NAME" == */* || "$PROJECT_NAME" == "." || "$PROJECT_NAME" == ".." ]]; then
    error "Invalid project name:"
    echo "      $PROJECT_NAME"
    exit 1
fi

PROJECT_DIR="$PROJECTS_DIR/$PROJECT_NAME"

if [[ -e "$PROJECT_DIR" ]]; then
    error "Project already exists:"
    echo "      $PROJECT_DIR"
    exit 1
fi


# ============================================================
# Clone / initialize
# ============================================================

info "Preparing project"

case "$SOURCE_TYPE" in

    "Clone from Overleaf"|"Clone from Git repository")

        git clone "$GIT_URL" "$PROJECT_DIR"
        ok "Repository cloned"

        ;;

    "Create local project")

        mkdir -p "$PROJECT_DIR"

        (
            cd "$PROJECT_DIR"
            git init
        )

        ok "Local Git repository created"

        ;;

esac


# ============================================================
# Dev Container
# ============================================================

info "Configuring Dev Container"

DEVCONTAINER_CREATED=false

if [[ -d "$PROJECT_DIR/.devcontainer" ]]; then

    warn "Project already contains .devcontainer/"
    echo

    read -r -p "Replace it with the environment template? [y/N]: " ANSWER

    if [[ "$ANSWER" =~ ^[Yy]$ ]]; then
        rm -rf "$PROJECT_DIR/.devcontainer"
        cp -a "$DEVCONTAINER_TEMPLATE" "$PROJECT_DIR/.devcontainer"
        DEVCONTAINER_CREATED=true
        ok ".devcontainer replaced"
    else
        ok "Existing .devcontainer kept"
    fi

else

    cp -a "$DEVCONTAINER_TEMPLATE" "$PROJECT_DIR/.devcontainer"
    DEVCONTAINER_CREATED=true
    ok ".devcontainer created"

fi


# ============================================================
# .gitignore
# ============================================================

info "Configuring .gitignore"

PROJECT_GITIGNORE="$PROJECT_DIR/.gitignore"

if [[ ! -f "$PROJECT_GITIGNORE" ]]; then

    cp "$GITIGNORE_TEMPLATE" "$PROJECT_GITIGNORE"
    ok ".gitignore created"

else

    ADDED=false

    while IFS= read -r line || [[ -n "$line" ]]; do

        # Skip empty lines/comments when checking for duplicates.
        if [[ -z "$line" || "$line" == \#* ]]; then
            continue
        fi

        if ! grep -Fxq "$line" "$PROJECT_GITIGNORE"; then

            if [[ "$ADDED" == false ]]; then
                {
                    echo
                    echo "# Added by LaTeX development environment"
                } >> "$PROJECT_GITIGNORE"

                ADDED=true
            fi

            echo "$line" >> "$PROJECT_GITIGNORE"

        fi

    done < "$GITIGNORE_TEMPLATE"

    if [[ "$ADDED" == true ]]; then
        ok "Missing LaTeX ignore rules added"
    else
        ok "Existing .gitignore already contains required rules"
    fi

fi


# ============================================================
# latexmkrc
# ============================================================

info "Checking latexmk configuration"

if [[ -f "$PROJECT_DIR/latexmkrc" && -f "$PROJECT_DIR/.latexmkrc" ]]; then

    warn "Both latexmkrc and .latexmkrc exist."
    echo "      Existing configuration will be preserved."

elif [[ -f "$PROJECT_DIR/latexmkrc" ]]; then

    ok "Existing latexmkrc kept"

elif [[ -f "$PROJECT_DIR/.latexmkrc" ]]; then

    ok "Existing .latexmkrc kept"

else

    ENGINE="$(
        printf '%s\n' \
            "pdfLaTeX" \
            "LuaLaTeX" \
            "upLaTeX" \
            "pLaTeX" \
        | fzf \
            --prompt="LaTeX engine > " \
            --height=45% \
            --layout=reverse \
            --border \
            --info=hidden
    )"

    if [[ -z "${ENGINE:-}" ]]; then
        warn "No LaTeX engine selected."
    else

        case "$ENGINE" in
            "pdfLaTeX")
                TEMPLATE="pdflatex"
                ;;
            "LuaLaTeX")
                TEMPLATE="lualatex"
                ;;
            "upLaTeX")
                TEMPLATE="uplatex"
                ;;
            "pLaTeX")
                TEMPLATE="platex"
                ;;
        esac

        cp "$LATEXMKRC_DIR/$TEMPLATE" "$PROJECT_DIR/latexmkrc"

        ok "latexmkrc created: $ENGINE"

    fi

fi


# ============================================================
# Pin TeX Live Docker image
# ============================================================

DEVCONTAINER_JSON="$PROJECT_DIR/.devcontainer/devcontainer.json"

if [[ -f "$DEVCONTAINER_JSON" ]] \
    && grep -q '"image"[[:space:]]*:[[:space:]]*"texlive/texlive' \
        "$DEVCONTAINER_JSON"; then

    echo
    read -r -p \
        "Pin texlive/texlive Docker image to the current digest? [Y/n]: " \
        ANSWER

    ANSWER="${ANSWER:-Y}"

    if [[ "$ANSWER" =~ ^[Yy]$ ]]; then

        info "Pulling TeX Live Docker image"

        docker pull texlive/texlive:latest

        IMAGE_REF="$(
            docker image inspect texlive/texlive:latest \
                --format '{{index .RepoDigests 0}}'
        )"

        if [[ -z "$IMAGE_REF" || "$IMAGE_REF" != *@sha256:* ]]; then
            warn "Could not determine Docker image digest."
        else

            sed -i -E \
                "s#\"image\"[[:space:]]*:[[:space:]]*\"texlive/texlive(:[^\"]+|@sha256:[^\"]+)\"#\"image\": \"$IMAGE_REF\"#" \
                "$DEVCONTAINER_JSON"

            ok "Pinned:"
            echo "      $IMAGE_REF"

        fi

    fi

fi


# ============================================================
# Summary
# ============================================================

echo
echo "============================================================"
echo " LaTeX project ready"
echo "============================================================"
echo
echo "Project:"
echo "  $PROJECT_DIR"
echo

case "$SOURCE_TYPE" in
    "Clone from Overleaf")
        echo "Canonical Git remote:"
        echo "  Overleaf"
        ;;
    "Clone from Git repository")
        echo "Canonical Git remote:"
        echo "  $(git -C "$PROJECT_DIR" remote get-url origin 2>/dev/null || echo unknown)"
        ;;
    "Create local project")
        echo "Canonical Git remote:"
        echo "  none"
        ;;
esac

echo
echo "No commit or push was performed automatically."
echo


# ============================================================
# Open VS Code
# ============================================================

if command -v code >/dev/null 2>&1; then

    read -r -p "Open this project in VS Code? [Y/n]: " ANSWER
    ANSWER="${ANSWER:-Y}"

    if [[ "$ANSWER" =~ ^[Yy]$ ]]; then

        code "$PROJECT_DIR"

        echo
        echo "VS Codeで:"
        echo "  Ctrl + Shift + P"
        echo "  -> Dev Containers: Reopen in Container"
        echo

    fi

else

    warn "'code' command is not available."
    echo "      Open manually:"
    echo
    echo "        cd \"$PROJECT_DIR\""
    echo "        code ."

fi