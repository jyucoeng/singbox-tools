
#!/usr/bin/env bash
export LANG=en_US.UTF-8

# ================== 版本和作者信息 ==================
VERSION="1.0.6(2026-03-07)"
AUTHOR="littleDoraemon"

# ================== 工作目录常量 ==================
AGSB_HOME="${HOME}/agsb"
AGSB_BIN="${AGSB_HOME}/sing-box"
AGSB_CONFIG="${AGSB_HOME}/sb.json"
AGSB_UUID_FILE="${AGSB_HOME}/uuid"
AGSB_REALITY_KEY="${AGSB_HOME}/reality.key"
AGSB_SHORT_ID="${AGSB_HOME}/short_id"
AGSB_WEBROOT="$AGSB_WEBROOT"
AGSB_LOG_DIR="${AGSB_HOME}/logs"
AGSB_LOG_FILE="${AGSB_LOG_DIR}/agsb.log"
AGSB_STATE_FILE="${AGSB_HOME}/state.json"

# ================== 默认值常量定义 ==================
# 【CDN 和 SNI 默认值】
DEFAULT_CDN_HOST="saas.sin.fan"
DEFAULT_HY_SNI="www.microsoft.com"
DEFAULT_VL_SNI="www.microsoft.com"
DEFAULT_TU_SNI="www.microsoft.com"

# 【端口默认值】
DEFAULT_NGINX_PORT=8080
DEFAULT_ARGO_PORT=8001
DEFAULT_CDN_PORT=443
DEFAULT_VL_SNI_PORT=443

# 【功能开关默认值】
DEFAULT_SUBSCRIBE="false"
DEFAULT_DEBUG_FLAG="0"

# 【其他默认值】
DEFAULT_REALITY_PRIVATE=""
DEFAULT_REALITY_PUBLIC=""
DEFAULT_OUT_IP=""

# ================== 文件名常量定义 ==================
# 【配置和数据文件】
AGSB_FILE_UUID="uuid"
AGSB_FILE_CONFIG="sb.json"
AGSB_FILE_REALITY_KEY="reality.key"
AGSB_FILE_SHORT_ID="short_id"
AGSB_FILE_SERVER_IP="server_ip.log"
AGSB_FILE_NAME="name"
AGSB_FILE_CDN_HOST="cdn_host"
AGSB_FILE_STATE="state.json"

# 【Argo 相关文件】
AGSB_FILE_TUNNEL_JSON="tunnel.json"
AGSB_FILE_TUNNEL_YML="tunnel.yml"
AGSB_FILE_ARGO_LOG="argo.log"
AGSB_FILE_ARGO_PORT="argoport.log"
AGSB_FILE_ARGO_YM="sbargoym.log"
AGSB_FILE_ARGO_TOKEN="sbargotoken.log"

# 【日志和临时文件】
AGSB_FILE_DEPS_FAILED="deps_failed.log"
AGSB_FILE_PERF_REPORT="perf_report.txt"
AGSB_FILE_TEST_REPORT="test_report.txt"
AGSB_DIR_TMP_REALITY=".tmp_reality"

# ================== 系统路径常量 ==================
TMP_DIR="/tmp"
TMP_CRONTAB="${TMP_DIR}/crontab.tmp"
REDHAT_RELEASE="/etc/redhat-release"
OS_RELEASE="/etc/os-release"
IPTABLES_DIR="/etc/iptables"
SYSTEMD_DIR="/etc/systemd/system"
INITD_DIR="/etc/init.d"
BASHRC_FILE="${HOME}/.bashrc"

# ================== 服务名称常量 ==================
SB_SERVICE_NAME="agsb-singbox"
NGINX_SERVICE_NAME="nginx"

# ================== 错误消息常量定义 ==================
# 【目录和文件操作错误】
ERR_CREATE_DIR="❌ 无法创建目录"
ERR_CREATE_LOG_DIR="❌ 无法创建日志目录"
ERR_CONFIG_LOAD="❌ 配置文件加载失败"
ERR_CONFIG_UNREADABLE="❌ 配置文件不可读"
ERR_CONFIG_SYNTAX="❌ 配置文件语法错误"
ERR_CONFIG_INVALID="❌ 配置文件无效"

# 【验证错误】
ERR_UUID_INVALID="❌ UUID 格式无效"
ERR_PORT_INVALID="❌ 端口无效（必须是 1-65535 的整数）"
ERR_IP_INVALID="❌ IP 地址无效"
ERR_DOMAIN_INVALID="❌ 域名格式无效"
ERR_SNI_INVALID="❌ SNI 格式无效"
ERR_PORT_CONFLICT="❌ 端口冲突"

# 【权限和安全错误】
ERR_PERMS_UNSAFE="❗ 文件权限不安全，已修复"
ERR_BACKUP_FAILED="❗ 配置备份失败"

# 【文件操作错误】
ERR_FILE_WRITE="❌ 无法写入文件"
ERR_FILE_READ="❌ 无法读取文件"
ERR_FILE_EMPTY="❌ 文件为空或不存在"
ERR_CHMOD_FAILED="❌ 无法设置执行权限"
ERR_DOWNLOAD_FAILED="❌ 下载失败"

# 【服务管理错误】
ERR_SERVICE_RESTART="❌ 服务重启失败"
ERR_SERVICE_UNSUPPORTED="❌ 不支持的服务管理器"
ERR_NGINX_CONFIG="❌ Nginx 配置检查失败"
ERR_NGINX_INSTALL="❌ Nginx 安装失败"

# 【Argo 错误】
ERR_ARGO_TUNNEL_ID="❌ Argo JSON 中未找到 TunnelID"
ERR_ARGO_DOMAIN="❌ 未能获取 Argo 域名"
ERR_ARGO_PROCESS="❌ 未检测到 sing-box/cloudflared 运行"

# 【其他错误】
ERR_TIMER_NOT_FOUND="❌ 计时器不存在"
ERR_TIMER_NOT_STOPPED="❌ 计时器未停止"
ERR_PACKAGE_MANAGER="❌ 未检测到支持的包管理器"
ERR_MISSING_DEPS="❌ 关键依赖仍缺失"

# ================== 日志格式常量定义 ==================
# 【日志级别】
LOG_LEVEL_INFO="INFO"
LOG_LEVEL_WARN="WARN"
LOG_LEVEL_ERROR="ERROR"
LOG_LEVEL_DEBUG="DEBUG"

# 【日志格式】
LOG_FORMAT_TIMESTAMP="%s"
LOG_FORMAT_LEVEL="%s"
LOG_FORMAT_MESSAGE="%s"
LOG_SEPARATOR_LONG="=========================================="
LOG_SEPARATOR_SHORT="=============================="

# ================== 协议常量定义 ==================
# 【Argo 协议映射】协议类型 -> 输出文件内容
declare -A ARGO_PROTOCOL_MAP=(
  ["vmpt"]="Vmess"
  ["trpt"]="Trojan"
)

# 【支持的 Argo 协议列表】用于验证和扩展
ARGO_SUPPORTED_PROTOCOLS="vmpt trpt"

# ================== 外部资源 URL ==================
IP_CHECK_URL="https://icanhazip.com"
SCRIPT_REPO_URL="https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb00.sh"

# ================== Argo 优选端口白名单 ==================
HTTPS_CDN_PORTS=(443 2053 2083 2087 2096 8443)

# ================== Phase 32: 配置文件支持 ==================
# 配置文件路径（按优先级）
AGSB_CONFIG_USER="${HOME}/.agsb/config"
AGSB_CONFIG_SYSTEM="/etc/agsb/config"

# 从配置文件加载参数
# 参数优先级：命令行环境变量 > 配置文件 > 默认值
load_config_file() {
  local config_file=""
  
  # 查找配置文件（用户级优先于系统级）
  if [ -f "$AGSB_CONFIG_USER" ]; then
    config_file="$AGSB_CONFIG_USER"
  elif [ -f "$AGSB_CONFIG_SYSTEM" ]; then
    config_file="$AGSB_CONFIG_SYSTEM"
  else
    dlog "未找到配置文件（$AGSB_CONFIG_USER 或 $AGSB_CONFIG_SYSTEM），使用默认值"
    return 0
  fi
  
  dlog "从配置文件加载参数：$config_file"
  
  # 验证配置文件可读性
  if [ ! -r "$config_file" ]; then
    yellow "❗ 配置文件不可读：$config_file"
    return 1
  fi
  
  # 逐行读取配置文件，支持 KEY=VALUE 格式和注释
  local line key value
  while IFS='=' read -r key value; do
    # 跳过空行和注释行
    [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
    
    # 去掉前后空格
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)
    
    # 跳过空值
    [ -z "$value" ] && continue
    
    # 只有当环境变量未设置时才从配置文件读取
    # 这样保证命令行参数优先级最高
    if [ -z "${!key:-}" ]; then
      export "$key=$value"
      dlog "从配置文件加载：$key=$value"
    else
      dlog "跳过配置文件参数（已由环境变量设置）：$key"
    fi
  done < "$config_file"
  
  return 0
}

# ================== Phase 32: 配置文件支持 END ==================

# ================== 环境变量配置 ==================
# CDN 和 SNI 配置
export cdn_host=${cdn_host:-"$DEFAULT_CDN_HOST"}
export hy_sni=${hy_sni:-"$DEFAULT_HY_SNI"}
export vl_sni=${vl_sni:-"$DEFAULT_VL_SNI"}
export tu_sni=${tu_sni:-"$DEFAULT_TU_SNI"}

# 端口配置
export uuid=${uuid:-''}
export port_vm_ws=${vmpt:-''}
export port_tr=${trpt:-''}
export port_hy2=${hypt:-''}
export port_vlr=${vlrt:-''}
export port_tu=${tupt:-''}

# 出口 IP（优先级高于检测到的 IP）
export out_ip=${out_ip:-"$DEFAULT_OUT_IP"}

# Argo 隧道配置
export argo=${argo:-''}
export ARGO_DOMAIN=${agn:-''}
export ARGO_AUTH=${agk:-''}
export ippz=${ippz:-''}
export name=${name:-''}

# 服务端口配置
export nginx_pt=${nginx_pt:-$DEFAULT_NGINX_PORT}
export argo_pt=${argo_pt:-$DEFAULT_ARGO_PORT}

# 功能开关
export subscribe="${subscribe:-$DEFAULT_SUBSCRIBE}"
export reality_private="${reality_private:-$DEFAULT_REALITY_PRIVATE}"
export reality_public="${reality_public:-$DEFAULT_REALITY_PUBLIC}"

# CDN 端口配置
export cdn_pt="${cdn_pt:-$DEFAULT_CDN_PORT}"
export vl_sni_pt="${vl_sni_pt:-$DEFAULT_VL_SNI_PORT}"

# 调试日志开关
export DEBUG_FLAG=${DEBUG_FLAG:-'$DEFAULT_DEBUG_FLAG'}

# ================== 其他常量 ==================
# 全局变量
v4_ok=false
v6_ok=false

# 外部资源 URL
v46url="https://icanhazip.com"
agsburl="https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh"

# 调试日志开关
export DEBUG_FLAG=${DEBUG_FLAG:-'0'}

 # ================== 常量和环境变量 结束 ==================

 # ================== 颜色函数 ==================
white(){ echo -e "\033[1;37m$1\033[0m"; }
red(){ echo -e "\e[1;91m$1\033[0m"; }
green(){ echo -e "\e[1;32m$1\033[0m"; }
yellow(){ echo -e "\e[1;33m$1\033[0m"; }
blue(){ echo -e "\e[1;34m$1\033[0m"; }
purple(){ echo -e "\e[1;35m$1\033[0m"; }
#彩虹打印
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
# ================== 颜色函数 ==================

# 检查命令是否存在
has_cmd() {
    command -v "$1" >/dev/null 2>&1
}

# 获取命令路径
get_cmd_path() {
    command -v "$1" 2>/dev/null || true
}

# 文件检查函数
is_file() { [ -f "$1" ]; }
is_file_nonempty() { [ -s "$1" ]; }
is_dir() { [ -d "$1" ]; }
is_executable() { [ -x "$1" ]; }
file_exists() { [ -e "$1" ]; }

# 文件读取函数
read_file() { cat "$1" 2>/dev/null; }
read_file_or_empty() { cat "$1" 2>/dev/null || echo ""; }

# 目录操作函数
ensure_dir() { ensure_dir "$1"; }
ensure_dir_strict() { mkdir -p "$1" || return 1; }

is_true() {
  [ "$(printf '%s' "${1:-}" | tr 'A-Z' 'a-z')" = "true" ]
}

debug_log() {
  [ "${DEBUG_FLAG:-0}" = "1" ] && echo -e "$*" >&2
}

# 简化版 debug_log（用于减少代码量）
dlog() { dlog "$*"; }

# ================== Phase 13: 通用文件操作函数 ==================
# 统一的文件写入函数
write_agsb_file() {
  local filename="$1"
  local content="$2"
  local filepath="$AGSB_HOME/$filename"
  
  echo "$content" > "$filepath" || {
    red "❌ 无法写入文件：$filepath"
    return 1
  }
}

# 统一的文件读取函数（带默认值）
read_agsb_file() {
  local filename="$1"
  local default="${2:-}"
  local filepath="$AGSB_HOME/$filename"
  
  if [ -s "$filepath" ]; then
    cat "$filepath"
  else
    echo "$default"
  fi
}

# 统一的变量初始化函数
init_var() {
  local var_name="$1"
  local default_value="$2"
  
  eval "[ -z \"\${$var_name}\" ] && $var_name='$default_value'"
}

# 通用的命令执行和错误处理
run_or_fail() {
  local cmd="$1"
  local error_msg="${2:-命令执行失败}"
  
  eval "$cmd" || {
    red "❌ $error_msg"
    return 1
  }
}

# 通用的服务操作函数
service_op() {
  local op="$1"      # start, stop, restart, status
  local service="$2"
  
  if has_systemd; then
    systemctl "$op" "$service" 2>/dev/null
  elif has_cmd rc-service; then
    rc-service "$service" "$op" 2>/dev/null
  elif has_cmd service; then
    service "$service" "$op" 2>/dev/null
  else
    red "❌ 未检测到支持的服务管理器"
    return 1
  fi
}

# ================== Phase 13: 通用文件操作函数 END ==================

# ================== Phase 14: 高级优化函数 ==================
# 端口生成、保存和验证的统一函数
save_port() {
  local port_name="$1"
  local port_value="${2:-}"
  
  # 如果没有提供端口值，则生成随机端口
  if [ -z "$port_value" ]; then
    port_value=$(rand_port)
  fi
  
  # 验证端口
  if ! [[ "$port_value" =~ ^[0-9]+$ ]] || [ "$port_value" -lt 1 ] || [ "$port_value" -gt 65535 ]; then
    red "❌ 无效的端口号：$port_value"
    return 1
  fi
  
  write_agsb_file "$port_name" "$port_value"
  echo "$port_value"
}

# 获取或生成端口
get_or_generate_port() {
  local port_name="$1"
  local port_file="$AGSB_HOME/$port_name"
  
  if [ -s "$port_file" ]; then
    cat "$port_file"
  else
    save_port "$port_name"
  fi
}

# 日志输出的统一函数
log_success() {
  local msg="$1"
    log_success "$msg"
  green "✅ $msg"
}

log_error() {
  local msg="$1"
  red "❌ $msg"
}

log_info() {
  local msg="$1"
  yellow "ℹ️ $msg"
}

# 等待条件满足的通用函数
wait_for_condition() {
  local file="$1"
  local pattern="$2"
  local timeout="${3:-30}"
  local waited=0
  
  while [ $waited -lt $timeout ]; do
    if [ -f "$file" ] && grep -q "$pattern" "$file" 2>/dev/null; then
      return 0
    fi
    sleep 1
    ((waited++))
  done
  
  return 1
}

# 确保目录存在并写入文件
ensure_and_write_file() {
  local filepath="$1"
  local content="$2"
  local dir=$(dirname "$filepath")
  
  ensure_dir "$dir" || return 1
  echo "$content" > "$filepath" || return 1
}

# 读取文件或返回默认值
read_or_default() {
  local filepath="$1"
  local default="${2:-}"
  
  if [ -s "$filepath" ]; then
    cat "$filepath"
  else
    echo "$default"
  fi
}

# 条件执行函数（如果条件为真则执行命令）
run_if() {
  local condition="$1"
  shift
  
  if eval "$condition"; then
    eval "$@"
  fi
}

# 条件执行函数（如果条件为假则执行命令）
run_unless() {
  local condition="$1"
  shift
  
  if ! eval "$condition"; then
    eval "$@"
  fi
}

# ================== Phase 14: 高级优化函数 END ==================

get_subscribe_flag() {
  # 优先读落盘值（避免用户不带环境变量执行 agsb sub 时失效）
  if is_file_nonempty $AGSB_HOME/subscribe; then
    cat "$AGSB_HOME/subscribe"
  else
    echo "${subscribe:-false}"
  fi
}

# 统一判断工具：只有值严格等于 yes 才视为启用
is_yes() { [ "${1:-}" = "yes" ]; }

# 这些变量是你脚本外部用来“开启协议”的标记：
# trpt / hypt / vmpt / vlrt / tupt
# 只要标记存在，就启用对应协议
if [ -n "${trpt+x}" ]; then
    trp=yes
    vmag=yes
fi

if [ -n "${hypt+x}" ]; then
    hyp=yes
fi

if [ -n "${vmpt+x}" ]; then
    vmp=yes
    vmag=yes
fi

if [ -n "${vlrt+x}" ]; then
    vlr=yes
fi

if [ -n "${tupt+x}" ]; then
    tup=yes
fi

# 判断：至少启用一个协议
any_proto_enabled() {
    is_yes "$vlr" || is_yes "$vmp" || is_yes "$trp" || is_yes "$hyp" || is_yes "$tup"
}

# 判断：是否需要 Argo
need_argo() {
  local argo_needed=0      # 0=false, 1=true（用数字更直观）
  local argo_src=""        # debug：值来源
  local argo_val=""        # debug：实际拿来判断的值

  if [ -n "${argo:-}" ]; then
    argo_src="env"
    argo_val="$argo"
    if [ "$argo_val" = "vmpt" ] || [ "$argo_val" = "trpt" ]; then
      argo_needed=1
    fi
  elif is_file_nonempty $AGSB_HOME/vlvm; then
    argo_src="file"
    argo_val="$(cat "$AGSB_HOME/vlvm" 2>/dev/null | tr -d '\r\n')"
    if [ "$argo_val" = "Vmess" ] || [ "$argo_val" = "Trojan" ]; then
      argo_needed=1
    fi
  else
    argo_src="none"
    argo_val=""
    argo_needed=0
  fi

  debug_log "[调试] need_argo: src=$argo_src val='$argo_val' -> argo_needed=$argo_needed"

  [ "$argo_needed" -eq 1 ]
}

# 已安装/未安装的参数规则检查
if pgrep -f 'agsb/sing-box' >/dev/null 2>&1; then
    # 已安装
    if [ "${1:-}" = "rep" ]; then
        any_proto_enabled || { echo "提示：rep重置协议时，请在脚本前至少设置一个协议变量哦，再见！💣"; exit 1; }
    fi
else
    # 未安装
    if [ "${1:-}" != "del" ]; then
        any_proto_enabled || { echo "提示：未安装agsb脚本，请在脚本前至少设置一个协议变量哦，再见！💣"; exit 1; }
    fi
fi

# 判断系统是否支持 systemd
has_systemd() {
  has_cmd systemctl || return 1
  [ -d /run/systemd/system ] || return 1
  # 可选：更严格，确保 PID1 就是 systemd（不想太严格可删掉这一行）
  [ "$(ps -p 1 -o comm= 2>/dev/null | tr -d '[:space:]')" = "systemd" ] || return 1
  return 0
}

# 安装依赖
install_deps() {
  # 只负责安装“脚本运行必需的通用依赖”
  # ❗不要在这里强装 nginx / cloudflared / glibc（按需安装放到对应函数里）
    # 你脚本里常用的基础命令（按需增删）
  # - curl/wget：下载
  # - jq：解析 JSON
  # - openssl：证书/派生
  # - iptables：放行端口/保存规则
  # - ss：端口检测（来自 iproute2）
  # - lsof：端口占用检测
  # - fuser：用于等待 apt/dpkg 锁（psmisc）
  # - base64/stat/等：coreutils（不同系统差异大时更稳）
  # - xxd：某些本地推导会用到（常见在 vim-common / vim / xxd）

  dlog "install_deps安装函数开始了……"

  local NEED_CMDS=(
    curl wget jq openssl
    iptables
    ss
    lsof
    fuser
    base64
    xxd
  )

  # 失败包记录文件
  local fail_log="$AGSB_HOME/deps_failed.log"
  ensure_dir "$AGSB_HOME"

  # 找出缺的命令
  local -a missing=()
  local c
  for c in "${NEED_CMDS[@]}"; do
    has_cmd "$c" || missing+=("$c")
  done

  # 都齐了就直接返回
  if [ "${#missing[@]}" -eq 0 ]; then
    green "✅ 依赖已齐全，跳过安装"
    return 0
  fi

  yellow "👉 正在安装依赖...（缺少：${missing[*]}）"

  # ==========================================================
  # 通用安装器：逐个安装 + 边装边打印 + 记录失败包
  # 参数：
  #   $1 label: apt-get|yum|dnf|apk
  #   $2 cmd_arr_name: 命令前缀数组名（例如 APT_CMD）
  #   $3 pkgs_arr_name: 包数组名（例如 APT_PKGS）
  # 返回：
  #   0：不代表全成功（会跳过失败包），最终靠“关键命令兜底检查”
  # ==========================================================
  install_pkgs_resilient() {
    local label="$1"
    local -n _cmd="$2"
    local -n _pkgs="$3"

    local -a failed=()
    local p

    # 安装输出日志（避免刷屏；失败时可回看）
    local run_log="$TMP_DIR/agsb_deps_${label}.log"
    : > "$run_log" 2>/dev/null || true

    pkg_installed() {
      local pkg="$1"
      case "$label" in
        apt-get)
          dpkg -s "$pkg" >/dev/null 2>&1
          ;;
        yum|dnf)
          rpm -q "$pkg" >/dev/null 2>&1
          ;;
        apk)
          apk info -e "$pkg" >/dev/null 2>&1
          ;;
        *)
          return 1
          ;;
      esac
    }

    for p in "${_pkgs[@]}"; do
      # 已安装就直接提示
      if pkg_installed "$p"; then
        green "✅ 已存在依赖包：$p"
        continue
      fi

      yellow "👉 正在安装依赖包：$p"

      if [ "${DEBUG_FLAG:-0}" = "1" ]; then
        # 调试模式：不静默，方便看具体报错
        if "${_cmd[@]}" "$p"; then
          dlog " ✅ 安装成功：$p"
        else
          red "❌ 安装失败：$p（已跳过）"
          failed+=("$p")
        fi
      else
        # 默认：静默，把输出写到日志，失败时提示查看
        if "${_cmd[@]}" "$p" >>"$run_log" 2>&1; then
          green "✅ 安装成功：$p"
        else
          red "❌ 安装失败：$p（已跳过，详见 $run_log）"
          failed+=("$p")
        fi
      fi
    done

    if [ "${#failed[@]}" -gt 0 ]; then
      yellow "❗ 以下包安装失败（已跳过）："
      yellow "   ${failed[*]}"
      {
        echo "----- $(date '+%F %T') ${label} failed pkgs -----"
        printf '%s\n' "${failed[@]}"
      } >> "$fail_log" 2>/dev/null || true
      yellow "📌 失败包已记录到：${fail_log}"
    fi

    return 0
  }

  # =========================
  # Debian/Ubuntu (apt-get)
  # =========================
  if has_cmd apt-get; then
    export DEBIAN_FRONTEND=noninteractive

    # 等待 apt/dpkg 锁（避免死等；默认 180s，可用 APT_LOCK_WAIT 覆盖）
    local max_wait="${APT_LOCK_WAIT:-180}"
    local waited=0
    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
          fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
      waited=$((waited + 1))
      if [ "$waited" -ge "$max_wait" ]; then
        red "❌ apt/dpkg 正在被占用超过 ${max_wait} 秒，退出。"
        yellow "❗ 可能是 apt-daily / unattended-upgrades 在后台更新。"
        yellow "👉 你可以稍后再试，或临时增大等待时间：APT_LOCK_WAIT=600"
        return 1
      fi
      sleep 1
    done

    # update 尽量稳一点（重试+超时）
    apt-get -o Acquire::Retries=3 \
            -o Acquire::http::Timeout=15 \
            -o Acquire::https::Timeout=15 \
            update || { red "❌ apt-get update 失败（DNS/网络/源不可用）"; return 1; }

    local -a APT_PKGS=(
      curl wget jq openssl
      iptables iproute2
      lsof
      psmisc
      coreutils
      ca-certificates
      vim-common   # 提供 xxd（大多数 Debian/Ubuntu）
    )

    local -a APT_CMD=(
      apt-get -o Acquire::Retries=3
              -o Acquire::http::Timeout=15
              -o Acquire::https::Timeout=15
              install -y
    )

    install_pkgs_resilient "apt-get" APT_CMD APT_PKGS
    green "✅ 依赖安装流程完成（apt-get）"

  # =========================
  # RHEL/CentOS (yum) / Fedora (dnf)
  # =========================
  elif has_cmd yum || has_cmd dnf; then
    local pm="yum"
    has_cmd dnf && pm="dnf"

    local -a YUM_DNF_PKGS=(
      curl wget jq openssl
      iptables iproute
      lsof
      psmisc
      coreutils
      ca-certificates
      vim-common   # 多数发行版提供 xxd
    )

    if [ "$pm" = "dnf" ]; then
      local -a DNF_CMD=(dnf install -y)
      install_pkgs_resilient "dnf" DNF_CMD YUM_DNF_PKGS
      green "✅ 依赖安装流程完成（dnf）"
    else
      local -a YUM_CMD=(yum install -y)
      install_pkgs_resilient "yum" YUM_CMD YUM_DNF_PKGS
      green "✅ 依赖安装流程完成（yum）"
    fi

  # =========================
  # Alpine (apk)
  # =========================
  elif has_cmd apk; then
    # Alpine 关键点：
    # - 不跑 apk update（你之前遇到过 apk update 被 Killed）
    # - 逐个 apk add --no-cache，避免“一个包失败导致全盘退出”
    local -a APK_PKGS=(
      curl wget jq openssl
      iptables ip6tables
      iproute2
      lsof
      psmisc
      coreutils
      ca-certificates
    )

    local -a APK_CMD=(apk add --no-cache)
    install_pkgs_resilient "apk" APK_CMD APK_PKGS

    # xxd：Alpine 有时在 xxd 包或 vim 包里，做成“可选补齐”
    if ! has_cmd xxd; then
      yellow "👉 尝试补齐 xxd（可选）"
      apk add --no-cache xxd >/dev/null 2>&1 || apk add --no-cache vim >/dev/null 2>&1 || true
      has_cmd xxd && green "✅ xxd 已可用" || yellow "❗ xxd 仍不可用（不致命，继续）"
    fi

    green "✅ 依赖安装流程完成（apk）"
  else
    red "❌ 未检测到支持的包管理器（apt-get/yum/dnf/apk）"
    return 1
  fi

  # =========================
  # 关键命令兜底检查：缺了就失败
  # =========================
  local -a critical_cmds=(curl jq openssl iptables)
  local miss=0
  for c in "${critical_cmds[@]}"; do
    has_cmd "$c" || miss=1
  done

  # 下载工具至少要有一个（curl 或 wget）
  if ! has_cmd curl && ! has_cmd wget; then
    miss=1
  fi

  if [ "$miss" = "1" ]; then
    red "⚠️ 关键依赖仍缺失（curl/jq/openssl/iptables 或下载工具）"
    yellow "📌 你可以查看失败包记录：${fail_log}"
    yellow "👉 常见原因：源缺失（如 Alpine 缺 community）、网络/DNS、权限不足、低内存被系统杀进程"
    yellow "⚠️ 继续安装，但后续协议安装可能会失败"
  fi

  return 0
}

