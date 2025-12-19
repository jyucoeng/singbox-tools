#!/bin/bash
export LANG=en_US.UTF-8

# ======================================================================
# Sing-box Hy2 一键脚本（整合版）
# 作者：littleDoraemon
# 版本：v3.0
# ======================================================================

# ======================================================================
# 环境变量加载（自动模式依据环境变量是否非空）
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
# 判断自动/交互模式
# ======================================================================
is_interactive_mode() {
    if [[ -n "$PORT" || -n "$UUID" || -n "$RANGE_PORTS" || -n "$NODE_NAME" ]]; then
        return 1   # 自动模式
    else
        return 0   # 交互模式
    fi
}

# ======================================================================
# 常量定义
# ======================================================================
SINGBOX_VERSION="1.12.13"
AUTHOR="littleDoraemon"
VERSION="v3.0"

work_dir="/etc/sing-box"
client_dir="${work_dir}/url.txt"
config_dir="${work_dir}/config.json"
sub_file="${work_dir}/sub.txt"
sub_port_file="/etc/sing-box/sub.port"
DEFAULT_UUID=$(cat /proc/sys/kernel/random/uuid)

# ======================================================================
# UI 颜色
# ======================================================================
re="\033[0m"
white()  { echo -e "\033[1;37m$1\033[0m"; }
red()    { echo -e "\e[1;91m$1\033[0m"; }
green()  { echo -e "\e[1;32m$1\033[0m"; }
yellow() { echo -e "\e[1;33m$1\033[0m"; }
purple() { echo -e "\e[1;35m$1\033[0m"; }
blue()   { echo -e "\e[1;34m$1\033[0m"; }

