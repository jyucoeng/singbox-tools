#!/bin/bash

# ===========================================
# sing-box VLESS-REALITY 一键部署脚本
# ===========================================

# ===========================================
# 常量定义
# ===========================================

# 项目信息常量
AUTHOR="LittleDoraemon"
VERSION="v1.0.3"

# 默认SNI常量
SNI_DEFAULT="www.yahoo.com"

# 调试模式（可通过环境变量 DEBUG_MODE=true 启用）
DEBUG_MODE=${DEBUG_MODE:-false}

# 系统检查执行状态（防止重复执行）
SYSTEM_CHECKS_PERFORMED="false"

# 文件路径常量
LOG_FILE="/var/log/sing-box-install.log"
CONFIG_DIR="/etc/sing-box"
CONFIG_FILE="$CONFIG_DIR/sb-vless.json"
KEYS_DIR="$CONFIG_DIR/keys"
PUBLIC_KEY_FILE="$KEYS_DIR/public.key"
PRIVATE_KEY_FILE="$KEYS_DIR/private.key"
BACKUP_DIR="$CONFIG_DIR/backup"

# Unicode符号常量
CHECK_MARK='\u2705'  # 白色对勾✅
CROSS_MARK='\u274C'  # 红色叉号❌
WARNING_SIGN='\u26A0'  # 警告符号⚠️

# 颜色定义常量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
SKYBLUE='\033[0;36m'
BROWN='\033[0;33m'
NC='\033[0m' # No Color

# ===========================================
# 日志记录函数
# ===========================================

log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() {
    log "INFO" "$1"
}

log_warn() {
    log "WARN" "$1"
}

log_error() {
    log "ERROR" "$1"
}

log_debug() {
    # 仅在调试模式下记录调试信息
    if [[ "${DEBUG_MODE}" == "true" ]]; then
        log "DEBUG" "$1"
    fi
}

# ===========================================
# 颜色输出函数
# ===========================================

# 打印带颜色的信息
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_blue() {
    echo -e "${BLUE}$1${NC}"
}

print_purple() {
    echo -e "${PURPLE}$1${NC}"
}

print_green() {
    echo -e "${GREEN}$1${NC}"
}

print_skyblue() {
    echo -e "${SKYBLUE}$1${NC}"
}

print_cyan() {
    echo -e "${SKYBLUE}$1${NC}"
}

print_red() {
    echo -e "${RED}$1${NC}"
}

# ===========================================
# 系统环境检查函数
# ===========================================

# 检查并创建日志目录
setup_logging() {
    local log_dir=$(dirname "$LOG_FILE")
    log_debug "检查日志目录: $log_dir"
    if [[ ! -d "$log_dir" ]]; then
        log_debug "日志目录不存在，尝试创建: $log_dir"
        mkdir -p "$log_dir" 2>/dev/null
        if [[ $? -ne 0 ]]; then
            # 如果无法创建日志目录，使用临时日志文件
            log_warn "无法创建日志目录 $log_dir，使用临时日志文件"
            LOG_FILE="/tmp/sing-box-install.log"
            log_dir=$(dirname "$LOG_FILE")
            log_debug "使用临时日志目录: $log_dir"
            mkdir -p "$log_dir" 2>/dev/null
        fi
    fi
    
    # 清空之前的日志文件
    log_debug "清空日志文件: $LOG_FILE"
    > "$LOG_FILE"
    
    log_info "开始 sing-box 下载并安装过程"
    log_info "脚本版本: $VERSION"
    log_debug "调试模式: $DEBUG_MODE"
    log_debug "日志文件路径: $LOG_FILE"
}

# 检查是否为root用户（清单模式）
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}${CROSS_MARK}${NC} Root权限检查: 未通过 - 此脚本必须以root权限运行"
        return 1
    fi
    echo -e "${GREEN}${CHECK_MARK}${NC} Root权限检查: 通过"
    return 0
}

# 检查系统类型和支持的架构（清单模式）
check_system() {
    local system_check_passed=false
    local arch_check_passed=false
    
    log_debug "开始系统类型检查"
    if [[ -f /etc/debian_version ]]; then
        OS="debian"
        PACKAGE_MANAGER="apt"
        system_check_passed=true
        log_debug "检测到Debian/Ubuntu系统"
        echo -e "${GREEN}${CHECK_MARK}${NC} 系统类型检查: 通过 (Debian/Ubuntu)"
    elif [[ -f /etc/redhat-release ]]; then
        OS="centos"
        PACKAGE_MANAGER="yum"
        system_check_passed=true
        log_debug "检测到CentOS/RHEL系统"
        echo -e "${GREEN}${CHECK_MARK}${NC} 系统类型检查: 通过 (CentOS/RHEL)"
    elif [[ -f /etc/alpine-release ]]; then
        OS="alpine"
        PACKAGE_MANAGER="apk"
        system_check_passed=true
        log_debug "检测到Alpine Linux系统"
        echo -e "${GREEN}${CHECK_MARK}${NC} 系统类型检查: 通过 (Alpine Linux)"
    fi
    
    # 检测系统架构
    log_debug "开始系统架构检查"
    ARCH=$(uname -m)
    log_debug "检测到系统架构: $ARCH"
    case $ARCH in
        x86_64)
            SINGBOX_ARCH="amd64"
            arch_check_passed=true
            log_debug "映射到sing-box架构: amd64"
            echo -e "${GREEN}${CHECK_MARK}${NC} 系统架构检查: 通过 (x86_64/amd64)"
            ;;
        'x86' | 'i686' | 'i386')
            SINGBOX_ARCH="386"
            arch_check_passed=true
            log_debug "映射到sing-box架构: 386"
            echo -e "${GREEN}${CHECK_MARK}${NC} 系统架构检查: 通过 (x86/i686/i386/386)"
            ;;
        aarch64 | arm64)
            SINGBOX_ARCH="arm64"
            arch_check_passed=true
            log_debug "映射到sing-box架构: arm64"
            echo -e "${GREEN}${CHECK_MARK}${NC} 系统架构检查: 通过 (aarch64/arm64)"
            ;;
        armv7l)
            SINGBOX_ARCH="armv7"
            arch_check_passed=true
            log_debug "映射到sing-box架构: armv7"
            echo -e "${GREEN}${CHECK_MARK}${NC} 系统架构检查: 通过 (armv7l/armv7)"
            ;;
        s390x)
            SINGBOX_ARCH="s390x"
            arch_check_passed=true
            log_debug "映射到sing-box架构: s390x"
            echo -e "${GREEN}${CHECK_MARK}${NC} 系统架构检查: 通过 (s390x)"
            ;;
        *)
            log_debug "不支持的系统架构: $ARCH"
            echo -e "${RED}${CROSS_MARK}${NC} 系统架构检查: 未通过 - 不支持的系统架构: $ARCH"
            ;;
    esac
    
    # 返回检查结果
    if [[ "$system_check_passed" == true ]] && [[ "$arch_check_passed" == true ]]; then
        log_info "系统类型: $OS, 系统架构: $ARCH ($SINGBOX_ARCH)"
        return 0
    fi
    log_debug "系统检查未通过 - system_check_passed: $system_check_passed, arch_check_passed: $arch_check_passed"
    return 1
}

# 检查系统是否支持IPv6
# 
# 设计说明:
# 该函数通过多种方式检查IPv6支持，确保在不同环境下都能正确检测:
# 1. 首先检查 /proc/net/if_inet6 文件是否存在且不为空（Linux系统标准方法）
# 2. 备选使用 ip -6 addr show 命令检查是否有IPv6接口（更通用的方法）
# 3. 进一步验证IPv6功能是否真正可用
# 
# 这种多重检查机制确保了在各种Linux发行版和Unix系统中都能准确检测IPv6支持
check_ipv6_support() {
    # 检查/proc/net/if_inet6文件是否存在且不为空
    if [[ -f /proc/net/if_inet6 ]] && [[ -s /proc/net/if_inet6 ]]; then
        # 进一步验证IPv6功能是否真正可用
        if command -v ip &> /dev/null && ip -6 addr show 2>/dev/null | grep -q "inet6"; then
            echo -e "${GREEN}${CHECK_MARK}${NC} IPv6支持检查: 通过"
            return 0
        fi
    fi
    
    # 如果以上检查都失败，说明系统不支持IPv6
    echo -e "${YELLOW}${WARNING_SIGN}${NC} IPv6支持检查: 未通过 - 系统不支持IPv6"
    return 1
}