# 检查 IPv4 和 IPv6 的连通性
check_ip_connectivity() {
  local v46url="$1"
  local timeout="${IP_CHECK_TIMEOUT:-2}"   # 默认 2 秒（你也可以设成 1）
  local v4="" v6=""

  # IPv4
  v4="$(curl -s4 -m"$timeout" --connect-timeout "$timeout" "$v46url" 2>/dev/null \
        || wget -4 -qO- --tries=1 --timeout="$timeout" "$v46url" 2>/dev/null)"

  debug_log "[调试] check_ip_connectivity函数IPv4: $v4"
  # IPv6
  v6="$(curl -s6 -m"$timeout" --connect-timeout "$timeout" "$v46url" 2>/dev/null \
        || wget -6 -qO- --tries=1 --timeout="$timeout" "$v46url" 2>/dev/null)"
  debug_log "[调试] check_ip_connectivity函数IPv6: $v6"
  
  # 去掉换行（curl/wget 往往带 \n）
  v4_res="$(printf '%s' "$v4" | tr -d '\r\n')"
  v6_res="$(printf '%s' "$v6" | tr -d '\r\n')"
  #v4和v6中间用 | 分隔然后返回
  local result="$v4_res|$v6_res"

  debug_log "[调试] check_ip_connectivity函数返回值: $result"
  echo "$result"

}

# 开启自启
enable_autostart() {
  local workdir="/root/agsb"
  local bin="$workdir/sing-box"
  local cfg="$workdir/sb.json"
  local svc="agsb-singbox"

  # 只做“已安装才启用”，避免误触发安装
  if [ ! -x "$bin" ] || [ ! -s "$cfg" ]; then
    echo "❗ 未检测到已安装：$bin 或 $cfg 不存在/为空，已跳过开启自启"
    return 1
  fi

  # systemd (Debian/Ubuntu 等)
  if has_cmd systemctl && [ -d /run/systemd/system ]; then
    cat >$SYSTEMD_DIR/${svc}.service <<EOF
[Unit]
Description=agsb sing-box service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=${workdir}
ExecCondition=/bin/sh -c 'test -x ${bin} && test -s ${cfg}'
ExecStart=${bin} run -c ${cfg}
Restart=always
RestartSec=2
LimitNOFILE=1048576
TimeoutStartSec=30

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now "${svc}.service" >/dev/null 2>&1
    systemctl restart "${svc}.service" >/dev/null 2>&1
    echo "✅ 已开启开机自启（systemd）：${svc}"
    return 0
  fi

  # openrc (Alpine)
  if has_cmd rc-service && has_cmd rc-update; then
    cat >$INITD_DIR/${svc} <<'EOF'
#!/sbin/openrc-run
name="agsb sing-box"
description="agsb sing-box service"
command="/root/agsb/sing-box"
command_args="run -c /root/agsb/sb.json"
command_background="yes"
pidfile="/run/agsb-singbox.pid"

depend() {
  need net
  after firewall
}

start_pre() {
  [ -x /root/agsb/sing-box ] || return 1
  [ -s /root/agsb/sb.json ] || return 1
}

start() {
  ebegin "Starting ${name}"
  start-stop-daemon --start --background --make-pidfile --pidfile "$pidfile" \
    --exec "$command" -- $command_args
  eend $?
}

stop() {
  ebegin "Stopping ${name}"
  start-stop-daemon --stop --pidfile "$pidfile"
  eend $?
}
EOF

    chmod +x $INITD_DIR/${svc}
    rc-update add "${svc}" default >/dev/null 2>&1
    rc-service "${svc}" restart >/dev/null 2>&1
    echo "✅ 已开启开机自启（openrc）：${svc}"
    return 0
  fi

  echo "❗ 未检测到 systemd 或 openrc，无法设置开机自启"
  return 1
}

# 关闭自启
disable_autostart() {
  local svc="agsb-singbox"

  if has_cmd systemctl && [ -d /run/systemd/system ]; then
    systemctl disable --now "${svc}.service" >/dev/null 2>&1
    rm -f "$SYSTEMD_DIR/${svc}.service"
    systemctl daemon-reload >/dev/null 2>&1
    echo "✅ 已关闭开机自启（systemd）：${svc}"
    return 0
  fi

  if has_cmd rc-service && has_cmd rc-update; then
    rc-update del "${svc}" default >/dev/null 2>&1
    rc-service "${svc}" stop >/dev/null 2>&1
    rm -f "$INITD_DIR/${svc}"
    echo "✅ 已关闭开机自启（openrc）：${svc}"
    return 0
  fi

  echo "❗ 未检测到 systemd 或 openrc"
  return 1
}

# 显示菜单
showmode(){
    blue "===================================================="
    gradient "       singbox 一键脚本（vmess/trojan Argo选1,vless+hy2+tuic 3个直连）"
    green    "       作者：$AUTHOR"
    yellow   "       版本：$VERSION"
    blue "===================================================="
 
    yellow "主脚本：bash <(curl -Ls ${agsburl}) 或 bash <(wget -qO- ${agsburl})"
    yellow "显示节点信息：agsb list"
    yellow "生成配置文件：agsb config（生成 ~/.agsb/config 模板）"
    yellow "安装命令：  agsb ins（命令前面需要带上环境变量）"
    yellow "覆盖式安装命令： agsb rep（命令前面需要带上环境变量）"
    yellow "更新Singbox内核：agsb ups(属于预留命令)"
    yellow "重启脚本：agsb res(重启singbox和argo)"
    yellow "卸载脚本：agsb del"
    yellow "Nginx相关：agsb nginx_start | agsb nginx_stop | agsb nginx_restart | agsb nginx_status"
    echo "---------------------------------------------------------"
}

# ================== Phase 32: 配置文件生成函数 ==================
# 生成配置文件示例
generate_config_template() {
  local config_path="${1:-$AGSB_CONFIG_USER}"
  local config_dir=$(dirname "$config_path")
  
  # 创建配置目录
  mkdir -p "$config_dir" || {
    red "❌ 无法创建配置目录：$config_dir"
    return 1
  }
  
  # 生成配置文件模板
  cat > "$config_path" <<'EOF'
# agsb 配置文件示例
# 参数优先级：命令行环境变量 > 配置文件 > 默认值
# 注意：配置文件中的值会被命令行环境变量覆盖

# ========== CDN 和 SNI 配置 ==========
cdn_host=saas.sin.fan
hy_sni=www.microsoft.com
vl_sni=www.microsoft.com
tu_sni=www.microsoft.com

# ========== 端口配置 ==========
# UUID（必填）
uuid=0631a7f3-09f8-4144-acf2-a4f5bd9ed281

# 协议端口（可选，不设置则自动生成）
trpt=33952
vlrt=33953
hypt=33954
tupt=33955

# ========== Argo 隧道配置 ==========
# argo 值：trpt 或 vmpt（选择哪个协议走 Argo）
argo=trpt

# Argo 域名（agn）
agn=ca-tower-wong.dora.cc.cd

# Argo 凭据（agk）- JSON 格式
# agk='{"a":"...","t":"...","s":"..."}'

# ========== 服务端口配置 ==========
nginx_pt=33956
argo_pt=8001

# ========== 功能开关 ==========
subscribe=true
reality_private=GHCRfqiJFj3hzsOTyy57Gix-r6DJ0Ych-VnXH6Fj2XA
name=小叮当-加拿大-tower-wong

# ========== CDN 端口配置 ==========
cdn_pt=443
vl_sni_pt=443

# ========== 调试开关 ==========
DEBUG_FLAG=0
EOF

  chmod 600 "$config_path"
  green "✅ 配置文件模板已生成：$config_path"
  yellow "👉 请编辑配置文件并填入你的参数，然后运行脚本"
  return 0
}

# ================== Phase 32: 配置文件生成函数 END ==================

# 安装 Nginx 包
install_nginx_pkg() {
  # 已安装就不重复装
  if has_cmd nginx; then
    return 0
  fi

  yellow "👉 正在安装 Nginx..."

  # 统一把详细输出写到日志，失败时 tail 出来
  local log="$TMP_DIR/agsb_nginx_install.log"
  : > "$log" 2>/dev/null || true

  # Debian/Ubuntu (apt-get)
  if has_cmd apt-get; then
    export DEBIAN_FRONTEND=noninteractive

    # 1) 等待 apt/dpkg 锁（默认最多等 20s，可用 APT_LOCK_WAIT 覆盖）
    local max_wait="${APT_LOCK_WAIT:-20}"
    local waited=0

    while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
          fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
      waited=$((waited + 1))

      # ✅ 写法B：每秒更新同一行（不刷屏）
      printf "\r\033[0K\e[1;33m⏳ 等待 apt/dpkg 锁释放... (%s/%ss)\033[0m" "$waited" "$max_wait"

      if [ "$waited" -ge "$max_wait" ]; then
        echo
        red "❌ 等待 apt/dpkg 锁超时：${max_wait}s"
        yellow "❗ 常见原因：apt-daily / unattended-upgrades 在后台更新"
        yellow "👉 解决：稍后重试，或临时加长：APT_LOCK_WAIT=180"
        # 给个线索（不杀进程，只展示）
        ps aux 2>/dev/null | grep -E 'apt|dpkg|unattended|apt-daily' | grep -v grep | head -n 10 || true
        return 1
      fi

      sleep 1
    done
    echo  # 结束等待后换行，避免后续输出接在同一行

    # 2) 尝试修复 dpkg 中断（减少“莫名其妙失败”）
    dpkg --configure -a >>"$log" 2>&1 || true
    apt-get -f install -y >>"$log" 2>&1 || true

    # 3) update 加重试+超时（稳定很多）
    if ! apt-get -o Acquire::Retries=3 \
                 -o Acquire::http::Timeout=15 \
                 -o Acquire::https::Timeout=15 \
                 update >>"$log" 2>&1; then
      red "❌ apt-get update 失败（可能是 DNS/网络/源问题），详见：$log"
      tail -n 60 "$log" 2>/dev/null || true
      return 1
    fi

    # 4) 安装 nginx（同样加重试+超时）
    if ! apt-get -o Acquire::Retries=3 \
                 -o Acquire::http::Timeout=15 \
                 -o Acquire::https::Timeout=15 \
                 install -y nginx >>"$log" 2>&1; then
      red "❌ Nginx 安装失败，详见：$log"
      tail -n 80 "$log" 2>/dev/null || true
      return 1
    fi

  elif has_cmd apt; then
    # 兜底：尽量用 apt-get，但这里保留 apt
    export DEBIAN_FRONTEND=noninteractive
    if ! apt update >>"$log" 2>&1 || ! apt install -y nginx >>"$log" 2>&1; then
      red "❌ Nginx 安装失败，详见：$log"
      tail -n 80 "$log" 2>/dev/null || true
      return 1
    fi

  elif has_cmd yum; then
    yum install -y nginx >>"$log" 2>&1 || { red "❌ Nginx 安装失败，详见：$log"; tail -n 80 "$log" 2>/dev/null || true; return 1; }

  elif has_cmd dnf; then
    dnf install -y nginx >>"$log" 2>&1 || { red "❌ Nginx 安装失败，详见：$log"; tail -n 80 "$log" 2>/dev/null || true; return 1; }

  elif has_cmd apk; then
    apk add --no-cache nginx >>"$log" 2>&1 || { red "❌ Nginx 安装失败，详见：$log"; tail -n 80 "$log" 2>/dev/null || true; return 1; }

  else
    red "❌ 无法安装 Nginx：不支持的包管理器"
    return 1
  fi

  green "✅ Nginx 安装完成"
  return 0
}

# Check if the given port is in the list of HTTPS CDN ports
is_https_cdn_port() {
  local p="${1:-}"
  local x
  for x in "${HTTPS_CDN_PORTS[@]}"; do
    [ "$p" = "$x" ] && return 0
  done
  return 1
}

# ✅规范化 cdn_pt：非法就回退到默认端口（默认 443）
normalize_cdn_pt() {
  local p="${1:-}"
  local fallback="${2:-443}"

  # 空值直接回退
  [ -z "$p" ] && { echo "$fallback"; return 0; }

  # 非法端口回退
  if ! is_https_cdn_port "$p"; then
    yellow "❗ cdn_pt=$p 非法，仅支持 ${HTTPS_CDN_PORTS[*]}，已回退为 ${fallback}"
    echo "$fallback"
    return 0
  fi

  echo "$p"
}

# 调用规范化函数
# ✅ 规范化 cdn_pt（让后续写入文件/输出节点都统一）
cdn_pt="$(normalize_cdn_pt "$cdn_pt" 443)"
vl_sni_pt="$(normalize_cdn_pt "$vl_sni_pt" 443)"
export vl_sni_pt
export cdn_pt

# ================== 处理tunnel的json ==================

# 随机端口
rand_port() {
    # 优先用 shuf（最常见）
    if has_cmd shuf; then
        shuf -i 10000-65535 -n 1
        return
    fi

    # 备选：awk + 随机种子（兼容性很好）
    if has_cmd awk; then
        awk 'BEGIN{srand(); print int(10000 + rand()*55535)}'
        return
    fi

    # 兜底：用时间戳拼一个（保证有结果）
    echo $(( ( $(date +%s) % 55535 ) + 10000 ))
}

# 用法：
# prepare_argo_credentials "<ARGO_AUTH>" "<ARGO_DOMAIN>" "<LOCAL_PORT>"
prepare_argo_credentials() {
    local auth="$1"
    local domain="$2"
    local local_port="$3"

    ARGO_MODE="none"

    # 调试：不要打印敏感凭据本体，仅打印长度/关键信息
    dlog "prepare_argo_credentials：开始处理凭据（auth长度=${#auth}，domain=${domain:-<空>}，local_port=${local_port:-<空>}）"

    if [ -z "$auth" ]; then
        dlog "prepare_argo_credentials：auth 为空，跳过（ARGO_MODE=none）"
        return
    fi

    # ---------- JSON 凭据 ----------
    if echo "$auth" | grep -q 'TunnelSecret'; then
        yellow "检测到 Argo JSON 凭据，使用 credentials-file 模式"
        dlog "prepare_argo_credentials：识别为 JSON 凭据（将写入 $AGSB_HOME/tunnel.json 并生成 tunnel.yml）"

        if [ -z "$local_port" ]; then
            red "❌ prepare_argo_credentials: LOCAL_PORT 为空"
            dlog "prepare_argo_credentials：失败：local_port 为空，无法生成 tunnel.yml"
            return 1
        fi

        ensure_dir "$AGSB_HOME"

        # 写入 tunnel.json
        #❗ 如果 ARGO_AUTH 里的 JSON 含有 \n、\r、\uXXXX 之类，echo 在某些 shell/实现里可能会解释转义，导致 tunnel.json 内容被破坏。 改法：用 printf 更可靠
        printf '%s' "$auth" > "$AGSB_HOME/tunnel.json"
        dlog "prepare_argo_credentials：tunnel.json 已写入（大小=$(wc -c "$AGSB_HOME/tunnel.json" 2>/dev/null | awk '{print $1}') 字节）"

        # 提取 TunnelID
        local tunnel_id
        tunnel_id=$(echo "$auth" | sed -n 's/.*"TunnelID"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

        if [ -z "$tunnel_id" ]; then
            red "❌ Argo JSON 中未找到 TunnelID"
            dlog "prepare_argo_credentials：失败：JSON 中未解析到 TunnelID"
            return 1
        fi
        dlog "prepare_argo_credentials：已解析 TunnelID（前8位=${tunnel_id:0:8}...）"

        # 生成 tunnel.yml（对齐 s4.sh）
        cat > "$AGSB_HOME/tunnel.yml" <<EOF
tunnel: $tunnel_id
credentials-file: $AGSB_HOME/tunnel.json
protocol: http2

ingress:
  - hostname: ${domain}
    service: http://localhost:${local_port}
    originRequest:
      noTLSVerify: true
  - service: http_status:404
EOF
        dlog "prepare_argo_credentials：tunnel.yml 已生成（回源到 localhost:${local_port}，hostname=${domain:-<空>}）"

        ARGO_MODE="json"
        dlog "prepare_argo_credentials：ARGO_MODE 已设为 json"

    else
        # token 模式
        ARGO_MODE="token"
        dlog "prepare_argo_credentials：识别为 token 凭据（ARGO_MODE=token）"
    fi

    export ARGO_MODE
    dlog "prepare_argo_credentials：结束（ARGO_MODE=${ARGO_MODE}）"
}

echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"; 
echo "agsb一键无交互脚本💣 (Sing-box内核版)";  
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

hostname=$(uname -a | awk '{print $2}'); 
op=$(cat $REDHAT_RELEASE 2>/dev/null || cat $OS_RELEASE 2>/dev/null | grep -i pretty_name | cut -d \" -f2); 
case $(uname -m) in aarch64) cpu=arm64;; x86_64) cpu=amd64;; *) echo "目前脚本不支持$(uname -m)架构" && exit; esac;
 ensure_dir "$AGSB_HOME"
# Check and set IP version
v4v6(){
    # Check IPv4 connectivity
    dlog " Checking IPv4 and IPv6 connectivity, ready to get IP..."
    dlog " Checking IPv4 connectivity..."
    v4=$(curl -s4 -m2 --connect-timeout 2 -k "$v46url" 2>/dev/null || wget -4 -qO- --tries=2 --timeout=2 "$v46url" 2>/dev/null)
    if [ -n "$v4" ]; then
        v4_ok=true
    else
        v4_ok=false
    fi

    dlog " IPv4 connectivity check completed. ipv4=$v4"

    # Check IPv6 connectivity
    dlog " Checking IPv6 connectivity..."
    v6=$(curl -s6 -m2 --connect-timeout 2 -k "$v46url" 2>/dev/null || wget -6 -qO- --tries=2 --timeout=2 "$v46url" 2>/dev/null)
    if [ -n "$v6" ]; then
        v6_ok=true
    else
        v6_ok=false
    fi
    dlog " IPv6 connectivity check completed. ipv6=$v6"
    dlog " IP connectivity check completed. ipv4=$v4, ipv6=$v6"

}

# Set up name for nodes and IP version preference
setup_node_name_and_ip_strategy(){
    if [ -n "$name" ]; then
        sxname=$name-
        write_agsb_file "name" "$sxname"
        echo
        yellow "所有节点名称前缀：$name"
    fi
    echo "IP版本获取中……请稍候"
    v4v6  # This now sets both v4_ok and v6_ok
    
    # Determine which connection to prefer based on the availability of IPv4 and IPv6
    if [ "$v4_ok" = true ] && [ "$v6_ok" = true ]; then
        sbyx='prefer_ipv6'
    elif [ "$v4_ok" = true ] && [ "$v6_ok" != true ]; then
        sbyx='ipv4_only'
    elif [ "$v4_ok" != true ] && [ "$v6_ok" = true ]; then
        sbyx='ipv6_only'
    else
        sbyx='prefer_ipv6'  # Default to prefer IPv6 if neither is available
    fi
}

