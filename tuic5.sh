#!/bin/bash
export LANG=en_US.UTF-8

# ======================================================================
# Sing-box TUIC v5 一键脚本
# 作者：littleDoraemon
# 说明：
#   - 支持自动 / 交互模式
#   - 支持跳跃端口：使用nat端口转发给主端口，也就是服务端一下子给你把跳跃端口范围的端口都指向了主端口号的转发(跟hy2的服务器天然支持跳跃端口功能不太一样)
#   - 支持环境变量：PORT / UUID / RANGE_PORTS / NODE_NAME
#  
#  1、安装方式（2种）
#     1.1 交互式菜单安装：
#     curl -fsSL https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/tuic5.sh -o tuic5.sh && chmod +x tuic5.sh && ./tuic5.sh
#    
#     1.2 非交互式全自动安装:
#     PORT=31020 RANGE_PORTS=40000-41000 NODE_NAME="小叮当的节点" bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/tuic5.sh)
#
# 
#  
# ======================================================================

# ======================================================================
# 基本信息
# ======================================================================
AUTHOR="littleDoraemon"
VERSION="v1.0.2"
SINGBOX_VERSION="1.12.13"

# ======================================================================
# 路径定义（TUIC 独立）
# ======================================================================
SERVICE_NAME="sing-box-tuic"

work_dir="/etc/sing-box-tuic"
config_dir="${work_dir}/config.json"
client_dir="${work_dir}/url.txt"
sub_file="${work_dir}/sub.txt"
sub_port_file="${work_dir}/sub.port"
range_port_file="${work_dir}/range_ports"

sub_nginx_conf="$work_dir/singbox_tuic_sub.conf"





NAT_COMMENT="tuic_jump"

# ======================================================================
# UI 输出（与 hy2 一致）
# ======================================================================
re="\033[0m"
white(){ echo -e "\033[1;37m$1\033[0m"; }
red(){ echo -e "\e[1;91m$1\033[0m"; }
green(){ echo -e "\e[1;32m$1\033[0m"; }
yellow(){ echo -e "\e[1;33m$1\033[0m"; }
blue(){ echo -e "\e[1;34m$1\033[0m"; }
purple(){ echo -e "\e[1;35m$1\033[0m"; }
err(){ red "[错误] $1" >&2; }

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

red_input() { printf "\e[1;91m%s\033[0m" "$1"; }
# ======================================================================
# Root 权限检查
# ======================================================================
if [[ $EUID -ne 0 ]]; then
    err "请使用 root 权限运行脚本"
    exit 1
fi

# ======================================================================
# 基础工具函数
# ======================================================================
command_exists(){ command -v "$1" >/dev/null 2>&1; }
is_valid_port(){ [[ "$1" =~ ^[0-9]+$ && "$1" -ge 1 && "$1" -le 65535 ]]; }

is_port_occupied(){  
    
    local port="$1"

  if command -v ss >/dev/null 2>&1; then
    # ss：兼容 IPv4 / IPv6 / [::]:PORT / 0.0.0.0:PORT
    ss -tuln | grep -qE "[:.]${port}\b"
  elif command -v netstat >/dev/null 2>&1; then
    netstat -tuln | grep -qE "[:.]${port}\b"
  else
    # 理论兜底：无 ss / netstat 时认为未占用
    return 1
  fi
}

urlencode(){ printf "%s" "$1" | jq -sRr @uri; }
urldecode(){ printf '%b' "${1//%/\\x}"; }

# ======================================================================
# 二维码输出（与 hy2 同款）
# ======================================================================
generate_qr() {
    local link="$1"
    [[ -z "$link" ]] && return
    yellow "二维码链接："
    echo "https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${link}"
}

# ======================================================================
# 高可用公网 IP 获取（含多源 fallback）
# ======================================================================
get_public_ip() {
    local ip

    # IPv4 优先：多个源轮询
    for src in \
        "curl -4 -fs https://api.ipify.org" \
        "curl -4 -fs https://ipv4.icanhazip.com" \
        "curl -4 -fs https://ifconfig.me" \
        "curl -4 -fs https://ip.sb" \
        "curl -4 -fs https://checkip.amazonaws.com" \
    ; do
        ip=$(eval $src 2>/dev/null)
        if [[ -n "$ip" ]]; then
            echo "$ip"
            return 0
        fi
    done

    # IPv6 fallback
    for src in \
        "curl -6 -fs https://api64.ipify.org" \
        "curl -6 -fs https://ipv6.icanhazip.com" \
        "curl -6 -fs https://ifconfig.me" \
    ; do
        ip=$(eval $src 2>/dev/null)
        if [[ -n "$ip" ]]; then
            echo "$ip"
            return 0
        fi
    done

    echo ""
    return 1
}


detect_nginx_conf_dir() {
  if [[ "$INIT_SYSTEM" == "openrc" ]]; then
    echo "/etc/nginx/http.d"
  else
    echo "/etc/nginx/conf.d"
  fi
}


detect_init() {
  if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    INIT_SYSTEM="systemd"
  elif command -v rc-service >/dev/null 2>&1; then
    INIT_SYSTEM="openrc"
  else
    red "无法识别 init 系统"
    exit 1
  fi
}



init_nginx_paths() {
  NGX_NGINX_DIR="$(detect_nginx_conf_dir)"
  nginx_conf_link="$NGX_NGINX_DIR/singbox_tuic_sub.conf"
  mkdir -p "$NGX_NGINX_DIR"
}


init_platform() {
  init_nginx_paths
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

# ======================================================================
# 环境变量加载（原样对齐 hy2）
# ======================================================================
load_env_vars() {
    while IFS='=' read -r key value; do
        case "$key" in
            PORT|UUID|RANGE_PORTS|NODE_NAME)
                if [[ -n "$value" && "$value" =~ ^[a-zA-Z0-9\.\-\:_/]+$ ]]; then
                    export "$key=$value"
                fi
                ;;
        esac
    done < <(env | grep -E '^(PORT|UUID|RANGE_PORTS|NODE_NAME)=')
}
load_env_vars

