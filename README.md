# nekonoverse-cloud-init-examples

Nekonoverse を Docker を使わずに Cloud-Init でベアメタル/VM 上に構築するための構成例集。

## ディストリビューション

| ディレクトリ | 対象 | 状態 |
|---|---|---|
| [archlinux/](./archlinux/) | Arch Linux | WIP |

## 使い方

各ディレクトリ内の `user-data` を Cloud-Init の user-data として渡してインスタンスを起動する。
詳細は各ディレクトリの README を参照。

## 構成オプション

`user-data` 内のコメントアウトを切り替えることで以下を選択可能:

- **追従ブランチ**: `main`（安定） / `develop`（最新）
- **S3 ストレージ**: 内部 VersityGW (POSIX バックエンド) / 外部 S3 互換サービス
- **GPU**: 不使用 / ローカル GPU / 外部 GPU サービス
- **ネットワーク**: Cloudflared（メイン） / Tailscale

## ライセンス

MIT
