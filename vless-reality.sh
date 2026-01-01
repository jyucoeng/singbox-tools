#!/bin/bash
export LANG=en_US.UTF-8

# ======================================================================
# Sing-box vless-reality 一键脚本
# 作者：littleDoraemon
# 说明：
#   - 支持自动 / 交互模式
#   - #   - 支持环境变量： PORT (必填) /NGINX_PORT (必填) / UUID / NODE_NAME / SNI/ REALITY_PBK / REALITY_SID
# 
#  
#  1、安装方式（2种）
#     1.1 交互式菜单安装：
#     curl -fsSL https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/vless-reality.sh -o vless-reality.sh && chmod +x vless-reality.sh && ./vless-reality.sh
#    
#     1.2 非交互式全自动安装(支持环境变量： PORT(必填)  /NGINX_PORT(必填) / UUID / NODE_NAME / SNI/ REALITY_PBK / REALITY_SID):
#     未提供 PORT / NGINX_PORT 时，脚本将暂停并提示输入（不会直接失败）

#     PORT=31090 SNI=www.visa.com NODE_NAME="小叮当的节点" bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/vless-reality.sh)
#
# Optional env(可选环境变量):
#   REALITY_PBK   Reality public key
#   REALITY_SID   Reality short id (hex)
# 
# 
# ======================================================================

AUTHOR="littleDoraemon"
VERSION="v1.0.13(2026-01-01)"
SINGBOX_VERSION="1.12.13"

SERVICE_NAME="sing-box-vless-reality"
WORK_DIR="/etc/sing-box-vless-reality"
CONFIG="$WORK_DIR/config.json"

NODE_NAME_FILE="$WORK_DIR/node_name"
SNI_FILE="$WORK_DIR/sni"

SUB_FILE="$WORK_DIR/sub.txt"
SUB_B64="$WORK_DIR/sub_base64.txt"
SUB_PORT_FILE="$WORK_DIR/sub.port"


NGINX_SERVICE="nginx"

NGX_CONF="$WORK_DIR/vless_reality_sub.conf"

REALITY_PUBKEY_FILE="$WORK_DIR/reality_public.key"
REALITY_SID_FILE="$WORK_DIR/reality_short_id"

REALITY_PRIVATE_FILE="$WORK_DIR/reality_private.key"




DEFAULT_SNI="www.bing.com"

# =====================================================
# UI
# =====================================================
red(){ echo -e "\e[1;91m$1\033[0m"; }
green(){ echo -e "\e[1;32m$1\033[0m"; }
yellow(){ echo -e "\e[1;33m$1\033[0m"; }
blue(){ echo -e "\e[1;34m$1\033[0m"; }
purple(){ echo -e "\e[1;35m$1\033[0m"; }
red_input(){ printf "\e[1;91m%s\033[0m" "$1"; }
brown(){ echo -e "\033[38;5;94m$1\033[0m"; }

pause(){ read -n 1 -s -r -p "按任意键继续..." </dev/tty; }

