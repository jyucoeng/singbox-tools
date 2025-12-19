#!/bin/bash
export LANG=en_US.UTF-8

# ======================================================================
# Sing-box Hysteria2 一键安装管理脚本（最终整合修复版）
# 作者：LittleDoraemon（升级增强版）
# 功能：自动模式、跳跃端口、安全 NAT 删除、IPv6 支持、三合一订阅系统
# ======================================================================

# ======================================================================
# 自动加载环境变量（支持 PORT=xxx RANGE_PORTS=xxx UUID=xxx）
# ======================================================================
load_env_vars() {
    while IFS='=' read -r key value; do
        case "$key" in
            PORT|UUID|RANGE_PORTS|NODE_NAME)
                if [[ "$value" =~ ^[a-zA-Z0-9\.\-\:_/]+$ ]]; then
                    export "$key=$value"
                fi
                ;;
        esac
    done < <(env | grep -E '^(PORT|UUID|RANGE_PORTS|NODE_NAME)=')
}
load_env_vars



# ======================================================================
# 常量
# ======================================================================
SINGBOX_VERSION="1.12.13"
AUTHOR="LittleDoraemon"
VERSION="v1.0-final"

work_dir="/etc/sing-box"
config_dir="${work_dir}/config.json"
sub_file="${work_dir}/sub.txt"
sub_port_file="/etc/sing-box/sub.port"

DEFAULT_UUID=$(cat /proc/sys/kernel/random/uuid)

# ======================================================================
# UI 配色
# ======================================================================
re="\033[0m"
_white() { echo -e "\033[1;37m$1\033[0m"; }
_red() { echo -e "\e[1;91m$1\033[0m"; }
_green() { echo -e "\e[1;32m$1\033[0m"; }
_yellow() { echo -e "\e[1;33m$1\033[0m"; }
_purple() { echo -e "\e[1;35m$1\033[0m"; }
_skyblue() { echo -e "\e[1;36m$1\033[0m"; }
_blue() { echo -e "\e[1;34m$1\033[0m"; }
_brown() { echo -e "\033[0;33m$1\033[0m"; }

