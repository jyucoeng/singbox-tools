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
    eval "$(env | grep -E '^(PORT|UUID|RANGE_PORTS|NODE_NAME)=' | sed 's/^/export /')"
}
load_env_vars

# ======================================================================
# 判断是否为非交互模式（PORT / UUID / RANGE_PORTS 任意存在即自动安装）
# ======================================================================
is_interactive_mode() {
    if [[ -n "$PORT" || -n "$UUID" || -n "$RANGE_PORTS" || -n "$NODE_NAME" ]]; then
        return 1  # 自动安装
    else
        return 0  # 菜单模式
    fi
}

# ======================================================================
# 常量
# ======================================================================
SINGBOX_VERSION="1.12.13"
AUTHOR="LittleDoraemon"
VERSION="v2.0-final"

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
_red()   { echo -e "\e[1;91m$1\033[0m"; }
_green() { echo -e "\e[1;32m$1\033[0m"; }
_yellow(){ echo -e "\e[1;33m$1\033[0m"; }
_purple(){ echo -e "\e[1;35m$1\033[0m"; }
_skyblue(){ echo -e "\e[1;36m$1\033[0m"; }
_blue(){ echo -e "\e[1;34m$1\033[0m"; }

_err() { _red "[错误] $1" >&2; }

# ======================================================================
# 基础工具检查 / Root 检查
# ======================================================================
[[ $EUID -ne 0 ]] && { _err "请使用 root 执行脚本！"; exit 1; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

# ======================================================================
# 依赖安装
# ======================================================================
install_common_packages() {
    local pkgs="tar nginx jq openssl lsof coreutils curl"
    for p in $pkgs; do
        if ! command_exists "$p"; then
            _yellow "安装依赖：$p"
            if command_exists apt; then apt update -y && apt install -y $p; fi
            if command_exists yum; then yum install -y $p; fi
            if command_exists dnf; then dnf install -y $p; fi
            if command_exists apk; then apk add $p; fi
        fi
    done
}

# ======================================================================
# 获取公网 IP
# ======================================================================
get_realip() {
    local ip4 ip6
    ip4=$(curl -4 -s https://api.ipify.org)
    ip6=$(curl -6 -s https://api64.ipify.org)

    if [[ -n "$ip4" ]]; then echo "$ip4"; return; fi
    if [[ -n "$ip6" ]]; then echo "[$ip6]"; return; fi
    echo "0.0.0.0"
}

# ======================================================================
# 端口校验
# ======================================================================
is_valid_port() { [[ "$1" =~ ^[0-9]+$ && "$1" -ge 1 && "$1" -le 65535 ]]; }
is_port_occupied() { lsof -i :"$1" >/dev/null 2>&1; }

get_port() {
    local p="$1"
    if [[ -n "$p" ]]; then
        is_valid_port "$p" || { _err "端口无效"; exit 1; }
        ! is_port_occupied "$p" || { _err "端口已占用"; exit 1; }
        echo "$p"; return
    fi
    # 自动生成
    while true; do
        local rp=$(shuf -i 20000-60000 -n 1)
        ! is_port_occupied "$rp" && { echo "$rp"; return; }
    done
}

# ======================================================================
# UUID 校验
# ======================================================================
is_valid_uuid() { [[ "$1" =~ ^[a-fA-F0-9-]{36}$ ]]; }
get_uuid() { [[ -n "$1" ]] && echo "$1" || echo "$DEFAULT_UUID"; }

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
# 安全防火墙放行函数
# ======================================================================
allow_port() {
    local port="$1"
    local proto="$2"
    firewall-cmd --permanent --add-port=${port}/${proto} 2>/dev/null
    firewall-cmd --reload 2>/dev/null

    iptables -I INPUT -p ${proto} --dport ${port} -j ACCEPT 2>/dev/null
    ip6tables -I INPUT -p ${proto} --dport ${port} -j ACCEPT 2>/dev/null
}

# ======================================================================
# 精准可删除的端口跳跃 NAT 规则（使用 --comment 标记）
# ======================================================================

# 添加跳跃端口 NAT 规则
add_jump_rule() {
    local min="$1"
    local max="$2"
    local listen_port="$3"

    # IPv4
    iptables -t nat -A PREROUTING \
        -p udp --dport ${min}:${max} \
        -m comment --comment "hy2_jump" \
        -j DNAT --to-destination :${listen_port}

    # IPv6
    ip6tables -t nat -A PREROUTING \
        -p udp --dport ${min}:${max} \
        -m comment --comment "hy2_jump" \
        -j DNAT --to-destination :${listen_port}
}

# 删除跳跃端口 NAT 规则（只删 hy2_jump，不动别的规则）
delete_jump_rule() {
    # IPv4
    while iptables -t nat -C PREROUTING -m comment --comment "hy2_jump" &>/dev/null; do
        iptables -t nat -D PREROUTING -m comment --comment "hy2_jump"
    done

    # IPv6
    while ip6tables -t nat -C PREROUTING -m comment --comment "hy2_jump" &>/dev/null; do
        ip6tables -t nat -D PREROUTING -m comment --comment "hy2_jump"
    done
}

# ======================================================================
# configure_port_jump（修复版 — 可靠端口跳跃）
# ======================================================================
configure_port_jump() {
    local min="$1"
    local max="$2"

    # 检查 HY2 主端口
    local listen_port
    listen_port=$(jq -r '.inbounds[0].listen_port' "$config_dir")

    [[ -z "$listen_port" ]] && { _err "HY2 主端口解析失败"; return 1; }

    _green "正在应用跳跃端口区间：${min}-${max}"

    # 开放防火墙（使用 multiport）
    if command_exists iptables; then
        iptables -I INPUT -p udp -m multiport --dports ${min}:${max} -j ACCEPT 2>/dev/null
    fi
    if command_exists ip6tables; then
        ip6tables -I INPUT -p udp -m multiport --dports ${min}:${max} -j ACCEPT 2>/dev/null
    fi

    # 删除旧规则，防止重复叠加
    delete_jump_rule

    # 添加新规则
    add_jump_rule "$min" "$max" "$listen_port"

    restart_singbox
    _green "跳跃端口规则已更新完成"
}

# ======================================================================
# handle_range_ports（调用入口）
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
# 安装 Sing-box（核心功能）
# ======================================================================
install_singbox() {
    clear
    _purple "正在准备 Sing-box，请稍候..."

    mkdir -p "$work_dir"

    # =======================
    # CPU 架构检测
    # =======================
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)   ARCH="amd64" ;;
        aarch64)  ARCH="arm64" ;;
        armv7l)   ARCH="armv7" ;;
        i386|i686)ARCH="i386" ;;
        riscv64)  ARCH="riscv64" ;;
        mips64el) ARCH="mips64le" ;;
        *) _err "不支持的架构: $ARCH" ;;
    esac

    FILE="sing-box-${SINGBOX_VERSION}-linux-${ARCH}.tar.gz"
    URL="https://github.com/SagerNet/sing-box/releases/download/v${SINGBOX_VERSION}/${FILE}"

    _yellow "下载 Sing-box：$URL"
    curl -L -o "$FILE" "$URL" || { _err "下载失败"; exit 1; }

    _yellow "解压中..."
    tar -xzf "$FILE" || { _err "解压失败"; exit 1; }
    rm -f "$FILE"

    extracted=$(find . -maxdepth 1 -type d -name "sing-box-*")
    extracted=$(echo "$extracted" | head -n 1)
    [[ -z "$extracted" ]] && { _err "解压目录未找到"; exit 1; }

    mv "$extracted/sing-box" "$work_dir/sing-box"
    chmod +x "$work_dir/sing-box"
    rm -rf "$extracted"

    _green "Sing-box 安装完成"

    # =======================
    # 模式识别：自动 / 交互
    # =======================
    is_interactive_mode
    if [[ $? -eq 1 ]]; then
        not_interactive=1
        _white "当前模式：非交互式（自动安装）"
    else
        not_interactive=0
        _white "当前模式：交互式"
    fi

    # =======================
    # 获取端口、UUID、跳跃端口
    # =======================
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

    # =======================
    # IPv4 / IPv6 DNS 自动探测
    # =======================
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

    # =======================
    # TLS 自签证书生成
    # =======================
    openssl ecparam -genkey -name prime256v1 -out "${work_dir}/private.key"
    openssl req -x509 -new -nodes \
        -key "${work_dir}/private.key" \
        -sha256 -days 3650 \
        -subj "/C=US/ST=CA/O=bing.com/CN=bing.com" \
        -out "${work_dir}/cert.pem"

    # =======================
    # 生成 config.json（无错误，支持 IPv6）
    # =======================
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

    # =======================
    # systemd 服务文件（唯一版本）
    # =======================
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

