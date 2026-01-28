#!/bin/bash

SCRIPT_VERSION="1.0.1(2026-01-10)"
SCRIPT_AUTHOR="LittleDoraemon"

# 颜色定义
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[36m'
PLAIN='\033[0m'

white(){ echo -e "\033[1;37m$1\033[0m"; }
red(){ echo -e "\e[1;91m$1\033[0m"; }
green(){ echo -e "\e[1;32m$1\033[0m"; }
yellow(){ echo -e "\e[1;33m$1\033[0m"; }
blue(){ echo -e "\e[1;34m$1\033[0m"; }
purple(){ echo -e "\e[1;35m$1\033[0m"; }
err(){ red "[错误] $1" >&2; }


# Set environment variables (these will be used in both installation functions)
export DOMAIN="${DOMAIN:-www.apple.com}"
export PORT="${PORT:-}"
export PORT_V6="${PORT_V6:-}"
export SECRET="${SECRET:-}"
export IP_MODE="${IP_MODE:-v4}"

export INSTALL_MODE="${INSTALL_MODE:-go}"
export DEBUG_FLAG=${DEBUG_FLAG:-'0'}; 
DEFAULT_DOMAIN="www.microsoft.com"

INTERACTIVE_FLAG=1

v46url="https://icanhazip.com"

has_systemd() {
  command -v systemctl >/dev/null 2>&1 || return 1
  [ -d /run/systemd/system ] || return 1
  # 可选：更严格，确保 PID1 就是 systemd（不想太严格可删掉这一行）
  [ "$(ps -p 1 -o comm= 2>/dev/null | tr -d '[:space:]')" = "systemd" ] || return 1
  return 0
}

debug_log() {
  [ "${DEBUG_FLAG:-0}" = "1" ] && echo -e "$*" >&2
}


# 全局输出变量：
# - SUGGESTED_PORTS: "30001 30002 30003"（空则表示没找到列表，只有随机推荐）
# - SUGGESTED_RADIUS: 5 / 20 / random / invalid
# - SUGGESTED_RANDOM: 随机推荐端口（仅当找不到附近可用端口时）
SUGGESTED_PORTS=""
SUGGESTED_RADIUS=""
SUGGESTED_RANDOM=""

install_mode_init(){
    if [[ "$INSTALL_MODE" != "go" && "$INSTALL_MODE" != "py" ]]; then
        echo -e "${YELLOW}无效的安装模式: $INSTALL_MODE。默认使用 'go' 模式.${PLAIN}"
        INSTALL_MODE="go"
    fi
}


# 全局配置
WORKDIR="/opt/mtproxy"
CONFIG_DIR="$WORKDIR/config"
LOG_DIR="$WORKDIR/logs"
BIN_DIR="$WORKDIR/bin"

# 获取脚本绝对路径
SCRIPT_PATH=$(readlink -f "$0" 2>/dev/null)
if [ -z "$SCRIPT_PATH" ]; then
    SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
fi
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"


# 系统检测
OS=""
PACKAGE_MANAGER=""
INIT_SYSTEM=""




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


# 在给定半径内搜集可用端口（最多返回 max_count 个）
collect_free_ports() {
    local base="$1"
    local radius="$2"
    local max_count="${3:-5}"
    local start=$((base - radius))
    local end=$((base + radius))
    local found=()

    (( start < 1 )) && start=1
    (( end > 65535 )) && end=65535

    # 从近到远：base-1, base+1, base-2, base+2 ...
    local d
    for ((d=1; d<=radius; d++)); do
        local p1=$((base - d))
        local p2=$((base + d))

        if (( p1 >= start )) && ! is_port_occupied "$p1"; then
            found+=("$p1")
            (( ${#found[@]} >= max_count )) && break
        fi
        if (( p2 <= end )) && ! is_port_occupied "$p2"; then
            found+=("$p2")
            (( ${#found[@]} >= max_count )) && break
        fi
    done

    if (( ${#found[@]} > 0 )); then
        echo "${found[*]}"
        return 0
    fi
    return 1
}

# 按多个 radius 依次尝试，返回："<命中的radius>|<端口列表>"
# 用途： 从参数2的数组中依次尝试，返回第一个命中的端口列表，这个列表里面最多返回 参数3 也就是max_count 个值
suggest_ports() {
    local base="$1"
    local radii="$2"          # 例如: "5 20"
    local max_count="${3:-5}"
    local r ports

    for r in $radii; do
        ports="$(collect_free_ports "$base" "$r" "$max_count")" && {
            echo "${r}|${ports}"
            return 0
        }
    done
    return 1
}





check_sys() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    fi

    if [ -f /etc/alpine-release ]; then
        OS="alpine"
        PACKAGE_MANAGER="apk"
        INIT_SYSTEM="openrc"
    elif [[ "$OS" == "debian" || "$OS" == "ubuntu" ]]; then
        PACKAGE_MANAGER="apt"
        INIT_SYSTEM="systemd"
    elif [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
        if command -v dnf >/dev/null 2>&1; then
            PACKAGE_MANAGER="dnf"
        else
            PACKAGE_MANAGER="yum"
        fi
        INIT_SYSTEM="systemd"
    else
        echo -e "${RED}不支持的系统: $OS${PLAIN}"
        exit 1
    fi

    # Fallback if OS is not detected
    if [ -z "$OS" ]; then
        echo -e "${RED}无法检测操作系统，请检查是否为标准Linux发行版.${PLAIN}"
        exit 1
    fi
}


install_base_deps() {
    echo -e "${BLUE}正在安装基础依赖...${PLAIN}"

    # List of required dependencies
    REQUIRED_DEPS=("curl" "wget" "tar" "ca-certificates" "openssl" "bash")

    # Temporary array to store missing dependencies
    MISSING_DEPS=()

    # Check and install dependencies
    for dep in "${REQUIRED_DEPS[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            MISSING_DEPS+=("$dep")  # Add missing dependency to the array
            echo -e "${YELLOW}$dep 没有安装，正在安装...${PLAIN}"
            # Install using appropriate package manager
            if [[ "$PACKAGE_MANAGER" == "apk" ]]; then
                apk add --no-cache "$dep"
            elif [[ "$PACKAGE_MANAGER" == "apt" ]]; then
                apt-get install -y "$dep"
            elif [[ "$PACKAGE_MANAGER" == "yum" ]]; then
                yum install -y "$dep"
            fi
        else
            echo -e "${GREEN}$dep 已经安装，跳过安装.${PLAIN}"
        fi
    done

    # Debug log for missing dependencies
    if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
        debug_log "【调试】 未安装的依赖: ${MISSING_DEPS[*]}"
    fi

    # Debug log for systemd and OpenRC compatibility
    if [[ "$INIT_SYSTEM" == "systemd" ]]; then
        debug_log "【调试】 系统检测：systemd 初始化系统"
    elif [[ "$INIT_SYSTEM" == "openrc" ]]; then
        debug_log "【调试】 系统检测：OpenRC 初始化系统"
    else
        debug_log "【调试】 系统检测：未知的初始化系统"
    fi
}


get_public_ip() {
    # 超时2秒，重试2次
    timeout=2        # 超时时间2秒
    retries=2        # 重试次数2次

    start_time=$(date +%s)  # Start timing
    IPV4=$(curl -s4 --max-time $timeout --retry $retries -A Mozilla https://api.ip.sb/ip || curl -s4 --max-time $timeout --retry $retries -A Mozilla https://ipinfo.io/ip)
    end_time=$(date +%s)    # End timing
    elapsed_time=$((end_time - start_time))
    debug_log "获取IPv4地址花费时间: $elapsed_time 秒"
    
    echo "$IPV4"  # Return the IP address
}

get_public_ipv6() {
    # 超时2秒，重试2次
    timeout=2        # 超时时间2秒
    retries=2        # 重试次数2次

    start_time=$(date +%s)  # Start timing
    IPV6=$(curl -s6 --max-time $timeout --retry $retries -A Mozilla https://api.ip.sb/ip || curl -s6 --max-time $timeout --retry $retries -A Mozilla https://ipinfo.io/ip)
    end_time=$(date +%s)    # End timing
    elapsed_time=$((end_time - start_time))
    debug_log "获取IPv6地址花费时间: $elapsed_time 秒"
    
    echo "$IPV6"  # Return the IP address
}


get_public_ipv6() {
        # 超时2秒，重试2次
    timeout=2        # 超时时间2秒
    retries=2        # 重试次数2次

    # 使用 curl 命令获取 IP，增加重试和超时设置
    #curl -s6 --max-time $timeout --retry $retries -A Mozilla https://api.ip.sb/ip || curl -s6 --max-time $timeout --retry $retries -A Mozilla https://ipinfo.io/ip
    
      # 超时2秒，重试2次
    timeout=2        # 超时时间2秒
    retries=2        # 重试次数2次

    start_time=$(date +%s)  # Start timing
    IPV6=$(curl -s6 --max-time $timeout --retry $retries -A Mozilla https://api.ip.sb/ip || curl -s6 --max-time $timeout --retry $retries -A Mozilla https://ipinfo.io/ip)
    end_time=$(date +%s)    # End timing
    elapsed_time=$((end_time - start_time))
    debug_log "获取IPv6地址花费时间: $elapsed_time 秒"
    
    echo "$IPV6"  # Return the IP address

}

generate_secret() {
    head -c 32 /dev/urandom | od -A n -t x1 | tr -d ' \n'
}


# FULL_SECRET = ee + SECRET_HEX(64) + DOMAIN_HEX
# 返回：DOMAIN 明文；解析失败返回 "(解析失败)"
decode_domain_from_full_secret() {
    local full="$1"
    full="${full#ee}"               # 去掉 ee
    local secret_hex_len=64         # 你这里固定是 32 bytes => 64 hex chars:contentReference[oaicite:1]{index=1}

    local domain_hex="${full:$secret_hex_len}"

    # 校验：必须是偶数长度且全是 hex
    if [[ -z "$domain_hex" || $((${#domain_hex} % 2)) -ne 0 || ! "$domain_hex" =~ ^[0-9a-fA-F]+$ ]]; then
        echo "(解析失败)"
        return 1
    fi

    if command -v xxd >/dev/null 2>&1; then
        printf '%s' "$domain_hex" | xxd -r -p 2>/dev/null || echo "(解析失败)"
    else
        printf '%b' "$(printf '%s' "$domain_hex" | sed 's/../\\x&/g')" 2>/dev/null || echo "(解析失败)"
    fi
}

# 返回：BASE_SECRET（不带 ee，不带 domain 的那段 hex）
decode_base_secret_from_full_secret() {
    local full="$1"
    full="${full#ee}"               # 去掉 ee
    local secret_hex_len=64         # 你这里固定是 32 bytes => 64 hex chars:contentReference[oaicite:2]{index=2}
    echo "${full:0:$secret_hex_len}"
}



# --- IP 模式选择 ---
select_ip_mode() {
    echo -e "请选择监听模式:" >&2
    echo -e "1. ${GREEN}IPv4 仅${PLAIN} (默认，高稳定性)" >&2
    echo -e "2. ${YELLOW}IPv6 仅${PLAIN}" >&2
    echo -e "3. ${BLUE}双栈模式 (IPv4 + IPv6)${PLAIN}" >&2
    read -p "请选择 [1-3] (默认 1): " mode
    case $mode in
        2) echo "v6" ;;
        3) echo "dual" ;;
        *) echo "v4" ;;
    esac
}

 inputs_noninteractive() {
     # 非交互：只用环境变量 + 自动生成，不要任何 read
     # DOMAIN 为空，直接用 DEFAULT_DOMAIN作为默认值
     DOMAIN="${DOMAIN:-$DEFAULT_DOMAIN}"
     IP_MODE="${IP_MODE:-v4}"
 
     # 端口兜底：注意这里才给默认值，不要在文件顶部 export PORT=443
     PORT="${PORT:-443}"
 

    # 调用新的端口检查函数，避免直接退出
    check_port_or_suggest_noninteractive "$PORT"
    if [[ "$IP_MODE" == "dual" && -n "$PORT_V6" && "$PORT_V6" != "$PORT" ]]; then
        check_port_or_suggest_noninteractive "$PORT_V6"
    fi
 
     SECRET="${SECRET:-$(generate_secret)}"
 }



inputs_interactive() {
    # 交互：所有 read / 选择都在这里
    read -p "$(yellow "请输入伪装域名 (默认: ${DOMAIN:-$DEFAULT_DOMAIN}): ")" tmp
    DOMAIN="${DOMAIN:-$DEFAULT_DOMAIN}"

    IP_MODE="$(select_ip_mode)"

    if [[ "$IP_MODE" == "dual" ]]; then
        read -p "$(yellow "请输入 IPv4 端口 (默认: ${PORT:-443}): ")" tmp
        PORT="${tmp:-${PORT:-443}}"

        read -p "$(yellow "请输入 IPv6 端口 (默认: ${PORT_V6:-$PORT}): ")" tmp
        PORT_V6="${tmp:-${PORT_V6:-$PORT}}"
    else
        read -p "$(yellow "请输入端口 (默认: ${PORT:-443}): ")" tmp
        PORT="${tmp:-${PORT:-443}}"
        PORT_V6=""
    fi

    # 交互模式也允许用户预先 export SECRET，不填就自动生成
    if [[ -z "$SECRET" ]]; then
        SECRET="$(generate_secret)"
    fi
    echo -e "${GREEN}生成的密钥: $SECRET${PLAIN}"
}





check_port_or_prompt_interactive() {
    local port="$1"

    # 每次调用先清空
    SUGGESTED_PORTS=""
    SUGGESTED_RADIUS=""
    SUGGESTED_RANDOM=""

    # 非法端口：当成不可用，返回 1，并给个随机建议
    if ! [[ "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
        SUGGESTED_RADIUS="invalid"
        # 给一个随机端口建议
        local rnd tries=0
        while (( tries < 200 )); do
            rnd=$(( 20000 + (RANDOM % 40001) ))  # 20000-60000
            if ! is_port_occupied "$rnd"; then
                SUGGESTED_RANDOM="$rnd"
                break
            fi
            ((tries++))
        done
        [[ -z "$SUGGESTED_RANDOM" ]] && SUGGESTED_RANDOM="54321"
        return 1
    fi

    # 未占用 => OK
    if ! is_port_occupied "$port"; then
        return 0
    fi

    # 占用 => 生成推荐
    local res radius ports
    if res="$(suggest_ports "$port" "5 20" 5)"; then
        radius="${res%%|*}"
        ports="${res#*|}"
        SUGGESTED_RADIUS="$radius"
        SUGGESTED_PORTS="$ports"
        return 1
    fi

    # 附近没找到 => 随机推荐一个未占用端口
    SUGGESTED_RADIUS="random"
    local rnd tries=0
    while (( tries < 200 )); do
        rnd=$(( 20000 + (RANDOM % 40001) ))
        if ! is_port_occupied "$rnd"; then
            SUGGESTED_RANDOM="$rnd"
            break
        fi
        ((tries++))
    done
    [[ -z "$SUGGESTED_RANDOM" ]] && SUGGESTED_RANDOM="54321"
    return 1
}

download_file() {
    local url=$1
    local target_file=$2
    local retries=3
    local count=0

    while (( count < retries )); do
        echo -e "${BLUE}尝试下载文件: $url...${PLAIN}"
        wget -O "$target_file" "$url"

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}下载成功！${PLAIN}"
            return 0
        fi

        ((count++))
        echo -e "${RED}下载失败，重试 ${count}/${retries}...${PLAIN}"
        sleep 2  # Wait before retrying
    done

    debug_log "【调试】 下载文件失败，已尝试 $retries 次。请检查网络或文件路径。"
    echo -e "${RED}下载失败，已尝试 $retries 次。请检查网络或文件路径。${PLAIN}"
    return 1
}

# --- Python 版安装逻辑 ---
install_mtp_python() {
    echo -e "${BLUE}正在准备安装 Python 版...${PLAIN}"
    
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) P_ARCH="amd64" ;;
        aarch64) P_ARCH="arm64" ;;
        armv7l) P_ARCH="armv6l" ;;
        *) P_ARCH="$ARCH" ;;
    esac
    
    TARGET_OS="debian"
    [[ "$OS" == "alpine" ]] && TARGET_OS="alpine"
    
    TARGET_BIN="mtp-python-${TARGET_OS}-${P_ARCH}"
    mkdir -p "$BIN_DIR"
    
    FOUND_PATH=""
    if [ -f "./${TARGET_BIN}" ]; then
        FOUND_PATH="./${TARGET_BIN}"
    elif [ -f "${SCRIPT_DIR}/${TARGET_BIN}" ]; then
        FOUND_PATH="${SCRIPT_DIR}/${TARGET_BIN}"
    fi

    control_service stop mtp-python

    if [ -n "$FOUND_PATH" ]; then
        echo -e "${GREEN}检测到本地二进制文件: ${FOUND_PATH}${PLAIN}"
        cp "${FOUND_PATH}" "$BIN_DIR/mtp-python"
    else
        DOWNLOAD_URL="https://github.com/jyucoeng/singbox-tools/releases/download/mtproxy/${TARGET_BIN}"
        download_file "$DOWNLOAD_URL" "$BIN_DIR/mtp-python" || exit 1
    fi

    chmod +x "$BIN_DIR/mtp-python"
    
    # Generate config.py file with the selected values
    mkdir -p "$CONFIG_DIR"
    IPV4_CFG="\"0.0.0.0\""
    IPV6_CFG="None"
    if [[ "$IP_MODE" == "v6" ]]; then
        IPV4_CFG="None"
        IPV6_CFG="\"::\""
    elif [[ "$IP_MODE" == "dual" ]]; then
        IPV4_CFG="\"0.0.0.0\""
        IPV6_CFG="\"::\""
    fi

    # Create the config.py file
    cat > "$CONFIG_DIR/config.py" <<EOF
PORT = $PORT
USERS = {
    "tg": "$SECRET"
}
MODES = {
    "classic": False,
    "secure": False,
    "tls": True
}
TLS_DOMAIN = "$DOMAIN"
LISTEN_ADDR_IPV4 = $IPV4_CFG
LISTEN_ADDR_IPV6 = $IPV6_CFG
EOF

    if [ -n "$PORT_V6" ]; then
        echo "PORT_IPV6 = $PORT_V6" >> "$CONFIG_DIR/config.py"
    fi

    # If ad tag is provided, add it to the config
    if [ -n "$ADTAG" ]; then
        echo "AD_TAG = \"$ADTAG\"" >> "$CONFIG_DIR/config.py"
    fi

    # Proceed with the installation using the variables
    create_service_python 1
    check_service_status mtp-python
    debug_log "【调试】 show_info_python函数开始打印节点信息……"
    yellow "准备打印节点信息，请稍候……"
    show_info_python "$PORT" "$SECRET" "$DOMAIN" "$IP_MODE" "$PORT_V6"
}

# --- Go 版安装逻辑 ---
install_mtp_go() {
    # Use environment variables for domain, port, and other settings
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) MTG_ARCH="amd64" ;;
        aarch64) MTG_ARCH="arm64" ;;
        *) echo "不支持的架构: $ARCH"; exit 1 ;;
    esac

    debug_log "【调试】 install_mtp_go 架构为: $MTG_ARCH"
    
    mkdir -p "$BIN_DIR"
    TARGET_NAME="mtg-go-${MTG_ARCH}"
    FOUND_PATH=""
    
    if [ -f "./${TARGET_NAME}" ]; then
        FOUND_PATH="./${TARGET_NAME}"
    elif [ -f "${SCRIPT_DIR}/${TARGET_NAME}" ]; then
        FOUND_PATH="${SCRIPT_DIR}/${TARGET_NAME}"
    fi

    debug_log "【调试】 FOUND_PATH 为: $FOUND_PATH"

    debug_log "【调试】 准备下载或使用本地的 mtg-go 二进制文件"

    control_service stop mtg

    if [ -n "$FOUND_PATH" ]; then
        echo -e "${GREEN}检测到本地二进制文件: ${FOUND_PATH}${PLAIN}"
        cp "${FOUND_PATH}" "$BIN_DIR/mtg-go"
    else
        DOWNLOAD_URL="https://github.com/jyucoeng/singbox-tools/releases/download/mtproxy/${TARGET_NAME}"
        download_file "$DOWNLOAD_URL" "$BIN_DIR/mtg-go" || exit 1
    fi
    chmod +x "$BIN_DIR/mtg-go"

    debug_log "【调试】 准备创建服务 (Go)"
    # Proceed with the installation using the variables
    create_service_mtg "$PORT" "$SECRET" "$DOMAIN" "$IP_MODE" "$PORT_V6"

    debug_log "【调试】 准备检查服务状态 (Go)"
    check_service_status mtg
    debug_log "【调试】 show_info_mtg函数开始打印节点信息……"
    yellow "准备打印节点信息，请稍候……"
    show_info_mtg "$PORT" "$SECRET" "$DOMAIN" "$IP_MODE" "$PORT_V6"
}



create_service_python() {
    USE_BINARY=$1
    echo -e "${BLUE}正在创建服务 (Python)...${PLAIN}"
    EXEC_CMD="$BIN_DIR/mtp-python $CONFIG_DIR/config.py"
    SERVICE_WORKDIR="$WORKDIR"
    
    if [[ "$INIT_SYSTEM" == "systemd" ]]; then
        cat > /etc/systemd/system/mtp-python.service <<EOF
[Unit]
Description=MTProto Proxy (Python)
After=network.target

[Service]
Type=simple
WorkingDirectory=$SERVICE_WORKDIR
ExecStart=$EXEC_CMD
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable mtp-python
        systemctl restart mtp-python
        
    elif [[ "$INIT_SYSTEM" == "openrc" ]]; then
        cat > /etc/init.d/mtp-python <<EOF
#!/sbin/openrc-run
name="mtp-python"
description="MTProto Proxy (Python)"
directory="$SERVICE_WORKDIR"
command="${EXEC_CMD%% *}" 
command_args="${EXEC_CMD#* }"
supervisor="supervise-daemon"
respawn_delay=5
respawn_max=0
rc_ulimit="-n 65535"
pidfile="/run/mtp-python.pid"
output_log="/var/log/mtp-python.log"
error_log="/var/log/mtp-python.log"

depend() {
    need net
    after firewall
}
EOF
        chmod +x /etc/init.d/mtp-python
        rc-update add mtp-python default
        rc-service mtp-python restart
    fi
}

# --- Go 版安装逻辑 ---

create_service_mtg() {
    PORT=$1
    SECRET=$2
    DOMAIN=$3
    IP_MODE=$4

    debug_log "【调试】 create_service_mtg 参数: PORT=$PORT, SECRET=$SECRET, DOMAIN=$DOMAIN, IP_MODE=$IP_MODE, PORT_V6=$PORT_V6"
    
    HEX_DOMAIN=$(echo -n "$DOMAIN" | od -A n -t x1 | tr -d ' \n')
    FULL_SECRET="ee${SECRET}${HEX_DOMAIN}"
    
    NET_ARGS="-i only-ipv4 0.0.0.0:$PORT"
    if [[ "$IP_MODE" == "v6" ]]; then
        NET_ARGS="-i only-ipv6 [::]:$PORT"
    elif [[ "$IP_MODE" == "dual" ]]; then
        NET_ARGS="-i prefer-ipv6 [::]:$PORT"
    fi
    
    CMD_ARGS="simple-run -n 1.1.1.1 -t 30s -a 100mb $NET_ARGS $FULL_SECRET"
    EXEC_CMD="$BIN_DIR/mtg-go $CMD_ARGS"
    
    echo -e "${BLUE}正在创建服务 (Go)...${PLAIN}"
    
    if [[ "$INIT_SYSTEM" == "systemd" ]]; then
        cat > /etc/systemd/system/mtg.service <<EOF
[Unit]
Description=MTProto Proxy (Go - mtg)
After=network.target

[Service]
Type=simple
ExecStart=$EXEC_CMD
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable mtg
        systemctl restart mtg
        debug_log "【调试】 mtg 服务创建完成,已设置为开机自启(systemd)"
        green "✅ mtg服务创建完成，已设置为开机自启(systemd)"
        
    elif [[ "$INIT_SYSTEM" == "openrc" ]]; then
        cat > /etc/init.d/mtg <<EOF
#!/sbin/openrc-run
name="mtg"
description="MTProto Proxy (Go)"
command="$BIN_DIR/mtg-go"
command_args="$CMD_ARGS"
supervisor="supervise-daemon"
respawn_delay=5
respawn_max=0
rc_ulimit="-n 65535"
pidfile="/run/mtg.pid"
output_log="/var/log/mtg.log"
error_log="/var/log/mtg.log"

depend() {
    need net
    after firewall
}
EOF
        chmod +x /etc/init.d/mtg
        rc-update add mtg default
        rc-service mtg restart
        debug_log "【调试】 mtg 服务创建完成,已设置为开机自启(openrc)"
        green "✅ mtg服务创建完成，已设置为开机自启(openrc)"
    fi
}

check_service_status() {
    local service=$1
    debug_log "【调试】 检查服务状态：$service"
    sleep 2
     if has_systemd; then
        debug_log "【调试】 使用 systemd 检查服务状态：$service"

        if systemctl is-active --quiet "$service"; then
            echo -e "${GREEN}服务已启动: $service${PLAIN}"
        else
            echo -e "${RED}服务启动失败: $service${PLAIN}"
            journalctl -u "$service" --no-pager -n 20
        fi
    fi    

    if command -v rc-service >/dev/null 2>&1; then
        debug_log "【调试】 使用 openrc 检查服务状态：$service"
        if rc-service "$service" status | grep -q "started"; then
            echo -e "${GREEN}服务已启动: $service${PLAIN}"
        else
            echo -e "${RED}服务启动失败: $service${PLAIN}"
        fi
    fi
}

check_port_or_suggest_noninteractive() {
    local port="$1"
    if is_port_occupied "$port"; then
        err "端口 $port 已被占用，尝试为您推荐可用端口..."
        # 获取推荐端口
        local res radius ports
        if res="$(suggest_ports "$port" "5 20" 5)"; then
            radius="${res%%|*}"
            ports="${res#*|}"
            echo -e "${BLUE}推荐可用端口(±${radius}): ${GREEN}${ports}${PLAIN}"
            # 如果需要，可以提供用户选择的机制（例如自动选择第一个端口）
            PORT="${ports%% *}"
        else
            echo -e "${YELLOW}无法找到可用端口，使用默认端口 $port.${PLAIN}"
        fi
        return 1
    fi
    return 0
}



check_port_or_exit_noninteractive() {
   check_port_or_suggest_noninteractive "$1"
}


# --- 修改配置逻辑 ---
modify_mtg() {
    if [[ "$INIT_SYSTEM" == "systemd" ]]; then
        CMD_LINE=$(grep "ExecStart" /etc/systemd/system/mtg.service 2>/dev/null)
    else
        CMD_LINE=$(grep "command_args" /etc/init.d/mtg 2>/dev/null)
    fi
    
    if [ -z "$CMD_LINE" ]; then
        echo -e "${YELLOW}未检测到 MTG 服务配置。${PLAIN}"
        return
    fi

    # 简单提取端口 （只取最后一个 :PORT）
    CUR_PORT=$(echo "$CMD_LINE" | grep -oE ':[0-9]{1,5}' | tail -n 1 | tr -d ':')
    # 提取完整Secret
    CUR_FULL_SECRET=$(echo "$CMD_LINE" | sed -n 's/.*\(ee[0-9a-fA-F]*\).*/\1/p' | awk '{print $1}')
    

    CUR_DOMAIN="$(decode_domain_from_full_secret "$CUR_FULL_SECRET")"


    [ -z "$CUR_DOMAIN" ] && CUR_DOMAIN="(解析失败)"

    echo -e "当前配置 (Go): port=[${GREEN}$CUR_PORT${PLAIN}] domain=[${GREEN}$CUR_DOMAIN${PLAIN}]"
    
    read -p "请输入新端口 (留空保持不变): " NEW_PORT
    [ -z "$NEW_PORT" ] && NEW_PORT="$CUR_PORT"
    
    read -p "请输入新伪装域名 (留空保持不变): " NEW_DOMAIN
    [ -z "$NEW_DOMAIN" ] && NEW_DOMAIN="$CUR_DOMAIN"
    
    if [[ "$NEW_PORT" == "$CUR_PORT" && "$NEW_DOMAIN" == "$CUR_DOMAIN" ]]; then
        echo -e "${YELLOW}配置未变更。${PLAIN}"
        return
    fi
    
    echo -e "${BLUE}正在更新配置...${PLAIN}"
    # 重新生成 Secret
    NEW_SECRET=$(generate_secret)
    echo -e "${GREEN}新生成的密钥: $NEW_SECRET${PLAIN}"
    
    # 保持 IP 模式不变 (简单检测一下当前模式)
    CUR_IP_MODE="v4"
    if echo "$CMD_LINE" | grep -q "only-ipv6"; then CUR_IP_MODE="v6"; fi
    if echo "$CMD_LINE" | grep -q "prefer-ipv6"; then CUR_IP_MODE="dual"; fi
    
    create_service_mtg "$NEW_PORT" "$NEW_SECRET" "$NEW_DOMAIN" "$CUR_IP_MODE"

     debug_log "【调试】 检查服务状态……"

    check_service_status mtg
    debug_log "【调试】 show_info_mtg函数开始打印节点信息……"
    yellow "准备打印节点信息，请稍候……"
    show_info_mtg "$NEW_PORT" "$NEW_SECRET" "$NEW_DOMAIN" "$CUR_IP_MODE"
}

modify_python() {
    if [ ! -f "$CONFIG_DIR/config.py" ]; then
         echo -e "${YELLOW}未检测到 Python 版配置文件。${PLAIN}"
         return
    fi
    
    CUR_PORT=$(grep "PORT =" "$CONFIG_DIR/config.py" | awk '{print $3}' | tr -d ' ')
    CUR_DOMAIN=$(grep "TLS_DOMAIN =" "$CONFIG_DIR/config.py" | awk -F= '{print $2}' | tr -d ' "')
    
    echo -e "当前配置 (Python): port=[${GREEN}$CUR_PORT${PLAIN}] domain=[${GREEN}$CUR_DOMAIN${PLAIN}]"
    
    read -p "请输入新端口 (留空保持不变): " NEW_PORT
    [ -z "$NEW_PORT" ] && NEW_PORT="$CUR_PORT"
    
    read -p "请输入新伪装域名 (留空保持不变): " NEW_DOMAIN
    [ -z "$NEW_DOMAIN" ] && NEW_DOMAIN="$CUR_DOMAIN"
    
    if [[ "$NEW_PORT" == "$CUR_PORT" && "$NEW_DOMAIN" == "$CUR_DOMAIN" ]]; then
        echo -e "${YELLOW}配置未变更。${PLAIN}"
        return
    fi
    
    echo -e "${BLUE}正在更新配置文件...${PLAIN}"
    sed -i "s/PORT = .*/PORT = $NEW_PORT/" "$CONFIG_DIR/config.py"
    sed -i "s/TLS_DOMAIN = .*/TLS_DOMAIN = \"$NEW_DOMAIN\"/" "$CONFIG_DIR/config.py"
    
    control_service restart mtp-python
    
    # 重新提取 Secret
    CUR_SECRET=$(grep "\"tg\":" "$CONFIG_DIR/config.py" | head -n 1 | awk -F: '{print $2}' | tr -d ' "')
    
    # 获取当前 Python 模式
    CUR_IP_MODE="v4"
    if grep -q "LISTEN_ADDR_IPV6 = \"::\"" "$CONFIG_DIR/config.py"; then
            if grep -q "LISTEN_ADDR_IPV4 = \"0.0.0.0\"" "$CONFIG_DIR/config.py"; then
                CUR_IP_MODE="dual"
            else
                CUR_IP_MODE="v6"
            fi
    fi
    
    # 获取 V6 端口 (如果是双栈且被单独定义)
    CUR_PORT_V6=$(grep "PORT_IPV6 =" "$CONFIG_DIR/config.py" | awk '{print $3}' | tr -d ' ')
    if [ -z "$CUR_PORT_V6" ]; then CUR_PORT_V6="$NEW_PORT"; fi
    
    show_info_python "$NEW_PORT" "$CUR_SECRET" "$NEW_DOMAIN" "$CUR_IP_MODE" "$CUR_PORT_V6"
}

modify_config() {
    echo ""
    echo -e "请选择要修改的服务:"
    echo -e "1. MTProxy (Go 版)"
    echo -e "2. MTProxy (Python 版)"
    read -p "请选择 [1-2]: " m_choice
    case $m_choice in
        1) modify_mtg ;;
        2) modify_python ;;
        *) echo -e "${RED}无效选择${PLAIN}" ;;
    esac
    back_to_menu
}

# --- 删除配置逻辑 ---
delete_mtg() {
    echo -e "${RED}正在删除 MTProxy (Go 版)...${PLAIN}"
    if [[ "$INIT_SYSTEM" == "systemd" ]]; then
        systemctl stop mtg 2>/dev/null
        systemctl disable mtg 2>/dev/null
        rm -f /etc/systemd/system/mtg.service
        systemctl daemon-reload
    else
        rc-service mtg stop 2>/dev/null
        rc-update del mtg 2>/dev/null
        rm -f /etc/init.d/mtg
    fi
    rm -f "$BIN_DIR/mtg-go"
    echo -e "${GREEN}Go 版服务已删除。${PLAIN}"
}

delete_python() {
    echo -e "${RED}正在删除 MTProxy (Python 版)...${PLAIN}"
    if [[ "$INIT_SYSTEM" == "systemd" ]]; then
        systemctl stop mtp-python 2>/dev/null
        systemctl disable mtp-python 2>/dev/null
        rm -f /etc/systemd/system/mtp-python.service
        systemctl daemon-reload
    else
        rc-service mtp-python stop 2>/dev/null
        rc-update del mtp-python 2>/dev/null
        rm -f /etc/init.d/mtp-python
    fi
    rm -f "$BIN_DIR/mtp-python"
    rm -f "$CONFIG_DIR/config.py"
    echo -e "${GREEN}Python 版服务已删除。${PLAIN}"
}

delete_config() {
    echo ""
    echo -e "请选择要删除的服务 (仅删除配置和服务，不全盘卸载):"
    echo -e "1. MTProxy (Go 版)"
    echo -e "2. MTProxy (Python 版)"
    read -p "请选择 [1-2]: " d_choice
    case $d_choice in
        1) delete_mtg ;;
        2) delete_python ;;
        *) echo -e "${RED}无效选择${PLAIN}" ;;
    esac
    back_to_menu
}

# --- 查看连接信息逻辑 ---
show_detail_info() {
    echo ""

    # ---------------- Go 版信息 ----------------
    if [[ "$INIT_SYSTEM" == "systemd" ]]; then
        CMD_LINE=$(grep "ExecStart" /etc/systemd/system/mtg.service 2>/dev/null)
    else
        CMD_LINE=$(grep "command_args" /etc/init.d/mtg 2>/dev/null)
    fi

    if [ -n "$CMD_LINE" ]; then
        echo -e "${BLUE}=== Go 版信息 ===${PLAIN}"

        # 更稳的端口提取：取最后一个 :PORT
        PORT=$(echo "$CMD_LINE" | grep -oE ':[0-9]{1,5}' | tail -n 1 | tr -d ':')

        # 提取完整 FULL_SECRET（以 ee 开头的那段）
        FULL_SECRET=$(echo "$CMD_LINE" | grep -oE 'ee[0-9a-fA-F]+' | head -n 1)

        # 还原域名 / 基础 Secret
        CUR_DOMAIN="(不可解析)"
        BASE_SECRET=""

        if [[ -n "$FULL_SECRET" ]]; then
            CUR_DOMAIN="$(decode_domain_from_full_secret "$FULL_SECRET")"
            BASE_SECRET="$(decode_base_secret_from_full_secret "$FULL_SECRET")"
            [[ -z "$CUR_DOMAIN" ]] && CUR_DOMAIN="(不可解析)"
        fi

        # 还原 IP 模式（简单推断）
        CUR_IP_MODE="v4"
        if echo "$CMD_LINE" | grep -q "only-ipv6"; then CUR_IP_MODE="v6"; fi
        if echo "$CMD_LINE" | grep -q "prefer-ipv6"; then CUR_IP_MODE="dual"; fi

        show_info_mtg "$PORT" "$BASE_SECRET" "$CUR_DOMAIN" "$CUR_IP_MODE"
    else
        echo -e "${BLUE}=== Go 版信息 ===${PLAIN}"
        echo -e "${YELLOW}未安装或未运行${PLAIN}"
    fi

    echo -e ""

    # ---------------- Python 版信息 ----------------
    if [ -f "$CONFIG_DIR/config.py" ]; then
        echo -e "${BLUE}=== Python 版信息 ===${PLAIN}"

        PORT=$(grep "PORT =" "$CONFIG_DIR/config.py" | head -n 1 | awk '{print $3}' | tr -d ' ')
        SECRET=$(grep "\"tg\":" "$CONFIG_DIR/config.py" | head -n 1 | awk -F: '{print $2}' | tr -d ' "')
        DOMAIN=$(grep "TLS_DOMAIN =" "$CONFIG_DIR/config.py" | awk -F= '{print $2}' | tr -d ' "')

        # 获取 IP 模式
        PY_IP_MODE="v4"
        if grep -q "LISTEN_ADDR_IPV6 = \"::\"" "$CONFIG_DIR/config.py"; then
            if grep -q "LISTEN_ADDR_IPV4 = \"0.0.0.0\"" "$CONFIG_DIR/config.py"; then
                PY_IP_MODE="dual"
            else
                PY_IP_MODE="v6"
            fi
        fi

        # 获取 V6 端口（若没有单独定义，则用 PORT）
        PORT_V6=$(grep "PORT_IPV6 =" "$CONFIG_DIR/config.py" | awk '{print $3}' | tr -d ' ')
        [ -z "$PORT_V6" ] && PORT_V6="$PORT"

        show_info_python "$PORT" "$SECRET" "$DOMAIN" "$PY_IP_MODE" "$PORT_V6"
    else
        echo -e "${BLUE}=== Python 版信息 ===${PLAIN}"
        echo -e "${YELLOW}未安装配置文件${PLAIN}"
    fi

    back_to_menu
}


# --- 信息显示 ---
show_info_python() {
    debug_log "【调试】 show_info_python函数开始获取ip……"

    IPV4=$(get_public_ip)
    IPV6=$(get_public_ipv6)
    IP_MODE=$4

    debug_log "【调试】 获取到的IPV4地址为：$IPV4"
    debug_log "【调试】 获取到的IPV6地址为：$IPV6"
    debug_log "【调试】 获取到的IP_MODE为：$IP_MODE"
    
    HEX_DOMAIN=$(echo -n "$3" | od -A n -t x1 | tr -d ' \n')
    FULL_SECRET="ee$2$HEX_DOMAIN"
    
    echo -e "=============================="
    echo -e "${GREEN}Python 版连接信息${PLAIN}"
    echo -e "端口: $1"
    echo -e "Secret: $FULL_SECRET"
    echo -e "Domain: $3"
    echo -e "------------------------------"
    
    if [[ "$IP_MODE" == "v4" || "$IP_MODE" == "dual" ]]; then
        if [ -n "$IPV4" ]; then
            echo -e "${GREEN}IPv4 链接:${PLAIN}"
            echo -e "${GREEN}tg://proxy?server=$IPV4&port=$1&secret=$FULL_SECRET${PLAIN}"
        else
            echo -e "${RED}未检测到 IPv4 地址${PLAIN}"
        fi
    fi
    
    if [[ "$IP_MODE" == "v6" || "$IP_MODE" == "dual" ]]; then
        # 如果定义了 PORT_V6 (第5个参数)，则使用它，否则默认用 端口1
        PORT_V6=$5
        [ -z "$PORT_V6" ] && PORT_V6="$1"
        
        if [ -n "$IPV6" ]; then
            echo -e "${PURPLE}IPv6 链接:${PLAIN}"
            echo -e "${PURPLE}tg://proxy?server=$IPV6&port=$PORT_V6&secret=$FULL_SECRET${PLAIN}"
        else
            echo -e "${YELLOW}未检测到 IPv6 地址${PLAIN}"
        fi
    fi
    echo -e "=============================="
}

show_info_mtg() {
    debug_log "【调试】 show_info_mtg函数开始获取ip……"

    IPV4=$(get_public_ip)
    IPV6=$(get_public_ipv6)
    IP_MODE=$4

    debug_log "【调试】 获取到的IPV4地址为：$IPV4"
    debug_log "【调试】 获取到的IPV6地址为：$IPV6"
    debug_log "【调试】 获取到的IP_MODE为：$IP_MODE"
    
    HEX_DOMAIN=$(echo -n "$3" | od -A n -t x1 | tr -d ' \n')
    FULL_SECRET="ee$2$HEX_DOMAIN"
    echo -e "=============================="
    echo -e "${GREEN}Go 版连接信息如下:${PLAIN}"
    echo -e "端口: $1"
    echo -e "Secret: $FULL_SECRET"
    echo -e "Domain: $3"
    echo -e "------------------------------"

    if [[ "$IP_MODE" == "v4" || "$IP_MODE" == "dual" ]]; then
        if [ -n "$IPV4" ]; then
            echo -e "${GREEN}IPv4 链接:${PLAIN}"
            echo -e "${GREEN}tg://proxy?server=$IPV4&port=$1&secret=$FULL_SECRET${PLAIN}"
        else
            echo -e "${RED}未检测到 IPv4 地址${PLAIN}"
        fi
    fi
    
    if [[ "$IP_MODE" == "v6" || "$IP_MODE" == "dual" ]]; then
        if [ -n "$IPV6" ]; then
            echo -e "${PURPLE}IPv6 链接:${PLAIN}"
            echo -e "${PURPLE}tg://proxy?server=$IPV6&port=$1&secret=$FULL_SECRET${PLAIN}"
        else
            echo -e "${YELLOW}未检测到 IPv6 地址${PLAIN}"
        fi
    fi
    echo -e "=============================="
}

get_service_status_str() {
    local service=$1
    if [[ "$INIT_SYSTEM" == "systemd" ]]; then
        if [ -f "/etc/systemd/system/${service}.service" ]; then
            if systemctl is-active --quiet "$service"; then
                echo -e "${GREEN}运行中${PLAIN}"
                return
            fi
        fi
    else
        if [ -f "/etc/init.d/${service}" ]; then
            if rc-service "$service" status 2>/dev/null | grep -q "started"; then
                echo -e "${GREEN}运行中${PLAIN}"
                return
            fi
        fi
    fi
    echo -e "${RED}未运行/未安装${PLAIN}"
}

# --- 服务控制 ---
control_service() {
    ACTION=$1
    shift
    TARGETS="mtg mtp-python"
    # 如果指定了具体服务名，就只操作那一个
    if [[ -n "$1" ]]; then TARGETS="$1"; fi
    
    for SERVICE in $TARGETS; do
        if [[ "$INIT_SYSTEM" == "systemd" ]]; then
             if [ -f "/etc/systemd/system/${SERVICE}.service" ]; then
                 systemctl $ACTION $SERVICE
                 echo -e "${BLUE}$SERVICE $ACTION 完成${PLAIN}"
             fi
        else
             if [ -f "/etc/init.d/${SERVICE}" ]; then
                 rc-service $SERVICE $ACTION
                 echo -e "${BLUE}$SERVICE $ACTION 完成${PLAIN}"
             fi
        fi
    done
}

delete_all() {
    echo -e "${RED}正在卸载所有服务...${PLAIN}"

    # 确保已检测系统（依赖 INIT_SYSTEM / WORKDIR / BIN_DIR / CONFIG_DIR 等变量）
    if [[ -z "$INIT_SYSTEM" ]]; then
        check_sys
    fi

    # 1) 停止 + 禁用 + 删除服务文件
    if [[ "$INIT_SYSTEM" == "systemd" ]]; then
        echo -e "${BLUE}检测到 systemd，停止并清理服务...${PLAIN}"

        systemctl stop mtg 2>/dev/null
        systemctl stop mtp-python 2>/dev/null

        systemctl disable mtg 2>/dev/null
        systemctl disable mtp-python 2>/dev/null

        rm -f /etc/systemd/system/mtg.service
        rm -f /etc/systemd/system/mtp-python.service

        systemctl daemon-reload 2>/dev/null

    elif [[ "$INIT_SYSTEM" == "openrc" ]]; then
        echo -e "${BLUE}检测到 OpenRC，停止并清理服务...${PLAIN}"

        rc-service mtg stop 2>/dev/null
        rc-service mtp-python stop 2>/dev/null

        rc-update del mtg default 2>/dev/null
        rc-update del mtp-python default 2>/dev/null

        rm -f /etc/init.d/mtg
        rm -f /etc/init.d/mtp-python

        # OpenRC 不需要 systemctl daemon-reload
    else
        echo -e "${YELLOW}未知初始化系统，尝试尽力停止服务...${PLAIN}"
        killall mtg-go 2>/dev/null
        killall mtp-python 2>/dev/null
    fi

    # 2) 删除二进制与配置
    echo -e "${BLUE}清理安装目录...${PLAIN}"

    # 只要 WORKDIR 存在并且不是空变量，就删
    if [[ -n "$WORKDIR" && -d "$WORKDIR" ]]; then
        rm -rf "$WORKDIR"
        echo -e "${GREEN}删除 $WORKDIR 完成。${PLAIN}"
    else
        # 兼容你旧脚本里写死 /opt/mtproxy 的情况
        if [[ -d /opt/mtproxy ]]; then
            rm -rf /opt/mtproxy
            echo -e "${GREEN}删除 /opt/mtproxy 完成。${PLAIN}"
        fi
    fi

    # 3) 清理可能的额外目录（可选）
    rm -rf /etc/mtproxy 2>/dev/null
    rm -rf /var/log/mtproxy 2>/dev/null

    echo -e "${GREEN}卸载完成。${PLAIN}"
}




back_to_menu() {
    echo ""
    read -n 1 -s -r -p "按任意键返回主菜单..."
    menu
}

exit_script() {
    echo ""
    green "感谢使用本脚本,再见👋"
    echo ""
    exit 0
}

# --- 菜单 ---
menu() {
    check_sys
    clear
    
    echo -e "=================================="
    echo -e "     MTProxy 一键部署管理脚本"
    echo -e "     Author: ${GREEN}$SCRIPT_AUTHOR${PLAIN}"
    echo -e "     Version: ${YELLOW}$SCRIPT_VERSION${PLAIN}"
    echo -e "=================================="
    echo -e "Go     版: $(get_service_status_str mtg)"
    echo -e "Python 版: $(get_service_status_str mtp-python)"
    echo -e "=================================="
    echo -e "${GREEN}1.${PLAIN} 安装/重装 Go 版(强烈推荐)"
    echo -e "${GREEN}2.${PLAIN} 安装/重装 Python 版"
    echo -e "----------------------------------"
    echo -e "${GREEN}3.${PLAIN} 查看详细连接信息"
    echo -e "${GREEN}4.${PLAIN} 修改服务配置 (端口/域名)"
    echo -e "${GREEN}5.${PLAIN} 删除服务配置 (选择删除)"
    echo -e "----------------------------------"
    echo -e "${GREEN}6.${PLAIN} 启动服务"
    echo -e "${GREEN}7.${PLAIN} 停止服务"
    echo -e "${GREEN}8.${PLAIN} 重启服务"
    echo -e "----------------------------------"
    echo -e "${GREEN}9.${PLAIN} 卸载全部并清理"
    echo -e "${GREEN}88.${PLAIN} 退出脚本"
    echo -e "=================================="
    read -p "请选择: " choice
    
    case $choice in
        1) menu_operation_go; 
            ;;
        2) menu_operation_python; 
            ;;
        3) show_detail_info ;;
        4) modify_config ;;
        5) delete_config ;;
        6) control_service start; back_to_menu ;;
        7) control_service stop; back_to_menu ;;
        8) control_service restart; back_to_menu ;;
        9) delete_all; exit 0 ;;
        88) exit_script ;;
        *) echo -e "${RED}无效此选项${PLAIN}"; menu ;;
    esac
}



