# LaTeX Development Environment

WSL2 + Docker + VS Code + Git を用いた LaTeX 執筆環境。

各 LaTeX プロジェクトを Docker Dev Container 内で開くことで、ホスト側の TeX 環境に依存せず、再現可能な LaTeX 環境を構築する。

GitHub 等の通常の Git repository、および Overleaf Git の双方に対応する。

## 基本方針

各 LaTeX プロジェクトでは、原則として **canonical Git remote を1つだけ持つ**。

- Overleaf を中心に共同執筆する場合：Overleaf Git を `origin` とする
- GitHub を中心に管理する場合：GitHub を `origin` とする
- GitHub と Overleaf の双方を利用する場合：GitHub を `origin` とし、Overleaf 側の GitHub Sync を利用する
- ローカルのみの場合：remote なし

ローカル repository から GitHub と Overleaf の双方へ直接 push する二重同期は、通常は行わない。

これにより「どこが最新版か」を分かりやすく保つ。

GitHub repository は private repository を主に想定し、GitHub CLI (`gh`) を利用して HTTPS 認証を行う。

---

## 1. 全体構成

```text
Windows
└── WSL2
    └── Ubuntu
        ├── Git
        ├── GitHub CLI
        ├── Docker Engine
        │
        └── ~/docker_work/
            └── latex/
                ├── bin/
                ├── setup/
                ├── templates/
                └── projects/
                    ├── paper-a/
                    ├── paper-b/
                    └── ...
```

LaTeX のコンパイルは各プロジェクトの Dev Container 内で行う。

```text
WSL2 Ubuntu
    │
    └── Docker Engine
        │
        └── Dev Container
            └── texlive/texlive
```

---

## 2. 前提環境

このリポジトリは、以下がすでに準備されていることを前提とする。

### WSL 側

- WSL2
- Ubuntu
- Git
- Docker Engine
- `~/docker_work/` ディレクトリ

Docker Desktop は使用せず、Docker Engine は WSL2 の Ubuntu 内に直接インストールする。

以下が正常に動作すること。

```bash
git --version
docker --version
docker info
```

### Windows / VS Code 側

VS Code を利用する場合は以下を準備しておく。

- Visual Studio Code
- WSL extension
- Dev Containers extension

WSL ターミナルから、

```bash
code .
```

が動作すること。

VS Code および WSL 自体のインストールは、この repository のセットアップスクリプトでは行わない。

---

## 3. インストール

### 3.1 Environment repository を clone

```bash
cd ~/docker_work
git clone <repository-url> latex
cd latex
```

この環境では repository を、

```text
~/docker_work/latex
```

付近に配置することを想定している。

### 3.2 セットアップ

```bash
./setup/install-wsl.sh
```

実行権限が失われている場合は、

```bash
chmod +x setup/install-wsl.sh
./setup/install-wsl.sh
```

または、

```bash
bash setup/install-wsl.sh
```

で実行できる。

セットアップでは主に以下を行う。

- `projects/` の作成
- `fzf` の確認・必要に応じた導入
- GitHub CLI (`gh`) の確認・必要に応じた導入
- GitHub へのブラウザ認証
- `gh` の Git credential helper 設定
- 各スクリプトへの実行権限設定
- `~/bin/texmenu` の作成
- `~/bin/texproj` の作成
- `~/bin/texnew` の作成
- `~/bin` の PATH 設定
- Git identity の確認
- Docker の利用可否確認
- VS Code の `code` コマンド確認

必要な項目については対話的に設定する。

セットアップスクリプトは複数回実行しても問題ないように設計している。

実行後：

```bash
source ~/.bashrc
```

確認：

```bash
which texmenu
which texproj
which texnew
```

---

## 4. GitHub 認証

GitHub repository は private repository を主に想定する。

セットアップ時に GitHub CLI が存在しなければ、導入するか確認される。

その後、

```text
GitHub CLI
    ↓
browser authentication
    ↓
HTTPS Git
    ↓
GitHub CLI credential helper
```

という構成を作る。

認証状態は、

```bash
gh auth status
```

で確認できる。

認証をやり直す場合：

```bash
gh auth login
```

Git credential helper を再設定する場合：

```bash
gh auth setup-git
```

この環境では GitHub の Git protocol として HTTPS を標準とする。

新しく GitHub repository を clone するときに SSH形式のURLを入力した場合、GitHub CLI認証が利用可能であれば HTTPS URL に変換して clone する。

既存 repository が SSH remote を利用している場合は、自動的には変更しない。

---

## 5. ディレクトリ構成

```text
latex/
├── .gitignore
├── README.md
│
├── bin/
│   ├── latex-menu.sh
│   ├── latex-select.sh
│   └── new-latex-project.sh
│
├── setup/
│   └── install-wsl.sh
│
├── templates/
│   ├── devcontainer/
│   │   └── devcontainer.json
│   ├── gitignore/
│   │   └── latex.gitignore
│   └── latexmkrc/
│       ├── pdflatex
│       ├── lualatex
│       ├── platex
│       └── uplatex
│
└── projects/
    ├── project-a/
    ├── project-b/
    └── ...
```