_gradient() {
    local text="$1"
    local colors=(196 202 208 214 220 190 82 46 51 39 33 99 129 163)
    local i=0
    local len=${#colors[@]}

    for (( n=0; n<${#text}; n++ )); do
        local c=${text:n:1}
        printf "\033[38;5;${colors[i]}m%s\033[0m" "$c"
        i=$(( (i+1) % len ))
    done
    echo
}

_err() { _red "[错误] $1" >&2; }

# ======================================================================
# 基础工具检查 / Root 检查
# ======================================================================
[[ $EUID -ne 0 ]] && { _err "请使用 root 执行脚本！"; exit 1; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

# ======================================================================
# 依赖安装（优化 curl 稳定性 & 避免重复更新）
# ======================================================================
install_common_packages() {
    local pkgs="tar nginx jq openssl lsof coreutils curl"
    local need_update=1

    for p in $pkgs; do
        if ! command_exists "$p"; then

            # 仅在第一次缺包时执行更新（避免重复 update）
            if [[ $need_update -eq 1 ]]; then
                if command_exists apt; then
                    apt update -y
                elif command_exists yum; then
                    yum makecache -y
                elif command_exists dnf; then
                    dnf makecache -y
                fi
                need_update=0
            fi

            _yellow "安装依赖：$p"

            if command_exists apt; then
                apt install -y "$p"
            elif command_exists yum; then
                yum install -y "$p"
            elif command_exists dnf; then
                dnf install -y "$p"
            elif command_exists apk; then
                apk add "$p"
            fi
        fi
    done
}


# ======================================================================
# 获取公网 IP（加入多重兜底）
# ======================================================================
get_realip() {
    local ip4 ip6

    ip4=$(curl -4 -s --retry 3 --connect-timeout 3 https://api.ipify.org)
    [[ -z "$ip4" ]] && ip4=$(curl -4 -s --retry 3 --connect-timeout 3 https://ipv4.icanhazip.com)

    ip6=$(curl -6 -s --retry 3 --connect-timeout 3 https://api64.ipify.org)
    [[ -z "$ip6" ]] && ip6=$(curl -6 -s --retry 3 --connect-timeout 3 https://ipv6.icanhazip.com)

    [[ -n "$ip4" ]] && echo "$ip4" && return
    [[ -n "$ip6" ]] && echo "[$ip6]" && return

    echo "0.0.0.0"
}

# ======================================================================
# 端口校验（增强端口占用检测）
# ======================================================================
is_valid_port() { [[ "$1" =~ ^[0-9]+$ && "$1" -ge 1 && "$1" -le 65535 ]]; }

is_port_occupied() {
    ss -tuln | grep -q ":$1 " && return 0
    netstat -tuln 2>/dev/null | grep -q ":$1 " && return 0
    lsof -i :"$1" &>/dev/null && return 0
    return 1
}

get_port() {
    local p="$1"
    if [[ -n "$p" ]]; then
        is_valid_port "$p" || { _err "端口无效"; exit 1; }
        ! is_port_occupied "$p" || { _err "端口已占用"; exit 1; }
        echo "$p"
        return
    fi

    while true; do
        local rp
        rp=$(shuf -i 20000-60000 -n 1)
        ! is_port_occupied "$rp" && { echo "$rp"; return; }
    done
}

# ======================================================================
# UUID 校验（更严格）
# ======================================================================
is_valid_uuid() { [[ "$1" =~ ^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$ ]]; }

get_uuid() {
    if [[ -n "$1" ]]; then
        is_valid_uuid "$1" || { _err "UUID 格式错误"; exit 1; }
        echo "$1"
        return
    fi
    echo "$DEFAULT_UUID"
}

# ======================================================================
# RANGE_PORTS 校验
# ======================================================================
is_valid_range() {
    [[ "$1" =~ ^([0-9]+)-([0-9]+)$ ]] || return 1
    local min="${BASH_REMATCH[1]}"
    local max="${BASH_REMATCH[2]}"
    is_valid_port "$min" && is_valid_port "$max" && [[ $min -lt $max ]]
}

get_range_ports() {
    local r="$1"
    [[ -z "$r" ]] && { echo ""; return; }
    is_valid_range "$r" || { _err "RANGE_PORTS 格式错误，应为 10000-20000"; exit 1; }
    echo "$r"
}


# ======================================================================
# 判断是否为非交互模式（PORT / UUID / RANGE_PORTS 任意存在即自动安装）
# ======================================================================
is_interactive_mode() {
    if [[ -n "$PORT" || -n "$UUID" || -n "$RANGE_PORTS" || -n "$NODE_NAME" ]]; then
        return 1
    else
        return 0
    fi
}

# ======================================================================
# 防火墙放行（避免重复添加）
# ======================================================================
allow_port() {
    local port="$1"
    local proto="$2"

    if command_exists firewall-cmd; then
        firewall-cmd --permanent --add-port=${port}/${proto} &>/dev/null
        firewall-cmd --reload &>/dev/null
    fi

    iptables -C INPUT -p ${proto} --dport ${port} -j ACCEPT &>/dev/null ||
        iptables -I INPUT -p ${proto} --dport ${port} -j ACCEPT &>/dev/null

    ip6tables -C INPUT -p ${proto} --dport ${port} -j ACCEPT &>/dev/null ||
        ip6tables -I INPUT -p ${proto} --dport ${port} -j ACCEPT &>/dev/null
}

# ======================================================================
# 跳跃端口 NAT 规则（可清除）
# ======================================================================
add_jump_rule() {
    local min="$1"
    local max="$2"
    local listen_port="$3"

    iptables -t nat -A PREROUTING -p udp --dport ${min}:${max} \
        -m comment --comment "hy2_jump" \
        -j DNAT --to-destination :${listen_port}

    ip6tables -t nat -A PREROUTING -p udp --dport ${min}:${max} \
        -m comment --comment "hy2_jump" \
        -j DNAT --to-destination :${listen_port}
}

delete_jump_rule() {
    while iptables -t nat -C PREROUTING -m comment --comment "hy2_jump" &>/dev/null; do
        iptables -t nat -D PREROUTING -m comment --comment "hy2_jump"
    done

    while ip6tables -t nat -C PREROUTING -m comment --comment "hy2_jump" &>/dev/null; do
        ip6tables -t nat -D PREROUTING -m comment --comment "hy2_jump"
    done
}

# ======================================================================
# configure_port_jump（增强版）
# ======================================================================
configure_port_jump() {
    local min="$1"
    local max="$2"
    local listen_port
    listen_port=$(jq -r '.inbounds[0].listen_port' "$config_dir")

    [[ -z "$listen_port" ]] && { _err "HY2 主端口解析失败"; return 1; }

    _green "正在应用跳跃端口区间：${min}-${max}"

    iptables -C INPUT -p udp -m multiport --dports ${min}:${max} -j ACCEPT &>/dev/null ||
        iptables -I INPUT -p udp -m multiport --dports ${min}:${max} -j ACCEPT &>/dev/null

    ip6tables -C INPUT -p udp -m multiport --dports ${min}:${max} -j ACCEPT &>/dev/null ||
        ip6tables -I INPUT -p udp -m multiport --dports ${min}:${max} -j ACCEPT &>/dev/null

    delete_jump_rule
    add_jump_rule "$min" "$max" "$listen_port"

    restart_singbox
    _green "跳跃端口规则已更新完成"
}

handle_range_ports() {
    if [[ -z "$RANGE_PORTS" ]]; then return; fi
    is_valid_range "$RANGE_PORTS" || { _err "RANGE_PORTS 格式错误，应为 10000-20000"; return; }

    local min="${RANGE_PORTS%-*}"
    local max="${RANGE_PORTS#*-}"

    _purple "正在设置跳跃端口：${min}-${max}"
    configure_port_jump "$min" "$max"
}

# ======================================================================
# 安装 Sing-box（核心功能，增强下载容错）
# ======================================================================
install_singbox() {
    clear
    _purple "正在准备 Sing-box，请稍候..."

    mkdir -p "$work_dir"

    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l) ARCH="armv7" ;;
        i386|i686) ARCH="i386" ;;
        riscv64) ARCH="riscv64" ;;
        mips64el) ARCH="mips64le" ;;
        *) _err "不支持的架构: $ARCH" ;;
    esac

    FILE="sing-box-${SINGBOX_VERSION}-linux-${ARCH}.tar.gz"
    URL="https://github.com/SagerNet/sing-box/releases/download/v${SINGBOX_VERSION}/${FILE}"

    _yellow "下载 Sing-box：$URL"

    curl -fSL --retry 3 --retry-delay 2 --connect-timeout 10 \
        -o "$FILE" "$URL" || { _err "下载失败"; exit 1; }

    _yellow "解压中..."
    tar -xzf "$FILE" 2>/dev/null || { _err "解压失败"; exit 1; }
    rm -f "$FILE"

    extracted=$(find . -maxdepth 1 -type d -name "sing-box-*")
    extracted=$(echo "$extracted" | head -n 1)
    [[ -z "$extracted" ]] && { _err "解压目录未找到"; exit 1; }

    mv "$extracted/sing-box" "$work_dir/sing-box"
    chmod +x "$work_dir/sing-box"
    rm -rf "$extracted"

    _green "Sing-box 安装完成"

    is_interactive_mode
    if [[ $? -eq 1 ]]; then
        not_interactive=1
        _white "当前模式：非交互式（自动安装）"
    else
        not_interactive=0
        _white "当前模式：交互式"
    fi

    PORT=$(get_port "$PORT" "$not_interactive")
    _white "HY2 主端口：$PORT"

    UUID=$(get_uuid "$UUID" "$not_interactive")
    HY2_PASSWORD="$UUID"
    _white "UUID：$UUID"

    RANGE_PORTS=$(get_range_ports "$RANGE_PORTS")
    [[ -n "$RANGE_PORTS" ]] && _green "启用跳跃端口范围：$RANGE_PORTS"

    nginx_port=$((PORT + 1))
    export nginx_port
    hy2_port="$PORT"

    allow_port "$PORT" udp

    ipv4_ok=false
    ipv6_ok=false

    ping -4 -c1 -W1 8.8.8.8 >/dev/null 2>&1 && ipv4_ok=true
    ping -6 -c1 -W1 2001:4860:4860::8888 >/dev/null 2>&1 && ipv6_ok=true

    dns_servers=()
    $ipv4_ok && dns_servers+=("\"8.8.8.8\"")
    $ipv6_ok && dns_servers+=("\"2001:4860:4860::8888\"")

    [[ ${#dns_servers[@]} -eq 0 ]] && dns_servers+=("\"8.8.8.8\"")

    if $ipv4_ok && $ipv6_ok; then
        dns_strategy="prefer_ipv4"
    elif $ipv4_ok; then
        dns_strategy="prefer_ipv4"
    else
        dns_strategy="prefer_ipv6"
    fi

    _white "DNS 服务器：${dns_servers[*]}"
    _white "DNS 策略：$dns_strategy"

    openssl ecparam -genkey -name prime256v1 -out "${work_dir}/private.key"
    openssl req -x509 -new -nodes \
        -key "${work_dir}/private.key" \
        -sha256 -days 3650 \
        -subj "/C=US/ST=CA/O=bing.com/CN=bing.com" \
        -out "${work_dir}/cert.pem"

cat > "$config_dir" <<EOF
{
  "log": {
    "disabled": false,
    "level": "error",
    "output": "$work_dir/sb.log",
    "timestamp": true
  },
  "dns": {
    "servers": [
      $(IFS=,; echo "${dns_servers[*]}")
    ],
    "strategy": "$dns_strategy"
  },
  "ntp": {
    "enabled": true,
    "server": "time.apple.com",
    "server_port": 123,
    "interval": "30m"
  },
  "inbounds": [
    {
      "type": "hysteria2",
      "tag": "hy2",
      "listen": "::",
      "listen_port": $hy2_port,
      "users": [
        { "password": "$HY2_PASSWORD" }
      ],
      "ignore_client_bandwidth": false,
      "masquerade": "https://bing.com",
      "tls": {
        "enabled": true,
        "alpn": ["h3"],
        "min_version": "1.3",
        "max_version": "1.3",
        "certificate_path": "$work_dir/cert.pem",
        "key_path": "$work_dir/private.key"
      }
    }
  ],
  "outbounds": [
    { "type": "direct", "tag": "direct" },
    { "type": "block", "tag": "block" }
  ],
  "route": { "final": "direct" }
}
EOF

    _green "配置文件已生成：$config_dir"

cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
Description=Sing-box Service
After=network.target

[Service]
ExecStart=${work_dir}/sing-box run -c ${config_dir}
Restart=on-failure
User=root
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now sing-box
    systemctl restart sing-box

    _green "Sing-box 服务已启动"
}

urlencode() {
    local LANG=C
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            *)
                printf '%%%02X' "'$c"
                ;;
        esac
    done
}

display_qr_link() {
    local TEXT="$1"
    local encoded
    encoded=$(urlencode "$TEXT")
    local QR_URL="https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=$encoded"

    _yellow "📱 二维码链接（点击打开扫码）："
    echo "$QR_URL"
    echo ""
}

generate_all_subscription_files() {
    local base_url="$1"
    mkdir -p "$work_dir"

cat > "$sub_file" <<EOF
# HY2 主订阅
$base_url
EOF

    base64 -w0 "$sub_file" > "${work_dir}/sub_base64.txt"

cat > "${work_dir}/sub.json" <<EOF
{
  "hy2": "$base_url"
}
EOF
}

# ======================================================================
# 输出订阅信息（包含跳跃端口逻辑）
# ======================================================================
generate_subscription_info() {

    ipv4=$(curl -4 -s https://api.ipify.org || true)
    ipv6=$(curl -6 -s https://api64.ipify.org || true)

    if [[ -n "$ipv4" ]]; then
        server_ip="$ipv4"
    else
        server_ip="[$ipv6]"
    fi

    if [[ -n "$RANGE_PORTS" ]]; then
        port_display="端口跳跃区间：$RANGE_PORTS"
        base_url="http://${server_ip}:${RANGE_PORTS}/${HY2_PASSWORD}"
    else
        port_display="单端口模式：${nginx_port}"
        base_url="http://${server_ip}:${nginx_port}/${HY2_PASSWORD}"
    fi

    generate_all_subscription_files "$base_url"

    clear
    _blue  "============================================================"
    _blue  "                    Hy2 节点订阅信息"
    _blue  "============================================================"
    _yellow "服务器 IPv4：${ipv4:-无}"
    _yellow "服务器 IPv6：${ipv6:-无}"
    _yellow "$port_display"
    _yellow "节点密码（UUID）：$HY2_PASSWORD"
    _blue  "============================================================"
    echo ""

    _skyblue "⚠ 提示：部分客户端需要关闭 TLS 校验 / 允许 Insecure"
    _skyblue "  请在 V2RayN / Shadowrocket / Nekobox 等开启『跳过证书验证』"
    echo ""

    node_name="${NODE_NAME:-HY2-Node}"

    if [[ -n "$RANGE_PORTS" ]]; then
        min_port="${RANGE_PORTS%-*}"
        max_port="${RANGE_PORTS#*-}"
        mport_param="${hy2_port},${min_port}-${max_port}"
    else
        mport_param="${hy2_port}"
    fi

    hy2_raw="hysteria2://${HY2_PASSWORD}@${server_ip}:${hy2_port}/?insecure=1&alpn=h3&obfs=none&mport=${mport_param}#${node_name}"

    _green "⓪ Hy2 原生协议（支持所有 Hy2 客户端）"
    _green "$hy2_raw"
    display_qr_link "$hy2_raw"
    _yellow "------------------------------------------------------------"

    _green "① 通用订阅（V2RayN / Shadowrocket / V2RayNG / Nekobox / Karing）"
    _green "$base_url"
    display_qr_link "$base_url"
    _yellow "------------------------------------------------------------"

    clash_sub="https://sublink.eooce.com/clash?config=$base_url"
    _green "② Clash / Mihomo / Clash Verge"
    _green "$clash_sub"
    display_qr_link "$clash_sub"
    _yellow "------------------------------------------------------------"

    singbox_sub="https://sublink.eooce.com/singbox?config=$base_url"
    _green "③ Sing-box SFA / SFM / SFI"
    _green "$singbox_sub"
    display_qr_link "$singbox_sub"
    _yellow "------------------------------------------------------------"

    surge_sub="https://sublink.eooce.com/surge?config=$base_url"
    _green "④ Surge"
    _green "$surge_sub"
    display_qr_link "$surge_sub"
    _yellow "------------------------------------------------------------"

    qx_sub="https://sublink.eooce.com/qx?config=$base_url"
    _green "⑤ Quantumult X"
    _green "$qx_sub"
    display_qr_link "$qx_sub"
    _yellow "------------------------------------------------------------"

    _blue "============================================================"
    _blue "     订阅信息生成完成，如遇不兼容请尝试手动导入"
    _blue "============================================================"
}

# ======================================================================
# Nginx 订阅服务（端口自动修复 & 冲突检测）
# ======================================================================
add_nginx_conf() {

    if ! command_exists nginx; then
        _red "未安装 Nginx，跳过订阅服务配置"
        return
    fi

    mkdir -p /etc/nginx/conf.d

    sub_port_file="/etc/sing-box/sub.port"

    if [[ -f "$sub_port_file" ]]; then
        nginx_port=$(cat "$sub_port_file")
        _green "订阅端口从记录加载：$nginx_port"
    else
        desired_port="$nginx_port"
        actual_port="$desired_port"

        if is_port_occupied "$desired_port"; then
            _yellow "订阅端口 $desired_port 被占用，自动寻找可用端口..."

            for p in $(seq $((desired_port+1)) 65000); do
                if ! is_port_occupied "$p"; then
                    actual_port="$p"
                    _green "订阅端口自动设为：$actual_port"
                    break
                fi
            done
        fi

        nginx_port="$actual_port"
        echo "$nginx_port" > "$sub_port_file"
        _green "订阅端口已写入记录：$nginx_port"
    fi

    rm -f /etc/nginx/conf.d/singbox_sub.conf

cat > /etc/nginx/conf.d/singbox_sub.conf <<EOF
server {
    listen $nginx_port;
    listen [::]:$nginx_port;

    server_name sb_sub.local;

    add_header Cache-Control "no-cache, no-store, must-revalidate";
    add_header Pragma "no-cache";
    add_header Expires "0";

    location /$HY2_PASSWORD {
        alias $sub_file;
        default_type text/plain;
    }

    location / {
        return 404;
    }
}
EOF

    if [[ -f /etc/nginx/nginx.conf ]]; then
        if ! grep -q "conf.d/\*\.conf" /etc/nginx/nginx.conf; then
            sed -i '/http {/a\    include /etc/nginx/conf.d/*.conf;' /etc/nginx/nginx.conf
            _yellow "自动修复 nginx.conf：添加 include /etc/nginx/conf.d/*.conf"
        fi
    fi

    nginx -t >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        _red "Nginx 配置测试失败，请检查 /etc/nginx/conf.d/singbox_sub.conf"
        return
    fi

    systemctl restart nginx
    _green "订阅服务已启动（订阅端口：$nginx_port）"
}

# ======================================================================
# Sing-box 服务管理
# ======================================================================
restart_singbox() {
    if command_exists systemctl; then
        systemctl restart sing-box
    elif command_exists rc-service; then
        rc-service sing-box restart
    fi
}

start_singbox() {
    if command_exists systemctl; then
        systemctl start sing-box
    elif command_exists rc-service; then
        rc-service sing-box start
    fi
}

stop_singbox() {
    if command_exists systemctl; then
        systemctl stop sing-box
    elif command_exists rc-service; then
        rc-service sing-box stop
    fi
}

# ======================================================================
# Sing-box 服务管理菜单
# ======================================================================
manage_singbox() {
    clear
    _blue  "===================================================="
    _green "                 Sing-box 服务管理"
    _blue  "===================================================="
    echo ""

    _green  " 1. 启动 Sing-box"
    _green  " 2. 停止 Sing-box"
    _green  " 3. 重启 Sing-box"
    _purple " 0. 返回主菜单"
    _yellow "----------------------------------------------------"
    echo ""

    read -rp "请输入选项(0-3): " m

    case "$m" in
        1)
            start_singbox
            _green "Sing-box 已启动"
            ;;
        2)
            stop_singbox
            _green "Sing-box 已停止"
            ;;
        3)
            restart_singbox
            _green "Sing-box 已重启"
            ;;
        0)
            return
            ;;
        *)
            _red "无效选项，请重试！"
            ;;
    esac

    echo ""
    read -n 1 -s -r -p $'\033[1;92m按任意键返回菜单...\033[0m'
}

# ======================================================================
# 订阅服务管理
# ======================================================================
disable_open_sub() {
    clear
    _blue  "===================================================="
    _green "                 管理订阅服务"
    _blue  "===================================================="
    echo ""

    _green  " 1. 关闭订阅服务 (Nginx)"
    _green  " 2. 启用订阅服务 (Nginx)"
    _green  " 3. 修改订阅端口"
    _purple " 0. 返回主菜单"
    _yellow "----------------------------------------------------"
    echo ""

    read -rp "请输入选项(0-3): " s

    case "$s" in
        1)
            systemctl stop nginx
            _green "订阅服务已关闭"
            ;;
        2)
            systemctl start nginx
            _green "订阅服务已开启"
            ;;
        3)
            read -rp "请输入新的订阅端口：" new_sub_port
            is_valid_port "$new_sub_port" || { _red "端口无效！"; return; }

            sed -i "s/listen [0-9]\+;/listen $new_sub_port;/" /etc/nginx/conf.d/singbox_sub.conf
            sed -i "s/listen \[::\]:[0-9]\+;/listen [::]:$new_sub_port;/" /etc/nginx/conf.d/singbox_sub.conf

            systemctl restart nginx
            echo "$new_sub_port" > /etc/sing-box/sub.port
            _green "订阅端口修改成功 → $new_sub_port"
            ;;
        0)
            return
            ;;
        *)
            _red "无效选择，请重试！"
            ;;
    esac

    echo ""
    read -n 1 -s -r -p $'\033[1;92m按任意键返回菜单...\033[0m'
}

