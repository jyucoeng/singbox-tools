#!/bin/bash
export LANG=en_US.UTF-8

# ======================================================================
# Sing-box Hysteria2 一键安装脚本（带跳跃端口、订阅服务、自动安装、交互安装）
# ======================================================================

# ======================================================================
# 自动加载环境变量
# - 自动模式依据环境变量是否“存在且非空”
# - load_env_vars 只会 export 非空合法值，避免误触发自动模式
# ======================================================================
load_env_vars() {
    while IFS='=' read -r key value; do
        case "$key" in
            PORT|UUID|RANGE_PORTS|NODE_NAME)
                # 只在 value 非空且合法时导出（关键！）
                if [[ -n "$value" && "$value" =~ ^[a-zA-Z0-9\.\-\:_/]+$ ]]; then
                    export "$key=$value"
                fi
                ;;
        esac
    done < <(env | grep -E '^(PORT|UUID|RANGE_PORTS|NODE_NAME)=')
}
load_env_vars

# ======================================================================
# 自动模式判断
# - 只要四个变量任意一个“非空” → 自动模式
# - 四个变量均为空或未设置 → 交互模式
# ======================================================================
is_interactive_mode() {
    if [[ -n "$PORT" || -n "$UUID" || -n "$RANGE_PORTS" || -n "$NODE_NAME" ]]; then
        return 1   # 自动模式
    else
        return 0   # 交互模式
    fi
}


# ======================================================================
# 清空自动模式环境变量（用于强制进入交互模式）
# ======================================================================
clear_env_vars() {
    unset PORT
    unset UUID
    unset RANGE_PORTS
    unset NODE_NAME
}

# ======================================================================
# 常量 / 目录
# ======================================================================
SINGBOX_VERSION="1.12.13"
AUTHOR="LittleDoraemon"
VERSION="v2.0-final"

work_dir="/etc/sing-box"
config_dir="${work_dir}/config.json"
sub_file="${work_dir}/sub.txt"
sub_port_file="/etc/sing-box/sub.port"

# 默认 UUID（仅在交互模式中使用）
DEFAULT_UUID=$(cat /proc/sys/kernel/random/uuid)

# ======================================================================
# 颜色输出函数（UI 样式）
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