# 综合系统环境检查（清单模式）
perform_system_checks() {
    # 添加防重复执行检查
    if [[ "${SYSTEM_CHECKS_PERFORMED}" == "true" ]]; then
        log_debug "系统检查已执行过，跳过重复检查"
        return 0
    fi
    
    log_debug "开始综合系统环境检查"
    print_blue "==========================================="
    print_blue "         系统环境检查清单"
    print_blue "==========================================="
    echo ""
    
    local failed_checks=0
    # 标记检查已执行
    SYSTEM_CHECKS_PERFORMED="true"
    
    # 检查Root权限
    log_debug "检查Root权限"
    if ! check_root; then
        ((failed_checks++))
        log_debug "Root权限检查未通过"
    else
        log_debug "Root权限检查通过"
    fi
    
    # 检查系统环境
    log_debug "检查系统环境"
    if ! check_system; then
        ((failed_checks++))
        log_debug "系统环境检查未通过"
    else
        log_debug "系统环境检查通过"
    fi
    
    # 检查IPv6支持（非必需检查）
    log_debug "检查IPv6支持"
    if check_ipv6_support; then
        log_debug "系统支持IPv6"
    else
        print_warning "系统不支持IPv6，将仅使用IPv4"
        log_debug "系统不支持IPv6"
        # IPv6支持不是必需的，因此即使检查失败也不会影响整体检查结果
    fi
    
    # 检查必要的命令
    log_debug "检查必要命令"
    local required_commands=("curl" "wget" "tar")
    # 重置命令检查相关变量，防止残留状态
    local cmd=""
    local cmd_path=""
    for cmd in "${required_commands[@]}"; do
        log_debug "正在检查命令: $cmd"
        # 重置变量
        cmd_path=""
        # 添加额外的诊断信息
        cmd_path=$(command -v "$cmd" 2>/dev/null)
        if [[ -n "$cmd_path" ]]; then
            log_debug "命令检查结果: $cmd 可用，路径: $cmd_path"
            echo -e "${GREEN}${CHECK_MARK}${NC} 命令检查: $cmd 可用"
        else
            log_debug "命令检查结果: $cmd 未安装"
            echo -e "${RED}${CROSS_MARK}${NC} 命令检查: $cmd 未安装"
            ((failed_checks++))
        fi
    done
    
    echo ""
    if [[ $failed_checks -eq 0 ]]; then
        log_debug "所有必需系统检查通过"
        echo -e "${GREEN}${CHECK_MARK}${NC} 所有必需系统检查通过"
        print_info "系统环境准备就绪，可以继续安装"
    else
        log_debug "系统检查未通过"
        echo -e "${RED}${CROSS_MARK}${NC} 系统检查未通过"
        print_error "请解决上述问题后再继续"
        exit 1
    fi
    
    echo ""
}

# ===========================================
# 配置生成函数
# ===========================================

# 生成随机UUID
generate_uuid() {
    if [[ -n "$UUID" ]]; then
        echo "$UUID"
    else
        # 当没有设置UUID环境变量且不在非交互模式下时，才进行交互输入
        if [[ "$NON_INTERACTIVE" != "true" ]]; then
            # 用户交互输入UUID
            print_info "未设置UUID环境变量"
            read -p "请输入UUID，或按回车跳过使用随机UUID: " user_input_uuid
            
            if [[ -n "$user_input_uuid" ]]; then
                echo "$user_input_uuid"
            else
                # 用户放弃输入，随机生成UUID
                uuid=$(cat /proc/sys/kernel/random/uuid)
                echo "$uuid"
            fi
        else
            # 非交互模式下直接生成随机UUID
            uuid=$(cat /proc/sys/kernel/random/uuid)
            echo "$uuid"
        fi
    fi
}

# 生成固定的short_id
generate_short_id() {
    # 使用固定的short_id
    echo "a2346cd0"
}

# 生成随机端口（确保端口未被占用）
generate_random_port() {
    local max_attempts=100
    local attempts=0
    local port
    
    while [[ $attempts -lt $max_attempts ]]; do
        # 生成1-65535之间的随机数
        port=$((RANDOM % 65535 + 1))
        
        # 检查端口是否已被占用
        if ! is_port_in_use $port; then
            echo "$port"
            return
        fi
        
        attempts=$((attempts + 1))
    done
    
    # 如果100次尝试后仍未找到可用端口，生成一个警告并返回端口1（肯定会失败）
    # 这种情况极少见，但在极端情况下可能发生
    print_warning "无法找到可用端口，建议手动指定端口"
    echo "1"
}

# 获取用户输入的端口（确保端口未被占用，无限次尝试直到用户放弃）
get_user_port() {
    # 在非交互模式下不执行交互式输入
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        echo ""
        return
    fi
    
    local user_port
    
    while true; do
        read -p "请输入端口号 (1-65535)，或按回车跳过使用随机端口: " user_port
        
        # 如果用户直接按回车，返回空值
        if [[ -z "$user_port" ]]; then
            echo ""
            return
        fi
        
        # 验证端口范围
        if ! [[ "$user_port" =~ ^[0-9]+$ ]] || [ "$user_port" -lt 1 ] || [ "$user_port" -gt 65535 ]; then
            print_error "端口号必须是1-65535之间的整数"
            echo "请重新输入"
            continue
        fi
        
        # 检查端口是否已被占用
        if is_port_in_use $user_port; then
            print_warning "端口 $user_port 已被占用，请选择其他端口"
            echo "请重新输入"
            continue
        fi
        
        # 端口有效且未被占用
        echo "$user_port"
        return
    done
}

# 获取用户输入的SNI
get_user_sni() {
    # 在非交互模式下不执行交互式输入
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        # 在非交互模式下，如果用户没有传入SNI值，则使用默认值
        if [[ -z "$SNI" ]]; then
            echo "$SNI_DEFAULT"
        else
            echo "$SNI"
        fi
        return
    fi
    
    local user_sni
    read -p "请输入SNI域名，或按回车跳过使用默认值($SNI_DEFAULT): " user_sni
    
    # 如果用户直接按回车，返回空值
    if [[ -z "$user_sni" ]]; then
        echo ""
        return
    fi
    
    echo "$user_sni"
}

# 生成REALITY密钥对
generate_reality_keys() {
    log_info "生成REALITY密钥对..."
    log_debug "开始生成REALITY密钥对"
    print_info "生成REALITY密钥对..."
    
    # 检查是否已安装sing-box
    if ! command -v sing-box &> /dev/null; then
        log_error "sing-box 未安装，无法生成密钥对"
        print_error "sing-box 未安装，无法生成密钥对"
        return 1
    fi
    
    # 生成密钥对
    log_debug "执行命令: sing-box generate reality-keypair"
    local keys_json=$(sing-box generate reality-keypair 2>/dev/null)
    if [[ $? -ne 0 ]]; then
        log_error "生成REALITY密钥对失败"
        print_error "生成REALITY密钥对失败"
        return 1
    fi
    
    # 记录生成的密钥对（仅记录长度，不记录实际内容）
    log_debug "密钥对生成成功，长度 - keys_json: ${#keys_json} 字符"
    
    # 提取私钥和公钥
    log_debug "开始提取私钥和公钥"
    PRIVATE_KEY=$(echo "$keys_json" | grep -o '"private_key":"[^"]*"' | cut -d'"' -f4)
    PUBLIC_KEY=$(echo "$keys_json" | grep -o '"public_key":"[^"]*"' | cut -d'"' -f4)
    
    if [[ -z "$PRIVATE_KEY" ]] || [[ -z "$PUBLIC_KEY" ]]; then
        log_error "提取密钥失败"
        print_error "提取密钥失败"
        return 1
    fi
    
    # 记录密钥长度（不记录实际内容）
    log_debug "密钥提取成功 - 私钥长度: ${#PRIVATE_KEY} 字符, 公钥长度: ${#PUBLIC_KEY} 字符"
    
    # 创建密钥目录
    log_debug "检查并创建密钥目录: $KEYS_DIR"
    if [[ ! -d "$KEYS_DIR" ]]; then
        mkdir -p "$KEYS_DIR"
        log_debug "创建密钥目录成功"
    fi
    
    # 保存私钥到文件
    log_debug "保存私钥到文件: $PRIVATE_KEY_FILE"
    echo "$PRIVATE_KEY" > "$PRIVATE_KEY_FILE"
    chmod 600 "$PRIVATE_KEY_FILE"
    
    # 保存公钥到文件
    log_debug "保存公钥到文件: $PUBLIC_KEY_FILE"
    echo "$PUBLIC_KEY" > "$PUBLIC_KEY_FILE"
    chmod 644 "$PUBLIC_KEY_FILE"
    
    print_info "密钥文件已保存到: $KEYS_DIR/"
    log_info "密钥文件已保存到: $KEYS_DIR/"
    log_info "REALITY密钥对生成成功"
    print_info "REALITY密钥对生成成功"
    log_debug "密钥对生成和保存完成"
    return 0
}