gradient() {
    local text="$1"
    local colors=(196 202 208 214 220 190 82 46 51 39 33)
    local i=0
    for ((n=0;n<${#text};n++)); do
        printf "\033[38;5;${colors[i]}m%s\033[0m" "${text:n:1}"
        i=$(( (i+1)%${#colors[@]} ))
    done
    echo
}

[[ $EUID -ne 0 ]] && { red "请使用 root 运行"; exit 1; }

command_exists(){ command -v "$1" >/dev/null 2>&1; }
is_port(){ [[ "$1" =~ ^[0-9]+$ && "$1" -ge 1 && "$1" -le 65535 ]]; }


is_used() {
  local port="$1"

  if command -v ss >/dev/null 2>&1; then
    # 精确匹配 LISTEN 状态 + 端口
    ss -H -lnt \
      | awk '{print $4}' \
      | grep -Eq "(:|\\])${port}$"

  elif command -v netstat >/dev/null 2>&1; then
    netstat -lnt 2>/dev/null \
      | awk '{print $4}' \
      | grep -Eq "(:|\\])${port}$"

  else
    # 无法判断时，保守认为未占用
    return 1
  fi
}



is_uuid(){ [[ "$1" =~ ^[a-fA-F0-9-]{36}$ ]]; }




# ======================= 统一退出 =======================
exit_script() {
    echo ""
    green "感谢使用本脚本,再见👋"
    echo ""
    exit 0
}


detect_nginx_conf_dir() {
  if [[ "$INIT_SYSTEM" == "openrc" ]]; then
    # Alpine / OpenRC
    echo "/etc/nginx/http.d"
  else
    # systemd (Debian / Ubuntu / CentOS ...)
    echo "/etc/nginx/conf.d"
  fi
}

init_nginx_paths() {
  NGX_NGINX_DIR="$(detect_nginx_conf_dir)"
  NGX_LINK="$NGX_NGINX_DIR/vless_reality_sub.conf"
}


detect_init() {
  if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    INIT_SYSTEM="systemd"
  elif command -v rc-service >/dev/null 2>&1; then
    INIT_SYSTEM="openrc"
  else
    red "无法识别 init 系统（既不是 systemd 也不是 OpenRC）"
    exit 1
  fi
  

}


detect_nginx_service() {
  if [[ "$INIT_SYSTEM" == "systemd" ]]; then
    # systemd 基本统一叫 nginx
    NGINX_SERVICE="nginx"
  else
    # OpenRC：尝试自动发现
    for svc in nginx nginx-openrc nginx-mainline; do
      if [[ -f "/etc/init.d/${svc}" ]]; then
        NGINX_SERVICE="$svc"
        return
      fi
    done
    # 兜底
    NGINX_SERVICE="nginx"
  fi
}


init_platform() {
  init_nginx_paths
  detect_nginx_service
}


service_enable() {
  local svc="$1"
  if [[ "$INIT_SYSTEM" == "systemd" ]]; then
    systemctl enable "$svc"
  else
    rc-update add "$svc" default 2>/dev/null || rc-update add "$svc" boot
  fi
}

service_start() {
  local svc="$1"
  if [[ "$INIT_SYSTEM" == "systemd" ]]; then
    systemctl start "$svc"
  else
    rc-service "$svc" start
  fi
}

service_stop() {
  local svc="$1"
  if [[ "$INIT_SYSTEM" == "systemd" ]]; then
    systemctl stop "$svc"
  else
    rc-service "$svc" stop
  fi
}

service_restart() {
  local svc="$1"
  if [[ "$INIT_SYSTEM" == "systemd" ]]; then
    systemctl restart "$svc"
  else
    rc-service "$svc" restart
  fi
}

service_active() {
  local svc="$1"
  if [[ "$INIT_SYSTEM" == "systemd" ]]; then
    systemctl is-active --quiet "$svc"
  else
   rc-service "$svc" status | grep -q "started"
  fi
}


# =====================================================
# IP
# =====================================================
get_ip4(){
  for s in api.ipify.org ipv4.icanhazip.com ip.sb; do
    ip=$(curl -4 -fs https://$s 2>/dev/null)
    [[ -n "$ip" ]] && { echo "$ip"; return; }
  done
}

get_ip6(){
  for s in api64.ipify.org ipv6.icanhazip.com; do
    ip=$(curl -6 -fs https://$s 2>/dev/null)
    [[ -n "$ip" ]] && { echo "$ip"; return; }
  done
}

load_runtime_from_config() {
  [[ ! -f "$CONFIG" ]] && {
    red "未找到配置文件，请先安装 Sing-box"
    return 1
  }

  PORT=$(jq -r '.inbounds[0].listen_port' "$CONFIG")
  UUID=$(jq -r '.inbounds[0].users[0].uuid' "$CONFIG")

  if [[ -z "$PORT" || -z "$UUID" || "$PORT" == "null" || "$UUID" == "null" ]]; then
    red "从配置文件读取端口或 UUID 失败"
    return 1
  fi

  return 0
}


# =====================================================
# URL encode / decode
# =====================================================

urlencode() {
  local str="$1"
  local out=""
  local i c

  for ((i=0; i<${#str}; i++)); do
    c="${str:i:1}"
    case "$c" in
      [a-zA-Z0-9.~_-]) out+="$c" ;;
      *) printf -v hex '%%%02X' "'$c"; out+="$hex" ;;
    esac
  done
  echo "$out"
}

urldecode() {
  local data="${1//+/ }"
  printf '%b' "${data//%/\\x}"
}


# =====================================================
# 模式判定
# =====================================================
is_interactive(){
  [[ -n "$PORT" || -n "$NGINX_PORT" || -n "$UUID" || -n "$NODE_NAME" || -n "$SNI" ]] && return 1 || return 0
}

# =====================================================
# 基础初始化
# =====================================================
init_dirs(){
  mkdir -p "$WORK_DIR"
}


prompt_nginx_port() {
  local p="$NGINX_PORT"

  while true; do
    if [[ -z "$p" ]]; then
      read -rp "$(red_input "请输入订阅端口（TCP，推荐 10000-65535）：")" p
    fi

    if ! is_port "$p"; then
      red "端口无效（1-65535）"
      p=""
      continue
    fi

    if is_used "$p"; then
      red "端口 $p 已被占用，请换一个未使用的端口（如 10000-65535）"
      p=""
      continue
    fi

    break
  done

  NGINX_PORT="$p"
  mkdir -p "$WORK_DIR"
  echo "$NGINX_PORT" > "$SUB_PORT_FILE"
}


prompt_vless_port() {
  local p="$PORT"

  while true; do
    if [[ -z "$p" ]]; then
      read -rp "$(red_input "请输入 VLESS端口（TCP，推荐 10000-65535）：")" p
    fi

    if ! is_port "$p"; then
      red "端口无效（1-65535）"
      p=""
      continue
    fi

    if is_used "$p"; then
      red "端口 $p 已被占用，请换一个未使用的端口（如 10000-65535）"
      p=""
      continue
    fi

    break
  done

  PORT="$p"
}




init_node_name(){
    local DEFAULT_NODE_NAME="${AUTHOR}-vless-reality"
    
    # ======================================================
    # 1. 持久化节点名称优先（如果用户曾设置过）
    # ======================================================
    if [[ -f "$NODE_NAME_FILE" ]]; then
        saved_name=$(cat "$NODE_NAME_FILE")
        if [[ -n "$saved_name" ]]; then
            echo "$saved_name" > "$NODE_NAME_FILE"
            return
        fi
    fi

    # ======================================================
    # 2. 当前会话设置的节点名称（NODE_NAME 环境变量）
    # ======================================================
    if [[ -n "$NODE_NAME" ]]; then
        echo "$NODE_NAME" > "$NODE_NAME_FILE"
        return
    fi

    # ======================================================
    # 3. 自动生成节点名称（基于IP的国家代码和运营商）
    # ======================================================
    local country=""
    local org=""

    # Try getting country code from ipapi
    country=$(curl -fs --max-time 2 https://ipapi.co/country 2>/dev/null | tr -d '\r\n')
    org=$(curl -fs --max-time 2 https://ipapi.co/org 2>/dev/null | sed 's/[ ]\+/_/g')

    # Fallback to ip.sb
    if [[ -z "$country" ]]; then
        country=$(curl -fs --max-time 2 ip.sb/country 2>/dev/null | tr -d '\r\n')
    fi

    if [[ -z "$org" ]]; then
        org=$(curl -fs --max-time 2 ipinfo.io/org 2>/dev/null \
            | awk '{$1=""; print $0}' \
            | sed -e 's/^[ ]*//' -e 's/[ ]\+/_/g')
    fi

    # Generate node name based on country and org
    if [[ -n "$country" && -n "$org" ]]; then
        node_name="${country}-${org}"
        echo "$node_name" > "$NODE_NAME_FILE"
        return
    fi

    if [[ -n "$country" && -z "$org" ]]; then
        echo "$country" > "$NODE_NAME_FILE"
        return
    fi

    if [[ -z "$country" && -n "$org" ]]; then
        echo "$DEFAULT_NODE_NAME" > "$NODE_NAME_FILE"
        return
    fi

    # Default node name if all else fails
    echo "$DEFAULT_NODE_NAME" > "$NODE_NAME_FILE"
}


init_sni(){
  [[ -f "$SNI_FILE" ]] && return
  echo "${SNI:-$DEFAULT_SNI}" > "$SNI_FILE"
}

get_node_name(){ cat "$NODE_NAME_FILE"; }
get_sni(){ cat "$SNI_FILE"; }

# =====================================================
# 安装依赖
# =====================================================
install_common_packages() {
  local pkgs="curl jq tar nginx openssl"
  local need_update=1

  for p in $pkgs; do
    if ! command_exists "$p"; then

      # 只 update 一次
      if [[ $need_update -eq 1 ]]; then
        if command_exists apt; then
          apt update -y
        elif command_exists yum; then
          yum makecache -y
        elif command_exists dnf; then
          dnf makecache -y
        elif command_exists apk; then
          apk update
        else
          red "无法识别包管理器，请手动安装依赖"
          exit 1
        fi
        need_update=0
      fi

      yellow "安装依赖：$p"

      if command_exists apt; then
        apt install -y "$p"
      elif command_exists yum; then
        yum install -y "$p"
      elif command_exists dnf; then
        dnf install -y "$p"
      elif command_exists apk; then
        apk add "$p"
      else
        red "无法识别包管理器，请手动安装 $p"
        exit 1
      fi
    fi
  done
}


download_singbox() {
  local ver="$1"
  local arch="$2"
  local out="$3"

  local urls=(
    # 1️⃣ ghproxy.net（当前最稳）
    "https://ghproxy.net/https://github.com/SagerNet/sing-box/releases/download/v${ver}/sing-box-${ver}-linux-${arch}.tar.gz"

    # 2️⃣ GitHub 原生
    "https://github.com/SagerNet/sing-box/releases/download/v${ver}/sing-box-${ver}-linux-${arch}.tar.gz"

    # 3️⃣ fastgit（可选兜底）
    "https://download.fastgit.org/SagerNet/sing-box/releases/download/v${ver}/sing-box-${ver}-linux-${arch}.tar.gz"
  )

  for u in "${urls[@]}"; do
    yellow "尝试下载 sing-box：$u"
    if curl -fL --retry 2 --connect-timeout 10 -o "$out" "$u"; then
      return 0
    fi
  done

  return 1
}



# =====================================================
# 安装 sing-box
# =====================================================
install_singbox(){
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64) ARCH=amd64 ;;
    aarch64) ARCH=arm64 ;;
    *) red "不支持的架构：$ARCH"; exit 1 ;;
  esac

  mkdir -p "$WORK_DIR"
  local tmpdir
  tmpdir=$(mktemp -d)

  # ===== 下载（方案 A：镜像 + fallback）=====
  if ! download_singbox "$SINGBOX_VERSION" "$ARCH" "$tmpdir/sb.tgz"; then
    red "无法下载 sing-box（版本 ${SINGBOX_VERSION} / 架构 ${ARCH}）"
    red "请检查 GitHub 访问或版本号是否存在"
    rm -rf "$tmpdir"
    exit 1
  fi

  # ===== 校验压缩包 =====
  if ! tar -tzf "$tmpdir/sb.tgz" >/dev/null 2>&1; then
    red "sing-box 压缩包损坏或不是有效的 tar.gz"
    rm -rf "$tmpdir"
    exit 1
  fi

  # ===== 解压 =====
  tar -xzf "$tmpdir/sb.tgz" -C "$tmpdir" || {
    red "解压 sing-box 失败"
    rm -rf "$tmpdir"
    exit 1
  }

  # ===== 安装二进制 =====
  if ! mv "$tmpdir"/sing-box-*/sing-box "$WORK_DIR/sing-box"; then
    red "未在压缩包中找到 sing-box 可执行文件"
    rm -rf "$tmpdir"
    exit 1
  fi

  chmod +x "$WORK_DIR/sing-box"
  rm -rf "$tmpdir"
}


uninstall_singbox() {
  clear
  blue "====== 卸载 Sing-box（VLESS Reality） ======"
  echo ""

  read -rp "确认卸载 Sing-box（VLESS Reality）？[Y/n]：" u
  u=${u:-y}
  [[ ! "$u" =~ ^[Yy]$ ]] && return

  # ==================================================
  # 1. 停止并移除 Sing-box 服务
  # ==================================================
  if service_active ${SERVICE_NAME}; then
    service_stop ${SERVICE_NAME}
  fi

  if [[ "$INIT_SYSTEM" == "systemd" ]]; then
    systemctl disable ${SERVICE_NAME} 2>/dev/null
    rm -f /etc/systemd/system/${SERVICE_NAME}.service
    systemctl daemon-reload
  else
    rc-update del ${SERVICE_NAME} 2>/dev/null
    rm -f /etc/init.d/${SERVICE_NAME}
  fi

  # ==================================================
  # 2. 删除运行目录
  # ==================================================
  rm -rf "$WORK_DIR"

  # ==================================================
  # 3. 删除 nginx 订阅配置
  # ==================================================
  rm -f "$NGX_LINK"
  rm -f "$NGX_CONF"

  # ==================================================
  # 4. 重载 nginx（如果存在且在运行）
  # ==================================================
  if command_exists nginx && service_active "$NGINX_SERVICE"; then
    service_restart "$NGINX_SERVICE"
  fi

  green "Sing-box（VLESS Reality）已卸载完成"
  echo ""

  # ==================================================
  # 5. 是否卸载 Nginx（可选）
  # ==================================================
  if command_exists nginx; then
    read -rp "是否同时卸载 Nginx？[y/N]：" delng
    delng=${delng:-n}

    if [[ "$delng" =~ ^[Yy]$ ]]; then
      if command_exists apt; then
        apt remove -y nginx nginx-core
      elif command_exists yum; then
        yum remove -y nginx
      elif command_exists dnf; then
        dnf remove -y nginx
      elif command_exists apk; then
        apk del nginx
      else
        yellow "无法识别包管理器，请手动卸载 Nginx"
      fi
      green "Nginx 已卸载"
    else
      yellow "已保留 Nginx"
    fi
  fi

  pause
}


# =====================================================
# Reality key ----只要 pbk / sid 无效，就强制重新生成 Reality key
# =====================================================

gen_reality(){
  # 如果 sing-box 不存在，直接报错
  if [[ ! -x "$WORK_DIR/sing-box" ]]; then
    red "sing-box 不存在或不可执行，无法生成 Reality 密钥"
    exit 1
  fi

  # 如果已有有效 key，直接返回（避免重复生成）
  if [[ -s "$REALITY_PUBKEY_FILE" && -s "$REALITY_SID_FILE" ]]; then
    return
  fi

  if [[ -n "$REALITY_PBK" && -n "$REALITY_SID" ]]; then
    local k
    k=$("$WORK_DIR/sing-box" generate reality-keypair)
    PRIVATE_KEY=$(awk '/PrivateKey/ {print $2}' <<<"$k")

    PUBLIC_KEY="$REALITY_PBK"
    SHORT_ID="$REALITY_SID"
  else
    local k
    k=$("$WORK_DIR/sing-box" generate reality-keypair)

    PUBLIC_KEY=$(awk '/PublicKey/ {print $2}' <<<"$k")
    PRIVATE_KEY=$(awk '/PrivateKey/ {print $2}' <<<"$k")
    SHORT_ID=$(openssl rand -hex 8)
  fi

  # 最终兜底校验
  if [[ -z "$PUBLIC_KEY" || -z "$SHORT_ID" ]]; then
    red "Reality 密钥生成失败（pbk 或 sid 为空）"
    exit 1
  fi

  echo "$PUBLIC_KEY" > "$REALITY_PUBKEY_FILE"
  echo "$SHORT_ID"  > "$REALITY_SID_FILE"
  echo "$PRIVATE_KEY" > "$REALITY_PRIVATE_FILE"
}


# =====================================================
# config.json
# =====================================================
make_config(){
cat > "$CONFIG" <<EOF
{
  "log": { "level": "error" },
  "inbounds": [{
    "type": "vless",
    "listen": "::",
    "listen_port": $PORT,
    "users": [{
      "uuid": "$UUID",
      "flow": "xtls-rprx-vision"
    }],
    "tls": {
      "enabled": true,
      "server_name": "$(get_sni)",
      "reality": {
        "enabled": true,
        "handshake": {
          "server": "$(get_sni)",
          "server_port": 443
        },
        "private_key": "$(cat "$REALITY_PRIVATE_FILE")",
        "short_id": ["$(cat "$REALITY_SID_FILE")"]
      }
    }
  }],
  "outbounds": [{ "type": "direct" }]
}
EOF
}

# =====================================================
# systemd
# =====================================================


make_service() {
  if [[ "$INIT_SYSTEM" == "systemd" ]]; then
    make_service_systemd
  else
    make_service_openrc
  fi

  service_enable "${SERVICE_NAME}"
  service_start "${SERVICE_NAME}"
}



make_service_systemd(){
cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=Sing-box VLESS Reality
After=network-online.target
Wants=network-online.target


[Service]
ExecStart=$WORK_DIR/sing-box run -c $CONFIG
Restart=always
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

 systemctl daemon-reload
}


make_service_openrc() {

cat > /etc/init.d/${SERVICE_NAME} <<EOF
#!/sbin/openrc-run

name="sing-box vless reality"
description="Sing-box VLESS Reality"

command="$WORK_DIR/sing-box"
command_args="run -c $CONFIG"
command_background="no"

start_pre() {
    checkpath -d -m 0755 /var/log
}

supervisor="supervise-daemon"
output_log="/var/log/${SERVICE_NAME}.log"
error_log="/var/log/${SERVICE_NAME}.err"

depend() {
  need net
}
EOF

chmod +x /etc/init.d/${SERVICE_NAME}
}


# =====================================================
# 订阅
# =====================================================

ensure_nginx_conf_dir() {
  [[ -d "$NGX_NGINX_DIR" ]] || mkdir -p "$NGX_NGINX_DIR"
}


init_subscribe_port() {
  if [[ -z "$NGINX_PORT" ]]; then
    red "NGINX_PORT 为必填参数，请重新运行脚本并输入端口"
    exit 1
  fi

  # 统一走校验逻辑，但不再 prompt
  local p="$NGINX_PORT"

  if ! is_port "$p"; then
    red "NGINX_PORT 无效：$p"
    exit 1
  fi

  if is_used "$p"; then
    red "NGINX_PORT 已被占用：$p"
    exit 1
  fi

  echo "$p" > "$SUB_PORT_FILE"
}



build_subscribe_conf() {
  ensure_nginx_conf_dir

  # =====================================================
  # 1. 订阅端口必须已存在（唯一事实源）
  # =====================================================
  if [[ ! -f "$SUB_PORT_FILE" ]]; then
    red "未找到订阅端口配置（SUB_PORT_FILE）"
    red "请先通过 NGINX_PORT 初始化订阅端口"
    return 1
  fi

  local sub_port
  sub_port=$(cat "$SUB_PORT_FILE")

  if ! is_port "$sub_port"; then
    red "订阅端口无效：$sub_port"
    return 1
  fi

  # =====================================================
  # 2. 生成 nginx 订阅配置
  # =====================================================
  cat > "$NGX_CONF" <<EOF
server {
  listen ${sub_port};
  listen [::]:${sub_port};



  location /${UUID} {
    alias ${SUB_FILE};
    default_type text/plain;
  }
}
EOF

  # =====================================================
  # 3. 建立 systemd / openrc 通用软链接
  # =====================================================
  ln -sf "$NGX_CONF" "$NGX_LINK"

  # =====================================================
  # 4. 防火墙：确保订阅端口已放行（TCP）
  # =====================================================
  allow_tcp_port "$sub_port"

  # =====================================================
  # 5. 重载 nginx（存在且运行中才操作）
  # =====================================================
  if command_exists nginx && service_active "$NGINX_SERVICE"; then
    service_restart "$NGINX_SERVICE"
  fi

  green "订阅服务已就绪（Nginx 端口：${sub_port}）"
}





generate_nodes() {
  local ip4 ip6 name sni
  local pbk sid

  # -----------------------------
  # 获取必要参数
  # -----------------------------
  ip4=$(get_ip4)
  ip6=$(get_ip6)

  name_raw=$(get_node_name)
  #name=$(urlencode "$name_raw")
  name="$name_raw"



  sni=$(get_sni)

  [[ -z "$ip4" && -z "$ip6" ]] && {
    red "无法获取 IPv4 / IPv6 公网地址"
    return 1
  }

  # Reality 公钥与 short_id（必须存在）
  if [[ ! -f "$REALITY_PUBKEY_FILE" || ! -f "$REALITY_SID_FILE" ]]; then
    red "未找到 Reality 公钥或 short_id，请重新安装或生成 Reality 密钥"
    return 1
  fi

  pbk=$(cat "$REALITY_PUBKEY_FILE")
  sid=$(cat "$REALITY_SID_FILE")




  # -----------------------------
  # 生成订阅内容（单行 URI）
  # -----------------------------
  > "$SUB_FILE"

  # IPv4
  if [[ -n "$ip4" ]]; then
    echo "vless://${UUID}@${ip4}:${PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${pbk}&sid=${sid}&type=tcp&headerType=none#${name}" >> "$SUB_FILE"
  fi

  # IPv6
  if [[ -n "$ip6" ]]; then
    echo "vless://${UUID}@[${ip6}]:${PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${pbk}&sid=${sid}&type=tcp&headerType=none#${name}" >> "$SUB_FILE"
  fi

  # -----------------------------
  # Base64 订阅（全量）
  # -----------------------------
  base64 "$SUB_FILE" | tr -d '\n' > "$SUB_B64"


  return 0
}


# =====================================================
# 核心：check_nodes（唯一事实源）
# =====================================================

print_subscribe_guide() {
    purple "================= 使用说明（如何添加订阅） ================="
    echo ""
    green  " · v2rayN / Nekobox / 小火箭：使用【基础订阅链接】"
    green  " · Clash 用户：使用【Clash 订阅】"
    green  " · Sing-box 用户：使用【Sing-box 订阅】"
    echo ""
    yellow "提示："
    yellow " - 基础订阅适用于大多数 VLESS 客户端"
    yellow " - 不确定用哪个时，优先尝试【基础订阅链接】"
    echo ""
}


check_nodes() {
  local mode="$1"   # silent / empty
  # yellow "下面是节点与订阅信息，请根据你使用的客户端选择对应订阅链接："
  # echo ""


  # =====================================================
  # 1️⃣ config.json = 唯一事实源
  # =====================================================
  load_runtime_from_config || {
    [[ "$mode" != "silent" ]] && pause
    return
  }

  # =====================================================
  # 2️⃣ 生成节点与订阅源（永远执行）
  # =====================================================




  generate_nodes || {
    [[ "$mode" != "silent" ]] && pause
    return
  }

  # silent 模式：只生成，不展示
  [[ "$mode" == "silent" ]] && return

  # =====================================================
  # 3️⃣ 展示层（完全 tuic5 级：多客户端 × v4/v6）
  # =====================================================
  local sub_port ip4 ip6
  sub_port=$(cat "$SUB_PORT_FILE")
  ip4=$(get_ip4)
  ip6=$(get_ip6)


  purple "================= 节点信息 ================="
    echo ""
    # 原始节点名（人类语义源）
    local name_raw
    name_raw="$(get_node_name)"

    while read -r line; do
      uri="${line%%#*}"
      name_enc="${line##*#}"

      yellow "【订阅用（URI，已 urlencode，复制到客户端使用请用这串）】"
      green  "${uri}#${name_enc}"
      echo ""

      brown "【人类可读（仅展示用）】"
      green  "${uri}#${name_raw}"
      echo ""
    done < "$SUB_FILE"


  purple "================= Base64 订阅（全量） ================="
  green "$(cat "$SUB_B64")"
  echo ""

  print_subscribe_guide
  # ================= IPv4 =================
  if [[ -n "$ip4" ]]; then
    purple "================= IPv4 订阅 ================="

    local base_v4="http://${ip4}:${sub_port}/${UUID}"
    local clash_v4="${base_v4}?client=clash"
    local singbox_v4="${base_v4}?client=singbox"

    green "【IPv4 · 基础订阅-V2rayN,Shadowrocket,Nekobox,Loon,Karing,Sterisand订阅链接】"
    green "$base_v4"
    generate_qr "$base_v4"
    echo ""

    green "【IPv4 · Clash 订阅】"
    green "$clash_v4"
    generate_qr "$clash_v4"
    echo ""

    green "【IPv4 · Sing-box 订阅】"
    green "$singbox_v4"
    generate_qr "$singbox_v4"
    echo ""
  fi

  # ================= IPv6 =================
  if [[ -n "$ip6" ]]; then
    purple "================= IPv6 订阅 ================="

    local base_v6="http://[${ip6}]:${sub_port}/${UUID}"
    local clash_v6="${base_v6}?client=clash"
    local singbox_v6="${base_v6}?client=singbox"

    green "【IPv6 · 基础订阅-V2rayN,Shadowrocket,Nekobox,Loon,Karing,Sterisand订阅链接】"
    green "$base_v6"
    generate_qr "$base_v6"
    echo ""

    green "【IPv6 · Clash 订阅】"
    green "$clash_v6"
    generate_qr "$clash_v6"
    echo ""

    green "【IPv6 · Sing-box 订阅】"
    green "$singbox_v6"
    generate_qr "$singbox_v6"
    echo ""
  fi

  pause
}




generate_qr() {
  local data="$1"
  [[ -z "$data" ]] && return
  yellow "二维码："
  echo "https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${data}"
}


refresh_all(){
  check_nodes silent
  build_subscribe_conf
  service_restart ${SERVICE_NAME}
}



# =====================================================
# 修改配置
# =====================================================

change_config() {
  while true; do
    clear
    blue "========== 修改节点配置 =========="
    echo ""
    green " 1. 修改监听端口"
    green " 2. 修改 UUID"
    green " 3. 修改节点名称"
    green " 4. 修改 SNI"
    yellow "----------------------------------"
    green " 0. 返回主菜单"
    red   " 88. 退出脚本"
    echo ""

    read -rp "$(red_input "请选择：")" sel
    case "$sel" in
      1) change_port ;;
      2) change_uuid ;;
      3) change_node_name ;;
      4) change_sni ;;
      0) return ;;
      88) exit_script ;;
      *) red "无效输入"; pause ;;
    esac
  done
}

change_port(){
  read -rp "$(red_input "请输入新端口号(回车则默认自动生成)：")" p

  if ! is_port "$p"; then
    red "端口格式无效"
    pause
    return
  fi

  if is_used "$p"; then
    red "端口已被占用"
    pause
    return
  fi

  local old_port
  old_port=$(jq -r '.inbounds[0].listen_port' "$CONFIG")

  PORT="$p"
  jq ".inbounds[0].listen_port=$PORT" "$CONFIG" > /tmp/cfg && mv /tmp/cfg "$CONFIG"

  green "监听端口已从 ${old_port} 修改为：${PORT}"
  yellow "正在应用配置…"

  refresh_all
  pause
}


change_uuid(){
  read -rp "$(red_input "新 UUID（回车自动生成）：")" u

  if [[ -z "$u" ]]; then
    u=$(cat /proc/sys/kernel/random/uuid)
    yellow "未输入 UUID，已自动生成"
  fi

  if ! is_uuid "$u"; then
    red "UUID 格式无效"
    pause
    return
  fi

  local old_uuid
  old_uuid=$(jq -r '.inbounds[0].users[0].uuid' "$CONFIG")

  UUID="$u"
  jq ".inbounds[0].users[0].uuid=\"$UUID\"" "$CONFIG" > /tmp/cfg && mv /tmp/cfg "$CONFIG"

  rm -f "$SUB_FILE" "$SUB_B64"

  green "UUID 已成功修改"
  brown "旧 UUID：$old_uuid"
  brown "新 UUID：$UUID"
  yellow "正在刷新配置…"

  refresh_all
  pause
}





change_node_name(){
  read -rp "$(red_input "新节点名：")" n

  if [[ -z "$n" ]]; then
    yellow "节点名称未修改（输入为空）"
    pause
    return
  fi

  echo "$n" > "$NODE_NAME_FILE"

  green "节点名称已成功修改为：$n"
  yellow "正在刷新节点配置…"

  refresh_all

  pause
}


change_sni(){
  clear
  blue "========== 修改 SNI =========="
  echo ""

  local old_sni
  old_sni=$(get_sni)

  yellow "当前 SNI：$old_sni"
  echo ""

  green " 1. www.bing.com        （默认 / 推荐）"
  green " 2. www.microsoft.com"
  green " 3. www.office.com"
  green " 4. www.apple.com"
  green " 5. www.visa.com"
  yellow "----------------------------------"
  green " 6. 自定义输入"
  red   " 0. 取消修改"
  echo ""

  read -rp "$(red_input "请选择 SNI：")" sel

  local new_sni=""

  case "$sel" in
    1) new_sni="www.bing.com" ;;
    2) new_sni="www.microsoft.com" ;;
    3) new_sni="www.office.com" ;;
    4) new_sni="www.apple.com" ;;
    5) new_sni="www.visa.com" ;;
    6)
      read -rp "$(red_input "请输入自定义 SNI：")" new_sni
      if [[ -z "$new_sni" ]]; then
        yellow "未输入 SNI，已取消修改"
        pause
        return
      fi
      ;;
    0)
      yellow "已取消修改 SNI"
      pause
      return
      ;;
    *)
      red "无效选择"
      pause
      return
      ;;
  esac

  # 如果没变化，直接返回
  if [[ "$new_sni" == "$old_sni" ]]; then
    yellow "新 SNI 与当前一致，未做修改"
    pause
    return
  fi

  # 写入并刷新
  echo "$new_sni" > "$SNI_FILE"
  make_config

  green "SNI 已成功修改"
  brown "旧 SNI：$old_sni"
  brown "新 SNI：$new_sni"
  yellow "正在应用配置…"

  refresh_all
  pause
}