# ======================================================================
# 查看节点信息
# ======================================================================
check_nodes() {
    clear
    _purple "================== 节点信息 =================="

    if [[ -f "$sub_file" ]]; then
        while IFS= read -r line; do
            _white "$line"
        done < "$sub_file"
    else
        _red "未找到订阅文件：$sub_file"
    fi

    _purple "=============================================="
}
# ======================================================================
# 修改节点配置
# ======================================================================
change_config() {
    clear
    _blue  "===================================================="
    _green "                 修改节点配置"
    _blue  "===================================================="
    echo ""

    _green  " 1. 修改 HY2 主端口"
    _green  " 2. 修改 UUID（密码）"
    _green  " 3. 修改节点名称"
    _green  " 4. 添加跳跃端口"
    _green  " 5. 删除跳跃端口"
    _purple " 0. 返回主菜单"
    _yellow "----------------------------------------------------"
    echo ""

    read -rp "请输入选项(0-5): " choice

    case "$choice" in
        1)
            read -rp "请输入新的 HY2 主端口：" new_port
            is_valid_port "$new_port" || { _red "端口无效！"; return; }
            sed -i "s/\"listen_port\": [0-9]*/\"listen_port\": $new_port/" "$config_dir"
            restart_singbox
            _green "HY2 主端口修改成功：$new_port"
            ;;
        2)
            read -rp "请输入新的 UUID：" new_uuid
            is_valid_uuid "$new_uuid" || { _red "UUID 格式无效！"; return; }
            sed -i "s/\"password\": \".*\"/\"password\": \"$new_uuid\"/" "$config_dir"
            restart_singbox
            _green "UUID 修改成功！"
            ;;
        3)
            read -rp "请输入新的节点名称：" new_name
            echo "#$new_name" > "$sub_file"
            base64 -w0 "$sub_file" > "${work_dir}/sub_base64.txt"
            _green "节点名称修改成功！"
            ;;
        4)
            read -rp "请输入跳跃起始端口：" jmin
            read -rp "请输入跳跃结束端口：" jmax
            is_valid_range "${jmin}-${jmax}" || { _red "跳跃端口范围无效！"; return; }
            configure_port_jump "$jmin" "$jmax"
            _green "跳跃端口已添加：${jmin}-${jmax}"
            ;;
        5)
            delete_jump_rule
            _green "跳跃端口规则已删除！（其他 NAT 规则不受影响）"
            ;;
        0)
            return
            ;;
        *)
            _red "无效选项，请重试！"
            ;;
    esac

    echo ""
    read -n 1 -s -r -p $'\033[1;92m按任意键返回菜单...\033[0m'
}

