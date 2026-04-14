# agents.md

## 概要

このリポジトリは、Scratch プロジェクトファイル（主に `.sb2` / `.sb3`）を読み込み、内容をブラウザで解析・可視化する Phoenix LiveView アプリです。

現在の実装は大きく 4 層に分かれます。

1. Phoenix/OTP の起動と HTTP 配線
2. Scratch ファイルの解析
3. LiveView による状態管理と画面描画
4. Mermaid を使ったフロント側の補助描画

実装上の中心は `lib/scratch_inspector/parser.ex` と `lib/scratch_inspector_web/live/inspector_live.ex` です。  
特に `InspectorLive` は、アップロード処理、画面状態、タブ切替、フロー詳細表示、UI ヘルパーをまとめて持つ構成です。

## システム構成

### 1. 起動と Web エントリ

- `lib/scratch_inspector/application.ex`
  - OTP アプリケーションの起動点です。
  - `ScratchInspectorWeb.Telemetry`
  - `DNSCluster`
  - `Phoenix.PubSub`
  - `ScratchInspectorWeb.Endpoint`
  - を supervision tree に載せています。
- `lib/scratch_inspector_web/endpoint.ex`
  - HTTP / LiveView ソケット / 静的ファイル配信の設定を持ちます。
  - `/live` ソケット、セッション、`Plug.Static`、`Plug.Parsers` などの Phoenix 標準配線があります。
- `lib/scratch_inspector_web/router.ex`
  - ブラウザパイプラインを通して `/` を `ScratchInspectorWeb.InspectorLive` に接続します。
  - 実質的なアプリ本体の入口は `/` の LiveView です。

### 2. 解析層

- `lib/scratch_inspector/parser.ex`
  - Scratch ファイルの解析責務を一手に担います。
  - `parse(path, ext)` が内部的な解析入口です。
  - `.sb3` / `.sb2` は ZIP として展開し、`project.json` を取り出して `Jason.decode/1` で JSON を読みます。
  - `.sb` は現状未対応で、エラーを返します。
  - 解析結果は専用 struct ではなく map ベースで組み立てています。

Parser が構築する主なデータは次のとおりです。

- `project`
  - `stage`
  - `sprites`
  - `variables`
- sprite / stage ごとの情報
  - `top_scripts`
  - `custom_blocks`
  - `costumes`
  - `sounds`
- フロー可視化や変数参照表示に必要な前計算済み情報
  - イベントハット
  - ブロック列
  - カスタムブロック呼び出し関係
  - 変数・リストの read/write 参照

つまり UI は生の `project.json` を直接読むのではなく、Parser が整形した `project` map を前提に動きます。

### 3. LiveView 層

- `lib/scratch_inspector_web/live/inspector_live.ex`
  - このアプリのオーケストレーション中心です。
  - 役割は次のとおりです。
    - ファイルアップロード受付
    - `ScratchInspector.Parser.parse/2` の呼び出し
    - 画面 state の保持
    - タブ切替
    - スプライト選択
    - フロー詳細の選択
    - 変数使用箇所へのジャンプ
    - Flow / Variables / Costumes / Sounds 各パネルの描画
    - Mermaid 用グラフ文字列の生成
- `lib/scratch_inspector_web/live/flow_detail_view_model.ex`
  - Flow タブの詳細パネル向け ViewModel を生成します。
  - `flow_detail` と `project` / `target` から、詳細表示に必要な
    - `detail_script`
    - `detail_title`
    - `detail_receivers`
    を返します。
  - `InspectorLive` から詳細表示用のデータ探索責務を切り離すための層です。

`mount/3` では主に以下を初期化しています。

- `allow_upload(:scratch_file, ...)`
- `project`
- `active_tab`
- `selected_sprite`
- `selected_target_type`
- `flow_detail`
- `expanded_variable_key`

`handle_event/3` で主に扱っているイベントは次のとおりです。

- `validate`
- `upload`
- `select_sprite`
- `select_tab`
- `toggle_sprite_code`
- `flow_select_detail`
- `toggle_variable_detail`
- `jump_to_variable_usage`
- `reset`

補足として、`InspectorLive` は画面描画だけでなく、フローグラフのノード関係組み立てや変数 usage 整形などの ViewModel 的処理も内包しています。  
新機能追加時は「UI 変更だけに見えても `InspectorLive` のヘルパー群まで影響する」前提で読む必要があります。

ただし Flow タブの詳細表示については、段階的リファクタリングの第一段として
`flow_detail_view_model.ex` に解決ロジックを分離しています。  
今後 `scratch-gui` 風の詳細表示に寄せる変更は、まずこの ViewModel とその返却 shape を確認してください。

### 4. フロント補助層

- `assets/js/app.js`
  - Phoenix LiveView クライアントの初期化を行います。
  - `MermaidHook` を LiveView hook として登録しています。