menu_operation_go() {
    INTERACTIVE_FLAG=1

    # 1) 先收集非端口信息（域名/IP_MODE/secret）
    # 如果你现在的 inputs_interactive() 里还包含端口输入，建议你把端口输入挪出来（见下方小建议）
    inputs_interactive_base_only

    # 2) 端口循环输入
    while true; do
        if [[ "$IP_MODE" == "dual" ]]; then
            read -p "$(yellow "请输入 IPv4 端口 (默认: ${PORT:-443}): ")" tmp
            PORT="${tmp:-${PORT:-443}}"

            if check_port_or_prompt_interactive "$PORT"; then
                :
            else
                echo -e "${YELLOW}端口 $PORT 被占用。${PLAIN}"
                if [[ -n "$SUGGESTED_PORTS" ]]; then
                    echo -e "${BLUE}推荐可用端口(±${SUGGESTED_RADIUS}): ${GREEN}${SUGGESTED_PORTS}${PLAIN}"
                else
                    echo -e "${BLUE}推荐可用端口: ${GREEN}${SUGGESTED_RANDOM}${PLAIN}"
                fi
                continue
            fi

            read -p "$(yellow "请输入 IPv6 端口 (默认: ${PORT_V6:-$PORT}): ")" tmp
            PORT_V6="${tmp:-${PORT_V6:-$PORT}}"

            # 如果你允许 v4/v6 分端口：这里也检查
            if [[ "$PORT_V6" != "$PORT" ]]; then
                if ! check_port_or_prompt_interactive "$PORT_V6"; then
                    echo -e "${YELLOW}端口 $PORT_V6 被占用。${PLAIN}"
                    if [[ -n "$SUGGESTED_PORTS" ]]; then
                        echo -e "${BLUE}推荐可用端口(±${SUGGESTED_RADIUS}): ${GREEN}${SUGGESTED_PORTS}${PLAIN}"
                    else
                        echo -e "${BLUE}推荐可用端口: ${GREEN}${SUGGESTED_RANDOM}${PLAIN}"
                    fi
                    continue
                fi
            fi

            break
        else
            read -p "$(yellow "请输入端口 (默认: ${PORT:-443}): ")" tmp
            PORT="${tmp:-${PORT:-443}}"
            PORT_V6=""

            if check_port_or_prompt_interactive "$PORT"; then
                break
            else
                echo -e "${YELLOW}端口 $PORT 被占用。${PLAIN}"
                if [[ -n "$SUGGESTED_PORTS" ]]; then
                    echo -e "${BLUE}推荐可用端口(±${SUGGESTED_RADIUS}): ${GREEN}${SUGGESTED_PORTS}${PLAIN}"
                else
                    echo -e "${BLUE}推荐可用端口: ${GREEN}${SUGGESTED_RANDOM}${PLAIN}"
                fi
            fi
        fi
    done

    install_base_deps
    install_mtp_go
    back_to_menu
}


