#!/bin/bash

SCRIPT_VERSION="2.2.9(2026-08-02)"
SCRIPT_AUTHOR="LittleDoraemon"

# 全局配置
WORKDIR="/opt/mtproxy"
CONFIG_DIR="$WORKDIR/config"
LOG_DIR="$WORKDIR/logs"
BIN_DIR="$WORKDIR/bin"
DATA_DIR="$WORKDIR/exhausteddata"

# Telegram 统计日报推送时间（北京时间 HH:MM，可用 TELEMT_TG_TIME 环境变量覆盖）
TG_PUSH_TIME="09:00"

# 获取脚本绝对路径
SCRIPT_PATH=$(readlink -f "$0" 2>/dev/null)
if [ -z "$SCRIPT_PATH" ]; then
    SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
fi
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

# 自动注册全局快捷命令 mtp（如果尚未注册）
if [ ! -L "/usr/local/bin/mtp" ] || [ "$(readlink -f /usr/local/bin/mtp 2>/dev/null)" != "$SCRIPT_PATH" ]; then
    ln -sf "$SCRIPT_PATH" /usr/local/bin/mtp 2>/dev/null
fi

# 颜色定义
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[36m'
PLAIN='\033[0m'

# 调试日志开关（DEBUG_FLAG=1 时输出调试信息到 stderr，方便后期排障）
export DEBUG_FLAG=${DEBUG_FLAG:-'0'}

debug_log() {
    [ "${DEBUG_FLAG:-0}" = "1" ] && echo -e "$*" >&2
}

debug_print() {
    [ "${DEBUG_FLAG:-0}" = "1" ] && "$@"
}

# 系统检测
OS=""
PACKAGE_MANAGER=""
INIT_SYSTEM=""

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
        PACKAGE_MANAGER="yum"
        INIT_SYSTEM="systemd"
    else
        echo -e "${RED}不支持的系统: $OS${PLAIN}"
        exit 1
    fi
    debug_log "【调试】系统检测: OS=$OS PACKAGE_MANAGER=$PACKAGE_MANAGER INIT_SYSTEM=$INIT_SYSTEM"
}

install_base_deps() {
    echo -e "${BLUE}正在安装基础依赖...${PLAIN}"
    debug_log "【调试】PACKAGE_MANAGER=$PACKAGE_MANAGER"
    if [[ "$PACKAGE_MANAGER" == "apk" ]]; then
        debug_log "【调试】执行: apk update && apk add curl wget tar ca-certificates openssl bash gawk coreutils python3"
        apk update
        apk add curl wget tar ca-certificates openssl bash gawk coreutils python3
    elif [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        debug_log "【调试】执行: apt-get update && apt-get install -y curl wget tar ca-certificates openssl gawk coreutils cron python3"
        apt-get update
        apt-get install -y curl wget tar ca-certificates openssl gawk coreutils cron python3
    elif [[ "$PACKAGE_MANAGER" == "yum" ]]; then
        debug_log "【调试】执行: yum install -y curl wget tar ca-certificates openssl gawk coreutils cronie python3"
        yum install -y curl wget tar ca-certificates openssl gawk coreutils cronie python3
    fi
}

get_public_ip() {
    curl -s4 --max-time 5 https://api.ip.sb/ip -A Mozilla || curl -s4 --max-time 5 https://ipinfo.io/ip -A Mozilla
}

get_public_ipv6() {
    curl -s6 --max-time 5 https://api.ip.sb/ip -A Mozilla || curl -s6 --max-time 5 https://ifconfig.co/ip -A Mozilla
}

# 预获取 IP，避免最后等待
prefetch_ips() {
    echo -e "${BLUE}正在检测服务器 IP (超时 5秒)...${PLAIN}"
    PUBLIC_IPV4=$(get_public_ip)
    PUBLIC_IPV6=$(get_public_ipv6)
    
    if [ -n "$PUBLIC_IPV4" ]; then
        echo -e "${GREEN}检测到 IPv4: $PUBLIC_IPV4${PLAIN}"
    else
        echo -e "${YELLOW}未检测到 IPv4${PLAIN}"
    fi
    
    if [ -n "$PUBLIC_IPV6" ]; then
        echo -e "${GREEN}检测到 IPv6: $PUBLIC_IPV6${PLAIN}"
    else
        echo -e "${YELLOW}未检测到 IPv6${PLAIN}"
    fi
}

generate_secret() {
    head -c 16 /dev/urandom | od -A n -t x1 | tr -d ' \n'
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

# 循环读取一个合法的端口号 (1-65535)，留空使用默认值
read_valid_port() {
    local prompt=$1
    local def=$2
    local val=""
    while true; do
        read -p "$prompt" val
        [ -z "$val" ] && val="$def"
        if [[ "$val" =~ ^[0-9]+$ ]] && [ "$val" -ge 1 ] && [ "$val" -le 65535 ]; then
            echo "$val"
            return 0
        fi
        echo -e "${RED}端口必须是 1-65535 之间的数字！${PLAIN}" >&2
    done
}

# --- 服务状态检测 ---
get_service_status_str() {
    local SERVICE=$1
    local status=""
    
    if [[ "$INIT_SYSTEM" == "systemd" ]]; then
        if [ -f "/etc/systemd/system/${SERVICE}.service" ]; then
            if systemctl is-active --quiet $SERVICE 2>/dev/null; then
                status="${GREEN}● 运行中${PLAIN}"
            else
                status="${RED}○ 已停止${PLAIN}"
            fi
        else
            status="${YELLOW}○ 未安装${PLAIN}"
        fi
    else
        if [ -f "/etc/init.d/${SERVICE}" ]; then
            if rc-service $SERVICE status 2>/dev/null | grep -q "started"; then
                status="${GREEN}● 运行中${PLAIN}"
            else
                status="${RED}○ 已停止${PLAIN}"
            fi
        else
            status="${YELLOW}○ 未安装${PLAIN}"
        fi
    fi
    
    echo -e "$status"
}

# Telegram 推送配置状态（主菜单信息行展示用）
get_tg_status_str() {
    if [ ! -f "/etc/telemt_tg.conf" ]; then
        echo -e "${YELLOW}○ 未配置${PLAIN}"
        return
    fi
    local token chat time
    token=$(grep -E '^BOT_TOKEN=' /etc/telemt_tg.conf | head -1 | cut -d'=' -f2-)
    chat=$(grep -E '^CHAT_ID=' /etc/telemt_tg.conf | head -1 | cut -d'=' -f2-)
    time=$(grep -E '^TG_TIME=' /etc/telemt_tg.conf | head -1 | cut -d'=' -f2-)
    [ -z "$time" ] && time="09:00"
    if [ -n "$token" ] && [ -n "$chat" ]; then
        echo -e "${GREEN}● 已配置${PLAIN} (Bot:${token:0:5}... → ${chat}  日报 ${time})"
    else
        echo -e "${YELLOW}△ 配置不完整${PLAIN}"
    fi
}

# --- 查看所有服务状态 ---
check_all_status() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════╗${PLAIN}"
    echo -e "${BLUE}║        MTProxy 服务状态详情              ║${PLAIN}"
    echo -e "${BLUE}╠══════════════════════════════════════════╣${PLAIN}"
    
    for SERVICE in mtg telemt; do
        local NAME=""
        case $SERVICE in
            mtg) NAME="Go 版 (mtg)   " ;;
            telemt) NAME="Telemt 高性能版" ;;
        esac
        
        local STATUS=""
        local PID=""
        local MEMORY="-"
        local UPTIME="-"
        
        if [[ "$INIT_SYSTEM" == "systemd" ]]; then
            if [ -f "/etc/systemd/system/${SERVICE}.service" ]; then
                if systemctl is-active --quiet $SERVICE 2>/dev/null; then
                    STATUS="${GREEN}运行中${PLAIN}"
                    PID=$(systemctl show -p MainPID --value $SERVICE 2>/dev/null)
                else
                    STATUS="${RED}已停止${PLAIN}"
                fi
            else
                STATUS="${YELLOW}未安装${PLAIN}"
            fi
        else
            if [ -f "/etc/init.d/${SERVICE}" ]; then
                if rc-service $SERVICE status 2>/dev/null | grep -q "started"; then
                    STATUS="${GREEN}运行中${PLAIN}"
                    PID=$(cat /run/${SERVICE}.pid 2>/dev/null)
                else
                    STATUS="${RED}已停止${PLAIN}"
                fi
            else
                STATUS="${YELLOW}未安装${PLAIN}"
            fi
        fi
        
        # 兼容跨平台(尤其是 Alpine)获取内存与运行时间 (纯依靠 /proc)
        if [ -n "$PID" ] && [ "$PID" != "0" ] && [ -d "/proc/$PID" ]; then
            local vm_rss=$(grep -i "VmRSS" /proc/$PID/status 2>/dev/null | awk '{print $2}')
            if [ -n "$vm_rss" ]; then
                MEMORY=$(awk "BEGIN {printf \"%.1f MB\", $vm_rss/1024}")
            fi
            
            local start_time=$(stat -c %Y /proc/$PID 2>/dev/null)
            if [ -n "$start_time" ]; then
                local now=$(date +%s)
                local diff=$((now - start_time))
                local days=$((diff / 86400))
                local hours=$(((diff % 86400) / 3600))
                local mins=$(((diff % 3600) / 60))
                if [ $days -gt 0 ]; then
                    UPTIME="${days}天 ${hours}小时 ${mins}分钟"
                else
                    UPTIME="${hours}小时 ${mins}分钟"
                fi
            fi
        fi
        
        # 使用动态排版抛弃右侧封口避免 ANSI 和 CJK 造成对不齐
        echo -e "${BLUE}║${PLAIN} $NAME  状态: $STATUS"
        if [ -n "$PID" ] && [ "$PID" != "0" ]; then
            echo -e "${BLUE}║${PLAIN}   PID: $PID   |   内存: $MEMORY   |   已运行: $UPTIME"
        fi
        echo -e "${BLUE}╟──────────────────────────────────────────╢${PLAIN}"
    done
    
    echo -e "${BLUE}╚══════════════════════════════════════════╝${PLAIN}"
    echo ""
}

# --- 查看服务日志 ---
view_logs() {
    echo ""
    echo -e "${BLUE}请选择要查看的日志:${PLAIN}"
    echo -e "${GREEN}1.${PLAIN} Go 版日志 (mtg)"
    echo -e "${GREEN}2.${PLAIN} Telemt 版日志 (telemt)"
    echo -e "${GREEN}3.${PLAIN} 实时跟踪所有日志"
    echo -e "${GREEN}0.${PLAIN} 返回主菜单"
    read -p "请选择: " log_choice
    
    case $log_choice in
        1)
            echo -e "${BLUE}=== Go 版日志 (最近 50 行) ===${PLAIN}"
            if [[ "$INIT_SYSTEM" == "systemd" ]]; then
                journalctl -u mtg -n 50 --no-pager
            else
                tail -n 50 /var/log/mtg.log 2>/dev/null || echo "日志文件不存在"
            fi
            ;;
        2)
            echo -e "${BLUE}=== Telemt 版日志 (最近 50 行) ===${PLAIN}"
            if [[ "$INIT_SYSTEM" == "systemd" ]]; then
                journalctl -u telemt -n 50 --no-pager
            else
                tail -n 50 /var/log/telemt.log 2>/dev/null || echo "日志文件不存在"
            fi
            ;;
        3)
            echo -e "${YELLOW}正在实时跟踪日志 (按 Ctrl+C 退出)...${PLAIN}"
            if [[ "$INIT_SYSTEM" == "systemd" ]]; then
                journalctl -u mtg -u telemt -f
            else
                tail -f /var/log/mtg.log /var/log/telemt.log 2>/dev/null
            fi
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效选项${PLAIN}"
            ;;
    esac
}

# --- Go 版安装逻辑 ---
install_mtg() {
    prefetch_ips
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) MTG_ARCH="amd64" ;;
        aarch64) MTG_ARCH="arm64" ;;
        *) echo -e "${RED}不支持的架构: $ARCH${PLAIN}"; return 1 ;;
    esac
    
    mkdir -p "$BIN_DIR"
    TARGET_NAME="mtg-go-${MTG_ARCH}"
    FOUND_PATH=""
    
    if [ -f "./${TARGET_NAME}" ]; then
        FOUND_PATH="./${TARGET_NAME}"
    elif [ -f "${SCRIPT_DIR}/${TARGET_NAME}" ]; then
        FOUND_PATH="${SCRIPT_DIR}/${TARGET_NAME}"
    fi
    
    if [ -n "$FOUND_PATH" ]; then
        echo -e "${GREEN}检测到本地二进制文件: ${FOUND_PATH}${PLAIN}"
        cp "${FOUND_PATH}" "$BIN_DIR/mtg-go"
    else
        echo -e "${BLUE}未找到本地文件，尝试从 GitHub 下载 (${TARGET_NAME})...${PLAIN}"
        # 本仓库自持源（由 sync-deps.yml 从上游镜像），如需切回上游源，取消下行注释并注释上行
        DOWNLOAD_URL="https://github.com/jyucoeng/singbox-tools/releases/download/Go-Rust/${TARGET_NAME}"
        # DOWNLOAD_URL="https://github.com/0xdabiaoge/MTProxy/releases/download/Go-Rust/${TARGET_NAME}"
        wget -O "$BIN_DIR/mtg-go" "$DOWNLOAD_URL"
        if [ $? -ne 0 ]; then
            echo -e "${RED}下载失败！${PLAIN}"
            return 1
        fi
    fi
    chmod +x "$BIN_DIR/mtg-go"

    # 无交互安装：优先使用环境变量，缺省自动填充；交互安装：逐项询问
    if [ -n "$NON_INTERACTIVE" ]; then
        DOMAIN="${DOMAIN:-www.apple.com}"
        IP_MODE="${IP_MODE:-v4}"
        PORT="${PORT:-443}"
        SECRET="${SECRET:-$(generate_secret)}"
    else
        read -p "请输入伪装域名 (默认 www.apple.com): " DOMAIN
        [ -z "$DOMAIN" ] && DOMAIN="www.apple.com"
        
        IP_MODE=$(select_ip_mode)
        
        # mtg 双栈模式使用同一端口 (dual-stack 监听)，无需单独输入 IPv6 端口
        PORT=$(read_valid_port "请输入端口 (默认 443): " "443")
        
        # 若已预先设置 SECRET 环境变量则沿用，否则自动生成（保证多次安装密钥一致）
        [ -z "$SECRET" ] && SECRET=$(generate_secret)
    fi
    
    case "$IP_MODE" in
        v4|v6|dual) ;;
        *) echo -e "${RED}无效的 IP_MODE: $IP_MODE (可选: v4 / v6 / dual)${PLAIN}"; return 1 ;;
    esac
    if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
        echo -e "${RED}端口无效: $PORT (必须是 1-65535 之间的数字)${PLAIN}"
        return 1
    fi
    if ! [[ "$SECRET" =~ ^[0-9a-fA-F]{32}$ ]]; then
        echo -e "${RED}SECRET 必须是 32 位 hex 字符 (a-f/0-9)！当前值: $SECRET${PLAIN}"
        return 1
    fi
    
    debug_log "【调试】install_mtg: ARCH=$ARCH MTG_ARCH=$MTG_ARCH DOMAIN=$DOMAIN IP_MODE=$IP_MODE PORT=$PORT SECRET=$SECRET"
    echo -e "${GREEN}密钥: $SECRET${PLAIN}"

    create_service_mtg "$PORT" "$SECRET" "$DOMAIN" "$IP_MODE"
    check_service_status mtg
    show_info_mtg "$PORT" "$SECRET" "$DOMAIN" "$IP_MODE"
}

create_service_mtg() {
    PORT=$1
    SECRET=$2
    DOMAIN=$3
    IP_MODE=$4
    
    HEX_DOMAIN=$(echo -n "$DOMAIN" | od -A n -t x1 | tr -d ' \n')
    FULL_SECRET="ee${SECRET}${HEX_DOMAIN}"
    
    NET_ARGS="-i only-ipv4 0.0.0.0:$PORT"
    if [[ "$IP_MODE" == "v6" ]]; then
        NET_ARGS="-i only-ipv6 [::]:$PORT"
    elif [[ "$IP_MODE" == "dual" ]]; then
        NET_ARGS="-i prefer-ipv6 [::]:$PORT"
    fi
    
    # -c 65535 显式指定最大并发连接数，与代码 DefaultConcurrency 一致
    CMD_ARGS="simple-run -n 1.1.1.1 -t 30s -a 1mb -c 65535 $NET_ARGS $FULL_SECRET"
    EXEC_CMD="$BIN_DIR/mtg-go $CMD_ARGS"
    
    # 保存配置到文件，便于后续修改和查看
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_DIR/go.conf" <<EOF
PORT=$PORT
SECRET=$FULL_SECRET
DOMAIN=$DOMAIN
IP_MODE=$IP_MODE
EOF
    
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
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable mtg
        systemctl restart mtg
        
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
    fi
}


# === Telemt 版安装逻辑 ===

# 在配额记录文件中将指定用户归零；若文件不存在则初始化，若已有该用户则就地更新，保留其他用户记录
set_quota_record_zero() {
    local user=$1
    local quota_json="/etc/telemt_quota.json"
    if [ ! -f "$quota_json" ]; then
        echo "{\"$user\":0}" > "$quota_json"
    elif grep -q "\"$user\":" "$quota_json"; then
        sed -i "s/\"$user\":[0-9]*/\"$user\":0/g" "$quota_json"
    else
        sed -i -e 's/}$/,/' -e "s/$/\"$user\":0}/" "$quota_json"
    fi
}

# === 流量统计 / Telegram 推送 / 用户用量展示 (Python 引擎) ===
# 说明: 这些功能由内嵌的 Python 脚本实现，每次调用时同步写出到 $WORKDIR/mtp_stats.py
#   bash 侧仅保留系统/服务/交互逻辑与薄封装入口，命令入口与 Cron 保持不变

STATS_PY_FILE="$WORKDIR/mtp_stats.py"