# ======================================================================
# 自动 / 交互模式判定（原样）
# ======================================================================
is_interactive_mode() {
    if [[ -n "$PORT" || -n "$UUID" || -n "$RANGE_PORTS" || -n "$NODE_NAME" ]]; then
        return 1   # 自动模式
    else
        return 0   # 交互模式
    fi
}

DEFAULT_UUID=$(cat /proc/sys/kernel/random/uuid)

# ======================================================================
# UUID / 端口工具（原样）
# ======================================================================
is_valid_uuid() {
    [[ "$1" =~ ^[a-fA-F0-9]{8}-([a-fA-F0-9]{4}-){3}[a-fA-F0-9]{12}$ ]]
}

get_uuid() {
    if [[ -n "$1" ]]; then
        is_valid_uuid "$1" || { err "UUID 格式错误"; exit 1; }
        echo "$1"
    else
        echo "$DEFAULT_UUID"
    fi
}

get_port() {
    local p="$1"
    if [[ -n "$p" ]]; then
        is_valid_port "$p" || { err "端口无效"; exit 1; }
        is_port_occupied "$p" && { err "端口已被占用"; exit 1; }
        echo "$p"
        return
    fi
    while true; do
        rp=$(shuf -i 1-65535 -n 1)
        ! is_port_occupied "$rp" && { echo "$rp"; return; }
    done
}

# ======================================================================
# 跳跃端口格式校验
# ======================================================================
is_valid_range() {
    [[ "$1" =~ ^([0-9]+)-([0-9]+)$ ]] || return 1
    local min="${BASH_REMATCH[1]}"
    local max="${BASH_REMATCH[2]}"
    is_valid_port "$min" && is_valid_port "$max" && [[ $min -lt $max ]]
}
# ======================================================================
# 安装常用依赖（与 hy2_fixed.sh 对齐）
# ======================================================================
install_common_packages() {

    local pkgs="tar jq openssl lsof curl coreutils iptables ip6tables nginx"
    local need_update=1

    for p in $pkgs; do
        if ! command_exists "$p"; then

            if [[ $need_update -eq 1 ]]; then
                if command_exists apt; then
                    apt update -y
                elif command_exists yum; then
                    yum makecache -y
                elif command_exists dnf; then
                    dnf makecache -y
                elif command_exists apk; then
                    apk update
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
                err "无法识别包管理器，请手动安装依赖：$p"
            fi
        fi
    done

     # ==================================================
    # Alpine nftables / iptables NAT 兼容兜底（TUIC 必须）
    # ==================================================
    if command_exists apk; then
        if ! iptables -t nat -L >/dev/null 2>&1; then
            yellow "检测到 iptables NAT 不可用，尝试安装 iptables-legacy 兼容层"
            apk add iptables-legacy ip6tables-legacy >/dev/null 2>&1 || true
        fi
    fi

}

# ======================================================================
# 防火墙放行 TUIC 主端口（UDP）
# ======================================================================
allow_port() {
    local port="$1"

    iptables -C INPUT -p udp --dport "$port" -j ACCEPT &>/dev/null ||
        iptables -I INPUT -p udp --dport "$port" -j ACCEPT

    ip6tables -C INPUT -p udp --dport "$port" -j ACCEPT &>/dev/null ||
        ip6tables -I INPUT -p udp --dport "$port" -j ACCEPT

    green "已放行 UDP 端口：$port"
}

# ======================================================================
# 添加跳跃端口 NAT 规则（IPv4 + IPv6）
# ======================================================================
add_jump_rule() {
    local min="$1"
    local max="$2"
    local listen_port="$3"

    iptables -t nat -A PREROUTING \
        -p udp --dport ${min}:${max} \
        -m comment --comment "$NAT_COMMENT" \
        -j DNAT --to-destination :${listen_port}

    ip6tables -t nat -A PREROUTING \
        -p udp --dport ${min}:${max} \
        -m comment --comment "$NAT_COMMENT" \
        -j DNAT --to-destination :${listen_port}

    green "已添加跳跃端口 NAT 转发：${min}-${max} → ${listen_port}"
}

# ======================================================================
# 刷新跳跃端口 NAT（在修改主端口时调用）
# ======================================================================
refresh_jump_ports_for_new_main_port() {
    # 必须存在 range_port_file，否则无需处理
    if [[ ! -f "$range_port_file" ]]; then
        return
    fi

    rp=$(cat "$range_port_file")
    local min="${rp%-*}"
    local max="${rp#*-}"
    local new_main_port="$1"

    yellow "检测到跳跃端口区间：${min}-${max}，正在刷新 NAT 映射..."

    # -------------------------
    # 删除旧 NAT 规则
    # -------------------------
    remove_jump_rule

    # -------------------------
    # 删除旧 INPUT 放行（避免重复）
    # -------------------------
    while iptables -C INPUT -p udp --dport ${min}:${max} -j ACCEPT &>/dev/null; do
        iptables -D INPUT -p udp --dport ${min}:${max} -j ACCEPT
    done
    while ip6tables -C INPUT -p udp --dport ${min}:${max} -j ACCEPT &>/dev/null; do
        ip6tables -D INPUT -p udp --dport ${min}:${max} -j ACCEPT
    done

    # -------------------------
    # 重新添加放行规则
    # -------------------------
    iptables -I INPUT -p udp --dport ${min}:${max} -j ACCEPT
    ip6tables -I INPUT -p udp --dport ${min}:${max} -j ACCEPT

    # -------------------------
    # 重新添加 NAT 转发（映射到新的主端口）
    # -------------------------
    add_jump_rule "$min" "$max" "$new_main_port"

    green "跳跃端口区间已更新并映射至新的 TUIC 主端口：${new_main_port}"
}