# ======================================================================
# 卸载 Sing-box（加强防误删 Nginx）
# ======================================================================
uninstall_singbox() {
    read -rp "确认卸载 Sing-box？(y/n): " u
    [[ "$u" != "y" ]] && { _yellow "取消卸载"; return; }

    stop_singbox
    systemctl disable sing-box 2>/dev/null
    rm -f /etc/systemd/system/sing-box.service
    systemctl daemon-reload

    rm -rf /etc/sing-box
    _green "Sing-box 已卸载完成"

    if [[ -f /etc/nginx/conf.d/singbox_sub.conf ]]; then
        rm -f /etc/nginx/conf.d/singbox_sub.conf
        _green "已移除订阅相关的 nginx 配置文件"
    fi

    if command_exists nginx; then
        echo ""
        _yellow "检测到系统安装了 Nginx。"
        _yellow "注意：Nginx 可能被其它网站、面板或服务使用！"
        read -rp "是否卸载 nginx？(y/N)： " delng

        if [[ "$delng" == "y" || "$delng" == "Y" ]]; then
            if command_exists apt; then
                apt remove -y nginx nginx-core
            elif command_exists yum; then
                yum remove -y nginx
            elif command_exists dnf; then
                dnf remove -y nginx
            elif command_exists apk; then
                apk del nginx
            fi
            _green "Nginx 已卸载"
        else
            _green "已保留 nginx（仅删除订阅配置）"
            systemctl restart nginx 2>/dev/null
        fi
    fi

    _green "卸载流程结束"
}

