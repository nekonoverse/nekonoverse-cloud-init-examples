# Debian Cloud-Init 構成例

Debian 13 (Trixie) 上で Nekonoverse を systemd ネイティブに構築する Cloud-Init 設定。

## 前提

- Debian 13 (Trixie) クラウドイメージ（cloud-init 対応）
- 最低 2GB RAM / 2 vCPU / 20GB ディスク
- Cloudflare Tunnel のトークン、または Tailscale の authkey

## 構成

```
user-data            # systemd ネイティブ (bare-metal) 版
user-data-docker     # Docker Compose 版
```

## Ubuntu との主な違い

- **sudo**: Debian はデフォルトで sudo が未インストール。`bootcmd` で早期インストール + `packages` でも指定
- **APT ソース**: PPA 非対応のため、PostgreSQL (PGDG)・Valkey・Node.js は公式 Debian リポジトリを使用
- **PostgreSQL 18**: PGDG リポジトリから `postgresql-18` をインストール

## 2 つの構成

| ファイル | 方式 | 概要 |
|---|---|---|
| `user-data` | systemd ネイティブ | PostgreSQL / Valkey / nginx 等を直接インストール。PGDG から PostgreSQL 18 |
| `user-data-docker` | Docker Compose | Docker CE + Compose プラグインのみ。サービスはすべてコンテナ内 |

## セキュリティ

- AppArmor enforcing
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
multipass launch --name nekonoverse --cloud-init user-data --memory 2G --disk 20G

# 例: QEMU/KVM
qemu-system-x86_64 \
  -m 2G -smp 2 \
  -drive file=debian-13-cloudimg.qcow2 \
  -drive file=seed.iso,format=raw \
  ...
```
