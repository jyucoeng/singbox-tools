#!/bin/bash
# sing-box socks5 脚本
# - 固定 sing-box 版本
# - IPv6 自动检测
# - 多架构
# - 自动重启（当前socks5服务支持系统重启后自动拉起socks5服务）
# 用法如下：
# 1、安装（可覆盖安装，端口号不指定则会随机端口，用户名和密码不指定也会随机生成）：
#   PORT=端口号 USERNAME=用户名 PASSWORD=密码 bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/socks5.sh)
#   
# 2、卸载：
#   bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/socks5.sh) uninstall
# 3、手动查看socks5节点：
#   bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/socks5.sh) node
#
# 4、命令行中如何测试socks5串通不通？？只要选下方的命令执行，成功返回ip就代表成功，不用在意是否返回的是什么ip，比如你明明是ipv6环境的服务器确返回了一个ipv4.这种情况其实也是对的。
#  curl --socks5-hostname "ipv4:端口号"  -U 用户名:密码 http://ip.sb
#  curl -6 --socks5-hostname "[ipv6]:端口号" -U 用户名:密码 http://ip.sb
#

set -e


########################
# root 校验
########################
[ "$(id -u)" -ne 0 ] && { echo "❌ 请使用 root 运行"; exit 1; }

########################
# 全局常量
########################
INSTALL_DIR="/usr/local/sb"
CONFIG_FILE="$INSTALL_DIR/config.json"
BIN_FILE="$INSTALL_DIR/sing-box-socks5"
LOG_FILE="$INSTALL_DIR/run.log"

SERVICE_NAME="sing-box-socks5"
SERVICE_SYSTEMD="/etc/systemd/system/${SERVICE_NAME}.service"
SERVICE_OPENRC="/etc/init.d/${SERVICE_NAME}"

SB_VERSION="1.12.13"
SB_VER="v${SB_VERSION}"

########################
# 颜色
########################
green(){ echo -e "\e[1;32m$1\033[0m"; }
yellow(){ echo -e "\e[1;33m$1\033[0m"; }
red(){ echo -e "\e[31m$1\033[0m"; }
blue(){ echo -e "\e[1;34m$1\033[0m"; }

########################
# 工具函数
########################
gen_username() { tr -dc 'A-Za-z0-9' </dev/urandom | head -c 10; }
# 注意：字符集不能含 @ 和 # —— 密码会以 socks5://user:pass@ip:port URI 形式输出，
# @ 破坏 userinfo 分隔、# 触发 URI fragment 截断，导致展示的节点链接不可用
gen_password() { tr -dc 'A-Za-z0-9!%^_+' </dev/urandom | head -c 12; }

########################
# 端口检测（多方案兜底）
########################
check_port_free() {
  local port="$1"

  if command -v ss >/dev/null 2>&1; then
    ss -lnt 2>/dev/null | awk '{print $4}' | grep -qE "(:|\])$port$" && return 1
    return 0
  fi

  if command -v netstat >/dev/null 2>&1; then
    netstat -lnt 2>/dev/null | awk '{print $4}' | grep -qE "(:|\])$port$" && return 1
    return 0
  fi

  grep -q ":$(printf '%04X' "$port")" /proc/net/tcp /proc/net/tcp6 2>/dev/null && return 1
  return 0
}

gen_random_port() {
  while :; do
    local p
    p=$(shuf -i 1-65535 -n 1)
    check_port_free "$p" && { echo "$p"; return; }
  done
}

########################
# init 系统检测
########################
detect_init_system() {
  if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    INIT_SYSTEM="systemd"
  elif command -v rc-service >/dev/null 2>&1; then
    INIT_SYSTEM="openrc"
  else
    INIT_SYSTEM=""
  fi
}


########################
# 停止旧服务
########################
stop_existing_service() {
  detect_init_system
  case "$INIT_SYSTEM" in
    systemd)
      systemctl is-active --quiet "$SERVICE_NAME" && systemctl stop "$SERVICE_NAME" || true
      ;;
    openrc)
      rc-service "$SERVICE_NAME" status >/dev/null 2>&1 && rc-service "$SERVICE_NAME" stop || true
      ;;
  esac
}

