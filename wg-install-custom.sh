#!/usr/bin/env bash
# Wrapper for hwdsl2/wireguard-install to allow custom IPv4 /24 subnet on first install,
# and jump straight to "add/remove peer" menu on subsequent runs.

set -euo pipefail

UPSTREAM_URL="https://raw.githubusercontent.com/hwdsl2/wireguard-install/refs/heads/master/wireguard-install.sh"
SUBNET_CACHE="/etc/wireguard/.wg-install-subnet"  # 仅做记录，不用于二次替换

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "请以 root 身份运行（例如：sudo $0）"
    exit 1
  fi
}

wg_installed() {
  if [[ -f /etc/wireguard/wg0.conf ]]; then
    return 0
  fi
  if command -v systemctl &>/dev/null && systemctl list-unit-files | grep -q '^wg-quick@wg0\.service'; then
    return 0
  fi
  if ip link show wg0 &>/dev/null; then
    return 0
  fi
  return 1
}

download_upstream() {
  local dst="$1"
  curl -fsSL "$UPSTREAM_URL" -o "$dst"
}

prompt_subnet() {
  local preset="10.7.0.0/24"
  if [[ -f "$SUBNET_CACHE" ]]; then
    preset="$(cat "$SUBNET_CACHE" || true)"
  fi
  read -rp "请输入 WireGuard 内网网段 (CIDR)，仅支持 /24，如 10.3.0.0/24 [默认 ${preset}]: " SUBNET
  SUBNET="${SUBNET:-$preset}"

  # 仅允许 RFC1918 且 /24（上游分配逻辑按最后一段递增，/24 最稳妥）
  if ! [[ "$SUBNET" =~ ^(10\.(25[0-5]|2[0-4][0-9]|1?[0-9]{1,2})\.(25[0-5]|2[0-4][0-9]|1?[0-9]{1,2})\.0/24)$|^(172\.(1[6-9]|2[0-9]|3[0-1])\.(25[0-5]|2[0-4][0-9]|1?[0-9]{1,2})\.0/24)$|^(192\.168\.(25[0-5]|2[0-4][0-9]|1?[0-9]{1,2})\.0/24)$ ]]; then
    echo "输入网段不合法。示例：10.3.0.0/24, 172.20.5.0/24, 192.168.88.0/24"
    exit 1
  fi

  echo "$SUBNET"
}

main() {
  require_root

  FORCE_INSTALL=false
  if [[ "${1:-}" == "--force-install" || "${1:-}" == "--reinstall" ]]; then
    FORCE_INSTALL=true
    shift
  fi

  TMP="$(mktemp)"
  download_upstream "$TMP"

  if wg_installed && [[ "$FORCE_INSTALL" == "false" ]]; then
    echo "检测到已安装 WireGuard。直接进入上游脚本的客户端管理菜单..."
    exec bash "$TMP" "$@"
  fi

  # 首次安装（或强制重装）——注入自定义网段
  SUBNET="$(prompt_subnet)"
  SUBNET_BASE="${SUBNET%/*}"
  IFS='.' read -r o1 o2 o3 o4 <<< "$SUBNET_BASE"
  NET_BASE="${o1}.${o2}.${o3}"

  # 仅替换默认 IPv4 段与前缀，IPv6 保持上游默认
  sed -i \
    -e "s#10\.7\.0\.0/24#${SUBNET//\//\\/}#g" \
    -e "s#10\.7\.0\.#${NET_BASE//./\\.}\.#g" \
    "$TMP"

  # 记录选择（仅作留档，无运行时影响）
  mkdir -p /etc/wireguard || true
  echo "$SUBNET" > "$SUBNET_CACHE" || true

  echo "将使用网段：$SUBNET（客户端将分配 ${NET_BASE}.X/24）"
  echo "开始执行上游安装脚本（已注入自定义网段）..."
  exec bash "$TMP" "$@"
}

main "$@"