# =====================================================
# 防火墙：TCP 端口放行 / 回收（订阅 & VLESS）
# =====================================================

allow_tcp_port() {
  local port="$1"

  # IPv4
  iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null || \
    iptables -I INPUT -p tcp --dport "$port" -j ACCEPT

  # IPv6
  ip6tables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null || \
    ip6tables -I INPUT -p tcp --dport "$port" -j ACCEPT

  green "已放行 TCP 端口：$port"
}

remove_tcp_port() {
  local port="$1"

  # IPv4
  while iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null; do
    iptables -D INPUT -p tcp --dport "$port" -j ACCEPT
  done

  # IPv6
  while ip6tables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null; do
    ip6tables -D INPUT -p tcp --dport "$port" -j ACCEPT
  done

  green "已回收 TCP 端口：$port"
}



# =====================================================
# 安装流程
# =====================================================


install_common(){
  install_common_packages
  install_singbox

  init_dirs
  init_node_name
  init_sni

  gen_reality
  make_config
  make_service
}


quick_install(){


 # ===== 必填参数，未提供则阻塞 =====
  prompt_vless_port
  prompt_nginx_port

  # UUID 仍然允许自动生成（这是合理的）
  UUID=${UUID:-$(cat /proc/sys/kernel/random/uuid)}


  install_common
  init_subscribe_port
  refresh_all

   # ===== 强制启用订阅 =====
  service_start "$NGINX_SERVICE"

  service_enable "$NGINX_SERVICE"

  
}