########################
# 参数处理（修复版）
########################
handle_params() {

  NON_INTERACTIVE=0

  if [[ -n "$PORT" || -n "$USERNAME" || -n "$PASSWORD" ]]; then
    NON_INTERACTIVE=1
    yellow "👉 非交互式安装"
  else
    yellow "👉 交互式安装"
  fi

  ########################
  # PORT 处理（不再 exit）
  ########################
  while :; do
    if [[ -z "$PORT" ]]; then
      if [[ "$NON_INTERACTIVE" == "1" ]]; then
        PORT=$(gen_random_port)
        yellow "👉 未指定 PORT，自动生成: $PORT"
      else
        read -rp "请输入端口号: " PORT
      fi
    fi

    if ! [[ "$PORT" =~ ^[0-9]+$ ]] || ((10#$PORT < 1 || 10#$PORT > 65535)); then
      red "❌ 端口必须是 1-65535 的数字"
      PORT=""
      continue
    fi
    # 规范化（去掉前导零，避免 080 之类被当作八进制/写入非法 JSON）
    PORT=$((10#$PORT))

    if ! check_port_free "$PORT"; then
      if [[ "$NON_INTERACTIVE" == "1" ]]; then
        yellow "👉 端口被占用，重新生成"
        PORT=""
        continue
      else
        red "❌ 端口被占用，请重新输入"
        PORT=""
        continue
      fi
    fi

    break
  done

  ########################
  # USER / PASS
  ########################
  if [[ "$NON_INTERACTIVE" == "1" ]]; then
    USERNAME="${USERNAME:-$(gen_username)}"
    PASSWORD="${PASSWORD:-$(gen_password)}"
  else
    read -rp "用户名（回车自动生成）: " INPUT_USERNAME
    USERNAME="${INPUT_USERNAME:-$(gen_username)}"
    read -rp "密码（回车自动生成）: " INPUT_PASSWORD
    PASSWORD="${INPUT_PASSWORD:-$(gen_password)}"
  fi
}

########################
# 安装依赖
########################
install_deps() {
  local need=0
  for b in curl tar gzip jq; do
    command -v "$b" >/dev/null 2>&1 || need=1
  done
  [[ "$need" == "0" ]] && return

  yellow "👉 正在安装依赖..."

  if command -v apt >/dev/null 2>&1; then
    apt update -y
    apt install -y curl tar gzip jq iproute2
  elif command -v yum >/dev/null 2>&1; then
    yum install -y curl tar gzip jq iproute
  elif command -v apk >/dev/null 2>&1; then
    apk add --no-cache curl tar gzip jq iproute2
  else
    red "❌ 不支持的系统"
    exit 1
  fi

  install_glibc

}

install_glibc() {
  # 检查是否为 Alpine 系统
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" == "alpine" ]]; then
      yellow "👉 当前系统为 Alpine，正在安装 glibc 兼容包..."
      echo "http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories
      apk update
      apk add libc6-compat
    else
      yellow "👉 当前系统不是 Alpine，跳过 glibc 兼容包安装"
    fi
  else
    yellow "❌ 无法识别系统，跳过 glibc 兼容包安装"
  fi
}


########################
# 安装 sing-box
########################
install_singbox() {
  mkdir -p "$INSTALL_DIR"

  case "$(uname -m)" in
    x86_64) SB_ARCH="amd64" ;;
    aarch64) SB_ARCH="arm64" ;;
    armv7l) SB_ARCH="armv7" ;;
    *) red "❌ 不支持的架构"; exit 1 ;;
  esac

  TMP_DIR=$(mktemp -d)
  trap 'rm -rf "$TMP_DIR"' EXIT

  URL="https://github.com/SagerNet/sing-box/releases/download/${SB_VER}/sing-box-${SB_VERSION}-linux-${SB_ARCH}.tar.gz"
  yellow "👉 下载 sing-box ${SB_VERSION}"

  curl -fL --retry 3 --connect-timeout 10 -o "$TMP_DIR/sb.tgz" "$URL"
  tar -xf "$TMP_DIR/sb.tgz" -C "$TMP_DIR"
  cp "$TMP_DIR"/sing-box-*/sing-box "$BIN_FILE"
  chmod +x "$BIN_FILE"

  rm -rf "$TMP_DIR"
  trap - EXIT

  green "✅ sing-box 安装完成"
}

########################
# 生成配置
########################
generate_config() {
  mkdir -p "$INSTALL_DIR"
  # 用 jq 生成 JSON：用户名/密码来自用户输入，直接内插进 heredoc 会因引号等特殊字符产生非法 JSON
  jq -n --arg log "$LOG_FILE" --arg port "$PORT" --arg user "$USERNAME" --arg pass "$PASSWORD" '{
    log: { level: "info", output: $log },
    inbounds: [{
      type: "socks",
      listen: "::",
      listen_port: ($port | tonumber),
      users: [{ username: $user, password: $pass }]
    }],
    outbounds: [{ type: "direct" }]
  }' > "$CONFIG_FILE"
  # 配置内含 socks5 账号密码，禁止其他用户读取
  chmod 600 "$CONFIG_FILE" 2>/dev/null || true
}