# download Sing-box
upsingbox(){
    url="https://github.com/jyucoeng/singbox-tools/releases/download/singbox/sing-box-$cpu"
    out="$AGSB_HOME/sing-box"
    (curl -Lo "$out" -# --connect-timeout 5 --max-time 120  --retry 2 --retry-delay 2 --retry-all-errors "$url") || (wget -O "$out" --tries=2 --timeout=120 --dns-timeout=5 --read-timeout=60 "$url")

    dlog "upsingbox：下载 Sing-box 二进制文件，保存路径 $out，url: $url"

    # 下载结果校验：防止拿到空文件/错误页导致后续假安装
    if [ ! -s "$out" ]; then
        dlog "upsingbox：下载失败：文件为空"
        red "❌ 下载失败：文件为空 $out"
        exit 1
    fi
    dlog "upsingbox：检查 Sing-box 二进制文件是否下载成功"

    chmod +x "$AGSB_HOME/sing-box"
    sbcore=$("$AGSB_HOME/sing-box" version 2>/dev/null | awk '/version/{print $NF}')
    dlog "upsingbox：Sing-box 版本为 $sbcore"
    green "✅  已安装Sing-box正式版内核：$sbcore"
}
# Generate UUID and save to file
insuuid(){
    if [ ! -e "$AGSB_HOME/sing-box" ]; then 
        upsingbox;
    fi

    if [ -z "$uuid" ] && [ ! -e "$AGSB_HOME/uuid" ]; then
        uuid=$("$AGSB_HOME/sing-box" generate uuid)
        write_agsb_file "uuid" "$uuid"
    elif [ -n "$uuid" ]; then
        write_agsb_file "uuid" "$uuid"
    fi
    uuid=$(cat "$AGSB_HOME/uuid")
    yellow "UUID密码：$uuid"
}

# Generate short_id
get_short_id() {
  # 用法：get_short_id [short_id_file_path]
  # 返回：echo 输出 short_id
  #
  # 优先级：
  # 1) 传了 reality_private → 直接由 reality_private 稳定推导 short_id（并写入文件）
  # 2) 否则                → 读文件；文件无效/不存在则随机生成并落盘

  local sid_file="${1:-$AGSB_HOME/short_id}"
  local sid=""

  # 兼容：如果脚本里没有 yellow/green，就用 echo
  has_cmd yellow || yellow(){ echo -e "$*"; }
  has_cmd green || green(){ echo -e "$*"; }

  _is_hex() { echo "$1" | grep -qiE '^[0-9a-f]{8}$'; }

  # 由 reality_private 推导一个稳定的 short_id
  # 仅使用 reality_private 推导（更可控、更干净）
  local rp="${reality_private:-}"
  if [ -n "${rp:-}" ]; then
    # 推导方式：sha256(reality_private) 取前 8 位 hex
    if has_cmd sha256sum; then
      sid="$(printf "%s" "$rp" | sha256sum | awk '{print $1}' | cut -c1-8)"
    elif has_cmd openssl; then
      sid="$(printf "%s" "$rp" | openssl dgst -sha256 2>/dev/null | awk '{print $NF}' | cut -c1-8)"
    elif has_cmd md5sum; then
      sid="$(printf "%s" "$rp" | md5sum | awk '{print $1}' | cut -c1-8)"
    else
      # 兜底：仍然随机生成，但会落盘保持后续稳定
      sid="$(head -c 4 /dev/urandom 2>/dev/null | od -An -tx1 | tr -d ' \n' | cut -c1-8)"
    fi

    sid="${sid,,}"
    if _is_hex "$sid"; then
      # 如果文件存在但不一致，覆盖以保证“只传 reality_private 也稳定一致”
      if is_file $sid_file; then
        local old_sid
        old_sid="$(cat "$sid_file" 2>/dev/null | tr -d ' \r\n')"
        if [ -n "$old_sid" ] && [ "${old_sid,,}" != "$sid" ]; then
          yellow "❗ 检测到 short_id 文件与 reality_private 推导值不同，已按 reality_private 覆盖以保证稳定"
        fi
      fi
      echo "$sid" > "$sid_file"

      debug_log "✅ 【调试】short_id 已由 reality_private 稳定推导, 值: $sid"

      echo "$sid"
      return 0
    fi
  fi

  # 3) 没传 short_id 且未传 reality_private → 文件优先
  if is_file $sid_file; then
    sid="$(cat "$sid_file" 2>/dev/null | tr -d ' \r\n')"
    sid="${sid,,}"
    if _is_hex "$sid"; then
      yellow "从文件中读取 short_id, 值: $sid" >&2
      echo "$sid"
      return 0
    else
      yellow "❗ short_id 文件内容无效（必须是8位hex），将重新生成"
      rm -f "$sid_file" 2>/dev/null
    fi
  fi

  # 4) 随机生成（8位 hex，等价 openssl rand -hex 4）
  if has_cmd openssl; then
    sid="$(openssl rand -hex 4 2>/dev/null)"
  else
    sid=""
  fi
  if [ -z "$sid" ]; then
    sid="$(head -c 4 /dev/urandom 2>/dev/null | od -An -tx1 | tr -d ' \n' | cut -c1-8)"
  fi

  sid="${sid,,}"
  echo "$sid" > "$sid_file"
  green "随机生成 short_id, 值: $sid"
  echo "$sid"
  return 0
}

# 从私钥推导公钥，并返回公钥
derive_reality_public_key() {
  local priv="$1"
  local pub=""

  # 私钥为空直接失败
  [ -z "$priv" ] && return 1

  # 1) 优先本地推导（openssl + xxd）
  if has_cmd xxd && has_cmd openssl; then
    debug_log "🔐 【调试】 derive_reality_public_key: 使用【本地推导】(openssl + xxd)"

    local tmp_dir="${HOME}/agsb/.tmp_reality"
    mkdir -p "$tmp_dir" 2>/dev/null

    # base64url -> base64 (字符集替换)
    local b64
    b64="$(printf '%s' "$priv" | tr '_-' '/+')"

    # base64 padding 补齐
    local mod=$(( ${#b64} % 4 ))
    if [ $mod -eq 2 ]; then
      b64="${b64}=="
    elif [ $mod -eq 3 ]; then
      b64="${b64}="
    elif [ $mod -eq 1 ]; then
      debug_log "❗ 【调试】 derive_reality_public_key: 私钥 base64 长度不合法（mod=1）"
      b64=""
    fi

    if [ -n "$b64" ]; then
      # 尝试多种 base64 decode 方式，兼容 BusyBox / GNU / BSD
      if echo "$b64" | base64 -d > "$tmp_dir/_x25519_priv_raw" 2>/dev/null; then
        :
      elif echo "$b64" | base64 -D > "$tmp_dir/_x25519_priv_raw" 2>/dev/null; then
        :
      elif echo "$b64" | openssl base64 -d -A > "$tmp_dir/_x25519_priv_raw" 2>/dev/null; then
        :
      else
        debug_log "❗ 【调试】 derive_reality_public_key: 本地解码失败（base64 -d/-D/openssl base64 均失败）"
        rm -f "$tmp_dir/_x25519_priv_raw" 2>/dev/null
      fi

      # 校验长度必须为 32 bytes
      if is_file_nonempty $tmp_dir/_x25519_priv_raw; then
        local priv_len
        priv_len="$(stat -c%s "$tmp_dir/_x25519_priv_raw" 2>/dev/null || stat -f%z "$tmp_dir/_x25519_priv_raw" 2>/dev/null || echo 0)"

        if [ "$priv_len" != "32" ]; then
          debug_log "❗ 【调试】 derive_reality_public_key: 本地解码后长度不为 32 bytes（实际=$priv_len）"
          rm -f "$tmp_dir/_x25519_priv_raw" 2>/dev/null
        else
          # PKCS#8 DER 前缀（X25519 固定头）
          local prefix_hex="302e020100300506032b656e04220420"
          local priv_hex
          priv_hex="$(xxd -p -c 256 "$tmp_dir/_x25519_priv_raw" 2>/dev/null | tr -d '\n')"

          if [ -n "$priv_hex" ]; then
            printf "%s%s" "$prefix_hex" "$priv_hex" | xxd -r -p > "$tmp_dir/_x25519_priv_der" 2>/dev/null || true

            if openssl pkcs8 -inform DER -in "$tmp_dir/_x25519_priv_der" -nocrypt -out "$tmp_dir/_x25519_priv_pem" 2>/dev/null \
              && openssl pkey -in "$tmp_dir/_x25519_priv_pem" -pubout -outform DER > "$tmp_dir/_x25519_pub_der" 2>/dev/null \
              && tail -c 32 "$tmp_dir/_x25519_pub_der" > "$tmp_dir/_x25519_pub_raw" 2>/dev/null; then

              # raw 公钥 -> base64url（无 padding）
              if has_cmd base64; then
                pub="$(base64 < "$tmp_dir/_x25519_pub_raw" 2>/dev/null | tr -d '\n' | tr '+/' '-_' | sed -E 's/=+$//')"
              elif has_cmd openssl; then
                pub="$(openssl base64 -A < "$tmp_dir/_x25519_pub_raw" 2>/dev/null | tr '+/' '-_' | sed -E 's/=+$//')"
              fi

              if [ -n "$pub" ]; then
                debug_log "✅ 【调试】 derive_reality_public_key: 本地推导成功"

                # 清理临时文件（可选）
                rm -f "$tmp_dir/_x25519_priv_raw" "$tmp_dir/_x25519_priv_der" "$tmp_dir/_x25519_priv_pem" \
                      "$tmp_dir/_x25519_pub_der" "$tmp_dir/_x25519_pub_raw" 2>/dev/null

                echo "$pub"
                return 0
              else
                debug_log "❗ 【调试】 derive_reality_public_key: 本地推导成功但编码公钥失败（缺少 base64 工具？）"
              fi
            else
              debug_log "❗ 【调试】 derive_reality_public_key: openssl 推导公钥失败（pkcs8/pkey/pubout）"
            fi
          else
            debug_log "❗ 【调试】 derive_reality_public_key: xxd 读取私钥失败"
          fi
        fi
      fi
    fi

    debug_log "❗ 【调试】 derive_reality_public_key: 本地推导失败，准备在线兜底"
  else
    debug_log "❗ 【调试】 derive_reality_public_key: 缺少 openssl 或 xxd，本地推导不可用"
  fi

  # 2) 在线兜底推导（curl/wget）
  debug_log "🌐 【调试】 derive_reality_public_key: 使用【在线推导】(realitykey.cloudflare.now.cc)"

  if has_cmd curl; then
    pub="$(curl -s --max-time 2 "https://realitykey.cloudflare.now.cc/?privateKey=${priv}" \
      | awk -F '"' '/publicKey/{print $4; exit}')"
  elif has_cmd wget; then
    pub="$(wget --no-check-certificate -qO- --tries=3 --timeout=2 "https://realitykey.cloudflare.now.cc/?privateKey=${priv}" \
      | awk -F '"' '/publicKey/{print $4; exit}')"
  else
    debug_log "❗ 【调试】 derive_reality_public_key: curl/wget 都不存在，在线推导不可用"
    return 1
  fi

  if [ -n "$pub" ]; then
    debug_log "✅ 【调试】 derive_reality_public_key: 在线推导成功"
    echo "$pub"
    return 0
  fi

  debug_log "❗ 【调试】 derive_reality_public_key: 在线推导失败（未获取到 publicKey）"
  return 1
}

# ================== Reality Keypair BEGIN ==================

# 打印 Reality Keypair
print_reality_keypair_hint() {
  [ "${1:-0}" = "1" ] || return 0
  [ -n "${reality_private:-}" ] || return 0

  echo
  yellow "🔐 Reality 私钥（请保存，后续可将此参数值放在安装参数里，可保持reality协议节点一致）"
  green "reality_private=${reality_private}"
  echo
}

# 初始化 Reality Keypair
init_reality_keypair() {
  local key_file="$AGSB_HOME/reality.key"
  local file_priv="" file_pub=""
  local env_priv="${reality_private:-}"
  local priv="" pub=""
  local print_reality_private=0

  debug_log "🔑 【调试】init_reality_keypair: 开始初始化 Reality Keypair..."
  debug_log "📌 【调试】init_reality_keypair: key_file=$key_file"

  # 读取文件中的 keypair（如果存在）
  if is_file $key_file; then
    file_priv="$(awk -F': ' '/PrivateKey/{print $2; exit}' "$key_file" 2>/dev/null)"
    file_pub="$(awk -F': ' '/PublicKey/{print $2; exit}' "$key_file" 2>/dev/null)"
    debug_log "📄 【调试】 init_reality_keypair: 检测到已有 reality.key（priv=${#file_priv} chars, pub=${#file_pub} chars）"
  else
    debug_log "📄 【调试】 init_reality_keypair: 未找到 reality.key（首次安装或文件丢失）"
  fi

  # A) 用户传入了 reality_private（最高优先级）
  if [ -n "$env_priv" ]; then
    debug_log "🧩 【调试】 init_reality_keypair: 使用环境变量 reality_private（优先级最高）"

    priv="$env_priv"

    # 如果文件里私钥与传入相同，则优先复用文件里的公钥（避免变化）
    if [ -n "$file_priv" ] && [ "$file_priv" = "$priv" ] && [ -n "$file_pub" ]; then
      pub="$file_pub"
      debug_log "✅ 【调试】 init_reality_keypair: 文件私钥与传入一致，复用文件公钥"
    else
      debug_log "🔄 【调试】 init_reality_keypair: 尝试由私钥推导公钥（derive_reality_public_key）"
      pub="$(derive_reality_public_key "$priv" 2>/dev/null)" || pub=""

      if [ -n "$pub" ]; then
        debug_log "✅ 【调试】 init_reality_keypair: 推导公钥成功（pub=${#pub} chars）"
      else
        debug_log "❗ 【调试】 init_reality_keypair: 推导公钥失败，将回退为生成新 keypair（这会覆盖 reality_private）"

        # 推导失败：生成一套新的 keypair（回退）
        local kp
        kp="$("$AGSB_HOME/sing-box" generate reality-keypair 2>/dev/null)"
        priv="$(awk '/PrivateKey/{print $NF; exit}' <<< "$kp")"
        pub="$(awk '/PublicKey/{print $NF; exit}' <<< "$kp")"

        if [ -z "$priv" ] || [ -z "$pub" ]; then
          debug_log "❗ 【调试】 init_reality_keypair: 生成 keypair 失败（sing-box generate reality-keypair 无输出）"
          return 1
        fi

        print_reality_private=1
        debug_log "✅ 【调试】 init_reality_keypair: 已生成新的 Reality Keypair（priv/pub 均已获得）"
      fi
    fi

  # B) 没传私钥，但文件里有 → 直接复用（稳定）
  elif [ -n "$file_priv" ] && [ -n "$file_pub" ]; then
    debug_log "♻️ 【调试】 init_reality_keypair: 未传入 reality_private，复用 reality.key 中的 keypair（稳定模式）"

    export reality_private="$file_priv"
    export reality_public="$file_pub"

    debug_log "✅ 【调试】 init_reality_keypair: 复用成功（priv=${#file_priv} chars, pub=${#file_pub} chars）"
    return 0

  # C) 既没传私钥，文件也没有 → 首次生成
  else
    debug_log "🆕 【调试】 init_reality_keypair: 无传入私钥且无本地文件，生成新的 Reality Keypair"

    local kp
    kp="$("$AGSB_HOME/sing-box" generate reality-keypair 2>/dev/null)"
    priv="$(awk '/PrivateKey/{print $NF; exit}' <<< "$kp")"
    pub="$(awk '/PublicKey/{print $NF; exit}' <<< "$kp")"

    if [ -z "$priv" ] || [ -z "$pub" ]; then
      debug_log "❗ 【调试】 init_reality_keypair: 生成 keypair 失败（sing-box generate reality-keypair 无输出）"
      return 1
    fi

    print_reality_private=1
    debug_log "✅ 【调试】 init_reality_keypair: 首次生成成功（priv/pub 均已获得）"
  fi

  # 写入 reality.key（统一落盘）
  mkdir -p "$(dirname "$key_file")" 2>/dev/null
  printf "PrivateKey: %s\nPublicKey: %s\n" "$priv" "$pub" > "$key_file" 2>/dev/null
  chmod 600 "$key_file" 2>/dev/null

  # 导出环境变量（给后续生成配置用）
  export reality_private="$priv"
  export reality_public="$pub"

  debug_log "💾 【调试】 init_reality_keypair: 已写入 $key_file（chmod 600）"
  debug_log "✅ 【调试】 init_reality_keypair: 完成（priv=${#priv} chars, pub=${#pub} chars）"

  # 仅在“新生成私钥”时提示用户保存（避免每次刷屏）
  print_reality_keypair_hint "$print_reality_private"

  return 0
}

# ================== Reality Keypair END ==================

# ================== TLS Self-signed Cert Helper ==================
# 生成自签证书（用于 hy2/tuic），证书的 CN 与 SNI 解耦：
# - 服务端不强制 server_name
# - 客户端可自由改 sni（一般配合 allow_insecure=1）
gen_self_signed_cert() {
  # 用法：gen_self_signed_cert <key_path> <cert_path> <cn> <days>
  local key_path="$1"
  local cert_path="$2"
  local cn="$3"
  local days="${4:-3650}"

  # 已存在就不重复生成（避免 rep 覆盖后证书频繁变化）
  if is_file_nonempty $key_path && is_file_nonempty $cert_path; then
    return 0
  fi

  mkdir -p "$(dirname "$key_path")" 2>/dev/null
  # P-256 证书即可
  openssl ecparam -genkey -name prime256v1 -out "$key_path" >/dev/null 2>&1 || return 1

  # 优先带 SAN（部分客户端只认 SAN 不认 CN）
  if openssl req -new -x509 -days "$days" -key "$key_path" -out "$cert_path"       -subj "/CN=${cn}" -addext "subjectAltName=DNS:${cn}" >/dev/null 2>&1; then
    :
  else
    # 兼容旧 openssl：无 -addext 时回退
    openssl req -new -x509 -days "$days" -key "$key_path" -out "$cert_path"       -subj "/CN=${cn}" >/dev/null 2>&1 || return 1
  fi

  return 0
}

# Install and configure Sing-box
installsb(){
    echo; 
    echo "=========开始下载/安装Sing-box内核========="

    if [ ! -e "$AGSB_HOME/sing-box" ]; then 
        dlog "installsb：Sing-box 不存在，开始下载/安装"
        upsingbox; 
    fi

    cat > "$AGSB_HOME/sb.json" <<EOF
{"log": { "disabled": false, "level": "info", "timestamp": true },
"inbounds": [
EOF
    insuuid
    write2AgsbFolders

   # Generate a self-signed cert for hy2（CN 与 hy_sni 解耦）
    gen_self_signed_cert "$AGSB_HOME/private.key" "$AGSB_HOME/cert.pem" "${CN_BING}" 36500

    # 添加tuic协议
    if [ -n "$tup" ]; then
        port_tu=$(get_protocol_port "$port_tu" "port_tu")
        add_tuic_protocol "$port_tu" "$uuid"
    fi

    # 添加hy2协议
    if [ -n "$hyp" ]; then
        port_hy2=$(get_protocol_port "$port_hy2" "port_hy2")
        add_hy2_protocol "$port_hy2" "$uuid"
    fi
    
    # 添加trojan协议
    if [ -n "$trp" ]; then
        port_tr=$(get_protocol_port "$port_tr" "port_tr")
        add_trojan_protocol "$port_tr" "$uuid"
    fi

   # 添加vmess协议
    if [ -n "$vmp" ]; then
        port_vm_ws=$(get_protocol_port "$port_vm_ws" "port_vm_ws")
        add_vmess_protocol "$port_vm_ws" "$uuid"
    fi
    # 添加vless-reality-vision协议
    if [ -n "$vlr" ]; then
        port_vlr=$(get_protocol_port "$port_vlr" "port_vlr")
        add_vless_reality_protocol "$port_vlr" "$uuid" "$vl_sni" "$vl_sni_pt"
    fi
}

# ================== Phase 21: 协议配置优化 ==================
# 通用的端口获取或生成函数
get_protocol_port() {
  local port_var="$1"
  local port_file="$2"
  
  if [ -n "$port_var" ]; then
    write_agsb_file "$port_file" "$port_var"
    echo "$port_var"
  elif is_file_nonempty "$AGSB_HOME/$port_file"; then
    cat "$AGSB_HOME/$port_file"
  else
    local new_port=$(rand_port)
    write_agsb_file "$port_file" "$new_port"
    echo "$new_port"
  fi
}

# 添加TUIC协议配置
add_tuic_protocol() {
  local port_tu="$1"
  local uuid="$2"
  
  yellow "Tuic端口：$port_tu"
  cat >> "$AGSB_HOME/sb.json" <<EOF
{"type": "tuic", "tag": "tuic-sb", "listen": "::", "listen_port": ${port_tu}, "users": [ {  "uuid": "$uuid", "password": "$uuid" } ],"congestion_control": "bbr", "tls": { "enabled": true,"alpn": ["h3"], "certificate_path": "$AGSB_HOME/cert.pem", "key_path": "$AGSB_HOME/private.key" }},
EOF
}

# 添加Hysteria2协议配置
add_hy2_protocol() {
  local port_hy2="$1"
  local uuid="$2"
  
  yellow "Hysteria2端口：$port_hy2"
  cat >> "$AGSB_HOME/sb.json" <<EOF
{"type": "hysteria2", "tag": "hy2-sb", "listen": "::", "listen_port": ${port_hy2},"users": [ { "password": "${uuid}" } ],"tls": { "enabled": true, "alpn": ["h3"], "certificate_path": "$AGSB_HOME/cert.pem", "key_path": "$AGSB_HOME/private.key" }},
EOF
}

# 添加Trojan协议配置
add_trojan_protocol() {
  local port_tr="$1"
  local uuid="$2"
  
  yellow "Trojan端口(Argo本地使用)：$port_tr"
  cat >> "$AGSB_HOME/sb.json" <<EOF
{"type": "trojan", "tag": "trojan-ws-sb", "listen": "::", "listen_port": ${port_tr},"users": [ { "password": "${uuid}" } ],"transport": { "type": "ws", "path": "/${uuid}-tr" }},
EOF
}

# 添加Vmess协议配置
add_vmess_protocol() {
  local port_vm_ws="$1"
  local uuid="$2"
  
  yellow "Vmess-ws端口 (Argo本地使用)：$port_vm_ws"
  cat >> "$AGSB_HOME/sb.json" <<EOF
{"type": "vmess", "tag": "vmess-sb", "listen": "::", "listen_port": ${port_vm_ws},"users": [ { "uuid": "${uuid}", "alterId": 0 } ],"transport": { "type": "ws", "path": "/${uuid}-vm" }},
EOF
}

# 添加VLESS-Reality-Vision协议配置
add_vless_reality_protocol() {
  local port_vlr="$1"
  local uuid="$2"
  local vl_sni="$3"
  local vl_sni_pt="$4"
  
  yellow "VLESS-Reality-Vision端口：$port_vlr"
  
  if [ ! -f "$AGSB_HOME/reality.key" ]; then 
    "$AGSB_HOME/sing-box" generate reality-keypair > "$AGSB_HOME/reality.key"
  fi
  
  init_reality_keypair
  local private_key="${reality_private}"
  local short_id="$(get_short_id "$AGSB_HOME/short_id")"
  
  cat >> "$AGSB_HOME/sb.json" <<EOF
{"type": "vless", "tag": "vless-reality-vision-sb", "listen": "::", "listen_port": ${port_vlr},"sniff": true,"users": [{"uuid": "${uuid}","flow": "xtls-rprx-vision"}],"tls": {"enabled": true,"server_name": "${vl_sni}","reality": {"enabled": true,"handshake": {"server": "${vl_sni}","server_port": ${vl_sni_pt}},"private_key": "${private_key}","short_id": ["${short_id}"]}}},
EOF
}

# ================== Phase 21: 协议配置优化 END ==================

#  Generate Sing-box configuration file
sbbout(){
    if [ -e "$AGSB_HOME/sb.json" ]; then
        sed -i '$ s/,[[:space:]]*$//' "$AGSB_HOME/sb.json"

        cat >> "$AGSB_HOME/sb.json" <<EOF
],
"outbounds": [ { "type": "direct", "tag": "direct" }, { "type": "block", "tag": "block" } ],
"route": { "rules": [ { "action": "sniff" }, { "action": "resolve", "strategy": "${sbyx}" } ], "final": "direct" }
}
EOF
        if has_systemd && [ "$EUID" -eq 0 ]; then
            dlog "sbbout：使用 systemd 管理/启动 sb 服务"
            cat > $SYSTEMD_DIR/sb.service <<EOF
[Unit]
Description=sb service
After=network.target
[Service]
Type=simple
NoNewPrivileges=yes
ExecStart=$AGSB_HOME/sing-box run -c $AGSB_HOME/sb.json
Restart=on-failure
RestartSec=5s
[Install]
WantedBy=multi-user.target
EOF
            systemctl daemon-reload; 
            systemctl enable sb; 
            systemctl start sb
            echo ""
            green "✅ sb 服务已启动,并开启开机自启服务（systemd）"
        elif has_cmd rc-service && [ "$EUID" -eq 0 ]; then
            dlog "sbbout：使用 openrc 管理/启动 sb 服务"
            cat > $INITD_DIR/sing-box <<EOF
#!/sbin/openrc-run
description="sb service"
command="$AGSB_HOME/sing-box"
command_args="run -c $AGSB_HOME/sb.json"
command_background=yes
pidfile="/run/sing-box.pid"
depend() { need net; }
EOF
            chmod +x $INITD_DIR/sing-box;
            rc-update add sing-box default;
            rc-service sing-box start
            echo "" 
            green "✅ sb 服务已启动,并开启开机自启服务（openrc）"
        else
            dlog "sbbout：使用 nohup 模式运行 sb 服务"
            nohup "$AGSB_HOME/sing-box" run -c "$AGSB_HOME/sb.json" >/dev/null 2>&1 &
            echo ""
            green "✅  sb 服务已启动, 使用 nohup 模式运行"
        fi
    fi
}

# ================== Nginx 订阅服务 ==================
# Nginx 配置文件路径
nginx_conf_path() {
    # Alpine
    if [ -d /etc/nginx/http.d ]; then
        echo "/etc/nginx/http.d/agsb.conf"
    else
        echo "/etc/nginx/conf.d/agsb.conf"
    fi
}

setup_nginx_subscribe() {
  local port="${nginx_pt:-$NGINX_DEFAULT_PORT}"
  local argo_port="${argo_pt:-$ARGO_DEFAULT_PORT}"
  write_agsb_file "nginx_port" "$port"

    # ✅端口相同会导致 nginx listen 冲突
    if [ "$port" = "$argo_port" ]; then
        red "❌ nginx_pt($port) 和 argo_pt($argo_port) 不能相同，否则 Nginx 监听冲突"
        return 1
    fi
  
  local webroot="$AGSB_WEBROOT"
  mkdir -p "$webroot"
  chmod 755 /var /var/www $AGSB_WEBROOT 2>/dev/null

  local vm_port tr_port uuid
  uuid="$(cat "$AGSB_HOME/uuid" 2>/dev/null)"
  vm_port="$(cat "$AGSB_HOME/port_vm_ws" 2>/dev/null)"
  tr_port="$(cat "$AGSB_HOME/port_tr" 2>/dev/null)"

  local conf
  conf="$(nginx_conf_path)"
  mkdir -p "$(dirname "$conf")" >/dev/null 2>&1

  cat > "$conf" <<EOF
server {
    listen ${port};
    listen 127.0.0.1:${argo_port};
    server_name _;
EOF

  # ✅ 订阅仅在 subscribe=true 才开放
  if is_true "$(get_subscribe_flag)" && [ -n "$uuid" ]; then
    cat >> "$conf" <<EOF

    # 订阅输出（base64）
    location ^~ /sub/${uuid} {
        default_type text/plain;
        alias $AGSB_WEBROOT/sub.txt;
        add_header Cache-Control "no-store";
    }
EOF
    # 确保订阅文件存在（只在开启订阅时需要）
    is_file $webroot/sub.txt || : > "$webroot/sub.txt"
  fi

  cat >> "$conf" <<EOF

    # --------- ws 反代（固定 Argo 同域名下可代理节点） ---------
EOF

  if [ -n "$vm_port" ] && [ -n "$uuid" ]; then
    cat >> "$conf" <<EOF
    location /${uuid}-vm {
        proxy_pass http://127.0.0.1:${vm_port};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }

EOF
  fi

  if [ -n "$tr_port" ] && [ -n "$uuid" ]; then
    cat >> "$conf" <<EOF
    location /${uuid}-tr {
        proxy_pass http://127.0.0.1:${tr_port};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }

EOF
  fi

  cat >> "$conf" <<EOF
    location / {
        return 404;
    }
}
EOF

  nginx -t >/dev/null 2>&1 || {
    red "❌ Nginx 配置检查失败，请运行 nginx -t 查看原因"
    nginx -t
    return 1
  }
 
}

# 启动 Nginx 服务
start_nginx_service() {
  dlog "start_nginx_service：开始启动 Nginx 服务"
    # systemd
    if has_systemd; then
        dlog "start_nginx_service：使用 systemd 管理 Nginx 服务"
        systemctl enable nginx >/dev/null 2>&1
        service_op restart nginx || service_op start nginx
        echo ""
        green "✅ Nginx 服务已启动,并开启开机自启服务（systemd）"
        return 0
    fi

    # openrc
    if has_cmd rc-service; then
        dlog "start_nginx_service：使用 openrc 管理 Nginx 服务"
        rc-update add nginx default >/dev/null 2>&1
        service_op restart nginx || service_op start nginx
        echo ""
        green "✅ Nginx 服务已启动,并开启开机自启服务（openrc）"
        return 0
    fi

    dlog "start_nginx_service：使用 nohup 模式运行 Nginx 服务"
    # no init
    pkill -15 nginx >/dev/null 2>&1
    nohup nginx >/dev/null 2>&1 &
    echo ""
    green "✅ Nginx 服务已启动, 使用 nohup 模式运行"
    return 0
}

nginx_start() {
    start_nginx_service
}

nginx_stop() {
  dlog "nginx_stop：开始停止 Nginx 服务"
    # systemd
    if has_systemd; then
        dlog "nginx_stop：使用 systemd 管理 Nginx 服务"
        service_op stop nginx
        return 0
    fi

    # openrc
    if has_cmd rc-service; then
        dlog "nginx_stop：使用 openrc 管理 Nginx 服务"
        service_op stop nginx
        return 0
    fi

    # no init：直接杀进程
    pkill -15 -x nginx >/dev/null 2>&1
    dlog "nginx_stop： Nginx 服务已停止"
    return 0
}

# 重启 Nginx 服务
nginx_restart() {
  dlog "nginx_restart：开始重启 Nginx 服务"
    # systemd
    if has_systemd; then
        dlog "nginx_restart：使用 systemd 管理 Nginx 服务"
        service_op restart nginx || service_op start nginx
    log_success "Nginx 服务已重启"
        green "✅ Nginx 服务已重启"
        return 0
    fi

    # openrc
    if has_cmd rc-service; then
        dlog "nginx_restart：使用 openrc 管理 Nginx 服务"
        service_op restart nginx || service_op start nginx
    log_success "Nginx 服务已重启"
        green "✅ Nginx 服务已重启"
        return 0
    fi

    dlog "nginx_restart：使用 nohup 模式运行 Nginx 服务"
    # no init：优先 reload，不行就 stop+start
    if has_cmd nginx; then
        dlog "nginx_restart：使用 nohup 模式运行 Nginx 服务，尝试 reload"
        nginx -s reload >/dev/null 2>&1 && return 0
    fi

    dlog "nginx_restart：使用 nohup 模式运行 Nginx 服务，尝试 stop+start"
    nginx_stop
    nginx_start
}

# 检查 Nginx 状态
nginx_status() {
    if pgrep -x nginx >/dev/null 2>&1; then
        echo "Nginx：$(green "运行中")"
    elif rc-service nginx status >/dev/null 2>&1; then
        echo "Nginx：$(green "运行中 (OpenRC)")"
    else
        echo "Nginx：$(red "未运行")"
    fi
}

# 确保 cloudflared 如果需要
ensure_cloudflared_if_needed() {
  # ✅ 仅当启用 argo=vmpt/trpt 且 vmag 存在时才需要 cloudflared
  dlog "ensure_cloudflared_if_needed：检查是否需要 cloudflared"
  if { [ "${argo:-}" != "vmpt" ] && [ "${argo:-}" != "trpt" ]; } || [ -z "${vmag:-}" ]; then
    dlog "ensure_cloudflared_if_needed：未启用 Argo（或未启用 vmess/trojan），跳过 cloudflared 下载/安装"
    purple "ℹ️ 未启用 Argo（或未启用 vmess/trojan），跳过 cloudflared 下载/安装"
    return 0
  fi
  dlog "ensure_cloudflared_if_needed：需要 cloudflared，开始下载/安装"
  ensure_cloudflared || return 1
  return 0
}

# 确保 cloudflared
ensure_cloudflared() {
  dlog "ensure_cloudflared：开始下载/安装 cloudflared"
  # 已存在就不重复下载
  if is_executable $AGSB_HOME/cloudflared; then
    return 0
  fi

  dlog "ensure_cloudflared：检查 cloudflared 是否已存在"
  yellow "下载 Cloudflared Argo 内核中…"
  local url out

  # 下面为备用链接，里面的版本为2025.11.1，当有latest问题在切回我的仓库去
  # url="https://github.com/jyucoeng/singbox-tools/releases/download/cloudflared/cloudflared-linux-$cpu";

  url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$cpu"
  out="$AGSB_HOME/cloudflared"

  dlog "ensure_cloudflared：下载 cloudflared 二进制文件，保存路径 $out"

  (curl -Lo "$out" -# --connect-timeout 5 --max-time 120 \
    --retry 2 --retry-delay 2 --retry-all-errors "$url") \
  || (wget -O "$out" --tries=2 --timeout=60 --dns-timeout=5 --read-timeout=60 "$url")

  dlog "ensure_cloudflared：检查 cloudflared 二进制文件是否下载成功"
  if [ ! -s "$out" ]; then
    dlog "ensure_cloudflared：下载失败：文件为空"
    red "❌ 下载失败：文件为空 $out"
    return 1
  fi

  dlog "ensure_cloudflared：设置 cloudflared 二进制文件权限"
  chmod +x "$out" || return 1

  dlog "ensure_cloudflared：cloudflared 二进制文件权限设置成功"
  return 0
}

# 安装 Argo 服务（systemd）
install_argo_service_systemd() {
    local mode="$1" # json|token
    local token="$2"

     # 检查 systemd 是否存在
    if ! has_cmd systemctl; then
        red "系统未检测到 systemd，跳过 systemd 服务安装！"
        return
    fi

    if [ "$mode" = "json" ]; then
        dlog "使用 json 模式安装 argo 服务(systemd)"

        cat > $SYSTEMD_DIR/argo.service <<EOF
[Unit]
Description=argo service
After=network.target

[Service]
Type=simple
NoNewPrivileges=yes
ExecStart=$AGSB_HOME/cloudflared tunnel --edge-ip-version auto --config $AGSB_HOME/tunnel.yml run
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    else
        dlog "使用 token 模式安装 argo 服务(systemd)"

        cat > $SYSTEMD_DIR/argo.service <<EOF
[Unit]
Description=argo service
After=network.target

[Service]
Type=simple
NoNewPrivileges=yes
ExecStart=$AGSB_HOME/cloudflared tunnel --no-autoupdate --edge-ip-version auto run --token ${token}
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    fi

    systemctl daemon-reload
    systemctl enable argo
    systemctl start argo
    echo ""
    green "✅ Argo 服务已启动并成功设置开机自启动（systemd）"
}

# 安装 Argo 服务（openrc）
install_argo_service_openrc() {
    local mode="$1" # json|token
    local token="$2"

      # 检查 openrc 是否存在
    if ! has_cmd rc-service; then
        red "系统未检测到 openrc，跳过 openrc 服务安装！"
        return
    fi

    local command_path="$AGSB_HOME/cloudflared"
    local args=""

    if [ "$mode" = "json" ]; then
        dlog "使用 json 模式安装 argo 服务(openrc)"
        args="tunnel --edge-ip-version auto --config $AGSB_HOME/tunnel.yml run"
    else
        dlog "使用 token 模式安装 argo 服务(openrc)"
        args="tunnel --no-autoupdate --edge-ip-version auto run --token ${token}"
    fi

    cat > $INITD_DIR/argo <<EOF
#!/sbin/openrc-run
description="argo service"
command="${command_path}"
command_args="${args}"
command_background=yes
pidfile="/run/argo.pid"
depend() { need net; }
EOF

    chmod +x $INITD_DIR/argo
    rc-update add argo default
    rc-service argo start
    green "✅ Argo 服务已成功安装并启动（openrc）"
}

# 无守护进程启动 Argo
start_argo_no_daemon() {
    local mode="$1"
    local token="$2"
    local port="$3"

    if [ "$mode" = "json" ]; then
        dlog "使用 json 模式，nohup 启动 argo"
        nohup "$AGSB_HOME/cloudflared" tunnel \
          --edge-ip-version auto \
          --config "$AGSB_HOME/tunnel.yml" run \
          > "$AGSB_HOME/argo.log" 2>&1 &
    elif [ -n "$token" ]; then
        dlog "使用 token 模式，nohup 启动 argo"
        nohup "$AGSB_HOME/cloudflared" tunnel \
          --no-autoupdate \
          --edge-ip-version auto run \
          --token "$token" \
          > "$AGSB_HOME/argo.log" 2>&1 &
    else
        dlog "使用 URL 模式，nohup 启动 argo"
        nohup "$AGSB_HOME/cloudflared" tunnel \
          --url "http://localhost:${port}" \
          --edge-ip-version auto \
          --no-autoupdate \
          > "$AGSB_HOME/argo.log" 2>&1 &
    fi
}

# 等待并检查 Argo
wait_and_check_argo() {
  local argo_tunnel_type="${1:-临时}"  # 第一个参数：隧道类型（固定/临时）
  local argo_log="$AGSB_HOME/argo.log"
  local ym_log="$AGSB_HOME/sbargoym.log"
  local argodomain=""
  local i=0
  local max_wait=5

  # ✅ 没启用 argo：直接跳过
  if ! need_argo; then
    purple "ℹ️ 未启用 Argo，跳过 Argo 域名检查"
    return 0
  fi

  # ✅ 规范化隧道类型
  case "$argo_tunnel_type" in
    固定|fixed|FIXED) argo_tunnel_type="固定" ;;
    临时|temp|temporary|"") argo_tunnel_type="临时" ;;
    *)
      yellow "❗ 未知隧道类型：$argo_tunnel_type，按【临时】处理" >&2
      argo_tunnel_type="临时"
      ;;
  esac

  # ✅ 固定 Argo：域名只允许来自 ARGO_DOMAIN 或 sbargoym.log
  if [ "$argo_tunnel_type" = "固定" ]; then
    if [ -n "${ARGO_DOMAIN}" ]; then
      argodomain="${ARGO_DOMAIN}"
    elif is_file_nonempty $ym_log; then
      argodomain="$(tail -n1 "$ym_log" 2>/dev/null | tr -d '\r\n')"
    fi

    # 简单校验：必须像域名（含点号）
    if [ -n "$argodomain" ] && echo "$argodomain" | grep -q '\.'; then
      export ARGO_DOMAIN="$argodomain"
      echo "$ARGO_DOMAIN" > "$ym_log" 2>/dev/null
      purple "✅ 固定 Argo 域名：$ARGO_DOMAIN"
      return 0
    fi

    red "❌ 固定 Argo 模式未获取到域名，请设置 ARGO_DOMAIN 或写入 $ym_log"
    return 1
  fi

  # ✅ 临时 Argo：从 argo.log 提取 *.trycloudflare.com
  yellow "⏳ 正在等待临时 Argo 域名生成（trycloudflare.com）..."
  while [ "$i" -lt "$max_wait" ]; do
    if is_file_nonempty $argo_log; then
      argodomain="$(grep -aoE '[a-zA-Z0-9.-]+\.trycloudflare\.com' "$argo_log" 2>/dev/null | tail -n1)"
      if [ -n "$argodomain" ]; then
        export ARGO_DOMAIN="$argodomain"
        echo "$ARGO_DOMAIN" > "$ym_log" 2>/dev/null
        green "✅ 临时 Argo 域名：$ARGO_DOMAIN"
        return 0
      fi
    fi
    sleep 1
    i=$((i + 1))
  done

  red "❌ 未能获取临时 Argo 域名（$argo_log 未生成或 cloudflared 未启动成功）"
  return 1
}

# 开机自启argo
append_argo_cron_legacy() {
    # 只在启用了 argo + vmag 的情况下处理
    if ! need_argo || [ -z "$vmag" ]; then
        return
    fi

    # systemd 永远不写 cron ✅
    # openrc 只有 root 能装服务时才不写 cron ✅
    # 非 root 的 openrc 环境会写 cron ✅

   if has_systemd && [ "$EUID" -eq 0 ]; then
        return
   fi

    # 固定 Argo（token / JSON）
    if [ -n "${ARGO_DOMAIN}" ] && [ -n "${ARGO_AUTH}" ]; then
        if [ "$ARGO_MODE" = "json" ]; then
            echo '@reboot sleep 10 && nohup $AGSB_HOME/cloudflared tunnel --edge-ip-version auto --config $AGSB_HOME/tunnel.yml run >/dev/null 2>&1 &' \
                >> $TMP_DIR/crontab.tmp
        else
            echo '@reboot sleep 10 && nohup $AGSB_HOME/cloudflared tunnel --no-autoupdate --edge-ip-version auto run --token $(cat $AGSB_HOME/sbargotoken.log) >/dev/null 2>&1 &' \
                >> $TMP_DIR/crontab.tmp
        fi

    # 临时 Argo
    else
        echo '@reboot sleep 10 && nohup $AGSB_HOME/cloudflared tunnel --url http://localhost:$(cat $AGSB_HOME/argoport.log) --edge-ip-version auto --no-autoupdate > $AGSB_HOME/argo.log 2>&1 &' \
            >> $TMP_DIR/crontab.tmp
    fi
}

# _legacy 后安装收尾
post_install_finalize_legacy() {
  # 用“最多等待 10 秒 + 检测到就立刻继续”替代固定 sleep
  for i in 1 2 3 4 5 6 7 8 9 10; do
    if is_agsb_running; then
      break
    fi
    sleep 1
  done
  echo

  # 只要 sing-box 或 cloudflared 进程存在，认为安装启动成功
  if is_agsb_running; then
    white "✅ 安装完成：已检测到 sing-box/cloudflared 正在运行"
    return 0
  fi

  red "❌ 未检测到 sing-box/cloudflared 运行，安装可能未成功"
  return 1
}

# 确保 Nginx 如果需要
ensure_nginx_if_needed() {
  # ✅ 需要 Nginx 的条件：
  # 1) 订阅开启 subscribe=true
  # 2) 启用 argo（vmpt/trpt）
  local need_nginx=false

  if is_true "$(get_subscribe_flag)"; then
    need_nginx=true
  fi

  if need_argo; then
    need_nginx=true
  fi

  # ✅ 不需要 nginx：既不安装，也不启动
  if ! $need_nginx; then
    purple "ℹ️ subscribe 未开启且未启用 Argo，跳过 Nginx 安装/配置/启动"
    return 0
  fi

  # ✅ 需要 nginx：先按需安装
  install_nginx_pkg || {
    red "❌ Nginx 安装失败"
    return 1
  }

  # ✅ 需要 nginx：生成配置（你原来的逻辑）
  setup_nginx_subscribe || return 1

  # ✅ 只有订阅开启时才清空/准备 sub.txt
  if is_true "$(get_subscribe_flag)"; then
    : > $AGSB_WEBROOT/sub.txt
  fi

  # ✅ 启动 nginx
  start_nginx_service
  return 0
}

 # 2) 工具函数：去掉所有外层 []（支持 [[v6]] 这种奇葩情况），并去空白/换行
  strip_ip_brackets_all() {
    local s="${1:-}"
    s="$(printf '%s' "$s" | tr -d ' \t\r\n')"
    # 反复剥离最外层 []
    while [ -n "$s" ] && [ "${s#\[}" != "$s" ] && [ "${s%\]}" != "$s" ]; do
      s="${s#[}"
      s="${s%]}"
      s="$(printf '%s' "$s" | tr -d ' \t\r\n')"
    done
    printf '%s' "$s"
  }

  #工具函数：判断 IP 合法（宽松 IPv6：含冒号并符合基本十六进制/冒号结构）
is_valid_ip_simple() {
  local ip
  ip="$(strip_ip_brackets_all "${1:-}")"  # 去除 IP 地址中的中括号（如果有）
  
  # 检查 IP 是否为空
  [ -n "$ip" ] || return 1  # 如果为空，返回无效（1）

  # 检查是否为 IPv4 地址
  if echo "$ip" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
    # 如果是 IPv4 地址格式（如 192.168.0.1）
    return 0  # 返回有效（0）
  fi

  # 检查是否为 IPv6 地址（支持压缩格式 ::）
  # 以下的正则表达式支持：
  # - 完整 IPv6 地址（如：2001:0db8:0000:0042:0000:8a2e:0370:7334）
  # - 压缩格式 IPv6 地址（如：2001:db8::ff00:42:8329 或 ::）
  if echo "$ip" | grep -qE '^([a-fA-F0-9]{1,4}:){7}[a-fA-F0-9]{1,4}$' || \
     echo "$ip" | grep -qE '^([a-fA-F0-9]{1,4}:){1,7}:$' || \
     echo "$ip" | grep -qE '^([a-fA-F0-9]{1,4}:){0,6}:([a-fA-F0-9]{1,4}:){1,6}$' || \
     echo "$ip" | grep -qE '^::([a-fA-F0-9]{1,4}:){1,7}[a-fA-F0-9]{1,4}$' || \
     [ "$ip" == "::" ]; then
    # 检查是否为有效的 IPv6 地址
    # - 匹配常规 IPv6 格式：xxxx:xxxx:xxxx:xxxx:xxxx:xxxx:xxxx:xxxx
    # - 匹配压缩格式 IPv6 地址：xxxx::xxxx:xxxx 或 ::
    return 0  # 返回有效（0）
  fi

  return 1  # 如果都不匹配，返回无效（1）
}

  # 4) 工具函数：输出写入 server_ip.log 的最终形式（IPv6 自动加 []）
  format_ip_for_log() {
    local ip
    ip="$(strip_ip_brackets_all "${1:-}")"
    [ -n "$ip" ] || return 1
    if echo "$ip" | grep -q ':'; then
      printf '[%s]' "$ip"
    else
      printf '%s' "$ip"
    fi
  }

# 写入服务器 IP（IPv6 自动加 []，根据ipzz参数来决定写入哪一个ip，当有out_ip时，优先写入out_ip）
write_server_ip() {
  # 1) 读取偏好：优先用传参，其次 ipzz，再其次 ippz（兼容你现在脚本变量名）
  local ipzz_local="${1:-${ipzz:-${ippz:-}}}"

  dlog "pick_server_ip_for_install：ipzz_local=$ipzz_local"
 
  # 5) 拿到本机 v4 / v6（复制 ipchange 的“check + 拆分”核心逻辑，不调用 ipchange）
  local v4v6_result v4_local v6_local
  v4v6_result="$(check_ip_connectivity "$v46url")"
  dlog "check_ip_connectivity：v4v6_result=$v4v6_result"

  # 兼容输出里有换行/多空格：压成一行再拆
  IFS='|' read -r v4_local v6_local <<EOF
$(printf '%s' "$v4v6_result" | tr -d '\r\n')
EOF
  v4_local="${v4_local:-}"
  v6_local="${v6_local:-}"

  dlog "pick_server_ip_for_install：v4_local=$v4_local，v6_local=$v6_local"

  # 6) 根据 ipzz/ippz 选择 prefer_ip -> server_ip（先不加括号，统一用“裸 IP”比较）
  local prefer_ip server_ip
  case "$ipzz_local" in
    4) prefer_ip="$v4_local" ;;
    6) prefer_ip="$v6_local" ;;
    *) prefer_ip="" ;;
  esac

  dlog "pick_server_ip_for_install：prefer_ip=$prefer_ip"  
 
 # 去掉乱七八糟的中括号
  server_ip="$(strip_ip_brackets_all "$prefer_ip")"

  dlog "pick_server_ip_for_install：去除乱七八糟的中括号后,server_ip=$server_ip"

  # 7) 若 prefer_ip 为空/不合法：兜底抓公网（先 v4 再 v6，2 秒超时，wget 重试 2 次）
  if [ -z "$server_ip" ] || ! is_valid_ip_simple "$server_ip"; then
    dlog "pick_server_ip_for_install：prefer_ip 为空或不合法，开始兜底抓公网"
    local serip_raw
    serip_raw="$(
      (curl -s4m2 -k "$v46url" 2>/dev/null) || (wget -4 -qO- --timeout=2 --tries=2 "$v46url" 2>/dev/null)
    )"
    dlog "pick_server_ip_for_install函数：由于prefer_ip 为空或不合法，开始兜底抓公网ipv4,serip_raw=$serip_raw"
    if [ -z "$serip_raw" ]; then
     dlog "pick_server_ip_for_install函数：由于prefer_ip 为空或不合法，开始兜底抓公网ipv4,ipv4 为空，开始抓ipv6……"
      serip_raw="$(
        (curl -s6m2 -k "$v46url" 2>/dev/null) || (wget -6 -qO- --timeout=2 --tries=2 "$v46url" 2>/dev/null)
      )"
      dlog "pick_server_ip_for_install函数：由于prefer_ip 为空或不合法，抓公网ipv6结束,serip_raw=$serip_raw"
    fi
    server_ip="$(strip_ip_brackets_all "$serip_raw")"
    dlog "pick_server_ip_for_install：最终抓取的公网IP,server_ip=$server_ip"
  fi

  dlog "pick_server_ip_for_install：开始对比out_ip与server_ip，out_ip=$out_ip，server_ip=$server_ip"

  # 8) 处理 out_ip：去括号后再比较；若 out_ip 合法且与 server_ip 不同，则 out_ip 覆盖server_ip的值
  local out_norm
  out_norm="$(strip_ip_brackets_all "${out_ip:-}")"
  if is_valid_ip_simple "$out_norm" && [ -n "$out_norm" ]; then
    dlog "pick_server_ip_for_install：out_ip经过处理格式后，out_norm=$out_norm"
    if [ -z "$server_ip" ] || ! is_valid_ip_simple "$server_ip" || [ "$out_norm" != "$(strip_ip_brackets_all "$server_ip")" ]; then
      dlog "pick_server_ip_for_install：out_ip合法且与server_ip不同，out_norm=$out_norm，server_ip=$server_ip"
      server_ip="$out_norm"
    fi
  fi

  dlog "pick_server_ip_for_install：最终选择的服务器IP，server_ip=$server_ip"
  # 9) 最终写入：IPv6 加 []，写入 $AGSB_HOME/server_ip.log
  ensure_dir "$AGSB_HOME"

  local ip_final
  ip_final="$(format_ip_for_log "$server_ip" 2>/dev/null || true)"
  dlog "pick_server_ip_for_install：最终写入的IP文件形式，ip_final=$ip_final"
  write_agsb_file "server_ip.log" "$ip_final"

  dlog "pick_server_ip_for_install：已写入 $AGSB_HOME/server_ip.log, ip_final=$ip_final"

}

