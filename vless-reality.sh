#!/bin/bash
export LANG=en_US.UTF-8

# ======================================================================
# Sing-box vless-reality 一键脚本
# 作者：littleDoraemon
# 说明：
#   - 支持自动 / 交互模式
#   - 支持跳跃端口：使用nat端口转发给主端口，也就是服务端一下子给你把跳跃端口范围的端口都指向了主端口号的转发(跟hy2的服务器天然支持跳跃端口功能不太一样)
#   - #   - 支持环境变量： PORT / UUID / NODE_NAME / SNI/ REALITY_PBK / REALITY_SID
# 
#  
#  1、安装方式（2种）
#     1.1 交互式菜单安装：
#     curl -fsSL https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/vless-reality.sh -o vless-reality.sh && chmod +x vless-reality.sh && ./vless-reality.sh
#    
#     1.2 非交互式全自动安装(支持环境变量： PORT / UUID / NODE_NAME / SNI/ REALITY_PBK / REALITY_SID):
#     PORT=31090 SNI=www.visa.com NODE_NAME="小叮当的节点" bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/vless-reality.sh)
#
# Optional env(可选环境变量):
#   REALITY_PBK   Reality public key
#   REALITY_SID   Reality short id (hex)
# 
# 
# ======================================================================

AUTHOR="littleDoraemon"
VERSION="v2.3.8"
SINGBOX_VERSION="1.12.13"

SERVICE_NAME="sing-box-vless-reality"
WORK_DIR="/etc/sing-box-vless-reality"
CONFIG="$WORK_DIR/config.json"

NODE_NAME_FILE="$WORK_DIR/node_name"
SNI_FILE="$WORK_DIR/sni"

SUB_FILE="$WORK_DIR/sub.txt"
SUB_B64="$WORK_DIR/sub_base64.txt"
SUB_PORT_FILE="$WORK_DIR/sub.port"

NGX_CONF="$WORK_DIR/vless_reality_sub.conf"
NGX_LINK="/etc/nginx/conf.d/vless_reality_sub.conf"

REALITY_PUBKEY_FILE="$WORK_DIR/reality_public.key"
REALITY_SID_FILE="$WORK_DIR/reality_short_id"


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
is_used(){ ss -tuln | grep -q ":$1 "; }
is_uuid(){ [[ "$1" =~ ^[a-fA-F0-9-]{36}$ ]]; }

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
# 模式判定
# =====================================================
is_interactive(){
  [[ -n "$PORT" || -n "$UUID" || -n "$NODE_NAME" || -n "$SNI" ]] && return 1 || return 0
}

# =====================================================
# 基础初始化
# =====================================================
init_dirs(){
  mkdir -p "$WORK_DIR"
}

init_node_name(){
  [[ -f "$NODE_NAME_FILE" ]] && return
  if [[ -n "$NODE_NAME" ]]; then
    echo "$NODE_NAME" > "$NODE_NAME_FILE"
  else
    echo "VLESS-Reality" > "$NODE_NAME_FILE"
  fi
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



# =====================================================
# 安装 sing-box
# =====================================================
install_singbox(){
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64) ARCH=amd64 ;;
    aarch64) ARCH=arm64 ;;
    *) red "不支持架构"; exit 1 ;;
  esac

  mkdir -p "$WORK_DIR"

  local tmpdir
  tmpdir=$(mktemp -d)

  curl -fsSL -o "$tmpdir/sb.tgz" \
    https://github.com/SagerNet/sing-box/releases/download/v${SINGBOX_VERSION}/sing-box-${SINGBOX_VERSION}-linux-${ARCH}.tar.gz

  tar -xzf "$tmpdir/sb.tgz" -C "$tmpdir"

  mv "$tmpdir"/sing-box-*/sing-box "$WORK_DIR/sing-box"
  chmod +x "$WORK_DIR/sing-box"

  rm -rf "$tmpdir"
}