# 配置sing-box
configure_singbox() {
    log_info "开始配置sing-box..."
    log_debug "配置参数 - PORT: ${PORT:-未设置}, SNI: ${SNI:-未设置}, UUID: ${UUID:-未设置}"
    print_info "开始配置sing-box..."
    
    # 检测配置目录是否存在，不存在才创建
    if [[ ! -d "/etc/sing-box" ]]; then
        print_info "配置目录不存在，正在创建 /etc/sing-box..."
        log_debug "执行创建目录命令: mkdir -p /etc/sing-box"
        mkdir -p /etc/sing-box
        print_info "配置目录已存在: /etc/sing-box"
        log_debug "配置目录已存在: /etc/sing-box"
    fi
    
    # 获取端口参数
    if [[ -n "$PORT" ]]; then
        # 如果已设置PORT环境变量，直接使用
        log_debug "使用环境变量PORT: $PORT"
        # 检查环境变量指定的端口是否已被占用
        if is_port_in_use $PORT; then
            print_warning "环境变量指定的端口 $PORT 已被占用，可能存在冲突"
            log_warn "环境变量指定的端口 $PORT 已被占用，可能存在冲突"
        fi
        CONFIG_PORT=$PORT
    else
        # 如果未设置PORT环境变量，通过交互式输入或其他方式获取
        log_debug "未设置PORT环境变量，进入交互式端口输入"
        user_input_port=$(get_user_port)
        
        if [[ -n "$user_input_port" ]]; then
            CONFIG_PORT=$user_input_port
            log_debug "用户输入端口: $CONFIG_PORT"
        else
            # 用户放弃输入或非交互模式下无输入，随机生成端口
            CONFIG_PORT=$(generate_random_port)
            log_debug "使用随机生成的端口: $CONFIG_PORT"
            print_info "使用随机生成的端口: $CONFIG_PORT"
        fi
    fi
    
    # 获取SNI参数
    if [[ -n "$SNI" ]]; then
        # 如果已设置SNI环境变量，直接使用
        log_debug "使用环境变量SNI: $SNI"
        CONFIG_SNI=$SNI
    else
        # 如果未设置SNI环境变量，通过交互式输入或其他方式获取
        log_debug "未设置SNI环境变量，进入交互式SNI输入"
        user_input_sni=$(get_user_sni)
        
        if [[ -n "$user_input_sni" ]]; then
            CONFIG_SNI=$user_input_sni
            log_debug "用户输入SNI: $CONFIG_SNI"
        else
            # 用户放弃输入或非交互模式下无输入，使用默认值
            CONFIG_SNI="$SNI_DEFAULT"
            log_debug "使用默认SNI: $CONFIG_SNI"
        fi
    fi
    
    # 生成配置参数
    log_debug "开始生成UUID"
    UUID=$(generate_uuid)
    log_debug "生成的UUID: $UUID"
    
    log_debug "开始生成Short ID"
    SHORT_ID=$(generate_short_id)
    log_debug "生成的Short ID: $SHORT_ID"
    
    # 生成并保存REALITY密钥对
    log_debug "开始生成REALITY密钥对"
    if ! generate_reality_keys; then
        log_error "生成REALITY密钥对失败"
        print_error "生成REALITY密钥对失败"
        show_main_menu
        return
    fi
    
    # 记录生成的密钥信息（不记录私钥）
    log_debug "生成的公钥: $PUBLIC_KEY"
    
    # 创建配置文件，同时监听IPv4和IPv6
    log_debug "开始创建配置文件: $CONFIG_FILE"
    log_debug "配置详情 - 端口: $CONFIG_PORT, SNI: $CONFIG_SNI, UUID: $UUID"
    cat > "$CONFIG_FILE" << EOF
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "google",
        "address": "8.8.8.8"
      },
      {
        "tag": "local",
        "address": "223.5.5.5",
        "detour": "direct"
      }
    ]
  },
  "inbounds": [
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",  
      "listen_port": $CONFIG_PORT,
      "sniff": true,
      "sniff_override_destination": false,
      "domain_strategy": "prefer_ipv6",  // 优先使用IPv6，同时也支持IPv4
      "users": [
        {
          "uuid": "$UUID",
          "flow": "xtls-rprx-vision"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$CONFIG_SNI",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "$CONFIG_SNI",
            "server_port": 443
          },
          "private_key": "$PRIVATE_KEY",
          "short_id": ["$SHORT_ID"],
          "public_key": "$PUBLIC_KEY"
        },
        "fallback": {
          "server": "$CONFIG_SNI",
          "server_port": 443
        }
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    },
    {
      "type": "block",
      "tag": "block"
    }
  ],
  "route": {
    "rules": [
      {
        "ip_cidr": [
          "10.0.0.0/8",
          "172.16.0.0/12",
          "192.168.0.0/16"
        ],
        "outbound": "block"
      }
    ],
    "final": "direct"
  }
}
EOF
    
    if [[ $? -ne 0 ]]; then
        log_error "创建配置文件失败"
        print_error "创建配置文件失败"
        exit 1
    fi
    
    print_info "配置文件已创建：$CONFIG_FILE"
    log_info "配置文件已创建：$CONFIG_FILE"
    log_debug "配置文件内容写入完成"
}

# 获取sing-box下载URL
get_singbox_download_url() {
    local arch=${1:-$SINGBOX_ARCH}
    local url=""
    
    case $OS in
        "debian"|"centos")
            url="https://${arch}.ssss.nyc.mn/sbx"
            ;;
        "alpine")
            url="https://${arch}.ssss.nyc.mn/sbx"
            ;;
        *)
            log_error "未知操作系统类型: $OS"
            return 1
            ;;
    esac
    
    echo "$url"
    log_info "sing-box下载URL: $url"
}

