#!/bin/bash
# sing-box socks5 脚本
# - 固定 sing-box 版本
# - IPv6 自动检测
# - 多架构
# - 自动重启（当前socks5服务支持系统重启后自动拉起socks5服务）
# 用法如下：
# 1、安装：
#   PORT=端口号 USERNAME=用户名 PASSWORD=密码 bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/socks5.sh)
#   
# 2、卸载：
#   bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/socks5.sh) uninstall
#
# 3、命令行中如何测试socks5串通不通？？只要选下方的命令执行，成功返回ip就代表成功，不用在意是否返回的是什么ip，比如你明明是ipv6环境的服务器确返回了一个ipv4.这种情况其实也是对的。
#  curl --socks5-hostname "ipv4:端口号"  -U 用户名:密码 http://ip.sb
#  curl -6 --socks5-hostname "[ipv6]:端口号" -U 用户名:密码 http://ip.sb
#
set -euo pipefail

# ================== 基本变量 ==================
INSTALL_DIR="/usr/local/sb"
CONFIG_FILE="$INSTALL_DIR/config.json"
BIN_FILE="$INSTALL_DIR/sing-box-socks5"
LOG_FILE="$INSTALL_DIR/run.log"

SERVICE_SYSTEMD="/etc/systemd/system/sing-box-socks5.service"
SERVICE_OPENRC="/etc/init.d/sing-box-socks5"

SB_VERSION="1.12.13"
SB_VER="v${SB_VERSION}"

# ================== 卸载 ==================
if [[ "${1:-}" == "uninstall" ]]; then
  echo "[INFO] 卸载 socks5..."

  if command -v systemctl >/dev/null 2>&1; then
    systemctl stop sing-box-socks5 2>/dev/null || true
    systemctl disable sing-box-socks5 2>/dev/null || true
    rm -f "$SERVICE_SYSTEMD"
    systemctl daemon-reload
  elif command -v rc-service >/dev/null 2>&1; then
    rc-service sing-box-socks5 stop 2>/dev/null || true
    rc-update del sing-box-socks5 default 2>/dev/null || true
    rm -f "$SERVICE_OPENRC"
  fi

  rm -rf "$INSTALL_DIR"
  echo "✅ socks5 已卸载"
  exit 0
fi

# ================== 颜色 ==================
green(){ echo -e "\e[1;32m$1\033[0m"; }
yellow(){ echo -e "\e[1;33m$1\033[0m"; }
blue(){ echo -e "\e[1;34m$1\033[0m"; }

# ================== 随机函数 ==================
gen_username() {
  tr -dc 'A-Za-z0-9' </dev/urandom | head -c 10
}

gen_password() {
  tr -dc 'A-Za-z0-9!@#%^_-+=' </dev/urandom | head -c 10
}

gen_port() {
  shuf -i 1-65530 -n 1
}

check_port_free() {
  ! ss -lnt | awk '{print $4}' | grep -q ":$1$"
}

# ================== TTY / 交互判断 ==================
IS_TTY=0
[[ -t 0 ]] && IS_TTY=1

if [[ -z "${PORT:-}" || -z "${USERNAME:-}" || -z "${PASSWORD:-}" ]]; then
  INTERACTIVE=1
else
  INTERACTIVE=0
fi

# 🔧 关键修复：非 TTY 时强制非交互
if [[ "$INTERACTIVE" == "1" && "$IS_TTY" == "0" ]]; then
  INTERACTIVE=0
fi

# ================== 参数处理 ==================
if [[ "$INTERACTIVE" == "1" ]]; then
  echo "[INFO] 交互式安装模式（回车自动生成）"

  # ---------- 端口 ----------
  if [[ -z "${PORT:-}" ]]; then
    while true; do
      read -rp "请输入端口号（回车自动生成）: " PORT
      if [[ -z "$PORT" ]]; then
        PORT="$(gen_port)"
        echo "[INFO] 已生成端口: $PORT"
        break
      fi
      if [[ "$PORT" =~ ^[0-9]+$ ]] && check_port_free "$PORT"; then
        break
      fi
      echo "❌ 端口非法或已被占用"
      PORT=""
    done
  fi

  # ---------- 用户名 ----------
  if [[ -z "${USERNAME:-}" ]]; then
    read -rp "请输入用户名（回车自动生成）: " USERNAME
    [[ -z "$USERNAME" ]] && USERNAME="$(gen_username)"
    echo "[INFO] 用户名: $USERNAME"
  fi

  # ---------- 密码 ----------
  if [[ -z "${PASSWORD:-}" ]]; then
    read -rsp "请输入密码（回车自动生成）: " PASSWORD
    echo
    [[ -z "$PASSWORD" ]] && PASSWORD="$(gen_password)"
    echo "[INFO] 密码已生成"
  fi