menu_operation_python() {
    INTERACTIVE_FLAG=1

    # 1) 先收集非端口信息（域名/IP_MODE/secret）
    # 如果你现在的 inputs_interactive() 里还包含端口输入，建议你把端口输入挪出来（见下方小建议）
    inputs_interactive_base_only

    # 2) 端口循环输入
    while true; do
        if [[ "$IP_MODE" == "dual" ]]; then
            read -p "$(yellow "请输入 IPv4 端口 (默认: ${PORT:-443}): ")" tmp
            PORT="${tmp:-${PORT:-443}}"

            if check_port_or_prompt_interactive "$PORT"; then
                :
            else
                echo -e "${YELLOW}端口 $PORT 被占用。${PLAIN}"
                if [[ -n "$SUGGESTED_PORTS" ]]; then
                    echo -e "${BLUE}推荐可用端口(±${SUGGESTED_RADIUS}): ${GREEN}${SUGGESTED_PORTS}${PLAIN}"
                else
                    echo -e "${BLUE}推荐可用端口: ${GREEN}${SUGGESTED_RANDOM}${PLAIN}"
                fi
                continue
            fi

            read -p "$(yellow "请输入 IPv6 端口 (默认: ${PORT_V6:-$PORT}): ")" tmp
            PORT_V6="${tmp:-${PORT_V6:-$PORT}}"

            # 如果你允许 v4/v6 分端口：这里也检查
            if [[ "$PORT_V6" != "$PORT" ]]; then
                if ! check_port_or_prompt_interactive "$PORT_V6"; then
                    echo -e "${YELLOW}端口 $PORT_V6 被占用。${PLAIN}"
                    if [[ -n "$SUGGESTED_PORTS" ]]; then
                        echo -e "${BLUE}推荐可用端口(±${SUGGESTED_RADIUS}): ${GREEN}${SUGGESTED_PORTS}${PLAIN}"
                    else
                        echo -e "${BLUE}推荐可用端口: ${GREEN}${SUGGESTED_RANDOM}${PLAIN}"
                    fi
                    continue
                fi
            fi

            break
        else
            read -p "$(yellow "请输入端口 (默认: ${PORT:-443}): ")" tmp
            PORT="${tmp:-${PORT:-443}}"
            PORT_V6=""

            if check_port_or_prompt_interactive "$PORT"; then
                break
            else
                echo -e "${YELLOW}端口 $PORT 被占用。${PLAIN}"
                if [[ -n "$SUGGESTED_PORTS" ]]; then
                    echo -e "${BLUE}推荐可用端口(±${SUGGESTED_RADIUS}): ${GREEN}${SUGGESTED_PORTS}${PLAIN}"
                else
                    echo -e "${BLUE}推荐可用端口: ${GREEN}${SUGGESTED_RANDOM}${PLAIN}"
                fi
            fi
        fi
    done

    install_base_deps
    install_mtp_python
    back_to_menu
}