uninstall_singbox(){
  clear
  blue "====== 卸载 Sing-box（VLESS Reality） ======"
  echo ""

  read -rp "确认卸载 Sing-box（VLESS Reality）？[Y/n]：" u
  u=${u:-y}
  [[ ! "$u" =~ ^[Yy]$ ]] && return

  # ----------------------------
  # 停止并移除 Sing-box 服务
  # ----------------------------
  systemctl stop ${SERVICE_NAME} 2>/dev/null
  systemctl disable ${SERVICE_NAME} 2>/dev/null
  rm -f /etc/systemd/system/${SERVICE_NAME}.service
  systemctl daemon-reload

  # ----------------------------
  # 删除运行目录
  # ----------------------------
  rm -rf "$WORK_DIR"

  # ----------------------------
  # 删除 nginx 订阅配置
  # ----------------------------
  rm -f "$NGX_LINK"
  rm -f "$NGX_CONF"

  if systemctl is-active nginx >/dev/null 2>&1; then
    systemctl reload nginx
  fi

  green "Sing-box（VLESS Reality）已卸载完成"
  echo ""

  # ----------------------------
  # 是否卸载 Nginx（默认不卸载）
  # ----------------------------
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
# Reality key
# =====================================================

gen_reality(){
  if [[ -n "$REALITY_PBK" && -n "$REALITY_SID" ]]; then
    # 仅为 private_key 生成
    local k
    k=$("$WORK_DIR/sing-box" generate reality-keypair)
    PRIVATE_KEY=$(awk '/PrivateKey/ {print $2}' <<<"$k")

    PUBLIC_KEY="$REALITY_PBK"
    SHORT_ID="$REALITY_SID"
  else
    local k
    k=$("$WORK_DIR/sing-box" generate reality-keypair)
    PRIVATE_KEY=$(awk '/PrivateKey/ {print $2}' <<<"$k")
    PUBLIC_KEY=$(awk '/PublicKey/ {print $2}' <<<"$k")
    SHORT_ID=$(openssl rand -hex 8)
  fi

  echo "$PUBLIC_KEY" > "$REALITY_PUBKEY_FILE"
  echo "$SHORT_ID"  > "$REALITY_SID_FILE"
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
        "private_key": "$PRIVATE_KEY",
        "short_id": ["'"$SHORT_ID"'"]
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
make_service(){
cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=Sing-box VLESS Reality
After=network.target

[Service]
ExecStart=$WORK_DIR/sing-box run -c $CONFIG
Restart=always
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable ${SERVICE_NAME}
}


# =====================================================
# 订阅
# =====================================================
build_subscribe_conf(){
  [[ -f "$SUB_PORT_FILE" ]] || echo $((PORT+1)) > "$SUB_PORT_FILE"
cat > "$NGX_CONF" <<EOF
server {
  listen $(cat "$SUB_PORT_FILE");
  listen [::]:$(cat "$SUB_PORT_FILE");
  location /$UUID {
    alias $SUB_FILE;
    default_type text/plain;
  }
}
EOF
  ln -sf "$NGX_CONF" "$NGX_LINK"
  systemctl reload nginx
}



generate_nodes() {
  local ip4 ip6 name sni
  local pbk sid

  # -----------------------------
  # 获取必要参数
  # -----------------------------
  ip4=$(get_ip4)
  ip6=$(get_ip6)
  name=$(get_node_name)
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
  # 确保订阅端口存在
  # -----------------------------
  [[ -f "$SUB_PORT_FILE" ]] || echo $((PORT + 1)) > "$SUB_PORT_FILE"

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
  base64 -w0 "$SUB_FILE" > "$SUB_B64"

  return 0
}


# =====================================================
# 核心：check_nodes（唯一事实源）
# =====================================================

check_nodes() {
  local mode="$1"   # silent / empty

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

  purple "================= 节点信息（VLESS Reality） ================="
  green "$(cat "$SUB_FILE")"
  echo ""

  purple "================= Base64 订阅（全量） ================="
  green "$(cat "$SUB_B64")"
  echo ""

  # ================= IPv4 =================
  if [[ -n "$ip4" ]]; then
    purple "================= IPv4 订阅 ================="

    local base_v4="http://${ip4}:${sub_port}/${UUID}"
    local clash_v4="${base_v4}?client=clash"
    local singbox_v4="${base_v4}?client=singbox"

    green "【IPv4 · 基础订阅】"
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

    green "【IPv6 · 基础订阅】"
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
  systemctl restart ${SERVICE_NAME}
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
      88) exit 0 ;;
      *) red "无效输入"; pause ;;
    esac
  done
}



change_port(){
  read -rp "$(red_input "新端口：")" p
  is_port "$p" && ! is_used "$p" || { red "端口无效"; return; }

  PORT="$p"
  jq ".inbounds[0].listen_port=$PORT" "$CONFIG" > /tmp/cfg && mv /tmp/cfg "$CONFIG"

  refresh_all
}

