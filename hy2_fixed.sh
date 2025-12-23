#!/bin/bash
export LANG=en_US.UTF-8

# ============================================================
# Sing-box Hysteria2 一键脚本
#
# ✔ 功能 100% 等价原始 hy2.sh
# ✔ 状态模型 / 架构 / 菜单行为 对齐 tuic5
# ✔ 单文件 · 最终发布版
# ============================================================

AUTHOR="littleDoraemon"
VERSION="1.0.2"


SINGBOX_VERSION="1.12.13"

# ======================= 路径定义 =======================
work_dir="/etc/sing-box"
config_dir="$work_dir/config.json"
client_dir="$work_dir/url.txt"

sub_file="$work_dir/sub.txt"
sub_port_file="$work_dir/sub.port"
range_port_file="$work_dir/range_ports"

node_name_file="$work_dir/node_name"


# NAT comment
NAT_COMMENT="hy2_jump"

# ======================= UI 输出 =======================
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


# ======================= pause（tuic5 同款） =======================
pause_return() {
    echo ""
    read -n 1 -s -r -p "按任意键返回菜单..."
    echo ""
}

# ======================= Root 检查 =======================
if [[ $EUID -ne 0 ]]; then
    err "请使用 root 权限运行脚本"
    exit 1
fi

# ======================= 基础工具 =======================
command_exists(){ command -v "$1" >/dev/null 2>&1; }

is_valid_port(){
    [[ "$1" =~ ^[0-9]+$ && "$1" -ge 1 && "$1" -le 65535 ]]
}

is_port_occupied(){
    ss -tuln | grep -q ":$1 " && return 0
    lsof -i :"$1" &>/dev/null && return 0
    netstat -tuln 2>/dev/null | grep -q ":$1 " && return 0
    return 1
}

is_valid_uuid(){
    [[ "$1" =~ ^[a-fA-F0-9]{8}-([a-fA-F0-9]{4}-){3}[a-fA-F0-9]{12}$ ]]
}

urlencode(){
    printf "%s" "$1" | jq -sRr @uri
}

urldecode(){
    printf '%b' "${1//%/\\x}"
}

# ======================= QR（在线） =======================
generate_qr() {
    local link="$1"
    [[ -z "$link" ]] && return
    yellow "二维码链接："
    echo "https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${link}"
}

# ======================= 公网 IP 获取 =======================
get_public_ip() {
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

    local sources6=(
        "curl -6 -fs https://api64.ipify.org"
        "curl -6 -fs https://ipv6.icanhazip.com"
    )

    for src in "${sources6[@]}"; do
        ip=$(eval "$src" 2>/dev/null)
        [[ -n "$ip" ]] && { echo "$ip"; return; }
    done
}


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



# ======================= ENV 自动模式加载 =======================
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

# ======================= 模式判定 =======================
is_interactive_mode() {
    if [[ -n "$PORT" || -n "$UUID" || -n "$RANGE_PORTS" || -n "$NODE_NAME" ]]; then
        return 1   # 自动模式
    else
        return 0   # 交互模式
    fi
}

DEFAULT_UUID=$(cat /proc/sys/kernel/random/uuid)

# ======================= 跳跃端口状态（唯一事实源） =======================
get_range_ports() {
    [[ -f "$range_port_file" ]] && cat "$range_port_file"
}

# ============================================================
# 安装常用依赖（等价原 hy2）
# ============================================================
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
                err "无法识别包管理器，请手动安装 $p"
            fi
        fi
    done
}

# ============================================================
# 防火墙放行 HY2 主端口（UDP）
# ============================================================
allow_port() {
    local port="$1"

    iptables -C INPUT -p udp --dport "$port" -j ACCEPT &>/dev/null ||
        iptables -I INPUT -p udp --dport "$port" -j ACCEPT

    ip6tables -C INPUT -p udp --dport "$port" -j ACCEPT &>/dev/null ||
        ip6tables -I INPUT -p udp --dport "$port" -j ACCEPT

    green "已放行 UDP 端口：$port"
}