########################
# 服务
########################
write_systemd_service() {
  cat > "$SERVICE_SYSTEMD" <<EOF
[Unit]
Description=Sing-box Socks5 Service
After=network-online.target

[Service]
ExecStart=$BIN_FILE run -c $CONFIG_FILE
Restart=always
RestartSec=3
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
}

write_openrc_service() {
  cat > "$SERVICE_OPENRC" <<EOF
#!/sbin/openrc-run

command="$BIN_FILE"
command_args="run -c $CONFIG_FILE"

command_background="yes"
pidfile="/run/${SERVICE_NAME}.pid"

depend() {
  need net
}
EOF
  chmod +x "$SERVICE_OPENRC"
}

start_service() {
  detect_init_system
  case "$INIT_SYSTEM" in
    systemd)
      write_systemd_service
      systemctl daemon-reload
      systemctl enable "$SERVICE_NAME"
      systemctl restart "$SERVICE_NAME"
      ;;
    openrc)
      write_openrc_service
      rc-update add "$SERVICE_NAME" default
      rc-service "$SERVICE_NAME" restart
      ;;
    *) red "❌ 未识别 init 系统"; exit 1 ;;
  esac
}

########################
# 管理命令输出（已恢复）
########################
print_manage_commands() {
  echo
  yellow "管理命令："

  if [[ "$INIT_SYSTEM" == "systemd" ]]; then
    green "查看状态:  systemctl status $SERVICE_NAME"
    green "重启服务:  systemctl restart $SERVICE_NAME"
    green "查看日志:  journalctl -u $SERVICE_NAME -f"
  else
    green "查看状态:  rc-service $SERVICE_NAME status"
    green "重启服务:  rc-service $SERVICE_NAME restart"
    green "查看日志:  tail -f $LOG_FILE"
  fi
}

########################
# 节点信息
########################

show_node() {
  # Ensure config file exists
  if [[ ! -f "$CONFIG_FILE" ]]; then
    red "❌ 配置文件未找到或者未安装"
    exit 1
  fi

  # Extract port, username, and password from the config file using jq
  PORT=$(jq -r '.inbounds[0].listen_port' "$CONFIG_FILE")
  USERNAME=$(jq -r '.inbounds[0].users[0].username' "$CONFIG_FILE")
  PASSWORD=$(jq -r '.inbounds[0].users[0].password' "$CONFIG_FILE")

  # Fetch IPv4 and IPv6 addresses using curl
  IP_V4=$(curl -s4 --max-time 3 ipv4.ip.sb || true)
  IP_V6=$(curl -s6 --max-time 3 ipv6.ip.sb || true)

  echo
  green "👉 Socks5 节点信息"
  if [[ -n "$IP_V4" ]]; then
    blue "IPv4: socks5://$USERNAME:$PASSWORD@$IP_V4:$PORT"
  fi
  if [[ -n "$IP_V6" ]]; then
    yellow "IPv6: socks5://$USERNAME:$PASSWORD@[${IP_V6}]:$PORT"
  fi

  print_manage_commands
}


########################
# node 子命令依赖
########################
ensure_node_deps() {
  command -v jq >/dev/null 2>&1 && return
  install_deps
}

ensure_installed() {
  [[ -f "$CONFIG_FILE" ]] || { red "❌ 未检测到配置文件"; exit 1; }
}

########################
# 卸载
########################
uninstall() {
  yellow "👉 开始卸载 socks5 服务..."
  detect_init_system

  case "$INIT_SYSTEM" in
    systemd)
      systemctl stop "$SERVICE_NAME" 2>/dev/null || true
      systemctl disable "$SERVICE_NAME" 2>/dev/null || true
      ;;
    openrc)
      rc-service "$SERVICE_NAME" stop 2>/dev/null || true
      rc-update del "$SERVICE_NAME" default 2>/dev/null || true
      ;;
  esac

  rm -f "$SERVICE_SYSTEMD" "$SERVICE_OPENRC"
  rm -rf "$INSTALL_DIR"

  green "✅ socks5 已卸载"
  exit 0
}

########################
# main（保留子命令）
########################
main() {
  case "${1:-}" in
    uninstall)
      uninstall
      ;;
    node)
      ensure_node_deps
      ensure_installed
      show_node
      exit 0
      ;;
  esac

  install_deps
  handle_params
  stop_existing_service
  install_singbox
  generate_config
  start_service
  show_node
}

main "$@"