change_uuid(){
  read -rp "$(red_input "新 UUID（回车自动生成）：")" u
  [[ -z "$u" ]] && u=$(cat /proc/sys/kernel/random/uuid)
  is_uuid "$u" || { red "UUID 无效"; return; }

  UUID="$u"
  jq ".inbounds[0].users[0].uuid=\"$UUID\"" "$CONFIG" > /tmp/cfg && mv /tmp/cfg "$CONFIG"

  rm -f "$SUB_FILE" "$SUB_B64"

  refresh_all
}





change_node_name(){
  read -rp "$(red_input "新节点名：")" n
  [[ -z "$n" ]] && return
  echo "$n" > "$NODE_NAME_FILE"
  refresh_all
}




change_sni(){
  read -rp "$(red_input "新 SNI：")" n
  [[ -z "$n" ]] && return
  echo "$n" > "$SNI_FILE"
  make_config
  refresh_all
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
  # 参数兜底（自动模式）
  PORT=${PORT:-$(shuf -i 1-65535 -n1)}
  UUID=${UUID:-$(cat /proc/sys/kernel/random/uuid)}

  install_common
  refresh_all
}


interactive_install(){
  # -------- 端口 --------
  while true; do
    read -rp "$(red_input "请输入vless端口（留空回车则自动生成）：")" PORT

    # 回车 → 自动生成端口
    if [[ -z "$PORT" ]]; then
      while true; do
        PORT=$(shuf -i 10000-65535 -n1)
        ! is_used "$PORT" && break
      done
      green "已自动选择端口：$PORT"
      break
    fi

    # 手动输入 → 校验
    if is_port "$PORT" && ! is_used "$PORT"; then
      break
    else
      red "端口无效或已被占用，请重新输入"
    fi
  done

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
  refresh_all
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

  echo "$new_port" > "$SUB_PORT_FILE"

  if is_subscribe_enabled; then
    build_subscribe_conf
    green "订阅端口已修改为：$new_port"
  else
    yellow "订阅未启用，端口已保存，启用订阅后生效"
  fi
}


disable_subscribe() {
  rm -f "$NGX_CONF"
  rm -f "$NGX_LINK"

  if systemctl is-active nginx >/dev/null 2>&1; then
    systemctl reload nginx
  fi

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
        systemctl start nginx
        systemctl is-active nginx >/dev/null 2>&1 \
          && green "Nginx 已启动" \
          || red "Nginx 启动失败"
        pause
        ;;
      2)
        systemctl stop nginx
        green "Nginx 已停止"
        pause
        ;;
      3)
        systemctl restart nginx
        systemctl is-active nginx >/dev/null 2>&1 \
          && green "Nginx 已重启" \
          || red "Nginx 重启失败"
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
        exit 0
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
      1) interactive_install ;;
      2) uninstall_singbox ;;
      3) manage_singbox ;;
      4) check_nodes ;;
      5) change_config ;;
      6) manage_subscribe_menu ;;
      88) exit 0 ;;
      *) red "无效选项，请重新输入" ;;
    esac
}

get_singbox_status_colored() {
    # 未安装：systemd 服务文件不存在
    if ! systemctl list-unit-files --type=service 2>/dev/null | grep -q "^${SERVICE_NAME}\.service"; then
        red "未安装"
        return
    fi

    # 已安装，正在运行
    if systemctl is-active ${SERVICE_NAME} 2>&1; then
        green "运行中"
    else
        red "未运行"
    fi
}



get_nginx_status_colored() {
    if ! command_exists nginx; then
        red "未安装"
        return
    fi

    if systemctl is-active nginx >/dev/null 2>&1; then
        green "运行中"
    else
        red "未运行"
    fi
}


get_subscribe_status_colored() {
    if [[ -f "$sub_nginx_conf" ]]; then
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
        systemctl start ${SERVICE_NAME}
        systemctl is-active ${SERVICE_NAME} >/dev/null 2>&1 \
          && green "服务已启动" \
          || red "启动失败"
        pause
        ;;
      2)
        systemctl stop ${SERVICE_NAME}
        green "服务已停止"
        pause
        ;;
      3)
        systemctl restart ${SERVICE_NAME}
        systemctl is-active ${SERVICE_NAME} >/dev/null 2>&1 \
          && green "服务已重启" \
          || red "重启失败"
        pause
        ;;
      0)
        return
        ;;
      88)
        exit 0
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
  is_interactive
  if [[ $? -eq 1 ]]; then
    # 非交互式（自动模式）
    quick_install

    echo ""
    yellow "安装完成，按任意键进入菜单..."
    pause          # ⭐ 关键：这里暂停，但不清屏

    main_loop      # 之后才进入 menu → clear
  else
    # 交互模式
    main_loop
  fi
}



main