# ============================================================
# 跳跃端口 NAT 管理（核心修复）
# ============================================================

# 添加跳跃端口 NAT
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

    green "已添加跳跃端口 NAT：${min}-${max} → ${listen_port}"
}

# 删除所有跳跃端口 NAT
remove_jump_rule() {
    while iptables -t nat -C PREROUTING -m comment --comment "$NAT_COMMENT" &>/dev/null; do
        iptables -t nat -D PREROUTING -m comment --comment "$NAT_COMMENT"
    done

    while ip6tables -t nat -C PREROUTING -m comment --comment "$NAT_COMMENT" &>/dev/null; do
        ip6tables -t nat -D PREROUTING -m comment --comment "$NAT_COMMENT"
    done
}

# 删除 INPUT 放行（防残留）
remove_jump_input() {
    local min="$1"
    local max="$2"

    iptables -D INPUT -p udp --dport ${min}:${max} -j ACCEPT 2>/dev/null
    ip6tables -D INPUT -p udp --dport ${min}:${max} -j ACCEPT 2>/dev/null
}

# ============================================================
# 主端口变化时刷新跳跃端口（对齐 tuic5）
# ============================================================
refresh_jump_ports_for_new_main_port() {
    [[ ! -f "$range_port_file" ]] && return

    local rp
    rp=$(cat "$range_port_file")
    local min="${rp%-*}"
    local max="${rp#*-}"
    local new_port="$1"

    yellow "刷新跳跃端口 NAT：${min}-${max} → ${new_port}"

    # 清旧 NAT
    remove_jump_rule

    # 重新放行 INPUT
    remove_jump_input "$min" "$max"
    iptables -I INPUT -p udp --dport ${min}:${max} -j ACCEPT
    ip6tables -I INPUT -p udp --dport ${min}:${max} -j ACCEPT

    # 新 NAT
    add_jump_rule "$min" "$max" "$new_port"
}

# ============================================================
# 跳跃端口格式校验
# ============================================================
is_valid_range() {
    [[ "$1" =~ ^([0-9]+)-([0-9]+)$ ]] || return 1
    local min="${BASH_REMATCH[1]}"
    local max="${BASH_REMATCH[2]}"
    is_valid_port "$min" && is_valid_port "$max" && [[ $min -lt $max ]]
}