---

## 6. Git 管理方針

この repository は **LaTeX 開発環境そのもの**を管理する。

`projects/` 以下に置く各論文・プロジェクトは、この repository では管理しない。

親 repository の `.gitignore`：

```gitignore
/projects/
```

例えば、

```text
~/docker_work/latex/.git
```

と、

```text
~/docker_work/latex/projects/paper-a/.git
```

は独立した Git repository となる。

確認：

```bash
git check-ignore -v projects/
```

---

## 7. Launcher

通常の入口は、

```bash
texmenu
```

である。

実行すると、

```text
New project
Open existing project
```

から選択できる。

```text
texmenu
   │
   ├── New project
   │       ↓
   │     texnew
   │
   └── Open existing project
           ↓
         texproj
```

`texnew` と `texproj` を直接実行することもできる。

---

## 8. 新しいプロジェクト

```bash
texnew
```

を実行すると、

```text
Clone from Overleaf
Clone from Git repository
Create local project
```

から選択する。

### 8.1 Clone from Overleaf

Overleaf の Git URL を入力する。

この場合、

```text
origin = Overleaf
```

となり、Overleaf を canonical remote とする。

```text
Local
  ↕
Overleaf
```

Overleaf Git の認証には Overleaf の Git authentication token を使用する。

### 8.2 Clone from Git repository

GitHub、GitLab、その他の Git URL を指定する。

GitHub repository が検出された場合は GitHub CLI の認証状態を確認する。

未認証の場合は、その場でブラウザ認証を開始できる。

GitHub を利用する場合：

```text
origin = GitHub
```

GitHub と Overleaf の双方を利用したい場合は、ローカル repository に Overleaf remote を追加するのではなく、Overleaf 側の GitHub Sync を利用する。

```text
        GitHub
       ↗      ↖
   Local     Overleaf
```

これにより GitHub を唯一の canonical Git remote とする。

### 8.3 Create local project

新しい Git repository をローカルに作成する。

```text
origin = none
```

必要になった時点で任意の Git remote を追加する。

---

## 9. 既存プロジェクト

```bash
texproj
```

を実行する。

`fzf` で `projects/` 以下のプロジェクトを検索・選択する。

```text
texproj
   ↓
project 選択
   ↓
git pull --rebase
   ↓
VS Code
```

`texproj` は通常、remote の種類を意識しない。

例えば、

```text
origin = Overleaf
```

なら Overleaf から pull し、

```text
origin = GitHub
```

なら GitHub から pull する。

GitHub HTTPS repository の場合は、pull 前に GitHub CLI の認証状態を確認する。

remote が存在しない場合は pull をスキップする。

ローカルに未コミット変更がある場合も、自動 pull は行わない。

VS Code が開いたら、

```text
Ctrl + Shift + P
→ Dev Containers: Reopen in Container
```

を実行する。

---

## 10. Dev Container

テンプレート：

```text
templates/devcontainer/devcontainer.json
```

基本イメージ：

```text
texlive/texlive:latest
```

新規プロジェクト作成時には必要に応じて、

```text
texlive/texlive@sha256:...
```

の形で Docker image digest を固定する。

各プロジェクトの `.devcontainer/` は Git 管理する。

これにより、別PCでも同じ TeX Live image を利用できる。

既存 repository に `.devcontainer/` がある場合は、原則として既存設定を保持する。

---

## 11. latexmkrc

コンパイラ設定は各プロジェクトの `latexmkrc` を source of truth とする。

既存 repository に、

```text
latexmkrc
```

または、

```text
.latexmkrc
```

が存在する場合は、その設定を保持する。

存在しない場合は、

- pdfLaTeX
- LuaLaTeX
- upLaTeX
- pLaTeX

から選択し、

```text
templates/latexmkrc/
```

のテンプレートをコピーする。

ローカル出力先 `build/` は `latexmkrc` には設定しない。

LaTeX Workshop 側から、

```text
latexmk -outdir=build ...
```

として指定する。

これにより Overleaf 等で利用する `latexmkrc` と、ローカル固有の出力ディレクトリ設定を分離する。

---

## 12. LaTeX Workshop

Dev Container では LaTeX Workshop を使用する。

主な設定：

- 保存時に自動ビルド
- PDF を VS Code タブ内で表示
- 出力先は `build/`
- `latexmk` を利用
- コンパイラは各プロジェクトの `latexmkrc` に委ねる

通常は `.tex` ファイルを保存するだけでコンパイルされる。

---

## 13. Codex

Dev Container 内でも Codex / ChatGPT extension を利用できる。

Codex から、

- `.tex` ファイルの編集
- Git 操作
- `latexmk`
- `uplatex`
- その他の Linux コマンド

を実行できる。

TeX Live や Git は Dev Container 内のものを利用する。

Codex の OAuth ログインに失敗する場合、Tailscale や VPN が原因となる場合があるため、認証時のみ一時的に無効化して確認する。

