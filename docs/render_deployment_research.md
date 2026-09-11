# Render への Phoenix アプリのデプロイ調査

調査日: 2026-09-11

この文書は、Render の Web Service にこのリポジトリの Phoenix LiveView アプリをデプロイするための調査メモです。Render 公式ドキュメントと Phoenix 公式ドキュメントのみを参照しています。

## 結論

このアプリはサーバー側で Phoenix を実行するため、Render の **Web Service** としてデプロイします。Render の Phoenix 専用手順に合わせ、production release をビルドして `server` ランチャーで起動する構成が適しています。

現リポジトリには `build.sh` がないため、Render の Build Command に以下を直接設定するか、同じ内容の `build.sh` を追加して `./build.sh` を指定します。

```bash
npm ci --prefix assets && mix deps.get --only prod && MIX_ENV=prod mix compile && MIX_ENV=prod mix assets.deploy && MIX_ENV=prod mix phx.gen.release && MIX_ENV=prod mix release
```

Start Command はアプリ名に合わせて次のとおりです。

```bash
_build/prod/rel/scratch_inspector/bin/server
```

## Render Dashboard の設定

Render Dashboard で `New` → `Web Service` を選び、Git プロバイダーに接続してこのリポジトリを選択します。Render 公式の Web Service 手順では、サービス作成時に名前、リージョン、ブランチ、言語、Build Command、Start Command、プランを設定できます。

設定値は次のとおりです。

| 項目 | 推奨値 |
| --- | --- |
| Service type | Web Service |
| Repository | `scratch-inspector` の Git リポジトリ |
| Root Directory | リポジトリ直下（モノレポでないため空欄） |
| Branch | デプロイしたいブランチ（通常は `main`） |
| Language | `Elixir` |
| Build Command | `npm ci --prefix assets && mix deps.get --only prod && MIX_ENV=prod mix compile && MIX_ENV=prod mix assets.deploy && MIX_ENV=prod mix phx.gen.release && MIX_ENV=prod mix release` |
| Start Command | `_build/prod/rel/scratch_inspector/bin/server` |
| Health Check Path | 任意。設定する場合は公開されている軽量なパス（例: `/`） |

Render は Web Service を `0.0.0.0` 上のポートに bind することを要求します。ポートは Render が設定する `PORT` を使い、現在の `config/runtime.exs` は `PORT` を読み取る実装になっています。Render の既定ポートは `10000` です。

## 環境変数

### 必須

| キー | 値 |
| --- | --- |
| `SECRET_KEY_BASE` | ローカルで `mix phx.gen.secret` を実行して得られる 64 bytes 以上の値 |

`config/runtime.exs` は production 環境で `SECRET_KEY_BASE` がなければ起動時に raise します。値はソースコードに保存せず、Render Dashboard の Advanced → Environment Variables で Secret として登録します。短い値ではなく、ローカルで生成したコマンドの出力をそのまま貼り付けます。

ローカルでの生成例:

```bash
mix phx.gen.secret
```

### Render が提供する値

| キー | 用途 |
| --- | --- |
| `PORT` | Render が Web Service 用に設定する待受ポート。通常は明示設定不要 |
| `RENDER_EXTERNAL_HOSTNAME` | Render が提供する公開ホスト名。Phoenix の `PHX_HOST` に利用可能 |

このリポジトリの `config/runtime.exs` は `PHX_HOST` を参照し、未設定時は `example.com` にフォールバックします。公開 URL や絶対 URL を正しく生成するため、次のいずれかを推奨します。

1. Render の Environment Variables に `PHX_HOST` を追加し、Render の `*.onrender.com` ホスト名を設定する。
2. `config/runtime.exs` を Render 公式例に合わせ、`PHX_HOST` のフォールバックとして `RENDER_EXTERNAL_HOSTNAME` を使う。

カスタムドメインを追加した場合は、`PHX_HOST` をそのドメインに合わせます。`url` は HTTPS 用に設定済みです。

### バージョン固定（推奨）

このリポジトリの `mix.exs` は Elixir `~> 1.14` を要求しています。一方、Render の新しいサービスの既定値は Elixir 1.16.1／Erlang/OTP 26.2.2 です。互換性と再現性を明確にするため、Render の対応バージョンを確認したうえで、必要なら次を設定します。

| キー | 例 |
| --- | --- |
| `ELIXIR_VERSION` | プロジェクトと依存関係に適合するバージョン（例: `1.14.5`） |
| `ERLANG_VERSION` | その Elixir と互換性のある OTP バージョン |

`ERLANG_VERSION` を指定する場合は、Elixir との互換性を必ず確認します。指定しない場合、Render は選択した Elixir に互換性のある Erlang runtime を取得します。

## Build Command の根拠と内容