# ============================================================
# 安装 Sing-box（HY2）
# ============================================================
install_singbox() {

    clear
    purple "开始安装 Sing-box（Hysteria2）..."

    install_common_packages
    mkdir -p "$work_dir"

    # -------------------- 架构检测 --------------------
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l) ARCH="armv7" ;;
        i386|i686) ARCH="i386" ;;
        riscv64) ARCH="riscv64" ;;
        mips64el) ARCH="mips64le" ;;
        *)
            err "不支持的架构：$ARCH"
            pause_return
            return
            ;;
    esac

    FILE="sing-box-${SINGBOX_VERSION}-linux-${ARCH}.tar.gz"
    URL="https://github.com/SagerNet/sing-box/releases/download/v${SINGBOX_VERSION}/${FILE}"

    yellow "下载 Sing-box：$URL"
    curl -fSL --retry 3 --retry-delay 2 -o "$FILE" "$URL" || {
        err "下载失败"
        pause_return
        return
    }

    tar -xzf "$FILE" || {
        err "解压失败"
        pause_return
        return
    }
    rm -f "$FILE"

    extracted=$(find . -maxdepth 1 -type d -name "sing-box-*")
    extracted=$(echo "$extracted" | head -1)

    mv "$extracted/sing-box" "$work_dir/sing-box"
    chmod +x "$work_dir/sing-box"
    rm -rf "$extracted"

    # ====================================================
    # 模式判定
    # ====================================================
    is_interactive_mode
    if [[ $? -eq 1 ]]; then
        white "当前模式：自动模式"

        # -------- 主端口 --------
        if is_valid_port "$PORT" && ! is_port_occupied "$PORT"; then
            :
        else
            yellow "PORT 无效或被占用，切换为交互输入"
            while true; do
                read -rp "$(red_input "请输入 HY2 主端口（UDP）：")" PORT
                is_valid_port "$PORT" && ! is_port_occupied "$PORT" && break
                red "端口无效或被占用"
            done
        fi

        # -------- UUID --------
        if [[ -n "$UUID" ]]; then
            if ! is_valid_uuid "$UUID"; then
                yellow "UUID 无效，重新输入"
                while true; do
                    read -rp "$(red_input "请输入 UUID（回车自动生成）：")" UUID
                    [[ -z "$UUID" ]] && UUID=$(cat /proc/sys/kernel/random/uuid) && break
                    is_valid_uuid "$UUID" && break
                    red "UUID 格式错误"
                done
            fi
        else
            UUID=$(cat /proc/sys/kernel/random/uuid)
        fi

    else
        white "当前模式：交互模式"

        # -------- 主端口 --------
        while true; do
            read -rp "$(red_input "请输入 HY2 主端口（UDP）：")" PORT
            is_valid_port "$PORT" && ! is_port_occupied "$PORT" && break
            red "端口无效或被占用"
        done

        # -------- UUID --------
        while true; do
            read -rp "$(red_input "请输入 UUID（回车自动生成）：")" UUID
            [[ -z "$UUID" ]] && UUID=$(cat /proc/sys/kernel/random/uuid) && break
            is_valid_uuid "$UUID" && break
            red "UUID 格式错误"
        done
    fi

    # ====================================================
    # 放行主端口
    # ====================================================
    allow_port "$PORT"

    # ====================================================
    # TLS 证书（自签）
    # ====================================================
    openssl ecparam -genkey -name prime256v1 -out "$work_dir/private.key"
    openssl req -x509 -new -nodes \
        -key "$work_dir/private.key" \
        -sha256 -days 3650 \
        -subj "/C=US/ST=CA/O=bing.com/CN=bing.com" \
        -out "$work_dir/cert.pem"

    # ====================================================
    # 生成 config.json
    # ====================================================