# URL 编码函数（Bash 原生
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

# ======================================================================
# 生成二维码可点击链接
# ======================================================================
display_qr_link() {
    local TEXT="$1"
    local encoded
    encoded=$(urlencode "$TEXT")

    local QR_URL="https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=$encoded"

    _yellow "📱 二维码链接（点击打开扫码）："
    echo "$QR_URL"
    echo ""
}


# ======================================================================
# 写入节点信息
# ======================================================================
generate_all_subscription_files() {
    local base_url="$1"

    mkdir -p "$work_dir"

    # ① sub.txt（简单纯文本订阅）
cat > "$sub_file" <<EOF
# HY2 主订阅
$base_url
EOF

    # ② Base64 文件（V2RayN / Shadowrocket / 特殊客户端会用到）
    base64 -w0 "$sub_file" > "${work_dir}/sub_base64.txt"

    # ③ JSON（高级客户端使用）
cat > "${work_dir}/sub.json" <<EOF
{
  "hy2": "$base_url"
}
EOF
}


# ======================================================================
# 输出订阅信息（美观 UI）
# ======================================================================
generate_subscription_info() {

    # 获取公网 IP（IPv4 / IPv6 自动识别）
    ipv4=$(curl -4 -s https://api.ipify.org || true)
    ipv6=$(curl -6 -s https://api64.ipify.org || true)

    # 自动选择主 IP（优先 IPv4）
    if [[ -n "$ipv4" ]]; then
        server_ip="$ipv4"
    else
        server_ip="[$ipv6]"
    fi

    # 拼接订阅 URL
    if [[ -n "$RANGE_PORTS" ]]; then
        port_display="端口跳跃区间：$RANGE_PORTS"
        base_url="http://${server_ip}:${RANGE_PORTS}/${HY2_PASSWORD}"
    else
        port_display="单端口模式：${nginx_port}"
        base_url="http://${server_ip}:${nginx_port}/${HY2_PASSWORD}"
    fi

    # 生成订阅文件
    generate_all_subscription_files "$server_ip" "$base_url"

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

    _skyblue "⚠ 温馨提示：部分客户端需要关闭 TLS 校验 / 允许 Insecure"
    _skyblue "  请在 V2RayN / Shadowrocket / Nekobox / Karing 等中启用『跳过证书验证』"

    echo ""

    # ============================================================
    # ⓪ Hy2 原生协议串（自动兼容带跳跃端口与不带跳跃端口）
    # ============================================================

    # 节点名称（不转义）
    node_name="${NODE_NAME:-HY2-Node}"

    # 是否存在跳跃端口
    if [[ -n "$RANGE_PORTS" ]]; then
        # 拆分跳跃端口范围
        min_port="${RANGE_PORTS%-*}"
        max_port="${RANGE_PORTS#*-}"

        # 带跳跃端口的 mport 参数
        mport_param="${hy2_port},${min_port}-${max_port}"
    else
        # 无跳跃端口 → 只使用主端口（不重复输出）
        mport_param="${hy2_port}"
    fi

    # Hy2 原生协议串
    hy2_raw="hysteria2://${HY2_PASSWORD}@${server_ip}:${hy2_port}/?insecure=1&alpn=h3&obfs=none&mport=${mport_param}#${node_name}"

    _green "⓪ Hy2 原生协议（支持所有原生 Hy2 客户端）"
    _green "$hy2_raw"
    display_qr_link "$hy2_raw"
    _yellow "------------------------------------------------------------"

    # =============================
    # ① 通用订阅
    # =============================
    _green "① 通用订阅（V2RayN / Shadowrocket / V2RayNG / NekoBox / Loon / Karing）"
    _green "$base_url"
    display_qr_link "$base_url"
    _yellow "------------------------------------------------------------"

    # =============================
    # ② Clash / Mihomo
    # =============================
    clash_sub="https://sublink.eooce.com/clash?config=$base_url"
    _green "② Clash / Mihomo / Clash Verge"
    _green "$clash_sub"
    display_qr_link "$clash_sub"
    _yellow "------------------------------------------------------------"

    # =============================
    # ③ Sing-box
    # =============================
    singbox_sub="https://sublink.eooce.com/singbox?config=$base_url"
    _green "③ Sing-box (SFA / SFI / SFM)"
    _green "$singbox_sub"
    display_qr_link "$singbox_sub"
    _yellow "------------------------------------------------------------"

    # =============================
    # ④ Surge
    # =============================
    surge_sub="https://sublink.eooce.com/surge?config=$base_url"
    _green "④ Surge"
    _green "$surge_sub"
    display_qr_link "$surge_sub"
    _yellow "------------------------------------------------------------"

    # =============================
    # ⑤ Quantumult X
    # =============================
    qx_sub="https://sublink.eooce.com/qx?config=$base_url"
    _green "⑤ Quantumult X"
    _green "$qx_sub"
    display_qr_link "$qx_sub"
    _yellow "------------------------------------------------------------"

    _blue "============================================================"
    _blue "         订阅信息生成完成，如遇不兼容请手动导入"
    _blue "============================================================"
}

# ======================================================================
# Nginx 订阅服务（自动检测冲突、订阅端口持久化、自动修复）
# ======================================================================
add_nginx_conf() {

    if ! command_exists nginx; then
        _red "未安装 Nginx，跳过订阅服务"
        return
    fi

    mkdir -p /etc/nginx/conf.d

    # -------------------------------
    # 订阅端口持久化（确保订阅地址永不变）
    # -------------------------------
    sub_port_file="/etc/sing-box/sub.port"

    if [[ -f "$sub_port_file" ]]; then
        # 第二次运行及以后 → 使用记录端口
        nginx_port=$(cat "$sub_port_file")
        _green "订阅端口从记录加载：$nginx_port"
    else
        # 第一次运行 → 检查端口是否冲突
        desired_port="$nginx_port"
        actual_port="$desired_port"

        if lsof -i:${desired_port} >/dev/null 2>&1; then
            _yellow "订阅端口 $desired_port 被占用，首次自动分配新端口..."

            # 自动寻找下一个可用端口（不会破坏系统）
            for p in $(seq $((desired_port+1)) 65000); do
                if ! lsof -i:${p} >/dev/null 2>&1; then
                    actual_port="$p"
                    _green "订阅端口自动设为：$actual_port"
                    break
                fi
            done
        fi

        nginx_port="$actual_port"

        # 第一次写入端口记录 → 确保此后永不改变
        echo "$nginx_port" > "$sub_port_file"
        _green "订阅端口已写入记录：$nginx_port"
    fi

    # -------------------------------
    # 删除旧的 singbox_sub.conf（无损）
    # -------------------------------
    rm -f /etc/nginx/conf.d/singbox_sub.conf

    # -------------------------------
    # 创建全新且无冲突的订阅 server 配置
    # 使用唯一 server_name sb_sub.local 避免冲突
    # -------------------------------
cat > /etc/nginx/conf.d/singbox_sub.conf <<EOF
server {
    listen $nginx_port;
    listen [::]:$nginx_port;

    # 避免与其它 server_name "_" 冲突
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

    # -------------------------------
    # 自动修复 nginx.conf 里的 include
    # -------------------------------
    if [[ -f /etc/nginx/nginx.conf ]]; then
        if ! grep -q "conf.d/\*\.conf" /etc/nginx/nginx.conf; then
            sed -i '/http {/a\    include /etc/nginx/conf.d/*.conf;' /etc/nginx/nginx.conf
            _yellow "修复：已自动补全 nginx.conf 中的 include /etc/nginx/conf.d/*.conf"
        fi
    fi

    # -------------------------------
    # 检查语法 & 重启 nginx
    # -------------------------------
    nginx -t >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        _red "Nginx 配置测试失败，请检查 /etc/nginx/conf.d/singbox_sub.conf"
        return
    fi

    systemctl restart nginx
    _green "订阅服务已成功启动（订阅端口：$nginx_port）"
}


# ======================================================================
# Sing-box 服务管理（systemd / openrc 兼容）
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
    _green "=== Sing-box 服务管理 ==="
    echo ""
    echo -e " ${green}1.${re} 启动 Sing-box"
    echo -e " ${green}2.${re} 停止 Sing-box"
    echo -e " ${green}3.${re} 重启 Sing-box"
    echo -e " ${purple}0.${re} 返回"
    echo ""

    read -rp "请输入选择：" m

    case "$m" in
        1) start_singbox; _green "已启动 Sing-box";;
        2) stop_singbox;  _green "已停止 Sing-box";;
        3) restart_singbox; _green "已重启 Sing-box";;
        0) return ;;
        *) _red "无效选择" ;;
    esac
}

