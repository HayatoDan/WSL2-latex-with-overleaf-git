#!/usr/bin/env bash

set -euo pipefail


# ============================================================
# LaTeX development environment setup for WSL
# ============================================================


# ------------------------------------------------------------
# Paths
# ------------------------------------------------------------

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd -- "$(dirname -- "$SCRIPT_PATH")" && pwd)"
LATEX_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

BIN_DIR="$LATEX_ROOT/bin"
PROJECTS_DIR="$LATEX_ROOT/projects"

USER_BIN="$HOME/bin"
BASHRC="$HOME/.bashrc"

GH_CLI_BASE="https:"'//cli.github.com/packages'


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
    "bin/latex-menu.sh"
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

    if [[ ! -f "$LATEX_ROOT/$file" ]]; then

        error "Missing required file:"
        echo "      $LATEX_ROOT/$file"
        exit 1

    fi

done

ok "Repository structure looks good"
echo "      $LATEX_ROOT"


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
        echo "This installer assumes that Docker and Git"
        echo "are already installed in WSL."
        exit 1

    fi

done


# ------------------------------------------------------------
# fzf
# ------------------------------------------------------------

info "Checking fzf"

if command -v fzf >/dev/null 2>&1; then

    ok "fzf"

else

    warn "fzf is not installed."
    echo
    echo "texmenu / texproj / texnew require fzf."
    echo

    read -r -p \
        "Install fzf using apt? [Y/n]: " \
        ANSWER

    ANSWER="${ANSWER:-Y}"

    if [[ "$ANSWER" =~ ^[Yy]$ ]]; then

        sudo apt-get update
        sudo apt-get install -y fzf

        ok "fzf installed"

    else

        warn "fzf installation skipped."
        echo "      The LaTeX launcher will not work without fzf."

    fi

fi


# ------------------------------------------------------------
# GitHub CLI installation
# ------------------------------------------------------------

info "Checking GitHub CLI"

if command -v gh >/dev/null 2>&1; then

    GH_VERSION="$(gh --version | head -n 1)"
    ok "$GH_VERSION"

else

    warn "GitHub CLI (gh) is not installed."
    echo
    echo "Private GitHub repositories are expected to be common"
    echo "in this environment."
    echo

    read -r -p \
        "Install GitHub CLI from the official repository? [Y/n]: " \
        ANSWER

    ANSWER="${ANSWER:-Y}"

    if [[ "$ANSWER" =~ ^[Yy]$ ]]; then

        info "Installing GitHub CLI"

        if ! command -v wget >/dev/null 2>&1; then
            sudo apt-get update
            sudo apt-get install -y wget ca-certificates
        fi

        sudo mkdir -p -m 755 /etc/apt/keyrings

        TEMP_KEY="$(mktemp)"

        wget \
            -nv \
            -O "$TEMP_KEY" \
            "$GH_CLI_BASE/githubcli-archive-keyring.gpg"

        sudo install \
            -m 0644 \
            "$TEMP_KEY" \
            /etc/apt/keyrings/githubcli-archive-keyring.gpg

        rm -f "$TEMP_KEY"

        sudo mkdir -p -m 755 /etc/apt/sources.list.d

        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] $GH_CLI_BASE stable main" \
            | sudo tee \
                /etc/apt/sources.list.d/github-cli.list \
                >/dev/null

        sudo apt-get update
        sudo apt-get install -y gh

        ok "GitHub CLI installed"

    else

        warn "GitHub CLI installation skipped."

    fi

fi


# ------------------------------------------------------------
# GitHub authentication
# ------------------------------------------------------------

if command -v gh >/dev/null 2>&1; then

    info "Checking GitHub authentication"

    if gh auth status \
        --hostname github.com \
        >/dev/null 2>&1; then

        ok "Authenticated with GitHub"

        if gh auth setup-git \
            --hostname github.com \
            >/dev/null 2>&1; then

            ok "GitHub CLI configured as Git credential helper"

        else

            warn "Could not configure GitHub credential helper."

        fi

    else

        warn "GitHub authentication is not configured."
        echo

        read -r -p \
            "Authenticate with GitHub now? [Y/n]: " \
            ANSWER

        ANSWER="${ANSWER:-Y}"

        if [[ "$ANSWER" =~ ^[Yy]$ ]]; then

            echo
            echo "A browser-based GitHub login will start."
            echo

            if gh auth login \
                --hostname github.com \
                --git-protocol https \
                --web; then

                ok "GitHub authentication completed"

                if gh auth setup-git \
                    --hostname github.com; then

                    ok "GitHub CLI configured as Git credential helper"

                else

                    warn "Could not configure Git credential helper."

                fi

            else

                warn "GitHub authentication failed."
                echo "      You can retry later with:"
                echo
                echo "        gh auth login"

            fi

        else

            warn "GitHub authentication skipped."

        fi

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