cat > "$config_dir" <<EOF
{
  "log": {
    "level": "error",
    "output": "$work_dir/sb.log"
  },
  "inbounds": [
    {
      "type": "hysteria2",
      "listen": "::",
      "listen_port": $PORT,
      "users": [
        { "password": "$UUID" }
      ],
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

    # ====================================================
    # systemd 服务
    # ====================================================
cat > /etc/systemd/system/sing-box.service <<EOF
[Unit]
Description=Sing-box Hysteria2
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

    green "Sing-box HY2 服务已启动"

    init_node_name_on_install
}
# ============================================================
# 查看节点信息 / 多客户端订阅 / 二维码
# ============================================================

check_nodes() {
    local mode="$1"   # silent / empty

    [[ ! -f "$config_dir" ]] && {
        red "未找到配置文件，请先安装 HY2"
        [[ "$mode" != "silent" ]] && pause_return
        return
    }

    # =====================================================
    # 基础信息
    # =====================================================
    local PORT UUID
    PORT=$(jq -r '.inbounds[0].listen_port' "$config_dir")
    UUID=$(jq -r '.inbounds[0].users[0].password' "$config_dir")

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
    # 节点基础名称（不带 v4/v6）
    # =====================================================
    local BASE_NAME
    BASE_NAME=$(get_node_name)

    # =====================================================
    # 订阅端口
    # =====================================================
    local sub_port
    if [[ -f "$sub_port_file" ]]; then
        sub_port=$(cat "$sub_port_file")
    else
        sub_port=$((PORT + 1))
        echo "$sub_port" > "$sub_port_file"
    fi

    # =====================================================
    # 初始化订阅内容
    # =====================================================
    > "$sub_file"

    yellow "========================================================"

    # =====================================================
    # HY2 IPv4 节点
    # =====================================================
    local hy2_v4=""
    if [[ -n "$ip4" ]]; then
        local name4 enc4
        name4="${BASE_NAME}"
        enc4=$(urlencode "$name4")

        hy2_v4="hysteria2://${UUID}@${ip4}:${PORT}/?insecure=1&alpn=h3#${enc4}"

        purple "HY2 IPv4 节点（${name4}）"
        green "$hy2_v4"
        [[ "$mode" != "silent" ]] && generate_qr "$hy2_v4"
        echo ""

        echo "$hy2_v4" >> "$sub_file"
        echo "$hy2_v4" > "$client_dir"
    fi

    # =====================================================
    # HY2 IPv6 节点（必须使用 []）
    # =====================================================
    local hy2_v6=""
    if [[ -n "$ip6" ]]; then
        local name6 enc6
        name6="${BASE_NAME}"
        enc6=$(urlencode "$name6")

        hy2_v6="hysteria2://${UUID}@[${ip6}]:${PORT}/?insecure=1&alpn=h3#${enc6}"

        purple "HY2 IPv6 节点（${name6}）"
        green "$hy2_v6"
        [[ "$mode" != "silent" ]] && generate_qr "$hy2_v6"
        echo ""

        echo "$hy2_v6" >> "$sub_file"
        [[ -z "$hy2_v4" ]] && echo "$hy2_v6" > "$client_dir"
    fi

    yellow "========================================================"

    # =====================================================
    # 本地订阅（base64）
    # =====================================================
    base64 -w0 "$sub_file" > "${work_dir}/sub_base64.txt"

    # =====================================================
    # 基础订阅 URL（IPv4 / IPv6 分离）
    # =====================================================
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

    # =====================================================
    # 客户端订阅（IPv4）
    # =====================================================
    if [[ -n "$sub_url_v4" ]]; then
        local clash_v4 singbox_v4 surge_v4
        clash_v4="https://sublink.eooce.com/clash?config=${sub_url_v4}"
        singbox_v4="https://sublink.eooce.com/singbox?config=${sub_url_v4}"
        surge_v4="https://sublink.eooce.com/surge?config=${sub_url_v4}"

        purple "Clash / Mihomo（IPv4）："
        green "$clash_v4"
        [[ "$mode" != "silent" ]] && generate_qr "$clash_v4"
        echo ""

        purple "Sing-box（IPv4）："
        green "$singbox_v4"
        [[ "$mode" != "silent" ]] && generate_qr "$singbox_v4"
        echo ""

        purple "Surge（IPv4）："
        green "$surge_v4"
        [[ "$mode" != "silent" ]] && generate_qr "$surge_v4"
        echo ""
    fi

    # =====================================================
    # 客户端订阅（IPv6）
    # =====================================================
    if [[ -n "$sub_url_v6" ]]; then
        local clash_v6 singbox_v6 surge_v6
        clash_v6="https://sublink.eooce.com/clash?config=${sub_url_v6}"
        singbox_v6="https://sublink.eooce.com/singbox?config=${sub_url_v6}"
        surge_v6="https://sublink.eooce.com/surge?config=${sub_url_v6}"

        purple "Clash / Mihomo（IPv6）："
        green "$clash_v6"
        [[ "$mode" != "silent" ]] && generate_qr "$clash_v6"
        echo ""

        purple "Sing-box（IPv6）："
        green "$singbox_v6"
        [[ "$mode" != "silent" ]] && generate_qr "$singbox_v6"
        echo ""

        purple "Surge（IPv6）："
        green "$surge_v6"
        [[ "$mode" != "silent" ]] && generate_qr "$surge_v6"
        echo ""
    fi

    yellow "========================================================"

    [[ "$mode" != "silent" ]] && pause_return
}



get_node_name() {
    local name

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
        echo "${AUTHOR}-hy2"
        return
    fi

    echo "$name"
}



init_node_name_on_install() {

    local DEFAULT_NODE_NAME="${AUTHOR}-hy2"
    local country="" org="" name=""

    # 已存在则不覆盖（重装/升级保护）
    [[ -f "$work_dir/node_name" ]] && return

    # 1. ENV 优先
    if [[ -n "$NODE_NAME" ]]; then
        echo "$NODE_NAME" > "$work_dir/node_name"
        green "节点名称初始化为：$NODE_NAME"
        return
    fi

    # 2. IP 推断
    country=$(curl -fs --max-time 2 https://ipapi.co/country 2>/dev/null | tr -d '\r\n')
    org=$(curl -fs --max-time 2 https://ipapi.co/org 2>/dev/null | sed 's/[ ]\+/_/g')

    if [[ -z "$country" ]]; then
        country=$(curl -fs --max-time 2 ip.sb/country 2>/dev/null | tr -d '\r\n')
    fi

    if [[ -z "$org" ]]; then
        org=$(curl -fs --max-time 2 ipinfo.io/org 2>/dev/null \
            | awk '{$1=""; print $0}' \
            | sed -e 's/^[ ]*//' -e 's/[ ]\+/_/g')
    fi

    # 3. 组合规则（修正你原来的不一致）
    if [[ -n "$country" && -n "$org" ]]; then
        name="${country}-${org}"
    elif [[ -n "$country" ]]; then
        name="$country"
    elif [[ -n "$org" ]]; then
        name="$org"
    else
        name="$DEFAULT_NODE_NAME"
    fi

    echo "$name" > "$work_dir/node_name"
    green "节点名称初始化为：$name"
}


# ============================================================
# Sing-box 服务管理
# ============================================================
manage_singbox() {
    while true; do
        clear
        blue "========== Sing-box 服务管理 =========="
        echo ""
        green " 1. 启动 Sing-box"
        green " 2. 停止 Sing-box"
        green " 3. 重启 Sing-box"
        green " 4. 查看运行状态"
        yellow "--------------------------------------"
        green " 0. 返回上级菜单"
        red   "88. 退出脚本"
        echo ""

        read -rp "请选择操作：" sel
        case "$sel" in
            1)
                systemctl start sing-box
                systemctl is-active sing-box >/dev/null 2>&1 \
                    && green "Sing-box 已启动" \
                    || red "Sing-box 启动失败"
                pause_return
                ;;
            2)
                systemctl stop sing-box
                green "Sing-box 已停止"
                pause_return
                ;;
            3)
                systemctl restart sing-box
                systemctl is-active sing-box >/dev/null 2>&1 \
                    && green "Sing-box 已重启" \
                    || red "Sing-box 重启失败"
                pause_return
                ;;
            4)
                systemctl status sing-box -n 20
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

# ============================================================
# 修改 HY2 主端口（自动刷新 NAT）
# ============================================================
change_hy2_port() {

    read -rp "$(red_input "请输入新的 HY2 主端口：")" new_port

    is_valid_port "$new_port" || { red "端口无效"; return; }
    is_port_occupied "$new_port" && { red "端口已被占用"; return; }

    old_port=$(jq -r '.inbounds[0].listen_port' "$config_dir")

    # 修改 config.json
    sed -i "s/\"listen_port\": ${old_port}/\"listen_port\": ${new_port}/" "$config_dir"

    green "主端口已修改：${old_port} → ${new_port}"

    # 刷新防火墙
    allow_port "$new_port"

    # 刷新跳跃端口 NAT（如存在）
    refresh_jump_ports_for_new_main_port "$new_port"


    # 默认回收旧端口（安全策略）
    if [[ "$old_port" != "$new_port" ]]; then
        iptables -D INPUT -p udp --dport "$old_port" -j ACCEPT 2>/dev/null
        ip6tables -D INPUT -p udp --dport "$old_port" -j ACCEPT 2>/dev/null
        green "旧端口 ${old_port} 已回收"
    fi


    # 重启服务
    systemctl restart sing-box

    green "Sing-box 已重启，端口修改生效"

    check_nodes silent
    pause_return

}

# ============================================================
# 修改 UUID
# ============================================================
change_uuid() {

    read -rp "$(red_input "请输入新的 UUID（回车自动生成）：")" new_uuid

    if [[ -z "$new_uuid" ]]; then
        new_uuid=$(cat /proc/sys/kernel/random/uuid)
        green "已生成新 UUID：$new_uuid"
    else
        is_valid_uuid "$new_uuid" || { red "UUID 格式错误"; return; }
    fi

    old_uuid=$(jq -r '.inbounds[0].users[0].password' "$config_dir")

    tmpfile=$(mktemp)
    jq '.inbounds[0].users[0].password = "'"$new_uuid"'"' "$config_dir" > "$tmpfile" \
        && mv "$tmpfile" "$config_dir"

    green "UUID 已修改：${old_uuid} → ${new_uuid}"

    systemctl restart sing-box
    green "Sing-box 已重启"

    pause_return
}

# ============================================================
# 修改节点名称（只改 tag）
# ============================================================
change_node_name() {

    read -rp "$(red_input "请输入新的节点名称：")" new_name
    [[ -z "$new_name" ]] && { red "节点名称不能为空"; return; }

    encoded_name=$(urlencode "$new_name")

    if [[ -f "$client_dir" ]]; then
        old_url=$(cat "$client_dir")
        url_body="${old_url%%#*}"
        echo "${url_body}#${encoded_name}" > "$client_dir"
        green "节点名称已修改"
    fi


    pause_return
}


# ============================================================
# 跳跃端口处理
# ============================================================
apply_range_ports_if_needed() {
    [[ -z "$RANGE_PORTS" ]] && return

    green "检测到跳跃端口……"

    if ! is_valid_range "$RANGE_PORTS"; then
        red "RANGE_PORTS 格式错误，已跳过跳跃端口配置"
        return
    fi

    local min="${RANGE_PORTS%-*}"
    local max="${RANGE_PORTS#*-}"
    local PORT
    PORT=$(jq -r '.inbounds[0].listen_port' "$config_dir")

    yellow "应用跳跃端口区间：${min}-${max} → ${PORT}"

    # 清理旧规则（幂等）
    remove_jump_rule
    
    if [[ -f "$range_port_file" ]]; then
    old=$(cat "$range_port_file")
    remove_jump_input "${old%-*}" "${old#*-}"

    fi


    # 写入状态文件
    echo "$RANGE_PORTS" > "$range_port_file"

    # 放行 INPUT
    iptables -I INPUT -p udp --dport ${min}:${max} -j ACCEPT
    ip6tables -I INPUT -p udp --dport ${min}:${max} -j ACCEPT

    # 添加 NAT
    add_jump_rule "$min" "$max" "$PORT"

    green "跳跃端口已生效：$RANGE_PORTS"
}



# ============================================================
# 启用 / 修改跳跃端口（动作函数）
# ============================================================
enable_or_update_jump_ports() {
    read -rp "$(red_input "请输入跳跃端口区间（如 10000-20000）：")" rp

    if ! is_valid_range "$rp"; then
        red "跳跃端口格式错误"
        pause_return
        return
    fi

    local min="${rp%-*}"
    local max="${rp#*-}"
    local PORT
    PORT=$(jq -r '.inbounds[0].listen_port' "$config_dir")

    # 幂等清理旧规则
    remove_jump_rule
    if [[ -f "$range_port_file" ]]; then
        old_range=$(cat "$range_port_file")
        remove_jump_input "${old_range%-*}" "${old_range#*-}"
    fi

    # 写入状态文件
    echo "$rp" > "$range_port_file"

    # 放行 INPUT
    iptables -I INPUT -p udp --dport ${min}:${max} -j ACCEPT
    ip6tables -I INPUT -p udp --dport ${min}:${max} -j ACCEPT

    # 添加 NAT
    add_jump_rule "$min" "$max" "$PORT"

    green "跳跃端口已启用 / 更新：$rp"
    pause_return
}

# ============================================================
# 关闭跳跃端口（动作函数）
# ============================================================
disable_jump_ports() {
    if [[ ! -f "$range_port_file" ]]; then
        yellow "当前未启用跳跃端口"
        pause_return
        return
    fi

    local rp
    rp=$(cat "$range_port_file")
    local min="${rp%-*}"
    local max="${rp#*-}"

    remove_jump_rule
    remove_jump_input "$min" "$max"
    rm -f "$range_port_file"

    green "跳跃端口已关闭"
    pause_return
}


# ============================================================
# 修改节点配置菜单（平铺最终版）
# ============================================================
manage_node_config_menu() {
    while true; do
        clear
        blue "========== 修改节点配置 =========="
        echo ""

        # 当前节点状态提示
        local CUR_PORT CUR_UUID CUR_RANGE
        CUR_PORT=$(jq -r '.inbounds[0].listen_port' "$config_dir" 2>/dev/null)
        CUR_UUID=$(jq -r '.inbounds[0].users[0].password' "$config_dir" 2>/dev/null)

        if [[ -f "$range_port_file" ]]; then
            CUR_RANGE=$(cat "$range_port_file")
        else
            CUR_RANGE="未启用"
        fi

        yellow "当前主端口：${CUR_PORT:-未安装}"
        yellow "当前 UUID ：${CUR_UUID:-未安装}"
        yellow "跳跃端口  ：$CUR_RANGE"
        echo ""

        green " 1. 修改 HY2 主端口"
        green " 2. 修改 UUID"
        green " 3. 修改节点名称"
        green " 4. 修改跳跃端口"
        green " 5. 关闭跳跃端口"
        yellow "---------------------------------"
        green " 0. 返回上级菜单"
        red   "88. 退出脚本"
        echo ""

        read -rp "请选择操作：" sel
        case "$sel" in
            1)
                change_hy2_port
                ;;
            2)
                change_uuid
                ;;
            3)
                change_node_name
                ;;
            4)
                enable_or_update_jump_ports
                ;;
            5)
                disable_jump_ports
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