# ======================================================================
# 删除跳跃端口 NAT 规则
# ======================================================================
remove_jump_rule() {

    while iptables -t nat -C PREROUTING -m comment --comment "$NAT_COMMENT" &>/dev/null; do
        iptables -t nat -D PREROUTING -m comment --comment "$NAT_COMMENT"
    done

    while ip6tables -t nat -C PREROUTING -m comment --comment "$NAT_COMMENT" &>/dev/null; do
        ip6tables -t nat -D PREROUTING -m comment --comment "$NAT_COMMENT"
    done

    green "跳跃端口 NAT 规则已删除"
}

# ======================================================================
# 获取节点名称（持久化优先 > 用户设置 > 自动生成）
# ======================================================================
get_node_name() {

    local DEFAULT_NODE_NAME="${AUTHOR}-tuic"

    # ======================================================
    # 1. 持久化节点名称优先（如果用户曾设置过）
    # ======================================================
    if [[ -f "$work_dir/node_name" ]]; then
        saved_name=$(cat "$work_dir/node_name")
        if [[ -n "$saved_name" ]]; then
            echo "$saved_name"
            return
        fi
    fi

    # ======================================================
    # 2. 当前会话设置的节点名称（change_node_name 临时变量）
    # ======================================================
    if [[ -n "$NODE_NAME" ]]; then
        echo "$NODE_NAME"
        return
    fi

    # ======================================================
    # 3. 自动生成节点名称（国家代码 + 运营商）
    # ======================================================

    local country=""
    local org=""

    # 先尝试 ipapi
    country=$(curl -fs --max-time 2 https://ipapi.co/country 2>/dev/null | tr -d '\r\n')
    org=$(curl -fs --max-time 2 https://ipapi.co/org 2>/dev/null | sed 's/[ ]\+/_/g')

    # fallback
    if [[ -z "$country" ]]; then
        country=$(curl -fs --max-time 2 ip.sb/country 2>/dev/null | tr -d '\r\n')
    fi

    if [[ -z "$org" ]]; then
        org=$(curl -fs --max-time 2 ipinfo.io/org 2>/dev/null \
            | awk '{$1=""; print $0}' \
            | sed -e 's/^[ ]*//' -e 's/[ ]\+/_/g')
    fi

    # 自动生成节点名称规则
    if [[ -n "$country" && -n "$org" ]]; then
        echo "${country}-${org}"
        return
    fi

    if [[ -n "$country" && -z "$org" ]]; then
        echo "$country"
        return
    fi

    if [[ -z "$country" && -n "$org" ]]; then
        echo "$DEFAULT_NODE_NAME"
        return
    fi

    echo "$DEFAULT_NODE_NAME"
}

# ======================================================================
# 自动模式下处理跳跃端口（与 hy2_fixed.sh 行为对齐）
# ======================================================================
handle_range_ports() {

    [[ -z "$RANGE_PORTS" ]] && return

    if ! is_valid_range "$RANGE_PORTS"; then
        err "跳跃端口格式错误（示例：10000-20000）"
        return
    fi

    local min="${RANGE_PORTS%-*}"
    local max="${RANGE_PORTS#*-}"

    green "自动模式检测到跳跃端口区间：${min}-${max}"

    #把跳跃端口写入文件
    echo "$RANGE_PORTS" > "$range_port_file"

    iptables -I INPUT -p udp --dport ${min}:${max} -j ACCEPT
    ip6tables -I INPUT -p udp --dport ${min}:${max} -j ACCEPT

    add_jump_rule "$min" "$max" "$PORT"
}

# ======================================================================
# 安装 Sing-box（TUIC v5，结构对齐 hy2_fixed.sh）
# ======================================================================
install_singbox() {

    clear
    purple "准备下载并安装 Sing-box（TUIC v5）..."

    mkdir -p "$work_dir"

    # -------------------- 架构检测（原样对齐 hy2） --------------------
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l) ARCH="armv7" ;;
        i386|i686) ARCH="i386" ;;
        riscv64) ARCH="riscv64" ;;
        mips64el) ARCH="mips64le" ;;
        *) err "不支持的架构: $ARCH"; exit 1 ;;
    esac

    FILE="sing-box-${SINGBOX_VERSION}-linux-${ARCH}.tar.gz"
    URL="https://github.com/SagerNet/sing-box/releases/download/v${SINGBOX_VERSION}/${FILE}"

    yellow "下载 Sing-box：$URL"
    curl -fSL --retry 3 --retry-delay 2 -o "$FILE" "$URL" || { err "下载失败"; exit 1; }

    tar -xzf "$FILE" || { err "解压失败"; exit 1; }
    rm -f "$FILE"

    extracted=$(find . -maxdepth 1 -type d -name "sing-box-*")
    extracted=$(echo "$extracted" | head -1)

    mv "$extracted/sing-box" "$work_dir/sing-box"
    chmod +x "$work_dir/sing-box"
    rm -rf "$extracted"

    # -------------------- 模式判定 --------------------

    is_interactive_mode
    if [[ $? -eq 1 ]]; then
        # 自动模式
        white "当前模式：自动模式"

        # 先尝试使用传入的 PORT
        if is_valid_port "$PORT" && ! is_port_occupied "$PORT"; then
            PORT="$PORT"
        else
            yellow "检测到 PORT 无效或已被占用，切换为手动输入端口"
            while true; do
                read -rp "$(red_input "请输入 TUIC 主端口（UDP）：")" USER_PORT
                if is_valid_port "$USER_PORT" && ! is_port_occupied "$USER_PORT"; then
                    PORT="$USER_PORT"
                    break
                else
                    red "端口无效或已被占用，请重新输入"
                fi
            done
        fi

    # ===============================
    # 自动模式 - UUID 处理（兜底）
    # ===============================
    if [[ -n "$UUID" ]]; then
        if is_valid_uuid "$UUID"; then
            UUID="$UUID"
        else
            yellow "检测到 UUID 无效，请重新输入"
            while true; do
                read -rp "$(red_input "请输入 UUID（回车自动生成）：")" USER_UUID
                if [[ -z "$USER_UUID" ]]; then
                    UUID=$(cat /proc/sys/kernel/random/uuid)
                    green "已自动生成 UUID：$UUID"
                    break
                fi
                if is_valid_uuid "$USER_UUID"; then
                    UUID="$USER_UUID"
                    break
                else
                    red "UUID 格式不正确，请重新输入"
                fi
            done
        fi
    else
        # 自动模式但未传 UUID → 自动生成（不打扰用户）
        UUID=$(cat /proc/sys/kernel/random/uuid)
    fi

    else
        # 交互模式 - 端口
        white "当前模式：交互模式"
        while true; do
            read -rp "$(red_input "请输入 TUIC 主端口（UDP）：")" USER_PORT
            if is_valid_port "$USER_PORT" && ! is_port_occupied "$USER_PORT"; then
                PORT="$USER_PORT"
                break
            fi
            red "端口无效或已被占用"
        done

        # 交互模式 - UUID（必须校验）
        while true; do
            read -rp "$(red_input "请输入 UUID（回车自动生成随机 UUID）")" USER_UUID
            if [[ -z "$USER_UUID" ]]; then
                UUID=$(cat /proc/sys/kernel/random/uuid)
                green "已自动生成 UUID：$UUID"
                break
            fi

            # 用户填写 UUID → 校验格式
            if is_valid_uuid "$USER_UUID"; then
                UUID="$USER_UUID"
                break
            else
                red "UUID 格式不正确，请重新输入。"
            fi
        done
    fi

    # 放行 TUIC 主端口
    allow_port "$PORT"


    # -------------------- TLS 证书 --------------------
    openssl ecparam -genkey -name prime256v1 -out "${work_dir}/private.key"
    openssl req -x509 -new -nodes \
        -key "${work_dir}/private.key" \
        -sha256 -days 3650 \
        -subj "/C=US/ST=CA/O=bing.com/CN=bing.com" \
        -out "${work_dir}/cert.pem"

    # -------------------- 生成 config.json --------------------