gradient() {
    local text="$1"
    local colors=(196 202 208 214 220 190 82 46 51 39 33 99 129 163)
    local i=0
    for (( n=0; n<${#text}; n++ )); do
        printf "\033[38;5;${colors[i]}m%s\033[0m" "${text:n:1}"
        i=$(( (i+1) % ${#colors[@]} ))
    done
    echo
}

err() { red "[错误] $1" >&2; }

# ======================================================================
# Root 检查
# ======================================================================
[[ $EUID -ne 0 ]] && { err "请使用 root 权限运行脚本"; exit 1; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

# ======================================================================
# 依赖安装
# ======================================================================
install_common_packages() {
    local pkgs="tar jq openssl lsof curl coreutils qrencode nginx"
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
                fi
                need_update=0
            fi

            yellow "安装依赖：$p"
            if command_exists apt; then apt install -y "$p"
            elif command_exists yum; then yum install -y "$p"
            elif command_exists dnf; then dnf install -y "$p"
            elif command_exists apk; then apk add "$p"
            fi
        fi
    done
}

# ======================================================================
# 获取公网 IP（优先IPv4）
# ======================================================================
get_realip() {
    ip4=$(curl -4 -s https://api.ipify.org)
    ip6=$(curl -6 -s https://api64.ipify.org)

    [[ -n "$ip4" ]] && echo "$ip4" && return
    [[ -n "$ip6" ]] && echo "[$ip6]" && return
    echo "0.0.0.0"
}

# ======================================================================
# 端口检测
# ======================================================================
is_valid_port() { [[ "$1" =~ ^[0-9]+$ && "$1" -ge 1 && "$1" -le 65535 ]]; }

is_port_occupied() {
    ss -tuln | grep -q ":$1 " && return 0
    lsof -i :"$1" &>/dev/null && return 0
    netstat -tuln 2>/dev/null | grep -q ":$1 " && return 0
    return 1
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
        rp=$(shuf -i 20000-60000 -n 1)
        ! is_port_occupied "$rp" && { echo "$rp"; return; }
    done
}

# ======================================================================
# UUID
# ======================================================================
is_valid_uuid() {
    [[ "$1" =~ ^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$ ]]
}

get_uuid() {
    if [[ -n "$1" ]]; then
        is_valid_uuid "$1" || { err "UUID 格式错误"; exit 1; }
        echo "$1"
    else
        echo "$DEFAULT_UUID"
    fi
}

# ======================================================================
# 跳跃端口格式校验
# ======================================================================
is_valid_range() {
    [[ "$1" =~ ^([0-9]+)-([0-9]+)$ ]] || return 1
    min="${BASH_REMATCH[1]}"
    max="${BASH_REMATCH[2]}"
    is_valid_port "$min" && is_valid_port "$max" && [[ $min -lt $max ]]
}

get_range_ports() {
    local r="$1"
    [[ -z "$r" ]] && { echo ""; return; }
    is_valid_range "$r" || { err "跳跃端口格式错误（例如 10000-20000）"; exit 1; }
    echo "$r"
}

# ======================================================================
# 防火墙放行
# ======================================================================
allow_port() {
    local port="$1"

    if command_exists firewall-cmd; then
        firewall-cmd --permanent --add-port=${port}/udp &>/dev/null
        firewall-cmd --reload &>/dev/null
    fi

    iptables  -C INPUT -p udp --dport "$port" -j ACCEPT &>/dev/null ||
        iptables  -I INPUT -p udp --dport "$port" -j ACCEPT

    ip6tables -C INPUT -p udp --dport "$port" -j ACCEPT &>/dev/null ||
        ip6tables -I INPUT -p udp --dport "$port" -j ACCEPT
}

# ======================================================================
# NAT 跳跃端口
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
# 应用跳跃端口区间 NAT
# ======================================================================
configure_port_jump() {
    local min="$1"
    local max="$2"
    local listen_port
    listen_port=$(jq -r '.inbounds[0].listen_port' "$config_dir")

    [[ -z "$listen_port" ]] && { err "无法读取 HY2 主端口"; return 1; }

    # 放行跳跃端口区间
    iptables -C INPUT -p udp -m multiport --dports ${min}:${max} -j ACCEPT &>/dev/null ||
        iptables -I INPUT -p udp -m multiport --dports ${min}:${max} -j ACCEPT

    ip6tables -C INPUT -p udp -m multiport --dports ${min}:${max} -j ACCEPT &>/dev/null ||
        ip6tables -I INPUT -p udp -m multiport --dports ${min}:${max} -j ACCEPT

    # 清除旧规则 → 添加新规则
    delete_jump_rule
    add_jump_rule "$min" "$max" "$listen_port"

    restart_singbox
    green "跳跃端口区间 ${min}-${max} 已应用"
}

handle_range_ports() {
    [[ -z "$RANGE_PORTS" ]] && return

    is_valid_range "$RANGE_PORTS" || { err "跳跃端口格式错误"; return; }

    local min="${RANGE_PORTS%-*}"
    local max="${RANGE_PORTS#*-}"

    configure_port_jump "$min" "$max"
}

# ======================================================================
# install_singbox（自动模式 + 交互模式）
# ======================================================================
install_singbox() {
    clear
    purple "准备下载并安装 Sing-box..."

    mkdir -p "$work_dir"

    # -------------------- CPU 架构 --------------------
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l)  ARCH="armv7" ;;
        i386|i686) ARCH="i386" ;;
        riscv64) ARCH="riscv64" ;;
        mips64el) ARCH="mips64le" ;;
        *) err "不支持的架构: $ARCH" ;;
    esac

    FILE="sing-box-${SINGBOX_VERSION}-linux-${ARCH}.tar.gz"
    URL="https://github.com/SagerNet/sing-box/releases/download/v${SINGBOX_VERSION}/${FILE}"

    yellow "下载 Sing-box：$URL"
    curl -fSL --retry 3 --retry-delay 2 --connect-timeout 10 -o "$FILE" "$URL" \
        || { err "下载失败"; exit 1; }

    yellow "解压中..."
    tar -xzf "$FILE" || { err "解压失败"; exit 1; }
    rm -f "$FILE"

    extracted=$(find . -maxdepth 1 -type d -name "sing-box-*")
    extracted=$(echo "$extracted" | head -1)

    mv "$extracted/sing-box" "$work_dir/sing-box"
    chmod +x "$work_dir/sing-box"
    rm -rf "$extracted"

    green "Sing-box 已成功安装"

    # -------------------- 判断是否为自动模式 --------------------
    is_interactive_mode
    if [[ $? -eq 1 ]]; then
        not_interactive=1
        white "当前模式：自动模式（由环境变量触发）"
    else
        not_interactive=0
        white "当前模式：交互模式（用户手动输入）"
    fi

    # ==================================================================
    # 自动模式
    # ==================================================================
    if [[ $not_interactive -eq 1 ]]; then
        PORT=$(get_port "$PORT")
        UUID=$(get_uuid "$UUID")
        HY2_PASSWORD="$UUID"


    # ==================================================================
    # 手动模式：要求用户输入
    # ==================================================================
    else
        # ---------- 输入主端口 ----------
        while true; do
            read -rp "请输入 HY2 主端口：" USER_PORT
            if is_valid_port "$USER_PORT" && ! is_port_occupied "$USER_PORT"; then
                PORT="$USER_PORT"
                break
            else
                red "端口无效或已被占用，请重新输入"
            fi
        done

        # ---------- 输入 UUID ----------
        while true; do
            read -rp "请输入 UUID（留空自动生成）：" USER_UUID
            if [[ -z "$USER_UUID" ]]; then
                UUID="$DEFAULT_UUID"
                break
            elif is_valid_uuid "$USER_UUID"; then
                UUID="$USER_UUID"
                break
            else
                red "UUID 格式不正确，请重新输入"
            fi
        done

        HY2_PASSWORD="$UUID"
    fi

    white "最终 HY2 主端口：$PORT"
    white "最终 UUID：$UUID"

    RANGE_PORTS=$(get_range_ports "$RANGE_PORTS")

    if [[ -n "$RANGE_PORTS" ]]; then
        green "启用跳跃端口范围：$RANGE_PORTS"
    fi

    NODE_NAME=$(get_node_name)
    nginx_port=$((PORT + 1))
    hy2_port="$PORT"
    allow_port "$PORT" udp

    # ==================================================================
    # DNS 自动探测
    # ==================================================================
    ipv4_ok=false
    ipv6_ok=false

    ping -4 -c1 -W1 8.8.8.8   >/dev/null 2>&1 && ipv4_ok=true
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

    # ==================================================================
    # 生成 TLS 自签证书
    # ==================================================================
    openssl ecparam -genkey -name prime256v1 -out "${work_dir}/private.key"
    openssl req -x509 -new -nodes \
        -key "${work_dir}/private.key" \
        -sha256 -days 3650 \
        -subj "/C=US/ST=CA/O=bing.com/CN=bing.com" \
        -out "${work_dir}/cert.pem"

    # ==================================================================
    # 生成 config.json
    # ==================================================================
cat > "$config_dir" <<EOF
{
  "log": { "level": "error", "output": "$work_dir/sb.log" },

  "dns": {
    "servers": [ $(IFS=,; echo "${dns_servers[*]}") ],
    "strategy": "$dns_strategy"
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

      "masquerade": "https://bing.com",

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

    # ==================================================================
    # 注册 systemd 服务
    # ==================================================================
cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
Description=Sing-box Service
After=network.target

[Service]
ExecStart=$work_dir/sing-box run -c $config_dir
Restart=always
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable sing-box
    systemctl restart sing-box

    green "Sing-box 服务已成功启动！"
}

# ======================================================================
# 在线二维码输出（使用你指定的 URL 方式）
# ======================================================================
generate_qr() {
        local link="$1"
    if [ -z "$link" ]; then
        echo "QR Link 生成失败：链接为空"
        return 1
    fi

    echo "二维码链接："
    echo "https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${link}"
}

# ======================================================================
# 统一的节点输出函数（Hy2 + 订阅 + 全平台链接 + 二维码）
# ======================================================================
print_node_info_custom() {
    local server_ip="$1"
    local hy2_port="$2"
    local uuid="$3"
    local sub_port="$4"
    local range_ports="$5"

    # ---------- Hy2 协议 ----------
    if [[ -n "$range_ports" ]]; then
        minp="${range_ports%-*}"
        maxp="${range_ports#*-}"
        mport_param="${hy2_port},${minp}-${maxp}"
    else
        mport_param="${hy2_port}"
    fi

   hy2_url="hysteria2://${uuid}@${server_ip}:${hy2_port}/?insecure=1&alpn=h3&obfs=none&mport=${mport_param}#${NODE_NAME}"


    # 写入 Hy2 原始链接到 url.txt
    echo "$hy2_url" > "$client_dir"

    # ========== ★★★ 新增：输出 hy2 原始链接 ★★★ ==========
    purple "\nHY2 原始链接（可直接导入客户端）："
    green  "$hy2_url"
    generate_qr "$hy2_url"
    yellow "=========================================================================================="
    

    # ---------- 通用订阅 ----------
    if [[ -n "$range_ports" ]]; then
        base_url="http://${server_ip}:${range_ports}/${uuid}"
    else
        base_url="http://${server_ip}:${sub_port}/${uuid}"
    fi

    yellow '\n温馨提醒：需打开 V2rayN 或其他软件里的 "跳过证书验证"，或将节点的 Insecure 或 TLS 设置为 "true"\n'

    

    # ---------------- 通用订阅 ----------------
    green "V2rayN / Shadowrocket / Nekobox / Loon / Karing / Sterisand 订阅链接："
    green "$base_url"
    generate_qr "$base_url"
    yellow "=========================================================================================="

    # ---------------- Clash / Mihomo ----------------
    clash_url="https://sublink.eooce.com/clash?config=${base_url}"
    green "\nClash / Mihomo 订阅链接："
    green "$clash_url"
    generate_qr "$clash_url"
    yellow "=========================================================================================="

    # ---------------- Sing-box ----------------
    singbox_url="https://sublink.eooce.com/singbox?config=${base_url}"
    green "\nSing-box 订阅链接："
    green "$singbox_url"
    generate_qr "$singbox_url"
    yellow "=========================================================================================="

    # ---------------- Surge ----------------
    surge_url="https://sublink.eooce.com/surge?config=${base_url}"
    green "\nSurge 订阅链接："
    green "$surge_url"
    generate_qr "$surge_url"
    yellow "==========================================================================================\n"
}

# ======================================================================
# 本地订阅文件生成（sub.txt / base64 / json）
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
# 安装完成后的节点展示（使用统一格式）
# ======================================================================
generate_subscription_info() {

    ipv4=$(curl -4 -s https://api.ipify.org || true)
    ipv6=$(curl -6 -s https://api64.ipify.org || true)

    [[ -n "$ipv4" ]] && server_ip="$ipv4" || server_ip="[$ipv6]"

    hy2_port=$(jq -r '.inbounds[0].listen_port' "$config_dir")
    uuid=$(jq -r '.inbounds[0].users[0].password' "$config_dir")

    if [[ -f "$sub_port_file" ]]; then
        sub_port=$(cat "$sub_port_file")
    else
        sub_port=$((hy2_port + 1))
    fi

    if [[ -n "$RANGE_PORTS" ]]; then
        base_url="http://${server_ip}:${RANGE_PORTS}/${uuid}"
    else
        base_url="http://${server_ip}:${sub_port}/${uuid}"
    fi

    generate_all_subscription_files "$base_url"

    clear
    blue "============================================================"
    blue "                Sing-box Hy2 节点安装完成"
    blue "============================================================"

    print_node_info_custom "$server_ip" "$hy2_port" "$uuid" "$sub_port" "$RANGE_PORTS"
}

# ======================================================================
# Nginx 订阅服务（自动修复、端口检测、配置生成）
# ======================================================================
add_nginx_conf() {

    if ! command_exists nginx; then
        red "未安装 Nginx，跳过订阅服务配置"
        return
    fi

    mkdir -p /etc/nginx/conf.d

    # ------------------- 获取订阅端口 -------------------
    if [[ -f "$sub_port_file" ]]; then
        nginx_port=$(cat "$sub_port_file")
    else
        nginx_port=$((hy2_port + 1))

        # 若被占用则寻找下一个端口
        if is_port_occupied "$nginx_port"; then
            for p in $(seq $((nginx_port+1)) 65000); do
                if ! is_port_occupied "$p"; then
                    nginx_port="$p"
                    break
                fi
            done
        fi

        echo "$nginx_port" > "$sub_port_file"
    fi

    rm -f /etc/nginx/conf.d/singbox_sub.conf

cat > /etc/nginx/conf.d/singbox_sub.conf <<EOF
server {
    listen $nginx_port;
    listen [::]:$nginx_port;

    server_name sb_sub.local;

    add_header Cache-Control "no-cache, must-revalidate";
    add_header Pragma "no-cache";
    add_header Expires "0";

    location /$uuid {
        alias $sub_file;
        default_type text/plain;
    }

    location / {
        return 404;
    }
}
EOF

    # ------------------- 修复 nginx 主配置 -------------------
    if [[ -f /etc/nginx/nginx.conf ]]; then
        if ! grep -q "conf.d/\*\.conf" /etc/nginx/nginx.conf; then
            sed -i '/http {/a\    include /etc/nginx/conf.d/*.conf;' /etc/nginx/nginx.conf
        fi
    fi

    if ! nginx -t >/dev/null 2>&1; then
        red "Nginx 配置语法错误，请检查 /etc/nginx/conf.d/singbox_sub.conf"
        return
    fi

    systemctl restart nginx
    green "订阅服务已启动 → 端口：$nginx_port"
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
# 订阅服务管理菜单（增强版）
# ======================================================================
disable_open_sub() {
    clear
    blue "===================================================="
    green "               管理订阅服务（Nginx）"
    blue "===================================================="
    echo ""

    green " 1. 关闭订阅服务"
    green " 2. 启用订阅服务"
    green " 3. 修改订阅端口"
    green " 4. 修复订阅配置"
    purple " 0. 返回主菜单"
    echo ""

    read -rp "请选择 (0-4): " s

    case "$s" in

        1)
            systemctl stop nginx
            green "订阅服务已关闭"
            ;;

        2)
            systemctl start nginx
            if systemctl is-active nginx >/dev/null; then
                green "订阅服务已启动"
            else
                red "订阅服务启动失败，请检查配置"
            fi
            ;;

        3)
            read -rp "请输入新的订阅端口：" new_port
            if ! is_valid_port "$new_port"; then red "端口无效"; return; fi
            if is_port_occupied "$new_port"; then red "端口已占用"; return; fi

            sed -i "s/listen [0-9]\+;/listen $new_port;/" /etc/nginx/conf.d/singbox_sub.conf
            sed -i "s/listen \[::\]:[0-9]\+;/listen [::]:$new_port;/" /etc/nginx/conf.d/singbox_sub.conf

            echo "$new_port" > "$sub_port_file"

            if nginx -t >/dev/null 2>&1; then
                systemctl restart nginx
                green "订阅端口修改为：$new_port"
            else
                red "配置错误，恢复原配置..."
                add_nginx_conf
            fi
            ;;

        4)
            yellow "正在修复订阅配置..."
            add_nginx_conf
            systemctl restart nginx
            green "修复完成"
            ;;

        0)
            return
            ;;

        *)
            red "无效输入，请重试"
            ;;
    esac

    read -n 1 -s -r -p "按任意键返回菜单..."
}

# ======================================================================
# 查看节点信息（与安装完成展示保持完全一致）
# ======================================================================
check_nodes() {
    clear
    blue "============================================================"
    blue "                     查看节点信息"
    blue "============================================================"

    [[ ! -f "$config_dir" ]] && { red "未找到配置文件"; return; }

    hy2_port=$(jq -r '.inbounds[0].listen_port' "$config_dir")
    uuid=$(jq -r '.inbounds[0].users[0].password' "$config_dir")

    if [[ -f "$sub_port_file" ]]; then
        sub_port=$(cat "$sub_port_file")
    else
        sub_port=$((hy2_port + 1))
    fi

    ipv4=$(curl -4 -s https://api.ipify.org)
    ipv6=$(curl -6 -s https://api64.ipify.org)
    [[ -n "$ipv4" ]] && server_ip="$ipv4" || server_ip="[$ipv6]"

    if [[ -f "$client_dir" ]]; then
        hy2_url=$(cat "$client_dir")
    else
        hy2_url="（未找到原始链接，请重新安装或生成）"
    fi


    purple "\nHY2 原始链接（从 url.txt 读取）："
    green "$hy2_url"
    echo
    print_node_info_custom "$server_ip" "$hy2_port" "$uuid" "$sub_port" "$RANGE_PORTS"
}

# ======================================================================
# 修改节点配置（端口 / UUID / 名称 / 跳跃端口）
# ======================================================================
change_config() {
    clear
    blue  "===================================================="
    green "                 修改节点配置"
    blue  "===================================================="
    echo ""

    green " 1. 修改 HY2 主端口"
    green " 2. 修改 UUID（密码）"
    green " 3. 修改节点名称（只影响订阅名称）"
    green " 4. 添加跳跃端口"
    green " 5. 删除跳跃端口 NAT 规则"
    purple " 0. 返回主菜单"
    echo ""

    read -rp "请选择(0-5): " choice

    case "$choice" in
        1)
            read -rp "请输入新的主端口：" new_port
            if ! is_valid_port "$new_port"; then red "端口无效"; return; fi
            if is_port_occupied "$new_port"; then red "端口被占用"; return; fi
            sed -i "s/\"listen_port\": [0-9]*/\"listen_port\": $new_port/" "$config_dir"
            restart_singbox
            green "主端口已修改：$new_port"
            ;;

        2)
            read -rp "请输入新的 UUID：" new_uuid
            if ! is_valid_uuid "$new_uuid"; then red "UUID 无效"; return; fi
            sed -i "s/\"password\": \".*\"/\"password\": \"$new_uuid\"/" "$config_dir"
            restart_singbox
            green "UUID 修改成功"
            ;;

        3)
            read -rp "请输入新的节点名称：" new_name

            # ========== A. 更新订阅文件 ==========
            echo "#$new_name" > "$sub_file"
            base64 -w0 "$sub_file" > "${work_dir}/sub_base64.txt"

            # ========== B. 更新 hy2 原串（url.txt） ==========
            if [[ -f "$client_dir" ]]; then
                sed -i "s/#.*/#$new_name/" "$client_dir"
            fi

            # ========== C. 更新 config.json 中的 tag/name 字段（预留） ==========
            if grep -q '"tag":' "$config_dir"; then
                sed -i "s/\"tag\": \".*\"/\"tag\": \"$new_name\"/" "$config_dir"
            fi
            if grep -q '"name":' "$config_dir"; then
                sed -i "s/\"name\": \".*\"/\"name\": \"$new_name\"/" "$config_dir"
            fi

            restart_singbox
            green "节点名称已更新并同步到所有配置"
            ;;
        4)
            read -rp "跳跃起始端口：" jmin
            read -rp "跳跃结束端口：" jmax

            if ! is_valid_range "${jmin}-${jmax}"; then
                red "格式无效（示例：10000-20000）"
                return
            fi

            configure_port_jump "$jmin" "$jmax"
            green "跳跃端口已应用"
            ;;

        5)
            delete_jump_rule
            green "跳跃端口 NAT 已删除"
            ;;

        0)
            return
            ;;
        *)
            red "无效选项"
            ;;
    esac

    echo
    read -n 1 -s -r -p "按任意键返回菜单..."
}