uninstall_singbox() {

    clear
    blue "============== 卸载 HY2 =============="
    echo ""

    read -rp "确认卸载Singbox(包括卸载hy2)？ [Y/n]（默认 Y）：" u
    u=${u:-y}

    [[ ! "$u" =~ ^[Yy]$ ]] && { yellow "已取消卸载"; pause_return; return; }

    # ---------- 清理跳跃端口 ----------
    remove_jump_rule
    if [[ -f "$range_port_file" ]]; then
        rp=$(cat "$range_port_file")
        min="${rp%-*}"
        max="${rp#*-}"
        iptables -D INPUT -p udp --dport ${min}:${max} -j ACCEPT 2>/dev/null
        ip6tables -D INPUT -p udp --dport ${min}:${max} -j ACCEPT 2>/dev/null
        rm -f "$range_port_file"
    fi

    green "已清理跳跃端口相关防火墙规则"

    # ---------- 停止并删除服务 ----------
    systemctl stop sing-box 2>/dev/null
    systemctl disable sing-box 2>/dev/null
    rm -f /etc/systemd/system/sing-box.service
    systemctl daemon-reload

    # ---------- 删除运行目录 ----------
    rm -rf "$work_dir"

    # ---------- 删除 nginx 订阅配置 ----------
    rm -f /etc/nginx/conf.d/singbox_hy2_sub.conf

    # ---------- 是否卸载 nginx ----------
    if command_exists nginx; then
        echo ""
        read -rp "是否卸载 Nginx？ [y/N]（默认 N）：" delng
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

    green "HY2 卸载完成"
    pause_return
}