# =========================
# 展示阶段：显示本机 v4/v6 + 地区，并在出口 IP 变更时提示
# =========================
show_local_ip_info_with_out_ip_hint() {
  # A) 获取本机 v4/v6
  local v4v6_result v4_local v6_local
  v4v6_result="$(check_ip_connectivity "${v46url:-https://icanhazip.com}")"
  IFS='|' read -r v4_local v6_local <<EOF
$(printf '%s' "$v4v6_result" | tr -d '\r\n')
EOF
  v4_local="$(strip_ip_brackets_all "$v4_local")"
  v6_local="$(strip_ip_brackets_all "$v6_local")"

  # B) 获取地区（按 v4/v6 分开探测）
  local v4dq="" v6dq=""
  v4dq="$(
    (curl -s4 -m5 --connect-timeout 5 -k https://ip.fm 2>/dev/null \
      | sed -nE 's/.*Location: ([^,]+(, [^,]+)*),.*/\1/p' | head -n1) \
    || (wget -4 -qO- --tries=2 --timeout=5 https://ip.fm 2>/dev/null \
      | sed -nE 's/.*Location: ([^,]+(, [^,]+)*),.*/\1/p' | head -n1)
  )"
  v6dq="$(
    (curl -s6 -m5 --connect-timeout 5 -k https://ip.fm 2>/dev/null \
      | sed -nE 's/.*Location: ([^,]+(, [^,]+)*),.*/\1/p' | head -n1) \
    || (wget -6 -qO- --tries=2 --timeout=5 https://ip.fm 2>/dev/null \
      | sed -nE 's/.*Location: ([^,]+(, [^,]+)*),.*/\1/p' | head -n1)
  )"

  [ -z "$v4dq" ] && v4dq="未知"
  [ -z "$v6dq" ] && v6dq="未知"

  # C) 决定 current_server_ip： server_ip.log
  local current_server_ip=""
  local out_norm
  out_norm="$(strip_ip_brackets_all "${out_ip:-}")"

  if is_file_nonempty $AGSB_HOME/server_ip.log; then
      current_server_ip="$(strip_ip_brackets_all "$(cat "$AGSB_HOME/server_ip.log" 2>/dev/null)")"
  fi

  # D) 输出本地 IP 地址
  green "=========当前服务器本地IP情况========="

  # 输出 IPv4 地址
  if [ -n "$v4_local" ]; then
    echo "$(white "IPV4地址：")$(yellow "${v4_local}")$(white "(服务器地区：")$(green "${v4dq}")$(white ")")"
  else
    echo "$(white "IPV4地址：")$(yellow "无IPV4")"
  fi

  # 输出 IPv6 地址
  if [ -n "$v6_local" ]; then
    echo "$(white "IPV6地址：")$(purple "${v6_local}")$(white "(服务器地区：")$(green "${v6dq}")$(white ")")"
  else
    echo "$(white "IPV6地址：")$(purple "无IPV6")"
  fi

  echo

  # E) 打印“当前使用的IP”：
  if [ -n "$v4_local" ] && [ "$v4_local" = "$current_server_ip" ]; then
    echo "$(green "✅ 当前使用的IP：")$(yellow "${v4_local}")$(white " (IPv4)")"
  fi
  if [ -n "$v6_local" ] && [ "$v6_local" = "$current_server_ip" ]; then
    echo "$(green "✅ 当前使用的IP：")$(purple "${v6_local}")$(white " (IPv6)")"
  fi

  # F) 如果出口 IP 发生变化，打印变更提示
  if [ -n "$current_server_ip" ] && is_valid_ip_simple "$current_server_ip"; then
    local local_expected=""

    if echo "$current_server_ip" | grep -q ':'; then
      local_expected="$v6_local"
    else
      local_expected="$v4_local"
    fi

    # 如果 current_server_ip 与本地的 IP 不匹配，提示出口 IP 已变更
    if [ -n "$local_expected" ] && [ "$current_server_ip" != "$local_expected" ]; then
      local show_ip
      show_ip="$(format_ip_for_log "$current_server_ip" 2>/dev/null || echo "$current_server_ip")"
      yellow " ❗ 👉  由于你设置了单独的出口ip,出口IP已变更为：$show_ip   👈"
    fi
  fi
}

ins(){
    dlog "进入 ins() 安装流程"
    dlog "关键参数：argo=${argo:-<空>}，vmag=${vmag:-<空>}，subscribe=$(get_subscribe_flag 2>/dev/null || echo ${subscribe:-false})，nginx_pt=${nginx_pt:-<空>}，argo_pt=${argo_pt:-<空>}"
    # =====================================================
    # 1. 安装并启动 sing-box
    # =====================================================
    installsb
    setup_node_name_and_ip_strategy
    sbbout

    # 把ip写入server_ip.log
    write_server_ip

    # 2. Nginx（按需：subscribe=true 或启用 argo 才需要）
    ensure_nginx_if_needed || exit 1
    dlog "ensure_nginx_if_needed 已执行完成（如需 Nginx 则已确保安装/启动）"
    dlog "即将判断是否进入 Argo 分支：need_argo=$(need_argo && echo yes || echo no)，vmag=${vmag:-<空>}"

    # =====================================================
    # 2. Argo 相关逻辑（仅在启用 argo + vmag 时）
    # =====================================================
   if need_argo && [ -n "$vmag" ]; then
        dlog "已进入 Argo 启动分支（argo=${argo}，vmag=${vmag}）"
        echo
        echo "=========启用Cloudflared-argo内核========="

        # ✅ 3.1 仅在需要 argo 时才确保 cloudflared 存在
        ensure_cloudflared_if_needed || {
            red "❌ 已启用 Argo，但 cloudflared 准备失败，无法继续启用 Argo"
            exit 1
        }
        dlog "cloudflared 已准备就绪（已通过 ensure_cloudflared_if_needed 检查）"

         # 2.2 计算 Argo 本地端口
        argoport="${argo_pt:-$ARGO_DEFAULT_PORT}"
        dlog "Argo 本地回源端口 argoport=${argoport}（来自 argo_pt 或默认 ARGO_DEFAULT_PORT）"
        write_agsb_file "argoport.log" "$argoport"    

        # 仍然记录 Argo 输出节点类型（给 cip 用）
        record_argo_protocol_type "$argo"

        # 2.3 生成 Argo 凭据（JSON / token）
        # 仅用于“当前启动流程”，不用于重启判断
        prepare_argo_credentials "$ARGO_AUTH" "$ARGO_DOMAIN" "$argoport"
        dlog "prepare_argo_credentials 完成：ARGO_MODE=${ARGO_MODE:-<未设置>}，ARGO_DOMAIN=${ARGO_DOMAIN:-<空>}（固定隧道需域名+凭据）"

        # 2.4 启动 Argo（固定 / 临时）
        if [ -n "$ARGO_DOMAIN" ] && [ -n "$ARGO_AUTH" ]; then
            argo_tunnel_type="固定"
            dlog "判定为固定 Argo 隧道"
            handle_fixed_argo_tunnel "$ARGO_DOMAIN" "$ARGO_AUTH" "$ARGO_MODE"
        else
            argo_tunnel_type="临时"
            dlog "判定为临时 Argo 隧道"
            handle_temp_argo_tunnel "$argoport"
        fi

        # 2.5 等待并检查 Argo 申请结果（原版 sleep + grep 逻辑）
        dlog "开始等待并检查 Argo 申请结果：tunnel_type=${argo_tunnel_type}，日志文件：$AGSB_HOME/argo.log"
        wait_and_check_argo "$argo_tunnel_type"
    fi

    # =====================================================
    # 3. 安装完成后的 legacy 收尾逻辑
    #    （进程检测）
    # =====================================================
    post_install_finalize_legacy
    dlog "post_install_finalize_legacy 已执行完成"

}