cat > "$config_dir" <<EOF
{
  "log": {
    "level": "error",
    "output": "$work_dir/sb.log"
  },
  "inbounds": [
    {
      "type": "tuic",
      "listen": "::",
      "listen_port": $PORT,
      "users": [
        { "uuid": "$UUID", "password": "$UUID" }
      ],
      "congestion_control": "bbr",
      "tls": {
        "enabled": true,
        "alpn": ["h3"],
        "certificate_path": "$work_dir/cert.pem",
        "key_path": "$work_dir/private.key"
      }
    }
  ],
  "outbounds": [
    { "type": "direct" }
  ]
}
EOF

    green "配置文件已生成：$config_dir"

    # -------------------- systemd 服务 --------------------
cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=Sing-box TUIC
After=network.target

[Service]
ExecStart=$work_dir/sing-box run -c $config_dir
Restart=always
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    make_service


    green "Sing-box TUIC 服务已启动"
}
# ======================================================================
# 生成本地订阅文件（sub.txt / base64 / json）
# 与 hy2_fixed.sh 行为对齐
# ======================================================================
generate_all_subscription_files() {
    local base_url="$1"

cat > "$sub_file" <<EOF
# TUIC 主订阅
$base_url
EOF

    base64 -w0 "$sub_file" > "${work_dir}/sub_base64.txt"

cat > "${work_dir}/sub.json" <<EOF
{
  "tuic": "$base_url"
}
EOF
}

# ======================================================================
# 安装 / 更新 nginx 订阅服务（与 hy2_fixed.sh 等价）
# ======================================================================

build_subscribe_conf() {

    [[ ! -f "$sub_file" ]] && {
        red "订阅内容不存在，请先生成节点"
        return 1
    }

    local sub_port
    if [[ -f "$sub_port_file" ]]; then
        sub_port=$(cat "$sub_port_file")
    else
        sub_port=$((PORT + 1))
        echo "$sub_port" > "$sub_port_file"
    fi

cat > "$sub_nginx_conf" <<EOF
server {
    listen ${sub_port};
    listen [::]:${sub_port};

    server_name sb_tuic_sub.local;

    add_header Cache-Control "no-cache, must-revalidate";
    add_header Pragma "no-cache";
    add_header Expires "0";

    location /${UUID} {
        alias ${sub_file};
        default_type text/plain;
    }

    location / {
        return 404;
    }
}
EOF

    ln -sf "$sub_nginx_conf" "$nginx_conf_link"

    if command_exists nginx && service_active nginx; then
        service_restart nginx
        green "订阅服务已生成并生效"
    else
        yellow "Nginx 未运行，订阅配置已生成，启动 Nginx 后生效"
    fi

    
}





# ======================================================================
# 查看节点信息（多客户端 + 二维码，对齐 hy2_fixed.sh）
# ======================================================================


get_ipv4() { 
    local ip
    local sources=(
        "curl -4 -fs https://api.ipify.org"
        "curl -4 -fs https://ipv4.icanhazip.com"
        "curl -4 -fs https://ip.sb"
        "curl -4 -fs https://checkip.amazonaws.com"
    )

    for src in "${sources[@]}"; do
        ip=$(eval "$src" 2>/dev/null)
        [[ -n "$ip" ]] && { echo "$ip"; return; }
    done
 }

 get_ipv6() { 
   local ip
   local sources6=(
        "curl -6 -fs https://api64.ipify.org"
        "curl -6 -fs https://ipv6.icanhazip.com"
    )

    for src in "${sources6[@]}"; do
        ip=$(eval "$src" 2>/dev/null)
        [[ -n "$ip" ]] && { echo "$ip"; return; }
    done
 }