# ============================================================
# 订阅服务（Nginx）管理菜单
# ============================================================
manage_subscribe_menu() {
    while true; do
        clear
        blue "========== 订阅服务管理（Nginx） =========="
        echo ""

        green " 1. 启动 Nginx"
        green " 2. 停止 Nginx"
        green " 3. 重启 Nginx"
        green " 4. 修改订阅端口"
        yellow "-----------------------------------------"
        green " 0. 返回上级菜单"
        red   "88. 退出脚本"
        echo ""

        read -rp "请选择操作：" sel
        case "$sel" in
            1)
                systemctl start nginx
                systemctl is-active nginx >/dev/null 2>&1 \
                    && green "Nginx 已启动" \
                    || red "Nginx 启动失败"
                pause_return
                ;;
            2)
                systemctl stop nginx
                green "Nginx 已停止"
                pause_return
                ;;
            3)
                systemctl restart nginx
                systemctl is-active nginx >/dev/null 2>&1 \
                    && green "Nginx 已重启" \
                    || red "Nginx 重启失败"
                pause_return
                ;;
            4)
                read -rp "$(red_input "请输入新的订阅端口：")" new_sub_port
                if ! is_valid_port "$new_sub_port"; then
                    red "端口无效"
                    pause_return
                    continue
                fi
                echo "$new_sub_port" > "$sub_port_file"
                green "订阅端口已修改为：$new_sub_port"
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


