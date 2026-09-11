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

## Render へのデプロイ

Render のネイティブ Elixir ランタイムを使い、Phoenix の Mix Release としてデプロイする。Dockerfile は不要。この手順は DB を使わない現在の構成を前提としている。

### 事前準備

1. このリポジトリを GitHub などの Git プロバイダに push する。
2. Render Dashboard で **New > Web Service** を選び、リポジトリを接続する。
3. サービス作成画面で、次の値を設定する。

| 項目 | 値 |
| --- | --- |
| Language | `Elixir` |
| Build Command | `npm ci --prefix assets && mix deps.get --only prod && MIX_ENV=prod mix compile && MIX_ENV=prod mix assets.deploy && MIX_ENV=prod mix phx.gen.release && MIX_ENV=prod mix release` |
| Start Command | `_build/prod/rel/scratch_inspector/bin/server` |

`npm ci --prefix assets` は `assets/package-lock.json` に従って Mermaid などの JavaScript 依存関係をインストールする。`mix phx.gen.release` で `bin/server` ランチャーを生成した後、`mix release` で production release を assemble する。`mix assets.deploy` は本番用アセットと digest を生成する。

### 環境変数

Render のサービス設定画面の **Environment** に、次を追加する。

| キー | 値 |
| --- | --- |
| `SECRET_KEY_BASE` | ローカルで `mix phx.gen.secret` を実行して得られる 64 bytes 以上の値 |
| `PORT` | `10000` |
| `PHX_HOST` | Render が表示する `<サービス名>.onrender.com` のホスト名（`https://` は付けない） |

`SECRET_KEY_BASE` はリポジトリへ commit しない。必ずローカルで `mix phx.gen.secret` を実行して得た出力を、そのまま Render に貼り付ける。Render の Elixir サービスでは `MIX_ENV=prod` が自動設定されるため、通常は追加設定不要。Elixir/OTP のバージョンを固定する場合は、`mix.exs` の制約（Elixir `~> 1.14`）に合う `ELIXIR_VERSION` と `ERLANG_VERSION` も設定する。

### デプロイと確認

1. **Create Web Service** をクリックする。
2. **Deploys** のログで release の生成と起動処理が成功することを確認する。
3. デプロイ完了後、Render が表示する URL をブラウザで開き、Scratch ファイルをアップロードする。

Render の Web Service は `0.0.0.0` の `PORT` で待ち受ける必要がある。このアプリは `config/runtime.exs` で `PORT` を読み取る。LiveView の WebSocket 接続を含むため、Static Site ではなく Web Service を選ぶこと。初回デプロイでポート検出に失敗する場合は、同ファイルの `http` 設定にある `ip` を `{0, 0, 0, 0}`（IPv4 any）へ変更して再デプロイする。

### 更新時

接続したブランチへ push すると、Render が自動デプロイする。失敗時は Render の **Logs** と **Deploys** で、特に以下を確認する。

- `SECRET_KEY_BASE is missing` が出ていないか
- `npm ci --prefix assets`、`assets.deploy`、`phx.gen.release`、`mix release` が完了しているか
- `PORT` と `PHX_HOST` の値に余計な引用符や `https://` が入っていないか

詳しい仕様は [Render の Phoenix デプロイガイド](https://render.com/docs/deploy-phoenix)、[Web Services のポート設定](https://render.com/docs/web-services)、[Elixir/OTP バージョン設定](https://render.com/docs/elixir-erlang-versions) を参照。

## 主要機能

### ファイル読み込み
- ブラウザからのファイルアップロード（LiveView の `allow_upload`）
- ScratchプロジェクトページURLからの読み込み（例: `https://scratch.mit.edu/projects/123456789/`）
- `.sb` / `.sb2` / `.sb3` のパース
  - `.sb2` / `.sb3` は ZIP 形式。内部の `project.json` を抽出して解析
  - `.sb` はバイナリ形式（Scratch 1.x 独自フォーマット）

URLから読み込む場合は、Scratch公式APIからプロジェクトトークンを取得した後、プロジェクトJSONを取得して解析します。元のアーカイブを取得しないため、URL経由ではコスチューム画像・音声のバイナリ表示と、重いスプライトの遅延詳細解析は利用できません。

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
