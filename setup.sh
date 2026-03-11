#!/usr/bin/env bash
# =============================================================================
# Nekonoverse Cloud-Init 構築対話シェル
# =============================================================================
set -euo pipefail

# --- 色定義 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_FILE=""

# --- ユーティリティ ---
info()  { echo -e "${CYAN}==>${NC} ${BOLD}$*${NC}"; }
warn()  { echo -e "${YELLOW}==> WARNING:${NC} $*"; }
ok()    { echo -e "${GREEN}==>${NC} $*"; }
err()   { echo -e "${RED}==> ERROR:${NC} $*" >&2; }

# 選択肢を表示して番号で選ばせる
# usage: pick "質問" "選択肢1" "選択肢2" ...
# 結果は $REPLY に入る (1-indexed)
pick() {
  local prompt="$1"; shift
  local options=("$@")
  echo
  info "$prompt"
  for i in "${!options[@]}"; do
    echo -e "  ${BOLD}$((i+1)))${NC} ${options[$i]}"
  done
  while true; do
    echo -ne "\n${CYAN}選択 [1-${#options[@]}]:${NC} "
    read -r REPLY
    if [[ "$REPLY" =~ ^[0-9]+$ ]] && (( REPLY >= 1 && REPLY <= ${#options[@]} )); then
      return 0
    fi
    err "1〜${#options[@]} の数字を入力してください"
  done
}

# 自由入力
ask() {
  local prompt="$1"
  local default="${2:-}"
  if [[ -n "$default" ]]; then
    echo -ne "\n${CYAN}${prompt}${NC} [${default}]: "
  else
    echo -ne "\n${CYAN}${prompt}:${NC} "
  fi
  read -r REPLY
  [[ -z "$REPLY" ]] && REPLY="$default"
}

# =============================================================================
# メイン
# =============================================================================
main() {
  echo
  echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║   Nekonoverse Cloud-Init セットアップ        ║${NC}"
  echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"

  # --- ディストリビューション選択 ---
  pick "ディストリビューションを選択" \
    "Arch Linux" \
    "Ubuntu Server 24.04 LTS"

  local distro=""
  local template=""
  case "$REPLY" in
    1)
      distro="archlinux"
      template="${SCRIPT_DIR}/archlinux/user-data"
      if [[ ! -f "$template" ]]; then
        err "テンプレートが見つかりません: $template"
        exit 1
      fi
      ;;
    2)
      distro="ubuntu"
      template="${SCRIPT_DIR}/ubuntu/user-data"
      if [[ ! -f "$template" ]]; then
        err "テンプレートが見つかりません: $template"
        exit 1
      fi
      ;;
    *)
      warn "未対応のディストリビューションです"
      exit 0
      ;;
  esac

  ok "ディストリビューション: ${distro}"

  # --- 追従ブランチ ---
  pick "追従ブランチ" \
    "main (安定版)" \
    "develop (最新)"

  local branch="main"
  [[ "$REPLY" == "2" ]] && branch="develop"
  ok "ブランチ: ${branch}"

  # --- ドメイン ---
  ask "ドメイン名 (例: neko.example.com)" ""
  local domain="$REPLY"
  [[ -z "$domain" ]] && { err "ドメインは必須です"; exit 1; }
  ok "ドメイン: ${domain}"

  # --- ネットワーク ---
  pick "ネットワーク (トンネル方式)" \
    "Cloudflare Tunnel (推奨)" \
    "Tailscale"

  local network="cloudflared"
  local cf_token="" ts_authkey=""
  if [[ "$REPLY" == "1" ]]; then
    ask "Cloudflare Tunnel トークン" ""
    cf_token="$REPLY"
    [[ -z "$cf_token" ]] && { err "トークンは必須です"; exit 1; }
  else
    network="tailscale"
    ask "Tailscale authkey (空欄で tailscaled のみ起動)" ""
    ts_authkey="$REPLY"
  fi
  if [[ "$network" == "tailscale" && -z "$ts_authkey" ]]; then
    ok "ネットワーク: tailscale (tailscaled のみ、手動 login)"
  else
    ok "ネットワーク: ${network}"
  fi

  # --- S3 ストレージ ---
  pick "S3 ストレージ" \
    "内部 VersityGW (POSIX バックエンド)" \
    "外部 S3 互換サービス (R2, AWS S3 等)"

  local s3_mode="internal"
  local s3_endpoint="http://127.0.0.1:7070"
  local s3_access="nekonoverse"
  local s3_secret=""
  local s3_bucket="nekonoverse"

  if [[ "$REPLY" == "1" ]]; then
    ask "S3 シークレットキー" "$(openssl rand -hex 16 2>/dev/null || echo 'change-me-s3-secret')"
    s3_secret="$REPLY"
  else
    s3_mode="external"
    ask "S3 エンドポイント URL" ""
    s3_endpoint="$REPLY"
    ask "S3 アクセスキー" ""
    s3_access="$REPLY"
    ask "S3 シークレットキー" ""
    s3_secret="$REPLY"
    ask "S3 バケット名" "nekonoverse"
    s3_bucket="$REPLY"
  fi
  ok "S3: ${s3_mode} (${s3_endpoint})"

  # --- GPU ---
  pick "GPU (顔検出サービス用)" \
    "不使用 (CPU フォールバック)" \
    "ローカル GPU" \
    "外部サービス"

  local gpu_mode="cpu"
  local gpu_url=""
  case "$REPLY" in
    2) gpu_mode="gpu" ;;
    3)
      gpu_mode="external"
      ask "外部 GPU サービス URL" ""
      gpu_url="$REPLY"
      ;;
  esac
  ok "GPU: ${gpu_mode}"

  # --- パスワード類 ---
  info "パスワード / シークレットを生成します"
  local pg_password
  pg_password="$(openssl rand -hex 16 2>/dev/null || echo 'change-me-pg-password')"
  local valkey_password
  valkey_password="$(openssl rand -hex 16 2>/dev/null || echo 'change-me-valkey-password')"
  local secret_key
  secret_key="$(openssl rand -hex 32 2>/dev/null || echo 'change-me-secret-key')"
  ok "パスワード自動生成完了"

  # --- 出力先 ---
  ask "出力ファイルパス" "./user-data"
  OUTPUT_FILE="$REPLY"

  # ==========================================================================
  # テンプレート加工
  # ==========================================================================
  info "user-data を生成中..."
  local content
  content="$(cat "$template")"

  # ブランチ
  if [[ "$branch" == "develop" ]]; then
    content="$(echo "$content" | sed 's/export NEKONOVERSE_BRANCH="main"/# export NEKONOVERSE_BRANCH="main"/')"
    content="$(echo "$content" | sed 's/# - export NEKONOVERSE_BRANCH="develop"/- export NEKONOVERSE_BRANCH="develop"/')"
  fi

  # ネットワーク: Tailscale 選択時
  if [[ "$network" == "tailscale" ]]; then
    # cloudflared を無効化
    content="$(echo "$content" | sed 's/^  - systemctl enable --now nekonoverse-cloudflared/  # - systemctl enable --now nekonoverse-cloudflared/')"
    # tailscaled を有効化
    content="$(echo "$content" | sed 's/^  # - systemctl enable --now tailscaled/  - systemctl enable --now tailscaled/')"
    # パッケージ
    content="$(echo "$content" | sed 's/^  - cloudflared/  # - cloudflared/')"
    content="$(echo "$content" | sed 's/^  # - tailscale/  - tailscale/')"
    # authkey がある場合のみ tailscale-up を有効化
    if [[ -n "$ts_authkey" ]]; then
      content="$(echo "$content" | sed 's/^  # - systemctl enable --now nekonoverse-tailscale-up/  - systemctl enable --now nekonoverse-tailscale-up/')"
      # Tailscale ユニットファイルのコメント解除
      content="$(echo "$content" | sed '/^  # - path: \/etc\/systemd\/system\/nekonoverse-tailscale-up.service/,/^  #     WantedBy=multi-user.target/ s/^  # /  /')"
    fi
  fi

  # 外部 S3 選択時: VersityGW セットアップをコメントアウト
  if [[ "$s3_mode" == "external" ]]; then
    content="$(echo "$content" | sed '/VersityGW セットアップ/,/外部 S3 使用時はここをコメントアウト/ s/^  - /  # - /')"
  fi

  # GPU: ローカル GPU 選択時
  if [[ "$gpu_mode" == "gpu" ]]; then
    content="$(echo "$content" | sed 's/^  # - python-pytorch/  - python-pytorch/')"
    content="$(echo "$content" | sed 's/^  # - python-torchvision/  - python-torchvision/')"
    content="$(echo "$content" | sed 's/^  # - cuda/  - cuda/')"
    content="$(echo "$content" | sed 's/^  # - cudnn/  - cudnn/')"
    content="$(echo "$content" | sed 's/^      # DeviceAllow/      DeviceAllow/')"
  fi

  echo "$content" > "$OUTPUT_FILE"

  # ==========================================================================
  # サマリー
  # ==========================================================================
  echo
  echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║   生成完了                                   ║${NC}"
  echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
  echo
  echo -e "  ファイル:         ${GREEN}${OUTPUT_FILE}${NC}"
  echo -e "  ディストリビューション: ${distro}"
  echo -e "  ブランチ:         ${branch}"
  echo -e "  ドメイン:         ${domain}"
  if [[ "$network" == "tailscale" && -z "$ts_authkey" ]]; then
    echo -e "  ネットワーク:     tailscale (tailscaled のみ → 手動 tailscale up)"
  else
    echo -e "  ネットワーク:     ${network}"
  fi
  echo -e "  S3:               ${s3_mode} (${s3_endpoint})"
  echo -e "  GPU:              ${gpu_mode}"
  echo
  echo -e "  ${YELLOW}重要: 出力ファイル内のコメントアウトされた Environment 行を${NC}"
  echo -e "  ${YELLOW}実際の値に置き換えてから使用してください。${NC}"
  echo
  echo -e "  PostgreSQL PW:    ${pg_password}"
  echo -e "  Valkey PW:        ${valkey_password}"
  echo -e "  Secret Key:       ${secret_key}"
  echo -e "  S3 Access Key:    ${s3_access}"
  echo -e "  S3 Secret Key:    ${s3_secret}"
  if [[ -n "$cf_token" ]]; then
    echo -e "  CF Token:         ${cf_token}"
  fi
  if [[ -n "$ts_authkey" ]]; then
    echo -e "  TS Authkey:       ${ts_authkey}"
  fi
  echo
  warn "上記のパスワード/シークレットは安全な場所に保管してください"
}

main "$@"