# Write environment variables to files for persistence
write2AgsbFolders(){
  ensure_dir "$AGSB_HOME"
  write_config_batch
}

#   show status
agsbstatus() {
  purple "=========当前内核运行状态========="

  dlog "进入 agsbstatus() 函数，开始判断 sing-box 状态"
  # 1) sing-box
  if is_singbox_running_verbose; then
    # 兼容：sing-box version r1.12.13
    local singbox_version
    singbox_version=$("$AGSB_HOME/sing-box" version 2>/dev/null | sed -n 's/.*r\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p')
    echo "Sing-box (版本V${singbox_version:-unknown})：✅ $(green "运行中")"
  else
    echo "Sing-box：❌ $(red "未运行")"
  fi

  # ========= 统一判断：订阅/Argo/Nginx 是否“需要” =========
  local subscribe_flag argo_needed nginx_needed
  subscribe_flag="$(get_subscribe_flag)"

  # Argo 是否需要（用 need_argo 函数）
  argo_needed=false
  if need_argo; then
    argo_needed=true
  fi

  # Nginx 是否需要：订阅开启 或 需要 Argo
  nginx_needed=false
  if is_true "$subscribe_flag" || $argo_needed; then
    nginx_needed=true
  fi

  dlog "进入 agsbstatus() 函数，开始判断 cloudflared 状态"
  # ✅ cloudflared 安装状态（不影响 Argo 是否启用）
  if is_executable $AGSB_HOME/cloudflared || has_cmd cloudflared; then
    echo "cloudflared：✅ $(green "已安装")"
  else
    echo "cloudflared：❌ $(red "未安装")"
  fi

  # 2) Argo 状态（细分：不需要 / 需要但未运行 / 运行中）
  if ! $argo_needed; then
    dlog "进入 agsbstatus() 函数，当前场景无需 Argo，由于argo_needed=$argo_needed"
    echo "Argo：✅ $(purple "未启用")（当前场景无需 Argo）"
  else
    dlog "进入 agsbstatus() 函数，开始判断 cloudflared 状态，argo_needed=$argo_needed"
    if is_cloudflared_running_verbose; then
      # 兼容：cloudflared version 2025.11.1
      local cloudflared_version
      cloudflared_version=$("$AGSB_HOME/cloudflared" version 2>/dev/null | sed -n 's/.*version \([0-9]\{4\}\.[0-9]\+\.[0-9]\+\).*/\1/p')
      echo "cloudflared Argo (版本V${cloudflared_version:-unknown})：✅ $(green "运行中")"
    else
        echo "Argo：❌ 未运行（已启用 Argo）"
        yellow "❗ 已启用 Argo，但 cloudflared 未运行"

    fi
  fi

  # 3) Nginx + subscribe 状态（细分：不需要 / 未安装 / 未运行 / 运行中）
  dlog "进入 agsbstatus() 函数，开始判断 Nginx 状态"
  local nginx_port sub_desc
  nginx_port="${nginx_pt:-$NGINX_DEFAULT_PORT}"
  is_file_nonempty $AGSB_HOME/nginx_port && nginx_port="$(cat "$AGSB_HOME/nginx_port" 2>/dev/null)"

  if is_true "$subscribe_flag"; then
    sub_desc="✅ $(green "订阅已开启")"
  else
    sub_desc="⛔ $(purple "订阅未开启")"
  fi

  # ✅ 不需要 nginx 的场景：明确说明（既不安装也不启动）
  if ! $nginx_needed; then
    echo "Nginx：✅ $(purple "未安装/未启用")（符合 subscribe=false 且未启用 Argo）"
    return 0
  fi

  dlog "进入 agsbstatus() 函数，开始判断 Nginx 状态，进一步区分未安装/未运行/运行中,nginx_needed=$nginx_needed"
  # ✅ 需要 nginx：进一步区分未安装/未运行/运行中
  if ! has_cmd nginx; then
    echo "Nginx：❌ $(red "未安装")（${sub_desc}，端口：${nginx_port}）"
    if is_true "$subscribe_flag"; then
      yellow "❗ 订阅已开启，但系统未安装 Nginx：请重新执行安装或手动安装 nginx"
    fi
    if $argo_needed; then
      yellow "❗ 已启用 Argo，但系统未安装 Nginx：cloudflared 回源将无法工作"
    fi
    return 0
  fi

  # Check if Nginx is running
  if ps aux | grep -v grep | grep -q nginx; then
    echo "Nginx：✅ $(green "运行中")（${sub_desc}，端口：${nginx_port}）"
  else
    echo "Nginx：❌ $(red "未运行")（${sub_desc}，端口：${nginx_port}）"
    if is_true "$subscribe_flag"; then
      yellow "❗ 订阅已开启，但 Nginx 未运行：请重启 nginx"
    fi
    if $argo_needed; then
      yellow "❗ 已启用 Argo，但 Nginx 未运行：cloudflared 回源将无法工作"
    fi
  fi
}

# ================== 订阅：生成订阅内容 ==================

# 把 jh.txt 转成 base64 订阅（兼容 busybox / GNU）
update_subscription_file() {
  # ✅ 打印 subscribe 的最终生效值（不同颜色）
  local subscribe_flag
  subscribe_flag="$(get_subscribe_flag)"

  if is_true "$subscribe_flag"; then
    green "📌  subscribe = true ✅（订阅已开启）"
  else
    purple "📌  subscribe = false ⛔（订阅未开启）"
    return 0
  fi

  # ✅ 没有节点文件就不生成
  if [ ! -s "$AGSB_HOME/jh.txt" ]; then
    purple "❗ 订阅源文件不存在或为空：$AGSB_HOME/jh.txt（跳过生成 sub.txt）"
    return 0
  fi

  mkdir -p $AGSB_WEBROOT
  local out="$AGSB_WEBROOT/sub.txt"

  # ✅ 优先用 openssl（更通用）
  if has_cmd openssl; then
    if openssl base64 -A -in "$AGSB_HOME/jh.txt" > "$out" 2>/dev/null; then
      purple "✅ sub.txt 生成成功：$out"
      return 0
    else
      red "❌ sub.txt 生成失败（openssl base64）"
      return 1
    fi
  fi

  # ✅ fallback：base64（兼容 busybox 与 GNU）
  if has_cmd base64; then
    if base64 -w 0 "$AGSB_HOME/jh.txt" 2>/dev/null > "$out"; then
      purple "✅  sub.txt 生成成功：$out"
      return 0
    fi

    # busybox base64 没有 -w 参数
    if base64 "$AGSB_HOME/jh.txt" 2>/dev/null | tr -d '\n' > "$out"; then
      purple "✅  sub.txt 生成成功：$out"
      return 0
    else
      red "❌ sub.txt 生成失败（base64）"
      return 1
    fi
  fi

  red "❌ sub.txt 生成失败：系统缺少 openssl/base64"
  return 1
}

# 输出订阅链接（规则：固定 Argo => https://域名/sub/uuid；否则 http://IP:nginx_port/sub/uuid）

show_sub_url() {
  # ✅ 没开订阅直接不输出
  is_true "$(get_subscribe_flag)" || return 0

  local port="${nginx_pt}"
  is_file_nonempty $AGSB_HOME/nginx_port && port="$(cat "$AGSB_HOME/nginx_port")"

  local sub_uuid
  sub_uuid="$(cat "$AGSB_HOME/uuid" 2>/dev/null)"

  [ -z "$sub_uuid" ] && return 0

  local argodomain=$(cat "$AGSB_HOME/sbargoym.log" 2>/dev/null)

  local need_argo_flag=false
  vlvm=$(cat $AGSB_HOME/vlvm 2>/dev/null);
  # vlvm不为空，则代表一定有argo  
  if [ -n "$vlvm" ]; then
    need_argo_flag=true
  fi
 
    # 当 need_argo_flag 为 true 且 argodomain 为空且 argo.log 存在时
    if $need_argo_flag && [ -z "$argodomain" ] && is_file_nonempty $AGSB_HOME/argo.log; then
        argodomain=$(grep -aoE '[a-zA-Z0-9.-]+trycloudflare\.com' "$AGSB_HOME/argo.log" 2>/dev/null | tail -n1)
    fi
  
  # 当argodomain 不为空时
  if [ -n "$argodomain" ]; then
    echo "https://${argodomain}/sub/${sub_uuid}"
    return 0
  fi

  # 普通 http：IP:PORT
  local server_ip
  server_ip=$(cat "$AGSB_HOME/server_ip.log" 2>/dev/null)

  if [ -z "$server_ip" ]; then
    server_ip="$( (curl -s4m5 -k https://icanhazip.com) || (wget -4 -qO- --tries=2 https://icanhazip.com) )"
    server_ip=$(update_server_ip "$server_ip" "$out_ip")
    server_ip=$(add_ipv6_brackets "$server_ip")  # 确保 IPv6 地址加上中括号
  fi

  echo "http://${server_ip}:${port}/sub/${sub_uuid}"
}

ensure_and_print_reality_private_for_cip() {
  local want_print="${1:-0}"
  [ "$want_print" = "1" ] || return 0

  if [ -z "$reality_private" ] && is_file_nonempty $AGSB_HOME/reality.key; then
    reality_private="$(awk '/PrivateKey/{print $NF; exit}' "$AGSB_HOME/reality.key" 2>/dev/null)"
    reality_public="$(awk '/PublicKey/{print $NF; exit}' "$AGSB_HOME/reality.key" 2>/dev/null)"
  fi

  if [ -n "$reality_private" ]; then
    print_reality_keypair_hint 1
  fi
}

print_reality_key(){
    case "${1:-}" in
    key|rp|showkey)
        ensure_and_print_reality_private_for_cip 1
        ;;
    esac
}

append_jh() {
  # 只写纯文本到聚合文件，禁止任何颜色码污染订阅
  # 用 echo -e 是为了支持变量里自带的 \n 换行
  echo -e "$1" >> "$AGSB_HOME/jh.txt"
}

# 定义验证 IP 地址是否合法的函数
is_valid_ip() {
  local ip
  ip="$(strip_ip_brackets "${1:-}")"

  [ -n "$ip" ] || return 1

  # IPv4
  if echo "$ip" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
    return 0
  fi

  # IPv6（宽松判断：包含冒号即可，再配合你原来的正则）
  if echo "$ip" | grep -qE '^([a-fA-F0-9:]+:+)+[a-fA-F0-9]+$'; then
    return 0
  fi

# 返回1 代表无效的ip
  return 1
}

# 根据 out_ip_local 更新 current_server_ip 的函数，确保返回的 IPv6 不包含中括号
update_server_ip() {
    # 定义调试日志函数
    debug_log() {
        [ "${DEBUG_FLAG:-0}" = "1" ] && echo -e "$*" >&2  # 如果 DEBUG_FLAG 为 1，则打印日志
    }

    local current_server_ip="$1"
    local out_ip_local="$2"  # 修改变量名，避免与其他地方的 out_ip 混淆

    # 输出调试信息，显示传入的参数
    debug_log "[调试] 原始 current_server_ip: $current_server_ip"
    debug_log "[调试] 原始 out_ip_local: $out_ip_local"

   # 如果 current_server_ip 是 IPv6 地址（即包含中括号），去除中括号
    if echo "$current_server_ip" | grep -q '^\[' && echo "$current_server_ip" | grep -q '\]$'; then
        debug_log "[调试] 去掉 current_server_ip 中的中括号"
        current_server_ip=$(echo "$current_server_ip" | sed 's/^\[\(.*\)\]$/\1/')  # 去掉中括号
        debug_log "[调试] 去掉中括号后的 current_server_ip: $current_server_ip"
    fi

    # 如果 out_ip_local 非空且包含中括号，则去除中括号
    if [ -n "$out_ip_local" ] && echo "$out_ip_local" | grep -q '^\[' && echo "$out_ip_local" | grep -q '\]$'; then
        debug_log "[调试] 去掉 out_ip_local 中的中括号"
        out_ip_local=$(echo "$out_ip_local" | sed 's/^\[\(.*\)\]$/\1/')  # 去掉中括号
        debug_log "[调试] 去掉中括号后的 out_ip_local: $out_ip_local"
    fi

    # 检查 out_ip_local 是否有效，并且与 current_server_ip 不同，并且确保它们类型一致（IPv4 或 IPv6）
    if [ -n "$out_ip_local" ] && is_valid_ip "$out_ip_local" && [ "$current_server_ip" != "$out_ip_local" ]; then
        # 检查是否是 IPv6 地址，并且确保类型一致
        if echo "$current_server_ip" | grep -q ':' && echo "$out_ip_local" | grep -q ':'; then
            # 都是 IPv6 地址
            debug_log "[调试] current_server_ip 和 out_ip_local 都是 IPv6，进行更新"
            current_server_ip="$out_ip_local"
        # 检查是否是 IPv4 地址，并且确保类型一致
        elif ! echo "$current_server_ip" | grep -q ':' && ! echo "$out_ip_local" | grep -q ':'; then
            # 都是 IPv4 地址
            debug_log "[调试] current_server_ip 和 out_ip_local 都是 IPv4，进行更新"
            current_server_ip="$out_ip_local"
        else
            debug_log "[调试] current_server_ip 和 out_ip_local 类型不同（IPv4 和 IPv6），不进行更新"
        fi
    else
        debug_log "[调试] out_ip_local 为空、无效或与 current_server_ip 相同，不进行更新"
    fi

    # 输出最终的 server_ip 和 out_ip_local，方便对比
    debug_log "[调试] 最终的 server_ip: $current_server_ip"
    debug_log "[调试] 最终的 out_ip_local: $out_ip_local"

    # 返回更新后的 server_ip，确保不包含中括号
    echo "$current_server_ip"
}

# 给没有中括号的 IPv6 地址加上中括号的函数
add_ipv6_brackets() {
    local ipv6="$1"

    # 如果是 IPv6 地址且没有中括号，添加中括号
    if echo "$ipv6" | grep -q ':' && ! echo "$ipv6" | grep -q '[]]'; then
        echo "[$ipv6]"  # 给 IPv6 地址加上中括号
    else
        echo "$ipv6"  # 否则返回原始地址
    fi
}

# 去掉 IPv6 的中括号： [2001:db8::1] -> 2001:db8::1
strip_ip_brackets() {
  # todo 要去掉这个函数
  local ip="${1:-}"
  ip="${ip#[}"   # 去掉开头的 [
  ip="${ip%]}"   # 去掉结尾的 ]
  echo "$ip"
}

# ================== Phase 21: 节点链接生成优化 ==================
# 生成Hysteria2节点链接
generate_hy2_link() {
  local uuid="$1"
  local server_ip="$2"
  local port_hy2="$3"
  local hy_sni="$4"
  local sxname="$5"
  
  echo "hysteria2://$uuid@$server_ip:$port_hy2?security=tls&alpn=h3&insecure=1&allowInsecure=1&sni=${hy_sni}#${sxname}hy2-$hostname"
}

# 生成TUIC节点链接
generate_tuic_link() {
  local uuid="$1"
  local server_ip="$2"
  local port_tu="$3"
  local tu_sni="$4"
  local sxname="$5"
  
  echo "tuic://${uuid}:${uuid}@${server_ip}:${port_tu}?sni=${tu_sni}&congestion_control=bbr&security=tls&udp_relay_mode=native&alpn=h3&allow_insecure=1#${sxname}tuic-$hostname"
}

# 生成VLESS-Reality-Vision节点链接
generate_vless_reality_link() {
  local uuid="$1"
  local server_ip="$2"
  local port_vlr="$3"
  local vl_sni="$4"
  local public_key="$5"
  local short_id="$6"
  local sxname="$7"
  
  echo "vless://${uuid}@${server_ip}:${port_vlr}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${vl_sni}&fp=chrome&pbk=${public_key}&sid=${short_id}&type=tcp&headerType=none#${sxname}vless-reality-$hostname"
}

# 生成Vmess-WS-TLS-Argo节点链接
generate_vmess_argo_link() {
  local uuid="$1"
  local cdn_host="$2"
  local cdn_pt="$3"
  local argodomain="$4"
  local sxname="$5"
  
  local vmess_json="{\"v\":\"2\",\"ps\":\"${sxname}vmess-ws-tls-argo-$hostname-${cdn_pt}\",\"add\":\"${cdn_host}\",\"port\":\"${cdn_pt}\",\"id\":\"$uuid\",\"aid\":\"0\",\"net\":\"ws\",\"host\":\"$argodomain\",\"path\":\"/${uuid}-vm\",\"tls\":\"tls\",\"sni\":\"$argodomain\"}"
  echo "vmess://$(echo "$vmess_json" | base64 | tr -d '\n\r')"
}

# 生成Trojan-WS-TLS-Argo节点链接
generate_trojan_argo_link() {
  local uuid="$1"
  local cdn_host="$2"
  local cdn_pt="$3"
  local argodomain="$4"
  local sxname="$5"
  
  echo "trojan://${uuid}@${cdn_host}:${cdn_pt}?security=tls&type=ws&host=${argodomain}&path=%2F${uuid}-tr&sni=${argodomain}&fp=chrome#${sxname}trojan-ws-tls-argo-$hostname-${cdn_pt}"
}

# ================== Phase 21: 节点链接生成优化 END ==================

# ================== Phase 23: 协议检查优化 ==================
# 检查协议是否启用
is_protocol_enabled() {
  local protocol="$1"
  grep -q "$protocol" "$AGSB_HOME/sb.json" 2>/dev/null
}

# 检查Hysteria2是否启用
has_hy2() {
  is_protocol_enabled "hy2-sb"
}

# 检查TUIC是否启用
has_tuic() {
  is_protocol_enabled "tuic-sb"
}

# 检查VLESS-Reality是否启用
has_vless_reality() {
  is_protocol_enabled "vless-reality-vision-sb"
}

# 检查Trojan是否启用
has_trojan() {
  is_protocol_enabled "trojan-ws-sb"
}

# 检查Vmess是否启用
has_vmess() {
  is_protocol_enabled "vmess-sb"
}

# ================== Phase 23: 协议检查优化 END ==================

# show nodes
cip(){

    # 日志：只输出到 stderr，不污染 stdout
    debug_log() {
      [ "${DEBUG_FLAG:-0}" = "1" ] && echo -e "$*" >&2
    }
    
    echo
    # 显示 AGSB 状态
    agsbstatus
    echo
    
    # 显示本机 v4/v6 + 地区，并在出口 IP 变更时提示
    show_local_ip_info_with_out_ip_hint

    rm -rf "$AGSB_HOME/jh.txt"; 
    uuid=$(cat "$AGSB_HOME/uuid"); 
    server_ip=$(cat "$AGSB_HOME/server_ip.log" 2>/dev/null); 
    sxname=$(cat "$AGSB_HOME/name" 2>/dev/null);

    echo "*********************************************************"; 
    purple "agsb脚本输出节点配置如下："; 
    echo;
    # Hysteria2 protocol (hy2)
    if has_hy2; then 
        port_hy2=$(read_hy2_port)
        hy_sni=$(cat "$AGSB_HOME/hy_sni"); 
        hy2_link=$(generate_hy2_link "$uuid" "$server_ip" "$port_hy2" "$hy_sni" "$sxname")
        yellow "💣【 Hysteria2 】(直连协议)"; 
        green "$hy2_link"
        append_jh "$hy2_link"
        echo; 
    fi
    
     # TUIC protocol (tuic or tupt)
    if has_tuic; then
        port_tu=$(read_tuic_port)
        tu_sni=$(cat "$AGSB_HOME/tu_sni"); 
        tuic_link=$(generate_tuic_link "$uuid" "$server_ip" "$port_tu" "$tu_sni" "$sxname")
        yellow "💣【 TUIC 】(直连协议)"
        green "$tuic_link" 
        append_jh "$tuic_link"
        echo;
    fi
    # VLESS-Reality-Vision protocol (vless-reality-vision)
    if has_vless_reality; then
        port_vlr=$(read_vless_reality_port)
        public_key=$(sed -n '2p' "$AGSB_HOME/reality.key" | awk '{print $2}')
        short_id=$(cat "$AGSB_HOME/short_id")
        vl_sni=$(cat "$AGSB_HOME/vl_sni")

        dlog "cip函数中的short_id,值为:$short_id"

        vless_link=$(generate_vless_reality_link "$uuid" "$server_ip" "$port_vlr" "$vl_sni" "$public_key" "$short_id" "$sxname")
        yellow "💣【 VLESS-Reality-Vision 】(直连协议)"; 
        green "$vless_link"
        append_jh "$vless_link"
        echo;

        # 查看节点时提示用户保存私钥（方便下次保持节点一致）,一般这里的$1值为"key"
         print_reality_key "$1"
    fi
    #argodomain=$(cat "$AGSB_HOME/sbargoym.log" 2>/dev/null); [ -z "$argodomain" ] && argodomain=$(grep -a trycloudflare.com "$AGSB_HOME/argo.log" 2>/dev/null | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')
   
    argodomain=$(cat "$AGSB_HOME/sbargoym.log" 2>/dev/null)

    if need_argo && [ -z "$argodomain" ] && is_file_nonempty $AGSB_HOME/argo.log; then
        argodomain=$(grep -aoE '[a-zA-Z0-9.-]+trycloudflare\.com' "$AGSB_HOME/argo.log" 2>/dev/null | tail -n1)
    fi

    cdn_host=$(cat "$AGSB_HOME/cdn_host")
    cdn_pt=$(cat "$AGSB_HOME/cdn_pt" 2>/dev/null)
    cdn_pt="$(normalize_cdn_pt "$cdn_pt" 443)"

    if [ -n "$argodomain" ]; then
        vlvm=$(cat $AGSB_HOME/vlvm 2>/dev/null); uuid=$(cat "$AGSB_HOME/uuid")
        if [ "$vlvm" = "Vmess" ]; then
            vmatls_link1=$(generate_vmess_argo_link "$uuid" "$cdn_host" "$cdn_pt" "$argodomain" "$sxname")
            tratls_link1=""
        elif [ "$vlvm" = "Trojan" ]; then
            tratls_link1=$(generate_trojan_argo_link "$uuid" "$cdn_host" "$cdn_pt" "$argodomain" "$sxname")
            vmatls_link1=""
        fi

        sbtk=$(cat "$AGSB_HOME/sbargotoken.log" 2>/dev/null); 
        yellow "---------------------------------------------------------"
        yellow "Argo隧道信息 (使用 ${vlvm}-ws 端口: $(cat $AGSB_HOME/argoport.log 2>/dev/null))"
        yellow "---------------------------------------------------------"

        green "Argo域名: ${argodomain}"

        #输出 argo token
        if [ -n "${sbtk}" ]; then
            green "Argo固定隧道token:\n${sbtk}"
        fi

        green ""
        green "💣 ${cdn_pt}端口 Argo-TLS 节点 (优选IP可替换):"
        green "${vmatls_link1}${tratls_link1}" 
        append_jh "${vmatls_link1}${tratls_link1}"
        yellow "---------------------------------------------------------"

    fi

    update_subscription_file
    echo
    yellow "📌 节点订阅地址："
    if ! is_true "$(get_subscribe_flag)"; then
        purple "⛔ 未开启订阅"
    else
        green "$(show_sub_url)"
    fi

    echo; 
    yellow "聚合节点: cat $AGSB_HOME/jh.txt"; 
    yellow "========================================================="; 
    purple "相关快捷方式如下：👇"; 
    showmode
    
}

cleanup_nginx() {
  
    # 清理 nginx
    pkill -15 nginx >/dev/null 2>&1
    rm -f "$(nginx_conf_path)" 2>/dev/null

    # 禁用 nginx 自启（避免卸载后 nginx 仍然起来）
    if has_systemd; then
        systemctl stop nginx >/dev/null 2>&1
        systemctl disable nginx >/dev/null 2>&1
    elif has_cmd rc-service; then
        rc-service nginx stop >/dev/null 2>&1
        rc-update del nginx default >/dev/null 2>&1
    fi
    echo "Nginx 已被清理(清理配置文件和禁止自启，nginx 服务已停止)。"
}

# ================== Phase 22: 清理函数优化 ==================
# 杀死进程
kill_agsb_processes() {
  dlog "杀死 agsb 相关进程"
  for P in /proc/[0-9]*; do
    if [ -L "$P/exe" ]; then
      TARGET=$(readlink -f "$P/exe" 2>/dev/null)
      if echo "$TARGET" | grep -qE '/agsb/cloudflared|/agsb/sing-box'; then 
        kill "$(basename "$P")" 2>/dev/null
      fi
    fi
  done
  
  pkill -15 -f "$AGSB_HOME/sing-box" 2>/dev/null
  pkill -15 -f "$AGSB_HOME/cloudflared" 2>/dev/null
}

# 清理crontab
cleanup_crontab() {
  dlog "清理 crontab"
  crontab -l > $TMP_DIR/crontab.tmp 2>/dev/null || touch $TMP_DIR/crontab.tmp
  sed -i '/.*agsb.*/d' $TMP_DIR/crontab.tmp
  crontab $TMP_DIR/crontab.tmp >/dev/null 2>&1
  rm -f $TMP_DIR/crontab.tmp
}

# 清理服务
cleanup_services() {
  dlog "清理服务"
  if has_systemd; then
    for svc in sb argo; do
      systemctl stop "$svc" >/dev/null 2>&1
      systemctl disable "$svc" >/dev/null 2>&1
    done
    rm -f $SYSTEMD_DIR/{sb.service,argo.service}
  elif has_cmd rc-service; then
    for svc in sing-box argo; do
      rc-service "$svc" stop >/dev/null 2>&1
      rc-update del "$svc" default >/dev/null 2>&1
    done
    rm -f $INITD_DIR/{sing-box,argo}
  fi
}

# 清理目录
cleanup_directories() {
  dlog "清理目录"
  if is_dir $HOME/bin/agsb; then
    rm -rf "$HOME/bin/agsb"
  fi
}