# ============================================================
# 主菜单（最终版，对齐 tuic5）
# ============================================================
main_menu() {
    while true; do
        clear
        blue "===================================================="
        gradient "       Sing-box 一键脚本（hy2版本）"
        green    "       作者：$AUTHOR"
        yellow   "       版本：$VERSION"
        blue "===================================================="
        echo ""


        sb="$(get_singbox_status_colored)"
        ng="$(get_nginx_status_colored)"

        yellow " Sing-box 状态：$sb"
        yellow " Nginx 状态：   $ng"
        echo ""
        green " 1. 安装 Sing-box (HY2)"
        red   " 2. 卸载 Sing-box"
        yellow "----------------------------------------"
        green " 3. 管理 Sing-box 服务"
        green " 4. 查看节点信息"
        yellow "----------------------------------------"
        green " 5. 修改节点配置"
        green " 6. 订阅服务管理"
        yellow "---------------------------------------------"
        green " 88. 退出脚本"
        echo ""

        read -rp "请选择操作：" choice
        case "$choice" in
            1)
                install_singbox
                # 安装后统一处理（对齐自动模式）
                apply_range_ports_if_needed
                check_nodes
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
                manage_node_config_menu
                ;;
            6)
                manage_subscribe_menu
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


get_singbox_status_colored() {
    # 未安装：systemd 服务文件不存在
    if ! systemctl list-unit-files --type=service 2>/dev/null | grep -q '^sing-box\.service'; then
        red "未安装"
        return
    fi

    # 已安装，正在运行
    if systemctl is-active sing-box >/dev/null 2>&1; then
        green "运行中"
    else
        red "未运行"
    fi
}