# 下载并安装sing-box
download_and_install_singbox() {
    log_info "开始下载并安装 sing-box..."
    log_debug "当前操作系统: $OS, 架构: $SINGBOX_ARCH"
    print_info "开始下载并安装 sing-box..."
    
    # 强制覆盖下载并安装，不检查是否已安装
    
    # 使用更稳定的下载源
    local download_url="https://${SINGBOX_ARCH}.ssss.nyc.mn/sbx"
    log_info "开始下载 sing-box: $download_url"
    print_info "开始下载 sing-box..."
    
    # 创建临时目录
    local temp_dir=$(mktemp -d)
    log_debug "创建临时目录: $temp_dir"
    cd "$temp_dir"
    
    # 下载sing-box，优先使用curl以提高稳定性和支持断点续传，备用wget
    log_debug "执行下载命令: curl -L --progress-bar \"$download_url\" -o sing-box (备用: wget)"
    local max_retries=3
    local retry_count=0
    local download_success=false
    
    # 验证清理后的URL
    if [[ -z "$download_url" ]]; then
        log_error "清理后的下载URL为空"
        print_error "清理后的下载URL为空"
        rm -rf "$temp_dir"
        read -p "按回车键返回主菜单..." dummy
        show_main_menu
        return
    fi
    
    # 检查URL是否以http开头
    if [[ ! "$download_url" =~ ^https?:// ]]; then
        log_error "下载URL格式不正确: $download_url"
        print_error "下载URL格式不正确"
        rm -rf "$temp_dir"
        read -p "按回车键返回主菜单..." dummy
        show_main_menu
        return
    fi
    
    log_debug "验证后的下载URL: $download_url"
    
    while [[ $retry_count -lt $max_retries ]]; do
        # 首先尝试使用curl下载
        log_debug "尝试使用curl下载，第$((retry_count+1))次"
        # 添加--http1.1选项以避免HTTP/2相关问题
        if curl -L --http1.1 --progress-bar --connect-timeout 30 --max-time 300 "$download_url" -o sing-box; then
            download_success=true
            break
        else
            log_debug "curl下载失败，退出码: $?"
            # 如果curl失败，尝试使用wget作为备用方案
            if command -v wget &> /dev/null; then
                log_warn "curl下载失败，尝试使用wget作为备用方案"
                print_warning "curl下载失败，尝试使用wget作为备用方案"
                # 添加更多选项以提高wget的稳定性
                if wget -q --show-progress --timeout=30 --tries=1 --random-wait "$download_url" -O sing-box; then
                    download_success=true
                    break
                else
                    log_debug "wget下载失败，退出码: $?"
                fi
            else
                log_debug "wget命令不可用"
            fi
            
            # 如果两种方法都失败，增加重试计数
            retry_count=$((retry_count + 1))
            if [[ $retry_count -lt $max_retries ]]; then
                log_warn "下载失败，正在重试 ($retry_count/$max_retries)..."
                print_warning "下载失败，正在重试 ($retry_count/$max_retries)..."
                sleep 2
            fi
        fi
    done
    
    if [[ "$download_success" != "true" ]]; then
        log_error "下载 sing-box 失败，已重试 $max_retries 次"
        print_error "下载 sing-box 失败"
        print_error "可能的原因：网络连接不稳定、防火墙限制或下载源问题"
        print_error "解决建议："
        print_error "  1. 检查网络连接是否正常"
        print_error "  2. 尝试使用代理或更换网络环境"
        print_error "  3. 手动下载文件并放置到适当位置"
        print_error "  4. 如果问题持续存在，可尝试使用wget替代curl重新运行脚本"
        rm -rf "$temp_dir"
        read -p "按回车键返回主菜单..." dummy
        show_main_menu
        return
    fi
    
    
    # 设置二进制文件路径（直接下载的就是二进制文件）
    local binary_path="./sing-box"
    log_info "安装 sing-box 到 /usr/local/bin/"
    print_info "安装 sing-box..."
    
    # 安装到系统路径
    log_debug "执行安装命令: install -m 755 \"$binary_path\" /usr/local/bin/sing-box"
    if ! install -m 755 "$binary_path" /usr/local/bin/sing-box; then
        log_error "安装 sing-box 失败"
        print_error "安装 sing-box 失败"
        print_error "请检查系统权限或磁盘空间"
        rm -rf "$temp_dir"
        read -p "按回车键返回主菜单..." dummy
        show_main_menu
        return
    fi
    
    log_info "清理临时文件"
    log_debug "删除临时目录: $temp_dir"
    rm -rf "$temp_dir"
    
    # 创建配置目录
    log_info "创建配置目录 /etc/sing-box/"
    if [[ ! -d "/etc/sing-box" ]]; then
        log_debug "执行创建目录命令: mkdir -p /etc/sing-box"
        if ! mkdir -p /etc/sing-box; then
            log_error "创建配置目录失败"
            print_error "创建配置目录失败"
            print_error "请检查系统权限"
            read -p "按回车键返回主菜单..." dummy
            show_main_menu
            return
        fi
    fi
    
    # 创建systemd服务文件（如果systemctl可用）
    if command -v systemctl &> /dev/null; then
        log_info "创建 systemd 服务文件"
        log_debug "写入systemd服务文件: /etc/systemd/system/sing-box@.service"
        cat > /etc/systemd/system/sing-box@.service << EOF
[Unit]
Description=sing-box service for %i
Documentation=https://sing-box.sagernet.org/
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/sing-box run -c \$CONFIG_DIR/%i.json
Restart=on-failure
RestartSec=5s
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
        
        # 重新加载systemd
        log_debug "执行systemctl daemon-reload"
        systemctl daemon-reload
        log_info "systemd 服务文件创建完成"
    fi
    
    log_info "sing-box 下载并安装完成"
    print_success "sing-box 下载并安装完成"
}

# 显示主菜单
show_main_menu() {
    clear
    echo -e "${BLUE}===============================================${NC}"
    echo -e "${BLUE}          sing-box 一键安装管理脚本${NC}"
    echo -e "${GREEN}          作者: $AUTHOR${NC}"
    echo -e "${BROWN}          版本: $VERSION${NC}"
    echo -e "${BLUE}===============================================${NC}"
    echo ""
    # 检查sing-box是否已安装
    local singbox_installed="未安装"
    if command -v sing-box &> /dev/null; then
        singbox_installed="已安装 ($(sing-box version | head -n1 | awk '{print $3}'))"
    fi
    
    # 检查sing-box服务状态（只有在已安装的情况下才检查服务状态）
    local singbox_status="未运行"
    if [[ "$singbox_installed" == *"已安装"* ]] && pgrep sing-box &> /dev/null; then
        singbox_status="运行中"
    fi
    
    echo -e "sing-box状态: $([[ "$singbox_installed" == *"已安装"* ]] && echo -e "${GREEN}$singbox_installed${NC}" || echo -e "${RED}$singbox_installed${NC}")"
    # 只有在已安装的情况下才显示服务状态
    if [[ "$singbox_installed" == *"已安装"* ]]; then
        echo -e "服务状态: $([[ "$singbox_status" == "运行中" ]] && echo -e "${GREEN}$singbox_status${NC}" || echo -e "${RED}$singbox_status${NC}")"
    else
        echo -e "服务状态: ${RED}未安装${NC}"
    fi
    echo ""
    print_green "1. 一键下载并安装sing-box"
    print_skyblue "------------------"
    print_green "2. 卸载sing-box"
    print_skyblue "------------------"
    print_green "3. 启动sing-box服务"
    print_skyblue "------------------"
    print_green "4. 停止sing-box服务"
    print_skyblue "------------------"
    print_green "5. 重启sing-box服务"
    print_skyblue "------------------"
    print_green "6. 查看sing-box运行状态"
    print_skyblue "------------------"
    print_green "7. 修改节点配置"
    print_skyblue "------------------"
    print_green "8. 查看配置文件"
    print_skyblue "------------------"
    print_green "9. 查看日志"
    print_skyblue "------------------"
    print_purple "0. 退出脚本"
    print_skyblue "------------------"
    read -p "请输入选择: " choice
    
    case $choice in
        1)
            main_install_process
            ;;
        2)
            uninstall_singbox
            ;;
        3)
            start_singbox_service
            ;;
        4)
            stop_singbox_service
            ;;
        5)
            restart_singbox_service
            ;;
        6)
            check_singbox_status
            ;;
        7)
            show_config_menu
            ;;
        8)
            view_config
            ;;
        9)
            show_log_menu
            ;;
        0)
            print_info "感谢使用，再见！"
            exit 0
            ;;
        *)
            print_error "无效选择，请重新输入"
            sleep 2
            show_main_menu
            ;;
    esac
}

# 显示配置菜单
show_config_menu() {
    clear
    print_blue "==========================================="
    print_blue "           sing-box 配置管理"
    print_blue "==========================================="
    
    # 检查配置文件是否存在
    local config_file="$CONFIG_FILE"
    local config_status="未配置"
    if [[ -f "$config_file" ]]; then
        config_status="已配置"
    fi
    
    echo ""
    print_cyan "配置状态: $config_status"
    echo ""
    print_cyan "请选择操作:"
    print_green "1. 修改端口"
    print_skyblue "------------------"
    print_green "2. 修改UUID"
    print_skyblue "------------------"
    print_green "3. 修改Reality伪装域名"
    print_skyblue "------------------"
    print_green "4. 查看当前配置"
    print_skyblue "------------------"
    print_purple "0. 返回主菜单"
    print_skyblue "------------------"
    echo ""
    
    read -p "请输入选择: " choice
    
    case $choice in
        1)
            modify_port
            ;;
        2)
            modify_uuid
            ;;
        3)
            modify_sni
            ;;
        4)
            view_current_config
            ;;
        0)
            show_main_menu
            ;;
        *)
            print_error "无效选择，请重新输入"
            sleep 2
            show_config_menu
            ;;
    esac
}

# 显示日志菜单
show_log_menu() {
    clear
    print_blue "==========================================="
    print_blue "           sing-box 日志查看"
    print_blue "==========================================="
    
    echo ""
    print_cyan "请选择操作:"
    print_green "1. 查看完整安装日志"
    print_skyblue "------------------"
    print_green "2. 查看最近300行日志"
    print_skyblue "------------------"
    print_green "3. 实时监控日志"
    print_skyblue "------------------"
    print_purple "0. 返回主菜单"
    print_skyblue "------------------"
    echo ""
    
    read -p "请输入选择: " choice
    
    case $choice in
        1)
            view_full_logs
            ;;
        2)
            view_recent_logs
            ;;
        3)
            monitor_logs
            ;;
        0)
            show_main_menu
            ;;
        *)
            print_error "无效选择，请重新输入"
            sleep 2
            show_log_menu
            ;;
    esac
}



# 非交互式下载并安装函数
non_interactive_install() {
    log_info "开始非交互式下载并安装sing-box..."
    log_debug "进入非交互式下载并安装流程"
    print_info "开始非交互式下载并安装sing-box..."
    
    # 在非交互模式下，执行系统环境检查
    log_debug "开始下载并安装sing-box"
    download_and_install_singbox
    log_debug "开始配置sing-box"
    configure_singbox
    log_debug "开始启动服务"
    start_service
    # 在非交互模式下显示简化的客户端配置信息
    log_debug "显示客户端配置信息"
    show_simple_client_config
    
    log_info "sing-box非交互式下载并安装完成！"
    print_info "sing-box非交互式下载并安装完成！"
}