# ================== Phase 22: 清理函数优化 END ==================

# Remove agsb folder
cleandel(){
    # Change to $HOME to avoid issues when deleting directories
   cd "$HOME" || exit 1

    yellow "开始卸载sing-box/cloudflared流程..."; 
    
    # 杀死进程
    kill_agsb_processes
    
    # 清理crontab
    cleanup_crontab
    
    # 清理服务
    cleanup_services
    
    # 清理目录
    cleanup_directories

    yellow "开始卸载或者清理nginx流程..."; 
    cleanup_nginx
}

# Restart sing-box
sbrestart(){
    pkill -15 -f "$AGSB_HOME/sing-box" 2>/dev/null

    if has_systemd; then
        systemctl restart sb
    elif has_cmd rc-service; then
        rc-service sing-box restart
    else
        nohup "$AGSB_HOME/sing-box" run -c "$AGSB_HOME/sb.json" >/dev/null 2>&1 &
    fi
}

# Restart argo
argorestart(){
    # 先尽力停止现有 cloudflared 进程（原版行为）
   pkill -15 -f "$AGSB_HOME/cloudflared" 2>/dev/null

    # ===============================
    # systemd 管理
    # ===============================
    if has_systemd; then
        systemctl restart argo
        return
    fi

    # ===============================
    # openrc 管理
    # ===============================
    if has_cmd rc-service; then
        rc-service argo restart
        return
    fi

    # ===============================
    # 无 init 系统（nohup 启动）
    # 判断顺序非常重要！
    # ===============================

    # 1️⃣ JSON 固定隧道（最高优先级）
    if is_file $AGSB_HOME/tunnel.yml; then
        start_argo_json_tunnel
        return
    fi

    # 2️⃣ token 固定隧道
    if is_file $AGSB_HOME/sbargotoken.log; then
        start_argo_token_tunnel
        return
    fi

    # 3️⃣ 临时 Argo（trycloudflare）
    if is_file $AGSB_HOME/argoport.log; then
        start_argo_temp_tunnel
    fi
}

install_step(){
    install_init
    validate_all_params || exit 1
    validate_extended_params || exit 1
    configure_iptables
    ins
    green "agsb脚本安装完成！即将打印节点信息……"
    # 显示节点信息 这里的key是一个定值，为了打印私钥
    cip "key"
}

# ================== 端口冲突检测（subscribe=true 才检查 nginx_pt） ==================
check_port_conflicts_or_exit() {
  _is_port_int() {
    [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
  }

  # subscribe 只兼容 TRUE/True/true（统一转小写），不改原变量
  local subscribe_norm="${subscribe,,}"
  [[ -z "$subscribe_norm" ]] && subscribe_norm="false"

  # ✅ 在函数内部计算“有效端口”（不修改全局变量）
  #  ❗ argo_pt 默认 8001；nginx_pt 默认 8080
  #  ❗ :- 不会发生“把 argo_pt 默认值写进去”的副作用；只有 := 才会。
  local argo_eff="${argo_pt:-8001}"
  local nginx_eff="${nginx_pt:-8080}"

  # ✅ 规则：argo_pt 和 nginx_pt 不能同时为 8001（按有效端口判断）
  if [[ "$argo_eff" == "8001" && "$nginx_eff" == "8001" ]]; then
    echo
    red "❌ 端口冲突：argo_pt 和 nginx_pt 不能同时等于 8001"
    yellow "原因：由于 8001 作为 argo_pt 的内部默认值（nginx_pt 默认 8080），因此不要把 nginx_pt 也设成 8001"
    yellow "当前值：argo_pt=${argo_eff} | nginx_pt=${nginx_eff}"
    echo
    exit 1
  fi

  # 固定检查这四个；subscribe=true 时才额外检查 nginx_pt
  local vars="trpt vlrt hypt tupt"
  [[ "$subscribe_norm" == "true" ]] && vars="$vars nginx_pt"

  declare -A used   # port -> "name=value, name=value..."
  local has_conflict=0

  local k v
  for k in $vars; do
    if [[ "$k" == "nginx_pt" ]]; then
      v="$nginx_eff"   # 用有效默认值参与检查，但不改 nginx_pt 本身
    else
      v="${!k}"        # 动态取值：trpt/vlrt/hypt/tupt
    fi

    # 不为空才检查
    [ -z "${v:-}" ] && continue

    if ! _is_port_int "$v"; then
      echo
      red "❌ 端口参数非法：${k}=${v}（必须是 1-65535 的整数）"
      exit 1
    fi

    if [ -n "${used[$v]:-}" ]; then
      has_conflict=1
      used["$v"]+=", ${k}=${v}"
    else
      used["$v"]="${k}=${v}"
    fi
  done

  if [ "$has_conflict" -eq 1 ]; then
    echo
    # 将变量名列表转换为 CSV 格式，也就是变量之间用逗号分隔
    local vars_csv="${vars// /, }"
    red "❌ 检测到端口重复（${vars_csv}），已中断退出："
    local p
    for p in "${!used[@]}"; do
      [[ "${used[$p]}" == *","* ]] && yellow " - 端口 ${p} 冲突变量：${used[$p]}"
    done
    echo
    exit 1
  fi
}
# ================== 端口冲突检测 END ================

# ================== Phase 12: 命令处理优化函数 ==================
# 统一的命令执行和退出模式
run_cmd_and_exit() {
  local cmd="$1"
  local success_msg="${2:-}"
  
  eval "$cmd" || return 1
  [ -n "$success_msg" ] && green "$success_msg"
  exit 0
}

# Nginx 操作的统一处理
handle_nginx_cmd() {
  local action="$1"
  local func_name="nginx_${action}"
  
  if ! has_cmd "$func_name"; then
    red "❌ 不支持的 nginx 操作：$action"
    return 1
  fi
  
  $func_name
  green "Nginx 已完成${action}操作！"
  nginx_status
  exit 0
}

# 协议检查和安装流程
handle_install_flow() {
  local mode="$1"  # "ins" 或 "rep"
  
  if [ "$mode" = "rep" ]; then
    green "开始覆盖式安装流程..."
    green "1、即将开始清理操作..."
    cleandel
    rm -rf "$AGSB_HOME"/{sb.json,sbargoym.log,sbargotoken.log,argo.log,argoport.log,name,short_id,cdn_host,hy_sni,vl_sni,tu_sni,vl_sni_pt,cdn_pt}
    green "1.1、清理操作完成..."
    sleep 2
    green "2、覆盖式安装开始..."
  else
    yellow "开始安装流程..."
  fi
  
  install_step
  [ "$mode" = "rep" ] && echo "覆盖式安装已完成... 再见👋" || true
  exit 0
}

# ================== Phase 12: 安装流程优化函数 ==================
# 统一的安装前置检查和初始化
install_init() {
  echo "VPS系统：$op"
  echo "CPU架构：$cpu"
  echo "agsb脚本开始安装/更新…………" && sleep 1
  
  # 获取操作系统名称
  os_name=$(awk -F= '/^NAME/{print $2}' $OS_RELEASE)
  
  # Phase 33: 初始化缓存目录
  init_cache_dir || dlog "缓存目录初始化失败（非致命）"
  
  dlog "开始安装各种乱七八糟的依赖"
  install_deps
  dlog "安装各种乱七八糟的依赖完成"
}

# 统一的iptables配置
configure_iptables() {
  if ! has_cmd iptables; then
    return 0
  fi
  
  setenforce 0 >/dev/null 2>&1
  iptables -F
  iptables -P INPUT ACCEPT
  iptables -P FORWARD ACCEPT
  iptables -P OUTPUT ACCEPT
  
  # 根据系统类型保存规则
  if [[ "$os_name" == *"Debian"* || "$os_name" == *"Ubuntu"* ]]; then
    has_cmd netfilter-persistent && netfilter-persistent save >/dev/null 2>&1
    mkdir -p $IPTABLES_DIR 2>/dev/null
    has_cmd iptables-save && iptables-save >$IPTABLES_DIR/rules.v4 2>/dev/null
    echo "iptables执行开放所有端口 (Debian/Ubuntu)"
  elif [[ "$os_name" == *"Alpine"* ]]; then
    mkdir -p $IPTABLES_DIR 2>/dev/null
    has_cmd iptables-save && iptables-save > $IPTABLES_DIR/rules.v4 2>/dev/null
    echo "iptables执行开放所有端口 (Alpine)"
  else
    echo "不支持此操作系统"
  fi
}

# ================== Phase 12: 协议优化函数 ==================
# 从协议常量映射中获取协议对应的输出值
get_argo_protocol_output() {
  local protocol="$1"
  
  # 检查协议是否在支持列表中
  if [[ ! " $ARGO_SUPPORTED_PROTOCOLS " =~ " $protocol " ]]; then
    dlog "不支持的协议：$protocol"
    return 1
  fi
  
  # 从映射中获取输出值
  echo "${ARGO_PROTOCOL_MAP[$protocol]}"
}

# 记录 Argo 协议类型（使用常量映射）
record_argo_protocol_type() {
  local argo_type="$1"
  local protocol_output
  
  protocol_output=$(get_argo_protocol_output "$argo_type") || {
    red "❌ 不支持的 Argo 协议类型：$argo_type"
    return 1
  }
  
  write_agsb_file "vlvm" "$protocol_output"
  dlog "已记录 Argo 协议类型：$argo_type -> $protocol_output"
}

# 验证协议是否被支持
is_argo_protocol_supported() {
  local protocol="$1"
  [[ " $ARGO_SUPPORTED_PROTOCOLS " =~ " $protocol " ]]
}

# 列出所有支持的协议
list_argo_protocols() {
  echo "支持的 Argo 协议："
  local proto
  for proto in $ARGO_SUPPORTED_PROTOCOLS; do
    echo "  - $proto: ${ARGO_PROTOCOL_MAP[$proto]}"
  done
}

# ================== Phase 12: 命令处理优化函数 END ==================

# ================== Phase 15: Main函数优化 ==================
# 命令分发器 - 统一处理所有命令
dispatch_command() {
  local cmd="$1"
  local arg="${2:-}"
  
  case "$cmd" in
    autostart)
      enable_autostart
      ;;
    autostart_off)
      disable_autostart
      ;;
    nginx_start|nginx_stop|nginx_restart|nginx_status)
      handle_nginx_cmd "${cmd#nginx_}"
      ;;
    config)
      # Phase 32: 生成配置文件
      generate_config_template "${arg:-$AGSB_CONFIG_USER}"
      ;;
    del)
      cmd_uninstall
      ;;
    list)
      cip "$arg"
      ;;
    ups)
      cmd_update_singbox
      ;;
    res)
      cmd_restart_services
      ;;
    sub)
      cmd_subscription
      ;;
    rep|ins)
      handle_install_flow "$cmd"
      ;;
    *)
      return 1
      ;;
  esac
  
  return 0
}

# 卸载命令
cmd_uninstall() {
  cleandel
  rm -rf "$AGSB_HOME"
  echo "卸载完成"
  showmode
}

# 更新sing-box内核
cmd_update_singbox() {
  pkill -15 -f "$AGSB_HOME/sing-box" 2>/dev/null
  upsingbox && sbrestart && echo "Sing-box内核更新完成" && sleep 2 && cip
}

# 重启服务
cmd_restart_services() {
  sbrestart
  argorestart
  sleep 5 && echo "重启完成" && sleep 3 && cip
}

# 订阅命令
cmd_subscription() {
  update_subscription_file
  echo -e "📌 节点订阅地址："
  if ! is_true "$(get_subscribe_flag)"; then
    purple "⛔ 未开启订阅"
  else
    u="$(show_sub_url)"
    green "$u"
    echo
  fi
}

# ================== Phase 15: Argo启动优化 ==================
# 统一的Argo启动流程
start_argo_unified() {
  local argo_mode="$1"
  local argo_auth="$2"
  local argo_port="$3"
  local argo_domain="$4"
  
  dlog "开始统一Argo启动流程：mode=$argo_mode, domain=$argo_domain"
  
  # 确保cloudflared存在
  ensure_cloudflared_if_needed || {
    red "❌ 已启用 Argo，但 cloudflared 准备失败"
    return 1
  }
  
  # 记录Argo协议类型
  if [ "$argo_mode" = "vmpt" ]; then
    write_agsb_file "vlvm" "Vmess"
  elif [ "$argo_mode" = "trpt" ]; then
    write_agsb_file "vlvm" "Trojan"
  fi
  
  # 保存Argo端口
  write_agsb_file "argoport.log" "$argo_port"
  
  # 生成Argo凭据
  prepare_argo_credentials "$argo_auth" "$argo_domain" "$argo_port"
  
  # 判断固定或临时隧道
  if [ -n "$argo_domain" ] && [ -n "$argo_auth" ]; then
    dlog "启动固定Argo隧道"
    start_argo_with_method "$argo_mode" "$argo_auth" "$argo_port"
    write_agsb_file "sbargoym.log" "$argo_domain"
    [ "$argo_mode" = "token" ] && write_agsb_file "sbargotoken.log" "$argo_auth"
  else
    dlog "启动临时Argo隧道"
    start_argo_no_daemon "temp" "" "$argo_port"
  fi
  
  # 等待并检查结果
  wait_and_check_argo "$([ -n "$argo_domain" ] && echo 固定 || echo 临时)"
}

# ================== Phase 15: Main函数优化 END ==================

# ================== Phase 16: ins函数优化 ==================
# Sing-box安装和启动流程
install_singbox_phase() {
  dlog "Phase 1: 安装并启动 sing-box"
  installsb
  setup_node_name_and_ip_strategy
  sbbout
  write_server_ip
}

# ================== Phase 17: 协议配置优化 ==================
# 通用的协议配置函数
add_protocol_to_config() {
  local proto_type="$1"
  local proto_tag="$2"
  local proto_port="$3"
  local proto_config="$4"
  
  dlog "添加协议：$proto_type (端口: $proto_port)"
  
  # 验证端口
  if ! [[ "$proto_port" =~ ^[0-9]+$ ]] || [ "$proto_port" -lt 1 ] || [ "$proto_port" -gt 65535 ]; then
    red "❌ 无效的端口号：$proto_port"
    return 1
  fi
  
  # 追加到配置文件
  cat >> "$AGSB_HOME/sb.json" <<EOF
$proto_config
EOF
  
  yellow "${proto_type}端口：$proto_port"
}

# 获取或生成协议端口
get_protocol_port() {
  local port_name="$1"
  local port_var="$2"
  
  if [ -n "$port_var" ]; then
    write_agsb_file "$port_name" "$port_var"
    echo "$port_var"
  elif is_file_nonempty "$AGSB_HOME/$port_name"; then
    cat "$AGSB_HOME/$port_name"
  else
    local new_port=$(rand_port)
    write_agsb_file "$port_name" "$new_port"
    echo "$new_port"
  fi
}

# ================== Phase 17: 协议配置优化 END ==================

# ================== Phase 18: cip函数优化 ==================
# 统一的配置文件读取函数
read_config() {
  local config_name="$1"
  local default="${2:-}"
  
  if is_file_nonempty "$AGSB_HOME/$config_name"; then
    cat "$AGSB_HOME/$config_name"
  else
    echo "$default"
  fi
}

# 生成节点链接的通用函数
generate_node_link() {
  local protocol="$1"
  local uuid="$2"
  local server_ip="$3"
  local port="$4"
  local sni="$5"
  local node_name="$6"
  
  case "$protocol" in
    hy2)
      echo "hysteria2://$uuid@$server_ip:$port?security=tls&alpn=h3&insecure=1&allowInsecure=1&sni=${sni}#${node_name}"
      ;;
    tuic)
      echo "tuic://${uuid}:${uuid}@${server_ip}:${port}?sni=${sni}&congestion_control=bbr&security=tls&udp_relay_mode=native&alpn=h3&allow_insecure=1#${node_name}"
      ;;
    vless-reality)
      local public_key="$7"
      local short_id="$8"
      echo "vless://${uuid}@${server_ip}:${port}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${public_key}&sid=${short_id}&type=tcp&headerType=none#${node_name}"
      ;;
    vmess-ws-tls)
      local cdn_host="$7"
      local cdn_pt="$8"
      local argo_domain="$9"
      echo "vmess://$(echo "{\"v\":\"2\",\"ps\":\"${node_name}\",\"add\":\"${cdn_host}\",\"port\":\"${cdn_pt}\",\"id\":\"$uuid\",\"aid\":\"0\",\"net\":\"ws\",\"host\":\"$argo_domain\",\"path\":\"/${uuid}-vm\",\"tls\":\"tls\",\"sni\":\"$argo_domain\"}" | base64 | tr -d '\n\r')"
      ;;
    trojan-ws-tls)
      local cdn_host="$7"
      local cdn_pt="$8"
      local argo_domain="$9"
      echo "trojan://${uuid}@${cdn_host}:${cdn_pt}?security=tls&type=ws&host=${argo_domain}&path=%2F${uuid}-tr&sni=${argo_domain}&fp=chrome#${node_name}"
      ;;
  esac
}

# ================== Phase 18: cip函数优化 END ==================

# ================== Phase 18: 自启动优化 ==================
# 统一的服务文件检查
check_service_installed() {
  local bin="$1"
  local cfg="$2"
  
  if [ ! -x "$bin" ] || [ ! -s "$cfg" ]; then
    echo "❗ 未检测到已安装：$bin 或 $cfg 不存在/为空"
    return 1
  fi
  return 0
}

# 统一的systemd服务安装
install_systemd_service() {
  local svc="$1"
  local bin="$2"
  local cfg="$3"
  local workdir="$4"
  
  cat > "$SYSTEMD_DIR/${svc}.service" <<EOF
[Unit]
Description=agsb sing-box service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=${workdir}
ExecCondition=/bin/sh -c 'test -x ${bin} && test -s ${cfg}'
ExecStart=${bin} run -c ${cfg}
Restart=always
RestartSec=2
LimitNOFILE=1048576
TimeoutStartSec=30

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now "${svc}.service" >/dev/null 2>&1
  systemctl restart "${svc}.service" >/dev/null 2>&1
  echo "✅ 已开启开机自启（systemd）：${svc}"
}

# 统一的openrc服务安装
install_openrc_service() {
  local svc="$1"
  local bin="$2"
  local cfg="$3"
  
  cat > "$INITD_DIR/${svc}" <<'EOF'
#!/sbin/openrc-run
name="agsb sing-box"
description="agsb sing-box service"
command="/root/agsb/sing-box"
command_args="run -c /root/agsb/sb.json"
command_background="yes"
pidfile="/run/agsb-singbox.pid"

depend() {
  need net
  after firewall
}

start_pre() {
  [ -x /root/agsb/sing-box ] || return 1
  [ -s /root/agsb/sb.json ] || return 1
}

start() {
  ebegin "Starting ${name}"
  start-stop-daemon --start --background --make-pidfile --pidfile "$pidfile" \
    --exec "$command" -- $command_args
  eend $?
}

stop() {
  ebegin "Stopping ${name}"
  start-stop-daemon --stop --pidfile "$pidfile"
  eend $?
}
EOF

  chmod +x "$INITD_DIR/${svc}"
  rc-update add "${svc}" default >/dev/null 2>&1
  rc-service "${svc}" restart >/dev/null 2>&1
  echo "✅ 已开启开机自启（openrc）：${svc}"
}

# ================== Phase 18: 自启动优化 END ==================

# ================== Phase 19: 下载和验证优化 ==================
# ================== Phase 33: 性能优化 - 缓存和并行下载 ==================

# 缓存目录
AGSB_CACHE_DIR="${AGSB_HOME}/.cache"

# 初始化缓存目录
init_cache_dir() {
  mkdir -p "$AGSB_CACHE_DIR" || return 1
  chmod 700 "$AGSB_CACHE_DIR"
  return 0
}

# 生成缓存键（基于URL的MD5哈希）
get_cache_key() {
  local url="$1"
  echo "$url" | md5sum | awk '{print $1}'
}

# 获取缓存文件路径
get_cache_path() {
  local url="$1"
  local cache_key=$(get_cache_key "$url")
  echo "$AGSB_CACHE_DIR/$cache_key"
}

# 检查缓存是否有效（默认24小时过期）
is_cache_valid() {
  local cache_path="$1"
  local max_age="${2:-86400}"  # 默认24小时
  
  if [ ! -f "$cache_path" ]; then
    return 1
  fi
  
  local file_age=$(($(date +%s) - $(stat -f%m "$cache_path" 2>/dev/null || stat -c%Y "$cache_path" 2>/dev/null)))
  [ "$file_age" -lt "$max_age" ]
}

# 从缓存读取（如果有效）
read_from_cache() {
  local url="$1"
  local cache_path=$(get_cache_path "$url")
  
  if is_cache_valid "$cache_path"; then
    dlog "从缓存读取：$url"
    cat "$cache_path"
    return 0
  fi
  
  return 1
}

# 写入缓存
write_to_cache() {
  local url="$1"
  local content="$2"
  local cache_path=$(get_cache_path "$url")
  
  echo "$content" > "$cache_path" 2>/dev/null || true
  dlog "已缓存：$url"
}

# 统一的文件下载函数（支持缓存）
download_file() {
  local url="$1"
  local output="$2"
  local timeout="${3:-120}"
  local use_cache="${4:-true}"
  
  dlog "开始下载：$url -> $output（缓存=$use_cache）"
  
  # 如果启用缓存，先尝试从缓存读取
  if [ "$use_cache" = "true" ]; then
    if cached_content=$(read_from_cache "$url"); then
      echo "$cached_content" > "$output"
      dlog "从缓存恢复：$url"
      return 0
    fi
  fi
  
  # 执行下载
  local downloaded_content=""
  if downloaded_content=$(curl -s --connect-timeout 5 --max-time "$timeout" --retry 2 --retry-delay 2 --retry-all-errors "$url" 2>/dev/null); then
    echo "$downloaded_content" > "$output"
    # 写入缓存
    [ "$use_cache" = "true" ] && write_to_cache "$url" "$downloaded_content"
    return 0
  elif downloaded_content=$(wget -qO- --tries=2 --timeout="$timeout" --dns-timeout=5 --read-timeout=60 "$url" 2>/dev/null); then
    echo "$downloaded_content" > "$output"
    # 写入缓存
    [ "$use_cache" = "true" ] && write_to_cache "$url" "$downloaded_content"
    return 0
  fi
  
  red "❌ 下载失败：$url"
  return 1
}

# 并行下载多个文件
# 用法：parallel_download_files "url1:output1" "url2:output2" ...
parallel_download_files() {
  local -a pids=()
  local -a specs=("$@")
  
  dlog "开始并行下载 ${#specs[@]} 个文件"
  
  # 启动所有下载任务
  for spec in "${specs[@]}"; do
    local url="${spec%:*}"
    local output="${spec#*:}"
    
    # 后台下载
    download_file "$url" "$output" 120 true &
    pids+=($!)
  done
  
  # 等待所有任务完成
  local failed=0
  for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
      ((failed++))
    fi
  done
  
  if [ "$failed" -gt 0 ]; then
    red "❌ 并行下载失败：$failed 个文件"
    return 1
  fi
  
  green "✅ 并行下载完成"
  return 0
}

# ================== Phase 33: 性能优化 END ==================

# ================== Phase 34: 错误恢复和重试机制 ==================

# 重试执行命令（带指数退避）
retry_with_backoff() {
  local max_attempts="${1:-3}"
  local initial_delay="${2:-1}"
  shift 2
  local cmd=("$@")
  
  local attempt=1
  local delay=$initial_delay
  
  while [ "$attempt" -le "$max_attempts" ]; do
    dlog "执行命令（尝试 $attempt/$max_attempts）：${cmd[*]}"
    
    if "${cmd[@]}"; then
      dlog "命令执行成功"
      return 0
    fi
    
    if [ "$attempt" -lt "$max_attempts" ]; then
      yellow "⏳ 命令失败，${delay}秒后重试..."
      sleep "$delay"
      # 指数退避：每次延迟翻倍
      delay=$((delay * 2))
    fi
    
    ((attempt++))
  done
  
  red "❌ 命令执行失败（已重试 $max_attempts 次）"
  return 1
}

# 备份文件（用于回滚）
backup_file() {
  local filepath="$1"
  local backup_dir="${2:-${AGSB_HOME}/.backups}"
  
  if [ ! -f "$filepath" ]; then
    dlog "文件不存在，跳过备份：$filepath"
    return 0
  fi
  
  mkdir -p "$backup_dir" || return 1
  
  local filename=$(basename "$filepath")
  local timestamp=$(date +%s)
  local backup_path="${backup_dir}/${filename}.${timestamp}.bak"
  
  if cp "$filepath" "$backup_path"; then
    dlog "文件已备份：$filepath -> $backup_path"
    echo "$backup_path"
    return 0
  else
    red "❌ 备份失败：$filepath"
    return 1
  fi
}

# 恢复文件（从备份）
restore_file() {
  local backup_path="$1"
  local target_path="$2"
  
  if [ ! -f "$backup_path" ]; then
    red "❌ 备份文件不存在：$backup_path"
    return 1
  fi
  
  if cp "$backup_path" "$target_path"; then
    dlog "文件已恢复：$backup_path -> $target_path"
    green "✅ 文件已恢复"
    return 0
  else
    red "❌ 恢复失败：$backup_path"
    return 1
  fi
}

# 获取最新的备份文件
get_latest_backup() {
  local filepath="$1"
  local backup_dir="${2:-${AGSB_HOME}/.backups}"
  local filename=$(basename "$filepath")
  
  # 查找最新的备份文件
  ls -t "${backup_dir}/${filename}".*.bak 2>/dev/null | head -n 1
}

# 自动恢复（如果当前文件损坏）
auto_restore_if_corrupted() {
  local filepath="$1"
  local check_cmd="${2:-}"
  
  if [ ! -f "$filepath" ]; then
    dlog "文件不存在：$filepath"
    return 1
  fi
  
  # 如果提供了检查命令，执行检查
  if [ -n "$check_cmd" ]; then
    if ! eval "$check_cmd '$filepath'" >/dev/null 2>&1; then
      yellow "⚠️ 文件检查失败，尝试从备份恢复：$filepath"
      
      local latest_backup=$(get_latest_backup "$filepath")
      if [ -n "$latest_backup" ]; then
        restore_file "$latest_backup" "$filepath"
        return $?
      else
        red "❌ 未找到备份文件"
        return 1
      fi
    fi
  fi
  
  return 0
}