make_service_systemd() {

cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=Sing-box tuic5
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=${work_dir}/sing-box run -c ${config_dir}
Restart=always
RestartSec=3
LimitNOFILE=1048576

# 安全加固（可选，但推荐）
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true

[Install]
WantedBy=multi-user.target
EOF

  # 重新加载 systemd
  systemctl daemon-reload
}



make_service_openrc() {
cat > /etc/init.d/${SERVICE_NAME} <<EOF
#!/sbin/openrc-run
name="sing-box tuic5"
command="$work_dir/sing-box"
command_args="run -c $config_dir"
supervisor="supervise-daemon"
output_log="/var/log/${SERVICE_NAME}.log"
error_log="/var/log/${SERVICE_NAME}.err"

depend() {
  need net
}
EOF

chmod +x /etc/init.d/${SERVICE_NAME}
}


make_service() {
  if [[ "$INIT_SYSTEM" == "systemd" ]]; then
    make_service_systemd
  else
    make_service_openrc
  fi

  service_enable "${SERVICE_NAME}"
  service_start  "${SERVICE_NAME}"
}



check_nodes() {
    local mode="$1"   # silent / empty

    [[ ! -f "$config_dir" ]] && {
        red "未找到配置文件，请先安装 TUIC"
        [[ "$mode" != "silent" ]] && pause_return
        return
    }

    # =====================================================
    # 基础信息
    # =====================================================
    local PORT UUID
    PORT=$(jq -r '.inbounds[0].listen_port' "$config_dir")
    UUID=$(jq -r '.inbounds[0].users[0].uuid' "$config_dir")

    # =====================================================
    # 探测 IPv4 / IPv6
    # =====================================================
    local ip4 ip6
    ip4=$(get_ipv4)
    ip6=$(get_ipv6)

    if [[ -z "$ip4" && -z "$ip6" ]]; then
        red "无法获取 IPv4 / IPv6 公网地址"
        [[ "$mode" != "silent" ]] && pause_return
        return
    fi

    # =====================================================
    # 节点名称
    # =====================================================
    local BASE_NAME
    BASE_NAME=$(get_node_name)

    # =====================================================
    # 订阅端口（仅用于展示）
    # =====================================================
    local sub_port
    if [[ -f "$sub_port_file" ]]; then
        sub_port=$(cat "$sub_port_file")
    else
        sub_port=$((PORT + 1))
        echo "$sub_port" > "$sub_port_file"
    fi

    # =====================================================
    # 初始化订阅数据
    # =====================================================
    > "$sub_file"

    yellow "========================================================"

    # =====================================================
    # TUIC IPv4 节点
    # =====================================================
    local tuic_v4=""
    if [[ -n "$ip4" ]]; then
        local name4 enc4
        name4="${BASE_NAME}"
        enc4=$(urlencode "$name4")

        tuic_v4="tuic://${UUID}:${UUID}@${ip4}:${PORT}?congestion_control=bbr&alpn=h3&allow_insecure=1#${enc4}"

        purple "TUIC IPv4 节点（${name4}）"
        green "$tuic_v4"
        [[ "$mode" != "silent" ]] && generate_qr "$tuic_v4"
        echo ""

        echo "$tuic_v4" >> "$sub_file"
        echo "$tuic_v4" > "$client_dir"
    fi

    # =====================================================
    # TUIC IPv6 节点
    # =====================================================
    local tuic_v6=""
    if [[ -n "$ip6" ]]; then
        local name6 enc6
        name6="${BASE_NAME}"
        enc6=$(urlencode "$name6")

        tuic_v6="tuic://${UUID}:${UUID}@[${ip6}]:${PORT}?congestion_control=bbr&alpn=h3&allow_insecure=1#${enc6}"

        purple "TUIC IPv6 节点（${name6}）"
        green "$tuic_v6"
        [[ "$mode" != "silent" ]] && generate_qr "$tuic_v6"
        echo ""

        echo "$tuic_v6" >> "$sub_file"
        [[ -z "$tuic_v4" ]] && echo "$tuic_v6" > "$client_dir"
    fi

    yellow "========================================================"

    # =====================================================
    # 本地订阅（base64）
    # =====================================================
    base64 -w0 "$sub_file" > "${work_dir}/sub_base64.txt"

    # =====================================================
    # 订阅展示（仅在订阅启用时）
    # =====================================================
    if is_subscribe_enabled; then
        local sub_url_v4="" sub_url_v6=""

        if [[ -n "$ip4" ]]; then
            sub_url_v4="http://${ip4}:${sub_port}/${UUID}"
            purple "基础订阅（IPv4）："
            green "$sub_url_v4"
            [[ "$mode" != "silent" ]] && generate_qr "$sub_url_v4"
            echo ""
        fi

        if [[ -n "$ip6" ]]; then
            sub_url_v6="http://[${ip6}]:${sub_port}/${UUID}"
            purple "基础订阅（IPv6）："
            green "$sub_url_v6"
            [[ "$mode" != "silent" ]] && generate_qr "$sub_url_v6"
            echo ""
        fi

        yellow "========================================================"

        # 客户端订阅（与 hy2 统一抽象）
        print_client_subscribe_links "$sub_url_v4" "IPv4" "$mode"
        print_client_subscribe_links "$sub_url_v6" "IPv6" "$mode"
    else
        if [[ "$mode" != "silent" ]]; then
            yellow "订阅服务当前未启用"
            echo ""
            blue  "提示：如需使用订阅功能，请前往以下菜单手动启用："
            green "  主菜单 → 管理订阅服务"
            green "           → 启用 / 重建订阅服务"
        fi
    fi

    yellow "========================================================"

    [[ "$mode" != "silent" ]] && pause_return
}