# ======================================================================
# 卸载 Sing-box（含订阅服务）
# ======================================================================
uninstall_singbox() {
    read -rp "确认卸载 Sing-box？(y/n): " u
    [[ "$u" != "y" ]] && { yellow "取消卸载"; return; }

    stop_singbox
    systemctl disable sing-box >/dev/null 2>&1
    rm -f /etc/systemd/system/sing-box.service
    systemctl daemon-reload

    rm -rf /etc/sing-box
    green "Sing-box 已卸载"

    # 删除订阅配置
    if [[ -f /etc/nginx/conf.d/singbox_sub.conf ]]; then
        rm -f /etc/nginx/conf.d/singbox_sub.conf
        green "订阅服务配置已删除"
    fi

    # 是否卸载 Nginx
    if command_exists nginx; then
        read -rp "是否卸载 Nginx？(y/N): " delng
        if [[ "$delng" =~ ^[Yy]$ ]]; then
            if command_exists apt; then apt remove -y nginx nginx-core
            elif command_exists yum; then yum remove -y nginx
            elif command_exists dnf; then dnf remove -y nginx
            elif command_exists apk; then apk del nginx
            fi
            green "Nginx 已卸载"
        else
            yellow "已保留 Nginx"
            systemctl restart nginx >/dev/null 2>&1
        fi
    fi

    green "卸载流程完成"
}