- `assets/js/mermaid_hook.js`
  - Mermaid の描画とズーム操作を担当します。
  - Mermaid ノード click 時に Base64URL エンコードされた payload を復元し、LiveView に `flow_select_detail` を push します。
  - つまり Flow グラフの「見た目」はブラウザ側ですが、「詳細表示状態」は LiveView 側が真実のソースです。

## データフロー

通常の処理フローは以下です。

1. ユーザーが `/` にアクセスし、`InspectorLive` が起動する
2. LiveView Upload で Scratch ファイルを受け取る
3. `InspectorLive` が `ScratchInspector.Parser.parse/2` を呼ぶ
4. Parser が ZIP 展開、`project.json` 読み込み、各種解析を行う
5. 解析済み `project` map を LiveView assigns に載せる
6. LiveView が選択中スプライト・タブに応じて各パネルを描画する
7. Flow タブでは Mermaid 定義文字列を生成する
8. `mermaid_hook.js` が SVG を描画し、ノード click を LiveView イベントに戻す

重要なのは、解析はサーバ側、図のインタラクションはクライアント側、最終的な画面状態は LiveView 側、という分担です。

## 主要インターフェース

外から見た主要な接点は多くありません。

- 画面入口
  - `/` -> `ScratchInspectorWeb.InspectorLive`
- 解析入口
  - `ScratchInspector.Parser.parse(path, ext)`
- Flow 詳細表示入口
  - `ScratchInspectorWeb.FlowDetailViewModel.build(project, target, flow_detail)`
- クライアントから LiveView への主要イベント
  - アップロード関連イベント
  - `flow_select_detail`
  - `select_tab`
  - `select_sprite`
  - `jump_to_variable_usage`

内部データの事実上の標準形は `project` map です。現状は型定義や struct ではなく、Parser と LiveView の暗黙契約で成り立っています。

## 変更ガイド

### 解析ロジックを変えるとき

対象: 新しい Scratch ブロック対応、変数解析の精度向上、フロー関係の前計算追加

- 主に触る場所は `lib/scratch_inspector/parser.ex`
- 変更時は少なくとも以下の整合を確認します。
  - `project` map のキー構造
  - `top_scripts`
  - `custom_blocks`
  - `variables`
  - `costumes`
  - `sounds`
- UI から参照されているキー名を変える場合は `InspectorLive` 側も同時に追従が必要です

### 画面やタブを変えるとき

対象: 新しいタブ、表示情報の追加、選択状態の変更

- 主に触る場所は `lib/scratch_inspector_web/live/inspector_live.ex`
- 確認ポイントは次のとおりです。
  - `mount/3` の初期 state
  - `handle_event/3` の状態遷移
  - `render/1` のタブ分岐
  - 対応するヘルパー関数群

### Flow グラフの見た目や操作を変えるとき

対象: Mermaid レイアウト、ノード click、ズーム UI

- サーバ側
  - `InspectorLive` の Mermaid 定義文字列生成
- クライアント側
  - `assets/js/mermaid_hook.js`
- 両側のイベント契約
  - click payload の shape
  - `flow_select_detail` の引数

片側だけ変えると簡単に壊れるため、Flow 変更は Elixir と JS をセットで見る前提です。

### Phoenix 基盤を変えるとき

対象: ルーティング、セッション、静的ファイル、監視系

- `application.ex`
- `endpoint.ex`
- `router.ex`
- `telemetry.ex`

本アプリ固有の価値はここではなく、通常は Parser と LiveView の方が変更対象になります。

## 既知の設計特性

- `InspectorLive` に責務が集中しています
  - 小規模アプリとしては実用的ですが、機能追加時の影響範囲は広めです
- `project` が map ベースです
  - 柔軟ですが、キー変更に弱く、暗黙契約が多くなります
- 解析結果を UI 向けに前計算しています
  - UI は単純になりますが、解析ロジック変更時は View 依存も意識する必要があります
- `.sb` は未対応です
  - 現在の正常系は `.sb2` / `.sb3` 前提です

## 最初に読むべき場所

新しく入った開発者やエージェントは、まず次の順で読むと全体を掴みやすいです。

1. `lib/scratch_inspector_web/router.ex`
2. `lib/scratch_inspector_web/live/inspector_live.ex`
3. `lib/scratch_inspector_web/live/flow_detail_view_model.ex`
4. `lib/scratch_inspector/parser.ex`
5. `assets/js/mermaid_hook.js`
6. `README.md`

## 実務上の注意

- UI 上の表示だけを変えたい場合でも、必要な情報が Parser 側で作られているかを先に確認する
- Flow タブ関連は Elixir だけ見ても不十分で、Mermaid hook 側の click/zoom 実装も確認する
- `InspectorLive` の assign 名は実質的な画面状態 API なので、変更時はイベント・描画・ヘルパーを一括で見直す
- 既存機能の中心は単一 LiveView なので、影響調査は「別モジュールに分かれているはず」と仮定しない
- `scratch-gui` 寄せの残タスクは `docs/scratch_gui_alignment_roadmap.md` を基準に確認する
