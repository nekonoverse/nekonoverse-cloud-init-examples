# Arch Linux Cloud-Init 構成例

Arch Linux 上で Nekonoverse を systemd ネイティブに構築する Cloud-Init 設定。

## 前提

- Arch Linux のクラウドイメージ（cloud-init 対応）
- 最低 2GB RAM / 2 vCPU / 20GB ディスク
- Cloudflare Tunnel のトークン、または Tailscale の authkey

## 構成

```
user-data        # Cloud-Init 設定本体
```

## セキュリティ

- SELinux enforcing モード
- 各サービスは専用 systemd ユニット + DynamicUser / ProtectSystem 等で権限最小化
- PostgreSQL は unix socket 認証（ネットワーク非公開）
- Valkey は unix socket or localhost 限定

## 使い方

1. `user-data` をコピーし、`## ===== 設定 =====` セクションを環境に合わせて編集
2. コメントアウトで追従ブランチ・S3・GPU・ネットワーク方式を選択
3. Cloud-Init の user-data として渡してインスタンス起動

```bash
# 例: QEMU/KVM
qemu-system-x86_64 \
  -m 2G -smp 2 \
  -drive file=archlinux-cloudimg.qcow2 \
  -drive file=seed.iso,format=raw \
  ...
```