# 彩虹标题
_gradient() {
    local text="$1"
    local colors=(196 202 208 214 220 190 82 46 51 39 33 99 129 163)
    local i=0
    local len=${#colors[@]}

    for (( n=0; n<${#text}; n++ )); do
        printf "\033[38;5;${colors[i]}m%s\033[0m" "${text:n:1}"
        i=$(( (i+1) % len ))
    done
    echo
}

_err() { _red "[错误] $1" >&2; }

# ======================================================================
# Root 校验
# ======================================================================
[[ $EUID -ne 0 ]] && { _err "请使用 root 执行脚本！"; exit 1; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

# ======================================================================
# 依赖安装（关键注释）
# - 避免重复执行 apt update / yum makecache
# - 保证 curl/jq/lsof 可用
# ======================================================================
install_common_packages() {
    local pkgs="tar nginx jq openssl lsof coreutils curl"
    local need_update=1

    for p in $pkgs; do
        if ! command_exists "$p"; then

            # 第一次缺包 → 执行 update（避免重复 update）
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
# 获取公网 IP（多重兜底）
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
# 端口校验（关键逻辑）
# - is_port_occupied 使用 lsof + ss + netstat 三重检测
# - get_port 自动随机端口（交互模式）
# ======================================================================
is_valid_port() {
    [[ "$1" =~ ^[0-9]+$ && "$1" -ge 1 && "$1" -le 65535 ]]
}

is_port_occupied() {
    ss -tuln | grep -q ":$1 " && return 0
    netstat -tuln 2>/dev/null | grep -q ":$1 " && return 0
    lsof -i :"$1" &>/dev/null && return 0
    return 1
}

get_port() {
    local p="$1"

    # 自动模式传入端口，需校验合法性
    if [[ -n "$p" ]]; then
        is_valid_port "$p" || { _err "端口无效"; exit 1; }
        ! is_port_occupied "$p" || { _err "端口已占用"; exit 1; }
        echo "$p"
        return
    fi

    # 交互模式 → 自动生成不重复端口
    while true; do
        local rp
        rp=$(shuf -i 20000-60000 -n 1)
        ! is_port_occupied "$rp" && { echo "$rp"; return; }
    done
}

# ======================================================================
# UUID 处理（关键注释）
# ======================================================================
is_valid_uuid() {
    [[ "$1" =~ ^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$ ]]
}

get_uuid() {
    if [[ -n "$1" ]]; then
        is_valid_uuid "$1" || { _err "UUID 格式错误"; exit 1; }
        echo "$1"
    else
        echo "$DEFAULT_UUID"
    fi
}

# ======================================================================
# 跳跃端口区间校验（用于 NAT 多端口映射）
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
# 防火墙放行（避免重复添加规则）
# - allow_port 会同时处理 IPv4 / IPv6
# - 自动模式和交互模式均会调用
# ======================================================================
allow_port() {
    local port="$1"
    local proto="$2"

    # 若 firewalld 存在，则优先放行
    if command_exists firewall-cmd; then
        firewall-cmd --permanent --add-port=${port}/${proto} &>/dev/null
        firewall-cmd --reload &>/dev/null
    fi

    # iptables 放行（只在不存在时添加）
    iptables -C INPUT -p ${proto} --dport ${port} -j ACCEPT &>/dev/null ||
        iptables -I INPUT -p ${proto} --dport ${port} -j ACCEPT &>/dev/null

    # ip6tables 放行（同逻辑）
    ip6tables -C INPUT -p ${proto} --dport ${port} -j ACCEPT &>/dev/null ||
        ip6tables -I INPUT -p ${proto} --dport ${port} -j ACCEPT &>/dev/null
}

# ======================================================================
# 跳跃端口 NAT 规则（Hy2 使用多端口映射）
# - add_jump_rule：为区间端口 → 主端口 创建 DNAT
# - delete_jump_rule：仅删除带 hy2_jump 注释的 NAT 规则
# ======================================================================
add_jump_rule() {
    local min="$1"
    local max="$2"
    local listen_port="$3"

    # IPv4
    iptables -t nat -A PREROUTING -p udp --dport ${min}:${max} \
        -m comment --comment "hy2_jump" \
        -j DNAT --to-destination :${listen_port}

    # IPv6
    ip6tables -t nat -A PREROUTING -p udp --dport ${min}:${max} \
        -m comment --comment "hy2_jump" \
        -j DNAT --to-destination :${listen_port}
}

delete_jump_rule() {
    # 删除 IPv4 NAT
    while iptables -t nat -C PREROUTING -m comment --comment "hy2_jump" &>/dev/null; do
        iptables -t nat -D PREROUTING -m comment --comment "hy2_jump"
    done

    # 删除 IPv6 NAT
    while ip6tables -t nat -C PREROUTING -m comment --comment "hy2_jump" &>/dev/null; do
        ip6tables -t nat -D PREROUTING -m comment --comment "hy2_jump"
    done
}

# ======================================================================
# 应用跳跃端口区间：
# - 自动打开 INPUT 防火墙
# - 清理旧 NAT → 添加新 NAT
# - 重启 sing-box 服务使生效
# ======================================================================
configure_port_jump() {
    local min="$1"
    local max="$2"

    # 从 config.json 读取 HY2 主端口
    local listen_port
    listen_port=$(jq -r '.inbounds[0].listen_port' "$config_dir")

    [[ -z "$listen_port" ]] && { _err "HY2 主端口解析失败"; return 1; }

    _green "正在应用跳跃端口区间：${min}-${max}"

    # 放行区间端口（multiport）
    iptables -C INPUT -p udp -m multiport --dports ${min}:${max} -j ACCEPT &>/dev/null ||
        iptables -I INPUT -p udp -m multiport --dports ${min}:${max} -j ACCEP

    ip6tables -C INPUT -p udp -m multiport --dports ${min}:${max} -j ACCEPT &>/dev/null ||
        ip6tables -I INPUT -p udp -m multiport --dports ${min}:${max} -j ACCEPT

    # 清理旧规则 → 添加新规则
    delete_jump_rule
    add_jump_rule "$min" "$max" "$listen_port"

    restart_singbox
    _green "跳跃端口规则已更新完成"
}

# ======================================================================
# RANGE_PORTS 入口处理（交互/自动模式通用）
# ======================================================================
handle_range_ports() {
    if [[ -z "$RANGE_PORTS" ]]; then return; fi

    is_valid_range "$RANGE_PORTS" || {
        _err "RANGE_PORTS 格式错误，应为 10000-20000"
        return
    }

    local min="${RANGE_PORTS%-*}"
    local max="${RANGE_PORTS#*-}"

    _purple "正在设置跳跃端口：${min}-${max}"
    configure_port_jump "$min" "$max"
}

# ======================================================================
# 安装 Sing-box 主流程（关键模块，带交互/自动分支）
# ======================================================================
install_singbox() {
    clear
    _purple "正在准备 Sing-box，请稍候..."

    mkdir -p "$work_dir"

    # ------------------------------------------------------------------
    # CPU 架构识别
    # ------------------------------------------------------------------
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

    # 强化下载：失败自动退出
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

    # ------------------------------------------------------------------
    # 判断是否进入自动模式（核心修复）
    # ------------------------------------------------------------------
    is_interactive_mode
    if [[ $? -eq 1 ]]; then
        # 自动模式（环境变量已设置）
        not_interactive=1
        _white "当前模式：自动安装（由环境变量触发）"
    else
        # 交互模式（从菜单进入，或无环境变量）
        not_interactive=0
        _white "当前模式：交互安装（需要由用户输入）"
    fi

    # ------------------------------------------------------------------
    # 自动/交互模式：获取端口 / UUID / RANGE_PORTS
    # ------------------------------------------------------------------
    PORT=$(get_port "$PORT")
    _white "HY2 主端口：$PORT"

    UUID=$(get_uuid "$UUID")
    HY2_PASSWORD="$UUID"
    _white "UUID：$UUID"

    RANGE_PORTS=$(get_range_ports "$RANGE_PORTS")
    [[ -n "$RANGE_PORTS" ]] && _white "启用跳跃端口范围：$RANGE_PORTS"

    # 订阅服务端口（主端口 + 1）
    nginx_port=$((PORT + 1))
    export nginx_port
    hy2_port="$PORT"

    allow_port "$PORT" udp

    # ------------------------------------------------------------------
    # DNS 自动探测：根据 IPv4/IPv6 可用性决定
    # ------------------------------------------------------------------
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

    # ------------------------------------------------------------------
    # TLS 证书生成（自签，用于 Hy2）
    # ------------------------------------------------------------------
    openssl ecparam -genkey -name prime256v1 -out "${work_dir}/private.key"
    openssl req -x509 -new -nodes \
        -key "${work_dir}/private.key" \
        -sha256 -days 3650 \
        -subj "/C=US/ST=CA/O=bing.com/CN=bing.com" \
        -out "${work_dir}/cert.pem"
    # ==================================================================
    # 生成 sing-box 配置文件（Hy2 + 自签证书 + IPv6 支持）
    # ==================================================================
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

    # ==================================================================
    # 注册 systemd 服务（保证系统重启后自动启动）
    # ==================================================================
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

# ======================================================================
# URL encode，用于生成二维码链接（关键工具函数）
# ======================================================================
urlencode() {
    local LANG=C
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "%s" "$c" ;;
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

    _yellow "📱 扫码链接："
    echo "$QR_URL"
    echo ""
}

# ======================================================================
# 生成订阅文件（三格式：TXT / Base64 / JSON）
# ======================================================================
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
# 输出订阅信息 & 生成客户端可用格式（核心可视化逻辑）
# ======================================================================
generate_subscription_info() {

    # 获取 IPv4 / IPv6
    ipv4=$(curl -4 -s https://api.ipify.org || true)
    ipv6=$(curl -6 -s https://api64.ipify.org || true)

    if [[ -n "$ipv4" ]]; then
        server_ip="$ipv4"
    else
        server_ip="[$ipv6]"
    fi

    # 若启用跳跃端口，则订阅 URL 使用范围端口
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
    _blue  "                  Hy2 节点订阅信息"
    _blue  "============================================================"
    _yellow "服务器 IPv4：${ipv4:-无}"
    _yellow "服务器 IPv6：${ipv6:-无}"
    _yellow "$port_display"
    _yellow "节点密码（UUID）：$HY2_PASSWORD"
    _blue  "============================================================"
    echo ""

    _skyblue "⚠ 若客户端报 TLS 证书错误，请开启『跳过证书验证』"
    echo ""

    # 节点名称
    node_name="${NODE_NAME:-HY2-Node}"

    # 构建 Hy2 原生协议字符串（带跳跃端口兼容）
    if [[ -n "$RANGE_PORTS" ]]; then
        min_port="${RANGE_PORTS%-*}"
        max_port="${RANGE_PORTS#*-}"
        mport_param="${hy2_port},${min_port}-${max_port}"
    else
        mport_param="${hy2_port}"
    fi

    hy2_raw="hysteria2://${HY2_PASSWORD}@${server_ip}:${hy2_port}/?insecure=1&alpn=h3&obfs=none&mport=${mport_param}#${node_name}"

    # ===========================
    # 输出：Hy2 协议
    # ===========================
    _green "⓪ Hy2 原生协议（所有 Hy2 客户端支持）"
    _green "$hy2_raw"
    display_qr_link "$hy2_raw"
    _yellow "------------------------------------------------------------"

    # ===========================
    # 输出：通用订阅
    # ===========================
    _green "① 通用订阅（V2RayN / Shadowrocket / Nekobox）"
    _green "$base_url"
    display_qr_link "$base_url"
    _yellow "------------------------------------------------------------"

    # ===========================
    # Clash / Mihomo
    # ===========================
    clash_sub="https://sublink.eooce.com/clash?config=$base_url"
    _green "② Clash / Clash Verge / Mihomo"
    _green "$clash_sub"
    display_qr_link "$clash_sub"
    _yellow "------------------------------------------------------------"

    # ===========================
    # Sing-box
    # ===========================
    singbox_sub="https://sublink.eooce.com/singbox?config=$base_url"
    _green "③ Sing-box SFA / SFI / SFM"
    _green "$singbox_sub"
    display_qr_link "$singbox_sub"
    _yellow "------------------------------------------------------------"

    # ===========================
    # Surge
    # ===========================
    surge_sub="https://sublink.eooce.com/surge?config=$base_url"
    _green "④ Surge"
    _green "$surge_sub"
    display_qr_link "$surge_sub"
    _yellow "------------------------------------------------------------"

    # ===========================
    # Quantumult X
    # ===========================
    qx_sub="https://sublink.eooce.com/qx?config=$base_url"
    _green "⑤ Quantumult X"
    _green "$qx_sub"
    display_qr_link "$qx_sub"
    _yellow "------------------------------------------------------------"

    _blue "============================================================"
    _blue "   订阅信息生成完成，如遇不兼容请手动导入"
    _blue "============================================================"
}

# ======================================================================
# Nginx 订阅服务（自动检测端口冲突 & 自动修复 include）
# ======================================================================
add_nginx_conf() {

    if ! command_exists nginx; then
        _red "未安装 Nginx，跳过订阅服务配置"
        return
    fi

    mkdir -p /etc/nginx/conf.d

    # 持久化订阅端口：若存在则复用
    sub_port_file="/etc/sing-box/sub.port"

    if [[ -f "$sub_port_file" ]]; then
        nginx_port=$(cat "$sub_port_file")
        _green "订阅端口从记录加载：$nginx_port"
    else
        # 第一次安装 → 检查端口是否冲突
        desired_port="$nginx_port"
        actual_port="$desired_port"

        if is_port_occupied "$desired_port"; then
            _yellow "订阅端口 $desired_port 被占用，自动查找可用端口..."

            for p in $(seq $((desired_port+1)) 65000); do
                if ! is_port_occupied "$p"; then
                    actual_port="$p"
                    break
                fi
            done
        fi

        nginx_port="$actual_port"
        echo "$nginx_port" > "$sub_port_file"
        _green "订阅端口已写入：$nginx_port"
    fi

    # 删除旧配置
    rm -f /etc/nginx/conf.d/singbox_sub.conf

    # ==================================================================
    # 写入新的订阅 server 配置
    # ==================================================================
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

    # 自动修复 nginx 主配置 include 规则
    if [[ -f /etc/nginx/nginx.conf ]]; then
        if ! grep -q "conf.d/\*\.conf" /etc/nginx/nginx.conf; then
            sed -i '/http {/a\    include /etc/nginx/conf.d/*.conf;' /etc/nginx/nginx.conf
            _yellow "已自动修复 nginx.conf：加入 conf.d/*.conf"
        fi
    fi

    nginx -t >/dev/null 2>&1 || {
        _red "Nginx 配置测试失败，请检查：/etc/nginx/conf.d/singbox_sub.conf"
        return
    }

    systemctl restart nginx
    _green "订阅服务已启动（端口：$nginx_port）"
}
# ======================================================================
# Sing-box 服务管理（提供启动 / 停止 / 重启）
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
# Sing-box 服务管理菜单（可视化）
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
    echo ""

    read -rp "请输入选项(0-3): " m

    case "$m" in
        1) start_singbox;  _green "Sing-box 已启动";;
        2) stop_singbox;   _green "Sing-box 已停止";;
        3) restart_singbox; _green "Sing-box 已重启";;
        0) return;;
        *) _red "无效选项";;
    esac

    read -n 1 -s -r -p $'\033[1;92m按任意键返回...\033[0m'
}

# ======================================================================
# 查看节点订阅信息（直接读取 sub.txt）
# ======================================================================
check_nodes() {
    clear
    _purple "================== 节点订阅信息 =================="

    if [[ -f "$sub_file" ]]; then
        while IFS= read -r line; do
            _white "$line"
        done < "$sub_file"
    else
        _red "订阅文件不存在：$sub_file"
    fi

    _purple "==================================================="
}

# ======================================================================
# 修改节点配置（端口 / UUID / 节点名称 / 跳跃端口）
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
    echo ""

    read -rp "请输入选项(0-5): " choice

    case "$choice" in
        1)
            read -rp "请输入新的 HY2 主端口：" new_port
            is_valid_port "$new_port" || { _red "端口无效"; return; }
            sed -i "s/\"listen_port\": [0-9]*/\"listen_port\": $new_port/" "$config_dir"
            restart_singbox
            _green "主端口已修改：$new_port"
            ;;
        2)
            read -rp "请输入新的 UUID：" new_uuid
            is_valid_uuid "$new_uuid" || { _red "UUID 格式无效"; return; }
            sed -i "s/\"password\": \".*\"/\"password\": \"$new_uuid\"/" "$config_dir"
            restart_singbox
            _green "UUID 已修改"
            ;;
        3)
            read -rp "请输入新的节点名称：" new_name
            echo "#$new_name" > "$sub_file"
            base64 -w0 "$sub_file" > "${work_dir}/sub_base64.txt"
            _green "节点名称已更新"
            ;;
        4)
            read -rp "请输入跳跃起始端口：" jmin
            read -rp "请输入跳跃结束端口：" jmax
            is_valid_range "${jmin}-${jmax}" || { _red "范围无效"; return; }
            configure_port_jump "$jmin" "$jmax"
            _green "跳跃端口区间已添加：${jmin}-${jmax}"
            ;;
        5)
            delete_jump_rule
            _green "跳跃端口规则已删除"
            ;;
        0)
            return ;;
        *)
            _red "无效选项" ;;
    esac

    read -n 1 -s -r -p $'\033[1;92m按任意键返回...\033[0m'
}

