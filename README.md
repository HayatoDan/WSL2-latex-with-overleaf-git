# LaTeX Development Environment

WSL2 + Docker + VS Code + Overleaf Git を用いた LaTeX 執筆環境。

各 LaTeX プロジェクトを Docker Dev Container 内で開くことで、ホスト側の TeX 環境に依存せず、再現可能な LaTeX 環境を構築する。

主な用途：

- pdfLaTeX
- LuaLaTeX
- pLaTeX
- upLaTeX
- Overleaf Git との同期
- VS Code + LaTeX Workshop
- Codex を利用した編集・コンパイル支援

---

## 1. 全体構成

```text
Windows
└── WSL2
    └── Ubuntu
        ├── Git
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

VS Code を利用する場合は、以下を準備しておく。

- Visual Studio Code
- WSL extension
- Dev Containers extension

WSL ターミナルから以下が動作すること。

```bash
code .
```

---

## 3. インストール

### 3.1 リポジトリを clone

```bash
cd ~/docker_work
git clone <repository-url> latex
cd latex
```

この環境では、リポジトリを

```text
~/docker_work/latex
```

に配置することを想定している。

---

### 3.2 セットアップスクリプトを実行

```bash
./setup/install-wsl.sh
```

セットアップスクリプトでは主に以下を行う。

- 必要なディレクトリの確認・作成
- `projects/` の作成
- `fzf` の確認
- `bin/*.sh` の実行権限確認
- `~/bin/texproj` の作成
- `~/bin/texnew` の作成
- `~/bin` の PATH 設定
- Git の `user.name` / `user.email` の確認
- Docker が sudo なしで利用可能か確認
- VS Code の `code` コマンド確認

必要な項目については対話的に設定する。

セットアップスクリプトは複数回実行しても問題ないように設計している。

実行後、

```bash
source ~/.bashrc
```

を実行する。

確認：

```bash
which texproj
which texnew
```

通常は以下のようになる。

```text
/home/<user>/bin/texproj
/home/<user>/bin/texnew
```

---

## 4. ディレクトリ構成

```text
latex/
├── .gitignore
├── README.md
│
├── bin/
│   ├── latex-select.sh
│   └── new-latex-project.sh
│
├── setup/
│   └── install-wsl.sh
│
├── templates/
│   ├── devcontainer/
│   │   └── devcontainer.json
│   │
│   ├── gitignore/
│   │   └── latex.gitignore
│   │
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

## 5. Git 管理方針

このリポジトリは **LaTeX 開発環境そのもの**を管理する。

各論文・プロジェクトは `projects/` 以下に配置するが、この環境リポジトリでは管理しない。

親リポジトリの `.gitignore` には以下を指定する。

```gitignore
/projects/
```

したがって、

```text
~/docker_work/latex/.git
```

と

```text
~/docker_work/latex/projects/paper-a/.git
```

は独立した Git リポジトリとなる。

各 LaTeX プロジェクトは、それぞれ Overleaf Git 等で個別に管理する。

確認：

```bash
git check-ignore -v projects/
```

---

## 6. 既存プロジェクトを開く

以下を実行する。

```bash
texproj
```

`fzf` が起動し、`projects/` 以下のプロジェクトを検索・選択できる。

```text
texproj
   ↓
fzf でプロジェクト選択
   ↓
git pull --rebase
   ↓
VS Code 起動
```

ローカルに未コミット変更がある場合は、自動で `git pull` せず確認を求める。

VS Code が開いたら、

```text
Ctrl + Shift + P
```

から

```text
Dev Containers: Reopen in Container
```

を実行する。

Dev Container が起動したら、そのまま編集を開始できる。

---

## 7. 新しい LaTeX プロジェクトを作成する

以下を実行する。

```bash
texnew
```

実体は、

```text
bin/new-latex-project.sh
```

である。

以下の2種類のプロジェクト作成に対応する。

### 7.1 Overleaf プロジェクトを clone

Overleaf の Git URL を入力し、

```text
projects/<project-name>/
```

へ clone する。

Overleaf Git の URL は通常、

```text
https://git.overleaf.com/...
```

の形式となる。

認証時：

```text
Username: git
Password: Overleaf Git authentication token
```

を使用する。

---

### 7.2 新規ローカルプロジェクト

新しいディレクトリを作成し、Git リポジトリを初期化する。

既存の `latexmkrc` がない場合は、使用するコンパイラを選択する。

- pdfLaTeX
- LuaLaTeX
- upLaTeX
- pLaTeX

対応するテンプレートが

```text
templates/latexmkrc/
```

からコピーされる。

---

## 8. Dev Container

テンプレート：

```text
templates/devcontainer/devcontainer.json
```

基本イメージ：

```text
texlive/texlive:latest
```

新規プロジェクト作成時には最新版のイメージを pull した後、実際に取得された Docker image digest をプロジェクトの `devcontainer.json` に保存する。

例：

```json
"image": "texlive/texlive@sha256:..."
```

これにより、プロジェクトごとに使用した TeX Live 環境を再現可能にする。

一方、テンプレート側は

```json
"image": "texlive/texlive:latest"
```

のままとする。

---

## 9. `.devcontainer/` の Git 管理

各 LaTeX プロジェクトの

```text
.devcontainer/
```

は Git 管理する。

したがって Overleaf 側にも、

```text
.devcontainer/devcontainer.json
```

が保存される。

これにより、別PCへ clone した場合でも同じ Docker image digest を利用できる。

---

## 10. `latexmkrc`

コンパイラの選択は各プロジェクトの `latexmkrc` を source of truth とする。

既存の Overleaf プロジェクトに `latexmkrc` が存在する場合は、それを変更しない。

例えば upLaTeX：

```perl
$latex = 'uplatex %O %S';
$bibtex = 'upbibtex %O %B';
$dvipdf = 'dvipdfmx %O -o %D %S';
$makeindex = 'mendex -U %O -o %D %S';

$pdf_mode = 3;

$ENV{'TZ'} = 'Asia/Tokyo';
```

ローカルコンパイル時の出力先 `build/` は `latexmkrc` には書かない。

Dev Container / LaTeX Workshop 側から、

```text
latexmk -outdir=build ...
```

として指定する。

この設計により、

```text
Overleaf:
    latexmkrc をそのまま利用

Local:
    latexmkrc
    +
    -outdir=build
```

という役割分担になる。

---

## 11. LaTeX Workshop

Dev Container では LaTeX Workshop を使用する。

主な設定：

- 保存時に自動ビルド
- PDF を VS Code タブ内で表示
- 出力先は `build/`
- `latexmk` を利用
- コンパイラの詳細は各プロジェクトの `latexmkrc` に委ねる

通常は `.tex` ファイルを保存するだけでコンパイルされる。

---

## 12. Codex

Dev Container 内でも Codex / ChatGPT extension を利用できる。

Codex から、

- `.tex` ファイルの編集
- Git 操作
- `latexmk`
- `uplatex`
- その他の Linux コマンド

を実行できる。

Dev Container 内では例えば以下の環境となる。

```text
/workspaces/<project>
```

TeX Live や Git はコンテナ内のものを利用する。

---

## 13. 日常の基本ワークフロー

通常は以下だけでよい。

```bash
texproj
```

その後：

```text
1. fzf でプロジェクトを検索
2. Enter
3. git pull --rebase
4. VS Code が開く
5. Dev Containers: Reopen in Container
6. 編集
7. 保存すると LaTeX Workshop がコンパイル
8. Git commit
9. git pull --rebase
10. git push
```

---

## 14. Git / Overleaf の基本フロー

編集前：

```bash
git pull --rebase
```

編集後：

```bash
git status
git add .
git commit -m "..."
```

push の直前にもう一度、

```bash
git pull --rebase
git push
```

としておくと、Overleaf 側で編集された内容との衝突を減らせる。

---

## 15. Windows から `texproj` を起動する

Windows のショートカットから直接 `texproj` を起動することもできる。

ショートカットのリンク先：

```text
C:\Windows\System32\wsl.exe -d Ubuntu-22.04 -- bash -ic "texproj; exec bash"
```

Ubuntu のディストリビューション名が異なる場合は、

```powershell
wsl -l -v
```

で確認して変更する。

このショートカットを実行すると、

```text
Windows shortcut
    ↓
WSL Ubuntu
    ↓
texproj
    ↓
fzf
    ↓
VS Code
```

となる。

最後の

```text
exec bash
```

により、VS Code 起動後も WSL ターミナルを閉じず、

```text
Ctrl + Shift + P
→ Dev Containers: Reopen in Container
```

という案内を確認できる。

---

## 16. 新しいPC / WSL環境への復元

新しい環境では、まず以下を準備する。

```text
WSL2
Ubuntu
Git
Docker Engine
VS Code
```

WSL 内に作業ディレクトリを用意する。

```bash
mkdir -p ~/docker_work
cd ~/docker_work
```

環境リポジトリを clone。

```bash
git clone <repository-url> latex
cd latex
```

セットアップ：

```bash
./setup/install-wsl.sh
source ~/.bashrc
```

確認：

```bash
texproj
texnew
```

必要な LaTeX プロジェクトは、Overleaf Git 等から `projects/` 以下へ clone する。

```bash
texnew
```

を使用してもよい。

---

## 17. セットアップ状態の確認

### launcher

```bash
readlink -f ~/bin/texproj
readlink -f ~/bin/texnew
```

想定：

```text
~/docker_work/latex/bin/latex-select.sh
~/docker_work/latex/bin/new-latex-project.sh
```

### PATH

```bash
which texproj
which texnew
```

### Docker

```bash
docker info
```

### Git

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

### `texproj: command not found`

まず：

```bash
source ~/.bashrc
```

確認：

```bash
echo "$PATH"
which texproj
```

symlink：

```bash
ls -l ~/bin/texproj
```

---

### `fzf: command not found`

```bash
sudo apt update
sudo apt install fzf
```

その後：

```bash
fzf --version
```

---

### Docker が sudo なしで使用できない

確認：

```bash
docker info
```

permission error が出る場合：

```bash
sudo usermod -aG docker "$USER"
```

その後 WSL を再起動する。

---

### VS Code が起動しない

確認：

```bash
which code
code .
```

WSL から Windows 側の VS Code を起動できる状態にする。

---

### `Reopen in Container` が表示されない

Windows 側の VS Code に Dev Containers extension がインストールされていることを確認する。

Extension ID：

```text
ms-vscode-remote.remote-containers
```

---

### Codex のログインに失敗する

Tailscale 等のネットワーク/VPN環境によって OAuth 認証が失敗する場合がある。

認証時に問題が発生した場合は、一時的に Tailscale / VPN を無効化した状態でも確認する。

---

## 19. このリポジトリで管理するもの

管理対象：

```text
README.md
.gitignore
bin/
setup/
templates/
```

管理対象外：

```text
projects/
```

各プロジェクトは、それぞれ独立した Git リポジトリとして管理する。

---

## 20. Design Policy

この環境では、以下の役割分担を採用する。

### ホスト / WSL

- プロジェクト管理
- Git
- Docker Engine
- launcher
- VS Code 起動

### Dev Container

- TeX Live
- latexmk
- LaTeX Workshop
- Codex
- 実際の LaTeX コンパイル

### Project repository

- `.tex`
- bibliography
- figures
- `latexmkrc`
- `.devcontainer/`
- project-specific configuration

### Environment repository

- 共通テンプレート
- launcher
- project creation script
- bootstrap/setup script

この分離により、

- PC交換
- WSL再構築
- TeX Live更新
- Overleafとの同期
- プロジェクトごとの再現性

を可能な限り独立して扱えるようにする。