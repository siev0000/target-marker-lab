# Target Marker Lab

ゲーム本体から独立した、ターゲットマーカー作成・検証用の Vue アプリです。

## 含むもの

- リング、形状、色、発光、分割、移動時状態を編集する作成画面
- 停止時／移動時のプレビュー
- ブラウザ `localStorage` への自動保存
- 設定 JSON の書き出し／読み込み

ゲーム本体のキャラクター、背景、SE、戦闘ロジックは含みません。

## 開発

```bash
npm install
npm run dev
```

## GitHub Pages

このフォルダを `target-marker-lab` という GitHub リポジトリとして公開する前提です。リポジトリ名を変更する場合は、`vite.config.js` の `base` も `/リポジトリ名/` に変更してください。

1. GitHub で空のリポジトリを作成する
2. GitHub Pages の Source を `GitHub Actions` にする
3. `main` ブランチへ push する

`main` への push 後、`.github/workflows/deploy.yml` がビルドして GitHub Pages へ公開します。

## 設定の扱い

設定はこのブラウザの `localStorage` に保存されます。サイトデータを削除すると消えるため、残したいものは JSON を書き出してください。