# ======================================================================
# 订阅服务管理（启用 / 关闭 / 修改端口）
# ======================================================================
disable_open_sub() {
    clear
    _green "=== 管理订阅服务 ==="
    echo ""
    echo -e " ${green}1.${re} 关闭订阅服务(Nginx)"
    echo -e " ${green}2.${re} 启用订阅服务(Nginx)"
    echo -e " ${green}3.${re} 修改订阅端口"
    echo -e " ${purple}0.${re} 返回"
    echo ""

    read -rp "请输入选择:" s

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
            read -rp "请输入新的订阅端口: " new_sub_port
            is_valid_port "$new_sub_port" || { _red "端口无效"; return; }

            sed -i "s/listen [0-9]*/listen $new_sub_port/" /etc/nginx/conf.d/singbox_sub.conf
            sed -i "s/listen \[::]:[0-9]*/listen [::]:$new_sub_port/" /etc/nginx/conf.d/singbox_sub.conf

            systemctl restart nginx
            _green "订阅端口修改成功 → $new_sub_port"
            ;;
        0) return ;;
        *) _red "无效选择" ;;
    esac
}

# ======================================================================
# 查看节点信息（sub.txt 内容）
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
# 修改节点配置（端口 / UUID / 名称 / 跳跃端口）
# ======================================================================
change_config() {
    clear
    _green "=== 修改节点配置 ==="
    echo ""
    echo -e " ${green}1.${re} 修改主端口(HY2 listen_port)"
    echo -e " ${green}2.${re} 修改 UUID（密码）"
    echo -e " ${green}3.${re} 修改节点名称（仅订阅展示）"
    echo -e " ${green}4.${re} 添加跳跃端口"
    echo -e " ${green}5.${re} 删除跳跃端口"
    echo -e " ${purple}0.${re} 返回"
    echo ""

    read -rp "请输入选项：" choice

    case "$choice" in
        1)
            read -rp "请输入新主端口：" newp
            is_valid_port "$newp" || { _red "端口无效"; return; }
            sed -i "s/\"listen_port\": [0-9]*/\"listen_port\": $newp/" "$config_dir"
            restart_singbox
            _green "主端口已更新为：$newp"
            ;;
        2)
            read -rp "请输入新的 UUID：" newuuid
            is_valid_uuid "$newuuid" || { _red "UUID 格式无效"; return; }
            sed -i "s/\"password\": \".*\"/\"password\": \"$newuuid\"/" "$config_dir"
            restart_singbox
            _green "UUID 修改成功"
            ;;
        3)
            read -rp "请输入新的节点名称：" newname
            echo "#$newname" > "$sub_file"
            base64 -w0 "$sub_file" > "${work_dir}/sub_base64.txt"
            _green "节点名称已更新"
            ;;
        4)
            read -rp "请输入跳跃起始端口：" jmin
            read -rp "请输入跳跃结束端口：" jmax
            is_valid_range "${jmin}-${jmax}" || { _red "范围无效"; return; }
            configure_port_jump "$jmin" "$jmax"
            ;;
        5)
            delete_jump_rule
            _green "跳跃端口规则已删除（未影响其他 NAT 规则）"
            ;;
        0)
            return ;;
        *)
            _red "无效选项" ;;
    esac
}

