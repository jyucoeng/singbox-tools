#!/bin/bash

# ======================================================================
# Sing-box Hysteria2 一键安装管理脚本（最终整合修复版）
# 作者：LittleDoraemon（保留）
# 文件名：hy2_fixed.sh
# 修复项：自动模式、跳跃端口、nginx订阅、环境变量、stdout污染等
# ======================================================================

export LANG=en_US.UTF-8

# ======================================================================
# 自动加载环境变量（支持 PORT=xxx RANGE_PORTS=xxx 直接执行）
# ======================================================================
load_env_vars() {
    eval "$(env | grep -E '^(PORT|UUID|RANGE_PORTS|NODE_NAME)=' | sed 's/^/export /')"
}
load_env_vars

# ======================================================================
# 判断是否为非交互模式（只要任意参数存在即为自动模式）
# ======================================================================
is_interactive_mode() {
    if [[ -n "$PORT" || -n "$UUID" || -n "$RANGE_PORTS" || -n "$NODE_NAME" ]]; then
        return 1      # 非交互式（自动安装）
    else
        return 0      # 交互式（菜单模式）
    fi
}

# ======================================================================
# 基础变量与常量
# ======================================================================

SINGBOX_VERSION="1.12.13"
AUTHOR="LittleDoraemon"
VERSION="v1.0.2"

work_dir="/etc/sing-box"
config_dir="${work_dir}/config.json"
client_dir="${work_dir}/url.txt"

DEFAULT_UUID=$(cat /proc/sys/kernel/random/uuid)
DEFAULT_RANGE_PORTS=""

# UI 配色
re="\033[0m"; red="\033[1;91m"; green="\e[1;32m"; yellow="\e[1;33m"
purple="\e[1;35m"; skyblue="\e[1;36m"; blue="\e[1;34m"

_red() { echo -e "\e[1;91m$1\033[0m"; }
_green() { echo -e "\e[1;32m$1\033[0m"; }
_yellow() { echo -e "\e[1;33m$1\033[0m"; }
_purple() { echo -e "\e[1;35m$1\033[0m"; }
_skyblue() { echo -e "\e[1;36m$1\033[0m"; }
_blue() { echo -e "\e[1;34m$1\033[0m"; }

# 安全输入
reading() {
    local prompt="$1"
    local varname="$2"
    echo -ne "$prompt"
    read value
    printf -v "$varname" "%s" "$value"
}

# ======================================================================
# Root 用户检查
# ======================================================================
[[ $EUID -ne 0 ]] && { _red "请用 root 用户执行此脚本！"; exit 1; }

# ======================================================================
# 通用函数
# ======================================================================

command_exists() { command -v "$1" >/dev/null 2>&1; }

check_service() {
    local svc="$1"
    if command_exists systemctl; then
        systemctl is-active "$svc" >/dev/null 2>&1
        return $?
    elif command_exists rc-service; then
        rc-service "$svc" status >/dev/null 2>&1
        return $?
    fi
    return 1
}

check_nginx() { check_service nginx; }
check_singbox() { check_service sing-box; }

# ======================================================================
# 安装必要依赖
# ======================================================================
install_common_packages() {
    local pkgs="tar nginx jq openssl lsof coreutils"
    
    for pkg in $pkgs; do
        if ! command_exists "$pkg"; then
            _yellow "正在安装依赖包：$pkg ..."
            if command_exists apt; then
                apt update -y && apt install -y "$pkg"
            elif command_exists yum; then
                yum install -y "$pkg"
            elif command_exists apk; then
                apk add "$pkg"
            elif command_exists dnf; then
                dnf install -y "$pkg"
            fi
        fi
    done
}

# ======================================================================
# 获取真实IP（IPv4 / IPv6）
# ======================================================================
get_realip() {
    local ip
    ip=$(curl -4 -sm 2 ip.sb)
    if [[ -z "$ip" ]]; then
        ip="[$(curl -6 -sm 2 ip.sb)]"
    fi
    echo "$ip"
}

# ======================================================================
# 端口校验函数（无任何 echo，避免 stdout 污染）
# ======================================================================

is_valid_port() {
    local p="$1"
    [[ "$p" =~ ^[0-9]+$ ]] && [[ "$p" -ge 1 && "$p" -le 65535 ]]
}