inputs_interactive_base_only() {
    read -p "$(yellow "请输入伪装域名 (默认: ${DOMAIN:-www.apple.com}): ")" tmp
    DOMAIN="${tmp:-${DOMAIN:-www.apple.com}}"

    IP_MODE="$(select_ip_mode)"

    if [[ -z "$SECRET" ]]; then
        SECRET="$(generate_secret)"
    fi
    echo -e "${GREEN}生成的密钥: $SECRET${PLAIN}"
}



interactive_install_quick(){
    # call menu
    menu
}


# Function for non-interactive installation
non_interactive_install_quick() {
    echo -e "${GREEN}开始无交互式安装...${PLAIN}"
    install_base_deps

    install_mode_init
    inputs_noninteractive

    # 非交互下端口占用：直接退出
    check_port_or_exit_noninteractive "$PORT"
    if [[ "$IP_MODE" == "dual" && -n "$PORT_V6" && "$PORT_V6" != "$PORT" ]]; then
        check_port_or_exit_noninteractive "$PORT_V6"
    fi

    if [[ "$INSTALL_MODE" == "go" ]]; then
        debug_log "【调试】 安装模式为 go"
        install_mtp_go
    else
        debug_log "【调试】 安装模式为 python"
        install_mtp_python
    fi

    echo -e "${GREEN}无交互式安装完成！${PLAIN}"
}


install_entry(){
       if [[ -z "$PORT" ]]; then
            echo -e "${GREEN}未指定PORT，进入交互式安装模式...${PLAIN}"
            INTERACTIVE_FLAG=1  # Interactive mode
            menu  # Call the menu for interactive installation
        else
            echo -e "${GREEN}已指定PORT，进入非交互式安装模式...${PLAIN}"
            INTERACTIVE_FLAG=0  # Non-interactive mode
            non_interactive_install_quick  # Proceed with non-interactive installation
        fi

}


# Main function to parse arguments and perform actions
main() {
    check_sys

    # If no argument is provided, proceed with installation
    if [[ -z "$1" ]]; then
        install_entry
    else
        # Handle commands like del, list, start, stop
        case "$1" in
            rep)
                delete_all
                install_entry
                ;;
            del)
                delete_all
                ;;
            list)
                show_detail_info
                ;;
            start)
                control_service start
                ;;
            stop)
                control_service stop
                ;;
            restart)
                control_service restart
                ;;
            *)
                echo -e "${RED}未知命令: $1。有效命令: del, list, start, stop,restart${PLAIN}"
                exit 1
                ;;
        esac
    fi
}

main "$@"