# ======================================================================
# Sing-box 服务管理（与 hy2_fixed.sh 对齐）
# ======================================================================
manage_singbox() {
    while true; do
        clear
        blue "========== Sing-box 服务管理 =========="
        echo ""
        green " 1. 启动 Sing-box"
        green " 2. 停止 Sing-box"
        green " 3. 重启 Sing-box"
        yellow "----------------------------------------"
        green " 0. 返回主菜单"
        red   "88. 退出脚本"
        echo ""

        read -rp "请选择操作：" sel

        case "$sel" in
            1) service_start ${SERVICE_NAME} ;;
            2) service_stop ${SERVICE_NAME} ;;
            3) service_restart ${SERVICE_NAME} ;;
            0) return ;;
            88) exit 0 ;;
            *) red "无效输入，请重新选择" ;;
        esac
    done
}

# ======================================================================
# 订阅服务管理（nginx，与 hy2_fixed.sh 对齐）
# ======================================================================
manage_subscribe_menu() {
    while true; do
        clear
        blue "========== 订阅服务管理（TUIC / Nginx） =========="
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
        red   "88. 退出脚本"
        echo ""

        read -rp "请选择操作：" sel
        case "$sel" in
            1)
                service_start nginx
                service_active nginx && green "Nginx 已启动" || red "Nginx 启动失败"
                pause_return
                ;;
            2)
                service_stop nginx
                service_active nginx && red "Nginx 停止失败" || green "Nginx 已停止"
                pause_return
                ;;
            3)
                service_restart nginx
                service_active nginx && green "Nginx 已重启" || red "Nginx 重启失败"
                pause_return
                ;;
            4)
                build_subscribe_conf
                pause_return
                ;;
            5)
                change_subscribe_port
                pause_return
                ;;
            6)
                disable_subscribe
                pause_return
                ;;
            0)
                return
                ;;
            88)
                exit 0
                ;;
            *)
                red "无效输入"
                pause_return
                ;;
        esac
    done
}




disable_subscribe() {
    rm -f "$sub_nginx_conf"
    rm -f "$nginx_conf_link"

    if command_exists nginx && service_active nginx; then
        service_restart nginx
    fi


    green "订阅服务已关闭"
}


change_subscribe_port() {
    read -rp "$(red_input "请输入新的订阅端口：")" new_port

    if ! is_valid_port "$new_port"; then
        red "端口无效"
        return
    fi

    if is_port_occupied "$new_port"; then
        red "端口已被占用"
        return
    fi

    echo "$new_port" > "$sub_port_file"

    if is_subscribe_enabled; then
        build_subscribe_conf
        green "订阅端口已修改为：$new_port"
    else
        yellow "订阅未启用，端口已保存，启用订阅后生效"
    fi
}




# ======================================================================
# 修改节点配置（与 hy2_fixed.sh 对齐）
# ======================================================================
change_config() {
    while true; do
        # ===============================
        # 1️⃣ 画菜单（唯一 clear 的地方）
        # ===============================
        clear
        blue "========== 修改节点配置 =========="
        echo ""
        green " 1. 修改 TUIC 主端口（UDP）"
        green " 2. 修改 UUID（同时作为 password）"
        green " 3. 修改节点名称"
        green " 4. 添加跳跃端口（UDP 数据端口）"
        green " 5. 删除跳跃端口"
        yellow "-------------------------------------------"
        green " 0. 返回主菜单"
        red   "88. 退出脚本"
        echo ""

        # ===============================
        # 2️⃣ 读取用户选择
        # ===============================
        read -rp "请选择操作：" sel

        # ===============================
        # 3️⃣ 执行动作（动作自己负责 pause）
        # ===============================
        case "$sel" in
            1)
                change_main_tuic_port
                
                ;;
            2)
                read -rp "$(red_input "请输入新的 UUID（回车自动生成）：")" new_uuid

                if [[ -z "$new_uuid" ]]; then
                    new_uuid=$(cat /proc/sys/kernel/random/uuid)
                    green "已自动生成 UUID：$new_uuid"
                else
                    is_valid_uuid "$new_uuid" || {
                        red "UUID 格式错误"
                        read -n 1 -s -r -p "按任意键返回菜单..." </dev/tty
                        continue
                    }
                fi

                jq ".inbounds[0].users[0].uuid=\"$new_uuid\" | .inbounds[0].users[0].password=\"$new_uuid\"" \
                    "$config_dir" > /tmp/tuic_cfg && mv /tmp/tuic_cfg "$config_dir"

                service_restart ${SERVICE_NAME}
                service_restart nginx
                green "UUID 已成功修改"
                read -n 1 -s -r -p "按任意键返回菜单..." </dev/tty
                ;;
            3)
                read -rp "$(red_input "请输入新的节点名称：")" new_name
                change_node_name "$new_name"
                ;;
            4)
                add_jump_port
                read -n 1 -s -r -p "按任意键返回菜单..." </dev/tty
                ;;
            5)
                if [[ -f "$range_port_file" ]]; then
                    rp=$(cat "$range_port_file")
                    min="${rp%-*}"
                    max="${rp#*-}"

                    while iptables -C INPUT -p udp --dport ${min}:${max} -j ACCEPT &>/dev/null; do
                        iptables -D INPUT -p udp --dport ${min}:${max} -j ACCEPT
                    done
                    while ip6tables -C INPUT -p udp --dport ${min}:${max} -j ACCEPT &>/dev/null; do
                        ip6tables -D INPUT -p udp --dport ${min}:${max} -j ACCEPT
                    done

                    remove_jump_rule
                    rm -f "$range_port_file"

                    green "跳跃端口已彻底删除：${min}-${max}"
                else
                    yellow "当前未启用跳跃端口"
                fi
                read -n 1 -s -r -p "按任意键返回菜单..." </dev/tty
                ;;
            0)
                return
                ;;
            88)
                exit 0
                ;;
            *)
                red "无效输入，请重新选择"
                read -n 1 -s -r -p "按任意键返回菜单..." </dev/tty
                ;;
        esac
    done
}