# 端口占用检测
is_port_occupied() {
    local p="$1"
    lsof -i :"$p" &>/dev/null
}

# ======================================================================
# UUID 匹配函数（无输出污染）
# ======================================================================
is_valid_uuid() {
    local u="$1"
    [[ "$u" =~ ^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$ ]]
}

# ======================================================================
# RANGE_PORTS 格式验证
# ======================================================================

is_valid_range_ports_format() {
    local range
    range="$(echo "$1" | tr -d '\r' | xargs)"
    if [[ "$range" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        return 0
    fi
    return 1
}

# RANGE_PORTS 完整合法性验证
is_valid_range_ports() {
    local range="$1"

    is_valid_range_ports_format "$range" || return 1

    local min="${BASH_REMATCH[1]}"
    local max="${BASH_REMATCH[2]}"

    is_valid_port "$min" || return 1
    is_valid_port "$max" || return 1

    [[ "$min" -le "$max" ]] || return 1

    return 0
}

# ======================================================================
# 获取端口（自动模式 & 交互模式均可）
# ======================================================================

get_port() {
    local p="$1"
    local interactive="$2"

    # 如果用户传入端口
    if [[ -n "$p" ]]; then
        if ! is_valid_port "$p"; then
            _err "❌ 端口 $p 无效（必须为 1-65535）"
            exit 1
        fi
        if is_port_occupied "$p"; then
            _err "❌ 端口 $p 已被占用，请换一个端口"
            exit 1
        fi
        echo "$p"
        return
    fi

    # 自动生成端口
    while true; do
        local rp=$(shuf -i 20000-60000 -n 1)
        if ! is_port_occupied "$rp"; then
            echo "$rp"
            return
        else
            _err "⚠️ 自动生成的端口 $rp 已被占用，重试中..."
        fi
    done
}


# ======================================================================
# 获取 UUID
# ======================================================================

get_uuid() {
    local u="$1"
    local interactive="$2"

    if [[ -n "$u" ]]; then
        echo "$u"
        return
    fi

    echo "$DEFAULT_UUID"
}

# ======================================================================
# 处理 RANGE_PORTS 输入值
# ======================================================================

get_range_ports() {
    local r="$1"

    if [[ -z "$r" ]]; then
        echo ""
        return
    fi

    if ! is_valid_range_ports "$r"; then
        _err "❌ RANGE_PORTS='$r' 格式无效，应为 10000-20000 且范围合法"
        exit 1
    fi

    echo "$r"
}


# ======================================================================
# 防火墙开放端口
# ======================================================================

allow_port() {
    local rule="$1"
    local port="${rule%/*}"
    local proto="${rule#*/}"

    # systemd
    if command_exists firewall-cmd && systemctl is-active firewalld >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port=${port}/${proto}
        firewall-cmd --reload
    fi

    # iptables
    if command_exists iptables; then
        iptables -I INPUT -p ${proto} --dport ${port} -j ACCEPT 2>/dev/null
    fi

    # ip6tables
    if command_exists ip6tables; then
        ip6tables -I INPUT -p ${proto} --dport ${port} -j ACCEPT 2>/dev/null
    fi
}

# ======================================================================
# configure_port_jump（端口跳跃实现）
# ======================================================================

configure_port_jump() {
    local min="$1"
    local max="$2"

    allow_port "${min}-${max}/udp"

    # 从 config.json 获取 HY2 主端口
    local listen_port
    listen_port=$(jq -r '.inbounds[0].listen_port' "$config_dir" 2>/dev/null)

    [[ -z "$listen_port" ]] && { _red "无法解析 HY2 主端口"; return 1; }

    # 兼容 nftables / legacy iptables
    if iptables -V 2>&1 | grep -q nf_tables; then
        iptables -t nat -A PREROUTING -p udp --dport "$min":"$max" -j DNAT --to-destination :"$listen_port"
        ip6tables -t nat -A PREROUTING -p udp --dport "$min":"$max" -j DNAT --to-destination :"$listen_port"
    else
        iptables -t nat -A PREROUTING -p udp --dport "$min":"$max" -j DNAT --to :"$listen_port"
        ip6tables -t nat -A PREROUTING -p udp --dport "$min":"$max" -j DNAT --to :"$listen_port"
    fi

    restart_singbox
    _green "跳跃端口已生效：${min}-${max}"
}
# ======================================================================
# 安装 Sing-box（下载、解压、安装、生成 config.json）
# ======================================================================

install_singbox() {
    clear
    _purple "正在安装 Sing-box，请稍候..."

    # -------------------------------
    # 检测 CPU 架构
    # -------------------------------
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)   ARCH="amd64" ;;
        aarch64)  ARCH="arm64" ;;
        armv7l)   ARCH="armv7" ;;
        i386|i686)ARCH="i386"  ;;
        riscv64)  ARCH="riscv64" ;;
        mips64el) ARCH="mips64le" ;;
        *) _red "不支持的架构: $ARCH"; exit 1 ;;
    esac

    FILE="sing-box-${SINGBOX_VERSION}-linux-${ARCH}.tar.gz"
    URL="https://github.com/SagerNet/sing-box/releases/download/v${SINGBOX_VERSION}/${FILE}"

    mkdir -p "$work_dir"

    _yellow "下载 Sing-box: $URL"
    curl -L -o "$FILE" "$URL" || { _red "下载失败"; exit 1; }

    _yellow "解压..."
    tar -xzf "$FILE" || { _red "解压失败"; exit 1; }
    rm -f "$FILE"

    extracted=$(find . -maxdepth 1 -type d -name "sing-box-*")
    extracted=$(echo "$extracted" | head -n 1)

    [[ -z "$extracted" ]] && { _red "解压目录未找到"; exit 1; }

    cd "$extracted"
    mv sing-box "${work_dir}/sing-box"
    chmod +x "${work_dir}/sing-box"
    cd .. && rm -rf "$extracted"

    _green "Sing-box 安装完成"

    # -------------------------------------------------------
    # 解析运行模式（环境变量 ≠ 空 → 非交互式自动模式）
    # -------------------------------------------------------
    is_interactive_mode
    if [[ $? -eq 1 ]]; then
        not_interactive=1
        _green "当前运行模式：非交互式（自动安装）"
    else
        not_interactive=0
        _green "当前运行模式：交互式"
    fi

    # -------------------------------------------------------
    # 获取 PORT / UUID / RANGE_PORTS（均已自动无污染）
    # -------------------------------------------------------

    PORT=$(get_port "$PORT" "$not_interactive")
    _green "HY2 主端口：$PORT"

    UUID=$(get_uuid "$UUID" "$not_interactive")
    _green "UUID：$UUID"

    RANGE_PORTS=$(get_range_ports "$RANGE_PORTS")
    [[ -n "$RANGE_PORTS" ]] && _green "跳跃端口范围：$RANGE_PORTS"

    # password = UUID（你的需求）
    HY2_PASSWORD="$UUID"

    # 订阅端口 = PORT + 1
    nginx_port=$((PORT + 1))
    export nginx_port
    _green "订阅端口（自动设定）：$nginx_port"

    # 定义 hy2_port 值（修复：不能留空）
    hy2_port=$PORT
    export hy2_port

    # -------------------------------------------------------
    # 生成 TLS 自签证书（无交互）
    # -------------------------------------------------------
    openssl ecparam -genkey -name prime256v1 -out "${work_dir}/private.key"
    openssl req -x509 -new -nodes \
        -key "${work_dir}/private.key" \
        -sha256 -days 3650 \
        -subj "/C=US/ST=CA/O=bing.com/CN=bing.com" \
        -out "${work_dir}/cert.pem"

    allow_port "${PORT}/udp"

    # 检测 DNS 优先策略
    dns_strategy=$(ping -c1 -W1 8.8.8.8 >/dev/null 2>&1 && echo "prefer_ipv4" || echo "prefer_ipv6")

    # -------------------------------------------------------
    # 生成 config.json
    # -------------------------------------------------------
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
      { "tag": "local", "address": "local", "strategy": "$dns_strategy" }
    ]
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
      "tag": "hysteria2",
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
}
# ======================================================================
# 创建 systemd 服务
# ======================================================================