# 事务性文件操作（原子性）
# 用法：atomic_write_file "filepath" "content"
atomic_write_file() {
  local filepath="$1"
  local content="$2"
  local temp_file="${filepath}.tmp.$"
  
  # 写入临时文件
  if ! echo "$content" > "$temp_file"; then
    red "❌ 无法写入临时文件：$temp_file"
    rm -f "$temp_file"
    return 1
  fi
  
  # 原子性移动（同一文件系统内）
  if ! mv "$temp_file" "$filepath"; then
    red "❌ 无法移动文件：$temp_file -> $filepath"
    rm -f "$temp_file"
    return 1
  fi
  
  dlog "文件已原子性写入：$filepath"
  return 0
}

# ================== Phase 34: 错误恢复和重试机制 END ==================

# ================== Phase 35: 日志和监控优化 ==================

# 日志级别常量
LOG_LEVEL_TRACE=0
LOG_LEVEL_DEBUG=1
LOG_LEVEL_INFO=2
LOG_LEVEL_WARN=3
LOG_LEVEL_ERROR=4
LOG_LEVEL_FATAL=5

# 当前日志级别（可通过环境变量覆盖）
LOG_LEVEL="${LOG_LEVEL:-$LOG_LEVEL_INFO}"

# 结构化日志输出
log_structured() {
  local level="$1"
  local message="$2"
  local context="${3:-}"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  
  # 构建日志行
  local log_line="[$timestamp] [$level]"
  [ -n "$context" ] && log_line="$log_line [$context]"
  log_line="$log_line $message"
  
  # 输出到日志文件
  echo "$log_line" >> "$AGSB_LOG_FILE" 2>/dev/null || true
  
  # 根据日志级别输出到控制台
  case "$level" in
    TRACE|DEBUG)
      [ "$DEBUG_FLAG" = "1" ] && echo "$log_line" >&2
      ;;
    INFO)
      green "ℹ️ $message"
      ;;
    WARN)
      yellow "⚠️ $message"
      ;;
    ERROR)
      red "❌ $message"
      ;;
    FATAL)
      red "💥 $message"
      ;;
  esac
}

# 简化的日志函数
log_trace() { log_structured "TRACE" "$1" "${2:-}"; }
log_debug() { log_structured "DEBUG" "$1" "${2:-}"; }
log_info() { log_structured "INFO" "$1" "${2:-}"; }
log_warn() { log_structured "WARN" "$1" "${2:-}"; }
log_error() { log_structured "ERROR" "$1" "${2:-}"; }
log_fatal() { log_structured "FATAL" "$1" "${2:-}"; }

# 性能计时器
declare -A PERF_TIMERS

# 启动性能计时
perf_start() {
  local timer_name="$1"
  PERF_TIMERS["${timer_name}_start"]=$(date +%s%N)
  dlog "性能计时开始：$timer_name"
}

# 停止性能计时并输出结果
perf_stop() {
  local timer_name="$1"
  local start_time="${PERF_TIMERS[${timer_name}_start]:-}"
  
  if [ -z "$start_time" ]; then
    log_warn "计时器不存在：$timer_name"
    return 1
  fi
  
  local end_time=$(date +%s%N)
  local elapsed_ns=$((end_time - start_time))
  local elapsed_ms=$((elapsed_ns / 1000000))
  local elapsed_s=$((elapsed_ms / 1000))
  
  if [ "$elapsed_s" -gt 0 ]; then
    log_info "性能计时：$timer_name = ${elapsed_s}s ${elapsed_ms}ms"
  else
    log_info "性能计时：$timer_name = ${elapsed_ms}ms"
  fi
  
  # 清理计时器
  unset PERF_TIMERS["${timer_name}_start"]
  
  return 0
}

# 事件追踪
declare -a EVENT_LOG

# 记录事件
track_event() {
  local event_type="$1"
  local event_data="$2"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  
  local event_entry="[$timestamp] $event_type: $event_data"
  EVENT_LOG+=("$event_entry")
  
  dlog "事件已记录：$event_entry"
}

# 显示事件日志
show_event_log() {
  local limit="${1:-50}"
  
  echo "========== 事件日志 =========="
  local count=0
  for event in "${EVENT_LOG[@]}"; do
    echo "$event"
    ((count++))
    [ "$count" -ge "$limit" ] && break
  done
  echo "=============================="
}

# 清空事件日志
clear_event_log() {
  EVENT_LOG=()
  dlog "事件日志已清空"
}

# 导出事件日志到文件
export_event_log() {
  local output_file="${1:-${AGSB_HOME}/event_log.txt}"
  
  {
    echo "========== agsb 事件日志 =========="
    echo "导出时间：$(date '+%Y-%m-%d %H:%M:%S')"
    echo "========================================"
    for event in "${EVENT_LOG[@]}"; do
      echo "$event"
    done
  } > "$output_file"
  
  green "✅ 事件日志已导出：$output_file"
  return 0
}

# ================== Phase 35: 日志和监控优化 END ==================

# ================== Phase 36: 安全性加固 ==================

# 验证和清理输入（防止注入攻击）
sanitize_input() {
  local input="$1"
  local allowed_chars="${2:-[a-zA-Z0-9._-]}"
  
  # 移除不允许的字符
  echo "$input" | sed "s/[^$allowed_chars]//g"
}

# 验证文件路径（防止路径遍历）
validate_file_path() {
  local filepath="$1"
  
  # 检查是否包含 .. 或其他危险模式
  if [[ "$filepath" =~ \.\. ]] || [[ "$filepath" =~ ^/ ]]; then
    return 1
  fi
  
  return 0
}

# 检查文件权限安全性
check_file_permissions() {
  local filepath="$1"
  local expected_perms="${2:-600}"
  
  if [ ! -f "$filepath" ]; then
    return 0
  fi
  
  local current_perms=$(stat -c%a "$filepath" 2>/dev/null || stat -f%A "$filepath" 2>/dev/null)
  
  if [ "$current_perms" != "$expected_perms" ]; then
    log_warn "文件权限不安全：$filepath（当前=$current_perms，期望=$expected_perms）"
    chmod "$expected_perms" "$filepath" 2>/dev/null || return 1
    log_info "文件权限已修复：$filepath"
  fi
  
  return 0
}

# 验证 UUID 格式
validate_uuid_format() {
  local uuid="$1"
  
  # UUID v4 格式：xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
  if [[ $uuid =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
    return 0
  fi
  
  return 1
}

# 验证 IP 地址格式
validate_ip_format() {
  local ip="$1"
  
  # IPv4 格式
  if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    # 检查每个八位组是否在 0-255 范围内
    local IFS='.'
    local -a octets=($ip)
    for octet in "${octets[@]}"; do
      [ "$octet" -gt 255 ] && return 1
    done
    return 0
  fi
  
  # IPv6 格式（简单检查）
  if [[ $ip =~ ^([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}$ ]]; then
    return 0
  fi
  
  return 1
}

# 验证端口范围
validate_port_range() {
  local port="$1"
  local min="${2:-1}"
  local max="${3:-65535}"
  
  if ! [[ "$port" =~ ^[0-9]+$ ]]; then
    return 1
  fi
  
  [ "$port" -ge "$min" ] && [ "$port" -le "$max" ]
}

# 检查命令是否存在且可执行
check_command_safe() {
  local cmd="$1"
  
  # 防止路径遍历
  if [[ "$cmd" =~ / ]]; then
    return 1
  fi
  
  has_cmd "$cmd"
}

# 安全的环境变量设置
set_env_safe() {
  local var_name="$1"
  local var_value="$2"
  
  # 验证变量名
  if ! [[ "$var_name" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    log_error "无效的环境变量名：$var_name"
    return 1
  fi
  
  # 设置环境变量
  export "$var_name=$var_value"
  dlog "环境变量已设置：$var_name"
  
  return 0
}

# 安全的命令执行（带超时和输出限制）
execute_safe() {
  local timeout="${1:-30}"
  shift
  local cmd=("$@")
  
  # 使用 timeout 命令限制执行时间
  if has_cmd timeout; then
    timeout "$timeout" "${cmd[@]}"
  else
    # 备选：使用 bash 的 SECONDS 变量
    ( "${cmd[@]}" ) &
    local pid=$!
    local count=0
    while kill -0 "$pid" 2>/dev/null && [ "$count" -lt "$timeout" ]; do
      sleep 1
      ((count++))
    done
    
    if kill -0 "$pid" 2>/dev/null; then
      kill -9 "$pid" 2>/dev/null
      return 124  # timeout 返回码
    fi
    
    wait "$pid"
  fi
}

# ================== Phase 36: 安全性加固 END ==================

# ================== Phase 37: 配置管理和状态持久化 ==================

# 配置版本管理
CONFIG_VERSION="1.0"
CONFIG_SCHEMA_VERSION="1"

# 保存配置快照
save_config_snapshot() {
  local snapshot_dir="${AGSB_HOME}/.snapshots"
  mkdir -p "$snapshot_dir" || return 1
  
  local timestamp=$(date +%s)
  local snapshot_file="${snapshot_dir}/config_${timestamp}.json"
  
  # 收集当前配置
  local config_json=$(cat <<EOF
{
  "version": "$CONFIG_VERSION",
  "schema_version": "$CONFIG_SCHEMA_VERSION",
  "timestamp": "$timestamp",
  "config": {
    "cdn_host": "$cdn_host",
    "hy_sni": "$hy_sni",
    "vl_sni": "$vl_sni",
    "tu_sni": "$tu_sni",
    "uuid": "$uuid",
    "trpt": "$trpt",
    "vlrt": "$vlrt",
    "hypt": "$hypt",
    "tupt": "$tupt",
    "argo": "$argo",
    "agn": "$ARGO_DOMAIN",
    "nginx_pt": "$nginx_pt",
    "subscribe": "$subscribe",
    "name": "$name"
  }
}
EOF
)
  
  echo "$config_json" > "$snapshot_file" || return 1
  dlog "配置快照已保存：$snapshot_file"
  
  return 0
}

# 列出配置快照
list_config_snapshots() {
  local snapshot_dir="${AGSB_HOME}/.snapshots"
  
  if [ ! -d "$snapshot_dir" ]; then
    log_info "未找到配置快照"
    return 0
  fi
  
  echo "========== 配置快照列表 =========="
  ls -lh "$snapshot_dir"/config_*.json 2>/dev/null | awk '{print $9, "(" $5 ")"}'
  echo "=================================="
}

# 恢复配置快照
restore_config_snapshot() {
  local snapshot_file="$1"
  
  if [ ! -f "$snapshot_file" ]; then
    log_error "快照文件不存在：$snapshot_file"
    return 1
  fi
  
  # 验证 JSON 格式
  if ! jq . "$snapshot_file" >/dev/null 2>&1; then
    log_error "快照文件格式无效：$snapshot_file"
    return 1
  fi
  
  # 提取配置并设置环境变量
  local config=$(jq -r '.config' "$snapshot_file")
  
  export cdn_host=$(echo "$config" | jq -r '.cdn_host')
  export hy_sni=$(echo "$config" | jq -r '.hy_sni')
  export vl_sni=$(echo "$config" | jq -r '.vl_sni')
  export tu_sni=$(echo "$config" | jq -r '.tu_sni')
  export uuid=$(echo "$config" | jq -r '.uuid')
  export trpt=$(echo "$config" | jq -r '.trpt')
  export vlrt=$(echo "$config" | jq -r '.vlrt')
  export hypt=$(echo "$config" | jq -r '.hypt')
  export tupt=$(echo "$config" | jq -r '.tupt')
  export argo=$(echo "$config" | jq -r '.argo')
  export ARGO_DOMAIN=$(echo "$config" | jq -r '.agn')
  export nginx_pt=$(echo "$config" | jq -r '.nginx_pt')
  export subscribe=$(echo "$config" | jq -r '.subscribe')
  export name=$(echo "$config" | jq -r '.name')
  
  log_info "配置已从快照恢复：$snapshot_file"
  return 0
}

# 状态文件管理
save_state() {
  local state_key="$1"
  local state_value="$2"
  local state_file="${AGSB_HOME}/.state"
  
  # 读取现有状态
  local state_json="{}"
  if [ -f "$state_file" ]; then
    state_json=$(cat "$state_file")
  fi
  
  # 更新状态
  state_json=$(echo "$state_json" | jq --arg key "$state_key" --arg value "$state_value" '.[$key] = $value')
  
  # 保存状态
  echo "$state_json" > "$state_file" || return 1
  dlog "状态已保存：$state_key=$state_value"
  
  return 0
}

# 读取状态
read_state() {
  local state_key="$1"
  local default_value="${2:-}"
  local state_file="${AGSB_HOME}/.state"
  
  if [ ! -f "$state_file" ]; then
    echo "$default_value"
    return 0
  fi
  
  local state_value=$(jq -r --arg key "$state_key" '.[$key] // empty' "$state_file" 2>/dev/null)
  
  if [ -z "$state_value" ]; then
    echo "$default_value"
  else
    echo "$state_value"
  fi
}

# 清空状态
clear_state() {
  local state_file="${AGSB_HOME}/.state"
  echo "{}" > "$state_file"
  dlog "状态已清空"
}

# 显示所有状态
show_all_state() {
  local state_file="${AGSB_HOME}/.state"
  
  if [ ! -f "$state_file" ]; then
    log_info "未找到状态文件"
    return 0
  fi
  
  echo "========== 系统状态 =========="
  jq . "$state_file" 2>/dev/null || cat "$state_file"
  echo "=============================="
}

# ================== Phase 37: 配置管理和状态持久化 END ==================

# ================== Phase 38: 诊断和调试工具 ==================

# 系统诊断报告
generate_diagnostic_report() {
  local report_file="${AGSB_HOME}/diagnostic_report.txt"
  
  {
    echo "========== agsb 系统诊断报告 =========="
    echo "生成时间：$(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    echo "========== 系统信息 =========="
    echo "操作系统：$(uname -s)"
    echo "内核版本：$(uname -r)"
    echo "CPU架构：$(uname -m)"
    echo "主机名：$(hostname)"
    echo ""
    
    echo "========== 磁盘空间 =========="
    df -h | head -n 5
    echo ""
    
    echo "========== 内存使用 =========="
    free -h 2>/dev/null || vm_stat 2>/dev/null || true
    echo ""
    
    echo "========== 网络连接 =========="
    echo "IPv4 连接性："
    curl -s4 -m 2 https://icanhazip.com 2>/dev/null || echo "无法连接"
    echo "IPv6 连接性："
    curl -s6 -m 2 https://icanhazip.com 2>/dev/null || echo "无法连接"
    echo ""
    
    echo "========== 关键进程 =========="
    pgrep -f "sing-box" >/dev/null && echo "✅ sing-box 运行中" || echo "❌ sing-box 未运行"
    pgrep -f "cloudflared" >/dev/null && echo "✅ cloudflared 运行中" || echo "❌ cloudflared 未运行"
    pgrep -f "nginx" >/dev/null && echo "✅ nginx 运行中" || echo "❌ nginx 未运行"
    echo ""
    
    echo "========== 关键端口 =========="
    ss -tlnp 2>/dev/null | grep -E ":(${trpt}|${vlrt}|${hypt}|${tupt}|${nginx_pt})" || echo "未检测到关键端口"
    echo ""
    
    echo "========== 日志文件 =========="
    [ -f "$AGSB_LOG_FILE" ] && echo "✅ 日志文件存在：$AGSB_LOG_FILE（大小：$(du -h "$AGSB_LOG_FILE" | awk '{print $1}')）" || echo "❌ 日志文件不存在"
    echo ""
    
    echo "========== 配置文件 =========="
    [ -f "$AGSB_CONFIG" ] && echo "✅ 配置文件存在：$AGSB_CONFIG" || echo "❌ 配置文件不存在"
    echo ""
    
    echo "========== 环境变量 =========="
    echo "DEBUG_FLAG=$DEBUG_FLAG"
    echo "subscribe=$subscribe"
    echo "argo=$argo"
    echo ""
    
    echo "========== 依赖检查 =========="
    for cmd in curl wget jq openssl iptables ss lsof; do
      has_cmd "$cmd" && echo "✅ $cmd" || echo "❌ $cmd"
    done
    echo ""
    
    echo "========== 最后更新 =========="
    [ -f "$AGSB_BIN" ] && echo "sing-box 修改时间：$(stat -f%Sm -t '%Y-%m-%d %H:%M:%S' "$AGSB_BIN" 2>/dev/null || stat -c%y "$AGSB_BIN" 2>/dev/null | cut -d' ' -f1-2)"
    echo ""
    
    echo "========== 诊断完成 =========="
  } > "$report_file"
  
  green "✅ 诊断报告已生成：$report_file"
  cat "$report_file"
  
  return 0
}

# 性能分析
analyze_performance() {
  local analysis_file="${AGSB_HOME}/performance_analysis.txt"
  
  {
    echo "========== agsb 性能分析 =========="
    echo "分析时间：$(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    echo "========== 进程资源使用 =========="
    ps aux 2>/dev/null | grep -E "sing-box|cloudflared|nginx" | grep -v grep || echo "未找到相关进程"
    echo ""
    
    echo "========== 网络连接统计 =========="
    netstat -an 2>/dev/null | grep -E "ESTABLISHED|LISTEN" | wc -l
    echo ""
    
    echo "========== 文件描述符使用 =========="
    for pid in $(pgrep -f "sing-box|cloudflared|nginx"); do
      echo "PID $pid: $(ls -1 /proc/$pid/fd 2>/dev/null | wc -l) 个文件描述符"
    done
    echo ""
    
    echo "========== 磁盘 I/O =========="
    iostat -x 1 2 2>/dev/null | tail -n 5 || echo "iostat 不可用"
    echo ""
    
  } > "$analysis_file"
  
  green "✅ 性能分析已生成：$analysis_file"
  cat "$analysis_file"
  
  return 0
}

# 调试模式启用
enable_debug_mode() {
  export DEBUG_FLAG=1
  save_state "debug_mode" "enabled"
  log_info "调试模式已启用"
  return 0
}

# 调试模式禁用
disable_debug_mode() {
  export DEBUG_FLAG=0
  save_state "debug_mode" "disabled"
  log_info "调试模式已禁用"
  return 0
}

# 显示调试信息
show_debug_info() {
  echo "========== 调试信息 =========="
  echo "DEBUG_FLAG=$DEBUG_FLAG"
  echo "AGSB_HOME=$AGSB_HOME"
  echo "AGSB_CONFIG=$AGSB_CONFIG"
  echo "AGSB_LOG_FILE=$AGSB_LOG_FILE"
  echo "当前参数："
  echo "  cdn_host=$cdn_host"
  echo "  uuid=$uuid"
  echo "  argo=$argo"
  echo "  subscribe=$subscribe"
  echo "  name=$name"
  echo "=============================="
}

# 清理日志和缓存
cleanup_logs_and_cache() {
  local days="${1:-7}"
  
  log_info "清理 $days 天前的日志和缓存..."
  
  # 清理日志
  find "$AGSB_LOG_DIR" -type f -mtime "+$days" -delete 2>/dev/null || true
  
  # 清理缓存
  find "$AGSB_CACHE_DIR" -type f -mtime "+$days" -delete 2>/dev/null || true
  
  # 清理备份
  find "${AGSB_HOME}/.backups" -type f -mtime "+$days" -delete 2>/dev/null || true
  
  log_info "清理完成"
  return 0
}

# ================== Phase 38: 诊断和调试工具 END ==================

# ================== Phase 39: API 和集成接口 ==================

# API 版本
API_VERSION="1.0"

# 获取 API 版本
api_get_version() {
  echo "$API_VERSION"
}

# 获取脚本版本
api_get_script_version() {
  echo "$VERSION"
}

# 获取系统状态
api_get_status() {
  local status_json=$(cat <<EOF
{
  "version": "$API_VERSION",
  "script_version": "$VERSION",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": {
    "singbox_running": $(pgrep -f "sing-box" >/dev/null && echo "true" || echo "false"),
    "cloudflared_running": $(pgrep -f "cloudflared" >/dev/null && echo "true" || echo "false"),
    "nginx_running": $(pgrep -f "nginx" >/dev/null && echo "true" || echo "false")
  },
  "config": {
    "argo": "$argo",
    "subscribe": "$subscribe",
    "name": "$name"
  }
}
EOF
)
  echo "$status_json"
}

# 获取节点信息
api_get_node_info() {
  local node_json=$(cat <<EOF
{
  "name": "$name",
  "protocols": {
    "trojan": $([ -n "$trpt" ] && echo "true" || echo "false"),
    "vless": $([ -n "$vlrt" ] && echo "true" || echo "false"),
    "hysteria2": $([ -n "$hypt" ] && echo "true" || echo "false"),
    "tuic": $([ -n "$tupt" ] && echo "true" || echo "false")
  },
  "argo": {
    "enabled": $([ -n "$argo" ] && echo "true" || echo "false"),
    "type": "$argo"
  },
  "subscribe": $([ "$subscribe" = "true" ] && echo "true" || echo "false")
}
EOF
)
  echo "$node_json"
}

# 获取日志
api_get_logs() {
  local lines="${1:-100}"
  
  if [ -f "$AGSB_LOG_FILE" ]; then
    tail -n "$lines" "$AGSB_LOG_FILE"
  else
    echo "[]"
  fi
}

# 执行命令（受限的 API）
api_execute_command() {
  local cmd="$1"
  
  case "$cmd" in
    restart)
      cmd_restart_services
      ;;
    status)
      api_get_status
      ;;
    logs)
      api_get_logs
      ;;
    *)
      log_error "未知命令：$cmd"
      return 1
      ;;
  esac
}

# Webhook 支持
declare -A WEBHOOKS

# 注册 webhook
register_webhook() {
  local event="$1"
  local url="$2"
  
  WEBHOOKS["$event"]="$url"
  dlog "Webhook 已注册：$event -> $url"
}

# 触发 webhook
trigger_webhook() {
  local event="$1"
  local data="${2:-}"
  local url="${WEBHOOKS[$event]:-}"
  
  if [ -z "$url" ]; then
    dlog "未找到 webhook：$event"
    return 0
  fi
  
  dlog "触发 webhook：$event -> $url"
  
  # 异步发送 webhook
  (
    curl -s -X POST "$url" \
      -H "Content-Type: application/json" \
      -d "{\"event\":\"$event\",\"data\":$data,\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
      >/dev/null 2>&1
  ) &
}

# 列出所有 webhook
list_webhooks() {
  echo "========== 已注册的 Webhooks =========="
  for event in "${!WEBHOOKS[@]}"; do
    echo "$event -> ${WEBHOOKS[$event]}"
  done
  echo "======================================"
}

# 导出 API 文档
export_api_docs() {
  local docs_file="${AGSB_HOME}/api_docs.md"
  
  cat > "$docs_file" <<'EOF'
# agsb API 文档

## 版本
- API 版本：1.0
- 脚本版本：见 api_get_script_version()

## 可用的 API 函数

### 系统信息
- `api_get_version()` - 获取 API 版本
- `api_get_script_version()` - 获取脚本版本
- `api_get_status()` - 获取系统状态（JSON）
- `api_get_node_info()` - 获取节点信息（JSON）
- `api_get_logs [lines]` - 获取日志（默认100行）

### 命令执行
- `api_execute_command <cmd>` - 执行命令
  - restart: 重启服务
  - status: 获取状态
  - logs: 获取日志

### Webhook 支持
- `register_webhook <event> <url>` - 注册 webhook
- `trigger_webhook <event> [data]` - 触发 webhook
- `list_webhooks` - 列出所有 webhook

## 使用示例

```bash
# 获取系统状态
source sb00.sh
api_get_status | jq .

# 获取节点信息
api_get_node_info | jq .

# 注册 webhook
register_webhook "service_restart" "https://example.com/webhook"

# 触发 webhook
trigger_webhook "service_restart" '{"status":"success"}'
```

## 返回格式

所有 API 函数返回 JSON 格式的数据。

EOF

  green "✅ API 文档已导出：$docs_file"
  return 0
}

# ================== Phase 39: API 和集成接口 END ==================

# ================== Phase 40: 文档和帮助系统 ==================

# 显示帮助信息
show_help() {
  cat <<'EOF'
========== agsb 脚本帮助 ==========

用法：bash sb00.sh [命令] [选项]

命令列表：
  ins              - 安装 agsb（需要环境变量）
  rep              - 覆盖式安装（需要环境变量）
  del              - 卸载 agsb
  list             - 显示节点信息
  config           - 生成配置文件模板
  res              - 重启服务
  ups              - 更新 sing-box 内核
  sub              - 显示订阅信息
  autostart        - 启用开机自启
  autostart_off    - 禁用开机自启
  nginx_start      - 启动 Nginx
  nginx_stop       - 停止 Nginx
  nginx_restart    - 重启 Nginx
  nginx_status     - 查看 Nginx 状态

环境变量（安装时使用）：
  cdn_host         - CDN 主机（默认：saas.sin.fan）
  hy_sni           - Hysteria2 SNI（默认：www.microsoft.com）
  vl_sni           - VLESS SNI（默认：www.microsoft.com）
  tu_sni           - TUIC SNI（默认：www.microsoft.com）
  uuid             - UUID（必填）
  trpt             - Trojan 端口
  vlrt             - VLESS 端口
  hypt             - Hysteria2 端口
  tupt             - TUIC 端口
  argo             - Argo 协议（trpt 或 vmpt）
  agn              - Argo 域名
  agk              - Argo 凭据（JSON）
  nginx_pt         - Nginx 端口（默认：8080）
  subscribe        - 启用订阅（true/false）
  name             - 节点名称
  DEBUG_FLAG       - 调试模式（0/1）

示例：
  # 安装脚本
  cdn_host="saas.sin.fan" uuid="xxx" trpt=33952 bash sb00.sh ins

  # 生成配置文件
  bash sb00.sh config

  # 显示节点信息
  bash sb00.sh list

  # 重启服务
  bash sb00.sh res

更多信息：https://github.com/jyucoeng/singbox-tools

EOF
}

# 显示命令参考
show_command_reference() {
  cat <<'EOF'
========== agsb 命令参考 ==========

【安装和卸载】
  agsb ins    - 安装（需要环境变量）
  agsb rep    - 覆盖式安装（需要环境变量）
  agsb del    - 卸载

【配置管理】
  agsb config - 生成配置文件模板

【服务管理】
  agsb res    - 重启所有服务
  agsb ups    - 更新 sing-box 内核

【信息查询】
  agsb list   - 显示节点信息
  agsb sub    - 显示订阅信息

【自启管理】
  agsb autostart     - 启用开机自启
  agsb autostart_off - 禁用开机自启

【Nginx 管理】
  agsb nginx_start   - 启动 Nginx
  agsb nginx_stop    - 停止 Nginx
  agsb nginx_restart - 重启 Nginx
  agsb nginx_status  - 查看 Nginx 状态

====================================

EOF
}