---

## 14. Windows launcher

Windows のショートカットから直接 launcher を起動できる。

ショートカットのリンク先：

```text
C:\Windows\System32\wsl.exe -d Ubuntu-22.04 -- bash -ic "texmenu; exec bash"
```

Ubuntu の distribution 名は、

```powershell
wsl -l -v
```

で確認できる。

実行すると、

```text
Windows shortcut
      ↓
WSL Ubuntu
      ↓
   texmenu
      ↓
┌───────────────────────┐
│ New project           │
│ Open existing project │
└───────────────────────┘
```

となる。

`exec bash` により launcher 実行後も WSL terminal を残す。

VS Code が開いた後、

```text
Ctrl + Shift + P
→ Dev Containers: Reopen in Container
```

という案内を確認できる。

---

## 15. 日常ワークフロー

### 既存プロジェクト

```text
Windows LaTeX icon
        ↓
Open existing project
        ↓
fzf
        ↓
GitHubの場合は認証確認
        ↓
git pull --rebase
        ↓
VS Code
        ↓
Reopen in Container
        ↓
編集
        ↓
git commit
        ↓
git pull --rebase
        ↓
git push
```

### 新規プロジェクト

```text
Windows LaTeX icon
        ↓
New project
        ↓
┌──────────────────────────┐
│ Overleaf                 │
│ Git repository           │
│ Local repository         │
└──────────────────────────┘
        ↓
必要ならGitHub認証
        ↓
clone / git init
        ↓
Dev Container設定
        ↓
VS Code
```

---

## 16. 新しいPC / WSLへの復元

あらかじめ以下を用意する。

```text
WSL2
Ubuntu
Git
Docker Engine
VS Code
```

WSL 内で：

```bash
mkdir -p ~/docker_work
cd ~/docker_work
```

environment repository を clone：

```bash
git clone <repository-url> latex
cd latex
```

セットアップ：

```bash
./setup/install-wsl.sh
source ~/.bashrc
```

このとき必要に応じて、

```text
fzf
GitHub CLI
GitHub authentication
Git credential helper
texmenu
texproj
texnew
```

まで設定される。

確認：

```bash
texmenu
```

必要な LaTeX project は `texnew` から再度 clone する。

---

## 17. セットアップ状態の確認

### Commands

```bash
which texmenu
which texproj
which texnew
```

### Symlinks

```bash
readlink -f ~/bin/texmenu
readlink -f ~/bin/texproj
readlink -f ~/bin/texnew
```

### GitHub

```bash
gh auth status
```

### Docker

```bash
docker info
```

### Git identity

```bash
git config --global user.name
git config --global user.email
```

### fzf

```bash
fzf --version
```

### projects の Git 除外

```bash
cd ~/docker_work/latex
git check-ignore -v projects/
```

---

## 18. Troubleshooting

### `texmenu`, `texproj`, `texnew`: command not found

```bash
source ~/.bashrc
```

確認：

```bash
which texmenu
which texproj
which texnew
```

### GitHub private repository を clone できない

まず：

```bash
gh auth status
```

未認証なら：

```bash
gh auth login
gh auth setup-git
```

### `fzf: command not found`

setup を再実行する。

```bash
./setup/install-wsl.sh
```

### Docker が sudo なしで利用できない

```bash
sudo usermod -aG docker "$USER"
```

その後 WSL を再起動する。

### VS Code が起動しない

```bash
which code
code .
```

を確認する。

### `Reopen in Container` が表示されない

Windows 側の VS Code に Dev Containers extension がインストールされていることを確認する。

---

## 19. 管理対象

Environment repository で管理するもの：

```text
README.md
.gitignore
bin/
setup/
templates/
```

管理しないもの：

```text
projects/
```

各 project は独立した Git repository とする。

---

## 20. Design Policy

### Environment repository

管理：

- launcher
- project creation scripts
- setup scripts
- Dev Container template
- latexmkrc templates
- `.gitignore` template

### WSL host

担当：

- Git
- GitHub CLI
- Docker Engine
- project storage
- launcher
- VS Code 起動

### Dev Container

担当：

- TeX Live
- latexmk
- LaTeX Workshop
- Codex
- LaTeX compilation

### Project repository

管理：

- `.tex`
- bibliography
- figures
- `latexmkrc`
- `.devcontainer/`
- project-specific configuration

### Canonical remote

原則として各 project は1つの canonical Git remote を持つ。

```text
Overleaf-centric

Local ←→ Overleaf
```

```text
GitHub-centric

Local ←→ GitHub ←→ Overleaf
```

GitHub-centric な project では Overleaf との同期は Overleaf 側の GitHub Sync に任せ、ローカルから GitHub と Overleaf の2箇所へ直接同期する運用は避ける。

これにより、

- PC交換
- WSL再構築
- TeX Live更新
- private GitHub repository の認証
- Overleafとの同期
- プロジェクトごとの再現性

をできるだけ独立して扱えるようにする。