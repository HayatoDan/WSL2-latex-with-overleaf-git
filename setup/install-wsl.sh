#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# LaTeX environment setup for WSL
#
# Assumptions:
#   - WSL2 / Ubuntu are already installed
#   - Docker Engine is already installed in Ubuntu
#   - Git is already installed
#   - This repository has been cloned under:
#
#       ~/docker_work/latex
#
# This script configures only the user-side settings required
# by this LaTeX environment.
#
# Safe to run multiple times.
# ============================================================


# ------------------------------------------------------------
# Paths
# ------------------------------------------------------------

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

BIN_DIR="$REPO_ROOT/bin"
PROJECTS_DIR="$REPO_ROOT/projects"

USER_BIN="$HOME/bin"
BASHRC="$HOME/.bashrc"


# ------------------------------------------------------------
# Output helpers
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
# Repository structure
# ------------------------------------------------------------

info "Checking LaTeX environment repository"

REQUIRED_FILES=(
    "bin/latex-select.sh"
    "bin/new-latex-project.sh"
    "templates/devcontainer/devcontainer.json"
    "templates/gitignore/latex.gitignore"
    "templates/latexmkrc/pdflatex"
    "templates/latexmkrc/lualatex"
    "templates/latexmkrc/platex"
    "templates/latexmkrc/uplatex"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$REPO_ROOT/$file" ]]; then
        error "Missing required file:"
        echo "      $REPO_ROOT/$file"
        exit 1
    fi
done

ok "Repository structure looks good"
echo "      $REPO_ROOT"


# ------------------------------------------------------------
# Required base commands
# ------------------------------------------------------------

info "Checking prerequisites"

for command in git docker; do
    if command -v "$command" >/dev/null 2>&1; then
        ok "$command"
    else
        error "'$command' is not installed."
        echo
        echo "This setup script assumes that Docker and Git"
        echo "are already installed in WSL."
        exit 1
    fi
done


# ------------------------------------------------------------
# fzf
# ------------------------------------------------------------

if command -v fzf >/dev/null 2>&1; then

    ok "fzf"

else

    warn "fzf is not installed."
    echo
    echo "texproj requires fzf for project selection."
    echo

    read -r -p "Install fzf using apt? [Y/n]: " ANSWER
    ANSWER="${ANSWER:-Y}"

    if [[ "$ANSWER" =~ ^[Yy]$ ]]; then

        sudo apt-get update
        sudo apt-get install -y fzf

        ok "fzf installed"

    else

        warn "fzf installation skipped."
        echo "      texproj will not work until fzf is installed."

    fi

fi


# ------------------------------------------------------------
# Project directory
# ------------------------------------------------------------

info "Preparing projects directory"

mkdir -p "$PROJECTS_DIR"

ok "$PROJECTS_DIR"


# ------------------------------------------------------------
# Executable permissions
# ------------------------------------------------------------

info "Preparing scripts"

chmod +x "$BIN_DIR/latex-select.sh"
chmod +x "$BIN_DIR/new-latex-project.sh"

ok "latex-select.sh"
ok "new-latex-project.sh"


# ------------------------------------------------------------
# ~/bin
# ------------------------------------------------------------

info "Preparing user commands"

mkdir -p "$USER_BIN"


create_symlink() {

    local source="$1"
    local target="$2"
    local name="$3"

    if [[ -L "$target" ]]; then

        CURRENT_TARGET="$(readlink -f "$target" || true)"
        SOURCE_TARGET="$(readlink -f "$source")"

        if [[ "$CURRENT_TARGET" == "$SOURCE_TARGET" ]]; then
            ok "$name already configured"
            return
        fi

        warn "$target already points somewhere else:"
        echo "      -> $(readlink "$target")"
        echo

        read -r -p "Replace it? [y/N]: " ANSWER

        if [[ "$ANSWER" =~ ^[Yy]$ ]]; then
            rm "$target"
            ln -s "$source" "$target"
            ok "$name updated"
        else
            warn "$name was not changed"
        fi

        return
    fi


    if [[ -e "$target" ]]; then

        warn "$target already exists and is not a symbolic link."
        echo "      It will not be overwritten automatically."
        return

    fi


    ln -s "$source" "$target"
    ok "$name -> $source"
}


create_symlink \
    "$BIN_DIR/latex-select.sh" \
    "$USER_BIN/texproj" \
    "texproj"

create_symlink \
    "$BIN_DIR/new-latex-project.sh" \
    "$USER_BIN/texnew" \
    "texnew"


# ------------------------------------------------------------
# PATH configuration
# ------------------------------------------------------------

info "Checking ~/.bashrc"

touch "$BASHRC"

BEGIN_MARKER="# >>> latex-dev environment >>>"
END_MARKER="# <<< latex-dev environment <<<"

if grep -Fq "$BEGIN_MARKER" "$BASHRC"; then

    ok "~/bin PATH configuration already exists"

else

    cat >> "$BASHRC" <<'EOF'

# >>> latex-dev environment >>>
# Commands installed by ~/docker_work/latex/setup/install-wsl.sh
if [ -d "$HOME/bin" ]; then
    case ":$PATH:" in
        *":$HOME/bin:"*) ;;
        *) export PATH="$HOME/bin:$PATH" ;;
    esac