interactive_install(){
  # -------- 端口 --------
  
  prompt_vless_port
  prompt_nginx_port

  # -------- UUID --------
  while true; do
    read -rp "$(red_input "请输入UUID（留空回车则自动生成）：")" UUID

    if [[ -z "$UUID" ]]; then
      UUID=$(cat /proc/sys/kernel/random/uuid)
      green "已自动生成 UUID：$UUID"
      break
    fi

    if is_uuid "$UUID"; then
      break
    else
      red "UUID 格式不正确，请重新输入"
    fi
  done

 

  install_common
  init_subscribe_port
  refresh_all
  
  # 启动服务（交互安装期望的行为）
  service_start ${SERVICE_NAME}
  service_start "$NGINX_SERVICE"

}

print_subscribe_status() {
  if [[ -f "$NGX_CONF" ]]; then
    green "当前订阅状态：已启用"
  else
    yellow "当前订阅状态：未启用"
  fi
}

is_subscribe_enabled() {
  [[ -f "$NGX_CONF" ]]
}



change_subscribe_port() {
  read -rp "$(red_input "请输入新的订阅端口：")" new_port

  if ! is_port "$new_port"; then
    red "端口无效"
    return
  fi

  if is_used "$new_port"; then
    red "端口已被占用"
    return
  fi

  local old_port=""
  [[ -f "$SUB_PORT_FILE" ]] && old_port=$(cat "$SUB_PORT_FILE")

  # 写入新端口
  echo "$new_port" > "$SUB_PORT_FILE"

  # 防火墙处理
  allow_tcp_port "$new_port"

  if [[ -n "$old_port" && "$old_port" != "$new_port" ]]; then
    remove_tcp_port "$old_port"
  fi

  if is_subscribe_enabled; then
    build_subscribe_conf
    green "订阅端口已修改：${old_port:-无} → $new_port"
  else
    yellow "订阅未启用，端口已保存，启用后生效"
  fi
}