# ======================================================================
# 自动模式安装结束 → 启动服务 & 输出订阅
# ======================================================================
start_service_after_finish_sb() {
    sleep 1

    if command_exists systemctl; then
        systemctl daemon-reload
        systemctl enable sing-box
        systemctl restart sing-box
    fi

    sleep 1

    handle_range_ports

    generate_subscription_info

    add_nginx_conf
}

# ======================================================================
# 自动安装入口
# ======================================================================
quick_install() {
    _purple "进入全自动安装模式..."

    install_common_packages
    install_singbox
    start_service_after_finish_sb

    _green "非交互安装已完成"
}

# ======================================================================
# 菜单界面
# ======================================================================
menu() {
    clear
    _blue "===================================================="
    _gradient "        Sing-box Hysteria2 管理脚本"
    _green   "        作者：$AUTHOR"
    _brown   "        版本：$VERSION"
    _blue "===================================================="
    echo ""

    if systemctl is-active sing-box >/dev/null 2>&1; then
        sb_status="$(_green '运行中')"
    else
        sb_status="$(_red '未运行')"
    fi

    if systemctl is-active nginx >/dev/null 2>&1; then
        ng_status="$(_green '运行中')"
    else
        ng_status="$(_red '未运行')"
    fi

    _yellow " Sing-box 状态：$sb_status"
    _yellow " Nginx 状态：   $ng_status"
    echo ""

    _green  " 1. 安装 Sing-box (HY2)"
    _red    " 2. 卸载 Sing-box"
    _yellow "----------------------------------------"
    _green  " 3. 管理 Sing-box 服务"
    _green  " 4. 查看节点信息"
    _yellow "----------------------------------------"
    _green  " 5. 修改节点配置"
    _green  " 6. 管理订阅服务"
    _yellow "----------------------------------------"
    _purple " 7. 老王工具箱"
    _yellow "----------------------------------------"
    _red    " 0. 退出脚本"
    _yellow "----------------------------------------"
    echo ""

    read -rp "请输入选项(0-7): " choice
}

# ======================================================================
# 主循环
# ======================================================================
main_loop() {
    while true; do
        menu

        case "$choice" in
            1)
                install_common_packages
                install_singbox
                start_service_after_finish_sb
                ;;
            2)
                uninstall_singbox
                ;;
            3)
                manage_singbox
                ;;
            4)
                check_nodes
                ;;
            5)
                change_config
                ;;
            6)
                disable_open_sub
                ;;
            7)
                clear
                bash <(curl -Ls ssh_tool.eooce.com)
                ;;
            0)
                exit 0
                ;;
            *)
                _red "无效选项，请重试"
                ;;
        esac

        read -n 1 -s -r -p $'\033[1;92m按任意键返回主菜单...\033[0m'
    done
}

# ======================================================================
# 主入口 main()
# ======================================================================
main() {
    is_interactive_mode
    if [[ $? -eq 1 ]]; then
        quick_install
        echo ""
        read -n 1 -s -r -p $'\033[1;92m安装完成！按任意键进入主菜单...\033[0m'
        main_loop
    else
        main_loop
    fi
}

main