# 显示简化的客户端配置信息（用于非交互模式）
show_simple_client_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        print_error "未找到配置文件: $CONFIG_FILE"
        return
    fi
    
    # 从配置文件中提取必要的信息
    local port=$(jq -r '.inbounds[0].listen_port' "$CONFIG_FILE" 2>/dev/null)
    local uuid=$(jq -r '.inbounds[0].users[0].uuid' "$CONFIG_FILE" 2>/dev/null)
    local sni=$(jq -r '.inbounds[0].tls.server_name' "$CONFIG_FILE" 2>/dev/null)
    local short_id=$(jq -r '.inbounds[0].tls.reality.short_id[0]' "$CONFIG_FILE" 2>/dev/null)
    
    # 如果jq不可用，使用sed提取信息
    if [[ -z "$port" ]] || [[ "$port" == "null" ]]; then
        port=$(grep -o '"listen_port":[[:space:]]*[0-9]*' "$CONFIG_FILE" | head -1 | grep -o '[0-9]*')
    fi
    
    if [[ -z "$uuid" ]] || [[ "$uuid" == "null" ]]; then
        uuid=$(grep -o '"uuid":"[^"]*"' "$CONFIG_FILE" | head -1 | cut -d'"' -f4)
    fi
    
    if [[ -z "$sni" ]] || [[ "$sni" == "null" ]]; then
        sni=$(grep -o '"server_name":"[^"]*"' "$CONFIG_FILE" | head -1 | cut -d'"' -f4)
    fi
    
    if [[ -z "$short_id" ]] || [[ "$short_id" == "null" ]]; then
        short_id=$(grep -o '"short_id":\["[^"]*"\]' "$CONFIG_FILE" | head -1 | cut -d'"' -f2)
    fi
    
    # 尝试从密钥文件中获取public key
    local public_key=""
    if [[ -f "$PUBLIC_KEY_FILE" ]]; then
        public_key=$(cat "$PUBLIC_KEY_FILE")
    fi
    
    # 获取服务器IP地址（支持IPv4和IPv6）
    local server_ip_v4=""
    local server_ip_v6=""
    
    # 尝试获取IPv4地址
    server_ip_v4=$(curl -s -4 ipinfo.io/ip 2>/dev/null)
    
    # 尝试获取IPv6地址
    server_ip_v6=$(curl -s -6 ipinfo.io/ip 2>/dev/null)
    
    # 如果获取不到IPv4地址，则使用默认方法
    if [[ -z "$server_ip_v4" ]]; then
        server_ip_v4=$(curl -s ipinfo.io/ip 2>/dev/null)
    fi
    
    print_info "==================== 客户端配置 ===================="
    echo "服务器地址 (IPv4): ${server_ip_v4:-N/A}"
    if [[ -n "$server_ip_v6" ]]; then
        echo "服务器地址 (IPv6): $server_ip_v6"
    fi
    echo "服务器端口: $port"
    echo "UUID: $uuid"
    echo "SNI: $sni"
    echo "Short ID: $short_id"
    echo "Public Key: $public_key"
    echo ""
    echo "配置文件路径: $CONFIG_FILE"
    print_info "=================================================="
    
    # 构建VLESS链接（IPv4版本）
    local vless_link_v4="vless://${uuid}@${server_ip_v4}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${public_key}&sid=${short_id}&type=tcp&headerType=none"
    
    echo ""
    print_info "==================== VLESS链接 (IPv4) ===================="
    echo -e "${GREEN}${vless_link_v4}${NC}"
    print_info "========================================================="
    
    # 如果有IPv6地址，构建IPv6版本的链接
    if [[ -n "$server_ip_v6" ]]; then
        # IPv6地址需要用方括号包裹
        local vless_link_v6="vless://${uuid}@[${server_ip_v6}]:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${public_key}&sid=${short_id}&type=tcp&headerType=none"
        
        echo ""
        print_info "==================== VLESS链接 (IPv6) ===================="
        echo -e "${GREEN}${vless_link_v6}${NC}"
        print_info "========================================================="
    fi
    
    # 提示信息：服务同时支持IPv4和IPv6连接
    echo ""
    print_info "注意：sing-box服务已配置为同时支持IPv4和IPv6连接"
    print_info "客户端可以使用任一链接进行连接"
    
    echo ""
}

# 主下载并安装流程
main_install_process() {
    log_info "开始一键下载并安装sing-box..."
    log_debug "进入主下载并安装流程"
    print_info "开始一键下载并安装sing-box..."
    
    # 在交互模式下，执行系统环境检查
    log_debug "执行系统环境检查"
    perform_system_checks
    
    log_debug "开始下载并安装sing-box"
    download_and_install_singbox
    log_debug "开始配置sing-box"
    configure_singbox
    log_debug "开始启动服务"
    start_service
    log_debug "显示客户端配置"
    show_client_config
    
    log_info "sing-box一键下载并安装完成！"
    print_info "sing-box一键下载并安装完成！"
}

# 启动服务
start_service() {
    print_info "正在启动 sing-box 服务..."
    
    # 重新加载systemd配置
    systemctl daemon-reload 2>/dev/null
    
    # 启用并启动sing-box服务（使用固定配置文件名）
    systemctl enable sing-box@sb-vless 2>/dev/null
    systemctl start sing-box@sb-vless 2>/dev/null
    
    if [[ $? -eq 0 ]]; then
        print_info "sing-box 服务启动成功"
    else
        print_error "sing-box 服务启动失败"
    fi
}

# 通用服务管理函数
# 参数: $1 - 操作类型 (start|stop|restart)
manage_service() {
    local action=$1
    local action_chinese=""
    
    case $action in
        "start")
            action_chinese="启动"
            ;;
        "stop")
            action_chinese="停止"
            ;;
        "restart")
            action_chinese="重启"
            ;;
        *)
            print_error "未知的服务操作: $action"
            log_error "未知的服务操作: $action"
            return 1
            ;;
    esac
    
    log_info "正在${action_chinese} sing-box 服务..."
    print_info "正在${action_chinese} sing-box 服务..."
    
    # 检查systemctl是否可用
    if command -v systemctl &> /dev/null; then
        log_debug "使用systemctl管理服务: systemctl $action sing-box@sb-vless"
        systemctl $action sing-box@sb-vless
        if [[ $? -eq 0 ]]; then
            log_info "sing-box 服务${action_chinese}成功"
            print_info "sing-box 服务${action_chinese}成功"
            return 0
        else
            log_error "sing-box 服务${action_chinese}失败"
            print_error "sing-box 服务${action_chinese}失败"
            return 1
        fi
    else
        # 对于不支持systemctl的系统，根据具体系统类型使用不同的管理方式
        log_debug "systemctl不可用，使用备用服务管理方式"
        if [[ $OS == "alpine" ]]; then
            # Alpine Linux使用OpenRC
            log_debug "检测到Alpine系统，使用rc-service管理服务"
            if command -v rc-service &> /dev/null; then
                log_debug "执行rc-service sing-box $action"
                rc-service sing-box $action
                if [[ $? -eq 0 ]]; then
                    log_info "sing-box 服务${action_chinese}成功"
                    print_info "sing-box 服务${action_chinese}成功"
                    return 0
                else
                    log_error "sing-box 服务${action_chinese}失败"
                    print_error "sing-box 服务${action_chinese}失败"
                    return 1
                fi
            else
                log_error "Alpine系统缺少rc-service命令"
                print_error "Alpine系统缺少rc-service命令"
                return 1
            fi
        else
            # 其他系统尝试使用service命令
            if command -v service &> /dev/null; then
                log_debug "使用service命令管理服务: service sing-box $action"
                service sing-box $action
                if [[ $? -eq 0 ]]; then
                    log_info "sing-box 服务${action_chinese}成功"
                    print_info "sing-box 服务${action_chinese}成功"
                    return 0
                else
                    log_error "sing-box 服务${action_chinese}失败"
                    print_error "sing-box 服务${action_chinese}失败"
                    return 1
                fi
            else
                log_error "系统不支持服务管理命令"
                print_error "系统不支持服务管理命令"
                return 1
            fi
        fi
    fi
}

# 启动sing-box服务（菜单选项）
start_singbox_service() {
    manage_service "start"
    print_info "按任意键返回主菜单..."
    read -n 1 -s -r -p ""
    echo
    show_main_menu
}

# 停止sing-box服务（菜单选项）
stop_singbox_service() {
    manage_service "stop"
    print_info "按任意键返回主菜单..."
    read -n 1 -s -r -p ""
    echo
    show_main_menu
}

# 重启sing-box服务（菜单选项）
restart_singbox_service() {
    manage_service "restart"
    print_info "按任意键返回主菜单..."
    read -n 1 -s -r -p ""
    echo
    show_main_menu
}

# ===========================================
# 服务管理函数
# ===========================================

# 服务操作常量
SERVICE_NAME="sing-box"
CONFIG_NAME="sb-vless"