disable_subscribe() {
  rm -f "$NGX_CONF"
  rm -f "$NGX_LINK"

  if service_active "$NGINX_SERVICE"; then
    service_restart "$NGINX_SERVICE"
  fi

[[ -f "$SUB_PORT_FILE" ]] && remove_tcp_port "$(cat "$SUB_PORT_FILE")"


  green "订阅服务已关闭"
}


manage_subscribe_menu() {
  while true; do
    clear
    blue "========== 订阅服务管理（VLESS / Nginx） =========="
    echo ""

    print_subscribe_status
    echo ""

    green " 1. 启动 Nginx"
    green " 2. 停止 Nginx"
    green " 3. 重启 Nginx"

    yellow "---------------------------------------------"
    green " 4. 启用 / 重建订阅服务"
    green " 5. 修改订阅端口"
    green " 6. 关闭订阅服务"

    yellow "---------------------------------------------"
    green " 0. 返回上级菜单"
    red   " 88. 退出脚本"
    echo ""

    read -rp "$(red_input "请选择：")" sel
    case "$sel" in
      1)
        service_start "$NGINX_SERVICE"
        if service_active "$NGINX_SERVICE"; then
          green "Nginx 已启动"
        else
          red "Nginx 启动失败"
        fi
        pause
        ;;
      2)
        service_stop "$NGINX_SERVICE"
        if service_active "$NGINX_SERVICE"; then
          red "Nginx 停止失败"
        else
          green "Nginx 已停止"
        fi
        pause
        ;;
      3)
        service_restart "$NGINX_SERVICE"
        if service_active "$NGINX_SERVICE"; then
          green "Nginx 已重启"
        else
          red "Nginx 重启失败"
        fi
        pause
        ;;
      4)
        build_subscribe_conf
        green "订阅服务已启用 / 重建"
        pause
        ;;
      5)
        change_subscribe_port
        pause
        ;;
      6)
        disable_subscribe
        pause
        ;;
      0)
        return
        ;;
      88)
        exit_script
        ;;
      *)
        red "无效输入"
        pause
        ;;
    esac
  done
}