# ======================================================================
# 自动安装流程（环境变量触发）
# ======================================================================
start_service_after_finish_sb() {

    sleep 1
    systemctl daemon-reload
    systemctl enable sing-box
    systemctl restart sing-box

    # 跳跃端口 NAT
    handle_range_ports

    # 输出节点完整信息
    generate_subscription_info

    # 启动 Nginx
    add_nginx_conf
}

quick_install() {
    purple "检测到环境变量，自动安装模式启动..."

    install_common_packages
    install_singbox
    start_service_after_finish_sb

    green "自动安装完成！"
    check_nodes
    green "节点信息已全部显示完毕！"
}

# ======================================================================
# 主菜单
# ======================================================================
menu() {
    clear
    blue "===================================================="
    gradient "       Sing-box  一键脚本（Hy2整合版）"
    green    "       作者：$AUTHOR"
    yellow   "       版本：$VERSION"
    blue "===================================================="
    echo ""

    if systemctl is-active sing-box >/dev/null 2>&1; then
        sb_status="$(green '运行中')"
    else
        sb_status="$(red '未运行')"
    fi

    if systemctl is-active nginx >/dev/null 2>&1; then
        ng_status="$(green '运行中')"
    else
        ng_status="$(red '未运行')"
    fi

    yellow " Sing-box 状态：$sb_status"
    yellow " Nginx 状态：   $ng_status"
    echo ""

    green  " 1. 安装 Sing-box (HY2)"
    red    " 2. 卸载 Sing-box"
    yellow "----------------------------------------"
    green  " 3. 管理 Sing-box 服务"
    green  " 4. 查看节点信息"
    yellow "----------------------------------------"
    green  " 5. 修改节点配置"
    green  " 6. 管理订阅服务"
    yellow "----------------------------------------"
    purple " 7. 老王工具箱"
    yellow "----------------------------------------"
    red    " 0. 退出脚本"
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
                unset PORT UUID RANGE_PORTS NODE_NAME
                install_common_packages
                install_singbox
                start_service_after_finish_sb
                ;;

            2) uninstall_singbox ;;
            3) manage_singbox ;;
            4) check_nodes ;;
            5) change_config ;;
            6) disable_open_sub ;;
            7) bash <(curl -Ls ssh_tool.eooce.com) ;;
            0) exit 0 ;;
            *) red "无效选项" ;;
        esac

        echo
        read -n 1 -s -r -p "按任意键返回主菜单..."
    done
}