# ======================================================================
# 卸载 Sing-box（带 Nginx 订阅服务处理）
# ======================================================================
uninstall_singbox() {
    read -rp "确认卸载 Sing-box？(y/n): " u
    [[ "$u" != "y" ]] && { _yellow "取消卸载"; return; }

    stop_singbox
    systemctl disable sing-box 2>/dev/null
    rm -f /etc/systemd/system/sing-box.service
    systemctl daemon-reload

    rm -rf /etc/sing-box
    _green "Sing-box 已卸载"

    # 如果订阅服务配置存在，删除它但不强制删除 Nginx
    if [[ -f /etc/nginx/conf.d/singbox_sub.conf ]]; then
        rm -f /etc/nginx/conf.d/singbox_sub.conf
        _green "订阅服务已移除"
    fi

    # 检测是否卸载 nginx（可选）
    if command_exists nginx; then
        read -rp "是否卸载 nginx？(y/N): " delng
        if [[ "$delng" == "y" || "$delng" == "Y" ]]; then
            if command_exists apt; then apt remove -y nginx nginx-core
            elif command_exists yum; then yum remove -y nginx
            elif command_exists dnf; then dnf remove -y nginx
            elif command_exists apk; then apk del nginx
            fi
            _green "nginx 已卸载"
        else
            _yellow "已保留 nginx"
            systemctl restart nginx 2>/dev/null
        fi
    fi

    _green "卸载完成"
}