# =====================================================
# 菜单
# =====================================================
menu(){
    clear
    blue "===================================================="
    gradient "       Sing-box 一键脚本（vless-reality版）"
    green    "       作者：$AUTHOR"
    yellow   "       版本：$VERSION"
    blue "===================================================="
    echo ""
    sb="$(get_singbox_status_colored)"
    ng="$(get_nginx_status_colored)"
    ss="$(get_subscribe_status_colored)"

    yellow " Sing-box 状态：$sb"
    yellow " Nginx 状态：   $ng"
    yellow " 订阅 状态：   $ss"
    echo ""
    green " 1. 安装Sing-box"
    red   " 2. 卸载Sing-box"
    yellow "----------------------------"
    green  " 3. 管理 Sing-box 服务"
    green  " 4. 查看节点信息"
    yellow "----------------------------------------"
    green  " 5. 修改节点配置"
    green  " 6. 管理订阅服务"
    yellow "----------------------------------------"
    red    " 88. 退出脚本"
    echo ""
    read -rp "选择：" c
    case "$c" in
      1) interactive_install
        blue "========== 安装完成 · 节点信息 =========="
        echo ""
        check_nodes
       ;;
      2) uninstall_singbox ;;
      3) manage_singbox ;;
      4) check_nodes ;;
      5) change_config ;;
      6) manage_subscribe_menu ;;
      88) exit_script ;;
      *) red "无效选项，请重新输入" ;;
    esac
}