main_systemd_services() {
    cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
User=root
WorkingDirectory=/etc/sing-box
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
ExecStart=/etc/sing-box/sing-box run -c /etc/sing-box/config.json
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=5
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable sing-box
    systemctl restart sing-box
}


# ======================================================================
# Alpine OpenRC 服务
# ======================================================================

alpine_openrc_services() {
    cat > /etc/init.d/sing-box <<EOF
#!/sbin/openrc-run

description="sing-box service"
command="/etc/sing-box/sing-box"
command_args="run -c /etc/sing-box/config.json"
command_background=true
pidfile="/var/run/sing-box.pid"
EOF

    chmod +x /etc/init.d/sing-box
    rc-update add sing-box default
    rc-service sing-box restart
}

restart_singbox() {
    if command_exists systemctl; then
        systemctl restart sing-box
    elif command_exists rc-service; then
        rc-service sing-box restart
    fi
}

start_singbox() { restart_singbox; }
stop_singbox() {
    systemctl stop sing-box 2>/dev/null
}


# ======================================================================
# PORT 跳跃处理入口函数（自动调用 configure_port_jump）
# ======================================================================

handle_range_ports() {
    if [[ -z "$RANGE_PORTS" ]]; then return; fi

    if ! is_valid_range_ports_format "$RANGE_PORTS"; then
        _err "❌ RANGE_PORTS 格式无效，应为 10000-20000"
        return
    fi

    local min="${BASH_REMATCH[1]}"
    local max="${BASH_REMATCH[2]}"

    if [[ "$min" -ge "$max" ]]; then
        _err "❌ 跳跃端口无效：结束端口必须大于起始端口"
        return
    fi

    _purple "配置跳跃端口：$min-$max"
    configure_port_jump "$min" "$max"
}