chmod +x "$BIN_DIR/latex-menu.sh"
chmod +x "$BIN_DIR/latex-select.sh"
chmod +x "$BIN_DIR/new-latex-project.sh"

ok "latex-menu.sh"
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

    local current_target
    local source_target
    local answer

    if [[ -L "$target" ]]; then

        current_target="$(readlink -f "$target" || true)"
        source_target="$(readlink -f "$source")"

        if [[ "$current_target" == "$source_target" ]]; then

            ok "$name already configured"
            return

        fi

        warn "$target already points somewhere else:"
        echo "      -> $(readlink "$target")"
        echo

        read -r -p "Replace it? [y/N]: " answer

        if [[ "$answer" =~ ^[Yy]$ ]]; then

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
    "$BIN_DIR/latex-menu.sh" \
    "$USER_BIN/texmenu" \
    "texmenu"

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

if grep -Fq "$BEGIN_MARKER" "$BASHRC"; then

    ok "~/bin PATH configuration already exists"

else

    cat >> "$BASHRC" <<'EOF'

# >>> latex-dev environment >>>
# Commands installed by the LaTeX development environment
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


# Make commands available immediately.
case ":$PATH:" in
    *":$HOME/bin:"*) ;;
    *) export PATH="$HOME/bin:$PATH" ;;
esac


# ------------------------------------------------------------
# Git identity
# ------------------------------------------------------------

info "Checking Git identity"

GIT_NAME="$(
    git config --global --get user.name \
        || true
)"

GIT_EMAIL="$(
    git config --global --get user.email \
        || true
)"


if [[ -n "$GIT_NAME" ]]; then

    ok "user.name  = $GIT_NAME"

else

    warn "Git user.name is not configured."

    read -r -p \
        "Git user.name (leave empty to skip): " \
        VALUE

    if [[ -n "$VALUE" ]]; then

        git config \
            --global \
            user.name \
            "$VALUE"

        ok "user.name configured"

    fi

fi


if [[ -n "$GIT_EMAIL" ]]; then

    ok "user.email = $GIT_EMAIL"

else

    warn "Git user.email is not configured."

    read -r -p \
        "Git user.email (leave empty to skip): " \
        VALUE

    if [[ -n "$VALUE" ]]; then

        git config \
            --global \
            user.email \
            "$VALUE"

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

            sudo usermod \
                -aG docker \
                "$USER"

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
    echo "      texproj / texnew use:"
    echo
    echo "        code <project>"
    echo
    echo "      VS Code installation is outside the scope"
    echo "      of this installer."

fi


# ------------------------------------------------------------
# Parent repository .gitignore
# ------------------------------------------------------------

info "Checking projects/ Git exclusion"

if [[ -f "$LATEX_ROOT/.gitignore" ]] \
    && grep -Eq \
        '^/projects/?$' \
        "$LATEX_ROOT/.gitignore"; then

    ok "projects/ is excluded from this repository"

else

    warn "Parent .gitignore does not contain:"
    echo
    echo "        /projects/"
    echo
    echo "      Add this rule so project repositories are not"
    echo "      tracked by the environment repository."

fi


# ------------------------------------------------------------
# Final command checks
# ------------------------------------------------------------

info "Checking LaTeX environment commands"

for command in texmenu texproj texnew; do

    if command -v "$command" >/dev/null 2>&1; then
        ok "$command"
    else
        warn "$command is not currently available"
    fi

done


# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------

echo
echo "============================================================"
echo " LaTeX environment setup complete"
echo "============================================================"
echo
echo "Environment repository:"
echo "  $LATEX_ROOT"
echo
echo "Projects:"
echo "  $PROJECTS_DIR"
echo
echo "Commands:"
echo "  texmenu    LaTeX project launcher"
echo "  texproj    Select and open an existing project"
echo "  texnew     Create or clone a new project"
echo
echo "Reload the shell configuration with:"
echo
echo "  source ~/.bashrc"
echo
echo "Then:"
echo
echo "  texmenu"
echo