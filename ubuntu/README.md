# Ubuntu Server Cloud-Init 構成例

Ubuntu Server (24.04 LTS) 上で Nekonoverse を systemd ネイティブに構築する Cloud-Init 設定。

## 前提

- Ubuntu Server 24.04 LTS クラウドイメージ（cloud-init 対応）
- 最低 2GB RAM / 2 vCPU / 20GB ディスク
- Cloudflare Tunnel のトークン、または Tailscale の authkey

## 構成

```
user-data        # Cloud-Init 設定本体
```

## セキュリティ

- AppArmor enforcing（Ubuntu デフォルト）
- UFW ファイアウォール（SSH + HTTP のみ許可）
- 各サービスは専用 systemd ユニット + ProtectSystem / NoNewPrivileges 等で権限最小化
- PostgreSQL は unix socket 認証（ネットワーク非公開）
- Valkey は localhost 限定
- unattended-upgrades によるセキュリティパッチ自動適用

## 使い方

1. `user-data` をコピーし、`## ===== 設定 =====` セクションを環境に合わせて編集
2. コメントアウトで追従ブランチ・S3・GPU・ネットワーク方式を選択
3. Cloud-Init の user-data として渡してインスタンス起動

```bash
# 例: multipass (ローカルテスト)
multipass launch 24.04 --name nekonoverse --cloud-init user-data --memory 2G --disk 20G
```