# ======================================================================
# 生成节点信息与订阅链接
# ======================================================================

generate_subscription_info() {

    # ------------------------
    # 获取 IPv4 / IPv6
    # ------------------------
    ipv4=$(curl -4 -s https://api.ipify.org || curl -4 -s ifconfig.me)
    ipv6=$(curl -6 -s https://api64.ipify.org || curl -6 -s ifconfig.me)

    # ------------------------
    # 判断是否开启 RANGE_PORTS
    # ------------------------
    if [[ -n "$RANGE_PORTS" ]]; then
        port_display="端口跳跃范围：$RANGE_PORTS"
        base_url="http://${ipv4}:${RANGE_PORTS}/${password}"
    else
        port_display="单端口模式：${nginx_port}"
        base_url="http://${ipv4}:${nginx_port}/${password}"
    fi

    clear
    _blue "============================================================"
    _blue "                    Hy2 节点订阅信息"
    _blue "============================================================"
    _yellow "服务器 IPv4：$ipv4"
    _yellow "服务器 IPv6：${ipv6:-无 IPv6}"
    _yellow "$port_display"
    _yellow "节点密码：$password"
    _blue "============================================================"

    echo
    _red "⚠ 温馨提示：部分客户端需要关闭 TLS 校验 / 允许 Insecure"
    _red "  请在 V2RayN / Shadowrocket / Nekobox / Karing 等中启用「跳过证书验证」"

    # ------------------------
    # ① 通用订阅
    # ------------------------
    echo
    # ① 通用订阅（V2RayN / SR / V2RayNG / NekoBox / Loon / Karing）
    _green "① 通用订阅（V2RayN / SR / V2RayNG / NekoBox / Loon / Karing）"
    _green "$base_url"
    display_qr_link "$base_url"
    _yellow "------------------------------------------------------------"


    # ② Clash / Mihomo / Clash Verge
    clash_sub="https://sublink.eooce.com/clash?config=${base_url}"
    _green "② Clash / Mihomo / Clash Verge 订阅："
    _green "$clash_sub"
    display_qr_link "$clash_sub"
    _yellow "------------------------------------------------------------"


    # ③ Sing-box
    singbox_sub="https://sublink.eooce.com/singbox?config=${base_url}"
    _green "③ Sing-box 订阅："
    _green "$singbox_sub"
    display_qr_link "$singbox_sub"
    _yellow "------------------------------------------------------------"


    # ④ Surge
    surge_sub="https://sublink.eooce.com/surge?config=${base_url}"
    _green "④ Surge 订阅："
    _green "$surge_sub"
    display_qr_link "$surge_sub"
    _yellow "------------------------------------------------------------"


    # ⑤ Quantumult X
    qx_sub="https://sublink.eooce.com/qx?config=${base_url}"
    _green "⑤ Quantumult X 订阅："
    _green "$qx_sub"
    display_qr_link "$qx_sub"
    _yellow "------------------------------------------------------------"


    _blue "============================================================"
    _blue "          订阅生成完成，如遇 APP 不兼容请自行想招"
    _blue "============================================================"
}


# ======================================================================
# 配置 Nginx 订阅服务（listen_port = PORT+1）
# ======================================================================

add_nginx_conf() {

    if ! command_exists nginx; then
        _red "NGINX 未安装，无法启用订阅服务"
        return
    fi

    systemctl stop nginx 2>/dev/null
    mkdir -p /etc/nginx/conf.d

cat > /etc/nginx/conf.d/sing-box.conf <<EOF
server {
    listen $nginx_port;
    listen [::]:$nginx_port;
    server_name _;

    add_header Cache-Control "no-cache, no-store, must-revalidate";
    add_header Pragma "no-cache";
    add_header Expires "0";

    location = /$password {
        alias /etc/sing-box/sub.txt;
        default_type text/plain;
    }

    location / {
        return 404;
    }
}
EOF

    # 修复 nginx.conf include
    if [[ -f /etc/nginx/nginx.conf ]]; then
        if ! grep -q "conf.d/\*\.conf" /etc/nginx/nginx.conf; then
            sed -i '/http {/a \    include /etc/nginx/conf.d/*.conf;' /etc/nginx/nginx.conf
        fi
    fi

    nginx -t >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        systemctl restart nginx 2>/dev/null
        _green "订阅服务已启动：端口 $nginx_port"
    else
        _yellow "nginx 配置失败，但不影响节点使用"
    fi
}


# ======================================================================
# 非交互模式：自动安装模式（你要求的 quick_install）
# ======================================================================

quick_install() {
    _purple "进入全自动安装模式（非交互式）..."

    install_common_packages
    install_singbox
    start_service_after_finish_sb

    _green "非交互式安装已完成！"
}


# ======================================================================
# 自动安装完成后的主流程入口
# ======================================================================

start_service_after_finish_sb() {

    # 1. 启动服务
    if command_exists systemctl; then
        main_systemd_services
    elif command_exists rc-service; then
        alpine_openrc_services
    fi

    sleep 2

    # 2. 跳跃端口处理
    handle_range_ports

    # 3. 生成订阅与节点信息
    generate_subscription_info

    # 4. 配置 nginx
    add_nginx_conf
}
# ======================================================================
# Sing-box 服务管理
# ======================================================================

manage_singbox() {
    clear
    _green "=== Sing-box 服务管理 ==="
    echo ""
    echo -e "${green}1.${re} 启动 Sing-box"
    echo -e "${green}2.${re} 停止 Sing-box"
    echo -e "${green}3.${re} 重启 Sing-box"
    echo -e "${purple}0.${re} 返回"

    reading "请输入选择：" m

    case "$m" in
        1) start_singbox ;;
        2) stop_singbox ;;
        3) restart_singbox ;;
        0) return ;;
        *) _red "无效选择" ;;
    esac
}