Phoenix の Release 手順は、production 依存関係の取得、production コンパイル、アセットの production ビルド、`mix phx.gen.release` の順です。このリポジトリでは `mix.exs` に次のアセット alias が定義されています。

```text
assets.deploy = tailwind scratch_inspector --minify
                esbuild scratch_inspector --minify
                phx.digest
```

したがって Render の Build Command は、次の処理を一度に行います。

```bash
npm ci --prefix assets
mix deps.get --only prod
MIX_ENV=prod mix compile
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix phx.gen.release
MIX_ENV=prod mix release
```

`mix.lock` はリポジトリにコミットしておきます。Phoenix 公式手順も、依存関係を取得してから release を assemble する流れを示しています。

Render 公式の Phoenix 専用例は `build.sh` を Build Command に指定し、release の `bin/server` を Start Command に指定しています。このリポジトリでスクリプト化する場合の内容は次のとおりです（この調査ではファイルを追加していません）。

```bash
#!/usr/bin/env bash
set -o errexit

mix deps.get --only prod
MIX_ENV=prod mix compile
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix phx.gen.release
```

## 起動と `PHX_SERVER`

`mix phx.gen.release` が生成する `bin/server` は Phoenix Server を起動するためのラッパーです。そのため、上記の Start Command では `PHX_SERVER=true` を別途設定する必要はありません。

release のアプリ本体ランチャーを直接使う場合は、Phoenix 公式の説明どおり `PHX_SERVER=true` を環境変数に設定する必要があります。Render の一般的な Elixir の Start Command として `mix phx.server` も案内されていますが、production release を組み立てる今回の構成では release の `bin/server` を使います。

## このリポジトリ固有の確認点

- アプリケーション名は `scratch_inspector` なので、release パスは `_build/prod/rel/scratch_inspector/bin/server` です。
- production 起動時に `SECRET_KEY_BASE` が必須です（`config/runtime.exs`）。
- `PORT` は `config/runtime.exs` で `4000` をフォールバックにしていますが、Render 上では Render 提供の `PORT` が優先されます。
- `config/runtime.exs` の HTTP bind は現在 IPv6 any address (`{0, 0, 0, 0, 0, 0, 0, 0}`) です。Render の公式 Web Service 要件は host `0.0.0.0` への bind なので、初回デプロイでポート検出に失敗する場合は、Bandit の `ip` を IPv4 any address (`{0, 0, 0, 0}`) に変更して再デプロイします。
- アップロードされた Scratch ファイルなどを実行時ファイルシステムに保存する場合、Render の既定ファイルシステムは ephemeral です。デプロイや再起動で失われる前提で、永続化が必要なデータは外部 datastore または Render Persistent Disk を検討します。
- Render の Free Web Service は一定時間アクセスがないと spin down します。LiveView の初回接続や利用時に起動待ちが発生し得ます。
- Build／Start などのコマンドが失敗するとデプロイ全体が失敗します。Render Dashboard の Deploys ページとログで確認します。

## ローカルでの事前確認

Render に push する前に、production と同じ順序で確認します。

```bash
set SECRET_KEY_BASE=<mix phx.gen.secret の出力>
mix deps.get --only prod
MIX_ENV=prod mix compile
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix phx.gen.release

set PHX_SERVER=true
set PORT=4000
_build/prod/rel/scratch_inspector/bin/server
```

Windows PowerShell では環境変数の設定を次のように読み替えます。

```powershell
$env:SECRET_KEY_BASE = (mix phx.gen.secret)
$env:PHX_SERVER = "true"
$env:PORT = "4000"
```

`bin/server` を使う場合は `PHX_SERVER` はラッパー側で設定されるため、ローカル確認でも通常は不要です。

## 参照した一次情報

- [Render: Deploy a Phoenix App on Render](https://render.com/docs/deploy-phoenix) — Phoenix 専用の build script、`RENDER_EXTERNAL_HOSTNAME`、release の Start Command、`SECRET_KEY_BASE`。
- [Render: Web Services](https://render.com/docs/web-services) — Web Service の作成項目、環境変数、`0.0.0.0` bind、`PORT`。
- [Render: Deploying on Render](https://render.com/docs/deploys) — Elixir の build／start command、デプロイ順序、ephemeral filesystem。
- [Render: Setting Your Elixir and Erlang Versions](https://render.com/docs/elixir-erlang-versions) — `ELIXIR_VERSION`、`ERLANG_VERSION`、既定バージョン。
- [Phoenix: Deploying with Releases](https://github.com/phoenixframework/phoenix/blob/main/guides/deployment/releases.md) — `mix deps.get --only prod`、`MIX_ENV=prod mix compile`、`mix assets.deploy`、`mix phx.gen.release`、`bin/server`。