change_main_tuic_port() {
    local new_port
    local old_port

    while true; do
        read -rp "$(red_input "请输入新的 TUIC 主端口（UDP）：")" new_port

        if ! is_valid_port "$new_port"; then
            red "端口无效，请输入 1-65535 之间的数字"
            continue
        fi

        if is_port_occupied "$new_port"; then
            red "端口已被占用，请更换一个端口"
            continue
        fi

        break
    done

    # 旧主端口
    old_port=$(jq -r '.inbounds[0].listen_port' "$config_dir")

    # 更新配置文件
    jq ".inbounds[0].listen_port=$new_port" "$config_dir" > /tmp/tuic_cfg \
        && mv /tmp/tuic_cfg "$config_dir"

    # 放行新端口
    allow_port "$new_port"

    # 删除旧端口的放行规则
    iptables -D INPUT -p udp --dport "$old_port" -j ACCEPT 2>/dev/null
    ip6tables -D INPUT -p udp --dport "$old_port" -j ACCEPT 2>/dev/null


    # 自动刷新跳跃端口 NAT 映射
    refresh_jump_ports_for_new_main_port "$new_port"

    # 重启服务
    service_restart ${SERVICE_NAME}

    green "TUIC 主端口已从 ${old_port} 修改为：${new_port}"
    read -n 1 -s -r -p "按任意键返回菜单..." </dev/tty
}

# ======================================================================
# 修改节点名称（持久化写入 + 会话变量 + 自动刷新）
# ======================================================================
change_node_name() {
    local new_name="$1"

    if [[ -z "$new_name" ]]; then
        red "节点名称不能为空"
        return 1
    fi

    # ======================================================
    # 1. 写入当前会话变量（本次运行有效）
    # ======================================================
    NODE_NAME="$new_name"

    # ======================================================
    # 2. 写入持久化文件（脚本重启依然有效）
    # ======================================================
    echo "$new_name" > "$work_dir/node_name"

    green "节点名称已修改为：$new_name"
    yellow "正在刷新节点信息……"
    sleep 0.3

    # ======================================================
    # 3. 调用 check_nodes → 统一生成 TUIC URL（含节点名称）
    # ======================================================
    check_nodes
    read -n 1 -s -r -p "按任意键返回菜单..."
}

# ======================================================================
# 完美化版 添加跳跃端口（无残留 + 冲突检查 + 自动清理旧规则）
# ======================================================================
add_jump_port() {
    echo ""
    yellow "跳跃端口说明："
    yellow "- 仅用于 TUIC 的 UDP 数据通信"
    yellow "- 系统重启后不会自动恢复"
    echo ""

    read -rp "起始 UDP 端口：" jmin
    read -rp "结束 UDP 端口：" jmax

    # 校验格式
    is_valid_range "${jmin}-${jmax}" || { red "端口区间格式错误"; return; }

    # 主端口冲突检测
    local main_port
    main_port=$(jq -r '.inbounds[0].listen_port' "$config_dir")

    if [[ $jmin -le $main_port && $main_port -le $jmax ]]; then
        red "错误：跳跃端口区间不能包含 TUIC 主端口（$main_port）！"
        return
    fi

    # ======================================================
    # 清理旧跳跃端口规则（避免残留）
    # ======================================================
    if [[ -f "$range_port_file" ]]; then
        old_range=$(cat "$range_port_file")
        old_min="${old_range%-*}"
        old_max="${old_range#*-}"

        # 删除旧 INPUT 放行规则
        while iptables -C INPUT -p udp --dport ${old_min}:${old_max} -j ACCEPT &>/dev/null; do
            iptables -D INPUT -p udp --dport ${old_min}:${old_max} -j ACCEPT
        done
        while ip6tables -C INPUT -p udp --dport ${old_min}:${old_max} -j ACCEPT &>/dev/null; do
            ip6tables -D INPUT -p udp --dport ${old_min}:${old_max} -j ACCEPT
        done

        # 删除旧 NAT 跳跃规则
        remove_jump_rule

        yellow "已清理旧跳跃端口规则：${old_min}-${old_max}"
    fi

    # ======================================================
    # 写入新跳跃端口
    # ======================================================
    echo "${jmin}-${jmax}" > "$range_port_file"

    # 添加 INPUT 放行规则
    iptables -I INPUT -p udp --dport ${jmin}:${jmax} -j ACCEPT
    ip6tables -I INPUT -p udp --dport ${jmin}:${jmax} -j ACCEPT

    # 添加 NAT 规则
    add_jump_rule "$jmin" "$jmax" "$main_port"

    green "跳跃端口已启用：${jmin}-${jmax}"
    yellow "注意：该设置仅在当前系统运行期间有效"
}