stats_py() {
    mkdir -p "$WORKDIR"
    cat > "$STATS_PY_FILE" <<'PYEOF'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Telemt 流量统计 / Telegram 推送 / 用户用量展示（由 mtp-new.sh 调用）"""
import base64
import datetime
import json
import os
import re
import sys
import urllib.parse
import urllib.request

TOML = os.environ.get('TELEMT_TOML', '/etc/telemt.toml')
QUOTA = os.environ.get('TELEMT_QUOTA', '/etc/telemt_quota.json')
LOG = os.environ.get('TELEMT_LOG', '/var/log/telemt_traffic.log')
EXHAUSTED = os.environ.get('TELEMT_EXHAUSTED', '/etc/telemt_exhausted.json')
TG_CONF = os.environ.get('TELEMT_TG_CONF', '/etc/telemt_tg.conf')
TELEMT_CONF = os.environ.get('TELEMT_CONF', '/opt/mtproxy/config/telemt.conf')
DATA_DIR = os.environ.get('TELEMT_DATA_DIR', '/opt/mtproxy/exhausteddata')

RED = '\033[31m'
GREEN = '\033[32m'
YELLOW = '\033[33m'
BLUE = '\033[36m'
PLAIN = '\033[0m'

RE_SECTION = re.compile(r'^\[([^\]]+)\]\s*$')
RE_SIZE = re.compile(r'([0-9.]+)([KMGT]?B)')
SIZE_MULT = {'B': 1, 'KB': 1024, 'MB': 1048576, 'GB': 1073741824, 'TB': 1099511627776}

DEBUG = os.environ.get('DEBUG_FLAG', '0') == '1'


def dbg(*args):
    if DEBUG:
        print('[mtp_stats][调试]', *args, file=sys.stderr)


def fmt_bytes(b):
    try:
        b = int(b)
    except (TypeError, ValueError):
        b = 0
    if b >= 1073741824:
        return '%.2fGB' % (b / 1073741824.0)
    if b >= 1048576:
        return '%.1fMB' % (b / 1048576.0)
    if b >= 1024:
        return '%.1fKB' % (b / 1024.0)
    return '%dB' % b


def parse_sections(path):
    sections = {}
    current = None
    try:
        f = open(path, encoding='utf-8', errors='replace')
    except OSError:
        return sections
    with f:
        for raw in f:
            line = raw.rstrip('\n').rstrip('\r')
            m = RE_SECTION.match(line.strip())
            if m:
                current = m.group(1)
                sections[current] = []
                continue
            if current is None:
                continue
            s = line.strip()
            if not s or s.startswith('#'):
                continue
            if '=' not in s:
                continue
            k = s.split('=', 1)[0].strip().strip('"').strip("'").strip()
            v = s.split('=', 1)[1].strip().strip('"').strip("'").strip()
            if k:
                sections[current].append((k, v))
    return sections


def read_json(path, default):
    try:
        with open(path, encoding='utf-8') as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


def write_json(path, data):
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f)


def read_conf(path):
    conf = {}
    try:
        f = open(path, encoding='utf-8', errors='replace')
    except OSError:
        return conf
    with f:
        for raw in f:
            line = raw.strip()
            if not line or line.startswith('#'):
                continue
            if '=' in line:
                k, v = line.split('=', 1)
                conf[k.strip()] = v.strip()
    return conf


def bj_time():
    return datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8)))


def now_str():
    return datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')


def get_exhausted(user):
    ex = read_json(EXHAUSTED, {})
    ts = ex.get(user, '')
    if not ts:
        return ''
    if ts[:7] == datetime.datetime.now().strftime('%Y-%m'):
        return ts
    return ''


def record_exhausted(user, ts):
    if get_exhausted(user):
        return 1
    ex = read_json(EXHAUSTED, {})
    ex[user] = ts
    write_json(EXHAUSTED, ex)
    return 0


def parse_size_bytes(s):
    m = RE_SIZE.search(s)
    if not m:
        return None
    val = float(m.group(1)) * SIZE_MULT.get(m.group(2), 1)
    return int(val)


def quota_used(quota, user):
    return int(quota.get(user, 0) or 0)


def update_total_cache():
    if not os.path.exists(LOG):
        return
    os.makedirs(DATA_DIR, exist_ok=True)
    state_file = os.path.join(DATA_DIR, 'telemt_total.json')
    offset = 0
    cache = {}
    if os.path.exists(state_file):
        try:
            with open(state_file, encoding='utf-8') as f:
                lines = f.read().split('\n')
            if lines and lines[0].startswith('OFFSET '):
                offset = int(lines[0].split()[1])
                for ln in lines[1:]:
                    parts = ln.split()
                    if len(parts) >= 3:
                        cache[(parts[0], parts[1])] = int(float(parts[2]))
        except (ValueError, IndexError, OSError):
            offset = 0
            cache = {}
    try:
        log_size = os.path.getsize(LOG)
    except OSError:
        return
    if log_size < offset:
        offset = 0
        cache = {}
        if os.path.exists(state_file):
            os.remove(state_file)
    if log_size <= offset:
        return
    with open(LOG, 'rb') as f:
        f.seek(offset)
        new_data = f.read(log_size - offset)
    for raw in new_data.decode('utf-8', 'replace').split('\n'):
        if not raw:
            continue
        fields = raw.split(' | ')
        if len(fields) < 3:
            continue
        user = fields[0].strip()
        if not user:
            continue
        v = parse_size_bytes(fields[1])
        if v is None or v <= 0:
            continue
        ts = fields[2].strip()
        if len(ts) < 10:
            continue
        month = ts[:7]
        key = (user, month)
        if key not in cache or v > cache[key]:
            cache[key] = v
    tmp = state_file + '.tmp'
    with open(tmp, 'w', encoding='utf-8') as f:
        f.write('OFFSET %d\n' % log_size)
        for (user, month), val in sorted(cache.items()):
            f.write('%s %s %d\n' % (user, month, val))
    os.replace(tmp, state_file)


def snapshot():
    if not os.path.exists(TOML):
        dbg('snapshot: TOML 不存在 %s' % TOML)
        return 1
    sections = parse_sections(TOML)
    quota = read_json(QUOTA, {})
    if not os.path.exists(QUOTA):
        dbg('snapshot: QUOTA 不存在 %s' % QUOTA)
        return 0
    if not os.path.exists(LOG):
        open(LOG, 'a').close()
    now = now_str()
    rows = []
    for user, limit_s in sections.get('access.user_data_quota', []):
        if not user:
            continue
        try:
            limit_bytes = int(limit_s)
        except ValueError:
            continue
        used_bytes = quota_used(quota, user)
        used_s = fmt_bytes(used_bytes)
        limit_s = fmt_bytes(limit_bytes)
        if limit_bytes > 0 and used_bytes >= limit_bytes:
            if not record_exhausted(user, now):
                rows.append('%s | 用尽流量: 已用 %s / 限额 %s | %s' % (user, used_s, limit_s, now))
        rows.append('%s | 已用 %s / 限额 %s | %s' % (user, used_s, limit_s, now))
    with open(LOG, 'a', encoding='utf-8') as f:
        for r in rows:
            f.write(r + '\n')
    update_total_cache()
    dbg('snapshot: %s 个配额用户, 追加 %d 行, LOG=%s' % (len(sections.get('access.user_data_quota', [])), len(rows), LOG))
    return 0


def quota_rows():
    sections = parse_sections(TOML)
    quota = read_json(QUOTA, {})
    rows = []
    for user, limit_s in sections.get('access.user_data_quota', []):
        if not user:
            continue
        try:
            limit_bytes = int(limit_s)
        except ValueError:
            continue
        used_bytes = quota_used(quota, user)
        rows.append((user, used_bytes, limit_bytes))
    return rows


def usage_report():
    sections = parse_sections(TOML)
    if not sections:
        print(YELLOW + '未检测到 Telemt 配置文件！' + PLAIN)
        return 1
    snapshot()
    if not os.path.exists(QUOTA):
        print(YELLOW + '尚无流量账单 (/etc/telemt_quota.json 不存在)，请先安装 Telemt 并产生流量。' + PLAIN)
        return 0
    cur_month = datetime.datetime.now().strftime('%Y-%m')
    out = []
    out.append('')
    out.append('==================================================')
    out.append(GREEN + '       Telemt 本月流量使用统计 (%s)      ' % cur_month + PLAIN)
    out.append('==================================================')
    out.append('  %-16s %-10s %-10s %-10s %-8s %s' % ('用户名', '已用', '限额', '剩余', '使用率', '耗尽时间'))
    out.append('  ----------------------------------------------------------------')
    total_used = 0
    total_limit = 0
    exhausted_count = 0
    has_row = 0
    for user, used_bytes, limit_bytes in quota_rows():
        used_s = fmt_bytes(used_bytes)
        limit_s = fmt_bytes(limit_bytes)
        remain = limit_bytes - used_bytes
        if remain < 0:
            remain = 0
        remain_s = fmt_bytes(remain)
        if limit_bytes > 0:
            pct = '%.1f' % (used_bytes * 100.0 / limit_bytes)
        else:
            pct = '0.0'
        ex_t = get_exhausted(user)
        if not ex_t:
            ex_t = '-'
        if limit_bytes > 0 and used_bytes >= limit_bytes:
            exhausted_count += 1
        total_used += used_bytes
        total_limit += limit_bytes
        has_row = 1
        out.append('  %-16s %-10s %-10s %-10s %-8s %s' % (user, used_s, limit_s, remain_s, pct + '%', ex_t))
    out.append('  ----------------------------------------------------------------')
    if not has_row:
        out.append(YELLOW + '  暂未配置任何带配额的用户。' + PLAIN)
    else:
        out.append('  本月总用量: %s    总限额: %s    超限/耗尽用户: %d 个' % (fmt_bytes(total_used), fmt_bytes(total_limit), exhausted_count))
    out.append('==================================================')
    out.append(BLUE + '  本月最近流量流水 (按用户维度, 时间在行尾):' + PLAIN)
    if os.path.exists(LOG):
        pat = re.compile(r'\| %s-\d\d \d\d:\d\d:\d\d$' % cur_month)
        recent = [ln for ln in open(LOG, encoding='utf-8', errors='replace') if pat.search(ln.rstrip('\n'))][-10:]
        if recent:
            for ln in recent:
                out.append(ln.rstrip('\n'))
        else:
            out.append(YELLOW + '  本月暂无流水记录。' + PLAIN)
    else:
        out.append(YELLOW + '  暂无流水记录。' + PLAIN)
    sys.stdout.write('\n'.join(out) + '\n')
    return 0


def total_report():
    if not os.path.exists(LOG):
        print(YELLOW + '暂无流水日志 (/var/log/telemt_traffic.log)，无法统计历史累计总流量。' + PLAIN)
        return 0
    update_total_cache()
    state_file = os.path.join(DATA_DIR, 'telemt_total.json')
    if not os.path.exists(state_file):
        print(YELLOW + '暂无历史累计数据，请先产生流量或等待快照。' + PLAIN)
        return 0
    cache = {}
    with open(state_file, encoding='utf-8') as f:
        for ln in f:
            parts = ln.split()
            if len(parts) >= 3 and parts[0] != 'OFFSET':
                cache[(parts[0], parts[1])] = int(float(parts[2]))
    if not cache:
        print(YELLOW + '  暂无可解析的历史流量记录。' + PLAIN)
        return 0
    totals = {}
    for (user, month), val in cache.items():
        t = totals.setdefault(user, [0, 0])
        t[0] += val
        t[1] += 1
    ranked = sorted(totals.items(), key=lambda kv: kv[1][0], reverse=True)
    print('')
    print('==================================================')
    print(GREEN + '       总流量使用统计 (历史累计, 按已用排序)      ' + PLAIN)
    print('==================================================')
    print('  %-6s %-16s %-12s %-8s' % ('排名', '用户名', '历史累计', '统计月数'))
    print('  ----------------------------------------------------------------')
    rank = 0
    grand_bytes = 0
    total_users = 0
    for user, (tb, m) in ranked:
        rank += 1
        total_users += 1
        print('  %-6d %-16s %-12s %-8d' % (rank, user, fmt_bytes(tb), m))
        grand_bytes += tb
    print('  ----------------------------------------------------------------')
    print('  历史累计总用量: %s    有流量记录用户: %d 个' % (fmt_bytes(grand_bytes), total_users))
    print('==================================================')
    print(BLUE + '  说明: 历史累计 = 各用户每月流量快照的最大值跨月求和；缓存于 %s/telemt_total.json，仅增量解析新增流水，卸载或手动重置不影响已累计流量。' % DATA_DIR + PLAIN)
    return 0


def mask_ip(ip):
    parts = ip.split('.')
    if len(parts) == 4:
        return '.'.join(parts[:3]) + '.***'
    l = len(ip)
    return (ip[:l - 3] if l > 3 else ip[:1]) + '***'


def report_text():
    rows = quota_rows()
    total_used = 0
    total_limit = 0
    exhausted_count = 0
    has_row = 0
    body = ''
    for user, used_bytes, limit_bytes in rows:
        used_s = fmt_bytes(used_bytes)
        limit_s = fmt_bytes(limit_bytes)
        remain = limit_bytes - used_bytes
        if remain < 0:
            remain = 0
        remain_s = fmt_bytes(remain)
        if limit_bytes > 0:
            pct = '%.1f' % (used_bytes * 100.0 / limit_bytes)
        else:
            pct = '0.0'
        ex_t = get_exhausted(user)
        if not ex_t:
            ex_t = '-'
        if limit_bytes > 0 and used_bytes >= limit_bytes:
            exhausted_count += 1
        total_used += used_bytes
        total_limit += limit_bytes
        has_row = 1
        body += '%-14s %-9s %-9s %-9s %-7s %s\n' % (user, used_s, limit_s, remain_s, pct + '%', ex_t)

    bj_t = bj_time().strftime('%Y-%m-%d %H:%M:%S')
    utc_t = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%d %H:%M:%S')
    host = ''
    try:
        import socket
        host = socket.gethostname()
    except Exception:
        pass
    ip_line = ''
    try:
        req = urllib.request.Request('https://api.ipify.org', headers={'User-Agent': 'Mozilla'})
        pub_ip = urllib.request.urlopen(req, timeout=4).read().decode('utf-8', 'replace').strip()
        if pub_ip:
            ip_line = '🌐 IP 信息: %s\n' % mask_ip(pub_ip)
    except Exception:
        pass

    msg = '🎮 MTProxy 本月流量统计日报 (服务器报告)\n'
    msg += '🕐 运行时间: %s (北京时间)\n' % bj_t
    msg += '🕐 运行时间: %s (UTC)\n' % utc_t
    if ip_line:
        msg += ip_line
    if host:
        msg += '🖥️ 服务器: %s\n' % host
    msg += '\n'
    msg += '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
    msg += '%-14s %-9s %-9s %-9s %-7s %s\n' % ('用户名', '已用', '限额', '剩余', '使用率', '耗尽时间')
    msg += body
    msg += '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
    if not has_row:
        msg += '暂未配置任何带配额的用户\n'
    else:
        msg += '本月总用量: %s   总限额: %s   超限/耗尽: %d 人\n' % (fmt_bytes(total_used), fmt_bytes(total_limit), exhausted_count)
    return msg


def split_parts(text, max_bytes=3700):
    parts = []
    cur = ''
    cur_bytes = 0
    lines = text.split('\n')
    for i, ln in enumerate(lines):
        add = ln if i == 0 else '\n' + ln
        add_bytes = len(add.encode('utf-8'))
        if cur_bytes + add_bytes > max_bytes and cur_bytes > 0:
            parts.append(cur)
            cur = ln
            cur_bytes = len(ln.encode('utf-8'))
        else:
            cur += add
            cur_bytes += add_bytes
    if cur_bytes > 0:
        parts.append(cur)
    return parts


def tg_send(text):
    if not text:
        return 1
    if not os.path.exists(TG_CONF):
        print(YELLOW + '未配置 Telegram 推送 (/etc/telemt_tg.conf)。' + PLAIN)
        return 1
    conf = read_conf(TG_CONF)
    token = conf.get('BOT_TOKEN', '')
    chat = conf.get('CHAT_ID', '')
    if not token:
        print(RED + '未配置 BOT_TOKEN！' + PLAIN)
        return 1
    if not chat:
        print(RED + '未配置 CHAT_ID！' + PLAIN)
        return 1
    url = 'https://api.telegram.org/bot%s/sendMessage' % token
    parts = split_parts(text)
    if not parts:
        parts = [text]
    total = len(parts)
    fail = 0
    for idx, part in enumerate(parts, 1):
        body = part
        if total > 1:
            body = '📨 消息 %d/%d\n\n%s' % (idx, total, part)
        data = urllib.parse.urlencode({
            'chat_id': chat,
            'parse_mode': 'HTML',
            'text': body,
        }).encode('utf-8')
        try:
            resp = urllib.request.urlopen(urllib.request.Request(url, data=data), timeout=20)
            res = resp.read().decode('utf-8', 'replace')
        except Exception as e:
            fail += 1
            print(RED + 'Telegram 推送失败(第 %d/%d 条): %s' % (idx, total, str(e)[:200]) + PLAIN, file=sys.stderr)
            continue
        if '"ok":true' in res:
            continue
        fail += 1
        print(RED + 'Telegram 推送失败(第 %d/%d 条): %s' % (idx, total, res[:200]) + PLAIN, file=sys.stderr)
    return 1 if fail > 0 else 0


def tg_usage_report(force):
    sections = parse_sections(TOML)
    if not sections:
        print(YELLOW + '未检测到 Telemt 配置文件！' + PLAIN)
        return 1
    if not os.path.exists(TG_CONF):
        dbg('tg_report: TG_CONF 不存在 %s' % TG_CONF)
        return 0
    conf = read_conf(TG_CONF)
    if not force:
        bj_now = bj_time().strftime('%H:%M')
        want = conf.get('TG_TIME') or conf.get('TG_PUSH_TIME') or ''
        if bj_now != want:
            dbg('tg_report: 非推送时间点, bj=%s want=%s, 跳过' % (bj_now, want))
            return 0
    dbg('tg_report: force=%s, 准备推送' % force)
    snapshot()
    return tg_send(report_text())


def tg_secret(secret, domain):
    full = 'ee' + secret + domain.encode('utf-8').hex()
    return base64.urlsafe_b64encode(bytes.fromhex(full)).decode().rstrip('=')


def user_display(name, ipv4, ipv6):
    sections = parse_sections(TOML)
    conf = read_conf(TELEMT_CONF)
    domain = conf.get('DOMAIN', '')
    port = conf.get('PORT', '')
    ip_mode = conf.get('IP_MODE', 'v4')
    hex_domain = domain.encode('utf-8').hex()
    port_map = dict(sections.get('access.user_ports', []))
    quota_map = dict(sections.get('access.user_data_quota', []))
    expire_map = dict(sections.get('access.user_expirations', []))
    speed_map = dict(sections.get('access.user_speed_limits', []))
    user_map = dict(sections.get('access.users', []))
    quota = read_json(QUOTA, {})

    secret = user_map.get(name, '')
    link_port = port
    port_lbl = '全局共享'
    if name in port_map and port_map[name]:
        link_port = port_map[name]
        port_lbl = '专属专线'

    quota_str = '未限流'
    status_str = GREEN + '🟢 正常' + PLAIN
    ex_str = ''
    if name in quota_map and quota_map[name]:
        try:
            limit_bytes = int(quota_map[name])
        except ValueError:
            limit_bytes = 0
        used_bytes = quota_used(quota, name)
        used_mb = int(used_bytes / 1048576)
        limit_mb = int(limit_bytes / 1048576)
        limit_gb = '%.2f' % (limit_bytes / 1073741824.0)
        if limit_bytes > 0 and used_bytes >= limit_bytes:
            quota_str = '已用: ' + RED + '%dMB' % used_mb + PLAIN + ' / 总限额: %sGB (' % limit_gb + RED + '已超限' + PLAIN + ')'
            status_str = RED + '🔴 断流封禁中（流量耗尽或到期）' + PLAIN
            ex_t = get_exhausted(name)
            if ex_t:
                ex_str = '   ⏱️  本月流量耗尽时间: %s' % ex_t
        else:
            pct = '%.1f' % (used_mb * 100.0 / limit_mb) if limit_mb > 0 else '0.0'
            quota_str = '已用: ' + YELLOW + '%dMB' % used_mb + PLAIN + ' / 总限额: %sGB (使用率: %s%%)' % (limit_gb, pct)

    expire_str = '永久有效'
    if name in expire_map and expire_map[name]:
        end_iso = expire_map[name].split('+')[0].replace('T', ' ')
        current_iso = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        if current_iso > end_iso:
            expire_str = RED + '已过期 (%s)' % end_iso + PLAIN
            status_str = RED + '🔴 断流封禁中（流量耗尽或到期）' + PLAIN
        else:
            expire_str = '%s 到期' % end_iso

    speed_str = '无限制极速'
    if name in speed_map and speed_map[name]:
        sp = speed_map[name].split()
        up_s = sp[0] if sp else ''
        down_s = sp[1] if len(sp) > 1 else up_s
        speed_str = '上行 %s MB/s ｜ 下行 %s MB/s' % (up_s, down_s)

    out = []
    out.append('===========================================')
    out.append(GREEN + '        用户 %s 当前配置       ' % name + PLAIN)
    out.append('===========================================')
    out.append('👤 用户名: ' + YELLOW + name + PLAIN + '  (状态: %s)' % status_str)
    out.append('   🔑 密钥: %s' % secret)
    out.append('   🌐 端口: ' + RED + link_port + PLAIN + ' [%s]' % port_lbl)
    out.append('   📅 到期: %s' % expire_str)
    out.append('   📊 配额: %s' % quota_str)
    if ex_str:
        out.append(ex_str)
    out.append('   🚀 限速: %s' % speed_str)
    if secret:
        b64 = tg_secret(secret, domain)
        if ip_mode in ('v4', 'dual') and ipv4:
            out.append('   IPv4: tg://proxy?server=%s&port=%s&secret=%s' % (ipv4, link_port, b64))
        if ip_mode in ('v6', 'dual') and ipv6:
            out.append('   IPv6: tg://proxy?server=%s&port=%s&secret=%s' % (ipv6, link_port, b64))
    out.append('-------------------------------------------')
    sys.stdout.write('\n'.join(out) + '\n')
    return 0


def users_display(ipv4, ipv6):
    sections = parse_sections(TOML)
    conf = read_conf(TELEMT_CONF)
    domain = conf.get('DOMAIN', '')
    port = conf.get('PORT', '')
    ip_mode = conf.get('IP_MODE', 'v4')
    hex_domain = domain.encode('utf-8').hex()
    port_map = dict(sections.get('access.user_ports', []))
    quota_map = dict(sections.get('access.user_data_quota', []))
    expire_map = dict(sections.get('access.user_expirations', []))
    speed_map = dict(sections.get('access.user_speed_limits', []))
    quota = read_json(QUOTA, {})

    out = []
    out.append('===========================================')
    out.append(GREEN + '      Telemt 用户列表及专属分享链接       ' + PLAIN)
    out.append('===========================================')
    for user, secret in sections.get('access.users', []):
        if not user or not secret:
            continue
        full_secret = 'ee' + secret + hex_domain
        link_port = port
        port_lbl = '全局共享'
        if user in port_map and port_map[user]:
            link_port = port_map[user]
            port_lbl = '专属专线'
        quota_str = '未限流'
        status_str = GREEN + '🟢 正常' + PLAIN
        if user in quota_map and quota_map[user]:
            try:
                limit_bytes = int(quota_map[user])
            except ValueError:
                limit_bytes = 0
            used_bytes = quota_used(quota, user)
            used_mb = int(used_bytes / 1048576)
            limit_mb = int(limit_bytes / 1048576)
            limit_gb = '%.2f' % (limit_bytes / 1073741824.0)
            if limit_bytes > 0 and used_bytes >= limit_bytes:
                quota_str = '已用: ' + RED + '%dMB' % used_mb + PLAIN + ' / 总限额: %sGB (' % limit_gb + RED + '已超限' + PLAIN + ')'
                status_str = RED + '🔴 断流封禁中（流量耗尽或到期）' + PLAIN
                ex_t = get_exhausted(user)
                if ex_t:
                    quota_str = quota_str + '  ⏱️ 耗尽于: %s' % ex_t
            else:
                pct = '%.1f' % (used_mb * 100.0 / limit_mb) if limit_mb > 0 else '0.0'
                quota_str = '已用: ' + YELLOW + '%dMB' % used_mb + PLAIN + ' / 总限额: %sGB (使用率: %s%%)' % (limit_gb, pct)
        expire_str = '永久有效'
        if user in expire_map and expire_map[user]:
            end_iso = expire_map[user].split('+')[0].replace('T', ' ')
            current_iso = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            if current_iso > end_iso:
                expire_str = RED + '已过期 (%s)' % end_iso + PLAIN
                status_str = RED + '🔴 断流封禁中（流量耗尽或到期）' + PLAIN
            else:
                expire_str = '%s 到期' % end_iso
        speed_str = '   🚀 独立带宽：' + GREEN + '无限制极速' + PLAIN
        if user in speed_map and speed_map[user]:
            sp = speed_map[user].split()
            up_s = sp[0] if sp else ''
            down_s = sp[1] if len(sp) > 1 else up_s
            speed_str = '   🚀 独立带宽：' + YELLOW + '↑上行 %s MB/s' % up_s + PLAIN + ' ｜ ' + BLUE + '↓下行 %s MB/s' % down_s + PLAIN
        out.append('👤 用户名: ' + YELLOW + user + PLAIN + '  (密钥: %s | 状态: %s)' % (secret, status_str))
        out.append('   🌐 端口: ' + RED + link_port + PLAIN + ' [%s]   📅 到期: %s' % (port_lbl, expire_str))
        out.append('   📊 %s' % quota_str)
        out.append(speed_str)
        b64 = tg_secret(secret, domain)
        if ip_mode in ('v4', 'dual') and ipv4:
            out.append('   IPv4: tg://proxy?server=%s&port=%s&secret=%s' % (ipv4, link_port, b64))
        if ip_mode in ('v6', 'dual') and ipv6:
            out.append('   IPv6: tg://proxy?server=%s&port=%s&secret=%s' % (ipv6, link_port, b64))
        out.append('-------------------------------------------')
    sys.stdout.write('\n'.join(out) + '\n')
    return 0


def main(argv):
    cmd = argv[0] if argv else ''
    dbg('入口: %s %s' % (cmd, ' '.join(argv[1:])))
    if cmd == 'snapshot':
        return snapshot()
    if cmd == 'usage':
        return usage_report()
    if cmd == 'usage_total':
        return total_report()
    if cmd == 'users':
        return users_display(_get_opt(argv, '--ipv4', ''), _get_opt(argv, '--ipv6', ''))
    if cmd == 'user':
        return user_display(_get_opt(argv, '--name', ''), _get_opt(argv, '--ipv4', ''), _get_opt(argv, '--ipv6', ''))
    if cmd == 'tg_report':
        return tg_usage_report('--force' in argv)
    if cmd == 'tg_send':
        return tg_send(_get_opt(argv, '--text', ''))
    return 1


def _get_opt(argv, key, default):
    try:
        i = argv.index(key)
        if i + 1 < len(argv):
            return argv[i + 1]
    except ValueError:
        pass
    return default


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
PYEOF
    python3 "$STATS_PY_FILE" "$@"
}

# 清除某用户流量耗尽时间记录
clear_exhausted_record() {
    local user="$1"
    local ex_file="/etc/telemt_exhausted.json"
    [ ! -f "$ex_file" ] && return
    grep -q "\"$user\":" "$ex_file" || return
    sed -i "s/\"$user\":\"[^\"]*\",//; s/,\"$user\":\"[^\"]*\"//; s/\"$user\":\"[^\"]*\"//" "$ex_file"
    if [ ! -s "$ex_file" ]; then
        echo "{}" > "$ex_file"
    fi
}

# 流量快照（薄封装）：读取配额账单，记录耗尽时间并追加流水，更新历史累计缓存
snapshot_traffic_stats() {
    stats_py snapshot
    return $?
}

# 本月流量使用统计报表（usage 命令与交互菜单复用）
traffic_usage_report() {
    if [ ! -f "/etc/telemt.toml" ]; then
        echo -e "${YELLOW}未检测到 Telemt 配置文件！${PLAIN}"
        return 1
    fi
    stats_py usage
    return $?
}

# 总流量使用统计（历史累计，按已用排序）
traffic_total_report() {
    stats_py usage_total
    return $?
}

# 发送一条文本消息到 Telegram（薄封装）
tg_send() {
    stats_py tg_send --text "$1"
    return $?
}

# 生成本月统计并推送到 Telegram（tg_report 手动推送 / tg_autopush 定时判断）
tg_usage_report() {
    if [ "$1" = "force" ]; then
        stats_py tg_report --force
    else
        stats_py tg_report
    fi
    return $?
}

# 配置 Telegram 推送（非交互用 TELEMT_TG_TOKEN / TELEMT_TG_CHAT / TELEMT_TG_TIME）
setup_tg_push() {
    echo -e ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
    echo -e "${GREEN}      Telegram 流量统计推送配置     ${PLAIN}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
    
    local OLD_TOKEN="" OLD_CHAT="" OLD_TIME=""
    if [ -f /etc/telemt_tg.conf ]; then
        source /etc/telemt_tg.conf
        OLD_TOKEN="$BOT_TOKEN"
        OLD_CHAT="$CHAT_ID"
        OLD_TIME="$TG_TIME"
        echo -e "  当前配置: Token=${BOT_TOKEN:0:5}...  ChatID=${CHAT_ID}  日报时间=${TG_TIME:-23:00}"
        echo ""
    fi
    
    local TOKEN="${TELEMT_TG_TOKEN:-}"
    local CHAT="${TELEMT_TG_CHAT:-}"
    local TGTIME="${TELEMT_TG_TIME:-}"
    
    if [ -n "$NON_INTERACTIVE" ]; then
        # 未提供的环境变量沿用已有配置，可只更换其中一个
        [ -z "$TOKEN" ] && TOKEN="$OLD_TOKEN"
        [ -z "$CHAT" ] && CHAT="$OLD_CHAT"
        [ -z "$TGTIME" ] && TGTIME="$OLD_TIME"
        if [ -z "$TOKEN" ] || [ -z "$CHAT" ]; then
            echo -e "${RED}非交互模式需提供 TELEMT_TG_TOKEN 与 TELEMT_TG_CHAT（或已有可沿用的配置）！${PLAIN}"
            return 2
        fi
    else
        read -p "请输入 Telegram Bot Token (直接回车保持不变): " TOKEN
        read -p "请输入接收消息的 Chat ID (直接回车保持不变): " CHAT
        [ -z "$TOKEN" ] && TOKEN="$OLD_TOKEN"
        [ -z "$CHAT" ] && CHAT="$OLD_CHAT"
        if [ -z "$TOKEN" ] || [ -z "$CHAT" ]; then
            echo -e "${RED}Token 与 Chat ID 不能为空！${PLAIN}"
            return 2
        fi
    fi
    [ -z "$TGTIME" ] && TGTIME="$OLD_TIME"
    [ -z "$TGTIME" ] && TGTIME="$TG_PUSH_TIME"
    
    cat > /etc/telemt_tg.conf <<EOF
# Telemt 流量统计 Telegram 推送配置
BOT_TOKEN=$TOKEN
CHAT_ID=$CHAT
TG_TIME=${TGTIME:-$TG_PUSH_TIME}
EOF
    
    install_tg_cron
    echo -e "${GREEN}✅ 已保存 Telegram 推送配置，并注册每日自动日报 Cron（北京时间 ${TGTIME}）。${PLAIN}"
    if tg_send "✅ MTProxy 流量统计推送已启用

每天北京时间 ${TGTIME} 将自动发送本月流量统计到本会话"; then
        echo -e "${GREEN}测试消息发送成功。${PLAIN}"
    else
        echo -e "${YELLOW}测试消息发送失败，请检查 Token / ChatID 是否正确。${PLAIN}"
    fi
    return 0
}

# 注册每日日报 Cron（每小时触发一次，由 tg_usage_report 内部判断北京时间是否到点）
install_tg_cron() {
    local cron_cmd="0 * * * * /usr/local/bin/mtp tg_autopush >/dev/null 2>&1"
    (crontab -l 2>/dev/null | grep -v "mtp tg_"; echo "$cron_cmd") | crontab -
}

# 移除每日日报 Cron
remove_tg_cron() {
    crontab -l 2>/dev/null | grep -v "mtp tg_" | crontab -
}

install_telemt() {
    prefetch_ips
    echo -e "${BLUE}正在准备安装 Telemt 高性能版...${PLAIN}"
    
    if [[ "$INIT_SYSTEM" != "systemd" && "$INIT_SYSTEM" != "openrc" ]]; then
        echo -e "${RED}您的系统 ($INIT_SYSTEM) 不受支持！Telemt 仅支持 Systemd 和 OpenRC。${PLAIN}"
        return 1
    fi

    ARCH=$(uname -m)
    case $ARCH in
        x86_64) TELEMT_ARCH="amd64" ;;
        aarch64) TELEMT_ARCH="arm64" ;;
        *) echo -e "${RED}不支持的架构: $ARCH${PLAIN}"; return 1 ;;
    esac
    
    mkdir -p "$BIN_DIR"
    
    # 优先检测本地同级目录下是否已有编译好的二进制文件
    LOCAL_BIN=""
    TARGET_BIN="telemt-linux-${TELEMT_ARCH}"
    
    if [ -f "./${TARGET_BIN}" ]; then
        LOCAL_BIN="./${TARGET_BIN}"
    elif [ -f "${SCRIPT_DIR}/${TARGET_BIN}" ]; then
        LOCAL_BIN="${SCRIPT_DIR}/${TARGET_BIN}"
    elif [ -f "./telemt" ]; then
        LOCAL_BIN="./telemt"
    elif [ -f "${SCRIPT_DIR}/telemt" ]; then
        LOCAL_BIN="${SCRIPT_DIR}/telemt"
    fi

    if [ -n "$LOCAL_BIN" ]; then
        echo -e "${GREEN}检测到本地同级目录已存在预编译二进制: $(basename "$LOCAL_BIN")${PLAIN}"
        echo -e "${BLUE}跳过在线下载，直接使用本地文件...${PLAIN}"
        cp "$LOCAL_BIN" "$BIN_DIR/telemt"
        chmod +x "$BIN_DIR/telemt"
    else
        # --- 在线下载逻辑 ---
        # 本仓库自持源（由 sync-deps.yml 从上游镜像），如需切回上游源，取消下行注释并注释上行
        DOWNLOAD_URL="https://github.com/jyucoeng/singbox-tools/releases/download/Go-Rust/${TARGET_BIN}"
        # DOWNLOAD_URL="https://github.com/0xdabiaoge/MTProxy/releases/download/Go-Rust/${TARGET_BIN}"
        
        echo -e "${BLUE}未找到本地文件，尝试从个人 GitHub 仓库下载 (${TARGET_BIN})...${PLAIN}"
        wget -qO "$BIN_DIR/telemt" "$DOWNLOAD_URL"
        
        if [ $? -ne 0 ] || [ ! -f "$BIN_DIR/telemt" ]; then
            echo -e "${RED}下载或解压失败！请检查您的网络连接或 GitHub 访问情况。${PLAIN}"
            return 1
        fi
        chmod +x "$BIN_DIR/telemt"
        echo -e "${GREEN}Telemt 版下载成功。${PLAIN}"
    fi

    # 无交互安装：优先使用环境变量，缺省自动填充；交互安装：逐项询问
    if [ -n "$NON_INTERACTIVE" ]; then
        DOMAIN="${DOMAIN:-www.apple.com}"
        IP_MODE="${IP_MODE:-v4}"
        PORT="${PORT:-443}"
        TELEMT_USER="${TELEMT_USER:-admin}"
        SECRET="${SECRET:-$(generate_secret)}"
        NEW_QUOTA="${TELEMT_QUOTA:-}"
        NEW_EXPIRE="${TELEMT_EXPIRE:-}"
        SPEED_UP="${TELEMT_SPEED_UP:-}"
        SPEED_DOWN="${TELEMT_SPEED_DOWN:-}"
        if [ -n "$SPEED_UP" ]; then
            [ -z "$SPEED_DOWN" ] && SPEED_DOWN="$SPEED_UP"
            NEW_SPEED="$SPEED_UP $SPEED_DOWN"
        else
            NEW_SPEED=""
        fi
    else
        read -p "请输入伪装域名 (默认 www.apple.com): " DOMAIN
        [ -z "$DOMAIN" ] && DOMAIN="www.apple.com"
        
        IP_MODE=$(select_ip_mode)
        
        PORT=$(read_valid_port "请输入端口 (默认 443): " "443")
        
        read -p "请为初始管理员设置一个用户名 (默认 admin): " TELEMT_USER
        [ -z "$TELEMT_USER" ] && TELEMT_USER="admin"
        
        # 若已预先设置 SECRET 环境变量则沿用，否则自动生成（保证多次安装密钥一致）
        [ -z "$SECRET" ] && SECRET=$(generate_secret)

        echo ""
        read -p "请输入此用户的月度流量配额 (GB为单位, 直接回车表示不启用限流): " NEW_QUOTA
        NEW_QUOTA=$(echo "$NEW_QUOTA" | tr -d '\r ')
        if [[ -n "$NEW_QUOTA" && ! "$NEW_QUOTA" =~ ^[0-9.]+$ ]]; then
            echo -e "${RED}输入有误，配额必须是数字，将默认关闭该用户限流。${PLAIN}"
            NEW_QUOTA=""
        fi
        
        read -p "请输入此用户的强制到期日期 (格式 2026-10-01 或 2026-10-01 12:00:00, 回车表示永久): " NEW_EXPIRE
        NEW_EXPIRE=$(echo "$NEW_EXPIRE" | tr -d '\r' | xargs)
        NEW_SPEED=""
    fi
    
    # 统一校验
    case "$IP_MODE" in
        v4|v6|dual) ;;
        *) echo -e "${RED}无效的 IP_MODE: $IP_MODE (可选: v4 / v6 / dual)${PLAIN}"; return 1 ;;
    esac
    if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
        echo -e "${RED}端口无效: $PORT (必须是 1-65535 之间的数字)${PLAIN}"
        return 1
    fi
    if ! [[ "$TELEMT_USER" =~ ^[A-Za-z0-9_-]+$ ]]; then
        echo -e "${RED}用户名只能包含字母、数字、下划线或中划线！${PLAIN}"
        return 1
    fi
    if [[ -n "$NEW_QUOTA" && ! "$NEW_QUOTA" =~ ^[0-9.]+$ ]]; then
        echo -e "${RED}输入有误，配额必须是数字，将关闭该用户限流。${PLAIN}"
        NEW_QUOTA=""
    fi
    if ! [[ "$SECRET" =~ ^[0-9a-fA-F]{32}$ ]]; then
        echo -e "${RED}SECRET 必须是 32 位 hex 字符 (a-f/0-9)！当前值: $SECRET${PLAIN}"
        return 1
    fi
    debug_log "【调试】install_telemt: ARCH=$ARCH TELEMT_ARCH=$TELEMT_ARCH DOMAIN=$DOMAIN IP_MODE=$IP_MODE PORT=$PORT TELEMT_USER=$TELEMT_USER SECRET=$SECRET NEW_QUOTA=$NEW_QUOTA NEW_EXPIRE=$NEW_EXPIRE NEW_SPEED=$NEW_SPEED"
    echo -e "${GREEN}客户端连接密钥: $SECRET${PLAIN}"
    
    # 构造附加区块
    QUOTA_BLOCK=""
    if [ -n "$NEW_QUOTA" ]; then
        QUOTA_BYTES=$(awk "BEGIN {printf \"%.0f\", $NEW_QUOTA * 1073741824}")
        QUOTA_BLOCK="[access.user_data_quota]
$TELEMT_USER = $QUOTA_BYTES"
    fi

    EXPIRE_BLOCK=""
    if [ -n "$NEW_EXPIRE" ]; then
        if echo "$NEW_EXPIRE" | grep -q " "; then
            # 包含了具体时间，将空格替换为 T
            ISO_EXPIRE="$(echo "$NEW_EXPIRE" | tr ' ' 'T')+08:00"
        else
            # 仅输入了日期，默认尾缀为其当天的午夜 23:59:59
            ISO_EXPIRE="${NEW_EXPIRE}T23:59:59+08:00"
        fi
        EXPIRE_BLOCK="[access.user_expirations]
$TELEMT_USER = $ISO_EXPIRE"
    fi

    SPEED_BLOCK=""
    if [ -n "$NEW_SPEED" ]; then
        SPEED_BLOCK="[access.user_speed_limits]
$TELEMT_USER = \"$NEW_SPEED\""
    fi
    
    # Telemt 专有配置: 总是保存在 /etc/telemt.toml
    mkdir -p "/etc"
    cat > "/etc/telemt.toml" <<EOF
# === General Settings ===
[general]
use_middle_proxy = false

[general.modes]
classic = false
secure = false
tls = true

# === Server Binding ===
[server]
port = $PORT

[[server.listeners]]
ip = "0.0.0.0"
$(if [ "$IP_MODE" = "dual" ] || [ "$IP_MODE" = "v6" ]; then echo "
[[server.listeners]]
ip = \"::\"
"; fi)

# === Anti-Censorship & Masking ===
[censorship]
tls_domain = "$DOMAIN"
mask = true
tls_emulation = false

[access.users]
$TELEMT_USER = "$SECRET"

$QUOTA_BLOCK

$EXPIRE_BLOCK

$SPEED_BLOCK
EOF

    set_quota_record_zero "$TELEMT_USER"

    # 兼容脚本的读取记录
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_DIR/telemt.conf" <<EOF
PORT=$PORT
SECRET=$SECRET
DOMAIN=$DOMAIN
IP_MODE=$IP_MODE
MAIN_USER=$TELEMT_USER
EOF

    create_service_telemt
    check_service_status telemt
    
    # 按照 Telemt/MTG 现代客户端推荐的 Base64 Raw URL 编码构造 ee 密钥以突破截断
    RAW_SECRET_BYTES=$(echo -n "$SECRET" | sed 's/../\\x&/g')
    B64_SECRET=$(printf '\xee%b%b' "$RAW_SECRET_BYTES" "$DOMAIN" | base64 | tr -d '\r\n' | tr '+/' '-_' | tr -d '=')
    FULL_EE_SECRET="$B64_SECRET"
    show_info_telemt "$PORT" "$FULL_EE_SECRET" "$DOMAIN" "$IP_MODE"
    
    # 仅在设置了流量配额时才启用月度自动重置
    if [ -n "$NEW_QUOTA" ]; then
        if [ -n "$NON_INTERACTIVE" ]; then
            # 无交互模式：仅在显式指定 TELEMT_RESET_DAY 时启用
            if [ -n "${TELEMT_RESET_DAY:-}" ]; then
                reset_day="$TELEMT_RESET_DAY"
                cat > /etc/telemt_reset.conf <<REOF
# Telemt 流量配额自动重置配置
MODE=monthly
RESET_DAY=$reset_day
ONCE_DATE=
REOF
                install_reset_cron
                echo -e "${GREEN}✅ 已启用每月 ${reset_day} 号零点自动重置活跃用户流量。${PLAIN}"
            fi
        else
            echo -e ""
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
            read -p "是否启用流量配额月度自动重置？(y/n, 默认 y): " enable_reset
            enable_reset=$(echo "$enable_reset" | tr -d '\r ' | tr 'Y' 'y')
            [ -z "$enable_reset" ] && enable_reset="y"
            if [ "$enable_reset" == "y" ]; then
                read -p "请输入每月重置日 (直接回车默认为1号): " reset_day
                reset_day=$(echo "$reset_day" | tr -d '\r ')
                [ -z "$reset_day" ] && reset_day=1
                cat > /etc/telemt_reset.conf <<REOF
# Telemt 流量配额自动重置配置
MODE=monthly
RESET_DAY=$reset_day
ONCE_DATE=
REOF
                install_reset_cron
                echo -e "${GREEN}✅ 已启用每月 ${reset_day} 号零点自动重置活跃用户流量。${PLAIN}"
            fi
        fi
    fi

    # 注册每小时流量快照 Cron，用于记录各用户当月用量与耗尽时间
    install_traffic_cron
    echo -e "${GREEN}✅ 已启用每小时流量统计快照 (日志: /var/log/telemt_traffic.log)。${PLAIN}"

    # 若提供了 Telegram 推送参数则自动启用每日统计推送（否则不发送统计）
    if [ -n "${TELEMT_TG_TOKEN:-}" ] && [ -n "${TELEMT_TG_CHAT:-}" ]; then
        cat > /etc/telemt_tg.conf <<EOF
# Telemt 流量统计 Telegram 推送配置
BOT_TOKEN=$TELEMT_TG_TOKEN
CHAT_ID=$TELEMT_TG_CHAT
TG_TIME=${TELEMT_TG_TIME:-$TG_PUSH_TIME}
EOF
        install_tg_cron
        echo -e "${GREEN}✅ 已启用 Telegram 每日统计推送（北京时间 ${TELEMT_TG_TIME:-$TG_PUSH_TIME}）。${PLAIN}"
        tg_send "✅ MTProxy 流量统计推送已启用

每天北京时间 ${TELEMT_TG_TIME:-$TG_PUSH_TIME} 将自动发送本月流量统计到本会话" && echo -e "${GREEN}测试消息发送成功。${PLAIN}"
    fi
}

create_service_telemt() {
    if [[ "$INIT_SYSTEM" == "systemd" ]]; then
        cat > /etc/systemd/system/telemt.service <<EOF
[Unit]
Description=Telemt MTProxy
After=network.target

[Service]
Type=simple
WorkingDirectory=$BIN_DIR
Environment="RUST_LOG=info"
ExecStart=$BIN_DIR/telemt /etc/telemt.toml
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable telemt
        systemctl restart telemt
        
    elif [[ "$INIT_SYSTEM" == "openrc" ]]; then
        cat > /etc/init.d/telemt <<EOF
#!/sbin/openrc-run
name="telemt"
description="Telemt MTProxy"
command="$BIN_DIR/telemt"
command_args="/etc/telemt.toml"
command_background=true
supervisor="supervise-daemon"
respawn_delay=5
respawn_max=0
rc_ulimit="-n 65536"
command_env="RUST_LOG=info"
pidfile="/run/telemt.pid"
output_log="/var/log/telemt.log"
error_log="/var/log/telemt.log"

depend() {
    need net
    after firewall
}
EOF
        chmod +x /etc/init.d/telemt
        rc-update add telemt default
        rc-service telemt restart
    fi
}

show_info_telemt() {
    IPV4=$PUBLIC_IPV4
    IPV6=$PUBLIC_IPV6
    [ -z "$IPV4" ] && IPV4=$(get_public_ip)
    [ -z "$IPV6" ] && IPV6=$(get_public_ipv6)
    
    IP_MODE=$4
    FULL_SECRET="$2"
    
    echo -e "=============================="
    echo -e "${GREEN}Telemt 版连接信息${PLAIN}"
    echo -e "端口: $1"
    echo -e "Secret: $FULL_SECRET"
    echo -e "Domain: $3"
    echo -e "------------------------------"
    
    if [[ "$IP_MODE" == "v4" || "$IP_MODE" == "dual" ]]; then
        if [ -n "$IPV4" ]; then
            echo -e "${GREEN}IPv4 链接:${PLAIN}"
            echo -e "tg://proxy?server=$IPV4&port=$1&secret=${FULL_SECRET}"
        fi
    fi
    
    if [[ "$IP_MODE" == "v6" || "$IP_MODE" == "dual" ]]; then
        if [ -n "$IPV6" ]; then
            echo -e "${GREEN}IPv6 链接:${PLAIN}"
            echo -e "tg://proxy?server=$IPV6&port=$1&secret=${FULL_SECRET}"
        fi
    fi
    echo -e "=============================="
}


check_service_status() {
    local service=$1
    sleep 2
    if [[ "$INIT_SYSTEM" == "systemd" ]]; then
        if systemctl is-active --quiet "$service"; then
            echo -e "${GREEN}服务已启动: $service${PLAIN}"
        else
            echo -e "${RED}服务启动失败: $service${PLAIN}"
            journalctl -u "$service" --no-pager -n 20
        fi
    else
        if rc-service "$service" status | grep -q "started"; then
            echo -e "${GREEN}服务已启动: $service${PLAIN}"
        else
            echo -e "${RED}服务启动失败: $service${PLAIN}"
        fi
    fi
}

# --- 修改配置逻辑 ---
modify_mtg() {
    # 优先从配置文件读取，避免复杂的 sed 反解析
    if [ -f "$CONFIG_DIR/go.conf" ]; then
        source "$CONFIG_DIR/go.conf"
        CUR_PORT=$PORT
        CUR_DOMAIN=$DOMAIN
        CUR_IP_MODE=$IP_MODE
        # SECRET 是 ee 前缀的完整密钥，前 2 位 'ee' 之后 32 位即原始密钥
        CUR_BASE_SECRET=${SECRET:2:32}
    else
        # 兼容旧版：从服务文件中解析
        if [[ "$INIT_SYSTEM" == "systemd" ]]; then
            CMD_LINE=$(grep "ExecStart" /etc/systemd/system/mtg.service 2>/dev/null)
        else
            CMD_LINE=$(grep "command_args" /etc/init.d/mtg 2>/dev/null)
        fi
        
        if [ -z "$CMD_LINE" ]; then
            echo -e "${YELLOW}未检测到 MTG 服务配置。${PLAIN}"
            return
        fi

        CUR_PORT=$(echo "$CMD_LINE" | sed -n 's/.*:\([0-9]*\).*/\1/p')
        CUR_FULL_SECRET=$(echo "$CMD_LINE" | sed -n 's/.*\(ee[0-9a-fA-F]*\).*/\1/p' | awk '{print $1}')
        CUR_BASE_SECRET=${CUR_FULL_SECRET:2:32}
        
        CUR_DOMAIN=""
        if [[ -n "$CUR_FULL_SECRET" ]]; then
            DOMAIN_HEX=${CUR_FULL_SECRET:34}
            if [[ -n "$DOMAIN_HEX" ]]; then
                 ESCAPED_HEX=$(echo "$DOMAIN_HEX" | sed 's/../\\x&/g')
                 CUR_DOMAIN=$(printf "%b" "$ESCAPED_HEX")
            fi
        fi
        [ -z "$CUR_DOMAIN" ] && CUR_DOMAIN="(解析失败)"
        
        CUR_IP_MODE="v4"
        if echo "$CMD_LINE" | grep -q "only-ipv6"; then CUR_IP_MODE="v6"; fi
        if echo "$CMD_LINE" | grep -q "prefer-ipv6"; then CUR_IP_MODE="dual"; fi
    fi

    echo -e "当前配置 (Go): 端口=[${GREEN}$CUR_PORT${PLAIN}] 域名=[${GREEN}$CUR_DOMAIN${PLAIN}] 模式=[${GREEN}$CUR_IP_MODE${PLAIN}]"
    
    read -p "请输入新端口 (留空保持不变): " NEW_PORT
    [ -z "$NEW_PORT" ] && NEW_PORT="$CUR_PORT"
    if ! [[ "$NEW_PORT" =~ ^[0-9]+$ ]] || [ "$NEW_PORT" -lt 1 ] || [ "$NEW_PORT" -gt 65535 ]; then
        echo -e "${RED}端口无效，必须是 1-65535 之间的数字！${PLAIN}"
        return
    fi
    
    read -p "请输入新伪装域名 (留空保持不变): " NEW_DOMAIN
    [ -z "$NEW_DOMAIN" ] && NEW_DOMAIN="$CUR_DOMAIN"
    
    echo -e "当前监听模式: ${GREEN}$CUR_IP_MODE${PLAIN}"
    echo -e "请选择新的监听模式 (回车保持不变):"
    echo -e "1. ${GREEN}IPv4 仅${PLAIN}  2. ${YELLOW}IPv6 仅${PLAIN}  3. ${BLUE}双栈${PLAIN}"
    read -p "请选择 [1-3] (默认保持): " new_mode
    case $new_mode in
        1) NEW_IP_MODE="v4" ;;
        2) NEW_IP_MODE="v6" ;;
        3) NEW_IP_MODE="dual" ;;
        *) NEW_IP_MODE="$CUR_IP_MODE" ;;
    esac
    
    if [[ "$NEW_PORT" == "$CUR_PORT" && "$NEW_DOMAIN" == "$CUR_DOMAIN" && "$NEW_IP_MODE" == "$CUR_IP_MODE" ]]; then
        echo -e "${YELLOW}配置未变更。${PLAIN}"
        return
    fi
    
    echo -e "${BLUE}正在更新配置...${PLAIN}"
    # 密钥中内嵌了伪装域名的 hex，仅当域名变化时才需要重新生成密钥，避免旧链接全部失效
    if [[ "$NEW_DOMAIN" == "$CUR_DOMAIN" && -n "$CUR_BASE_SECRET" ]]; then
        NEW_SECRET="$CUR_BASE_SECRET"
        echo -e "${BLUE}域名未变化，保留原密钥。${PLAIN}"
    else
        NEW_SECRET=$(generate_secret)
        echo -e "${GREEN}新生成的密钥: $NEW_SECRET${PLAIN}"
    fi
    
    create_service_mtg "$NEW_PORT" "$NEW_SECRET" "$NEW_DOMAIN" "$NEW_IP_MODE"
    check_service_status mtg
    show_info_mtg "$NEW_PORT" "$NEW_SECRET" "$NEW_DOMAIN" "$NEW_IP_MODE"
}




modify_telemt() {
    if [ ! -f "$CONFIG_DIR/telemt.conf" ]; then
         echo -e "${YELLOW}未检测到 Telemt 配置文件。${PLAIN}"
         return
    fi
    
    source "$CONFIG_DIR/telemt.conf"
    CUR_PORT=$PORT
    CUR_DOMAIN=$DOMAIN
    CUR_IP_MODE=$IP_MODE
    CUR_SECRET=$SECRET
    
    echo -e "当前配置 (Telemt): 端口=[${GREEN}$CUR_PORT${PLAIN}] 域名=[${GREEN}$CUR_DOMAIN${PLAIN}]"
    
    read -p "请输入新端口 (留空保持不变): " NEW_PORT
    [ -z "$NEW_PORT" ] && NEW_PORT="$CUR_PORT"
    if ! [[ "$NEW_PORT" =~ ^[0-9]+$ ]] || [ "$NEW_PORT" -lt 1 ] || [ "$NEW_PORT" -gt 65535 ]; then
        echo -e "${RED}端口无效，必须是 1-65535 之间的数字！${PLAIN}"
        return
    fi
    
    read -p "请输入新伪装域名 (留空保持不变): " NEW_DOMAIN
    [ -z "$NEW_DOMAIN" ] && NEW_DOMAIN="$CUR_DOMAIN"
    
    if [[ "$NEW_PORT" == "$CUR_PORT" && "$NEW_DOMAIN" == "$CUR_DOMAIN" ]]; then
        echo -e "${YELLOW}配置未变更。${PLAIN}"
        return
    fi
    
    # Telemt 不再通过 modify_config 统一修改密钥（由多用户子菜单管理）
    # 不再重建整个 TOML（否则会丢失配额/到期/限速/专属端口等数据），
    # 仅就地更新端口与伪装域名，其余区块原样保留
    if ! grep -q "^port = " /etc/telemt.toml; then
        echo -e "${RED}未在 /etc/telemt.toml 中找到 [server] 端口配置，中止修改。${PLAIN}"
        return
    fi
    sed -i "s/^port = .*/port = $NEW_PORT/" /etc/telemt.toml
    sed -i "s/^tls_domain = .*/tls_domain = \"$NEW_DOMAIN\"/" /etc/telemt.toml

    # 修改外部环境文件
    cat > "$CONFIG_DIR/telemt.conf" <<EOF
PORT=$NEW_PORT
SECRET=$CUR_SECRET
DOMAIN=$NEW_DOMAIN
IP_MODE=$CUR_IP_MODE
MAIN_USER=$MAIN_USER
EOF

    create_service_telemt
    check_service_status telemt
    
    echo -e "${GREEN}端口和域名已成功更新并热生效！${PLAIN}"
}

modify_config() {
    echo ""
    echo -e "请选择要修改的服务:"
    echo -e "1. MTProxy (Go 版)"
    echo -e "2. MTProxy (Telemt 高性能版)"
    read -p "请选择 [1-2]: " m_choice
    case $m_choice in
        1) modify_mtg ;;
        2) modify_telemt ;;
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
    rm -f "$CONFIG_DIR/go.conf"
    echo -e "${GREEN}Go 版服务已删除。${PLAIN}"
}




delete_telemt() {
    echo -e "${RED}正在删除 MTProxy (Telemt 版)...${PLAIN}"
    if [[ "$INIT_SYSTEM" == "systemd" ]]; then
        systemctl stop telemt 2>/dev/null
        systemctl disable telemt 2>/dev/null
        rm -f /etc/systemd/system/telemt.service
        systemctl daemon-reload
    elif [[ "$INIT_SYSTEM" == "openrc" ]]; then
        rc-service telemt stop 2>/dev/null
        rc-update del telemt 2>/dev/null
        rm -f /etc/init.d/telemt
    fi
    rm -f "$BIN_DIR/telemt"
    rm -f "$CONFIG_DIR/telemt.conf"
    rm -f "/etc/telemt.toml"
    echo -e "${GREEN}Telemt 版服务已删除。${PLAIN}"
}

delete_config() {
    echo ""
    echo -e "请选择要删除的服务 (仅删除配置和服务，不全盘卸载):"
    echo -e "1. MTProxy (Go 版)"
    echo -e "2. MTProxy (Telemt 高性能版)"
    read -p "请选择 [1-2]: " d_choice
    case $d_choice in
        1) delete_mtg ;;
        2) delete_telemt ;;
        *) echo -e "${RED}无效选择${PLAIN}" ;;
    esac
    back_to_menu
}

# --- 查看连接信息逻辑 ---
show_detail_info() {
    echo ""
    echo -e "${BLUE}=== Go 版信息 ===${PLAIN}"
    if [ -f "$CONFIG_DIR/go.conf" ]; then
        source "$CONFIG_DIR/go.conf"
        BASE_SECRET=${SECRET:2:32}
        show_info_mtg "$PORT" "$BASE_SECRET" "$DOMAIN" "$IP_MODE"
    else
        # 兼容旧版：从服务文件解析
        if [[ "$INIT_SYSTEM" == "systemd" ]]; then
            CMD_LINE=$(grep "ExecStart" /etc/systemd/system/mtg.service 2>/dev/null)
        else
            CMD_LINE=$(grep "command_args" /etc/init.d/mtg 2>/dev/null)
        fi
        
        if [ -n "$CMD_LINE" ]; then
            PORT=$(echo "$CMD_LINE" | sed -n 's/.*:\([0-9]*\).*/\1/p')
            FULL_SECRET=$(echo "$CMD_LINE" | sed -n 's/.*\(ee[0-9a-fA-F]*\).*/\1/p' | awk '{print $1}')
            
            CUR_DOMAIN="(不可解析)"
            if [[ -n "$FULL_SECRET" ]]; then
                DOMAIN_HEX=${FULL_SECRET:34}
                if [[ -n "$DOMAIN_HEX" ]]; then
                     ESCAPED_HEX=$(echo "$DOMAIN_HEX" | sed 's/../\\x&/g')
                     CUR_DOMAIN=$(printf "%b" "$ESCAPED_HEX")
                fi
            fi
            
            BASE_SECRET=${FULL_SECRET:2:32}
            CUR_IP_MODE="v4"
            if echo "$CMD_LINE" | grep -q "only-ipv6"; then CUR_IP_MODE="v6"; fi
            if echo "$CMD_LINE" | grep -q "prefer-ipv6"; then CUR_IP_MODE="dual"; fi
            
            show_info_mtg "$PORT" "$BASE_SECRET" "$CUR_DOMAIN" "$CUR_IP_MODE"
        else
            echo -e "${YELLOW}未安装或未运行${PLAIN}"
        fi
    fi
    
    echo -e ""
    echo -e "${BLUE}=== Telemt 高性能版信息 ===${PLAIN}"
    if [ -f "$CONFIG_DIR/telemt.conf" ]; then
        source "$CONFIG_DIR/telemt.conf"
        # Telemt secret 是我们存放在 conf 里的本体，展示时组装 B64_URL_SAFE
        RAW_SECRET_BYTES=$(echo -n "$SECRET" | sed 's/../\\x&/g')
        FULL_EE_SECRET=$(printf '\xee%b%b' "$RAW_SECRET_BYTES" "$DOMAIN" | base64 | tr -d '\r\n' | tr '+/' '-_' | tr -d '=')
        show_info_telemt "$PORT" "$FULL_EE_SECRET" "$DOMAIN" "$IP_MODE"
    else
        echo -e "${YELLOW}未安装配置文件${PLAIN}"
    fi

    back_to_menu
}

# --- 信息显示 ---


show_info_mtg() {
    # 使用预获取的 IP
    IPV4=$PUBLIC_IPV4
    IPV6=$PUBLIC_IPV6
    # 如果为空则尝试再次获取
    [ -z "$IPV4" ] && IPV4=$(get_public_ip)
    [ -z "$IPV6" ] && IPV6=$(get_public_ipv6)
    
    IP_MODE=$4
    RAW_SECRET_BYTES=$(echo -n "$2" | sed 's/../\\x&/g')
    FULL_SECRET=$(printf '\xee%b%b' "$RAW_SECRET_BYTES" "$3" | base64 | tr -d '\r\n' | tr '+/' '-_' | tr -d '=')
    echo -e "=============================="
    echo -e "${GREEN}Go 版连接信息${PLAIN}"
    echo -e "端口: $1"
    echo -e "Secret: $FULL_SECRET"
    echo -e "Domain: $3"
    echo -e "------------------------------"

    if [[ "$IP_MODE" == "v4" || "$IP_MODE" == "dual" ]]; then
        if [ -n "$IPV4" ]; then
            echo -e "${GREEN}IPv4 链接:${PLAIN}"
            echo -e "tg://proxy?server=$IPV4&port=$1&secret=$FULL_SECRET"
        else
            echo -e "${RED}未检测到 IPv4 地址${PLAIN}"
        fi
    fi
    
    if [[ "$IP_MODE" == "v6" || "$IP_MODE" == "dual" ]]; then
        if [ -n "$IPV6" ]; then
            echo -e "${GREEN}IPv6 链接:${PLAIN}"
            echo -e "tg://proxy?server=$IPV6&port=$1&secret=$FULL_SECRET"
        else
            echo -e "${YELLOW}未检测到 IPv6 地址${PLAIN}"
        fi
    fi
    echo -e "=============================="
}

# 注意：get_service_status_str 已在第 109 行定义，此处不再重复

control_service() {
    ACTION=$1
    shift
    TARGETS="mtg telemt"
    # 如果指定了具体服务名，就只操作那一个
    if [[ -n "$1" ]]; then TARGETS="$1"; fi
    debug_log "【调试】control_service: ACTION=$ACTION TARGETS=$TARGETS INIT_SYSTEM=$INIT_SYSTEM"
    
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
    control_service stop
    
    if [[ "$INIT_SYSTEM" == "systemd" ]]; then
        systemctl disable mtg mtp-rust telemt 2>/dev/null
        rm -f /etc/systemd/system/mtg.service /etc/systemd/system/mtp-rust.service /etc/systemd/system/telemt.service
        systemctl daemon-reload
    else
        rc-update del mtg default 2>/dev/null
        rc-update del mtp-rust default 2>/dev/null
        rc-update del telemt default 2>/dev/null
        rm -f /etc/init.d/mtg /etc/init.d/mtp-rust /etc/init.d/telemt
    fi
    
    rm -rf "$WORKDIR"
    rm -f "/etc/telemt.toml"
    rm -f "/etc/telemt_quota.json"
    rm -f "/etc/telemt_exhausted.json"
    rm -f "/etc/telemt_reset.conf"
    rm -f "/var/log/telemt_reset.log"
    rm -f "/var/log/telemt_traffic.log"
    rm -rf "$DATA_DIR"
    rm -f "/etc/telemt_tg.conf"
    
    # 移除 Cron 定时任务
    crontab -l 2>/dev/null | grep -v "mtp check_reset" | crontab - 2>/dev/null
    remove_traffic_cron
    remove_tg_cron
    
    # 移除全局快捷命令
    rm -f "/usr/local/bin/mtp"
    
    echo -e "${RED}清理本地安装包...${PLAIN}"
    # 仅在脚本通过真实文件执行（非 /dev/fd 管道等）时才清理脚本所在目录的安装包
    if [ -d "$SCRIPT_DIR" ] && [[ "$SCRIPT_DIR" != /dev/fd ]] && [[ "$SCRIPT_DIR" != /dev/stdin ]]; then
        rm -f "${SCRIPT_DIR}/mtg-go"*
        rm -f "${SCRIPT_DIR}/mtp-rust"*
        rm -f "${SCRIPT_DIR}/telemt"*
    fi

    # 删除脚本自身（仅当通过真实文件执行，避免误删 /dev/fd 管道/进程替换）
    if [ -f "$0" ] && [[ "$0" != /dev/fd/* ]] && [[ "$0" != /dev/stdin ]]; then
        rm -f "$0"
    fi
    
    echo -e "${GREEN}卸载完成。${PLAIN}"
}

# rep 重新安装前的清理：仅删除服务与配置，保留脚本本体与全局快捷命令
rep_cleanup() {
    echo -e "${BLUE}正在清理旧服务配置 (保留脚本本体)...${PLAIN}"
    delete_mtg 2>/dev/null
    delete_telemt 2>/dev/null
}

# 根据 INSTALL_MODE 选择安装的后端（无交互模式下使用），默认 go 版
install_selected() {
    case "${INSTALL_MODE:-go}" in
        go|mtg|mtg-go) install_mtg ;;
        telemt|rust|telemt-rust) install_telemt ;;
        *)
            echo -e "${RED}无效的 INSTALL_MODE: $INSTALL_MODE (可选: go / telemt)${PLAIN}"
            return 1
            ;;
    esac
}

back_to_menu() {
    echo ""
    if [ -n "$NON_INTERACTIVE" ]; then
        return
    fi
    read -n 1 -s -r -p "按任意键返回主菜单..."
    menu
}


# --- Telemt 多用户管理功能 ---
# 纯展示：解析 /etc/telemt.toml 并打印用户列表与分享链接（无交互，供 users 命令与交互菜单复用）
# 纯展示：解析 /etc/telemt.toml 并打印用户列表与分享链接（由 Python 引擎实现）
list_telemt_users_plain() {
    if [ ! -f "/etc/telemt.toml" ] || [ ! -f "$CONFIG_DIR/telemt.conf" ]; then
        echo -e "${YELLOW}未检测到 Telemt 配置文件或未安装！${PLAIN}"
        return 1
    fi
    # 刷新一次流量快照，确保"耗尽时间"是最新的
    snapshot_traffic_stats
    source "$CONFIG_DIR/telemt.conf"
    local IPV4="${PUBLIC_IPV4:-}"
    local IPV6="${PUBLIC_IPV6:-}"
    [ -z "$IPV4" ] && IPV4=$(get_public_ip)
    [ -z "$IPV6" ] && IPV6=$(get_public_ipv6)
    TELEMT_CONF="$CONFIG_DIR/telemt.conf" stats_py users --ipv4 "$IPV4" --ipv6 "$IPV6"
    return $?
}
list_telemt_users() {
    if [ ! -f "/etc/telemt.toml" ] || [ ! -f "$CONFIG_DIR/telemt.conf" ]; then
        echo -e "${YELLOW}未检测到 Telemt 配置文件或未安装！${PLAIN}"
        return
    fi
    while true; do
        clear
        list_telemt_users_plain
        echo -e ""
        echo -e "  ${GREEN}1.${PLAIN} 刷新本页数据 (更新最新流量和状态)"
        echo -e "  ${GREEN}0.${PLAIN} 返回上一级菜单"
        echo -e "${BLUE}=======================================${PLAIN}"
        read -p "  请选择操作 [0-1]: " list_choice
        case $list_choice in
            1) 
                # 重新循环一次 while
                continue 
                ;;
            0|*) 
                # 退出查看
                break 
                ;;
        esac
    done
}

add_telemt_user() {
    if [ ! -f "/etc/telemt.toml" ]; then
        echo -e "${YELLOW}未检测到 Telemt 配置文件！${PLAIN}"
        return 1
    fi
    echo ""
    
    # 无交互添加用户：读取环境变量；交互模式：逐项询问
    if [ -n "$NON_INTERACTIVE" ]; then
        NEW_USER="${TELEMT_USER:-}"
        NEW_DEDICATED_PORT="${TELEMT_DEDICATED_PORT:-}"
        NEW_QUOTA="${TELEMT_QUOTA:-}"
        NEW_EXPIRE="${TELEMT_EXPIRE:-}"
        NEW_SECRET="${TELEMT_SECRET:-$(generate_secret)}"
        SPEED_UP="${TELEMT_SPEED_UP:-}"
        SPEED_DOWN="${TELEMT_SPEED_DOWN:-}"
        if [ -n "$SPEED_UP" ]; then
            [ -z "$SPEED_DOWN" ] && SPEED_DOWN="$SPEED_UP"
            NEW_SPEED="$SPEED_UP $SPEED_DOWN"
        else
            NEW_SPEED=""
        fi
        
        # --- 无交互模式统一校验 ---
        if [ -z "$NEW_USER" ]; then
            echo -e "${RED}TELEMT_USER 不能为空！${PLAIN}"
            return 2
        fi
        if ! [[ "$NEW_USER" =~ ^[A-Za-z0-9_-]+$ ]]; then
            echo -e "${RED}用户名只能包含字母、数字、下划线或中划线！${PLAIN}"
            return 2
        fi
        if grep -q "^[ \"]*$NEW_USER[ \"]*=" /etc/telemt.toml; then
            echo -e "${RED}该用户已存在！${PLAIN}"
            return 1
        fi
        if [ -n "$NEW_DEDICATED_PORT" ]; then
            if ! [[ "$NEW_DEDICATED_PORT" =~ ^[0-9]+$ ]] || [ "$NEW_DEDICATED_PORT" -lt 1 ] || [ "$NEW_DEDICATED_PORT" -gt 65535 ]; then
                echo -e "${RED}端口必须是在 1-65535 之间的合法数字！${PLAIN}"
                return 2
            fi
            if grep -q "port = $NEW_DEDICATED_PORT$" /etc/telemt.toml || grep -E -q "= \"?$NEW_DEDICATED_PORT\"?$" /etc/telemt.toml; then
                echo -e "${RED}严重冲突：你分配的专属端口已被某个用户或主程序监听征用！${PLAIN}"
                return 1
            fi
        fi
        if ! [[ "$NEW_SECRET" =~ ^[0-9a-fA-F]{32}$ ]]; then
            echo -e "${RED}TELEMT_SECRET 必须是 32 位 hex 字符 (a-f/0-9)！当前值: $NEW_SECRET${PLAIN}"
            return 2
        fi
        if [[ -n "$NEW_QUOTA" && ! "$NEW_QUOTA" =~ ^[0-9.]+$ ]]; then
            echo -e "${RED}TELEMT_QUOTA 必须是数字，已忽略配额限制。${PLAIN}"
            NEW_QUOTA=""
        fi
        echo -e "${GREEN}为 $NEW_USER 添加用户: 端口=[${NEW_DEDICATED_PORT:-共享}] 配额=[${NEW_QUOTA:-不限}GB] 到期=[${NEW_EXPIRE:-永久}] 限速=[${NEW_SPEED:-不限}]${PLAIN}"
        echo -e "${GREEN}通信密钥: $NEW_SECRET${PLAIN}"
        debug_log "【调试】add_telemt_user(非交互): USER=$NEW_USER DEDICATED_PORT=$NEW_DEDICATED_PORT QUOTA=$NEW_QUOTA EXPIRE=$NEW_EXPIRE SPEED=$NEW_SPEED SECRET=$NEW_SECRET"
    else
        read -p "请输入要添加的用户名 (英文/数字组合): " NEW_USER
        if [ -z "$NEW_USER" ]; then
            echo -e "${RED}用户名不能为空！${PLAIN}"
            return
        fi
        # 防止特殊字符破坏 TOML 或 sed 命令
        if ! [[ "$NEW_USER" =~ ^[A-Za-z0-9_-]+$ ]]; then
            echo -e "${RED}用户名只能包含字母、数字、下划线或中划线！${PLAIN}"
            return
        fi
        
        # 防止重复
        if grep -q "^[ \"]*$NEW_USER[ \"]*=" /etc/telemt.toml; then
            echo -e "${RED}该用户已存在！${PLAIN}"
            return
        fi
        
        
        read -p "请输入要为其分配的专属独立端口 (直接回车表示不独占，使用全局共享端口): " NEW_DEDICATED_PORT

        if [ -n "$NEW_DEDICATED_PORT" ]; then
            if ! [[ "$NEW_DEDICATED_PORT" =~ ^[0-9]+$ ]] || [ "$NEW_DEDICATED_PORT" -lt 1 ] || [ "$NEW_DEDICATED_PORT" -gt 65535 ]; then
                echo -e "${RED}端口必须是在 1-65535 之间的合法数字！${PLAIN}"
                return
            fi
            
            # 强制检查端口冲突 (包含全局端口冲突)
            if grep -q "port = $NEW_DEDICATED_PORT$" /etc/telemt.toml || grep -E -q "= \"?$NEW_DEDICATED_PORT\"?$" /etc/telemt.toml; then
                echo -e "${RED}严重冲突：你分配的专属端口已被某个用户或主程序监听征用，请换一个！${PLAIN}"
                return
            fi
            echo -e "${GREEN}为 $NEW_USER 成功锁定独立专享端口: $NEW_DEDICATED_PORT${PLAIN}"
        fi

        NEW_SECRET=$(generate_secret)
        echo -e "${GREEN}为 $NEW_USER 成功生成通信密钥: $NEW_SECRET${PLAIN}"
        
        echo ""
        read -p "请输入此用户的月度流量配额 (GB为单位, 直接回车表示不启用限流): " NEW_QUOTA
        NEW_QUOTA=$(echo "$NEW_QUOTA" | tr -d '\r ')
        if [[ -n "$NEW_QUOTA" && ! "$NEW_QUOTA" =~ ^[0-9.]+$ ]]; then
            echo -e "${RED}输入有误，配额必须是数字，将默认关闭该用户限流。${PLAIN}"
            NEW_QUOTA=""
        fi
        
        echo -e "   ${BLUE}▶ 独立网速限制配置${PLAIN}"
        read -p "请输入【上行】速度限制 (MB/s, 例如 1.5, 回车则极速不限流): " SPEED_UP
        SPEED_UP=$(echo "$SPEED_UP" | tr -d '\r ' | xargs)
        if [ -n "$SPEED_UP" ]; then
            read -p "请输入【下行】速度限制 (MB/s, 例如 5.0, 回车默认与上行相同): " SPEED_DOWN
            SPEED_DOWN=$(echo "$SPEED_DOWN" | tr -d '\r ' | xargs)
            [ -z "$SPEED_DOWN" ] && SPEED_DOWN=$SPEED_UP
            NEW_SPEED="$SPEED_UP $SPEED_DOWN"
        else
            NEW_SPEED=""
        fi
        
        read -p "请输入此用户的强制到期日期 (格式 2026-10-01 或 2026-10-01 12:00:00, 回车表示永久): " NEW_EXPIRE
        NEW_EXPIRE=$(echo "$NEW_EXPIRE" | tr -d '\r' | xargs)
    fi
    
    # 插入到 [access.users] 区块的末尾
    sed -i "/^\[access\.users\]/a $NEW_USER = \"$NEW_SECRET\"" /etc/telemt.toml

    # 如果有分配专属端口，则要写入 [access.user_ports] 区域
    if [ -n "$NEW_DEDICATED_PORT" ]; then
        if ! grep -q "^\[access\.user_ports\]" /etc/telemt.toml; then
            echo "" >> /etc/telemt.toml
            echo "[access.user_ports]" >> /etc/telemt.toml
        fi
        sed -i "/^\[access\.user_ports\]/a $NEW_USER = $NEW_DEDICATED_PORT" /etc/telemt.toml
    fi
    
    # 配额写入 [access.user_data_quota] 区域
    if [ -n "$NEW_QUOTA" ]; then
        if ! grep -q "^\[access\.user_data_quota\]" /etc/telemt.toml; then
            echo "" >> /etc/telemt.toml
            echo "[access.user_data_quota]" >> /etc/telemt.toml
        fi
        # 换算成 Bytes，使用 awk 兼容可能的小数输入
        QUOTA_BYTES=$(awk "BEGIN {printf \"%.0f\", $NEW_QUOTA * 1073741824}")
        sed -i "/^\[access\.user_data_quota\]/a $NEW_USER = $QUOTA_BYTES" /etc/telemt.toml
        
        # 清除它的历史用量
        if [ -f "/etc/telemt_quota.json" ]; then
            sed -i "s/\"$NEW_USER\":[0-9]*/\"$NEW_USER\":0/g" /etc/telemt_quota.json
        fi
    fi
    
    # 过期时间写入 [access.user_expirations] 区域
    if [ -n "$NEW_EXPIRE" ]; then
        if ! grep -q "^\[access\.user_expirations\]" /etc/telemt.toml; then
            echo "" >> /etc/telemt.toml
            echo "[access.user_expirations]" >> /etc/telemt.toml
        fi
        if echo "$NEW_EXPIRE" | grep -q " "; then
            ISO_EXPIRE="$(echo "$NEW_EXPIRE" | tr ' ' 'T')+08:00"
        else
            ISO_EXPIRE="${NEW_EXPIRE}T23:59:59+08:00"
        fi
        sed -i "/^\[access\.user_expirations\]/a $NEW_USER = $ISO_EXPIRE" /etc/telemt.toml
    fi
    
    # 速度限制写入 [access.user_speed_limits] 区域
    if [ -n "$NEW_SPEED" ]; then
        if ! grep -q "^\[access\.user_speed_limits\]" /etc/telemt.toml; then
            echo "" >> /etc/telemt.toml
            echo "[access.user_speed_limits]" >> /etc/telemt.toml
        fi
        sed -i "/^\[access\.user_speed_limits\]/a $NEW_USER = \"$NEW_SPEED\"" /etc/telemt.toml
    fi
    
    echo -e "${BLUE}正在重载配置 ...${PLAIN}"
    control_service restart telemt >/dev/null 2>&1
    echo -e "${GREEN}新用户已热生效！${PLAIN}"
}

# 非交互修改指定 Telemt 用户配置（TELEMT_USER 指定目标，TELEMT_* 为要修改的字段，0 = 解除该限制）
modify_telemt_user() {
    if [ ! -f "/etc/telemt.toml" ]; then
        echo -e "${YELLOW}未检测到 Telemt 配置文件！${PLAIN}"
        return 1
    fi
    if [ -z "$NON_INTERACTIVE" ]; then
        echo -e "${RED}moduser 仅支持无交互模式（配合 TELEMT_USER / TELEMT_* 环境变量）！${PLAIN}"
        return 1
    fi
    
    local TARGET_USER="${TELEMT_USER:-}"
    if [ -z "$TARGET_USER" ]; then
        echo -e "${RED}TELEMT_USER 不能为空！${PLAIN}"
        return 2
    fi
    if ! [[ "$TARGET_USER" =~ ^[A-Za-z0-9_-]+$ ]]; then
        echo -e "${RED}用户名只能包含字母、数字、下划线或中划线！${PLAIN}"
        return 2
    fi
    if ! grep -q "^[ \"]*$TARGET_USER[ \"]*=" /etc/telemt.toml; then
        echo -e "${RED}用户 $TARGET_USER 不存在！${PLAIN}"
        return 1
    fi
    
    if [ -z "${TELEMT_SECRET:-}${TELEMT_DEDICATED_PORT:-}${TELEMT_QUOTA:-}${TELEMT_EXPIRE:-}${TELEMT_SPEED_UP:-}" ]; then
        echo -e "${RED}未提供任何要修改的字段（TELEMT_SECRET / TELEMT_DEDICATED_PORT / TELEMT_QUOTA / TELEMT_EXPIRE / TELEMT_SPEED_UP）！${PLAIN}"
        return 2
    fi
    
    # 1. 通信密钥 [access.users]
    if [ -n "${TELEMT_SECRET:-}" ]; then
        if ! [[ "$TELEMT_SECRET" =~ ^[0-9a-fA-F]{32}$ ]]; then
            echo -e "${RED}TELEMT_SECRET 必须是 32 位 hex 字符 (a-f/0-9)！${PLAIN}"
            return 2
        fi
        sed -i "/^\[access\.users\]/,/^\[/{/^[ \"]*$TARGET_USER[ \"]*=/d}" /etc/telemt.toml
        sed -i "/^\[access\.users\]/a $TARGET_USER = \"$TELEMT_SECRET\"" /etc/telemt.toml
        echo -e "${GREEN}已更新 $TARGET_USER 的通信密钥。${PLAIN}"
    fi
    
    # 2. 专属端口 [access.user_ports]
    if [ -n "${TELEMT_DEDICATED_PORT:-}" ]; then
        if [ "$TELEMT_DEDICATED_PORT" = "0" ]; then
            sed -i "/^\[access\.user_ports\]/,/^\[/{/^$TARGET_USER *=/d}" /etc/telemt.toml
            echo -e "${GREEN}已移除 $TARGET_USER 的专属端口，恢复为共享端口。${PLAIN}"
        else
            if ! [[ "$TELEMT_DEDICATED_PORT" =~ ^[0-9]+$ ]] || [ "$TELEMT_DEDICATED_PORT" -lt 1 ] || [ "$TELEMT_DEDICATED_PORT" -gt 65535 ]; then
                echo -e "${RED}端口必须是在 1-65535 之间的合法数字！${PLAIN}"
                return 2
            fi
            if grep -q "port = $TELEMT_DEDICATED_PORT$" /etc/telemt.toml || grep -E -q "= \"?$TELEMT_DEDICATED_PORT\"?$" /etc/telemt.toml; then
                echo -e "${RED}严重冲突：端口 $TELEMT_DEDICATED_PORT 已被占用！${PLAIN}"
                return 1
            fi
            sed -i "/^\[access\.user_ports\]/,/^\[/{/^$TARGET_USER *=/d}" /etc/telemt.toml
            if ! grep -q "^\[access\.user_ports\]" /etc/telemt.toml; then
                echo "" >> /etc/telemt.toml
                echo "[access.user_ports]" >> /etc/telemt.toml
            fi
            sed -i "/^\[access\.user_ports\]/a $TARGET_USER = $TELEMT_DEDICATED_PORT" /etc/telemt.toml
            echo -e "${GREEN}已设置 $TARGET_USER 的专属端口: $TELEMT_DEDICATED_PORT。${PLAIN}"
        fi
    fi
    
    # 3. 流量配额 [access.user_data_quota]
    if [ -n "${TELEMT_QUOTA:-}" ]; then
        if [ "$TELEMT_QUOTA" = "0" ]; then
            sed -i "/^\[access\.user_data_quota\]/,/^\[/{/^$TARGET_USER *=/d}" /etc/telemt.toml
            echo -e "${GREEN}已解除 $TARGET_USER 的流量配额限制。${PLAIN}"
        else
            if ! [[ "$TELEMT_QUOTA" =~ ^[0-9.]+$ ]]; then
                echo -e "${RED}TELEMT_QUOTA 必须是数字 (GB)！${PLAIN}"
                return 2
            fi
            QUOTA_BYTES=$(awk "BEGIN {printf \"%.0f\", $TELEMT_QUOTA * 1073741824}")
            sed -i "/^\[access\.user_data_quota\]/,/^\[/{/^$TARGET_USER *=/d}" /etc/telemt.toml
            if ! grep -q "^\[access\.user_data_quota\]" /etc/telemt.toml; then
                echo "" >> /etc/telemt.toml
                echo "[access.user_data_quota]" >> /etc/telemt.toml
            fi
            sed -i "/^\[access\.user_data_quota\]/a $TARGET_USER = $QUOTA_BYTES" /etc/telemt.toml
            echo -e "${GREEN}已设置 $TARGET_USER 的配额: $TELEMT_QUOTA GB。${PLAIN}"
        fi
        # 配额调整后清空该用户已用账单
        if [ -f "/etc/telemt_quota.json" ]; then
            sed -i "s/\"$TARGET_USER\":[0-9]*/\"$TARGET_USER\":0/g" /etc/telemt_quota.json
        fi
        # 配额已重新设定，同步清除该用户本月"耗尽时间"记录
        clear_exhausted_record "$TARGET_USER"
    fi
    
    # 4. 到期时间 [access.user_expirations]
    if [ -n "${TELEMT_EXPIRE:-}" ]; then
        sed -i "/^\[access\.user_expirations\]/,/^\[/{/^$TARGET_USER *=/d}" /etc/telemt.toml
        if [ "$TELEMT_EXPIRE" = "0" ]; then
            echo -e "${GREEN}已解除 $TARGET_USER 的到期限制，恢复为永久有效。${PLAIN}"
        else
            if echo "$TELEMT_EXPIRE" | grep -q " "; then
                ISO_EXPIRE="$(echo "$TELEMT_EXPIRE" | tr ' ' 'T')+08:00"
            else
                ISO_EXPIRE="${TELEMT_EXPIRE}T23:59:59+08:00"
            fi
            if ! grep -q "^\[access\.user_expirations\]" /etc/telemt.toml; then
                echo "" >> /etc/telemt.toml
                echo "[access.user_expirations]" >> /etc/telemt.toml
            fi
            sed -i "/^\[access\.user_expirations\]/a $TARGET_USER = $ISO_EXPIRE" /etc/telemt.toml
            echo -e "${GREEN}已设置 $TARGET_USER 的到期日: $TELEMT_EXPIRE。${PLAIN}"
        fi
    fi
    
    # 5. 带宽限速 [access.user_speed_limits]
    if [ -n "${TELEMT_SPEED_UP:-}" ]; then
        sed -i "/^\[access\.user_speed_limits\]/,/^\[/{/^$TARGET_USER *=/d}" /etc/telemt.toml
        if [ "$TELEMT_SPEED_UP" = "0" ]; then
            echo -e "${GREEN}已解除 $TARGET_USER 的带宽限速。${PLAIN}"
        else
            local SPEED_DOWN="${TELEMT_SPEED_DOWN:-$TELEMT_SPEED_UP}"
            local NEW_SPEED="$TELEMT_SPEED_UP $SPEED_DOWN"
            if ! grep -q "^\[access\.user_speed_limits\]" /etc/telemt.toml; then
                echo "" >> /etc/telemt.toml
                echo "[access.user_speed_limits]" >> /etc/telemt.toml
            fi
            sed -i "/^\[access\.user_speed_limits\]/a $TARGET_USER = \"$NEW_SPEED\"" /etc/telemt.toml
            echo -e "${GREEN}已设置 $TARGET_USER 的限速: 上行 $TELEMT_SPEED_UP / 下行 $SPEED_DOWN MB/s。${PLAIN}"
        fi
    fi
    
    echo -e "${BLUE}正在重载配置 ...${PLAIN}"
    control_service restart telemt >/dev/null 2>&1
    debug_log "【调试】modify_telemt_user: TARGET_USER=$TARGET_USER TELEMT_SECRET=${TELEMT_SECRET:-} TELEMT_DEDICATED_PORT=${TELEMT_DEDICATED_PORT:-} TELEMT_QUOTA=${TELEMT_QUOTA:-} TELEMT_EXPIRE=${TELEMT_EXPIRE:-} TELEMT_SPEED_UP=${TELEMT_SPEED_UP:-}"
    echo -e "${GREEN}用户 $TARGET_USER 配置修改成功并已热生效！${PLAIN}"
}

# 查询指定 Telemt 用户的当前配置（TELEMT_USER 指定目标，无交互）
# 查询指定 Telemt 用户的当前配置（由 Python 引擎实现）
show_telemt_user() {
    if [ ! -f "/etc/telemt.toml" ] || [ ! -f "$CONFIG_DIR/telemt.conf" ]; then
        echo -e "${YELLOW}未检测到 Telemt 配置文件或未安装！${PLAIN}"
        return 1
    fi
    local TARGET_USER="${TELEMT_USER:-}"
    if [ -z "$TARGET_USER" ]; then
        echo -e "${RED}TELEMT_USER 不能为空！${PLAIN}"
        return 2
    fi
    if ! [[ "$TARGET_USER" =~ ^[A-Za-z0-9_-]+$ ]]; then
        echo -e "${RED}用户名只能包含字母、数字、下划线或中划线！${PLAIN}"
        return 2
    fi
    if ! grep -q "^[ \"]*$TARGET_USER[ \"]*=" /etc/telemt.toml; then
        echo -e "${RED}用户 $TARGET_USER 不存在！${PLAIN}"
        return 1
    fi
    # 刷新一次流量快照，确保"耗尽时间"是最新的
    snapshot_traffic_stats
    source "$CONFIG_DIR/telemt.conf"
    local IPV4="${PUBLIC_IPV4:-}"
    local IPV6="${PUBLIC_IPV6:-}"
    [ -z "$IPV4" ] && IPV4=$(get_public_ip)
    [ -z "$IPV6" ] && IPV6=$(get_public_ipv6)
    TELEMT_CONF="$CONFIG_DIR/telemt.conf" stats_py user --name "$TARGET_USER" --ipv4 "$IPV4" --ipv6 "$IPV6"
    return $?
}
query_telemt_user() {
    if [ ! -f "/etc/telemt.toml" ] || [ ! -f "$CONFIG_DIR/telemt.conf" ]; then
        echo -e "${YELLOW}未检测到 Telemt 配置文件或未安装！${PLAIN}"
        return
    fi
    echo ""
    read -p "请输入要查询的用户名关键词 (模糊匹配, 回车取消): " Q_KW
    Q_KW=$(echo "$Q_KW" | tr -d '\r ' | xargs)
    if [ -z "$Q_KW" ]; then
        echo -e "${YELLOW}已取消查询。${PLAIN}"
        return
    fi
    
    local in_users=0
    local -a match_names=()
    while IFS= read -r line || [ -n "$line" ]; do
        if [[ "$line" =~ ^\[access[.]users\] ]]; then
            in_users=1
            continue
        fi
        if [[ $in_users -eq 1 && "$line" =~ ^\[.*\] ]]; then
            in_users=0
            continue
        fi
        if [[ $in_users -eq 1 && -n "$line" && ! "$line" =~ ^# ]]; then
            local uName=$(echo "$line" | cut -d '=' -f 1 | tr -d ' "' | xargs)
            if [ -n "$uName" ] && [[ "$uName" == *"$Q_KW"* ]]; then
                match_names+=("$uName")
            fi
        fi
    done < /etc/telemt.toml
    
    if [ ${#match_names[@]} -eq 0 ]; then
        echo -e "${RED}未找到包含 \"$Q_KW\" 的用户！${PLAIN}"
        return
    fi
    
    local pick="$Q_KW"
    if [ ${#match_names[@]} -gt 1 ]; then
        echo -e "匹配到 ${YELLOW}${#match_names[@]}${PLAIN} 个用户:"
        local i=1
        for n in "${match_names[@]}"; do
            echo -e "  ${GREEN}[$i]${PLAIN} ${YELLOW}$n${PLAIN}"
            ((i++))
        done
        read -p "请选择要查询的用户序号 [1-${#match_names[@]}] (回车取消): " Q_SEL
        if [ -z "$Q_SEL" ] || ! [[ "$Q_SEL" =~ ^[0-9]+$ ]] || [ "$Q_SEL" -lt 1 ] || [ "$Q_SEL" -gt "${#match_names[@]}" ]; then
            echo -e "${YELLOW}已取消操作或输入无效。${PLAIN}"
            return
        fi
        pick="${match_names[$((Q_SEL-1))]}"
    elif [ ${#match_names[@]} -eq 1 ]; then
        pick="${match_names[0]}"
    fi
    
    echo ""
    TELEMT_USER="$pick" show_telemt_user
}

del_telemt_user() {
    if [ ! -f "/etc/telemt.toml" ]; then
        echo -e "${YELLOW}未检测到 Telemt 配置文件！${PLAIN}"
        return
    fi
    echo ""
    echo -e "==========================================="
    echo -e "${GREEN}      请选择要踢出 (删除) 的用户       ${PLAIN}"
    echo -e "==========================================="
    
    local in_users=0
    local user_count=0
    local user_lines=()
    local user_names=()
    local line_num=0
    
    while IFS= read -r line || [ -n "$line" ]; do
        ((line_num++))
        if [[ "$line" =~ ^\[access\.users\] ]]; then
            in_users=1
            continue
        fi
        if [[ $in_users -eq 1 && "$line" =~ ^\[.*\] ]]; then
            in_users=0
            continue
        fi
        if [[ $in_users -eq 1 && -n "$line" && ! "$line" =~ ^# ]]; then
            local uName=$(echo "$line" | cut -d '=' -f 1 | tr -d ' "' | xargs)
            if [ -n "$uName" ]; then
                ((user_count++))
                user_lines[$user_count]=$line_num
                user_names[$user_count]=$uName
                echo -e "  ${GREEN}[${user_count}]${PLAIN} 用户名: ${YELLOW}$uName${PLAIN}"
            fi
        fi
    done < /etc/telemt.toml
    
    if [ $user_count -eq 0 ]; then
        echo -e "${YELLOW}当前没有任何用户可供删除！${PLAIN}"
        echo -e "==========================================="
        return
    fi
    echo -e "==========================================="
    
    echo ""
    read -p "请输入要删除的用户序号 [1-$user_count] (回车取消): " DEL_INDEX
    if [ -z "$DEL_INDEX" ]; then
        echo -e "${YELLOW}已取消操作。${PLAIN}"
        return
    fi
    
    if ! [[ "$DEL_INDEX" =~ ^[0-9]+$ ]] || [ "$DEL_INDEX" -lt 1 ] || [ "$DEL_INDEX" -gt "$user_count" ]; then
        echo -e "${RED}输入的序号无效！${PLAIN}"
        return
    fi
    
    local target_line=${user_lines[$DEL_INDEX]}
    local target_name=${user_names[$DEL_INDEX]}
    
    # 精确删除目标行号 ([access.users] 中的那行)
    sed -i "${target_line}d" /etc/telemt.toml
    
    # 清理可能存在的配额、过期时间、专属端口等孤儿(僵尸)配置项
    # 由于其他区块不需要计算行号，直接用正则删除
    sed -i "/^\[access\.user_ports\]/,/^\[/{/^$target_name *=/d}" /etc/telemt.toml
    sed -i "/^\[access\.user_data_quota\]/,/^\[/{/^$target_name *=/d}" /etc/telemt.toml
    sed -i "/^\[access\.user_expirations\]/,/^\[/{/^$target_name *=/d}" /etc/telemt.toml
    sed -i "/^\[access\.user_speed_limits\]/,/^\[/{/^$target_name *=/d}" /etc/telemt.toml
    
    # 尝试从内存配额 JSON 中删除
    if [ -f "/etc/telemt_quota.json" ]; then
        sed -i "s/\"$target_name\":[0-9]*/\"$target_name\":0/g" /etc/telemt_quota.json 2>/dev/null
    fi
    clear_exhausted_record "$target_name"
    
    echo -e "${BLUE}正在重载配置注销该用户 ...${PLAIN}"
    control_service restart telemt >/dev/null 2>&1
    
    echo -e "${GREEN}删除用户 [$target_name] 成功并且已将其强制踢下线以及清理全部关联数据！${PLAIN}"
}

# 非交互删除指定 Telemt 用户（TELEMT_USER 指定目标）
del_telemt_user_by_name() {
    if [ ! -f "/etc/telemt.toml" ]; then
        echo -e "${YELLOW}未检测到 Telemt 配置文件！${PLAIN}"
        return 1
    fi
    local target_name="${TELEMT_USER:-}"
    if [ -z "$target_name" ]; then
        echo -e "${RED}TELEMT_USER 不能为空！${PLAIN}"
        return 2
    fi
    if ! [[ "$target_name" =~ ^[A-Za-z0-9_-]+$ ]]; then
        echo -e "${RED}用户名只能包含字母、数字、下划线或中划线！${PLAIN}"
        return 2
    fi
    if ! grep -q "^[ \"]*$target_name[ \"]*=" /etc/telemt.toml; then
        echo -e "${RED}用户 $target_name 不存在！${PLAIN}"
        return 1
    fi
    
    # 删除 [access.users] 中的用户条目
    sed -i "/^\[access\.users\]/,/^\[/{/^[ \"]*$target_name[ \"]*=/d}" /etc/telemt.toml
    
    # 清理其他区块的孤儿(僵尸)配置
    sed -i "/^\[access\.user_ports\]/,/^\[/{/^$target_name *=/d}" /etc/telemt.toml
    sed -i "/^\[access\.user_data_quota\]/,/^\[/{/^$target_name *=/d}" /etc/telemt.toml
    sed -i "/^\[access\.user_expirations\]/,/^\[/{/^$target_name *=/d}" /etc/telemt.toml
    sed -i "/^\[access\.user_speed_limits\]/,/^\[/{/^$target_name *=/d}" /etc/telemt.toml
    
    # 清理内存配额账单
    if [ -f "/etc/telemt_quota.json" ]; then
        sed -i "s/\"$target_name\":[0-9]*/\"$target_name\":0/g" /etc/telemt_quota.json 2>/dev/null
    fi
    clear_exhausted_record "$target_name"
    
    echo -e "${BLUE}正在重载配置注销该用户 ...${PLAIN}"
    control_service restart telemt >/dev/null 2>&1
    debug_log "【调试】del_telemt_user_by_name: target_name=$target_name"
    echo -e "${GREEN}删除用户 [$target_name] 成功并且已将其强制踢下线以及清理全部关联数据！${PLAIN}"
}

# 读取 toml 指定段落中指定键的当前值（去首尾引号与 \r，供修改前回显对照）
get_toml_val() {
    local sec="$1" key="$2"
    awk -v s="$sec" -v k="$key" '
        $0 ~ /^\[/ { insec = ($0 == "[" s "]") ? 1 : 0; next }
        insec && $0 ~ "^" k "[ \t]*=" {
            sub(/^[^=]*=[ \t]*/, "")
            sub(/^"/, ""); sub(/"$/, "")
            gsub(/\r/, "")
            print
        }
    ' /etc/telemt.toml
}

reset_telemt_user_quota() {
    if [ ! -f "/etc/telemt.toml" ]; then
        echo -e "${YELLOW}未检测到 Telemt 配置文件！${PLAIN}"
        return
    fi
    echo ""
    echo -e "==========================================="
    echo -e "${GREEN}      请选择要重置配额或续期的用户       ${PLAIN}"
    echo -e "==========================================="
    
    local in_users=0
    local user_count=0
    local user_lines=()
    local user_names=()
    local line_num=0
    
    while IFS= read -r line || [ -n "$line" ]; do
        ((line_num++))
        if [[ "$line" =~ ^\[access\.users\] ]]; then
            in_users=1
            continue
        fi
        if [[ $in_users -eq 1 && "$line" =~ ^\[.*\] ]]; then
            in_users=0
            continue
        fi
        if [[ $in_users -eq 1 && -n "$line" && ! "$line" =~ ^# ]]; then
            local uName=$(echo "$line" | cut -d '=' -f 1 | tr -d ' "' | xargs)
            if [ -n "$uName" ]; then
                ((user_count++))
                user_lines[$user_count]=$line_num
                user_names[$user_count]=$uName
                echo -e "  ${GREEN}[${user_count}]${PLAIN} 用户名: ${YELLOW}$uName${PLAIN}"
            fi
        fi
    done < /etc/telemt.toml
    
    if [ $user_count -eq 0 ]; then
        echo -e "${YELLOW}当前没有任何用户可供操作！${PLAIN}"
        echo -e "==========================================="
        return
    fi
    echo -e "==========================================="
    
    echo ""
    read -p "请输入要操作的用户序号 [1-$user_count] (回车取消): " SEL_INDEX
    if [ -z "$SEL_INDEX" ] || ! [[ "$SEL_INDEX" =~ ^[0-9]+$ ]] || [ "$SEL_INDEX" -lt 1 ] || [ "$SEL_INDEX" -gt "$user_count" ]; then
        echo -e "${YELLOW}已取消操作或输入无效。${PLAIN}"
        return
    fi
    
    local target_name=${user_names[$SEL_INDEX]}
    
    # 读取该用户当前配置，供各选项修改前回显对照
    local cur_expire=$(get_toml_val "access.user_expirations" "$target_name")
    local cur_quota=$(get_toml_val "access.user_data_quota" "$target_name")
    local cur_speed=$(get_toml_val "access.user_speed_limits" "$target_name")
    local cur_secret=$(get_toml_val "access.users" "$target_name")
    local cur_port=$(get_toml_val "access.user_ports" "$target_name")
    
    echo -e "您正在为 ${GREEN}$target_name${PLAIN} 配置："
    echo -e "1. ${YELLOW}仅清空当期已用流量账单 (恢复全部配额)${PLAIN}"
    echo -e "2. ${YELLOW}重新设定到期期限并清空账单${PLAIN}"
    echo -e "3. ${YELLOW}重新设定配额上限并清空账单${PLAIN}"
    echo -e "4. ${YELLOW}一键设定配额+到期日 (适合无限制用户转为受限)${PLAIN}"
    echo -e "5. ${YELLOW}重新单独设定网速带宽上下行分离限制${PLAIN}"
    echo -e "6. ${YELLOW}修改通信密钥 (强制该用户重新登录)${PLAIN}"
    echo -e "7. ${YELLOW}重新分配/移除专属独立端口${PLAIN}"
    read -p "选择重置策略 [1-7] (回车默认1): " POL_OPT
    [ -z "$POL_OPT" ] && POL_OPT=1
    
    if [ "$POL_OPT" -eq 1 ]; then
        if [ -f "/etc/telemt_quota.json" ]; then
            sed -i "s/\"$target_name\":[0-9]*/\"$target_name\":0/g" /etc/telemt_quota.json
            echo -e "${GREEN}已清空用户 $target_name 的配额用量账单。${PLAIN}"
        fi
    elif [ "$POL_OPT" -eq 2 ]; then
        if [ -n "$cur_expire" ]; then
            CUR_EXP_DISP=$(echo "$cur_expire" | tr 'T' ' ' | sed 's/+.*$//')
            echo -e "当前到期: ${YELLOW}${CUR_EXP_DISP}${PLAIN}"
        else
            echo -e "当前到期: ${YELLOW}永久有效${PLAIN}"
        fi
        read -p "请输入新的强制到期日期 (格式 2026-10-01 或 2026-10-01 12:00:00, 回车表示取消限期): " NEW_EXPIRE
        NEW_EXPIRE=$(echo "$NEW_EXPIRE" | tr -d '\r' | xargs)
        sed -i "/^\[access\.user_expirations\]/,/^\[/{/^$target_name *=/d}" /etc/telemt.toml
        if [ -n "$NEW_EXPIRE" ]; then
            if echo "$NEW_EXPIRE" | grep -q " "; then
                ISO_EXPIRE="$(echo "$NEW_EXPIRE" | tr ' ' 'T')+08:00"
            else
                ISO_EXPIRE="${NEW_EXPIRE}T23:59:59+08:00"
            fi
            if ! grep -q "^\[access\.user_expirations\]" /etc/telemt.toml; then
                echo "" >> /etc/telemt.toml
                echo "[access.user_expirations]" >> /etc/telemt.toml
            fi
            sed -i "/^\[access\.user_expirations\]/a $target_name = $ISO_EXPIRE" /etc/telemt.toml
            
            if [ -f "/etc/telemt_quota.json" ]; then
                sed -i "s/\"$target_name\":[0-9]*/\"$target_name\":0/g" /etc/telemt_quota.json
            fi
            echo -e "${GREEN}已为 $target_name 充值并延期至 $NEW_EXPIRE。${PLAIN}"
        else
            if [ -f "/etc/telemt_quota.json" ]; then
                sed -i "s/\"$target_name\":[0-9]*/\"$target_name\":0/g" /etc/telemt_quota.json
            fi
            echo -e "${GREEN}已彻底解除该用户的期限限制，恢复为永久有效。${PLAIN}"
        fi
    elif [ "$POL_OPT" -eq 3 ]; then
        if [ -n "$cur_quota" ]; then
            CUR_QUOTA_GB=$(awk "BEGIN {printf \"%.2f\", $cur_quota / 1073741824}")
            echo -e "当前配额: ${YELLOW}${CUR_QUOTA_GB} GB${PLAIN}"
        else
            echo -e "当前配额: ${YELLOW}未设置 (无限制)${PLAIN}"
        fi
        read -p "请输入此用户的新的总流量配额上限 (GB为单位, 回车则解除配额): " NEW_QUOTA
        NEW_QUOTA=$(echo "$NEW_QUOTA" | tr -d '\r ')
        sed -i "/^\[access\.user_data_quota\]/,/^\[/{/^$target_name *=/d}" /etc/telemt.toml
        if [[ -n "$NEW_QUOTA" && "$NEW_QUOTA" =~ ^[0-9.]+$ ]]; then
            QUOTA_BYTES=$(awk "BEGIN {printf \"%.0f\", $NEW_QUOTA * 1073741824}")
            if ! grep -q "^\[access\.user_data_quota\]" /etc/telemt.toml; then
                echo "" >> /etc/telemt.toml
                echo "[access.user_data_quota]" >> /etc/telemt.toml
            fi
            sed -i "/^\[access\.user_data_quota\]/a $target_name = $QUOTA_BYTES" /etc/telemt.toml
            
            if [ -f "/etc/telemt_quota.json" ]; then
                sed -i "s/\"$target_name\":[0-9]*/\"$target_name\":0/g" /etc/telemt_quota.json
            fi
            echo -e "${GREEN}已拉高 $target_name 的配额为 $NEW_QUOTA GB 并恢复可用状态。${PLAIN}"
        else
            if [ -f "/etc/telemt_quota.json" ]; then
                sed -i "s/\"$target_name\":[0-9]*/\"$target_name\":0/g" /etc/telemt_quota.json
            fi
            echo -e "${GREEN}已彻底解除该用户的流量配额限制！${PLAIN}"
        fi
    elif [ "$POL_OPT" -eq 4 ]; then
        echo -e "${BLUE}—— 一键设定配额 + 到期日（适合无限制用户转为受限）——${PLAIN}"
        if [ -n "$cur_quota" ]; then
            CUR_QUOTA_GB=$(awk "BEGIN {printf \"%.2f\", $cur_quota / 1073741824}")
            echo -e "当前配额: ${YELLOW}${CUR_QUOTA_GB} GB${PLAIN}"
        else
            echo -e "当前配额: ${YELLOW}未设置 (无限制)${PLAIN}"
        fi
        
        read -p "请输入流量配额 (GB为单位, 回车表示解除配额): " NEW_QUOTA
        NEW_QUOTA=$(echo "$NEW_QUOTA" | tr -d '\r ')
        sed -i "/^\[access\.user_data_quota\]/,/^\[/{/^$target_name *=/d}" /etc/telemt.toml
        if [[ -n "$NEW_QUOTA" && "$NEW_QUOTA" =~ ^[0-9.]+$ ]]; then
            QUOTA_BYTES=$(awk "BEGIN {printf \"%.0f\", $NEW_QUOTA * 1073741824}")
            if ! grep -q "^\[access\.user_data_quota\]" /etc/telemt.toml; then
                echo "" >> /etc/telemt.toml
                echo "[access.user_data_quota]" >> /etc/telemt.toml
            fi
            sed -i "/^\[access\.user_data_quota\]/a $target_name = $QUOTA_BYTES" /etc/telemt.toml
            if [ -f "/etc/telemt_quota.json" ]; then
                sed -i "s/\"$target_name\":[0-9]*/\"$target_name\":0/g" /etc/telemt_quota.json
            fi
            echo -e "${GREEN}已为 $target_name 设定配额: ${NEW_QUOTA} GB${PLAIN}"
        else
            if [ -f "/etc/telemt_quota.json" ]; then
                sed -i "s/\"$target_name\":[0-9]*/\"$target_name\":0/g" /etc/telemt_quota.json
            fi
            echo -e "${YELLOW}已解除该用户的流量配额限制。${PLAIN}"
        fi
        
        if [ -n "$cur_expire" ]; then
            CUR_EXP_DISP=$(echo "$cur_expire" | tr 'T' ' ' | sed 's/+.*$//')
            echo -e "当前到期: ${YELLOW}${CUR_EXP_DISP}${PLAIN}"
        else
            echo -e "当前到期: ${YELLOW}永久有效${PLAIN}"
        fi
        read -p "请输入到期日期 (格式 2026-10-01 或 2026-10-01 12:00:00, 回车表示取消限期): " NEW_EXPIRE
        NEW_EXPIRE=$(echo "$NEW_EXPIRE" | tr -d '\r' | xargs)
        sed -i "/^\[access\.user_expirations\]/,/^\[/{/^$target_name *=/d}" /etc/telemt.toml
        if [ -n "$NEW_EXPIRE" ]; then
            if echo "$NEW_EXPIRE" | grep -q " "; then
                ISO_EXPIRE="$(echo "$NEW_EXPIRE" | tr ' ' 'T')+08:00"
            else
                ISO_EXPIRE="${NEW_EXPIRE}T23:59:59+08:00"
            fi
            if ! grep -q "^\[access\.user_expirations\]" /etc/telemt.toml; then
                echo "" >> /etc/telemt.toml
                echo "[access.user_expirations]" >> /etc/telemt.toml
            fi
            sed -i "/^\[access\.user_expirations\]/a $target_name = $ISO_EXPIRE" /etc/telemt.toml
            
            echo -e "${GREEN}已为 $target_name 设定到期日: $NEW_EXPIRE${PLAIN}"
        else
            echo -e "${YELLOW}该用户已设为永久有效。${PLAIN}"
        fi
    elif [ "$POL_OPT" -eq 5 ]; then
        echo -e "${BLUE}—— 重新分配独立上下行网速 ——${PLAIN}"
        if [ -n "$cur_speed" ]; then
            SP_UP=$(echo "$cur_speed" | awk '{print $1}')
            SP_DN=$(echo "$cur_speed" | awk '{print $2}')
            [ -z "$SP_DN" ] && SP_DN=$SP_UP
            echo -e "当前限速: ${YELLOW}↑上行 ${SP_UP} MB/s ｜ ↓下行 ${SP_DN} MB/s${PLAIN}"
        else
            echo -e "当前限速: ${YELLOW}无限制极速${PLAIN}"
        fi
        read -p "请输入该用户【上行】速度限制 (MB/s, 例如 1.5, 回车则极速不限流): " SPEED_UP
        SPEED_UP=$(echo "$SPEED_UP" | tr -d '\r ' | xargs)
        if [ -n "$SPEED_UP" ]; then
            read -p "请输入该用户【下行】速度限制 (MB/s, 例如 5.0, 回车默认与上行相同): " SPEED_DOWN
            SPEED_DOWN=$(echo "$SPEED_DOWN" | tr -d '\r ' | xargs)
            [ -z "$SPEED_DOWN" ] && SPEED_DOWN=$SPEED_UP
            NEW_SPEED="$SPEED_UP $SPEED_DOWN"
        else
            NEW_SPEED=""
        fi
        
        sed -i "/^\[access\.user_speed_limits\]/,/^\[/{/^$target_name *=/d}" /etc/telemt.toml
        if [ -n "$NEW_SPEED" ]; then
            if ! grep -q "^\[access\.user_speed_limits\]" /etc/telemt.toml; then
                echo "" >> /etc/telemt.toml
                echo "[access.user_speed_limits]" >> /etc/telemt.toml
            fi
            sed -i "/^\[access\.user_speed_limits\]/a $target_name = \"$NEW_SPEED\"" /etc/telemt.toml
            echo -e "${GREEN}已成功赋予速度上限：$NEW_SPEED MB/s。${PLAIN}"
        else
            echo -e "${GREEN}该用户的通道限制已经彻底解除！${PLAIN}"
        fi
    elif [ "$POL_OPT" -eq 6 ]; then
        echo -e "${BLUE}—— 修改通信密钥 ——${PLAIN}"
        if [ -n "$cur_secret" ]; then
            echo -e "当前密钥: ${YELLOW}${cur_secret}${PLAIN}"
        fi
        read -p "请输入新的通信密钥 (32 位 hex, 回车自动生成): " NEW_SECRET
        NEW_SECRET=$(echo "$NEW_SECRET" | tr -d '\r ' | xargs)
        [ -z "$NEW_SECRET" ] && NEW_SECRET=$(generate_secret)
        if ! [[ "$NEW_SECRET" =~ ^[0-9a-fA-F]{32}$ ]]; then
            echo -e "${RED}密钥非法 (必须为 32 位 hex)，本次修改已中止！${PLAIN}"
        else
            sed -i "/^\[access\.users\]/,/^\[/{/^[ \"]*$target_name[ \"]*=/d}" /etc/telemt.toml
            sed -i "/^\[access\.users\]/a $target_name = \"$NEW_SECRET\"" /etc/telemt.toml
            echo -e "${GREEN}已为 $target_name 更新通信密钥，旧密钥立即失效。${PLAIN}"
        fi
    elif [ "$POL_OPT" -eq 7 ]; then
        echo -e "${BLUE}—— 重新分配专属独立端口 ——${PLAIN}"
        if [ -n "$cur_port" ]; then
            echo -e "当前专属端口: ${YELLOW}${cur_port}${PLAIN}"
        else
            echo -e "当前端口: ${YELLOW}全局共享${PLAIN}"
        fi
        read -p "请输入新的专属端口 (1-65535, 回车或 0 表示移除专属端口恢复共享): " NEW_DEDICATED_PORT
        NEW_DEDICATED_PORT=$(echo "$NEW_DEDICATED_PORT" | tr -d '\r ' | xargs)
        sed -i "/^\[access\.user_ports\]/,/^\[/{/^$target_name *=/d}" /etc/telemt.toml
        if [ -n "$NEW_DEDICATED_PORT" ] && [ "$NEW_DEDICATED_PORT" != "0" ]; then
            if ! [[ "$NEW_DEDICATED_PORT" =~ ^[0-9]+$ ]] || [ "$NEW_DEDICATED_PORT" -lt 1 ] || [ "$NEW_DEDICATED_PORT" -gt 65535 ]; then
                echo -e "${RED}端口必须是在 1-65535 之间的合法数字！${PLAIN}"
            elif grep -q "port = $NEW_DEDICATED_PORT$" /etc/telemt.toml || grep -E -q "= \"?$NEW_DEDICATED_PORT\"?$" /etc/telemt.toml; then
                echo -e "${RED}严重冲突：端口 $NEW_DEDICATED_PORT 已被占用！${PLAIN}"
            else
                if ! grep -q "^\[access\.user_ports\]" /etc/telemt.toml; then
                    echo "" >> /etc/telemt.toml
                    echo "[access.user_ports]" >> /etc/telemt.toml
                fi
                sed -i "/^\[access\.user_ports\]/a $target_name = $NEW_DEDICATED_PORT" /etc/telemt.toml
                echo -e "${GREEN}已为 $target_name 分配专属端口: $NEW_DEDICATED_PORT。${PLAIN}"
            fi
        else
            echo -e "${GREEN}已移除 $target_name 的专属端口，恢复为共享端口。${PLAIN}"
        fi
    fi
    
    # 凡是清空过账单的策略（1/2/3/4），同步清除该用户本月"耗尽时间"记录
    if [ "$POL_OPT" -eq 1 ] || [ "$POL_OPT" -eq 2 ] || [ "$POL_OPT" -eq 3 ] || [ "$POL_OPT" -eq 4 ]; then
        clear_exhausted_record "$target_name"
    fi
    
    echo -e "${BLUE}正在重载配置以释放最新数据 ...${PLAIN}"
    control_service restart telemt >/dev/null 2>&1
    echo -e "${GREEN}操作成功！${PLAIN}"
}


# --- 流量配额自动月度重置 ---

# 核心重置引擎：归零所有未过期用户的已用流量
auto_reset_quota() {
    local quota_json="/etc/telemt_quota.json"
    local toml_file="/etc/telemt.toml"
    local log_file="/var/log/telemt_reset.log"
    
    if [ ! -f "$toml_file" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 错误: 配置文件 $toml_file 不存在，跳过重置" >> "$log_file"
        return 1
    fi
    if [ ! -f "$quota_json" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 信息: 流量记录 $quota_json 不存在，无需重置" >> "$log_file"
        return 0
    fi
    
    # 重置前先做一次快照，完整保留本月最终用量与耗尽时间
    snapshot_traffic_stats
    
    # 收集过期用户列表（这些用户不重置）
    local current_iso=$(date +"%Y-%m-%d %H:%M:%S")
    local expired_users=""
    local in_expire_section=0
    while IFS= read -r line; do
        if echo "$line" | grep -q '^\[access\.user_expirations\]'; then
            in_expire_section=1
            continue
        fi
        if echo "$line" | grep -q '^\[' && [ $in_expire_section -eq 1 ]; then
            break
        fi
        if [ $in_expire_section -eq 1 ]; then
            local uname=$(echo "$line" | cut -d'=' -f1 | xargs)
            local uexpire=$(echo "$line" | cut -d'=' -f2 | xargs)
            if [ -n "$uname" ] && [ -n "$uexpire" ]; then
                local end_iso=$(echo "$uexpire" | sed 's/+.*//' | tr 'T' ' ')
                local is_expired=$(awk -v d1="$current_iso" -v d2="$end_iso" 'BEGIN {print (d1 > d2) ? 1 : 0}')
                if [ "$is_expired" -eq 1 ]; then
                    expired_users="$expired_users $uname"
                fi
            fi
        fi
    done < "$toml_file"
    
    # 收集有配额的用户列表
    local in_quota_section=0
    local reset_count=0
    local skip_count=0
    while IFS= read -r line; do
        if echo "$line" | grep -q '^\[access\.user_data_quota\]'; then
            in_quota_section=1
            continue
        fi
        if echo "$line" | grep -q '^\[' && [ $in_quota_section -eq 1 ]; then
            break
        fi
        if [ $in_quota_section -eq 1 ]; then
            local uname=$(echo "$line" | cut -d'=' -f1 | xargs)
            if [ -n "$uname" ]; then
                # 检查是否在过期名单中
                if echo "$expired_users" | grep -qw "$uname"; then
                    skip_count=$((skip_count + 1))
                else
                    # 归零该用户的流量
                    sed -i "s/\"$uname\":[0-9]*/\"$uname\":0/g" "$quota_json"
                    clear_exhausted_record "$uname"
                    reset_count=$((reset_count + 1))
                fi
            fi
        fi
    done < "$toml_file"
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] 自动重置完成: 成功归零 $reset_count 位活跃用户, 跳过 $skip_count 位已过期用户" >> "$log_file"
    
    # 重启服务刷新内存缓存
    if [[ "$INIT_SYSTEM" == "systemd" ]]; then
        systemctl restart telemt 2>/dev/null
    else
        rc-service telemt restart 2>/dev/null
    fi
    
    return 0
}

# Cron 入口调度器：每天零点被 Cron 调用，判断今天是否需要执行重置
check_and_reset_quota() {
    local conf_file="/etc/telemt_reset.conf"
    
    # 无论是否配置自动重置，每次调用都先记录一次流量快照
    snapshot_traffic_stats
    
    if [ ! -f "$conf_file" ]; then
        return 0
    fi
    
    source "$conf_file"
    
    if [ "$MODE" == "disabled" ]; then
        return 0
    fi
    
    if [ "$MODE" == "monthly" ]; then
        local today_day=$(date +"%d" | sed 's/^0//')
        local reset_day=${RESET_DAY:-1}
        if [ "$today_day" -eq "$reset_day" ]; then
            auto_reset_quota
        fi
    elif [ "$MODE" == "once" ]; then
        local today=$(date +"%Y-%m-%d")
        if [ "$today" == "$ONCE_DATE" ]; then
            auto_reset_quota
            # 执行完毕后自动切换为 disabled
            sed -i 's/^MODE=.*/MODE=disabled/' "$conf_file"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] 一次性重置任务已执行完毕，自动关闭" >> /var/log/telemt_reset.log
        fi
    fi
}

# 交互式 Cron 配置
setup_quota_reset_cron() {
    echo -e ""
    echo -e "${BLUE}======================================${PLAIN}"
    echo -e "${GREEN}    流量配额自动重置配置向导    ${PLAIN}"
    echo -e "${BLUE}======================================${PLAIN}"
    echo -e ""
    
    # 显示当前配置状态
    if [ -f "/etc/telemt_reset.conf" ]; then
        source /etc/telemt_reset.conf
        echo -e "  当前配置："
        if [ "$MODE" == "monthly" ]; then
            echo -e "  模式: ${GREEN}每月循环${PLAIN} (每月 ${YELLOW}${RESET_DAY:-1}${PLAIN} 号零点自动重置)"
        elif [ "$MODE" == "once" ]; then
            echo -e "  模式: ${YELLOW}一次性${PLAIN} (目标日期: ${ONCE_DATE})"
        else
            echo -e "  模式: ${RED}已关闭${PLAIN}"
        fi
        echo -e ""
    fi
    
    # 显示各用户的配额重置覆盖情况
    if [ -f "/etc/telemt.toml" ]; then
        echo -e "${BLUE}--- 用户流量配额概览 ---${PLAIN}"
        
        # 先收集有配额的用户及其限额
        local -A quota_map
        local in_q=0
        while IFS= read -r line; do
            if echo "$line" | grep -q '^\[access\.user_data_quota\]'; then
                in_q=1; continue
            fi
            if echo "$line" | grep -q '^\[' && [ $in_q -eq 1 ]; then
                break
            fi
            if [ $in_q -eq 1 ]; then
                local qn=$(echo "$line" | cut -d'=' -f1 | xargs)
                local qv=$(echo "$line" | cut -d'=' -f2 | xargs)
                if [ -n "$qn" ] && [ -n "$qv" ]; then
                    quota_map[$qn]=$qv
                fi
            fi
        done < /etc/telemt.toml
        
        # 遍历所有用户并显示状态
        local in_u=0
        while IFS= read -r line; do
            if echo "$line" | grep -q '^\[access\.users\]'; then
                in_u=1; continue
            fi
            if echo "$line" | grep -q '^\[' && [ $in_u -eq 1 ]; then
                break
            fi
            if [ $in_u -eq 1 ] && [ -n "$line" ] && ! echo "$line" | grep -q '^#'; then
                local un=$(echo "$line" | cut -d'=' -f1 | xargs)
                if [ -n "$un" ]; then
                    if [ -n "${quota_map[$un]}" ]; then
                        local gb=$(awk "BEGIN {printf \"%.2f\", ${quota_map[$un]} / 1073741824}")
                        echo -e "  👤 ${YELLOW}$un${PLAIN}: ${GREEN}✅ 已设置流量配额${PLAIN} (${gb} GB/月, 参与自动重置)"
                    else
                        echo -e "  👤 ${YELLOW}$un${PLAIN}: ${YELLOW}⏭️  未配置流量配额${PLAIN} (不限流, 不参与重置)"
                    fi
                fi
            fi
        done < /etc/telemt.toml
        echo -e ""
    fi
    
    echo -e "  ${GREEN}1.${PLAIN} 启用每月循环重置 (默认每月1号零点)"
    echo -e "  ${GREEN}2.${PLAIN} 设置一次性重置 (指定某天执行一次后自动关闭)"
    echo -e "  ${GREEN}3.${PLAIN} 关闭自动重置"
    echo -e "  ${GREEN}0.${PLAIN} 返回"
    echo -e ""
    read -p "  请选择 [0-3]: " reset_choice
    reset_choice=$(echo "$reset_choice" | tr -d '\r ')
    
    case $reset_choice in
        1)
            read -p "请输入每月重置日 (直接回车默认为1号): " reset_day
            reset_day=$(echo "$reset_day" | tr -d '\r ')
            [ -z "$reset_day" ] && reset_day=1
            
            # 写入配置
            cat > /etc/telemt_reset.conf <<EOF
# Telemt 流量配额自动重置配置
MODE=monthly
RESET_DAY=$reset_day
ONCE_DATE=
EOF
            # 注册 Cron
            install_reset_cron
            echo -e "${GREEN}✅ 已启用每月循环重置！每月 ${reset_day} 号零点将自动归零所有活跃用户的流量。${PLAIN}"
            echo -e "${YELLOW}📌 已过期的用户将被跳过，不会被重置。${PLAIN}"
            ;;
        2)
            echo -e "${YELLOW}⚠️  注意：自定义日期仅会执行一次重置，执行后将自动关闭！${PLAIN}"
            read -p "请输入一次性重置的目标日期 (格式 2026-04-01): " once_date
            once_date=$(echo "$once_date" | tr -d '\r ')
            if [ -z "$once_date" ]; then
                echo -e "${RED}未输入日期，操作取消。${PLAIN}"
                return
            fi
            
            cat > /etc/telemt_reset.conf <<EOF
# Telemt 流量配额自动重置配置
MODE=once
RESET_DAY=
ONCE_DATE=$once_date
EOF
            install_reset_cron
            echo -e "${GREEN}✅ 已设置一次性重置！将在 ${once_date} 零点执行一次流量归零。${PLAIN}"
            echo -e "${YELLOW}⚠️  此任务仅执行一次，执行后将自动关闭。${PLAIN}"
            echo -e "${YELLOW}📌 已过期的用户将被跳过，不会被重置。${PLAIN}"
            ;;
        3)
            if [ -f "/etc/telemt_reset.conf" ]; then
                sed -i 's/^MODE=.*/MODE=disabled/' /etc/telemt_reset.conf
            fi
            remove_reset_cron
            echo -e "${GREEN}已关闭自动重置。${PLAIN}"
            ;;
        0) return ;;
        *) echo -e "${RED}无效选项${PLAIN}" ;;
    esac
}

# 注册 Cron 定时任务（每天零点静默检查）
install_reset_cron() {
    local cron_cmd="0 0 * * * /usr/local/bin/mtp check_reset >/dev/null 2>&1"
    
    # 先移除旧的同类条目，再添加
    (crontab -l 2>/dev/null | grep -v "mtp check_reset"; echo "$cron_cmd") | crontab -
    
    # 确保 Cron 服务已启动
    if [[ "$INIT_SYSTEM" == "systemd" ]]; then
        systemctl enable cron 2>/dev/null || systemctl enable crond 2>/dev/null
        systemctl start cron 2>/dev/null || systemctl start crond 2>/dev/null
    else
        rc-update add crond default 2>/dev/null
        rc-service crond start 2>/dev/null
    fi
}

# 移除 Cron 定时任务
remove_reset_cron() {
    crontab -l 2>/dev/null | grep -v "mtp check_reset" | crontab -
}

# 注册流量快照 Cron（每小时整点静默记录一次，保证耗尽时间能被及时捕捉）
install_traffic_cron() {
    local cron_cmd="0 * * * * /usr/local/bin/mtp traffic_snapshot >/dev/null 2>&1"

    (crontab -l 2>/dev/null | grep -v "mtp traffic_snapshot"; echo "$cron_cmd") | crontab -

    if [[ "$INIT_SYSTEM" == "systemd" ]]; then
        systemctl enable cron 2>/dev/null || systemctl enable crond 2>/dev/null
        systemctl start cron 2>/dev/null || systemctl start crond 2>/dev/null
    else
        rc-update add crond default 2>/dev/null
        rc-service crond start 2>/dev/null
    fi
}

# 移除流量快照 Cron
remove_traffic_cron() {
    crontab -l 2>/dev/null | grep -v "mtp traffic_snapshot" | crontab -
}

# 查看当前自动重置状态
show_reset_status() {
    echo -e ""
    echo -e "${BLUE}--- 自动重置配置状态 ---${PLAIN}"
    
    if [ ! -f "/etc/telemt_reset.conf" ]; then
        echo -e "  状态: ${YELLOW}尚未配置${PLAIN}"
    else
        source /etc/telemt_reset.conf
        if [ "$MODE" == "monthly" ]; then
            echo -e "  模式: ${GREEN}🔄 每月循环${PLAIN}"
            echo -e "  重置日: 每月 ${YELLOW}${RESET_DAY:-1}${PLAIN} 号零点"
            echo -e "  范围: 仅归零活跃未过期用户"
        elif [ "$MODE" == "once" ]; then
            echo -e "  模式: ${YELLOW}📌 一次性${PLAIN}"
            echo -e "  目标日期: ${YELLOW}${ONCE_DATE}${PLAIN}"
            echo -e "  状态: 等待执行（执行后自动关闭）"
        else
            echo -e "  模式: ${RED}已关闭${PLAIN}"
        fi
    fi
    
    # 显示最近的重置日志
    if [ -f "/var/log/telemt_reset.log" ]; then
        echo -e ""
        echo -e "${BLUE}--- 最近重置记录 ---${PLAIN}"
        tail -5 /var/log/telemt_reset.log
    fi
    echo -e ""
}

manage_telemt_users() {
    clear
    echo -e "${BLUE}======================================${PLAIN}"
    echo -e "${GREEN}      Telemt 高级多用户管理菜单     ${PLAIN}"
    echo -e "${BLUE}======================================${PLAIN}"
    echo -e "  ${GREEN}1.${PLAIN} 查看所有用户及专属分享链接"
    echo -e "  ${GREEN}2.${PLAIN} 查询指定用户配置 (模糊匹配)"
    echo -e "  ${GREEN}3.${PLAIN} 添加新用户"
    echo -e "  ${GREEN}4.${PLAIN} 踢出(删除)指定用户"
    echo -e "  ${GREEN}5.${PLAIN} 管理配额/到期/限速/密钥/端口"
    echo -e "  ${GREEN}6.${PLAIN} 自动重置配置 (Cron 月度轮转)"
    echo -e "  ${GREEN}0.${PLAIN} 返回主菜单"
    echo -e "${BLUE}======================================${PLAIN}"
    read -p "  请选择操作 [0-6]: " tm_choice
    case $tm_choice in
        1) list_telemt_users ;;
        2) query_telemt_user ;;
        3) add_telemt_user ;;
        4) del_telemt_user ;;
        5) reset_telemt_user_quota ;;
        6) setup_quota_reset_cron; show_reset_status ;;
        0) return ;;
        *) echo -e "${RED}无效选项${PLAIN}"; sleep 1 ;;
    esac
    
    echo ""
    read -n 1 -s -r -p "按任意键继续..."
    manage_telemt_users
}

# --- 菜单 ---
menu() {
    clear
    echo -e ""
    echo -e "${BLUE} __  __ _____ ____                      ${PLAIN}"
    echo -e "${BLUE}|  \/  |_   _|  _ \ _ __ _____  ___   _ ${PLAIN}"
    echo -e "${BLUE}| |\/| | | | | |_) | '__/ _ \ \/ / | | |${PLAIN}"
    echo -e "${BLUE}| |  | | | | |  __/| | | (_) >  <| |_| |${PLAIN}"
    echo -e "${BLUE}|_|  |_| |_| |_|   |_|  \___/_/\_\\\\__, |${PLAIN}"
    echo -e "${BLUE}                                  |___/ ${PLAIN}${GREEN}Lite Manager${PLAIN}"
    echo -e ""
    echo -e "  ${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
    echo -e "          ${GREEN}MTProxy 管理脚本${PLAIN}  ${YELLOW}${SCRIPT_VERSION}${PLAIN}"
    echo -e "          ${GREEN}Author: ${SCRIPT_AUTHOR}${PLAIN}"
    echo -e "  ${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${PLAIN}"
    echo -e ""
    echo -e "  系统: ${GREEN}${OS}${PLAIN}  |  模式: ${GREEN}${INIT_SYSTEM}${PLAIN}"
    echo -e "  Go 版: $(get_service_status_str mtg)  Telemt 版: $(get_service_status_str telemt)"
    echo -e "  Telegram 推送: $(get_tg_status_str)"
    echo -e ""
    echo -e "  ${YELLOW}【安 装】${PLAIN}"
    echo -e "    ${GREEN}[1]${PLAIN} 安装 Go 版          ${GREEN}[2]${PLAIN} 安装 Telemt (高性能进阶版)"
    echo -e ""
    echo -e "  ${YELLOW}【管 理】${PLAIN}"
    echo -e "    ${GREEN}[3]${PLAIN} 查看连接信息        ${GREEN}[4]${PLAIN} 修改配置"
    echo -e "    ${GREEN}[5]${PLAIN} 删除配置            ${GREEN}[6]${PLAIN} Telemt 多用户管理"
    echo -e ""
    echo -e "  ${YELLOW}【TG 配置】${PLAIN}"
    echo -e "    ${GREEN}[7]${PLAIN} Telegram 推送配置   ${GREEN}[8]${PLAIN} 用户流量统计"
    echo -e "    ${GREEN}[9]${PLAIN} 立即发送统计        ${GREEN}[10]${PLAIN} 总流量统计"
    echo -e ""
    echo -e "  ${YELLOW}【状态与日志】${PLAIN}"
    echo -e "    ${GREEN}[11]${PLAIN} 查看运行状态        ${GREEN}[12]${PLAIN} 查看日志"
    echo -e ""
    echo -e "  ${YELLOW}【服务控制】${PLAIN}"
    echo -e "    ${GREEN}[13]${PLAIN} 启动服务           ${GREEN}[14]${PLAIN} 停止服务"
    echo -e "    ${GREEN}[15]${PLAIN} 重启服务"
    echo -e ""
    echo -e "  ${RED}【危险操作】${PLAIN}"
    echo -e "    ${RED}[16]${PLAIN} 卸载全部并清理"
    echo -e ""
    echo -e "    ${GREEN}[0]${PLAIN} 退出脚本"
    echo -e ""
    read -p "  请输入选项 [0-16]: " choice
    debug_log "【调试】menu 选择: $choice"

    case $choice in
        1) install_base_deps; install_mtg; back_to_menu ;;
        2) install_base_deps; install_telemt; back_to_menu ;;
        3) show_detail_info ;;
        4) modify_config ;;
        5) delete_config ;;
        6) manage_telemt_users; back_to_menu ;;
        7) setup_tg_push; back_to_menu ;;
        8) traffic_usage_report; back_to_menu ;;
        9) tg_usage_report force; back_to_menu ;;
        10) traffic_total_report; back_to_menu ;;
        11) check_all_status; back_to_menu ;;
        12) view_logs; back_to_menu ;;
        13) control_service start; back_to_menu ;;
        14) control_service stop; back_to_menu ;;
        15) control_service restart; back_to_menu ;;
        16) delete_all; exit 0 ;;
        0) echo -e "${GREEN}再见!${PLAIN}"; exit 0 ;;
        *) echo -e "${RED}无效选项${PLAIN}"; sleep 1; menu ;;
    esac
}

check_sys

# 需要 root 权限写 /etc 与安装服务
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}请以 root 用户运行本脚本！${PLAIN}"
    exit 1
fi

# 命令行参数：支持 Cron 静默调用与无交互安装/管理
_cmd0="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')"
debug_log "【调试】入口参数: _cmd0=$_cmd0"
debug_log "【调试】关键环境变量: INSTALL_MODE=$INSTALL_MODE NON_INTERACTIVE=$NON_INTERACTIVE PORT=$PORT IP_MODE=$IP_MODE DOMAIN=$DOMAIN TELEMT_USER=$TELEMT_USER TELEMT_SECRET=$TELEMT_SECRET TELEMT_DEDICATED_PORT=$TELEMT_DEDICATED_PORT TELEMT_QUOTA=$TELEMT_QUOTA TELEMT_EXPIRE=$TELEMT_EXPIRE TELEMT_SPEED_UP=$TELEMT_SPEED_UP TELEMT_SPEED_DOWN=$TELEMT_SPEED_DOWN"

case "$_cmd0" in
    check_reset)
        check_and_reset_quota
        exit 0
        ;;
    force_reset)
        echo -e "${BLUE}正在立即执行流量配额重置...${PLAIN}"
        auto_reset_quota
        echo -e "${GREEN}重置完成！以下为最新日志:${PLAIN}"
        tail -3 /var/log/telemt_reset.log 2>/dev/null
        exit 0
        ;;
    rep)
        NON_INTERACTIVE=1
        install_base_deps
        rep_cleanup
        install_selected
        exit 0
        ;;
    ins)
        NON_INTERACTIVE=1
        install_base_deps
        install_selected
        exit 0
        ;;
    del)
        delete_all
        exit 0
        ;;
    adduser)
        NON_INTERACTIVE=1
        add_telemt_user
        exit $?
        ;;
    users)
        NON_INTERACTIVE=1
        list_telemt_users_plain
        exit $?
        ;;
    moduser)
        NON_INTERACTIVE=1
        modify_telemt_user
        exit $?
        ;;
    getuser)
        NON_INTERACTIVE=1
        show_telemt_user
        exit $?
        ;;
    deluser)
        NON_INTERACTIVE=1
        del_telemt_user_by_name
        exit $?
        ;;
    usage|traffic|stats)
        NON_INTERACTIVE=1
        traffic_usage_report
        exit $?
        ;;
    usage_total|traffic_total|total)
        NON_INTERACTIVE=1
        traffic_total_report
        exit $?
        ;;
    traffic_snapshot)
        NON_INTERACTIVE=1
        snapshot_traffic_stats
        exit $?
        ;;
    tg_report)
        NON_INTERACTIVE=1
        tg_usage_report force
        exit $?
        ;;
    tg_autopush)
        NON_INTERACTIVE=1
        tg_usage_report
        exit $?
        ;;
    tg_config)
        NON_INTERACTIVE=1
        setup_tg_push
        exit $?
        ;;
    list)
        NON_INTERACTIVE=1
        show_detail_info
        exit 0
        ;;
    start)
        control_service start
        exit 0
        ;;
    stop)
        control_service stop
        exit 0
        ;;
    restart)
        control_service restart
        exit 0
        ;;
esac

# 无参数：进入交互式菜单
menu