# ======================================================================
# 订阅服务管理（开关订阅 / 修改订阅端口）
# ======================================================================

disable_open_sub() {
    clear
    _green "=== 管理订阅服务 ==="
    echo ""
    echo -e "${green}1.${re} 关闭订阅"
    echo -e "${green}2.${re} 启用订阅"
    echo -e "${green}3.${re} 修改订阅端口"
    echo -e "${purple}0.${re} 返回"

    reading "请输入选择: " s

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
            reading "请输入新的订阅端口：" new_sub_port
            is_valid_port "$new_sub_port" || { _red "端口无效"; return; }

            sed -i "s/listen [0-9]*/listen $new_sub_port/" /etc/nginx/conf.d/sing-box.conf

            systemctl restart nginx
            _green "订阅端口修改成功 → $new_sub_port"
            ;;
        0)
            return
            ;;
        *)
            _red "无效选择"
            ;;
    esac
}


# ======================================================================
# 查看节点信息（显示 URL 和订阅链接）
# ======================================================================

check_nodes() {
    clear
    purple "================== 节点信息 =================="
    if [[ -f "$client_dir" ]]; then
        while IFS= read -r line; do purple "$line"; done < "$client_dir"
    else
        _red "未找到节点信息文件 $client_dir"
    fi
    purple "=============================================="
}


# ======================================================================
# 修改节点配置（端口 / UUID / 名称 / 跳跃端口）
# ======================================================================