# ======================================================================
# 卸载 TUIC（与 hy2_fixed.sh 行为对齐）
# ======================================================================
uninstall_tuic() {

    clear
    blue "============== 卸载 TUIC v5 =============="
    echo ""

    read -rp "确认卸载 Sing-box TUIC？ [Y/n]（默认 Y）：" u
    u=${u:-y}
    [[ ! "$u" =~ ^[Yy]$ ]] && { yellow "已取消卸载"; pause_return; return; }

    # ==================================================
    # 1. 清理跳跃端口 NAT / 防火墙规则
    # ==================================================
    remove_jump_rule
    if [[ -f "$range_port_file" ]]; then
        rp=$(cat "$range_port_file")
        min="${rp%-*}"
        max="${rp#*-}"

        iptables -D INPUT -p udp --dport ${min}:${max} -j ACCEPT 2>/dev/null
        ip6tables -D INPUT -p udp --dport ${min}:${max} -j ACCEPT 2>/dev/null
        rm -f "$range_port_file"
    fi
    green "已清理跳跃端口相关规则"

    # ==================================================
    # 2. 停止并移除服务（systemd / openrc 自适应）
    # ==================================================
    if [[ "$INIT_SYSTEM" == "systemd" ]]; then
        systemctl stop ${SERVICE_NAME} 2>/dev/null
        systemctl disable ${SERVICE_NAME} 2>/dev/null
        rm -f /etc/systemd/system/${SERVICE_NAME}.service
        systemctl daemon-reload
    else
        rc-service ${SERVICE_NAME} stop 2>/dev/null
        rc-update del ${SERVICE_NAME} 2>/dev/null
        rm -f /etc/init.d/${SERVICE_NAME}
    fi
    green "TUIC 服务已移除"

    # ==================================================
    # 3. 删除运行目录
    # ==================================================
    rm -rf "$work_dir"

    # ==================================================
    # 4. 删除订阅配置（使用统一 nginx_conf_link）
    # ==================================================
    rm -f "$sub_nginx_conf" "$nginx_conf_link"

    # ==================================================
    # 5. 重载 nginx（如存在且正在运行）
    # ==================================================
    if command_exists nginx && service_active nginx; then
        service_restart nginx
    fi

    green "TUIC v5 已卸载完成"
    echo ""

    # ==================================================
    # 6. 是否卸载 Nginx（可选）
    # ==================================================
    if command_exists nginx; then
        read -rp "是否同时卸载 Nginx？ [y/N]：" delng
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
            fi
            green "Nginx 已卸载"
        else
            yellow "已保留 Nginx"
        fi
    fi

    pause_return
}



# ======================================================================
# 自动模式安装入口（与 hy2_fixed.sh 对齐）
# ======================================================================
quick_install() {
    install_common_packages
    install_singbox
    handle_range_ports
    build_subscribe_conf
    check_nodes
    # 持久化节点名称
    get_node_name > "$work_dir/node_name"
}

# ======================================================================
# 主菜单（与 hy2_fixed.sh 对齐）
# ======================================================================
menu() {
    clear
    blue "===================================================="
    gradient "       Sing-box 一键脚本（TUIC v5版本）"
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

    green  " 1. 安装 Sing-box (TUIC)"
    red    " 2. 卸载 Sing-box"
    yellow "----------------------------------------"
    green  " 3. 管理 Sing-box 服务"
    green  " 4. 查看节点信息"
    yellow "----------------------------------------"
    green  " 5. 修改节点配置"
    green  " 6. 管理订阅服务"
    yellow "----------------------------------------"
    red    " 88. 退出脚本"
    echo ""

    read -rp "请输入选项：" choice
}






get_singbox_status_colored() {
    # ---------- 是否已安装 ----------
    if [[ "$INIT_SYSTEM" == "systemd" ]]; then
        systemctl list-unit-files --type=service 2>/dev/null \
            | grep -q "^${SERVICE_NAME}\.service" \
            || { red "未安装"; return; }
    else
        [[ -f "/etc/init.d/${SERVICE_NAME}" ]] || { red "未安装"; return; }
    fi

    # ---------- 运行状态 ----------
    if service_active "${SERVICE_NAME}"; then
        green "运行中"
    else
        red "未运行"
    fi
}

get_subscribe_status_colored() {
    # 配置不存在 → 一定未启用
    [[ ! -f "$sub_nginx_conf" ]] && { yellow "未启用"; return; }

    # nginx 未安装
    if ! command_exists nginx; then
        yellow "未启用"
        return
    fi

    # nginx 未运行
    if ! service_active nginx; then
        yellow "未启用"
        return
    fi

    green "已启用"
}

print_subscribe_status() {
    if [[ ! -f "$sub_nginx_conf" ]] || ! command_exists nginx || ! service_active nginx; then
        yellow "当前订阅状态：未启用"
    else
        green "当前订阅状态：已启用"
    fi
}


is_subscribe_enabled() {
    [[ -f "$sub_nginx_conf" ]] && command_exists nginx && service_active nginx
}



# ======================================================================
# 主循环（与 hy2_fixed.sh 对齐）
# ======================================================================
main_loop() {
    while true; do
        menu
        case "$choice" in
            1)
                unset PORT UUID RANGE_PORTS NODE_NAME
                install_common_packages
                install_singbox
                add_nginx_conf
                check_nodes
                # 持久化节点名称
                get_node_name > "$work_dir/node_name"
                read -n 1 -s -r -p "安装完成！按任意键进入主菜单..." </dev/tty
                ;;
            2) uninstall_tuic ;;
            3) manage_singbox ;;
            4) check_nodes 
               read -n 1 -s -r -p "安装完成！按任意键进入主菜单..." </dev/tty
            ;;
            5) change_config ;;
            6) manage_subscribe_menu ;;
            88) exit 0 ;;
            *) red "无效选项，请重新输入" ;;
        esac
    done
}

# ======================================================================
# 主入口（与 hy2_fixed.sh 完全一致）
# ======================================================================
main() {
    detect_init
    init_platform
    is_interactive_mode
    if [[ $? -eq 1 ]]; then
        quick_install

        read -n 1 -s -r -p "安装完成！按任意键进入主菜单..." </dev/tty
        main_loop
    else
        main_loop
    fi
}

main
