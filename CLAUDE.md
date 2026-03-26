# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# 開発サーバー起動（http://localhost:4000）
mix phx.server

# テスト実行
mix test

# 単一テスト実行
mix test test/path/to/file_test.exs

# コンパイル
mix compile

# アセットビルド（本番用）
mix assets.build
```

## アーキテクチャ

Phoenix LiveView アプリケーション。DB なし（`--no-ecto`）。

```
lib/
  scratch_inspector/          # ビジネスロジック層
  scratch_inspector_web/      # Web層
    live/                     # LiveView モジュール（未作成・実装先）
    components/               # 共通 UI コンポーネント
    router.ex                 # ルーティング
assets/
  js/app.js                   # JS エントリポイント（Phoenix LiveView フック）
  css/app.css                 # Tailwind CSS
```

## このプロジェクトについて

Scratch（`.sb` / `.sb2` / `.sb3`）ファイルを読み込み、スクリプト内の**関数呼び出し・イベント・変数参照**を可視化する Web アプリ。

### ファイル形式
- `.sb3` / `.sb2`: ZIP ファイル。内部の `project.json` を JSON パースして解析
- `.sb`: Scratch 1.x バイナリ形式（独自フォーマット）

### 実装方針
- ファイルアップロードは `Phoenix.LiveView.Upload`（`allow_upload`）を使用
- パース処理は `lib/scratch_inspector/` 以下に配置
- 可視化は LiveView のリアルタイム更新で実現