# ======================================================================
# 自动模式完成后执行：应用跳跃端口 + 输出订阅 + 启动 Nginx
# ======================================================================
start_service_after_finish_sb() {

    sleep 1
    if command_exists systemctl; then
        systemctl daemon-reload
        systemctl enable sing-box
        systemctl restart sing-box
    fi

    sleep 1

    # 若设置 RANGE_PORTS，则应用 NAT 规则
    handle_range_ports

    # 输出可视化订阅信息
    generate_subscription_info

    # 启动订阅服务（Nginx）
    add_nginx_conf
}

# ======================================================================
# 自动安装入口（当检测到环境变量时触发）
# ======================================================================
quick_install() {
    _purple "进入自动安装模式（由环境变量触发）..."

    install_common_packages
    install_singbox
    start_service_after_finish_sb

    _green "自动安装已完成"
}

# ======================================================================
# 菜单主界面（交互入口）
# ======================================================================
menu() {
    clear
    _blue "===================================================="
    _gradient "        Sing-box Hysteria2 管理脚本"
    _green   "               作者：$AUTHOR"
    _brown   "               版本：$VERSION"
    _blue "===================================================="
    echo ""

    # 服务状态检查
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
    echo ""

    read -rp "请输入选项(0-7): " choice
}

# ======================================================================
# 主循环（菜单模式执行）
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
            2)  uninstall_singbox ;;
            3)  manage_singbox ;;
            4)  check_nodes ;;
            5)  change_config ;;
            6)  disable_open_sub ;;
            7)  bash <(curl -Ls ssh_tool.eooce.com) ;;
            0)  exit 0 ;;
            *)  _red "无效选项" ;;
        esac

        read -n 1 -s -r -p $'\033[1;92m按任意键返回主菜单...\033[0m'
    done
}

# ======================================================================
# 主入口：根据环境变量自动或手动安装
# - 若任意变量非空 → 自动安装
# - 否则进入交互菜单
# ======================================================================
main() {

    is_interactive_mode

    if [[ $? -eq 1 ]]; then
        # 自动模式
        quick_install
        read -n 1 -s -r -p $'\033[1;92m安装完成！按任意键进入主菜单...\033[0m'
        main_loop
    else
        clear_env_vars   # 强制进入交互模式
        # 交互模式（菜单）
        main_loop
    fi
}

main