fi
# <<< latex-dev environment <<<
EOF

    ok "Added ~/bin to PATH"

fi

# Make it available immediately during this script.
case ":$PATH:" in
    *":$HOME/bin:"*) ;;
    *) export PATH="$HOME/bin:$PATH" ;;
esac


# ------------------------------------------------------------
# Git identity
# ------------------------------------------------------------

info "Checking Git identity"

GIT_NAME="$(git config --global --get user.name || true)"
GIT_EMAIL="$(git config --global --get user.email || true)"


if [[ -n "$GIT_NAME" ]]; then

    ok "user.name  = $GIT_NAME"

else

    warn "Git user.name is not configured."

    read -r -p "Git user.name (leave empty to skip): " VALUE

    if [[ -n "$VALUE" ]]; then
        git config --global user.name "$VALUE"
        ok "user.name configured"
    fi

fi


if [[ -n "$GIT_EMAIL" ]]; then

    ok "user.email = $GIT_EMAIL"

else

    warn "Git user.email is not configured."

    read -r -p "Git user.email (leave empty to skip): " VALUE

    if [[ -n "$VALUE" ]]; then
        git config --global user.email "$VALUE"
        ok "user.email configured"
    fi

fi


# ------------------------------------------------------------
# Docker access
# ------------------------------------------------------------

info "Checking Docker access"

if docker info >/dev/null 2>&1; then

    ok "Docker can be used without sudo"

else

    if sudo docker info >/dev/null 2>&1; then

        warn "Docker currently requires sudo."
        echo

        read -r -p \
            "Add '$USER' to the docker group? [Y/n]: " \
            ANSWER

        ANSWER="${ANSWER:-Y}"

        if [[ "$ANSWER" =~ ^[Yy]$ ]]; then

            if ! getent group docker >/dev/null 2>&1; then
                sudo groupadd docker
            fi

            sudo usermod -aG docker "$USER"

            ok "Added '$USER' to docker group"
            echo
            echo "      Restart WSL before using Docker without sudo."

        fi

    else

        error "Docker daemon is not reachable."
        echo
        echo "Docker is installed, but the daemon does not appear"
        echo "to be running."
        echo
        echo "Check with:"
        echo
        echo "  sudo systemctl status docker"
        echo

    fi

fi


# ------------------------------------------------------------
# VS Code
# ------------------------------------------------------------

info "Checking VS Code integration"

if command -v code >/dev/null 2>&1; then

    ok "'code' command is available"

else

    warn "'code' command is not available in WSL."
    echo
    echo "      texproj uses:"
    echo
    echo "        code <project>"
    echo
    echo "      Make sure VS Code can be launched from WSL."

fi



# ------------------------------------------------------------
# Parent repo .gitignore
# ------------------------------------------------------------

info "Checking projects/ Git exclusion"

if [[ -f "$REPO_ROOT/.gitignore" ]] \
    && grep -Eq '^/projects/?$' "$REPO_ROOT/.gitignore"; then

    ok "projects/ is excluded from this repository"

else

    warn "Parent .gitignore does not appear to contain:"
    echo
    echo "        /projects/"
    echo
    echo "      Add it so individual LaTeX projects are not"
    echo "      tracked by the environment repository."

fi


# ------------------------------------------------------------
# Final checks
# ------------------------------------------------------------

info "Checking commands"

if command -v texproj >/dev/null 2>&1; then
    ok "texproj"
else
    warn "texproj is not currently available"
fi

if command -v texnew >/dev/null 2>&1; then
    ok "texnew"
else
    warn "texnew is not currently available"
fi


# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------

echo
echo "============================================================"
echo " LaTeX environment setup complete"
echo "============================================================"
echo
echo "Environment repository:"
echo
echo "  $REPO_ROOT"
echo
echo "Projects:"
echo
echo "  $PROJECTS_DIR"
echo
echo "Commands:"
echo
echo "  texproj    Select and open an existing project"
echo "  texnew     Create or clone a new project"
echo
echo "Reload the shell configuration with:"
echo
echo "  source ~/.bashrc"
echo
echo "Then:"
echo
echo "  texproj"
echo