# 查看sing-box运行状态
check_singbox_status() {
    print_info "正在检查 sing-box 运行状态..."
    
    # 检查sing-box是否已安装
    if ! command -v sing-box &> /dev/null; then
        print_error "sing-box 未安装"
        read -p "按回车键返回主菜单..." dummy
        show_main_menu
        return
    fi
    
    # 检查进程是否存在
    if pgrep sing-box &> /dev/null; then
        print_info "sing-box 进程状态: 运行中"
        
        # 显示进程详细信息
        echo "进程详情:"
        ps aux | grep sing-box | grep -v grep
        
        # 显示监听端口（包括IPv4和IPv6）
        echo ""
        echo "监听端口:"
        if command -v ss &> /dev/null; then
            ss -tulnp | grep sing-box
            echo "IPv6监听端口:"
            ss -tulnp6 | grep sing-box
        elif command -v netstat &> /dev/null; then
            netstat -tulnp | grep sing-box
            echo "IPv6监听端口:"
            netstat -tulnp6 | grep sing-box
        fi
    else
        print_info "sing-box 进程状态: 未运行"
    fi
    
    # 检查配置文件
    echo ""
    if [[ -f "$CONFIG_FILE" ]]; then
        print_info "配置文件状态: 存在 ($CONFIG_FILE)"
    else
        print_info "配置文件状态: 不存在"
    fi
    
    # 检查服务文件（如果存在systemctl）
    if command -v systemctl &> /dev/null; then
        echo ""
        print_info "systemd 服务状态:"
        systemctl status sing-box@sb-vless --no-pager -l 2>/dev/null || echo "服务未启用或不存在"
    fi
    
    read -p "按回车键返回主菜单..." dummy
    show_main_menu
}

# 修改端口
modify_port() {
    print_info "开始修改端口..."
    
    # 使用固定名称的配置文件
    local config_file="$CONFIG_FILE"
    
    if [[ ! -f "$config_file" ]]; then
        print_error "未找到配置文件: $config_file"
        read -p "按回车键返回配置菜单..." dummy
        show_config_menu
        return
    fi
    
    print_info "当前配置文件: $config_file"
    
    # 获取新的端口
    local new_port=""
    while true; do
        read -p "请输入新的端口号 (1-65535)，或按回车取消: " new_port
        
        # 如果用户按回车取消
        if [[ -z "$new_port" ]]; then
            print_info "取消修改端口"
            break
        fi
        
        # 验证端口范围
        if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1 ] || [ "$new_port" -gt 65535 ]; then
            print_error "端口号必须是1-65535之间的整数"
            echo "请重新输入"
            continue
        fi
        
        # 检查端口是否已被占用
        if is_port_in_use $new_port; then
            print_warning "端口 $new_port 已被占用，请选择其他端口"
            echo "请重新输入"
            continue
        fi
        
        # 端口有效且未被占用
        break
    done
    
    # 如果用户取消了操作
    if [[ -z "$new_port" ]]; then
        read -p "按回车键返回配置菜单..." dummy
        show_config_menu
        return
    fi
    
    # 备份原配置文件（使用带时间戳的备份文件名）
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="$BACKUP_DIR/sb-vless_backup_${timestamp}_before_port_change.json"
    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR"
    fi
    cp "$config_file" "$backup_file"
    print_info "已备份原配置文件至: $backup_file"
    log_info "配置文件已备份至: $backup_file"
    
    # 更新配置文件中的端口
    local update_success=false
    # 使用jq更新JSON配置文件中的端口（如果jq可用）
    if command -v jq &> /dev/null; then
        # 使用jq更新端口
        jq --arg port "$new_port" '.inbounds[0].listen_port = ($port | tonumber)' "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
        if [[ $? -eq 0 ]]; then
            print_info "端口已更新为: $new_port"
            log_info "端口已更新为: $new_port"
            update_success=true
        else
            print_error "使用jq更新端口失败"
            log_error "使用jq更新端口失败"
        fi
        # 如果没有jq，使用sed替换端口
        local old_port=$(grep -o '"listen_port":[[:space:]]*[0-9]*' "$config_file" | head -1 | grep -o '[0-9]*')
        if [[ -n "$old_port" ]]; then
            sed -i "s/"listen_port":[[:space:]]*$old_port/"listen_port": $new_port/" "$config_file"
            if [[ $? -eq 0 ]]; then
                print_info "端口已更新为: $new_port"
                log_info "端口已更新为: $new_port"
                update_success=true
            else
                print_error "使用sed更新端口失败"
                log_error "使用sed更新端口失败"
            fi
        else
            print_warning "无法自动更新端口，请手动编辑配置文件"
            log_warning "无法自动更新端口"
        fi
    fi
    
    if [[ "$update_success" == true ]]; then
        # 重启服务以应用更改
        print_info "正在重启 sing-box 服务以应用更改..."
        if ! manage_service "restart"; then
            print_warning "sing-box 服务重启失败，请手动重启服务"
            log_warning "sing-box 服务重启失败"
        fi
    else
        print_error "更新端口失败，配置未更改"
        log_error "更新端口失败，配置未更改"
    fi
    
    read -p "按回车键返回配置菜单..." dummy
    show_config_menu
}

# 修改UUID
modify_uuid() {
    print_info "开始修改UUID..."
    
    local config_file="$CONFIG_FILE"
    
    if [[ ! -f "$config_file" ]]; then
        print_error "未找到配置文件: $config_file"
        read -p "按回车键返回配置菜单..." dummy
        show_config_menu
        return
    fi
    
    print_info "当前配置文件: $config_file"
    
    # 获取新的UUID
    local new_uuid=""
    read -p "请输入新的UUID，或按回车取消: " new_uuid
    
    # 如果用户按回车取消
    if [[ -z "$new_uuid" ]]; then
        print_info "取消修改UUID"
        read -p "按回车键返回配置菜单..." dummy
        show_config_menu
        return
    fi
    
    # 备份原配置文件（使用带时间戳的备份文件名）
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="$BACKUP_DIR/sb-vless_backup_${timestamp}_before_uuid_change.json"
    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR"
    fi
    cp "$config_file" "$backup_file"
    print_info "已备份原配置文件至: $backup_file"
    log_info "配置文件已备份至: $backup_file"
    
    # 更新配置文件中的UUID
    local update_success=false
    # 使用jq更新JSON配置文件中的UUID（如果jq可用）
    if command -v jq &> /dev/null; then
        # 使用jq更新UUID
        jq --arg uuid "$new_uuid" '.inbounds[0].users[0].uuid = $uuid' "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
        if [[ $? -eq 0 ]]; then
            print_info "UUID已更新为: $new_uuid"
            log_info "UUID已更新为: $new_uuid"
            update_success=true
        else
            print_error "使用jq更新UUID失败"
            log_error "使用jq更新UUID失败"
        fi
    else
        # 如果没有jq，使用sed替换UUID
        # 先尝试匹配带双引号的UUID格式
        if grep -q '"uuid"' "$config_file"; then
            sed -i "s/\"uuid\": *\"[^\"]*\"/\"uuid\": \"$new_uuid\"/g" "$config_file"
            if [[ $? -eq 0 ]]; then
                print_info "UUID已更新为: $new_uuid"
                log_info "UUID已更新为: $new_uuid"
                update_success=true
            else
                print_error "使用sed更新UUID失败"
                log_error "使用sed更新UUID失败"
            fi
        else
            print_warning "无法自动更新UUID，请手动编辑配置文件"
            log_warning "无法自动更新UUID"
        fi
    fi
    
    if [[ "$update_success" == true ]]; then
        # 重启服务使更改生效
        print_info "正在重启 sing-box 服务以应用更改..."
        if ! manage_service "restart"; then
            print_warning "sing-box 服务重启失败，请手动重启服务"
            log_warning "sing-box 服务重启失败"
        fi
        print_info "按任意键返回配置菜单..."
        read -n 1 -s -r -p ""
        echo
    else
        print_error "更新UUID失败"
        log_error "更新UUID失败"
        # 恢复备份文件
        mv "$backup_file" "$config_file"
        print_info "已恢复原配置文件"
        log_info "已恢复原配置文件"
    fi
    
    read -p "按回车键返回配置菜单..." dummy
    show_config_menu
}

