#!/bin/bash
export LANG=en_US.UTF-8

# ======================================================================
# Sing-box Hy2 一键脚本（hy2版）-----适用于singbox版本>1.12+
# 作者：littleDoraemon  
# 说明：
#   - 带端口跳跃功能的hy2
#   - 修复跳跃端口逻辑、主端口更新、订阅同步不一致问题
#   - 带订阅功能
# ======================================================================


# ======================================================================
# 环境变量加载（用于自动模式部署）
# 若外部传入 PORT/UUID/RANGE_PORTS/NODE_NAME，则会自动安装
# ======================================================================
load_env_vars() {
    while IFS='=' read -r key value; do
        case "$key" in
            PORT|UUID|RANGE_PORTS|NODE_NAME)
                # 校验基本格式，避免非预期注入
                if [[ -n "$value" && "$value" =~ ^[a-zA-Z0-9\.\-\:_/]+$ ]]; then
                    export "$key=$value"
                fi
                ;;
        esac
    done < <(env | grep -E '^(PORT|UUID|RANGE_PORTS|NODE_NAME)=')
}
load_env_vars


# ======================================================================
# 判断模式：如果外部传入了变量 → 自动模式，否则交互模式
# ======================================================================
is_interactive_mode() {
    if [[ -n "$PORT" || -n "$UUID" || -n "$RANGE_PORTS" || -n "$NODE_NAME" ]]; then
        return 1   # 自动模式
    else
        return 0   # 交互模式
    fi
}


# ======================================================================
# 全局常量与关键路径
# ======================================================================
SINGBOX_VERSION="1.12.13" #Sing-box版本，因为sb版本老是变动，还不适配旧配置，所以只好逮一个固定版本
AUTHOR="littleDoraemon"
VERSION="v1.0.1"

# Sing-box 运行目录
work_dir="/etc/sing-box"

# Hy2 原始链接（URL）保存路径
client_dir="${work_dir}/url.txt"

# Sing-box 主配置文件
config_dir="${work_dir}/config.json"

# 订阅文件（sub.txt）
sub_file="${work_dir}/sub.txt"

# ⚠ 订阅端口文件：只在首次安装时生成
sub_port_file="/etc/sing-box/sub.port"

# 默认 UUID（自动模式下使用）
DEFAULT_UUID=$(cat /proc/sys/kernel/random/uuid)

ensure_url_file() {
    mkdir -p "$work_dir"
    [[ -f "$client_dir" ]] || touch "$client_dir"
}

# ======================================================================
# UI 颜色输出（保留你的风格）
# ======================================================================
re="\033[0m"
white()  { echo -e "\033[1;37m$1\033[0m"; }
red()    { echo -e "\e[1;91m$1\033[0m"; }
green()  { echo -e "\e[1;32m$1\033[0m"; }
yellow() { echo -e "\e[1;33m$1\033[0m"; }
purple() { echo -e "\e[1;35m$1\033[0m"; }
blue()   { echo -e "\e[1;34m$1\033[0m"; }


# 渐变文本（可用于标题）
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


red_input() { printf "\e[1;91m%s\033[0m" "$1"; }

# 错误输出工具
err() { red "[错误] $1" >&2; }


# ======================================================================
# Root 权限检查（必要）
# ======================================================================
if [[ $EUID -ne 0 ]]; then
    err "请使用 root 权限运行脚本"
    exit 1
fi

# 检查命令是否存在
command_exists() { command -v "$1" >/dev/null 2>&1; }


# ======================================================================
# 安装常用依赖（增强修复版）
# ======================================================================
install_common_packages() {

    # 需要安装的依赖
    local pkgs="tar jq openssl lsof curl coreutils qrencode nginx"
    local need_update=1

    for p in $pkgs; do
        if ! command_exists "$p"; then

            # 首次缺包 → 进行 update（避免每个包都执行一次）
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
                red "无法识别你的包管理器，请手动安装依赖：$p"
            fi
        fi
    done
}


# ======================================================================
# ------------------------ 端口工具函数 -------------------------------
# ======================================================================


# ======================================================================
# 在线二维码输出（
# 功能：
#   - 将任意 URL 转换成可扫描的二维码链接
#   - 适用 V2rayN / Clash / Singbox 等展示输出
# ======================================================================
generate_qr() {
    local link="$1"

    if [[ -z "$link" ]]; then
        red "二维码生成失败：链接为空"
        return 1
    fi

    echo ""
    yellow "二维码链接："
    echo "https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${link}"
}


# ======================================================================
# URL 编码 / 解码函数
# ======================================================================
urlencode() {
    printf "%s" "$1" | jq -sRr @uri
}

urldecode() {
    printf '%b' "${1//%/\\x}"
}


# 校验端口号格式
is_valid_port() { [[ "$1" =~ ^[0-9]+$ && "$1" -ge 1 && "$1" -le 65535 ]]; }


# ======================================================================
# 判断端口是否被占用，占用返回0，空闲返回1
# ======================================================================
is_port_occupied() {
    ss -tuln | grep -q ":$1 " && return 0
    lsof -i :"$1" &>/dev/null && return 0
    netstat -tuln 2>/dev/null | grep -q ":$1 " && return 0
    return 1
}

# 获取端口（用户指定或自动生成）
get_port() {
    local p="$1"

    # 用户有指定端口 → 校验即可
    if [[ -n "$p" ]]; then
        is_valid_port "$p" || { err "端口无效"; exit 1; }
        is_port_occupied "$p" && { err "端口已被占用"; exit 1; }
        echo "$p"
        return
    fi

    # 自动随机选择端口
    while true; do
        rp=$(shuf -i 1-65535 -n 1)
        ! is_port_occupied "$rp" && { echo "$rp"; return; }
    done
}


