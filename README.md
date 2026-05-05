# Scratch Inspector

## Encoding Note (VSCode)

To avoid Elixir compile errors caused by BOM (`U+FEFF`), this repository assumes UTF-8 without BOM.

- VSCode workspace default encoding is fixed to `utf8` in `.vscode/settings.json`.
- `.editorconfig` also declares `charset = utf-8` for text files.
- Please keep Elixir-related files (`.ex`, `.exs`, `.heex`) as UTF-8 without BOM.

> Implementation note:
> Flow detail data is now resolved by `lib/scratch_inspector_web/live/flow_detail_view_model.ex`.
> `InspectorLive` keeps UI state, while detail-display resolution is being split into that ViewModel for the staged `scratch-gui` alignment work.
> Remaining tasks from Phase 3 onward are documented in `docs/scratch_gui_alignment_roadmap.md`.

Scratch の `.sb` / `.sb2` / `.sb3` ファイルを読み込み、スクリプト内の関数呼び出し・イベント・変数参照を可視化する Web アプリケーション。

## 概要

Scratch プロジェクトファイルをアップロードすると、以下の要素を抽出してグラフィカルに表示する。

- **関数呼び出し**（カスタムブロック / `define` ブロックの呼び出し関係）
- **イベント**（`when green flag clicked`、`when I receive` などのイベントトリガーと対応するハンドラ）
- **変数参照**（変数の読み取り・書き込みが行われているスクリプト）

## 技術スタック

- **言語 / フレームワーク**: Elixir + Phoenix LiveView
- **対象ファイル形式**: `.sb`（Scratch 1.x）、`.sb2`（Scratch 2.x）、`.sb3`（Scratch 3.x）

## 主要機能

### ファイル読み込み
- ブラウザからのファイルアップロード（LiveView の `allow_upload`）
- `.sb` / `.sb2` / `.sb3` のパース
  - `.sb2` / `.sb3` は ZIP 形式。内部の `project.json` を抽出して解析
  - `.sb` はバイナリ形式（Scratch 1.x 独自フォーマット）

### 可視化
- スプライトごとのスクリプト一覧
- イベントフロー図（どのイベントがどのスクリプトをトリガーするか）
- カスタムブロックの呼び出しグラフ
- 変数の参照マップ（どのスプライト・スクリプトが参照しているか）

### インタラクション
- LiveView によるリアルタイム更新（再アップロード不要で再解析）
- ノードクリックで対応するスクリプトにジャンプ

## Windows 環境セットアップ

Windows に Elixir / Phoenix LiveView の開発環境を構築する手順。

### 1. Erlang のインストール

[Erlang/OTP ダウンロードページ](https://www.erlang.org/downloads) から Windows インストーラ（`.exe`）をダウンロードして実行する。

```powershell
# もしくは winget でインストール
winget install ErlangOTP.ErlangOTP
```

インストール後、`erl` コマンドが使えることを確認:

```powershell
erl -version
```

### 2. Elixir のインストール

[Elixir インストールページ](https://elixir-lang.org/install.html#windows) から Windows インストーラをダウンロードして実行する。

```powershell
# もしくは winget でインストール
winget install ElixirLang.Elixir
```

インストール後、ターミナルを再起動して確認:

```powershell
elixir --version
```

### 3. Hex と Phoenix のインストール

```bash
# Hex（パッケージマネージャ）
mix local.hex

# Phoenix プロジェクトジェネレータ
mix archive.install hex phx_new
```

### 4. Node.js のインストール（アセットビルド用）

[Node.js 公式サイト](https://nodejs.org/) から LTS 版をインストール。

```powershell
# もしくは winget でインストール
winget install OpenJS.NodeJS.LTS
```

### 5. このプロジェクトのセットアップ

```bash
# 依存関係のインストール
mix setup

# 開発サーバーの起動
mix phx.server
```

ブラウザで http://localhost:4001 を開く。

### トラブルシューティング

- **`mix` コマンドが見つからない**: ターミナルを再起動するか、Elixir のインストールパス（`C:\Program Files\Elixir\bin` など）を `PATH` 環境変数に追加する
- **C コンパイラ関連のエラー**: 一部の依存関係で C コンパイラが必要になる場合がある。[Visual Studio Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/) をインストールし、「C++ によるデスクトップ開発」ワークロードを選択する
- **ファイル監視（Live Reload）が動かない**: `config/dev.exs` の `:file_system_backend` 設定を確認する