# 修改SNI
modify_sni() {
    print_info "开始修改SNI..."
    
    local config_file="$CONFIG_FILE"
    
    if [[ ! -f "$config_file" ]]; then
        print_error "未找到配置文件: $config_file"
        read -p "按回车键返回配置菜单..." dummy
        show_config_menu
        return
    fi
    
    print_info "当前配置文件: $config_file"
    
    # 获取新的SNI
    local new_sni=""
    read -p "请输入新的SNI域名，或按回车取消: " new_sni
    
    # 如果用户按回车取消
    if [[ -z "$new_sni" ]]; then
        print_info "取消修改SNI"
        read -p "按回车键返回配置菜单..." dummy
        show_config_menu
        return
    fi
    
    # 备份原配置文件（使用带时间戳的备份文件名）
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_file="$BACKUP_DIR/sb-vless_backup_${timestamp}_before_sni_change.json"
    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR"
    fi
    cp "$config_file" "$backup_file"
    print_info "已备份原配置文件至: $backup_file"
    log_info "配置文件已备份至: $backup_file"
    
    # 更新配置文件中的SNI
    local update_success=false
    # 使用jq更新JSON配置文件中的SNI（如果jq可用）
    if command -v jq &> /dev/null; then
            # 使用jq更新SNI
            jq --arg sni "$new_sni" '.inbounds[0].tls.server_name = $sni' "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
            if [[ $? -eq 0 ]]; then
                print_info "SNI已更新为: $new_sni"
                log_info "SNI已更新为: $new_sni"
                update_success=true
            else
                print_error "使用jq更新SNI失败"
                log_error "使用jq更新SNI失败"
            fi
        else
            # 如果没有jq，使用sed替换SNI
            # 先尝试匹配带双引号的server_name格式
            if grep -q '"server_name"' "$config_file"; then
                sed -i "s/\"server_name\": *\"[^\"]*\"/\"server_name\": \"$new_sni\"/g" "$config_file"
                if [[ $? -eq 0 ]]; then
                    print_info "SNI已更新为: $new_sni"
                    log_info "SNI已更新为: $new_sni"
                    update_success=true
                else
                    print_error "使用sed更新SNI失败"
                    log_error "使用sed更新SNI失败"
                fi
            else
                print_warning "无法自动更新SNI，请手动编辑配置文件"
                log_warning "无法自动更新SNI"
            fi
        fi
    
    if [[ "$update_success" == true ]]; then
        # 重启服务使更改生效
        print_info "正在重启 sing-box 服务以应用更改..."
        if ! manage_service "restart"; then
            print_warning "sing-box 服务重启失败，请手动重启服务"
            log_warning "sing-box 服务重启失败"
        fi
        print_info "按任意键返回配置菜单..."
        read -n 1 -s -r -p ""
        echo
    else
        print_error "更新SNI失败"
        log_error "更新SNI失败"
        # 恢复备份文件
        mv "$backup_file" "$config_file"
        print_info "已恢复原配置文件"
        log_info "已恢复原配置文件"
    fi
    
    read -p "按回车键返回配置菜单..." dummy
    show_config_menu
}

# 修改Short ID
modify_short_id() {
    print_info "修改Short ID功能暂未实现"
    read -p "按回车键返回配置菜单..." dummy
    show_config_menu
}

# 重新生成密钥对
regenerate_keys() {
    print_info "重新生成密钥对功能暂未实现"
    read -p "按回车键返回配置菜单..." dummy
    show_config_menu
}

# 显示客户端配置
show_client_config() {
    local config_file="$CONFIG_FILE"
    
    if [[ ! -f "$config_file" ]]; then
        print_error "未找到配置文件: $config_file"
        return
    fi
    
    # 从配置文件中提取必要的信息
    local port=$(jq -r '.inbounds[0].listen_port' "$config_file" 2>/dev/null)
    local uuid=$(jq -r '.inbounds[0].users[0].uuid' "$config_file" 2>/dev/null)
    local sni=$(jq -r '.inbounds[0].tls.server_name' "$config_file" 2>/dev/null)
    local short_id=$(jq -r '.inbounds[0].tls.reality.short_id[0]' "$config_file" 2>/dev/null)
    local public_key=$(jq -r '.inbounds[0].tls.reality.public_key' "$config_file" 2>/dev/null)
    
    # 如果jq不可用，使用sed提取信息
    if [[ -z "$port" ]] || [[ "$port" == "null" ]]; then
        port=$(grep -o '"listen_port":[[:space:]]*[0-9]*' "$config_file" | head -1 | grep -o '[0-9]*')
    fi
    
    if [[ -z "$uuid" ]] || [[ "$uuid" == "null" ]]; then
        uuid=$(grep -o '"uuid":"[^"]*"' "$config_file" | head -1 | cut -d'"' -f4)
    fi
    
    if [[ -z "$sni" ]] || [[ "$sni" == "null" ]]; then
        sni=$(grep -o '"server_name":"[^"]*"' "$config_file" | head -1 | cut -d'"' -f4)
    fi
    
    if [[ -z "$short_id" ]] || [[ "$short_id" == "null" ]]; then
        short_id=$(grep -o '"short_id":\["[^"]*"\]' "$config_file" | head -1 | cut -d'"' -f2)
    fi
    
    if [[ -z "$public_key" ]] || [[ "$public_key" == "null" ]]; then
        # 尝试从密钥文件中获取public key
        if [[ -f "$PUBLIC_KEY_FILE" ]]; then
            public_key=$(cat "$PUBLIC_KEY_FILE")
        fi
    fi
    
    # 获取服务器IP地址（支持IPv4和IPv6）
    local server_ip_v4=""
    local server_ip_v6=""
    
    # 尝试获取IPv4地址
    server_ip_v4=$(curl -s -4 ipinfo.io/ip 2>/dev/null)
    
    # 尝试获取IPv6地址
    server_ip_v6=$(curl -s -6 ipinfo.io/ip 2>/dev/null)
    
    # 如果获取不到IPv4地址，则使用默认方法
    if [[ -z "$server_ip_v4" ]]; then
        server_ip_v4=$(curl -s ipinfo.io/ip 2>/dev/null)
    fi
    
    print_info "==================== Client Configuration ===================="
    echo "Server Address (IPv4): ${server_ip_v4:-N/A}"
    if [[ -n "$server_ip_v6" ]]; then
        echo "Server Address (IPv6): $server_ip_v6"
    fi
    echo "Server Port: $port"
    echo "UUID: $uuid"
    echo "SNI: $sni"
    echo "Short ID: $short_id"
    echo "Public Key: $public_key"
    echo ""
    echo "Config File Path: $config_file"
    print_info "=================================================="
    
    # 构建VLESS链接（IPv4版本）
    local vless_link_v4="vless://${uuid}@${server_ip_v4}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${public_key}&sid=${short_id}&type=tcp&headerType=none"
    
    echo ""
    print_info "==================== VLESS Link (IPv4) ===================="
    echo -e "${GREEN}${vless_link_v4}${NC}"
    print_info "========================================================="
    
    # 如果有IPv6地址，构建IPv6版本的链接
    if [[ -n "$server_ip_v6" ]]; then
        # IPv6地址需要用方括号包裹
        local vless_link_v6="vless://${uuid}@[${server_ip_v6}]:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${public_key}&sid=${short_id}&type=tcp&headerType=none"
        
        echo ""
        print_info "==================== VLESS Link (IPv6) ===================="
        echo -e "${GREEN}${vless_link_v6}${NC}"
        print_info "========================================================="
    fi
    
    # 提示信息：服务同时支持IPv4和IPv6连接
    echo ""
    print_info "Note: sing-box service is configured to support both IPv4 and IPv6 connections"
    print_info "Clients can use either link to connect"
    
    echo ""
    
    log_info "客户端配置显示完成"
}