# ==================================================
#Nginx 状态 =「订阅服务是否可用」
#这至少应该满足 任意一条：
#1、nginx service active
#2、订阅端口存在且被监听
#3、订阅配置文件存在 + 进程存在
# ==================================================
get_nginx_status_colored() {

    # nginx 未安装
    if ! command_exists nginx; then
        red "未安装"
        return
    fi

    # 有订阅端口，并且端口正在监听（IPv4 / IPv6 任一）
    if [[ -f "$sub_port_file" ]]; then
        local p
        p=$(cat "$sub_port_file")

        if ss -tuln | grep -q ":$p "; then
            green "运行中"
            return
        fi
    fi

    # fallback：systemd 状态
    if systemctl is-active nginx >/dev/null 2>&1; then
        green "运行中"
    else
        red "未运行"
    fi
}



main_entry() {
    is_interactive_mode
    if [[ $? -eq 1 ]]; then
        # ==================================================
        # 非交互式 / 自动模式
        # ==================================================
        yellow "检测到自动模式（ENV 已传入），开始自动部署..."

        install_singbox

        #  显式处理跳跃端口
        apply_range_ports_if_needed

        echo ""
        green "安装完成，正在输出节点与订阅信息..."
        echo ""

        # 自动模式下不 pause
        check_nodes silent

        green "自动模式执行完成"
        exit 0
    else
        # ==================================================
        # 交互式模式
        # ==================================================
        main_menu
    fi
}


main_entry