# 显示环境变量参考
show_env_reference() {
  cat <<'EOF'
========== 环境变量参考 ==========

【必填参数】
  uuid              - UUID（格式：xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx）

【CDN 和 SNI 配置】
  cdn_host          - CDN 主机（默认：saas.sin.fan）
  cdn_pt            - CDN 端口（默认：443）
  hy_sni            - Hysteria2 SNI（默认：www.microsoft.com）
  vl_sni            - VLESS SNI（默认：www.microsoft.com）
  vl_sni_pt         - VLESS SNI 端口（默认：443）
  tu_sni            - TUIC SNI（默认：www.microsoft.com）

【协议端口】
  trpt              - Trojan 端口（可选，不设置则自动生成）
  vlrt              - VLESS 端口（可选，不设置则自动生成）
  hypt              - Hysteria2 端口（可选，不设置则自动生成）
  tupt              - TUIC 端口（可选，不设置则自动生成）

【Argo 隧道配置】
  argo              - Argo 协议（trpt 或 vmpt）
  agn               - Argo 域名
  agk               - Argo 凭据（JSON 格式）
  ippz              - IP 优先级（可选）

【服务端口】
  nginx_pt          - Nginx 端口（默认：8080）
  argo_pt           - Argo 端口（默认：8001）

【功能开关】
  subscribe         - 启用订阅（true/false，默认：false）
  reality_private   - Reality 私钥
  reality_public    - Reality 公钥
  name              - 节点名称

【调试选项】
  DEBUG_FLAG        - 调试模式（0/1，默认：0）

====================================

EOF
}

# 显示配置文件示例
show_config_example() {
  cat <<'EOF'
========== 配置文件示例 ==========

# ~/.agsb/config

# CDN 和 SNI 配置
cdn_host=saas.sin.fan
hy_sni=www.microsoft.com
vl_sni=www.microsoft.com
tu_sni=www.microsoft.com

# 端口配置
uuid=0631a7f3-09f8-4144-acf2-a4f5bd9ed281
trpt=33952
vlrt=33953
hypt=33954
tupt=33955

# Argo 隧道配置
argo=trpt
agn=ca-tower-wong.dora.cc.cd

# 服务端口
nginx_pt=33956
argo_pt=8001

# 功能开关
subscribe=true
name=小叮当-加拿大-tower-wong

# 调试开关
DEBUG_FLAG=0

====================================

EOF
}

# 生成完整文档
generate_full_documentation() {
  local doc_file="${AGSB_HOME}/DOCUMENTATION.md"
  
  cat > "$doc_file" <<'EOF'
# agsb 完整文档

## 目录
1. [快速开始](#快速开始)
2. [安装](#安装)
3. [配置](#配置)
4. [命令参考](#命令参考)
5. [环境变量](#环境变量)
6. [故障排除](#故障排除)
7. [API 参考](#api-参考)

## 快速开始

### 最简单的安装方式

```bash
# 使用环境变量安装
uuid="your-uuid" trpt=33952 bash sb00.sh ins
```

### 使用配置文件安装

```bash
# 生成配置文件
bash sb00.sh config

# 编辑 ~/.agsb/config

# 运行安装
bash sb00.sh ins
```

## 安装

### 前置要求
- Linux 系统（Debian/Ubuntu/CentOS/Alpine）
- 至少 512MB 内存
- 至少 1GB 磁盘空间

### 安装步骤

1. 下载脚本
```bash
curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb00.sh -o sb00.sh
```

2. 设置环境变量
```bash
export uuid="your-uuid"
export trpt=33952
export vlrt=33953
```

3. 运行安装
```bash
bash sb00.sh ins
```

## 配置

### 配置文件位置
- 用户级：`~/.agsb/config`
- 系统级：`/etc/agsb/config`

### 参数优先级
1. 命令行环境变量（最高）
2. 配置文件
3. 默认值（最低）

## 命令参考

### 安装和卸载
- `bash sb00.sh ins` - 安装
- `bash sb00.sh rep` - 覆盖式安装
- `bash sb00.sh del` - 卸载

### 服务管理
- `bash sb00.sh res` - 重启服务
- `bash sb00.sh ups` - 更新内核

### 信息查询
- `bash sb00.sh list` - 显示节点信息
- `bash sb00.sh sub` - 显示订阅信息

## 环境变量

### 必填参数
- `uuid` - UUID（必填）

### 可选参数
- `cdn_host` - CDN 主机
- `trpt` - Trojan 端口
- `vlrt` - VLESS 端口
- `hypt` - Hysteria2 端口
- `tupt` - TUIC 端口
- `argo` - Argo 协议
- `name` - 节点名称

## 故障排除

### 常见问题

**Q: 安装失败，提示缺少依赖**
A: 脚本会自动安装依赖，如果仍然失败，请检查网络连接和包管理器。

**Q: 节点无法连接**
A: 检查防火墙设置和端口是否开放。

**Q: 如何查看日志**
A: 日志文件位于 `~/agsb/logs/agsb.log`

## API 参考

### 获取系统状态
```bash
source sb00.sh
api_get_status | jq .
```

### 获取节点信息
```bash
api_get_node_info | jq .
```

### 执行命令
```bash
api_execute_command restart
```

EOF

  green "✅ 完整文档已生成：$doc_file"
  return 0
}

# ================== Phase 40: 文档和帮助系统 END ==================

# 统一的文件验证函数
verify_file() {
  local filepath="$1"
  local error_msg="${2:-文件验证失败}"
  
  if [ ! -s "$filepath" ]; then
    red "❌ $error_msg：文件为空或不存在 $filepath"
    return 1
  fi
  
  dlog "文件验证成功：$filepath"
  return 0
}

# 统一的二进制文件安装函数
install_binary() {
  local filepath="$1"
  local version_cmd="${2:-}"
  
  chmod +x "$filepath" || return 1
  
  if [ -n "$version_cmd" ]; then
    local version=$($version_cmd 2>/dev/null | awk '/version/{print $NF}')
    dlog "已安装版本：$version"
    green "✅ 已安装：$version"
  fi
  
  return 0
}

# ================== Phase 19: 下载和验证优化 END ==================

# ================== Phase 19: 条件判断优化 ==================
# 统一的条件检查函数
check_condition() {
  local condition="$1"
  local true_action="$2"
  local false_action="${3:-}"
  
  if eval "$condition"; then
    [ -n "$true_action" ] && eval "$true_action"
    return 0
  else
    [ -n "$false_action" ] && eval "$false_action"
    return 1
  fi
}

# 判断是否需要Nginx
need_nginx_service() {
  if is_true "$(get_subscribe_flag)"; then
    return 0
  fi
  
  if need_argo; then
    return 0
  fi
  
  return 1
}

# 统一的服务启动检查
check_service_status() {
  local service="$1"
  
  if pgrep -f "$service" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

# ================== Phase 19: 条件判断优化 END ==================

# ================== Phase 20: 服务重启优化 ==================
# 统一的服务重启函数
restart_service() {
  local service="$1"
  local binary="${2:-}"
  local fallback_cmd="${3:-}"
  
  dlog "重启服务：$service"
  
  # 先停止现有进程
  if [ -n "$binary" ]; then
    pkill -15 -f "$binary" 2>/dev/null
  fi
  
  # 使用systemd重启
  if has_systemd; then
    systemctl restart "$service" 2>/dev/null && return 0
  fi
  
  # 使用openrc重启
  if has_cmd rc-service; then
    rc-service "$service" restart 2>/dev/null && return 0
  fi
  
  # 使用fallback命令
  if [ -n "$fallback_cmd" ]; then
    eval "$fallback_cmd" && return 0
  fi
  
  red "❌ 无法重启服务：$service"
  return 1
}

# 统一的服务启动函数
start_service() {
  local service="$1"
  local fallback_cmd="${2:-}"
  
  dlog "启动服务：$service"
  
  # 使用systemd启动
  if has_systemd; then
    systemctl start "$service" 2>/dev/null && return 0
  fi
  
  # 使用openrc启动
  if has_cmd rc-service; then
    rc-service "$service" start 2>/dev/null && return 0
  fi
  
  # 使用fallback命令
  if [ -n "$fallback_cmd" ]; then
    eval "$fallback_cmd" && return 0
  fi
  
  red "❌ 无法启动服务：$service"
  return 1
}

# 统一的服务停止函数
stop_service() {
  local service="$1"
  local binary="${2:-}"
  
  dlog "停止服务：$service"
  
  # 先停止进程
  if [ -n "$binary" ]; then
    pkill -15 -f "$binary" 2>/dev/null
  fi
  
  # 使用systemd停止
  if has_systemd; then
    systemctl stop "$service" 2>/dev/null && return 0
  fi
  
  # 使用openrc停止
  if has_cmd rc-service; then
    rc-service "$service" stop 2>/dev/null && return 0
  fi
  
  return 0
}

# ================== Phase 20: 服务重启优化 END ==================

# ================== Phase 20: 错误处理优化 ==================
# 统一的错误处理函数
handle_error() {
  local error_msg="$1"
  local exit_code="${2:-1}"
  
  red "❌ $error_msg"
  dlog "错误：$error_msg (代码: $exit_code)"
  
  if [ "$exit_code" -ne 0 ]; then
    return "$exit_code"
  fi
}

# 统一的成功处理函数
handle_success() {
  local success_msg="$1"
  
  green "✅ $success_msg"
  dlog "成功：$success_msg"
}

# 统一的信息输出函数
handle_info() {
  local info_msg="$1"
  
  yellow "ℹ️ $info_msg"
  dlog "信息：$info_msg"
}

# 统一的警告输出函数
handle_warning() {
  local warning_msg="$1"
  
  yellow "⚠️ $warning_msg"
  dlog "警告：$warning_msg"
}

# ================== Phase 20: 错误处理优化 END ==================

# Nginx按需安装流程
install_nginx_phase() {
  dlog "Phase 2: 按需安装 Nginx"
  ensure_nginx_if_needed || return 1
  dlog "Nginx 已确保安装/启动"
}

# Argo启动流程
install_argo_phase() {
  if ! need_argo || [ -z "$vmag" ]; then
    dlog "跳过 Argo 启动"
    return 0
  fi

  dlog "Phase 3: 启动 Argo"
  echo
  echo "=========启用Cloudflared-argo内核========="

  ensure_cloudflared_if_needed || {
    red "❌ 已启用 Argo，但 cloudflared 准备失败"
    return 1
  }

  # 记录协议类型
  record_argo_protocol_type "$argo"

  # 设置Argo端口
  local argoport="${argo_pt:-$ARGO_DEFAULT_PORT}"
  write_agsb_file "argoport.log" "$argoport"

  # 生成凭据
  prepare_argo_credentials "$ARGO_AUTH" "$ARGO_DOMAIN" "$argoport"

  # 启动Argo
  if [ -n "$ARGO_DOMAIN" ] && [ -n "$ARGO_AUTH" ]; then
    dlog "启动固定 Argo 隧道"
    start_argo_with_method "$ARGO_MODE" "$ARGO_AUTH" "$argoport"
    write_agsb_file "sbargoym.log" "$ARGO_DOMAIN"
    [ "$ARGO_MODE" = "token" ] && write_agsb_file "sbargotoken.log" "$ARGO_AUTH"
    wait_and_check_argo "固定"
  else
    dlog "启动临时 Argo 隧道"
    start_argo_no_daemon "temp" "" "$argoport"
    wait_and_check_argo "临时"
  fi
}

# ================== Phase 16: ins函数优化 END ==================


# ================== Phase 24: 进程检查优化 ==================
# 检查sing-box进程是否运行
is_singbox_running() {
  pgrep -f "$AGSB_HOME/sing-box" >/dev/null 2>&1
}

# 检查cloudflared进程是否运行
is_cloudflared_running() {
  pgrep -f "$AGSB_HOME/cloudflared" >/dev/null 2>&1
}

# 检查sing-box或cloudflared是否运行
is_agsb_running() {
  is_singbox_running || is_cloudflared_running
}

# ================== Phase 24: 进程检查优化 END ==================

# ================== Phase 25: 端口读取优化 ==================
# 通用的端口读取函数
read_port() {
  local port_file="$1"
  cat "$AGSB_HOME/$port_file" 2>/dev/null
}

# 读取Hysteria2端口
read_hy2_port() {
  read_port "port_hy2"
}

# 读取TUIC端口
read_tuic_port() {
  read_port "port_tu"
}

# 读取VLESS-Reality端口
read_vless_reality_port() {
  read_port "port_vlr"
}

# 读取Trojan端口
read_trojan_port() {
  read_port "port_tr"
}

# 读取Vmess端口
read_vmess_port() {
  read_port "port_vm_ws"
}

# 读取Argo端口
read_argo_port() {
  read_port "argoport.log"
}

# ================== Phase 25: 端口读取优化 END ==================

# ================== Phase 26: Argo启动流程优化 ==================
# 记录Argo协议类型
record_argo_protocol_type() {
  local argo_type="$1"
  
  if [ "$argo_type" = "vmpt" ]; then
    write_agsb_file "vlvm" "Vmess"
  elif [ "$argo_type" = "trpt" ]; then
    write_agsb_file "vlvm" "Trojan"
  fi
}

# 启动Argo服务（根据系统类型选择启动方式）
start_argo_service() {
  local argo_mode="$1"
  local argo_auth="$2"
  local argo_port="$3"
  
  dlog "start_argo_service：开始启动Argo服务，模式=${argo_mode}"
  
  if has_systemd && [ "$EUID" -eq 0 ]; then
    dlog "启动方式：systemd 服务"
    install_argo_service_systemd "$argo_mode" "$argo_auth"
  elif has_cmd rc-service && [ "$EUID" -eq 0 ]; then
    dlog "启动方式：openrc 服务"
    install_argo_service_openrc "$argo_mode" "$argo_auth"
  else
    dlog "启动方式：无 systemd/openrc，直接后台启动"
    start_argo_no_daemon "$argo_mode" "$argo_auth" "$argo_port"
  fi
}

# 处理固定Argo隧道
handle_fixed_argo_tunnel() {
  local argo_domain="$1"
  local argo_auth="$2"
  local argo_mode="$3"
  
  dlog "处理固定Argo隧道：domain=${argo_domain}"
  
  # 启动Argo服务
  start_argo_service "$argo_mode" "$argo_auth" "$argoport"
  
  # 保存域名和token
  write_agsb_file "sbargoym.log" "$argo_domain"
  [ "$argo_mode" = "token" ] && write_agsb_file "sbargotoken.log" "$argo_auth"
}

# 处理临时Argo隧道
handle_temp_argo_tunnel() {
  local argo_port="$1"
  
  dlog "处理临时Argo隧道"
  start_argo_no_daemon "temp" "" "$argo_port"
}

# ================== Phase 26: Argo启动流程优化 END ==================

# ================== Phase 27: Argo重启优化 ==================
# 启动JSON固定隧道
start_argo_json_tunnel() {
  dlog "启动JSON固定隧道"
  nohup "$AGSB_HOME/cloudflared" tunnel \
    --edge-ip-version auto \
    --config "$AGSB_HOME/tunnel.yml" run \
    >/dev/null 2>&1 &
}

# 启动token固定隧道
start_argo_token_tunnel() {
  dlog "启动token固定隧道"
  nohup "$AGSB_HOME/cloudflared" tunnel \
    --no-autoupdate \
    --edge-ip-version auto run \
    --token "$(cat "$AGSB_HOME/sbargotoken.log")" \
    >/dev/null 2>&1 &
}

# 启动临时Argo隧道
start_argo_temp_tunnel() {
  dlog "启动临时Argo隧道"
  nohup "$AGSB_HOME/cloudflared" tunnel \
    --url "http://localhost:$(cat "$AGSB_HOME/argoport.log")" \
    --edge-ip-version auto \
    --no-autoupdate \
    > "$AGSB_HOME/argo.log" 2>&1 &
}

# ================== Phase 27: Argo重启优化 END ==================

# ================== Phase 28: 批量操作优化 ==================
# 批量写入配置文件
write_config_batch() {
  local -a configs=(
    "vl_sni:${vl_sni}"
    "hy_sni:${hy_sni}"
    "tu_sni:${tu_sni}"
    "cdn_host:${cdn_host}"
    "cdn_pt:${cdn_pt}"
    "nginx_port:${nginx_pt}"
    "vl_sni_pt:${vl_sni_pt}"
    "subscribe:${subscribe}"
  )
  
  local config
  for config in "${configs[@]}"; do
    local key="${config%%:*}"
    local value="${config#*:}"
    write_agsb_file "$key" "$value"
  done
}

# 检查sing-box是否运行
is_singbox_running_verbose() {
  if pgrep -f "$AGSB_HOME/sing-box" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

# 检查cloudflared是否运行
is_cloudflared_running_verbose() {
  if pgrep -f "$AGSB_HOME/cloudflared" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

# ================== Phase 28: 批量操作优化 END ==================


main(){
  # Phase 32: 加载配置文件（参数优先级：命令行 > 配置文件 > 默认值）
  load_config_file || true
  
  check_port_conflicts_or_exit

  # 如果没有参数，显示菜单
  if [ -z "$1" ]; then
    showmode
    return 0
  fi

  # 分发命令
  if dispatch_command "$1" "$2"; then
    exit 0
  fi

  # 未知命令
  red "❌ 未知命令：$1"
  showmode
  exit 1
}

# ================== Phase 29: 参数验证优化 ==================
# 验证UUID格式
validate_uuid() {
  local uuid="$1"
  if [[ $uuid =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
    return 0
  else
    return 1
  fi
}

# 验证端口号
validate_port() {
  local port="$1"
  if [[ $port =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
    return 0
  else
    return 1
  fi
}

# 验证所有协议端口
validate_protocol_ports() {
  local -a ports=(
    "trpt:$trpt"
    "vlrt:$vlrt"
    "hypt:$hypt"
    "tupt:$tupt"
  )
  
  local port_entry
  for port_entry in "${ports[@]}"; do
    local name="${port_entry%%:*}"
    local port="${port_entry#*:}"
    
    if [ -n "$port" ]; then
      if ! validate_port "$port"; then
        red "❌ 无效的端口号：${name}=${port}"
        return 1
      fi
    fi
  done
  
  return 0
}

# 验证协议端口之间没有冲突
validate_protocol_port_conflicts() {
  local -a ports=()
  
  [ -n "$trpt" ] && ports+=("$trpt")
  [ -n "$vlrt" ] && ports+=("$vlrt")
  [ -n "$hypt" ] && ports+=("$hypt")
  [ -n "$tupt" ] && ports+=("$tupt")
  
  # 检查是否有重复
  local i j
  for ((i=0; i<${#ports[@]}; i++)); do
    for ((j=i+1; j<${#ports[@]}; j++)); do
      if [ "${ports[$i]}" = "${ports[$j]}" ]; then
        red "❌ 协议端口冲突：多个协议使用同一端口 ${ports[$i]}"
        return 1
      fi
    done
  done
  
  return 0
}

# 统一的参数验证函数
validate_all_params() {
  dlog "开始验证所有参数"
  
  # 验证UUID
  if [ -n "$uuid" ]; then
    if ! validate_uuid "$uuid"; then
      red "❌ UUID格式无效：$uuid"
      return 1
    fi
  fi
  
  # 验证协议端口
  if ! validate_protocol_ports; then
    return 1
  fi
  
  # 验证协议端口冲突
  if ! validate_protocol_port_conflicts; then
    return 1
  fi
  
  dlog "参数验证通过"
  return 0
}

# ================== Phase 29: 参数验证优化 END ==================

# ================== Phase 30: Argo启动流程统一优化 ==================
# 统一的Argo启动流程
start_argo_unified() {
  dlog "开始统一Argo启动流程"
  
  # 1. 确保cloudflared存在
  ensure_cloudflared_if_needed || {
    red "❌ 已启用 Argo，但 cloudflared 准备失败，无法继续启用 Argo"
    return 1
  }
  dlog "cloudflared 已准备就绪"
  
  # 2. 计算Argo本地端口
  local argoport="${argo_pt:-$ARGO_DEFAULT_PORT}"
  dlog "Argo 本地回源端口 argoport=${argoport}"
  write_agsb_file "argoport.log" "$argoport"
  
  # 3. 记录Argo协议类型
  record_argo_protocol_type "$argo"
  
  # 4. 生成Argo凭据
  prepare_argo_credentials "$ARGO_AUTH" "$ARGO_DOMAIN" "$argoport"
  dlog "prepare_argo_credentials 完成：ARGO_MODE=${ARGO_MODE:-<未设置>}"
  
  # 5. 启动Argo（固定或临时）
  local argo_tunnel_type
  if [ -n "$ARGO_DOMAIN" ] && [ -n "$ARGO_AUTH" ]; then
    argo_tunnel_type="固定"
    dlog "判定为固定 Argo 隧道"
    handle_fixed_argo_tunnel "$ARGO_DOMAIN" "$ARGO_AUTH" "$ARGO_MODE"
  else
    argo_tunnel_type="临时"
    dlog "判定为临时 Argo 隧道"
    handle_temp_argo_tunnel "$argoport"
  fi
  
  # 6. 等待并检查Argo申请结果
  dlog "开始等待并检查 Argo 申请结果：tunnel_type=${argo_tunnel_type}"
  wait_and_check_argo "$argo_tunnel_type"
}

# ================== Phase 30: Argo启动流程统一优化 END ==================

# ================== Phase 31: 扩展参数验证 ==================
# 验证SNI格式
validate_sni() {
  local sni="$1"
  # SNI应该是有效的域名格式
  if [[ $sni =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]] || [ "$sni" = "localhost" ]; then
    return 0
  else
    return 1
  fi
}

# 验证CDN主机
validate_cdn_host() {
  local cdn_host="$1"
  
  # 验证域名格式（标准域名）
  if [[ $cdn_host =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
    return 0
  fi
  
  # 验证 IPv4 格式（宽松验证，用户一般会注意格式）
  if [[ $cdn_host =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    return 0
  fi
  
  # 验证 IPv6 格式（支持多种格式）
  # 1. 完整格式：xxxx:xxxx:xxxx:xxxx:xxxx:xxxx:xxxx:xxxx
  if [[ $cdn_host =~ ^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$ ]]; then
    return 0
  fi
  
  # 2. 压缩格式：::1, ::, 2001:db8::1 等
  if [[ $cdn_host =~ ^::([0-9a-fA-F]{0,4}:)*[0-9a-fA-F]{0,4}$ ]] || \
     [[ $cdn_host =~ ^([0-9a-fA-F]{0,4}:)*::([0-9a-fA-F]{0,4}:)*[0-9a-fA-F]{0,4}$ ]] || \
     [[ $cdn_host =~ ^([0-9a-fA-F]{0,4}:)*[0-9a-fA-F]{0,4}::$ ]]; then
    return 0
  fi
  
  # 3. IPv6 映射 IPv4 格式：::ffff:192.0.2.1
  if [[ $cdn_host =~ ^::ffff:([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    return 0
  fi
  
  # 4. 带方括号的 IPv6（某些场景使用）：[2001:db8::1]
  if [[ $cdn_host =~ ^\[([0-9a-fA-F]{0,4}:)+[0-9a-fA-F]{0,4}\]$ ]]; then
    return 0
  fi
  
  return 1
}

# 验证Reality私钥格式
validate_reality_private() {
  local key="$1"
  # Reality私钥应该是base64格式，长度为44字符
  if [[ $key =~ ^[A-Za-z0-9_-]{43}=?$ ]]; then
    return 0
  else
    return 1
  fi
}

# 验证节点名称
validate_node_name() {
  local name="$1"
  # 节点名称不能为空，长度不超过100
  if [ -n "$name" ] && [ ${#name} -le 100 ]; then
    return 0
  else
    return 1
  fi
}

# 验证Argo域名
validate_argo_domain() {
  local domain="$1"
  # Argo域名应该是有效的域名格式
  if [[ $domain =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
    return 0
  else
    return 1
  fi
}

# 验证Argo凭据（JSON格式）
validate_argo_auth() {
  local auth="$1"
  # 检查是否是有效的JSON
  if echo "$auth" | jq . >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

# 扩展的参数验证函数
validate_extended_params() {
  dlog "开始扩展参数验证"
  
  # 验证SNI
  if [ -n "$hy_sni" ]; then
    if ! validate_sni "$hy_sni"; then
      red "❌ Hysteria2 SNI格式无效：$hy_sni"
      return 1
    fi
  fi
  
  if [ -n "$vl_sni" ]; then
    if ! validate_sni "$vl_sni"; then
      red "❌ VLESS SNI格式无效：$vl_sni"
      return 1
    fi
  fi
  
  if [ -n "$tu_sni" ]; then
    if ! validate_sni "$tu_sni"; then
      red "❌ TUIC SNI格式无效：$tu_sni"
      return 1
    fi
  fi
  
  # 验证CDN主机
  if [ -n "$cdn_host" ]; then
    if ! validate_cdn_host "$cdn_host"; then
      red "❌ CDN主机格式无效：$cdn_host"
      return 1
    fi
  fi
  
  # 验证Reality私钥
  if [ -n "$reality_private" ]; then
    if ! validate_reality_private "$reality_private"; then
      red "❌ Reality私钥格式无效：$reality_private"
      return 1
    fi
  fi
  
  # 验证节点名称
  if [ -n "$name" ]; then
    if ! validate_node_name "$name"; then
      red "❌ 节点名称无效：$name"
      return 1
    fi
  fi
  
  # 验证Argo域名
  if [ -n "$ARGO_DOMAIN" ]; then
    if ! validate_argo_domain "$ARGO_DOMAIN"; then
      red "❌ Argo域名格式无效：$ARGO_DOMAIN"
      return 1
    fi
  fi
  
  # 验证Argo凭据
  if [ -n "$ARGO_AUTH" ]; then
    if ! validate_argo_auth "$ARGO_AUTH"; then
      red "❌ Argo凭据格式无效（应为JSON）"
      return 1
    fi
  fi
  
  dlog "扩展参数验证通过"
  return 0
}

# ================== Phase 31: 扩展参数验证 END ==================