# ======================================================================
# 节点名称
# ======================================================================
get_node_name() {

    # ========== 1. 根据脚本文件名自动确定默认节点名 ==========
    local DEFAULT_NODE_NAME
    if [[ "${0##*/}" == *"hy2"* || "${0##*/}" == *"hysteria2"* ]]; then
        DEFAULT_NODE_NAME="$AUTHOR-hy2"
    else
        DEFAULT_NODE_NAME="$AUTHOR"
    fi

    # ========== 2. 环境变量 NODE_NAME 优先（用户手动指定） ==========
    if [[ -n "$NODE_NAME" ]]; then
        echo "$NODE_NAME"
        return
    fi

    local node_name=""
    local country org

    # ========== 3. 自动检测国家与运营商（ipapi.co） ==========
    node_name=$(
        curl -fs --max-time 2 https://ipapi.co/json 2>/dev/null |
        sed -n 's/.*"country":"\([^\"]*\)".*"org":"\([^\"]*\)".*/\1-\2/p' |
        sed 's/[ ]\+/_/g'
    )

    # ========== 4. fallback：使用 ip.sb + ipinfo.io/org ==========
    if [[ -z "$node_name" ]]; then
        country=$(curl -fs --max-time 2 ip.sb/country 2>/dev/null | tr -d '\r\n')
        org=$(curl -fs --max-time 2 ipinfo.io/org 2>/dev/null |
              awk '{$1=""; print $0}' | sed -e 's/^[ ]*//' -e 's/[ ]\+/_/g')

        if [[ -n "$country" && -n "$org" ]]; then
            node_name="${country}-${org}"
        fi
    fi

    # ========== 5. fallback：都失败 → 使用默认名称 ==========
    [[ -z "$node_name" ]] && node_name="$DEFAULT_NODE_NAME"

    # ========== 6. 输出最终节点名称 ==========
    echo "$node_name"
}

# ======================================================================
# 主入口
# ======================================================================
main() {
    is_interactive_mode
    if [[ $? -eq 1 ]]; then
        quick_install
        read -n 1 -s -r -p "安装完成！按任意键进入主菜单..."
        main_loop
    else
        main_loop
    fi
}

main