# 检查端口是否已被占用（支持IPv4和IPv6）
# 
# 设计说明:
# 该函数采用通用性检查策略，而非按系统类型硬编码，原因如下:
# 1. 自动适应性: 能在各种系统上自动选择最适合的工具
# 2. 兼容性强: 支持各种Linux发行版和Unix系统
# 3. 容错性好: 即使首选工具不可用，也有备选方案
# 4. 维护简单: 无需为每种系统维护不同的检查逻辑
# 
# 检查顺序:
# 1. 优先使用 ss 命令（现代Linux系统推荐工具）
# 2. 备选使用 netstat 命令（较老的系统）
# 3. 最后使用 lsof 命令（Unix系统通用工具）
# 
# 这种通用性设计比按系统类型硬编码更加灵活和健壮
is_port_in_use() {
    local port=$1
    
    # 记录端口检查日志
    log_debug "检查端口 $port 是否已被占用"
    
    # Alpine Linux可能没有ss命令，使用netstat替代
    if command -v ss &> /dev/null; then
        # 检查TCP和UDP端口（包括IPv4和IPv6）
        log_debug "使用 ss 命令检查端口 $port"
        if ss -tuln | grep -q ":$port " || ss -tuln6 | grep -q ":$port " || ss -tuln | grep -q ":$port$" || ss -tuln6 | grep -q ":$port$"; then
            log_debug "端口 $port 已被占用 (通过 ss 命令检测)"
            return 0  # 端口已被占用
        else
            log_debug "端口 $port 未被占用 (通过 ss 命令检测)"
            return 1  # 端口未被占用
        fi
    elif command -v netstat &> /dev/null; then
        # 使用netstat检查端口（包括IPv4和IPv6）
        log_debug "使用 netstat 命令检查端口 $port"
        if netstat -tuln | grep -q ":$port " || netstat -tuln6 | grep -q ":$port " || netstat -tuln | grep -q ":$port$" || netstat -tuln6 | grep -q ":$port$"; then
            log_debug "端口 $port 已被占用 (通过 netstat 命令检测)"
            return 0  # 端口已被占用
        else
            log_debug "端口 $port 未被占用 (通过 netstat 命令检测)"
            return 1  # 端口未被占用
        fi
    # 如果都没有，尝试使用lsof
    elif command -v lsof &> /dev/null; then
        log_debug "使用 lsof 命令检查端口 $port"
        if lsof -i :$port &> /dev/null || lsof -i6 :$port &> /dev/null; then
            log_debug "端口 $port 已被占用 (通过 lsof 命令检测)"
            return 0  # 端口已被占用
        else
            log_debug "端口 $port 未被占用 (通过 lsof 命令检测)"
            return 1  # 端口未被占用
        fi
    else
        # 如果所有工具都不可用，返回未占用（保守做法）
        log_debug "未找到可用的端口检查工具，假设端口 $port 未被占用"
        return 1
    fi
}
# 添加打印成功信息的函数
print_success() {
    echo -e "${GREEN}$1${NC}"
}



# 卸载sing-box
uninstall_singbox() {
    print_warning "注意: 此操作将完全删除sing-box及其所有配置文件!"
    read -p "确定要卸载sing-box吗? (y/N): " confirm
    
    if [[ "$confirm" == "y" ]] || [[ "$confirm" == "Y" ]]; then
        print_info "开始卸载sing-box..."
        
        # 停止服务（不使用stop_singbox_service函数，避免直接跳转）
        manage_service "stop"
        
        # 删除配置文件和目录
        if [[ -d "$CONFIG_DIR" ]]; then
            rm -rf "$CONFIG_DIR"
            print_info "已删除配置目录: $CONFIG_DIR"
        fi
        
        # 删除二进制文件
        if [[ -f "/usr/local/bin/sing-box" ]]; then
            rm -f /usr/local/bin/sing-box
            print_info "已删除sing-box二进制文件"
        fi
        
        # 删除systemd服务文件
        if [[ -f "/etc/systemd/system/sing-box@.service" ]]; then
            rm -f /etc/systemd/system/sing-box@.service
            systemctl daemon-reload 2>/dev/null
            print_info "已删除systemd服务文件"
        fi
        
        print_success "sing-box卸载完成!"
    else
        print_info "取消卸载操作"
    fi
    
    print_info "按任意键返回主菜单..."
    read -n 1 -s -r -p ""
    echo
    show_main_menu
}

# 查看完整日志
view_full_logs() {
    clear
    print_blue "==========================================="
    print_blue "           sing-box 完整安装日志"
    print_blue "==========================================="
    echo ""
    
    if [[ -f "$LOG_FILE" ]]; then
        local log_size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo "0")
        if [[ "$log_size" -eq 0 ]]; then
            print_info "日志文件为空"
        else
            print_info "日志文件大小: $(($log_size / 1024)) KB"
            echo "提示: 使用 less 查看时，按 q 键退出查看器"
            echo "----------------------------------------"
            if command -v less &> /dev/null; then
                less "$LOG_FILE"
            else
                cat "$LOG_FILE"
            fi
        fi
    else
        print_warning "日志文件不存在: $LOG_FILE"
    fi    
    echo ""
    read -p "按回车键返回日志菜单..." dummy
    show_log_menu
}

# 查看最近日志
view_recent_logs() {
    if [[ ! -f "$LOG_FILE" ]]; then
        print_error "日志文件不存在: $LOG_FILE"
        read -p "按回车键返回日志菜单..." dummy
        show_log_menu
        return
    fi
    
    local log_size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo "0")
    if [[ "$log_size" -eq 0 ]]; then
        print_info "日志文件为空"
        echo "----------------------------------------"
        print_info "最近300行日志内容 ($LOG_FILE):"
        echo "----------------------------------------"
        tail -n 300 "$LOG_FILE"
        echo "----------------------------------------"
    fi
    read -p "按回车键返回日志菜单..." dummy
    show_log_menu
}

# 实时监控日志
monitor_logs() {
    clear
    print_blue "==========================================="
    print_blue "           sing-box 实时日志监控"
    print_blue "==========================================="
    echo ""
    print_info "按 Ctrl+C 停止监控并返回日志菜单"
    echo ""
    
    if [[ -f "$LOG_FILE" ]]; then
        local log_size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo "0")
        if [[ "$log_size" -eq 0 ]]; then
            print_info "日志文件为空，等待新日志内容..."
        fi
        if command -v tail &> /dev/null; then
            tail -f "$LOG_FILE"
        else
            print_warning "系统缺少tail命令"
        fi
    else
        print_warning "日志文件不存在: $LOG_FILE"
    fi
    
    echo ""
    read -p "按回车键返回日志菜单..." dummy
    show_log_menu
}

# 查看配置文件
view_config() {
    local config_file="$CONFIG_FILE"
    
    if [[ ! -f "$config_file" ]]; then
        print_error "未找到配置文件: $config_file"
        read -p "按回车键返回主菜单..." dummy
        show_main_menu
        return
    fi
    
    print_info "配置文件内容 ($config_file):"
    echo "----------------------------------------"
    
    # 检查是否有jq命令可用，如果有则使用jq美化显示JSON
    if command -v jq &> /dev/null; then
        # 使用jq美化显示JSON
        jq . "$config_file"
    else
        # 如果没有jq，直接显示原始内容
        cat "$config_file"
    fi    
    echo "----------------------------------------"
    read -p "按回车键返回主菜单..." dummy
    show_main_menu
}



# 查看当前配置
view_current_config() {
    clear
    print_blue "==========================================="
    print_blue "           当前 sing-box 配置"
    print_blue "==========================================="
    echo ""
    
    local config_file="$CONFIG_FILE"
    
    # 检查配置文件是否存在
    if [[ ! -f "$config_file" ]]; then
        print_error "未找到配置文件: $config_file"
        read -p "按回车键返回配置菜单..." dummy
        show_config_menu
        return
    fi
    
    # 显示配置文件内容
    if command -v jq &> /dev/null; then
        # 使用jq美化显示JSON
        jq . "$config_file"
    else
        # 直接显示文件内容
        cat "$config_file"
    fi    
    echo ""
    print_info "配置文件路径: $config_file"
    echo ""
    read -p "按回车键返回配置菜单..." dummy
    show_config_menu
}

# 创建sing-box配置目录
create_config_dir() {
    log_info "创建配置目录 $CONFIG_DIR/"
    if [[ ! -d "$CONFIG_DIR" ]]; then
        print_info "配置目录不存在，正在创建 $CONFIG_DIR..."
        mkdir -p "$CONFIG_DIR"
    fi
    
    print_info "配置目录已存在: $CONFIG_DIR"
    
    # 创建密钥目录
    if [[ ! -d "$KEYS_DIR" ]]; then
        mkdir -p "$KEYS_DIR"
    fi
}

# 主函数
main() {
    # 设置非交互模式标志
    if [[ -n "$PORT" && -n "$UUID" && -n "$SNI" ]]; then
        NON_INTERACTIVE="true"
        log_info "启用非交互模式 (所有环境变量均已设置)"
    elif [[ -n "$PORT" ]] || [[ -n "$UUID" ]] || [[ -n "$SNI" ]]; then
        # 如果设置了任何一个环境变量，也启用非交互模式
        NON_INTERACTIVE="true"
        log_info "启用非交互模式 (部分环境变量已设置)"
    fi
    
    # 初始化日志
    setup_logging
    
    # 记录环境变量状态
    log_debug "环境变量状态 - PORT: ${PORT:-未设置}, UUID: ${UUID:-未设置}, SNI: ${SNI:-未设置}"
    log_debug "非交互模式状态: ${NON_INTERACTIVE:-false}"
    
    # 如果设置了非交互模式，运行安装但不直接退出
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        log_info "开始非交互式安装流程"
        # 在非交互模式下执行系统环境检查
        perform_system_checks
        non_interactive_install
        log_info "非交互式安装流程完成"
        # 安装完成后继续显示主菜单，而不是直接退出
    fi
    
    # 显示主菜单
    log_debug "显示主菜单"
    show_main_menu
}

# 执行主函数
main "$@"