# ======================================================================
# 卸载 Sing-box（完全清除）
# ======================================================================
uninstall_singbox() {
    read -rp "确认卸载 Sing-box？(y/n): " u
    [[ "$u" != "y" ]] && { _yellow "取消卸载"; return; }

    # 停止服务
    stop_singbox
    systemctl disable sing-box 2>/dev/null
    rm -f /etc/systemd/system/sing-box.service
    systemctl daemon-reload

    # 删除 Sing-box 程序与配置
    rm -rf /etc/sing-box
    _green "Sing-box 已卸载完成"

    # 删除订阅服务配置（不会影响系统原 nginx）
    if [[ -f /etc/nginx/conf.d/singbox_sub.conf ]]; then
        rm -f /etc/nginx/conf.d/singbox_sub.conf
        _green "已移除订阅相关的 nginx 配置文件"
    fi

    # 检查 nginx 是否安装
    if command_exists nginx; then
        echo ""
        _yellow "系统检测到 Nginx 已安装。"
        _yellow "警告：Nginx 可能被其它网站、服务、面板或反代使用。"
        _yellow "仅当你确定不再需要 nginx 时，才建议卸载。"
        echo ""
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
            _green "已保留 nginx（仅删除订阅配置，不影响其它 nginx 服务）"
            systemctl restart nginx 2>/dev/null
        fi
    fi

    _green "卸载流程结束"
}