else
  echo "[INFO] 非交互式安装模式（自动生成缺失参数）"
  PORT="${PORT:-$(gen_port)}"
  USERNAME="${USERNAME:-$(gen_username)}"
  PASSWORD="${PASSWORD:-$(gen_password)}"
fi

# ================== 安装依赖 ==================
if command -v apt >/dev/null 2>&1; then
  apt update
  apt install -y curl tar unzip file iproute2 net-tools
elif command -v yum >/dev/null 2>&1; then
  yum install -y curl tar unzip file iproute net-tools
elif command -v apk >/dev/null 2>&1; then
  apk add --no-cache curl tar unzip file iproute2
fi

# ================== 架构识别 ==================
ARCH_RAW=$(uname -m)
case "$ARCH_RAW" in
  x86_64|amd64) ARCH="amd64" ;;
  i386|i686) ARCH="386" ;;
  aarch64|arm64) ARCH="arm64" ;;
  armv7l|armhf) ARCH="armv7" ;;
  armv6l) ARCH="armv6" ;;
  riscv64) ARCH="riscv64" ;;
  mips64el|mips64le) ARCH="mips64le" ;;
  mipsel) ARCH="mipsle" ;;
  mips) ARCH="mips" ;;
  *) echo "❌ 不支持的架构: $ARCH_RAW"; exit 1 ;;
esac

# ================== IPv6 自动检测 ==================
IPV6_AVAILABLE=0
if [[ -f /proc/net/if_inet6 ]] \
  && ip -6 addr show scope global | grep -q inet6 \
  && curl -s6 --max-time 3 https://ipv6.ip.sb >/dev/null 2>&1; then
  IPV6_AVAILABLE=1
fi

LISTEN_ADDR=$([[ "$IPV6_AVAILABLE" -eq 1 ]] && echo "::" || echo "0.0.0.0")

IP_V4=$(curl -s4 ipv4.ip.sb || true)
IP_V6=$(curl -s6 ipv6.ip.sb || true)

# ================== 下载 sing-box ==================
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

URL="https://github.com/SagerNet/sing-box/releases/download/${SB_VER}/sing-box-${SB_VERSION}-linux-${ARCH}.tar.gz"
curl -L --retry 3 -o sb.tar.gz "$URL"

tar -xzf sb.tar.gz --strip-components=1
chmod +x sing-box
mv sing-box "$BIN_FILE"
rm -f sb.tar.gz

# ================== 生成配置 ==================
cat > "$CONFIG_FILE" <<EOF
{
  "log": { "level": "info" },
  "inbounds": [
    {
      "type": "socks",
      "listen": "$LISTEN_ADDR",
      "listen_port": $PORT,
      "users": [
        {
          "username": "$USERNAME",
          "password": "$PASSWORD"
        }
      ]
    }
  ],
  "outbounds": [{ "type": "direct" }]
}
EOF

# ================== 启动服务 ==================
if command -v systemctl >/dev/null 2>&1; then
  cat > "$SERVICE_SYSTEMD" <<EOF
[Unit]
Description=Sing-box Socks5 Service
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=$BIN_FILE run -c $CONFIG_FILE
Restart=always
RestartSec=3
LimitNOFILE=1048576
WorkingDirectory=$INSTALL_DIR
StandardOutput=append:$LOG_FILE
StandardError=append:$LOG_FILE

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable sing-box-socks5
  systemctl restart sing-box-socks5

elif command -v rc-service >/dev/null 2>&1; then
  cat > "$SERVICE_OPENRC" <<EOF
#!/sbin/openrc-run
command="$BIN_FILE"
command_args="run -c $CONFIG_FILE"
command_background="yes"
pidfile="/run/sing-box-socks5.pid"
output_log="$LOG_FILE"
error_log="$LOG_FILE"
depend() { need net; }
EOF

  chmod +x "$SERVICE_OPENRC"
  rc-update add sing-box-socks5 default
  rc-service sing-box-socks5 restart
else
  echo "❌ 未识别 init 系统"
  exit 1
fi

# ================== 输出 ==================
echo
green "✅ Socks5 服务已启动"
[[ -n "$IP_V4" ]] && blue "IPv4: socks5://$USERNAME:$PASSWORD@$IP_V4:$PORT"
[[ -n "$IP_V6" && "$IPV6_AVAILABLE" -eq 1 ]] && \
  yellow "IPv6: socks5://$USERNAME:$PASSWORD@[$IP_V6]:$PORT"