get_singbox_status_colored() {
  if [[ "$INIT_SYSTEM" == "systemd" ]]; then
    if ! systemctl list-unit-files --type=service 2>/dev/null | grep -q "^${SERVICE_NAME}\.service"; then
      red "未安装"
      return
    fi

    if systemctl is-active --quiet "${SERVICE_NAME}"; then
      green "运行中"
    else
      red "未运行"
    fi
  else
    if [[ ! -f "/etc/init.d/${SERVICE_NAME}" ]]; then
      red "未安装"
      return
    fi

    if rc-service "${SERVICE_NAME}" status 2>/dev/null | grep -q "started"; then
      green "运行中"
    else
      red "未运行"
    fi
  fi
}

get_nginx_status_colored() {
  if ! command_exists nginx; then
    red "未安装"
    return
  fi

  if [[ "$INIT_SYSTEM" == "systemd" ]]; then
    if systemctl is-active --quiet "$NGINX_SERVICE"; then
      green "运行中"
    else
      red "未运行"
    fi
  else
    if rc-service "$NGINX_SERVICE" status 2>/dev/null | grep -q "started"; then
      green "运行中"
    else
      red "未运行"
    fi
  fi
}




get_subscribe_status_colored() {
    if [[ -f "$NGX_CONF" ]]; then
        green "已启用"
    else
        yellow "未启用"
    fi
}