# ======================================================================
# 获取节点名称（最终严格规则版）
# 规则：
#   1. 国家代码 ≠ 空 且 运营商 ≠ 空 → 国家代码-运营商
#   2. 国家代码 ≠ 空 且 运营商 = 空 → 国家代码
#   3. 国家代码 = 空 且 运营商 ≠ 空 → DEFAULT_NODE_NAME
#   4. 国家代码 = 空 且 运营商 = 空 → DEFAULT_NODE_NAME
# ======================================================================
get_node_name() {

    # 默认节点名称的生成逻辑（与你脚本保持一致）
    local DEFAULT_NODE_NAME
    if [[ "${0##*/}" == *"hy2"* || "${0##*/}" == *"hysteria2"* ]]; then
        DEFAULT_NODE_NAME="$AUTHOR-hy2"
    else
        DEFAULT_NODE_NAME="$AUTHOR"
    fi

    # 用户提供的 NODE_NAME 优先
    if [[ -n "$NODE_NAME" ]]; then
        echo "$NODE_NAME"
        return
    fi

    local country=""
    local org=""

    # ======================================================
    # 尝试从 ipapi.co 获取国家代码与运营商
    # ======================================================
    country=$(curl -fs --max-time 2 https://ipapi.co/country 2>/dev/null | tr -d '\r\n')
    org=$(curl -fs --max-time 2 https://ipapi.co/org 2>/dev/null \
        | sed 's/[ ]\+/_/g')

    # ======================================================
    # fallback 获取方式（ip.sb + ipinfo.io）
    # ======================================================
    if [[ -z "$country" ]]; then
        country=$(curl -fs --max-time 2 ip.sb/country 2>/dev/null | tr -d '\r\n')
    fi

    if [[ -z "$org" ]]; then
        org=$(curl -fs --max-time 2 ipinfo.io/org 2>/dev/null \
            | awk '{$1=""; print $0}' \
            | sed -e 's/^[ ]*//' -e 's/[ ]\+/_/g')
    fi

    # ======================================================
    # 按你的严格规则构造节点名称
    # ======================================================

    # 情况 1：国家代码 ≠ 空 且 运营商 ≠ 空 → "国家代码-运营商"
    if [[ -n "$country" && -n "$org" ]]; then
        echo "${country}-${org}"
        return
    fi

    # 情况 2：国家代码 ≠ 空 且 运营商 = 空 → "国家代码"
    if [[ -n "$country" && -z "$org" ]]; then
        echo "$country"
        return
    fi

    # 情况 3：国家代码 = 空 且 运营商 ≠ 空 → 返回默认名称
    if [[ -z "$country" && -n "$org" ]]; then
        echo "$DEFAULT_NODE_NAME"
        return
    fi

    # 情况 4：国家代码 = 空 且 运营商 = 空 → 返回默认名称
    echo "$DEFAULT_NODE_NAME"
}

# ======================================================================
# 放行 HY2 主端口的 UDP 流量（增强版）
# 说明：
#   - 保留你的原逻辑：firewalld → iptables → ip6tables
#   - 必须保证端口可被外网访问，否则节点不可用
# ======================================================================
allow_port() {
    local port="$1"

    # firewalld（CentOS/RHEL）
    if command_exists firewall-cmd; then
        firewall-cmd --permanent --add-port=${port}/udp &>/dev/null
        firewall-cmd --reload &>/dev/null
    fi

    # IPv4 规则
    iptables  -C INPUT -p udp --dport "$port" -j ACCEPT &>/dev/null ||
        iptables  -I INPUT -p udp --dport "$port" -j ACCEPT

    # IPv6 规则
    ip6tables -C INPUT -p udp --dport "$port" -j ACCEPT &>/dev/null ||
        ip6tables -I INPUT -p udp --dport "$port" -j ACCEPT

    green "已放行 UDP 端口：$port"
}


# ======================================================================
# ------------------------ UUID 工具函数 -------------------------------
# ======================================================================

# 校验 UUID
is_valid_uuid() {
    [[ "$1" =~ ^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$ ]]
}

# 获取 UUID（允许外部传入）
get_uuid() {
    if [[ -n "$1" ]]; then
        is_valid_uuid "$1" || { err "UUID 格式错误"; exit 1; }
        echo "$1"
    else
        echo "$DEFAULT_UUID"
    fi
}


# ======================================================================
# -------------------- 跳跃端口格式校验工具 ---------------------------
# ======================================================================

# ======================================================================
# 从 url.txt 解析跳跃端口范围 RANGE_PORTS（增强修复版）
# 说明：
#   - 从 url.txt 中提取 mport=xxxx,10000-20000 这样的端口区间
#   - 若没有跳跃端口 → 返回空字符串
#   - 脚本所有跳跃端口功能都依赖该函数
# ======================================================================
parse_range_ports_from_url() {

    # 若 url.txt 不存在 → 认定无跳跃端口
    if [[ ! -f "$client_dir" ]]; then
        echo ""
        return
    fi

    local url mport_part range
    url=$(cat "$client_dir")

    # 提取 mport= 的内容，例如：
    # mport=31020,10000-20000
    mport_part=$(echo "$url" | sed -n 's/.*mport=\([^&#]*\).*/\1/p')

    # 没有 mport 字段 → 无跳跃端口
    [[ -z "$mport_part" ]] && {
        echo ""
        return
    }

    # 如果 mport 格式为 主端口,范围
    # 如：31020,10000-20000
    if [[ "$mport_part" == *,* ]]; then
        range="${mport_part#*,}"
        echo "$range"
    else
        # mport 只有主端口，没有范围 → 无跳跃
        echo ""
    fi
}

is_valid_range() {
    [[ "$1" =~ ^([0-9]+)-([0-9]+)$ ]] || return 1
    local min="${BASH_REMATCH[1]}"
    local max="${BASH_REMATCH[2]}"
    is_valid_port "$min" && is_valid_port "$max" && [[ $min -lt $max ]]
}

get_range_ports() {
    local r="$1"
    [[ -z "$r" ]] && { echo ""; return; }
    is_valid_range "$r" || { err "跳跃端口格式错误（例如 10000-20000）"; exit 1; }
    echo "$r"
}
# ======================================================================
# 跳跃端口删除模块
# 说明：
#   本模块用于彻底删除跳跃端口功能，包括：
#       - 删除 NAT 跳跃端口规则（IPv4 + IPv6）
#       - 删除 url.txt 中的 mport 参数
#       - 恢复普通 HY2 格式的订阅文件
#   ⚠ 注意：不修改 sub.port（订阅端口），遵守你的规则
# ======================================================================

delete_jump_rule() {

    # 1. 删除 NAT 跳跃端口规则（IPv4 + IPv6）
    remove_nat_jump_rules

    # 2. 删除 url.txt 中的 mport 字段
    restore_url_without_jump

    # 3. 将订阅文件恢复到普通 HY2 格式（不带跳跃端口区间）
    restore_sub_files_default

    # 4. 提示完成
    print_delete_jump_success
}

print_delete_jump_success() {
    green "跳跃端口已删除，URL / 订阅文件已恢复为标准 HY2 模式"
}


# ======================================================================
# 添加跳跃端口 NAT 规则
# 功能：
#   - 将 udp 的 min-max 跳跃端口区间转发到 HY2 主端口 listen_port
#   - 添加 IPv4 与 IPv6 NAT 规则
#   - 规则使用 comment 标记为 hy2_jump，便于删除
# ======================================================================

add_jump_rule() {
    local min="$1"
    local max="$2"
    local listen_port="$3"

    # ===============================
    # IPv4 NAT 转发规则
    # ===============================
    iptables -t nat -A PREROUTING \
        -p udp --dport ${min}:${max} \
        -m comment --comment "hy2_jump" \
        -j DNAT --to-destination :${listen_port}

    # ===============================
    # IPv6 NAT 转发规则
    # ===============================
    ip6tables -t nat -A PREROUTING \
        -p udp --dport ${min}:${max} \
        -m comment --comment "hy2_jump" \
        -j DNAT --to-destination :${listen_port}

    green "已添加跳跃端口 NAT 转发：${min}-${max} → ${listen_port}"
}

# ======================================================================
# 删除 NAT 跳跃端口规则
# ======================================================================
remove_nat_jump_rules() {

    # -------------------------
    # 删除 IPv4 NAT 规则
    # -------------------------
    while iptables -t nat -C PREROUTING -m comment --comment "hy2_jump" &>/dev/null; do
        iptables -t nat -D PREROUTING -m comment --comment "hy2_jump"
    done

    # -------------------------
    # 删除 IPv6 NAT 规则
    # -------------------------
    while ip6tables -t nat -C PREROUTING -m comment --comment "hy2_jump" &>/dev/null; do
        ip6tables -t nat -D PREROUTING -m comment --comment "hy2_jump"
    done

    green "跳跃端口 NAT 规则已删除（IPv4 / IPv6）"
}



# ======================================================================
# 恢复 url.txt → 删除 mport 参数（保留节点名称）
# ======================================================================
restore_url_without_jump() {

    ensure_url_file

    [[ ! -f "$client_dir" ]] && {
        yellow "未找到 url.txt，跳过 URL 清理"
        return
    }

    local old_url=$(cat "$client_dir")

    # 节点名称在 # 后面
    local node_tag="${old_url#*#}"

    # URL 主体在 # 前面
    local url_body="${old_url%%#*}"

    # -------------------------
    # 删除 mport=xxxx 或 mport=xxxx,yyyy-zzzz
    # -------------------------
    local cleaned=$(echo "$url_body" | sed 's/[&?]mport=[^&]*//')

    # 修复由于删除 mport 导致的多余 "?" 或 "?&"
    cleaned=$(echo "$cleaned" | sed 's/?&/?/' | sed 's/\?$//')

    echo "${cleaned}#${node_tag}" > "$client_dir"

    green "url.txt 已恢复为无 mport 的标准 HY2 URL"
}



# ======================================================================
# 恢复订阅文件
# 说明：
#   - 保持订阅端口不变
# ======================================================================
restore_sub_files_default() {

    local hy2_port uuid server_ip sub_port sub_url

    # -------------------------
    # 获取服务器公网 IP
    # -------------------------
    ipv4=$(curl -4 -s https://api.ipify.org)
    ipv6=$(curl -6 -s https://api64.ipify.org)
    [[ -n "$ipv4" ]] && server_ip="$ipv4" || { server_ip="[$ipv6]"; }
    

    uuid=$(jq -r '.inbounds[0].users[0].password' "$config_dir")

    # -------------------------
    # 使用原来的订阅端口（不自动修改）
    # -------------------------
    if [[ -f "$sub_port_file" ]]; then
        sub_port=$(cat "$sub_port_file")
    else
        # fallback（极罕见）
        hy2_port=$(jq -r '.inbounds[0].listen_port' "$config_dir")
        sub_port=$((hy2_port + 1))
    fi

    # -------------------------
    # 恢复普通 HY2 订阅 URL
    # -------------------------
    sub_url="http://${server_ip}:${sub_port}/${uuid}"

# 写入 sub.txt
cat > "$sub_file" <<EOF
# HY2 主订阅（跳跃端口已删除）
$sub_url
EOF

    # 写 base64
    base64 -w0 "$sub_file" > "${work_dir}/sub_base64.txt"

    # 写 json
cat > "${work_dir}/sub.json" <<EOF
{
  "hy2": "$sub_url"
}
EOF

    green "订阅文件已恢复为不含跳跃端口的标准格式"
}
# ======================================================================
# 添加跳跃端口
# 功能说明：
#   1. 自动放行跳跃端口区间（INPUT）
#   2. 清除旧的 NAT hy2_jump 规则，再重新添加
#   3. 正确更新 url.txt 的 mport 字段
#   4. 为跳跃端口生成新的订阅文件（不修改 sub.port）
#   5. 兼容普通模式与跳跃端口模式的切换
# ======================================================================

configure_port_jump() {
    local min="$1"
    local max="$2"

    # 获取 HY2 主端口
    local listen_port
    listen_port=$(jq -r '.inbounds[0].listen_port' "$config_dir")
    [[ -z "$listen_port" ]] && { err "无法读取 HY2 主端口"; return 1; }

    echo ""
    green "开始应用跳跃端口：${min}-${max}"
    echo ""

    # =====================================================
    # 1. 放行 INPUT（IPv4 + IPv6）
    # =====================================================
    iptables -C INPUT -p udp -m multiport --dports ${min}:${max} -j ACCEPT &>/dev/null || \
        iptables -I INPUT -p udp -m multiport --dports ${min}:${max} -j ACCEPT

    ip6tables -C INPUT -p udp -m multiport --dports ${min}:${max} -j ACCEPT &>/dev/null || \
        ip6tables -I INPUT -p udp -m multiport --dports ${min}:${max} -j ACCEPT

    green "已放行 UDP 端口区间：${min}-${max}"


    # =====================================================
    # 2. 清理旧 NAT 规则（但不删除 URL/订阅）
    # =====================================================
    while iptables -t nat -C PREROUTING -m comment --comment "hy2_jump" &>/dev/null; do
        iptables -t nat -D PREROUTING -m comment --comment "hy2_jump"
    done

    while ip6tables -t nat -C PREROUTING -m comment --comment "hy2_jump" &>/dev/null; do
        ip6tables -t nat -D PREROUTING -m comment --comment "hy2_jump"
    done

    yellow "旧跳跃 NAT 规则已清理"


    # =====================================================
    # 3. 添加新的 NAT 规则（IPv4 / IPv6）
    # =====================================================
    add_jump_rule "$min" "$max" "$listen_port"


    # =====================================================
    # 4. 更新 URL (url.txt) — 只更新 mport，不动其它参数
    # =====================================================
    ensure_url_file
    if [[ -f "$client_dir" ]]; then
        old_url=$(cat "$client_dir")

        url_body="${old_url%%#*}"
        node_tag="${old_url#*#}"

        host_part="${url_body%%\?*}"
        query_part="${url_body#*\?}"

        # Case A：没有 query 参数
        if [[ "$url_body" == "$host_part" ]]; then
            new_url="${host_part}?mport=${listen_port},${min}-${max}#${node_tag}"
        else
            if echo "$query_part" | grep -q "mport="; then
                new_query=$(echo "$query_part" | sed "s/mport=[^&]*/mport=${listen_port},${min}-${max}/")
            else
                new_query="${query_part}&mport=${listen_port},${min}-${max}"
            fi
            new_url="${host_part}?${new_query}#${node_tag}"
        fi

        echo "$new_url" > "$client_dir"
        green "url.txt 已更新 mport=${listen_port},${min}-${max}"
    fi


    # =====================================================
    # 5. 更新订阅文件（保持 sub.port，不写跳跃区间）
    # =====================================================
    uuid=$(jq -r '.inbounds[0].users[0].password' "$config_dir")

    # 获取订阅端口 sub.port（不自动修改）
    if [[ -f "$sub_port_file" ]]; then
        sub_port=$(cat "$sub_port_file")
    else
        sub_port=$((listen_port + 1))
    fi

    ipv4=$(curl -4 -s https://api.ipify.org)
    ipv6=$(curl -6 -s https://api64.ipify.org)
   [[ -n "$ipv4" ]] && server_ip="$ipv4" || { server_ip="[$ipv6]"; }

    # ❗关键：订阅永远使用 sub_port，而不是 min-max
    sub_url="http://${server_ip}:${sub_port}/${uuid}"

cat > "$sub_file" <<EOF
# HY2 主订阅（跳跃端口模式，但订阅端口不变）
$sub_url
EOF

    base64 -w0 "$sub_file" > "${work_dir}/sub_base64.txt"

cat > "${work_dir}/sub.json" <<EOF
{
  "hy2": "$sub_url"
}
EOF

    green "订阅文件已更新（保持 sub.port 原样，不使用跳跃端口）"


    # =====================================================
    # 6. 重启服务
    # =====================================================
    restart_singbox
    green "跳跃端口已成功启用 → 生效区间：${min}-${max}"

    echo ""
    yellow "提示：订阅端口 sub.port 未被修改（这是正确行为）"
    echo ""
}




# ======================================================================
# 修改 HY2 主端口
# 功能说明：
#   - 自动修改 config.json 的 listen_port
#   - 若开启跳跃端口 → 自动删除旧 NAT & 重建新 NAT
#   - 自动同步 url.txt 中的端口
#   - 自动同步 mport 主端口（仅跳跃端口模式）
#   - 自动同步订阅 sub.txt / base64 / sub.json
#   - ⚠ 不修改 sub.port（订阅端口），遵守你的原则
# ======================================================================
change_hy2_port() {


    read -rp "$(red_input "请输入新的 HY2 主端口：")" new_port

    # ------------------------------
    # 基础端口校验
    # ------------------------------
    if ! is_valid_port "$new_port"; then
        red "端口无效"; return
    fi
    if is_port_occupied "$new_port"; then
        red "端口已被占用"; return
    fi

    local old_port uuid server_ip
    old_port=$(jq -r '.inbounds[0].listen_port' "$config_dir")
    uuid=$(jq -r '.inbounds[0].users[0].password' "$config_dir")

    # ------------------------------
    # 1. 修改 config.json
    # ------------------------------
    sed -i "s/\"listen_port\": ${old_port}/\"listen_port\": ${new_port}/" "$config_dir"
    green "config.json 已更新主端口：${old_port} → ${new_port}"

    # ------------------------------
    # 2. 如果存在跳跃端口 → 重建 NAT 规则
    # ------------------------------
    RANGE_PORTS=$(parse_range_ports_from_url)

    if [[ -n "$RANGE_PORTS" ]]; then
        local min="${RANGE_PORTS%-*}"
        local max="${RANGE_PORTS#*-}"

        yellow "检测到跳跃端口模式，正在重新绑定 NAT..."

        # 删除旧 NAT 和旧 mport
        delete_jump_rule

        # 重建 NAT（绑定到新的主端口）
        configure_port_jump "$min" "$max"

        green "跳跃端口 NAT 已重新绑定到新端口 ${new_port}"
    fi

    # ------------------------------
    # 3. 同步更新 url.txt 的端口 + mport 主端口
    # ------------------------------
    ensure_url_file
    if [[ -f "$client_dir" ]]; then
        local old_url=$(cat "$client_dir")
        local node_tag="${old_url#*#}"    # 节点名称
        local url_body="${old_url%%#*}"   # URL 主体

        # 修改主端口（@IP:port 部分）
        local updated=$(echo "$url_body" | sed "s/:${old_port}/:${new_port}/")

        # 若开启跳跃端口，则同步更新 mport 主端口
        if [[ -n "$RANGE_PORTS" ]]; then
            updated=$(echo "$updated" | sed "s/mport=[0-9]*/mport=${new_port}/")
        fi

        echo "${updated}#${node_tag}" > "$client_dir"
        green "url.txt 已同步更新主端口"
    fi

    # ------------------------------
    # 4. 订阅端口 sub.port 不变，只更新订阅内容
    # ------------------------------
    if [[ -f "$sub_port_file" ]]; then
        sub_port=$(cat "$sub_port_file")   # 订阅端口不自动改
    else
        sub_port=$((new_port + 1))         # fallback（极罕见）
    fi

    # 获取服务器 IP
    ipv4=$(curl -4 -s https://api.ipify.org)
    ipv6=$(curl -6 -s https://api64.ipify.org)
    [[ -n "$ipv4" ]] && server_ip="$ipv4" || { server_ip="[$ipv6]"; }

    # 生成新的订阅 URL（不使用跳跃端口）
    sub_link="http://${server_ip}:${sub_port}/${uuid}"

# 写 sub.txt
cat > "$sub_file" <<EOF
# HY2 主订阅（主端口修改）
$sub_link
EOF

    # 写 base64
    base64 -w0 "$sub_file" > "${work_dir}/sub_base64.txt"

    # 写 json
cat > "${work_dir}/sub.json" <<EOF
{
  "hy2": "$sub_link"
}
EOF

    green "订阅文件已同步更新（但 sub.port 保持不变）"

    # ------------------------------
    # 5. 重启服务，使配置生效
    # ------------------------------
    restart_singbox
    systemctl restart nginx

    green "HY2 主端口已修改：${old_port} → ${new_port}"
    green "URL / NAT / mport / 订阅已全部更新"
    yellow "注意：订阅端口 sub.port 未被修改，遵从你的规则"
}


# ======================================================================
# 修改 UUID
# 功能特点：
#   - 支持按回车自动生成新的 UUID
#   - 使用 jq 安全写入 JSON（绝不会破坏 config.json）
#   - 自动同步更新 url.txt / sub.txt / sub_base64 / sub.json
#   - 完全兼容跳跃端口模式（RANGE_PORTS）
#   - ⚠ 不修改 sub.port（严格遵守你的规则）
# ======================================================================
change_uuid() {

    echo ""
    read -rp "$(red_input "请输入新的 UUID（回车自动生成）：")" new_uuid

    # ---------------------------------------------------------------
    # 1. 如果用户直接按回车 → 自动生成新的 UUID
    # ---------------------------------------------------------------
    if [[ -z "$new_uuid" ]]; then
        new_uuid=$(cat /proc/sys/kernel/random/uuid)
        green "已自动生成新的 UUID：$new_uuid"
    else
        if ! is_valid_uuid "$new_uuid"; then
            red "UUID 格式不正确，请重新输入"
            return
        fi
    fi

    # 当前 UUID
    local old_uuid
    old_uuid=$(jq -r '.inbounds[0].users[0].password' "$config_dir")

    # ---------------------------------------------------------------
    # 2. 使用 jq 安全写入 UUID（不会破坏 JSON）
    # ---------------------------------------------------------------
    tmpfile=$(mktemp)
    jq '.inbounds[0].users[0].password = "'"$new_uuid"'"' "$config_dir" > "$tmpfile" \
        && mv "$tmpfile" "$config_dir"

    green "config.json 中的 UUID 已成功更新"


    # ---------------------------------------------------------------
    # 3. 同步 url.txt（安全替换 UUID）
    # ---------------------------------------------------------------
    if [[ -f "$client_dir" ]]; then
        local old_url new_url_body node_tag

        old_url=$(cat "$client_dir")
        node_tag="${old_url#*#}"
        url_body="${old_url%%#*}"

        # 替换 URL 中的旧 UUID
        new_url_body=$(echo "$url_body" | sed "s/${old_uuid}@/${new_uuid}@/")

        echo "${new_url_body}#${node_tag}" > "$client_dir"
        green "url.txt 已同步更新 UUID"
    fi


    # ---------------------------------------------------------------
    # 4. 同步订阅文件（兼容跳跃端口）
    # ---------------------------------------------------------------
    local hy2_port server_ip RANGE_PORTS sub_link sub_port

    # 订阅端口 sub.port 不自动修改（严格遵守规则）
    if [[ -f "$sub_port_file" ]]; then
        sub_port=$(cat "$sub_port_file")
    else
        hy2_port=$(jq -r '.inbounds[0].listen_port' "$config_dir")
        sub_port=$((hy2_port + 1))
    fi

    # 获取服务器 IP
    ipv4=$(curl -4 -s https://api.ipify.org)
    ipv6=$(curl -6 -s https://api64.ipify.org)
   [[ -n "$ipv4" ]] && server_ip="$ipv4" || { server_ip="[$ipv6]"; }

    # 检查是否为跳跃端口模式
    RANGE_PORTS=$(parse_range_ports_from_url)

    if [[ -n "$RANGE_PORTS" ]]; then
        sub_link="http://${server_ip}:${RANGE_PORTS}/${new_uuid}"
    else
        sub_link="http://${server_ip}:${sub_port}/${new_uuid}"
    fi

# 写入 sub.txt
cat > "$sub_file" <<EOF
# HY2 主订阅（UUID 已更新）
$sub_link
EOF

    base64 -w0 "$sub_file" > "${work_dir}/sub_base64.txt"

# 写入 sub.json
cat > "${work_dir}/sub.json" <<EOF
{
  "hy2": "$sub_link"
}
EOF

    green "订阅文件已同步更新 UUID"


    # ---------------------------------------------------------------
    # 5. 重启 Sing-box 服务
    # ---------------------------------------------------------------
    restart_singbox

    if systemctl is-active sing-box >/dev/null 2>&1; then
        green "UUID 修改成功：${old_uuid} → ${new_uuid}"
    else
        red "警告：Sing-box 重启失败，请检查 config.json 是否有效"
        yellow "执行：systemctl status sing-box -n 50"
    fi
}



# ======================================================================
# 修改节点名称
# 功能说明：
#   - 修改 url.txt 中的节点名称（#tag 部分）
#   - 自动同步更新 sub.txt / base64 / sub.json
# ======================================================================
change_node_name() {

    read -rp "$(red_input "请输入新的节点名称：")" new_name

    # 保存与编码
    NEW_NAME="$new_name"
    NEW_NAME_ENCODED=$(urlencode "$new_name")

    ensure_url_file
    # ======================================================
    # 1. 修改 url.txt 中的节点标签（仅修改 #tag 而不动 URL 主体）
    # ======================================================
    if [[ -f "$client_dir" ]]; then
        local old_url=$(cat "$client_dir")

        # # 前为 URL 主体；# 后为名称
        local url_body="${old_url%%#*}"

        # 写入新的 encoded 名称
        echo "${url_body}#${NEW_NAME_ENCODED}" > "$client_dir"
        green "url.txt 已同步新的节点名称"
    else
        yellow "未找到 url.txt，跳过 URL 更新"
    fi


    # ======================================================
    # 2. 同步更新订阅文件（sub.txt / base64 / json）
    # ------------------------------------------------------
    #   注意：不更改 sub.port（订阅端口）
    # ======================================================
    local uuid hy2_port server_ip sub_port RANGE_PORTS SUB_LINK

    uuid=$(jq -r '.inbounds[0].users[0].password' "$config_dir")
    hy2_port=$(jq -r '.inbounds[0].listen_port' "$config_dir")

    # 获取服务器公网 IP
    ipv4=$(curl -4 -s https://api.ipify.org)
    ipv6=$(curl -6 -s https://api64.ipify.org)
    [[ -n "$ipv4" ]] && server_ip="$ipv4" || { server_ip="[$ipv6]"; }

    # 订阅端口不应自动修改
    if [[ -f "$sub_port_file" ]]; then
        sub_port=$(cat "$sub_port_file")
    else
        sub_port=$((hy2_port + 1))   # fallback（极少情况）
    fi

    # 检查是否为跳跃端口订阅模式
    RANGE_PORTS=$(parse_range_ports_from_url)

    if [[ -n "$RANGE_PORTS" ]]; then
        SUB_LINK="http://${server_ip}:${RANGE_PORTS}/${uuid}"
    else
        SUB_LINK="http://${server_ip}:${sub_port}/${uuid}"
    fi


# 写入 sub.txt
cat > "$sub_file" <<EOF
# 节点名称：$NEW_NAME
$SUB_LINK
EOF

    # 写入 base64 订阅
    base64 -w0 "$sub_file" > "${work_dir}/sub_base64.txt"

    # 写入 JSON 订阅
cat > "${work_dir}/sub.json" <<EOF
{
  "hy2": "$SUB_LINK"
}
EOF

    green "订阅文件（sub.txt/base64/json）已同步新的节点名称"


    # ======================================================
    # 3. 保持内存中的 NODE_NAME 与新名称一致
    # ======================================================
    NODE_NAME="$NEW_NAME"

    green "节点名称修改完成：$NEW_NAME"
}

# ======================================================================
# 统一的节点输出函数（Hy2 + 订阅 + 二维码）
# 功能说明：
#   - 显示 HY2 原始链接（支持中文节点名）
#   - 自动写入 url.txt（保持一致）
#   - 根据跳跃端口或普通端口生成订阅链接
#   - 输出各类格式（V2rayN、Clash、Singbox、Surge 等）
# ======================================================================
print_node_info_custom() {
    local server_ip="$1"      # 来自 generate_subscription_info()
    local hy2_port="$2"
    local uuid="$3"
    local sub_port="$4"
    local range_ports="$5"

    # ======================================================
    # 1. 生成 mport 参数
    # ======================================================
    if [[ -n "$range_ports" ]]; then
        local minp="${range_ports%-*}"
        local maxp="${range_ports#*-}"
        mport_param="${hy2_port},${minp}-${maxp}"
    else
        mport_param="${hy2_port}"
    fi

    # ======================================================
    # 2. 获取 IPv4 / IPv6
    # ======================================================
    ipv4=$(curl -4 -s https://api.ipify.org)
    ipv6=$(curl -6 -s https://api64.ipify.org)

    local ip4_ok=false
    local ip6_ok=false

    [[ -n "$ipv4" ]] && ip4_ok=true
    [[ -n "$ipv6" ]] && ip6_ok=true

    ipv6_fmt="[$ipv6]"   # IPv6 URL 必须加 []

    # ======================================================
    # 3. 节点名称编码
    # ======================================================
    encoded_name=$(urlencode "$NODE_NAME")
    decoded_name=$(urldecode "$encoded_name")

    # ======================================================
    # 4. 构造 HY2 URL（双模式）
    # ======================================================
    hy2_url_ipv4=""
    hy2_url_ipv6=""

    if $ip4_ok; then
        hy2_url_ipv4="hysteria2://${uuid}@${ipv4}:${hy2_port}/?insecure=1&alpn=h3&obfs=none&mport=${mport_param}#${encoded_name}"
    fi

    if $ip6_ok; then
        hy2_url_ipv6="hysteria2://${uuid}@${ipv6_fmt}:${hy2_port}/?insecure=1&alpn=h3&obfs=none&mport=${mport_param}#${encoded_name}"
    fi

    # ======================================================
    # 5. 写入 url.txt（仍使用 IPv4，保持脚本兼容性）
    # ======================================================
    if $ip4_ok; then
        echo "$hy2_url_ipv4" > "$client_dir"
    else
        echo "$hy2_url_ipv6" > "$client_dir"
    fi

    # ======================================================
    # 6. 输出完整节点信息（包括双 HY2 URL）
    # ======================================================
    purple "\nHY2 原始链接（节点名称：$decoded_name）"

    if $ip4_ok; then
        yellow "===== IPv4 HY2（推荐） ====="
        green "$hy2_url_ipv4"
        generate_qr "$hy2_url_ipv4"
        echo ""
    fi

    if $ip6_ok; then
        yellow "===== IPv6 HY2（备用） ====="
        green "$hy2_url_ipv6"
        generate_qr "$hy2_url_ipv6"
        echo ""
    fi

    yellow "====================================================================="

    # ======================================================
    # 7. 生成订阅 URL（仍然优先用 IPv4）
    # ======================================================
    if $ip4_ok; then
        base_url="http://${ipv4}:${sub_port}/${uuid}"
    else
        base_url="http://${ipv6_fmt}:${sub_port}/${uuid}"
    fi

    purple "订阅链接（V2rayN / Loon / Shadowrocket 等可直接扫描）："
    green "$base_url"
    generate_qr "$base_url"
    yellow "====================================================================="

    # ======================================================
    # 8. Clash / Mihomo / Sing-box / Surge 订阅
    # ======================================================
    clash_url="https://sublink.eooce.com/clash?config=${base_url}"
    singbox_url="https://sublink.eooce.com/singbox?config=${base_url}"
    surge_url="https://sublink.eooce.com/surge?config=${base_url}"

    purple "\nClash / Mihomo 订阅："
    green "$clash_url"
    generate_qr "$clash_url"
    yellow "====================================================================="

    purple "Sing-box 订阅："
    green "$singbox_url"
    generate_qr "$singbox_url"
    yellow "====================================================================="

    purple "Surge 订阅："
    green "$surge_url"
    generate_qr "$surge_url"
    yellow "=====================================================================\n"
}



# ======================================================================
# 生成本地订阅文件（sub.txt / base64 / JSON）
# ======================================================================
generate_all_subscription_files() {
    local base_url="$1"

# 写 sub.txt
cat > "$sub_file" <<EOF
# HY2 主订阅
$base_url
EOF

    # 写 base64
    base64 -w0 "$sub_file" > "${work_dir}/sub_base64.txt"

# 写 JSON
cat > "${work_dir}/sub.json" <<EOF
{
  "hy2": "$base_url"
}
EOF
}



# ======================================================================
# 安装完成后的节点展示（增强版）
# 功能说明：
#   - 自动判断是否为跳跃端口模式
#   - 自动生成订阅文件（三件套）
#   - 使用 print_node_info_custom 输出完整节点信息
# ======================================================================
generate_subscription_info() {

    # 若 NODE_NAME 未设置，则自动生成
    [[ -z "$NODE_NAME" ]] && NODE_NAME=$(get_node_name)

    # ------------------------
    # 获取服务器 IP（优先 IPv4）
    # ------------------------
    ipv4=$(curl -4 -s https://api.ipify.org || true)
    ipv6=$(curl -6 -s https://api64.ipify.org || true)
    [[ -n "$ipv4" ]] && server_ip="$ipv4" || { server_ip="[$ipv6]"; }

    # 获取配置中的主端口与 UUID
    hy2_port=$(jq -r '.inbounds[0].listen_port' "$config_dir")
    uuid=$(jq -r '.inbounds[0].users[0].password' "$config_dir")

    # 保持订阅端口固定
    if [[ -f "$sub_port_file" ]]; then
        sub_port=$(cat "$sub_port_file")
    else
        # fallback，仅首次安装无 sub.port 时触发
        sub_port=$((hy2_port + 1))
    fi

    # ------------------------
    # 使用 url.txt 自动解析跳跃端口
    # ------------------------
    RANGE_PORTS=$(parse_range_ports_from_url)

    base_url="http://${server_ip}:${sub_port}/${uuid}"

    # ------------------------
    # 生成本地订阅文件（sub.txt / base64 / json）
    # ------------------------
    generate_all_subscription_files "$base_url"

    clear 
    # ------------------------
    # 输出完整节点信息
    # ------------------------
    print_node_info_custom "$server_ip" "$hy2_port" "$uuid" "$sub_port" "$RANGE_PORTS"
}
# ======================================================================
# Nginx 订阅服务（增强版）
# 功能说明：
#   - 用 sub.port 决定订阅端口（首次安装后不自动修改）
#   - 自动修复 Nginx 配置
#   - 为订阅生成独立访问端点
# ======================================================================
add_nginx_conf() {

    if ! command_exists nginx; then
        red "未安装 Nginx，跳过订阅服务配置"
        return
    fi

    mkdir -p /etc/nginx/conf.d

    # -------------------------
    # 获取订阅端口（只在首次生成）
    # -------------------------
    if [[ -f "$sub_port_file" ]]; then
        nginx_port=$(cat "$sub_port_file")
    else
        nginx_port=$((hy2_port + 1))

        # 若被占用，则寻找下一个可用端口
        if is_port_occupied "$nginx_port"; then
            for p in $(seq $((nginx_port + 1)) 65000); do
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

    # -------------------------
    # 确保 nginx.conf 包含 conf.d/*.conf
    # -------------------------
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
# 修改nginx订阅端口
# ======================================================================
change_subscribe_port() {

    # 1. 输入端口
    read -rp "$(red "请输入新的订阅端口：")" new_port

    # 2. 校验端口格式
    if ! is_valid_port "$new_port"; then
        red "端口无效"
        return
    fi
    if is_port_occupied "$new_port"; then
        red "端口已被占用"
        return
    fi

    # 3. 更新 sub.port 文件
    echo "$new_port" > "$sub_port_file"
    green "订阅端口已修改为：$new_port"

    # 4. 获取必要信息
    uuid=$(jq -r '.inbounds[0].users[0].password' "$config_dir")

    ipv4=$(curl -4 -s https://api.ipify.org)
    ipv6=$(curl -6 -s https://api64.ipify.org)
   [[ -n "$ipv4" ]] && server_ip="$ipv4" || { server_ip="[$ipv6]"; }

    # 5. 生成新的订阅 URL（注意：不受跳跃端口影响）
    sub_url="http://${server_ip}:${new_port}/${uuid}"

    # 6. 写入订阅文件
cat > "$sub_file" <<EOF
# HY2 主订阅（订阅端口已手动修改）
$sub_url
EOF

    base64 -w0 "$sub_file" > "${work_dir}/sub_base64.txt"

cat > "${work_dir}/sub.json" <<EOF
{
  "hy2": "$sub_url"
}
EOF

    # 7. 同步更新 Nginx 配置（必须保留 uuid 路径）
cat > /etc/nginx/conf.d/singbox_sub.conf <<EOF
server {
    listen $new_port;
    listen [::]:$new_port;

    server_name sb_sub.local;

    location /$uuid {
        alias $sub_file;
        default_type text/plain;
    }

    location / {
        return 404;
    }
}
EOF

    # 8. 重启 Nginx
    if nginx -t >/dev/null 2>&1; then
        systemctl restart nginx
        green "订阅系统（Nginx + 订阅文件）已同步到新端口：$new_port"
    else
        red "Nginx 配置测试失败，请检查 /etc/nginx/conf.d/singbox_sub.conf"
    fi
}



# ======================================================================
# 订阅服务管理菜单（遵循你的新菜单规范 + 完整注释）
# ======================================================================
disable_open_sub() {
    while true; do
        clear
        blue  "========== 管理订阅服务（Nginx） =========="
        echo ""
        green " 1. 关闭nginx"
        green " 2. 启动nginx"
        green " 3. 修改nginx订阅端口（手动操作）"
        green " 4. 重启订阅服务（Nginx）"
        yellow "---------------------------------------------"
        green  " 0. 返回主菜单"
        red    "88. 退出脚本"
        echo ""

        local sel
        read -rp "请选择操作：" sel

        case "$sel" in

            1)
                systemctl stop nginx
                green "nginx服务已关闭"
                ;;

            2)
                systemctl start nginx
                if systemctl is-active nginx >/dev/null; then
                    green "nginx服务已启动"
                else
                    red "nginx服务启动失败"
                fi
                ;;

            3)
                change_subscribe_port
                ;;

            4)
                systemctl restart nginx
                if systemctl is-active nginx >/dev/null 2>&1; then
                    green "Nginx已重启成功"
                else
                    red "Nginx服务重启失败，请检查 Nginx 配置"
                fi
                ;;

            0)
                return      # 回主菜单
                ;;

            88)
                exit 0      # 退出脚本
                ;;

            *)
                red "无效输入，请重新选择"
                ;;
        esac

        
    done
}


# ======================================================================
# handle_range_ports（增强版）
# 功能说明：
#   - 用于在安装过程中自动处理 RANGE_PORTS 环境变量
#   - 如果用户通过自动安装指定了 RANGE_PORTS，则在安装结束后自动生效
#   - 手动模式不会触发本函数（符合你的设计）
#   - ⚠ 不修改 sub.port（遵守你的规则）
# ======================================================================
handle_range_ports() {

    # 若未指定 RANGE_PORTS，则不处理
    [[ -z "$RANGE_PORTS" ]] && return

    # 格式检查
    if ! is_valid_range "$RANGE_PORTS"; then
        err "跳跃端口格式无效（正确示例：1-65535"
        return
    fi

    # 提取起始与结束端口
    local min="${RANGE_PORTS%-*}"
    local max="${RANGE_PORTS#*-}"

    green "自动模式检测到跳跃端口区间：${min}-${max}"
    configure_port_jump "$min" "$max"
}


# ======================================================================
# 自动安装流程（用于环境变量触发）
# ======================================================================
start_service_after_finish_sb() {

    sleep 1
    systemctl daemon-reload
    systemctl enable sing-box
    systemctl restart sing-box

    # 如果安装时用户设置了 RANGE_PORTS，则应用跳跃端口 NAT
    handle_range_ports

    # 输出节点完整信息
    generate_subscription_info

    # 启动 Nginx 订阅服务
    add_nginx_conf
}


# ======================================================================
# 自动安装入口（外部传入变量触发）
# ======================================================================
quick_install() {
    purple "检测到环境变量 → 启动自动安装模式..."

    install_common_packages
    install_singbox
    start_service_after_finish_sb

    green "自动安装完成！"
    sleep 10
    check_nodes
    green "节点信息已全部显示。"
}
# ======================================================================
# Sing-box 服务管理菜单
# ======================================================================
manage_singbox() {
    while true; do
        clear
        blue  "========== Sing-box 服务管理 =========="
        echo ""
        green " 1. 启动 Sing-box"
        green " 2. 停止 Sing-box"
        green " 3. 重启 Sing-box"
        yellow "----------------------------------------"
        green  " 0. 返回主菜单"
        red    "88. 退出脚本"
        echo ""

        local sel
        read -rp "请选择操作：" sel

        case "$sel" in
            1) start_singbox; green "Sing-box 已启动";;
            2) stop_singbox;  yellow "Sing-box 已停止";;
            3) restart_singbox; green "Sing-box 已重启";;

            0) return ;;   # 返回主菜单
            88) exit_script ;;  # 退出脚本

            *) red "无效输入，请重新选择" ;;
        esac

     
    done
}



# ======================================================================
# 查看节点信息（支持跳跃端口）
# ======================================================================
check_nodes() {
   #  clear  #todo
    blue "=================== 查看节点信息 ==================="

    [[ ! -f "$config_dir" ]] && { red "未找到配置文件"; return; }

    hy2_port=$(jq -r '.inbounds[0].listen_port' "$config_dir")
    uuid=$(jq -r '.inbounds[0].users[0].password' "$config_dir")

    # 获取服务器 IP
    ipv4=$(curl -4 -s https://api.ipify.org)
    ipv6=$(curl -6 -s https://api64.ipify.org)
    [[ -n "$ipv4" ]] && server_ip="$ipv4" || { server_ip="[$ipv6]"; }

    # 是否启用跳跃端口？
    RANGE_PORTS=$(parse_range_ports_from_url)

    # 获取订阅端口（不自动修改）
    if [[ -f "$sub_port_file" ]]; then
        sub_port=$(cat "$sub_port_file")
    else
        sub_port=$((hy2_port + 1))
    fi

    # 显示 HY2 URL
    if [[ -f "$client_dir" ]]; then
        hy2_url=$(cat "$client_dir")
    else
        hy2_url="(未找到 url.txt，请重新安装或生成)"
    fi

    purple "\n当前 HY2 URL："
    green "$hy2_url"
    echo ""

    # 使用统一输出函数
    print_node_info_custom "$server_ip" "$hy2_port" "$uuid" "$sub_port" "$RANGE_PORTS"
}


# ======================================================================
# Sing-box 服务控制模块（增强修复版）
# ======================================================================

# ======================================================================
# 重启 Sing-box 
# ======================================================================
restart_singbox() {

    if command -v systemctl &>/dev/null; then
        systemctl restart sing-box

        if systemctl is-active sing-box >/dev/null 2>&1; then
            green "Sing-box 服务已重启"
        else
            red "Sing-box 服务重启失败"
        fi
        return
    fi

    if command -v rc-service &>/dev/null; then
        rc-service sing-box restart
        green "Sing-box 已通过 rc-service 重启"
        return
    fi

    red "无法重启 Sing-box（未知系统服务类型）"
}


# ======================================================================
# 启动 Sing-box 
# ======================================================================
start_singbox() {

    if command -v systemctl &>/dev/null; then
        systemctl start sing-box

        if systemctl is-active sing-box >/dev/null 2>&1; then
            green "Sing-box 服务已启动"
        else
            red "Sing-box 服务启动失败"
        fi
        return
    fi

    if command -v rc-service &>/dev/null; then
        rc-service sing-box start
        green "Sing-box 已通过 rc-service 启动"
        return
    fi

    red "无法启动 Sing-box（未知系统服务类型）"
}



# ======================================================================
# 停止 Sing-box 
# ======================================================================
stop_singbox() {

    if command -v systemctl &>/dev/null; then
        systemctl stop sing-box

        if systemctl is-active sing-box >/dev/null 2>&1; then
            red "Sing-box 停止失败（服务仍在运行）"
        else
            yellow "Sing-box 服务已停止"
        fi
        return
    fi

    if command -v rc-service &>/dev/null; then
        rc-service sing-box stop
        yellow "Sing-box 已通过 rc-service 停止"
        return
    fi

    red "无法停止 Sing-box（未知系统服务类型）"
}


# ======================================================================
# 安装 Sing-box
# 说明：
#   - 自动与手动模式都支持（基于是否传入环境变量）
#   - 自动创建目录 / 证书 / config.json
#   -这里面的配置仅仅兼容 Sing-box ≥ 1.12 的 DNS 格式
# ======================================================================
install_singbox() {
    clear
    purple "准备下载并安装 Sing-box..."

    mkdir -p "$work_dir"

    # -------------------- 检测 CPU 架构 --------------------
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

    # --------------------
    # 判断模式（自动 or 交互）
    # --------------------
    is_interactive_mode
    if [[ $? -eq 1 ]]; then
        not_interactive=1
        white "当前模式：自动模式"
        PORT=$(get_port "$PORT")
        UUID=$(get_uuid "$UUID")
    else
        not_interactive=0
        white "当前模式：交互模式"

        while true; do
            read -rp "$(red_input "请输入 HY2 主端口：")" USER_PORT
            if is_valid_port "$USER_PORT" && ! is_port_occupied "$USER_PORT"; then
                PORT="$USER_PORT"
                break
            else
                red "端口无效或已被占用，请重新输入"
            fi
        done

        while true; do
            read -rp "$(red_input "请输入 UUID（回车自动生成随机 UUID）")" USER_UUID
           # 用户直接按回车 → 自动生成真正随机 UUID
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

    HY2_PASSWORD="$UUID"
    hy2_port="$PORT"

    allow_port "$hy2_port" udp

    # ==================================================================
    # 自动探测 DNS 设置（已完全兼容新版 Sing-box）
    # ==================================================================
    ipv4_ok=false
    ipv6_ok=false
    ping -4 -c1 -W1 8.8.8.8 >/dev/null 2>&1 && ipv4_ok=true
    ping -6 -c1 -W1 2001:4860:4860::8888 >/dev/null 2>&1 && ipv6_ok=true

    dns_servers_json=""
    if $ipv4_ok && $ipv6_ok; then
        dns_servers_json='
      {
        "tag": "dns-google-ipv4",
        "address": "8.8.8.8"
      },
      {
        "tag": "dns-google-ipv6",
        "address": "2001:4860:4860::8888"
      }'
    elif $ipv4_ok; then
        dns_servers_json='
      {
        "tag": "dns-google-ipv4",
        "address": "8.8.8.8"
      }'
    else
        dns_servers_json='
      {
        "tag": "dns-google-ipv6",
        "address": "2001:4860:4860::8888"
      }'
    fi

    if $ipv4_ok; then
        dns_strategy="prefer_ipv4"
    else
        dns_strategy="prefer_ipv6"
    fi

    # ==================================================================
    # 生成 TLS 密钥与证书
    # ==================================================================
    openssl ecparam -genkey -name prime256v1 -out "${work_dir}/private.key"
    openssl req -x509 -new -nodes \
        -key "${work_dir}/private.key" \
        -sha256 -days 3650 \
        -subj "/C=US/ST=CA/O=bing.com/CN=bing.com" \
        -out "${work_dir}/cert.pem"

    # ==================================================================
    # 生成最终合法 JSON（不会报 jq 错误）
    # ==================================================================
cat > "$config_dir" <<EOF
{
  "log": {
    "level": "error",
    "output": "$work_dir/sb.log"
  },

  "dns": {
    "servers": [
$dns_servers_json
    ],
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
# 卸载 Sing-box + 清理订阅系统
# ======================================================================
uninstall_singbox() {

    clear
    blue "============== 卸载 Sing-box（增强版） =============="
    echo ""
    read -rp "确认卸载 Sing-box？ [Y/n]（默认 Y）：" u
    u=${u:-y}

    if [[ ! "$u" =~ ^[Yy]$ ]]; then
        yellow "已取消卸载操作"
        return
    fi

    # -------------------------
    # 1. 停止服务并删除 systemd 配置
    # -------------------------
    stop_singbox
    systemctl disable sing-box >/dev/null 2>&1
    rm -f /etc/systemd/system/sing-box.service
    systemctl daemon-reload

    # -------------------------
    # 2. 删除 Sing-box 运行目录
    # -------------------------
    rm -rf /etc/sing-box
    green "Sing-box 主程序与配置目录已删除"

    # -------------------------
    # 3. 删除订阅服务配置（Nginx）
    # -------------------------
    if [[ -f /etc/nginx/conf.d/singbox_sub.conf ]]; then
        rm -f /etc/nginx/conf.d/singbox_sub.conf
        green "订阅服务配置已删除"
    fi

    # -------------------------
    # 4. 询问是否卸载 Nginx（可选）
    # -------------------------
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
            yellow "保留 Nginx（如需手动管理订阅服务，可继续使用）"
            systemctl restart nginx >/dev/null 2>&1
        fi
    fi

    echo ""
    green "卸载完成！"
}


# ======================================================================
# 修改节点配置菜单（增强版 + 修复变量污染 + 统一退出规则）
# ======================================================================
change_config() {
    while true; do
        clear
        blue  "========== 修改节点配置（增强版） =========="
        echo ""
        green " 1. 修改 HY2 主端口"
        green " 2. 修改 UUID（密码）"
        green " 3. 修改节点名称"
        green " 4. 添加跳跃端口"
        green " 5. 删除跳跃端口"
        yellow "-------------------------------------------"
        green  " 0. 返回主菜单"
        red    "88. 退出脚本"
        echo ""

        local sel
        read -rp "请选择操作：" sel

        case "$sel" in
            1) change_hy2_port ;;
            2) change_uuid ;;
            3) change_node_name ;;
            4)
                read -rp "$(red_input "请输入跳跃端口起始值：")" jmin
                read -rp "$(red_input "请输入跳跃端口结束值：")" jmax

                if ! is_valid_range "${jmin}-${jmax}"; then
                    red "格式无效（必须为 1-65535 这种格式）"
                else
                    configure_port_jump "$jmin" "$jmax"
                fi
                ;;
            5) delete_jump_rule ;;

            0) return ;;    # 返回主菜单
            88) exit_script ;;   # 退出脚本

            *) red "无效输入，请重新选择" ;;
        esac


    done
}



# ======================================================================
# 主菜单（保持你的原风格 + 无需改变）
# ======================================================================
menu() {
    clear
    blue "===================================================="
    gradient "       Sing-box 一键脚本（Hy2整合增强版）"
    green    "       作者：$AUTHOR"
    yellow   "       版本：$VERSION"
    blue "===================================================="
    echo ""

    # 状态检测
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
    red    " 88. 退出脚本"
    echo ""

    read -rp "请输入选项：" choice
}



# ======================================================================
# 主循环（核心控制逻辑，保持你的原结构，但修复子菜单错乱问题）
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
            88) exit_script ;;   # 主菜单退出

            *) red "无效选项，请重新输入" ;;
        esac

    done
}


exit_script() {
    green "感谢使用本脚本, 再见👋"
    exit 0
}


# ======================================================================
# 入口函数（自动模式/交互模式）
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

main   # 启动脚本