# ======================================================================
# Nginx + Sing-box 服务启动逻辑（自动模式完成后调用）
# ======================================================================
start_service_after_finish_sb() {

    sleep 1

    # 启动 Sing-box systemd 服务
    if command_exists systemctl; then
        systemctl daemon-reload
        systemctl enable sing-box
        systemctl restart sing-box
    fi

    sleep 1

    # 跳跃端口规则
    handle_range_ports

    # 创建订阅与展示界面
    generate_subscription_info

    # Nginx 订阅服务
    add_nginx_conf
}

# ======================================================================
# 自动模式（自动安装 + 输出订阅）
# ======================================================================
quick_install() {
    _purple "进入全自动安装模式..."

    install_common_packages
    install_singbox
    start_service_after_finish_sb

    _green "非交互安装已完成"
}

# ======================================================================
# 菜单界面（主界面）
# ======================================================================
menu() {
    clear
    _blue "===================================================="
    _blue "        Sing-box Hysteria2 管理脚本"
    _blue "        作者：$AUTHOR"
    _blue "        版本：$VERSION"
    _blue "===================================================="
    echo ""

    # 服务状态（彩色显示）
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
    _purple " 7. 内置 SSH 工具箱"
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
            2) uninstall_singbox ;;
            3) manage_singbox ;;
            4) check_nodes ;;
            5) change_config ;;
            6) disable_open_sub ;;
            7)
                clear
                bash <(curl -Ls ssh_tool.eooce.com)
                ;;
            0) exit 0 ;;
            *) _red "无效选项，请重试" ;;
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
        # 非交互式自动安装
        quick_install
        echo ""
        read -n 1 -s -r -p $'\033[1;92m安装完成！按任意键进入主菜单...\033[0m'
        main_loop
    else
        # 交互式模式
        main_loop
    fi
}

# 执行主入口
main