manage_singbox() {
  while true; do
    clear
    blue "========== Sing-box 服务管理 =========="
    echo ""
    green " 1. 启动"
    green " 2. 停止"
    green " 3. 重启"
    yellow "----------------------------------------"
    green " 0. 返回"
    red   " 88. 退出脚本"
    echo ""
    echo ""

    read -rp "$(red_input "请选择：")" sel
    case "$sel" in
      1)
        service_start ${SERVICE_NAME}
        if service_active ${SERVICE_NAME}; then
          green "服务已启动"
        else
          red "启动失败"
        fi
        pause
        ;;
      2)
        service_stop ${SERVICE_NAME}
        if service_active ${SERVICE_NAME}; then
          red "停止失败"
        else
          green "服务已停止"
        fi
        pause
        ;;
      3)
        service_restart ${SERVICE_NAME}
        if service_active ${SERVICE_NAME}; then
          green "服务已重启"
        else
          red "重启失败"
        fi
        pause
        ;;
      0)
        return
        ;;
      88)
       exit_script
        ;;
      *)
        red "无效输入"
        pause
        ;;
    esac
  done
}


main_loop() {
  while true; do
    menu
  done
}




# =====================================================
# main
# =====================================================
main() {
  detect_init
  init_platform

  is_interactive
  if [[ $? -eq 1 ]]; then
    quick_install
    blue "自动安装完成，以下是节点信息："
    check_nodes
    main_loop
  else
    main_loop
  fi
}




main