change_config() {
    clear
    _green "=== 修改节点配置 ==="
    echo -e "${green}1.${re} 修改端口"
    echo -e "${green}2.${re} 修改 UUID"
    echo -e "${green}3.${re} 修改节点名称"
    echo -e "${green}4.${re} 添加跳跃端口"
    echo -e "${green}5.${re} 删除跳跃端口"
    echo -e "${purple}0.${re} 返回"

    reading "输入选项: " choice

    case "$choice" in
        1)
            reading "请输入新的端口：" new_port
            is_valid_port "$new_port" || { _red "端口无效"; return; }
            sed -i "s/\"listen_port\": [0-9]*/\"listen_port\": $new_port/" "$config_dir"
            restart_singbox
            _green "端口修改成功：$new_port"
            ;;
        2)
            reading "请输入新的 UUID：" new_uuid
            is_valid_uuid "$new_uuid" || { _red "UUID 格式无效"; return; }
            sed -i "s/\"password\": \".*\"/\"password\": \"$new_uuid\"/" "$config_dir"
            restart_singbox
            _green "UUID 修改成功"
            ;;
        3)
            reading "请输入新的节点名称：" newname
            sed -i "s/#.*/#$newname/" "$client_dir"
            base64 -w0 "$client_dir" > "$work_dir/sub.txt"
            _green "节点名称修改成功"
            ;;
        4)
            reading "请输入跳跃起始端口：" jmin
            reading "请输入跳跃结束端口：" jmax
            configure_port_jump "$jmin" "$jmax"
            ;;
        5)
            iptables -t nat -F PREROUTING >/dev/null 2>&1
            sed -i 's/&mport=[^#]*//' "$client_dir"
            base64 -w0 "$client_dir" > "$work_dir/sub.txt"
            _green "跳跃端口已删除"
            ;;
        0)
            return
            ;;
        *)
            _red "无效选择"
            ;;
    esac
}


# ======================================================================
# 卸载 Sing-box
# ======================================================================

uninstall_singbox() {
    reading "确认卸载 Sing-box？(y/n): " u
    [[ "$u" != "y" ]] && { _yellow "取消卸载"; return; }

    systemctl stop sing-box 2>/dev/null
    systemctl disable sing-box 2>/dev/null

    rm -rf /etc/sing-box
    rm -f /etc/systemd/system/sing-box.service
    rm -f /etc/nginx/conf.d/sing-box.conf

    _green "Sing-box 已卸载"
}


# ======================================================================
# 主菜单
# ======================================================================

menu() {
    clear
    blue "===================================================="
    blue "        Sing-box 一键安装管理脚本（HY2版）"
    blue "                   作者：$AUTHOR"
    yellow "                   版本：$VERSION"
    blue "===================================================="
    echo ""

    skyblue "Nginx 状态：$(check_nginx)"
    skyblue "Sing-box 状态：$(check_singbox)"
    echo ""

    green "1. 安装 Sing-box (HY2)"
    red   "2. 卸载 Sing-box"
    echo "----------------------------------------"
    green "3. 管理 Sing-box 服务"
    green "4. 查看节点信息"
    echo "----------------------------------------"
    green "5. 修改节点配置"
    green "6. 管理订阅服务"
    echo "----------------------------------------"
    purple "7. 老王 SSH 工具箱"
    echo "----------------------------------------"
    red "0. 退出脚本"
    echo "----------------------------------------"

    reading "请输入选项(0-7): " choice
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
            *) _red "无效选项" ;;
        esac

        read -n 1 -s -r -p $'\033[1;92m按任意键返回菜单...\033[0m'
    done
}


display_qr_link() {
    local TEXT="$1"
    local encoded

    encoded=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$TEXT")
    local QR_URL="https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=$encoded"

    echo
    _yellow "📱 二维码图片链接（点击此链接打开后扫码）："
    echo "$QR_URL"
    echo
}


# ======================================================================
# 主入口 main()
# ======================================================================

main() {
    is_interactive_mode
    if [[ $? -eq 1 ]]; then
        # 非交互模式自动安装
        quick_install

        echo ""
        read -n 1 -s -r -p $'\033[1;92m非交互模式完成！按任意键进入主菜单...\033[0m'
        main_loop
        return
    fi

    # 交互模式
    main_loop
}

# 执行脚本入口
main
