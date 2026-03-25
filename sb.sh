
#!/usr/bin/env bash
export LANG=en_US.UTF-8

# ================== 文件夹路径配置 ==================
# 统一定义文件夹名称和路径，方便后续修改
SB_FOLDER="doraemon"
SINGBOX_FOLDER_PATH="/root/$SB_FOLDER"
OLD_SINGBOX_FOLDER="/root/agsb"  # 旧路径，用于兼容和清理
# ================== 文件夹路径配置 结束 ==================

 # ================== 常量和环境变量 结束 ==================

VERSION="1.0.7(2026-03-25)"
AUTHOR="littleDoraemon"

# Environment variables for controlling CDN host and SNI values
export cdn_host=${cdn_host:-"saas.sin.fan"}  # Default CDN host for vmess or trojan  cdn.7zz.cn 
export hy_sni=${hy_sni:-"www.microsoft.com"}    # Default SNI for hy2 protocol
export vl_sni=${vl_sni:-"www.microsoft.com"}   # Default SNI for vless protocol   www.ua.edu www.yahoo.com
export tu_sni=${tu_sni:-"www.microsoft.com"}    # Default SNI for hy2 protocol
export any_sni=${any_sni:-"www.microsoft.com"}  # Default SNI for anytls protocol


# Environment variables for ports and other settings
export uuid=${uuid:-''}; 
export port_vm_ws=${vmpt:-''}; 
export port_tr=${trpt:-''}; 
export port_hy2=${hypt:-''}; 
export port_vlr=${vlrt:-''}; 
export port_tu=${tupt:-''}; 
export port_any=${anypt:-''}; 

# 获取到的IP和出口ip不一样的时候，优先使用出口ip也就是out_ip
export out_ip=${out_ip:-''};

# Argo 相关环境变量
export argo=${argo:-''}; 
export ARGO_DOMAIN=${agn:-''}; 
export ARGO_AUTH=${agk:-''}; 
export ippz=${ippz:-''}; 
export name=${name:-''}; 

# 默认端口
readonly NGINX_DEFAULT_PORT=8080
readonly ARGO_DEFAULT_PORT=8001

#
export nginx_pt=${nginx_pt:-$NGINX_DEFAULT_PORT}   # 订阅服务端口（Nginx）
export argo_pt=${argo_pt:-$ARGO_DEFAULT_PORT}     # Argo 回源入口端口（本地）

# ✅ 新增订阅开关（默认 false = 只装 nginx 不出订阅）
export subscribe="${subscribe:-false}"

# ✅ Reality 私钥环境变量（仅使用你指定的命名）
# 只需要传私钥即可：脚本会自动计算/复用公钥，保证节点输出一致
export reality_private="${reality_private:-""}"
export reality_public="${reality_public:-""}"

# ✅ Argo 优选端口白名单（仅 https 系端口）
HTTPS_CDN_PORTS=(443 2053 2083 2087 2096 8443)

# 默认 CDN 端口和 Vless SNI 端口
cdn_pt="${cdn_pt:-443}"
vl_sni_pt="${vl_sni_pt:-443}"


v46url="https://icanhazip.com"
SCRIPT_URL="https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh"

CN_BING="www.bing.com"

v4_ok=false
v6_ok=false

# 调试日志开关
export DEBUG_FLAG=${DEBUG_FLAG:-'0'}; 

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


is_true() {
  [ "$(printf '%s' "${1:-}" | tr 'A-Z' 'a-z')" = "true" ]
}

debug_log() {
  [ "${DEBUG_FLAG:-0}" = "1" ] && echo -e "$*" >&2
}


get_subscribe_flag() {
  # 优先读落盘值（避免用户不带环境变量执行脚本时失效）
  if [ -s "$SINGBOX_FOLDER_PATH/subscribe" ]; then
    cat "$SINGBOX_FOLDER_PATH/subscribe"
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

if [ -n "${anypt+x}" ]; then
    anyp=yes
fi

# 判断：至少启用一个协议
any_proto_enabled() {
    is_yes "$vlr" || is_yes "$vmp" || is_yes "$trp" || is_yes "$hyp" || is_yes "$tup" || is_yes "$anyp"
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
  elif [ -s "$SINGBOX_FOLDER_PATH/vlvm" ]; then
    argo_src="file"
    argo_val="$(cat "$SINGBOX_FOLDER_PATH/vlvm" 2>/dev/null | tr -d '\r\n')"
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
if pgrep -f 'sing-box' >/dev/null 2>&1; then
    # 已安装
    if [ "${1:-}" = "rep" ]; then
        any_proto_enabled || { echo "提示：rep重置协议时，请在脚本前至少设置一个协议变量哦，再见！💣"; exit 1; }
    fi
else
    # 未安装
    if [ "${1:-}" != "del" ]; then
        any_proto_enabled || { echo "提示：未安装脚本，请在脚本前至少设置一个协议变量哦，再见！💣"; exit 1; }
    fi
fi

# 判断系统是否支持 systemd
has_systemd() {
  command -v systemctl >/dev/null 2>&1 || return 1
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

  debug_log "【调试】install_deps安装函数开始了……"

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
  local fail_log="$SINGBOX_FOLDER_PATH/deps_failed.log"
  mkdir -p "$SINGBOX_FOLDER_PATH" 2>/dev/null || true

  # 找出缺的命令
  local -a missing=()
  local c
  for c in "${NEED_CMDS[@]}"; do
    command -v "$c" >/dev/null 2>&1 || missing+=("$c")
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
    local run_log="/tmp/singbox_deps_${label}.log"
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
          debug_log "【调试】 ✅ 安装成功：$p"
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
  if command -v apt-get >/dev/null 2>&1; then
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
  elif command -v yum >/dev/null 2>&1 || command -v dnf >/dev/null 2>&1; then
    local pm="yum"
    command -v dnf >/dev/null 2>&1 && pm="dnf"

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
  elif command -v apk >/dev/null 2>&1; then
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
    if ! command -v xxd >/dev/null 2>&1; then
      yellow "👉 尝试补齐 xxd（可选）"
      apk add --no-cache xxd >/dev/null 2>&1 || apk add --no-cache vim >/dev/null 2>&1 || true
      command -v xxd >/dev/null 2>&1 && green "✅ xxd 已可用" || yellow "❗ xxd 仍不可用（不致命，继续）"
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
    command -v "$c" >/dev/null 2>&1 || miss=1
  done

  # 下载工具至少要有一个（curl 或 wget）
  if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    miss=1
  fi

  if [ "$miss" = "1" ]; then
    red "❌ 关键依赖仍缺失（curl/jq/openssl/iptables 或下载工具）"
    yellow "📌 你可以查看失败包记录：${fail_log}"
    yellow "👉 常见原因：源缺失（如 Alpine 缺 community）、网络/DNS、权限不足、低内存被系统杀进程"
    return 1
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
  local workdir="$SINGBOX_FOLDER_PATH"
  local bin="$workdir/sing-box"
  local cfg="$workdir/sb.json"
  local svc="singbox-service"

  # 只做“已安装才启用”，避免误触发安装
  if [ ! -x "$bin" ] || [ ! -s "$cfg" ]; then
    echo "❗ 未检测到已安装：$bin 或 $cfg 不存在/为空，已跳过开启自启"
    return 1
  fi

  # systemd (Debian/Ubuntu 等)
  if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    cat >/etc/systemd/system/${svc}.service <<EOF
[Unit]
Description=singbox service
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
  if command -v rc-service >/dev/null 2>&1 && command -v rc-update >/dev/null 2>&1; then
    cat >/etc/init.d/${svc} <<'EOF'
#!/sbin/openrc-run
name="singbox service"
description="singbox service"
command="$SINGBOX_FOLDER_PATH/sing-box"
command_args="run -c $SINGBOX_FOLDER_PATH/sb.json"
command_background="yes"
pidfile="/run/singbox.pid"

depend() {
  need net
  after firewall
}

start_pre() {
  [ -x $SINGBOX_FOLDER_PATH/sing-box ] || return 1
  [ -s $SINGBOX_FOLDER_PATH/sb.json ] || return 1
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

    chmod +x /etc/init.d/${svc}
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
  local svc="singbox-service"

  if command -v systemctl >/dev/null 2>&1 && [ -d /run/systemd/system ]; then
    systemctl disable --now "${svc}.service" >/dev/null 2>&1
    rm -f "/etc/systemd/system/${svc}.service"
    systemctl daemon-reload >/dev/null 2>&1
    echo "✅ 已关闭开机自启（systemd）：${svc}"
    return 0
  fi

  if command -v rc-service >/dev/null 2>&1 && command -v rc-update >/dev/null 2>&1; then
    rc-update del "${svc}" default >/dev/null 2>&1
    rc-service "${svc}" stop >/dev/null 2>&1
    rm -f "/etc/init.d/${svc}"
    echo "✅ 已关闭开机自启（openrc）：${svc}"
    return 0
  fi

  echo "❗ 未检测到 systemd 或 openrc"
  return 1
}

# 确保快捷命令
ensure_singbox_shortcut() {
  local wrapper="$SINGBOX_FOLDER_PATH/singbox"
  local local_script="$SINGBOX_FOLDER_PATH/sb.sh"

  # 软链接目标（按优先级）
  local link_local1="$HOME/.local/bin/singbox"
  local link_local2="$HOME/bin/singbox"
  local link_sys1="/usr/local/bin/singbox"
  local link_sys2="/usr/bin/singbox"

  mkdir -p "$SINGBOX_FOLDER_PATH" "$HOME/.local/bin" "$HOME/bin"

  # ✅ wrapper：优先本地脚本，否则在线拉取脚本（curl/wget 二选一，兼容 Alpine）
  cat > "$wrapper" <<EOF
#!/usr/bin/env bash
set -e
LOCAL_SCRIPT="\$SINGBOX_FOLDER_PATH/sb.sh"

if [ -s "\$LOCAL_SCRIPT" ]; then
  exec bash "\$LOCAL_SCRIPT" "\$@"
else
  if command -v curl >/dev/null 2>&1; then
    exec bash <(curl -Ls "$SCRIPT_URL") "\$@"
  elif command -v wget >/dev/null 2>&1; then
    exec bash <(wget -qO- "$SCRIPT_URL") "\$@"
  else
    echo "ERROR: need curl or wget to fetch script." >&2
    echo "Debian/Ubuntu: apt update && apt install -y curl" >&2
    echo "Alpine: apk add --no-cache curl" >&2
    exit 1
  fi
fi
EOF
  chmod +x "$wrapper" 2>/dev/null || true

  # ✅ 用户级入口（建链接）
  ln -sf "$wrapper" "$link_local1" 2>/dev/null || true
  chmod +x "$link_local1" 2>/dev/null || true

  ln -sf "$wrapper" "$link_local2" 2>/dev/null || true
  chmod +x "$link_local2" 2>/dev/null || true

  # ✅ root：系统目录入口（通常立刻生效，且不需要改 PATH）
  if [ "$(id -u)" -eq 0 ]; then
    [ -d "/usr/local/bin" ] || mkdir -p /usr/local/bin 2>/dev/null || true
    if [ -d "/usr/local/bin" ] && [ -w "/usr/local/bin" ]; then
      ln -sf "$wrapper" "$link_sys1" 2>/dev/null || true
      chmod +x "$link_sys1" 2>/dev/null || true
    elif [ -d "/usr/bin" ] && [ -w "/usr/bin" ]; then
      ln -sf "$wrapper" "$link_sys2" 2>/dev/null || true
      chmod +x "$link_sys2" 2>/dev/null || true
    fi
  fi

  # ✅ 尽力让“当前 shell”立刻识别（不修改环境文件）
  hash -r 2>/dev/null || true
  command -v rehash >/dev/null 2>&1 && rehash 2>/dev/null || true

  # ✅ 输出结果
  if command -v singbox >/dev/null 2>&1; then
    echo ""
    purple " 已创建快捷命令：singbox（$(command -v singbox)）"
  else
    yellow "❗ 已创建 wrapper/软链接，但当前 PATH 未命中 singbox"
    yellow "👉 你仍可直接运行："
    green  "   $wrapper"
    yellow "👉 或用以下任一路径（若已在 PATH 中则可直接敲 singbox）："
    green  "   $link_local1"
    green  "   $link_local2"
    [ "$(id -u)" -eq 0 ] && { green "   $link_sys1"; green "   $link_sys2"; }
  fi
}

# 清理快捷命令
cleanup_singbox_shortcut() {
  local wrapper="$SINGBOX_FOLDER_PATH/singbox"

  local link_local1="$HOME/.local/bin/singbox"
  local link_local2="$HOME/bin/singbox"
  local link_sys1="/usr/local/bin/singbox"
  local link_sys2="/usr/bin/singbox"

  # 1) 删除入口（系统级 + 用户级）
  rm -f "$link_local1" 2>/dev/null || true
  rm -f "$link_local2" 2>/dev/null || true
  rm -f "$wrapper"     2>/dev/null || true

  # root 才能删系统目录入口
  if [ "$(id -u)" -eq 0 ]; then
    rm -f "$link_sys1" 2>/dev/null || true
    rm -f "$link_sys2" 2>/dev/null || true
  fi

  # 2) 刷新命令缓存
  hash -r 2>/dev/null || true
  command -v rehash >/dev/null 2>&1 && rehash 2>/dev/null || true

  # 3) 输出结果
  if command -v singbox >/dev/null 2>&1; then
    yellow "❗ cleanup 已执行，但当前会话仍能找到 singbox：$(command -v singbox)"
    yellow "👉 若你之前把某个路径手动加进 PATH，或 shell 有缓存，重新开一个终端/SSH 会话即可"
  else
    green "✅ 已清理快捷命令（wrapper/软链接）"
  fi
}



# 显示菜单
showmode(){
    blue "===================================================="
    gradient "       singbox 一键脚本（vmess/trojan Argo选1,vless+hy2+tuic+anytls 4个直连）"
    green    "       作者：$AUTHOR"
    yellow   "       版本：$VERSION"
    blue "===================================================="
}

# 安装 Nginx 包
install_nginx_pkg() {
  # 已安装就不重复装
  if command -v nginx >/dev/null 2>&1; then
    return 0
  fi

  yellow "👉 正在安装 Nginx..."

  # 统一把详细输出写到日志，失败时 tail 出来
  local log="/tmp/singbox_nginx_install.log"
  : > "$log" 2>/dev/null || true

  # Debian/Ubuntu (apt-get)
  if command -v apt-get >/dev/null 2>&1; then
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

  elif command -v apt >/dev/null 2>&1; then
    # 兜底：尽量用 apt-get，但这里保留 apt
    export DEBIAN_FRONTEND=noninteractive
    if ! apt update >>"$log" 2>&1 || ! apt install -y nginx >>"$log" 2>&1; then
      red "❌ Nginx 安装失败，详见：$log"
      tail -n 80 "$log" 2>/dev/null || true
      return 1
    fi

  elif command -v yum >/dev/null 2>&1; then
    yum install -y nginx >>"$log" 2>&1 || { red "❌ Nginx 安装失败，详见：$log"; tail -n 80 "$log" 2>/dev/null || true; return 1; }

  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y nginx >>"$log" 2>&1 || { red "❌ Nginx 安装失败，详见：$log"; tail -n 80 "$log" 2>/dev/null || true; return 1; }

  elif command -v apk >/dev/null 2>&1; then
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
    if command -v shuf >/dev/null 2>&1; then
        shuf -i 10000-65535 -n 1
        return
    fi

    # 备选：awk + 随机种子（兼容性很好）
    if command -v awk >/dev/null 2>&1; then
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
    debug_log "【调试】prepare_argo_credentials：开始处理凭据（auth长度=${#auth}，domain=${domain:-<空>}，local_port=${local_port:-<空>}）"

    if [ -z "$auth" ]; then
        debug_log "【调试】prepare_argo_credentials：auth 为空，跳过（ARGO_MODE=none）"
        return
    fi

    # ---------- JSON 凭据 ----------
    if echo "$auth" | grep -q 'TunnelSecret'; then
        yellow "检测到 Argo JSON 凭据，使用 credentials-file 模式"
        debug_log "【调试】prepare_argo_credentials：识别为 JSON 凭据（将写入 $SINGBOX_FOLDER_PATH/tunnel.json 并生成 tunnel.yml）"

        if [ -z "$local_port" ]; then
            red "❌ prepare_argo_credentials: LOCAL_PORT 为空"
            debug_log "【调试】prepare_argo_credentials：失败：local_port 为空，无法生成 tunnel.yml"
            return 1
        fi

        mkdir -p "$SINGBOX_FOLDER_PATH"

        # 写入 tunnel.json
        #❗ 如果 ARGO_AUTH 里的 JSON 含有 \n、\r、\uXXXX 之类，echo 在某些 shell/实现里可能会解释转义，导致 tunnel.json 内容被破坏。 改法：用 printf 更可靠
        printf '%s' "$auth" > "$SINGBOX_FOLDER_PATH/tunnel.json"
        debug_log "【调试】prepare_argo_credentials：tunnel.json 已写入（大小=$(wc -c "$SINGBOX_FOLDER_PATH/tunnel.json" 2>/dev/null | awk '{print $1}') 字节）"

        # 提取 TunnelID
        local tunnel_id
        tunnel_id=$(echo "$auth" | sed -n 's/.*"TunnelID"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

        if [ -z "$tunnel_id" ]; then
            red "❌ Argo JSON 中未找到 TunnelID"
            debug_log "【调试】prepare_argo_credentials：失败：JSON 中未解析到 TunnelID"
            return 1
        fi
        debug_log "【调试】prepare_argo_credentials：已解析 TunnelID（前8位=${tunnel_id:0:8}...）"

        # 生成 tunnel.yml（对齐 s4.sh）
        cat > "$SINGBOX_FOLDER_PATH/tunnel.yml" <<EOF
tunnel: $tunnel_id
credentials-file: $SINGBOX_FOLDER_PATH/tunnel.json
protocol: http2

ingress:
  - hostname: ${domain}
    service: http://localhost:${local_port}
    originRequest:
      noTLSVerify: true
  - service: http_status:404
EOF
        debug_log "【调试】prepare_argo_credentials：tunnel.yml 已生成（回源到 localhost:${local_port}，hostname=${domain:-<空>}）"

        ARGO_MODE="json"
        debug_log "【调试】prepare_argo_credentials：ARGO_MODE 已设为 json"

    else
        # token 模式
        ARGO_MODE="token"
        debug_log "【调试】prepare_argo_credentials：识别为 token 凭据（ARGO_MODE=token）"
    fi

    export ARGO_MODE
    debug_log "【调试】prepare_argo_credentials：结束（ARGO_MODE=${ARGO_MODE}）"
}




echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"; 
echo "Sing-box 一键无交互脚本💣 (Sing-box内核版)";  
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

hostname=$(uname -a | awk '{print $2}'); 
op=$(cat /etc/redhat-release 2>/dev/null || cat /etc/os-release 2>/dev/null | grep -i pretty_name | cut -d \" -f2); 
case $(uname -m) in aarch64) cpu=arm64;; x86_64) cpu=amd64;; *) echo "目前脚本不支持$(uname -m)架构" && exit; esac;
 mkdir -p "$SINGBOX_FOLDER_PATH"
# Check and set IP version
v4v6(){
    # Check IPv4 connectivity
    debug_log "【调试】 Checking IPv4 and IPv6 connectivity, ready to get IP..."
    debug_log "【调试】 Checking IPv4 connectivity..."
    v4=$(curl -s4 -m2 --connect-timeout 2 -k "$v46url" 2>/dev/null || wget -4 -qO- --tries=2 --timeout=2 "$v46url" 2>/dev/null)
    if [ -n "$v4" ]; then
        v4_ok=true
    else
        v4_ok=false
    fi

    debug_log "【调试】 IPv4 connectivity check completed. ipv4=$v4"

    # Check IPv6 connectivity
    debug_log "【调试】 Checking IPv6 connectivity..."
    v6=$(curl -s6 -m2 --connect-timeout 2 -k "$v46url" 2>/dev/null || wget -6 -qO- --tries=2 --timeout=2 "$v46url" 2>/dev/null)
    if [ -n "$v6" ]; then
        v6_ok=true
    else
        v6_ok=false
    fi
    debug_log "【调试】 IPv6 connectivity check completed. ipv6=$v6"
    debug_log "【调试】 IP connectivity check completed. ipv4=$v4, ipv6=$v6"

    
}

# Set up name for nodes and IP version preference
set_sbyx(){
    if [ -n "$name" ]; then
        sxname=$name-
        echo "$sxname" > "$SINGBOX_FOLDER_PATH/name"
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
    out="$SINGBOX_FOLDER_PATH/sing-box"
    (curl -Lo "$out" -# --connect-timeout 5 --max-time 120  --retry 2 --retry-delay 2 --retry-all-errors "$url") || (wget -O "$out" --tries=2 --timeout=120 --dns-timeout=5 --read-timeout=60 "$url")


    debug_log "【调试】upsingbox：下载 Sing-box 二进制文件，保存路径 $out，url: $url"

    # 下载结果校验：防止拿到空文件/错误页导致后续假安装
    if [ ! -s "$out" ]; then
        debug_log "【调试】upsingbox：下载失败：文件为空"
        red "❌ 下载失败：文件为空 $out"
        exit 1
    fi
    debug_log "【调试】upsingbox：检查 Sing-box 二进制文件是否下载成功"

    chmod +x "$SINGBOX_FOLDER_PATH/sing-box"
    sbcore=$("$SINGBOX_FOLDER_PATH/sing-box" version 2>/dev/null | awk '/version/{print $NF}')
    debug_log "【调试】upsingbox：Sing-box 版本为 $sbcore"
    green "✅  已安装Sing-box正式版内核：$sbcore"
}
# Generate UUID and save to file
insuuid(){
    if [ ! -e "$SINGBOX_FOLDER_PATH/sing-box" ]; then 
        upsingbox;
    fi

    if [ -z "$uuid" ] && [ ! -e "$SINGBOX_FOLDER_PATH/uuid" ]; then
        uuid=$("$SINGBOX_FOLDER_PATH/sing-box" generate uuid)
        echo "$uuid" > "$SINGBOX_FOLDER_PATH/uuid"
    elif [ -n "$uuid" ]; then
        echo "$uuid" > "$SINGBOX_FOLDER_PATH/uuid"
    fi
    uuid=$(cat "$SINGBOX_FOLDER_PATH/uuid")
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


  local sid_file="${1:-$SINGBOX_FOLDER_PATH/short_id}"
  local sid=""

  # 兼容：如果脚本里没有 yellow/green，就用 echo
  command -v yellow >/dev/null 2>&1 || yellow(){ echo -e "$*"; }
  command -v green  >/dev/null 2>&1 || green(){ echo -e "$*"; }

  _is_hex() { echo "$1" | grep -qiE '^[0-9a-f]{8}$'; }

  # 由 reality_private 推导一个稳定的 short_id
  # 仅使用 reality_private 推导（更可控、更干净）
  local rp="${reality_private:-}"
  if [ -n "${rp:-}" ]; then
    # 推导方式：sha256(reality_private) 取前 8 位 hex
    if command -v sha256sum >/dev/null 2>&1; then
      sid="$(printf "%s" "$rp" | sha256sum | awk '{print $1}' | cut -c1-8)"
    elif command -v openssl >/dev/null 2>&1; then
      sid="$(printf "%s" "$rp" | openssl dgst -sha256 2>/dev/null | awk '{print $NF}' | cut -c1-8)"
    elif command -v md5sum >/dev/null 2>&1; then
      sid="$(printf "%s" "$rp" | md5sum | awk '{print $1}' | cut -c1-8)"
    else
      # 兜底：仍然随机生成，但会落盘保持后续稳定
      sid="$(head -c 4 /dev/urandom 2>/dev/null | od -An -tx1 | tr -d ' \n' | cut -c1-8)"
    fi

    sid="${sid,,}"
    if _is_hex "$sid"; then
      # 如果文件存在但不一致，覆盖以保证“只传 reality_private 也稳定一致”
      if [ -f "$sid_file" ]; then
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
  if [ -f "$sid_file" ]; then
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
  if command -v openssl >/dev/null 2>&1; then
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
  if command -v xxd >/dev/null 2>&1 && command -v openssl >/dev/null 2>&1; then
    debug_log "🔐 【调试】 derive_reality_public_key: 使用【本地推导】(openssl + xxd)"

    local tmp_dir="$SINGBOX_FOLDER_PATH/.tmp_reality"
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
      if [ -s "$tmp_dir/_x25519_priv_raw" ]; then
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
              if command -v base64 >/dev/null 2>&1; then
                pub="$(base64 < "$tmp_dir/_x25519_pub_raw" 2>/dev/null | tr -d '\n' | tr '+/' '-_' | sed -E 's/=+$//')"
              elif command -v openssl >/dev/null 2>&1; then
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

  if command -v curl >/dev/null 2>&1; then
    pub="$(curl -s --max-time 2 "https://realitykey.cloudflare.now.cc/?privateKey=${priv}" \
      | awk -F '"' '/publicKey/{print $4; exit}')"
  elif command -v wget >/dev/null 2>&1; then
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
  local key_file="$SINGBOX_FOLDER_PATH/reality.key"
  local file_priv="" file_pub=""
  local env_priv="${reality_private:-}"
  local priv="" pub=""
  local print_reality_private=0

  debug_log "🔑 【调试】init_reality_keypair: 开始初始化 Reality Keypair..."
  debug_log "📌 【调试】init_reality_keypair: key_file=$key_file"

  # 读取文件中的 keypair（如果存在）
  if [ -f "$key_file" ]; then
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
        kp="$("$SINGBOX_FOLDER_PATH/sing-box" generate reality-keypair 2>/dev/null)"
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
    kp="$("$SINGBOX_FOLDER_PATH/sing-box" generate reality-keypair 2>/dev/null)"
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
  if [ -s "$key_path" ] && [ -s "$cert_path" ]; then
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

    if [ ! -e "$SINGBOX_FOLDER_PATH/sing-box" ]; then 
        debug_log "【调试】installsb：Sing-box 不存在，开始下载/安装"
        upsingbox; 
    fi


    cat > "$SINGBOX_FOLDER_PATH/sb.json" <<EOF
{"log": { "disabled": false, "level": "info", "timestamp": true },
"inbounds": [
EOF
    insuuid
    write2SingboxFolders

   # Generate a self-signed cert for protocols that need TLS (hy2, tuic, anytls)
    if [ -n "$hyp" ] || [ -n "$tup" ] || [ -n "$anyp" ]; then
        gen_self_signed_cert "$SINGBOX_FOLDER_PATH/private.key" "$SINGBOX_FOLDER_PATH/cert.pem" "${CN_BING}" 36500
    fi


    # 添加tuic协议
    if [ -n "$tup" ]; then
        if [ -n "$port_tu" ]; then
            echo "$port_tu" > "$SINGBOX_FOLDER_PATH/port_tu"
        elif [ -s "$SINGBOX_FOLDER_PATH/port_tu" ]; then
            port_tu=$(cat "$SINGBOX_FOLDER_PATH/port_tu")
        else
            port_tu=$(rand_port)
            echo "$port_tu" > "$SINGBOX_FOLDER_PATH/port_tu"
        fi

        
        port_tu=$(cat "$SINGBOX_FOLDER_PATH/port_tu"); 
        password=$uuid

        yellow "Tuic端口：$port_tu"

         cat >> "$SINGBOX_FOLDER_PATH/sb.json" <<EOF
{"type": "tuic", "tag": "tuic-sb", "listen": "::", "listen_port": ${port_tu}, "users": [ {  "uuid": "$uuid", "password": "$password" } ],"congestion_control": "bbr", "tls": { "enabled": true,"alpn": ["h3"], "certificate_path": "$SINGBOX_FOLDER_PATH/cert.pem", "key_path": "$SINGBOX_FOLDER_PATH/private.key" }},
EOF
    fi

    # 添加hy2协议
    if [ -n "$hyp" ]; then
        if [ -z "$port_hy2" ] && [ ! -e "$SINGBOX_FOLDER_PATH/port_hy2" ]; then port_hy2=$(rand_port); echo "$port_hy2" > "$SINGBOX_FOLDER_PATH/port_hy2"; elif [ -n "$port_hy2" ]; then echo "$port_hy2" > "$SINGBOX_FOLDER_PATH/port_hy2"; fi
        
        port_hy2=$(cat "$SINGBOX_FOLDER_PATH/port_hy2"); 
        yellow "Hysteria2端口：$port_hy2"

        cat >> "$SINGBOX_FOLDER_PATH/sb.json" <<EOF
{"type": "hysteria2", "tag": "hy2-sb", "listen": "::", "listen_port": ${port_hy2},"users": [ { "password": "${uuid}" } ],"tls": { "enabled": true, "alpn": ["h3"], "certificate_path": "$SINGBOX_FOLDER_PATH/cert.pem", "key_path": "$SINGBOX_FOLDER_PATH/private.key" }},
EOF
    fi
    
    # 添加trojan协议
    if [ -n "$trp" ]; then
        if [ -z "$port_tr" ] && [ ! -e "$SINGBOX_FOLDER_PATH/port_tr" ]; then port_tr=$(rand_port); echo "$port_tr" > "$SINGBOX_FOLDER_PATH/port_tr"; elif [ -n "$port_tr" ]; then echo "$port_tr" > "$SINGBOX_FOLDER_PATH/port_tr"; fi
        
        port_tr=$(cat "$SINGBOX_FOLDER_PATH/port_tr"); 
        yellow "Trojan端口(Argo本地使用)：$port_tr"

        cat >> "$SINGBOX_FOLDER_PATH/sb.json" <<EOF
{"type": "trojan", "tag": "trojan-ws-sb", "listen": "::", "listen_port": ${port_tr},"users": [ { "password": "${uuid}" } ],"transport": { "type": "ws", "path": "/${uuid}-tr" }},
EOF
    fi

   # 添加vmess协议
    if [ -n "$vmp" ]; then
        if [ -z "$port_vm_ws" ] && [ ! -e "$SINGBOX_FOLDER_PATH/port_vm_ws" ]; then port_vm_ws=$(rand_port); echo "$port_vm_ws" > "$SINGBOX_FOLDER_PATH/port_vm_ws"; elif [ -n "$port_vm_ws" ]; then echo "$port_vm_ws" > "$SINGBOX_FOLDER_PATH/port_vm_ws"; fi
        
        port_vm_ws=$(cat "$SINGBOX_FOLDER_PATH/port_vm_ws"); 
        yellow "Vmess-ws端口 (Argo本地使用)：$port_vm_ws"

        cat >> "$SINGBOX_FOLDER_PATH/sb.json" <<EOF
{"type": "vmess", "tag": "vmess-sb", "listen": "::", "listen_port": ${port_vm_ws},"users": [ { "uuid": "${uuid}", "alterId": 0 } ],"transport": { "type": "ws", "path": "/${uuid}-vm" }},
EOF
    fi
    # 添加vless-reality-vision协议
    if [ -n "$vlr" ]; then
        if [ -z "$port_vlr" ] && [ ! -e "$SINGBOX_FOLDER_PATH/port_vlr" ];  then 
            port_vlr=$(rand_port); 
            echo "$port_vlr" > "$SINGBOX_FOLDER_PATH/port_vlr"; 
        elif [ -n "$port_vlr" ]; then 
            echo "$port_vlr" > "$SINGBOX_FOLDER_PATH/port_vlr"; 
        fi
        
        port_vlr=$(cat "$SINGBOX_FOLDER_PATH/port_vlr"); 
        yellow "VLESS-Reality-Vision端口：$port_vlr"

        if [ ! -f "$SINGBOX_FOLDER_PATH/reality.key" ]; then 
            "$SINGBOX_FOLDER_PATH/sing-box" generate reality-keypair > "$SINGBOX_FOLDER_PATH/reality.key"; 
        fi

          # ✅ Reality Keypair：只传私钥即可（自动算公钥/或复用文件），节点输出保持一致
        init_reality_keypair
        private_key="${reality_private}"
        short_id="$(get_short_id "$SINGBOX_FOLDER_PATH/short_id")"


        # www.ua.edu
        cat >> "$SINGBOX_FOLDER_PATH/sb.json" <<EOF
{"type": "vless", "tag": "vless-reality-vision-sb", "listen": "::", "listen_port": ${port_vlr},"sniff": true,"users": [{"uuid": "${uuid}","flow": "xtls-rprx-vision"}],"tls": {"enabled": true,"server_name": "${vl_sni}","reality": {"enabled": true,"handshake": {"server": "${vl_sni}","server_port": ${vl_sni_pt}},"private_key": "${private_key}","short_id": ["${short_id}"]}}},
EOF
    fi
    # 添加anytls协议
    if [ -n "$anyp" ]; then
        if [ -n "$port_any" ]; then
            echo "$port_any" > "$SINGBOX_FOLDER_PATH/port_any"
        elif [ -s "$SINGBOX_FOLDER_PATH/port_any" ]; then
            port_any=$(cat "$SINGBOX_FOLDER_PATH/port_any")
        else
            port_any=$(rand_port)
            echo "$port_any" > "$SINGBOX_FOLDER_PATH/port_any"
        fi
        
        # any_sni 也应该保持稳定：优先读取文件，不存在才使用新值
        if [ -s "$SINGBOX_FOLDER_PATH/any_sni" ]; then
            any_sni=$(cat "$SINGBOX_FOLDER_PATH/any_sni")
        else
            echo "$any_sni" > "$SINGBOX_FOLDER_PATH/any_sni"
        fi
        
        port_any=$(cat "$SINGBOX_FOLDER_PATH/port_any"); 
        yellow "AnyTLS端口：$port_any"
        
        # 确保证书存在（如果 hy2/tuic 未启用，anytls 需要自己生成）
        if [ ! -s "$SINGBOX_FOLDER_PATH/cert.pem" ] || [ ! -s "$SINGBOX_FOLDER_PATH/private.key" ]; then
            gen_self_signed_cert "$SINGBOX_FOLDER_PATH/private.key" "$SINGBOX_FOLDER_PATH/cert.pem" "${CN_BING}" 36500
        fi

        cat >> "$SINGBOX_FOLDER_PATH/sb.json" <<EOF
{"type": "anytls", "tag": "anytls-sb", "listen": "::", "listen_port": ${port_any},"sniff": true,"users": [{"password": "${uuid}"}],"tls": {"enabled": true,"server_name": "${any_sni}","certificate_path": "$SINGBOX_FOLDER_PATH/cert.pem", "key_path": "$SINGBOX_FOLDER_PATH/private.key"}},
EOF
    fi
}
#  Generate Sing-box configuration file
sbbout(){
    if [ -e "$SINGBOX_FOLDER_PATH/sb.json" ]; then
        sed -i '$ s/,[[:space:]]*$//' "$SINGBOX_FOLDER_PATH/sb.json"

        cat >> "$SINGBOX_FOLDER_PATH/sb.json" <<EOF
],
"outbounds": [ { "type": "direct", "tag": "direct" }, { "type": "block", "tag": "block" } ],
"route": { "rules": [ { "action": "sniff" }, { "action": "resolve", "strategy": "${sbyx}" } ], "final": "direct" }
}
EOF
        if has_systemd && [ "$EUID" -eq 0 ]; then
            debug_log "【调试】sbbout：使用 systemd 管理/启动 sb 服务"
            cat > /etc/systemd/system/sb.service <<EOF
[Unit]
Description=sb service
After=network.target
[Service]
Type=simple
NoNewPrivileges=yes
ExecStart=$SINGBOX_FOLDER_PATH/sing-box run -c $SINGBOX_FOLDER_PATH/sb.json
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
        elif command -v rc-service >/dev/null 2>&1 && [ "$EUID" -eq 0 ]; then
            debug_log "【调试】sbbout：使用 openrc 管理/启动 sb 服务"
            cat > /etc/init.d/sing-box <<EOF
#!/sbin/openrc-run
description="sb service"
command="$SINGBOX_FOLDER_PATH/sing-box"
command_args="run -c $SINGBOX_FOLDER_PATH/sb.json"
command_background=yes
pidfile="/run/sing-box.pid"
depend() { need net; }
EOF
            chmod +x /etc/init.d/sing-box;
            rc-update add sing-box default;
            rc-service sing-box start
            echo "" 
            green "✅ sb 服务已启动,并开启开机自启服务（openrc）"
        else
            debug_log "【调试】sbbout：使用 nohup 模式运行 sb 服务"
            nohup "$SINGBOX_FOLDER_PATH/sing-box" run -c "$SINGBOX_FOLDER_PATH/sb.json" >/dev/null 2>&1 &
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
        echo "/etc/nginx/http.d/singbox.conf"
    else
        echo "/etc/nginx/conf.d/singbox.conf"
    fi
}

setup_nginx_subscribe() {
  local port="${nginx_pt:-$NGINX_DEFAULT_PORT}"
  local argo_port="${argo_pt:-$ARGO_DEFAULT_PORT}"
  echo "$port" > "$SINGBOX_FOLDER_PATH/nginx_port"


    # ✅端口相同会导致 nginx listen 冲突
    if [ "$port" = "$argo_port" ]; then
        red "❌ nginx_pt($port) 和 argo_pt($argo_port) 不能相同，否则 Nginx 监听冲突"
        return 1
    fi
  

  local webroot="/var/www/singbox"
  mkdir -p "$webroot"
  chmod 755 /var /var/www /var/www/singbox 2>/dev/null

  local vm_port tr_port uuid
  uuid="$(cat "$SINGBOX_FOLDER_PATH/uuid" 2>/dev/null)"
  vm_port="$(cat "$SINGBOX_FOLDER_PATH/port_vm_ws" 2>/dev/null)"
  tr_port="$(cat "$SINGBOX_FOLDER_PATH/port_tr" 2>/dev/null)"

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
        alias /var/www/singbox/sub.txt;
        add_header Cache-Control "no-store";
    }
EOF
    # 确保订阅文件存在（只在开启订阅时需要）
    [ -f "$webroot/sub.txt" ] || : > "$webroot/sub.txt"
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
  debug_log "【调试】start_nginx_service：开始启动 Nginx 服务"
    # systemd
    if has_systemd; then
        debug_log "【调试】start_nginx_service：使用 systemd 管理 Nginx 服务"
    
        systemctl enable nginx >/dev/null 2>&1
        systemctl restart nginx >/dev/null 2>&1 || systemctl start nginx >/dev/null 2>&1
        echo ""
        green "✅ Nginx 服务已启动,并开启开机自启服务（systemd）"
        return 0
    fi

    # openrc
    if command -v rc-service >/dev/null 2>&1; then
        debug_log "【调试】start_nginx_service：使用 openrc 管理 Nginx 服务"
        rc-update add nginx default >/dev/null 2>&1
        rc-service nginx restart >/dev/null 2>&1 || rc-service nginx start >/dev/null 2>&1
        echo ""  
        green "✅ Nginx 服务已启动,并开启开机自启服务（openrc）"
        return 0
    fi

    debug_log "【调试】start_nginx_service：使用 nohup 模式运行 Nginx 服务"
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
  debug_log "【调试】nginx_stop：开始停止 Nginx 服务"
    # systemd
    if has_systemd; then
        debug_log "【调试】nginx_stop：使用 systemd 管理 Nginx 服务"
        systemctl stop nginx >/dev/null 2>&1
        return 0
    fi

    # openrc
    if command -v rc-service >/dev/null 2>&1; then
        debug_log "【调试】nginx_stop：使用 openrc 管理 Nginx 服务"
        rc-service nginx stop >/dev/null 2>&1
        return 0
    fi

    # no init：直接杀进程
    pkill -15 -x nginx >/dev/null 2>&1
    debug_log "【调试】nginx_stop： Nginx 服务已停止"
    return 0
}

# 重启 Nginx 服务
nginx_restart() {
  debug_log "【调试】nginx_restart：开始重启 Nginx 服务"
    # systemd
    if has_systemd; then
        debug_log "【调试】nginx_restart：使用 systemd 管理 Nginx 服务"
        systemctl restart nginx >/dev/null 2>&1 || systemctl start nginx >/dev/null 2>&1
        echo
        green "✅ Nginx 服务已重启"
        return 0
    fi


 
    # openrc
    if command -v rc-service >/dev/null 2>&1; then
        debug_log "【调试】nginx_restart：使用 openrc 管理 Nginx 服务"
        rc-service nginx restart >/dev/null 2>&1 || rc-service nginx start >/dev/null 2>&1
        echo
        green "✅ Nginx 服务已重启"
        return 0
    fi

    debug_log "【调试】nginx_restart：使用 nohup 模式运行 Nginx 服务"
    # no init：优先 reload，不行就 stop+start
    if command -v nginx >/dev/null 2>&1; then
        debug_log "【调试】nginx_restart：使用 nohup 模式运行 Nginx 服务，尝试 reload"
        nginx -s reload >/dev/null 2>&1 && return 0
    fi

    debug_log "【调试】nginx_restart：使用 nohup 模式运行 Nginx 服务，尝试 stop+start"
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
  debug_log "【调试】ensure_cloudflared_if_needed：检查是否需要 cloudflared"
  if { [ "${argo:-}" != "vmpt" ] && [ "${argo:-}" != "trpt" ]; } || [ -z "${vmag:-}" ]; then
    debug_log "【调试】ensure_cloudflared_if_needed：未启用 Argo（或未启用 vmess/trojan），跳过 cloudflared 下载/安装"
    purple "ℹ️ 未启用 Argo（或未启用 vmess/trojan），跳过 cloudflared 下载/安装"
    return 0
  fi
  debug_log "【调试】ensure_cloudflared_if_needed：需要 cloudflared，开始下载/安装"
  ensure_cloudflared || return 1
  return 0
}




# 确保 cloudflared
ensure_cloudflared() {
  debug_log "【调试】ensure_cloudflared：开始下载/安装 cloudflared"
  # 已存在就不重复下载
  if [ -x "$SINGBOX_FOLDER_PATH/cloudflared" ]; then
    return 0
  fi

  debug_log "【调试】ensure_cloudflared：检查 cloudflared 是否已存在"
  yellow "下载 Cloudflared Argo 内核中…"
  local url out

  # 下面为备用链接，里面的版本为2025.11.1，当有latest问题在切回我的仓库去
  # url="https://github.com/jyucoeng/singbox-tools/releases/download/cloudflared/cloudflared-linux-$cpu";


  url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$cpu"
  out="$SINGBOX_FOLDER_PATH/cloudflared"

  debug_log "【调试】ensure_cloudflared：下载 cloudflared 二进制文件，保存路径 $out"

  (curl -Lo "$out" -# --connect-timeout 5 --max-time 120 \
    --retry 2 --retry-delay 2 --retry-all-errors "$url") \
  || (wget -O "$out" --tries=2 --timeout=60 --dns-timeout=5 --read-timeout=60 "$url")

  debug_log "【调试】ensure_cloudflared：检查 cloudflared 二进制文件是否下载成功"
  if [ ! -s "$out" ]; then
    debug_log "【调试】ensure_cloudflared：下载失败：文件为空"
    red "❌ 下载失败：文件为空 $out"
    return 1
  fi

  debug_log "【调试】ensure_cloudflared：设置 cloudflared 二进制文件权限"
  chmod +x "$out" || return 1

  debug_log "【调试】ensure_cloudflared：cloudflared 二进制文件权限设置成功"
  return 0
}


# 安装 Argo 服务（systemd）
install_argo_service_systemd() {
    local mode="$1" # json|token
    local token="$2"

     # 检查 systemd 是否存在
    if ! command -v systemctl >/dev/null 2>&1; then
        red "系统未检测到 systemd，跳过 systemd 服务安装！"
        return
    fi

    if [ "$mode" = "json" ]; then
        debug_log "【调试】使用 json 模式安装 argo 服务(systemd)"

        cat > /etc/systemd/system/argo.service <<EOF
[Unit]
Description=argo service
After=network.target

[Service]
Type=simple
NoNewPrivileges=yes
ExecStart=$SINGBOX_FOLDER_PATH/cloudflared tunnel --edge-ip-version auto --config $SINGBOX_FOLDER_PATH/tunnel.yml run
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    else
        debug_log "【调试】使用 token 模式安装 argo 服务(systemd)"

        cat > /etc/systemd/system/argo.service <<EOF
[Unit]
Description=argo service
After=network.target

[Service]
Type=simple
NoNewPrivileges=yes
ExecStart=$SINGBOX_FOLDER_PATH/cloudflared tunnel --no-autoupdate --edge-ip-version auto run --token ${token}
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
    if ! command -v rc-service >/dev/null 2>&1; then
        red "系统未检测到 openrc，跳过 openrc 服务安装！"
        return
    fi

    local command_path="$SINGBOX_FOLDER_PATH/cloudflared"
    local args=""

    if [ "$mode" = "json" ]; then
        debug_log "【调试】使用 json 模式安装 argo 服务(openrc)"
        args="tunnel --edge-ip-version auto --config $SINGBOX_FOLDER_PATH/tunnel.yml run"
    else
        debug_log "【调试】使用 token 模式安装 argo 服务(openrc)"
        args="tunnel --no-autoupdate --edge-ip-version auto run --token ${token}"
    fi

    cat > /etc/init.d/argo <<EOF
#!/sbin/openrc-run
description="argo service"
command="${command_path}"
command_args="${args}"
command_background=yes
pidfile="/run/argo.pid"
depend() { need net; }
EOF

    chmod +x /etc/init.d/argo
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
        debug_log "【调试】使用 json 模式，nohup 启动 argo"
        nohup "$SINGBOX_FOLDER_PATH/cloudflared" tunnel \
          --edge-ip-version auto \
          --config "$SINGBOX_FOLDER_PATH/tunnel.yml" run \
          > "$SINGBOX_FOLDER_PATH/argo.log" 2>&1 &
    elif [ -n "$token" ]; then
        debug_log "【调试】使用 token 模式，nohup 启动 argo"
        nohup "$SINGBOX_FOLDER_PATH/cloudflared" tunnel \
          --no-autoupdate \
          --edge-ip-version auto run \
          --token "$token" \
          > "$SINGBOX_FOLDER_PATH/argo.log" 2>&1 &
    else
        debug_log "【调试】使用 URL 模式，nohup 启动 argo"
        nohup "$SINGBOX_FOLDER_PATH/cloudflared" tunnel \
          --url "http://localhost:${port}" \
          --edge-ip-version auto \
          --no-autoupdate \
          > "$SINGBOX_FOLDER_PATH/argo.log" 2>&1 &
    fi
}

# 等待并检查 Argo
wait_and_check_argo() {
  local argo_tunnel_type="${1:-临时}"  # 第一个参数：隧道类型（固定/临时）
  local argo_log="$SINGBOX_FOLDER_PATH/argo.log"
  local ym_log="$SINGBOX_FOLDER_PATH/sbargoym.log"
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
    elif [ -s "$ym_log" ]; then
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
    if [ -s "$argo_log" ]; then
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
            echo '@reboot sleep 10 && nohup $SINGBOX_FOLDER_PATH/cloudflared tunnel --edge-ip-version auto --config $SINGBOX_FOLDER_PATH/tunnel.yml run >/dev/null 2>&1 &' \
                >> /tmp/crontab.tmp
        else
            echo '@reboot sleep 10 && nohup $SINGBOX_FOLDER_PATH/cloudflared tunnel --no-autoupdate --edge-ip-version auto run --token $(cat $SINGBOX_FOLDER_PATH/sbargotoken.log) >/dev/null 2>&1 &' \
                >> /tmp/crontab.tmp
        fi

    # 临时 Argo
    else
        echo '@reboot sleep 10 && nohup $SINGBOX_FOLDER_PATH/cloudflared tunnel --url http://localhost:$(cat $SINGBOX_FOLDER_PATH/argoport.log) --edge-ip-version auto --no-autoupdate > $SINGBOX_FOLDER_PATH/argo.log 2>&1 &' \
            >> /tmp/crontab.tmp
    fi
}

# _legacy 后安装收尾
post_install_finalize_legacy() {
  # 用“最多等待 10 秒 + 检测到就立刻继续”替代固定 sleep
  for i in 1 2 3 4 5 6 7 8 9 10; do
    if pgrep -f "$SINGBOX_FOLDER_PATH/sing-box" >/dev/null 2>&1 || pgrep -f "$SINGBOX_FOLDER_PATH/cloudflared" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
  echo

  # 只要 sing-box 或 cloudflared 进程存在，认为安装启动成功
  if pgrep -f "$SINGBOX_FOLDER_PATH/sing-box" >/dev/null 2>&1 || pgrep -f "$SINGBOX_FOLDER_PATH/cloudflared" >/dev/null 2>&1; then
    white "✅ 安装完成：已检测到 sing-box/cloudflared 正在运行"
    # ❗ legacy 收尾：这里只做检测与提示，不做快捷方式/下载主脚本/写 PATH/建软链
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
    : > /var/www/singbox/sub.txt
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

  debug_log "【调试】pick_server_ip_for_install：ipzz_local=$ipzz_local"
 
  # 5) 拿到本机 v4 / v6（复制 ipchange 的“check + 拆分”核心逻辑，不调用 ipchange）
  local v4v6_result v4_local v6_local
  v4v6_result="$(check_ip_connectivity "$v46url")"
  debug_log "【调试】check_ip_connectivity：v4v6_result=$v4v6_result"

  # 兼容输出里有换行/多空格：压成一行再拆
  IFS='|' read -r v4_local v6_local <<EOF
$(printf '%s' "$v4v6_result" | tr -d '\r\n')
EOF
  v4_local="${v4_local:-}"
  v6_local="${v6_local:-}"

  debug_log "【调试】pick_server_ip_for_install：v4_local=$v4_local，v6_local=$v6_local"


  # 6) 根据 ipzz/ippz 选择 prefer_ip -> server_ip（先不加括号，统一用“裸 IP”比较）
  local prefer_ip server_ip
  case "$ipzz_local" in
    4) prefer_ip="$v4_local" ;;
    6) prefer_ip="$v6_local" ;;
    *) prefer_ip="" ;;
  esac

  debug_log "【调试】pick_server_ip_for_install：prefer_ip=$prefer_ip"  
 
 # 去掉乱七八糟的中括号
  server_ip="$(strip_ip_brackets_all "$prefer_ip")"

  debug_log "【调试】pick_server_ip_for_install：去除乱七八糟的中括号后,server_ip=$server_ip"

  # 7) 若 prefer_ip 为空/不合法：兜底抓公网（先 v4 再 v6，2 秒超时，wget 重试 2 次）
  if [ -z "$server_ip" ] || ! is_valid_ip_simple "$server_ip"; then
    debug_log "【调试】pick_server_ip_for_install：prefer_ip 为空或不合法，开始兜底抓公网"
    local serip_raw
    serip_raw="$(
      (curl -s4m2 -k "$v46url" 2>/dev/null) || (wget -4 -qO- --timeout=2 --tries=2 "$v46url" 2>/dev/null)
    )"
    debug_log "【调试】pick_server_ip_for_install函数：由于prefer_ip 为空或不合法，开始兜底抓公网ipv4,serip_raw=$serip_raw"
    if [ -z "$serip_raw" ]; then
     debug_log "【调试】pick_server_ip_for_install函数：由于prefer_ip 为空或不合法，开始兜底抓公网ipv4,ipv4 为空，开始抓ipv6……"
      serip_raw="$(
        (curl -s6m2 -k "$v46url" 2>/dev/null) || (wget -6 -qO- --timeout=2 --tries=2 "$v46url" 2>/dev/null)
      )"
      debug_log "【调试】pick_server_ip_for_install函数：由于prefer_ip 为空或不合法，抓公网ipv6结束,serip_raw=$serip_raw"
    fi
    server_ip="$(strip_ip_brackets_all "$serip_raw")"
    debug_log "【调试】pick_server_ip_for_install：最终抓取的公网IP,server_ip=$server_ip"
  fi


  debug_log "【调试】pick_server_ip_for_install：开始对比out_ip与server_ip，out_ip=$out_ip，server_ip=$server_ip"

  # 8) 处理 out_ip：去括号后再比较；若 out_ip 合法且与 server_ip 不同，则 out_ip 覆盖server_ip的值
  local out_norm
  out_norm="$(strip_ip_brackets_all "${out_ip:-}")"
  if is_valid_ip_simple "$out_norm" && [ -n "$out_norm" ]; then
    debug_log "【调试】pick_server_ip_for_install：out_ip经过处理格式后，out_norm=$out_norm"
    if [ -z "$server_ip" ] || ! is_valid_ip_simple "$server_ip" || [ "$out_norm" != "$(strip_ip_brackets_all "$server_ip")" ]; then
      debug_log "【调试】pick_server_ip_for_install：out_ip合法且与server_ip不同，out_norm=$out_norm，server_ip=$server_ip"
      server_ip="$out_norm"
    fi
  fi

  debug_log "【调试】pick_server_ip_for_install：最终选择的服务器IP，server_ip=$server_ip"
  # 9) 最终写入：IPv6 加 []，写入 $SINGBOX_FOLDER_PATH/server_ip.log
  mkdir -p "$SINGBOX_FOLDER_PATH" 2>/dev/null || true

  local ip_final
  ip_final="$(format_ip_for_log "$server_ip" 2>/dev/null || true)"
  debug_log "【调试】pick_server_ip_for_install：最终写入的IP文件形式，ip_final=$ip_final"
  echo "$ip_final" > "$SINGBOX_FOLDER_PATH/server_ip.log"

  debug_log "【调试】pick_server_ip_for_install：已写入 $SINGBOX_FOLDER_PATH/server_ip.log, ip_final=$ip_final"

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

  if [ -s "$SINGBOX_FOLDER_PATH/server_ip.log" ]; then
      current_server_ip="$(strip_ip_brackets_all "$(cat "$SINGBOX_FOLDER_PATH/server_ip.log" 2>/dev/null)")"
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
    debug_log "【调试】进入 ins() 安装流程"
    debug_log "【调试】关键参数：argo=${argo:-<空>}，vmag=${vmag:-<空>}，subscribe=$(get_subscribe_flag 2>/dev/null || echo ${subscribe:-false})，nginx_pt=${nginx_pt:-<空>}，argo_pt=${argo_pt:-<空>}"
    # =====================================================
    # 1. 安装并启动 sing-box
    # =====================================================
    installsb
    set_sbyx
    sbbout

    # 把ip写入server_ip.log
    write_server_ip

    # 2. Nginx（按需：subscribe=true 或启用 argo 才需要）
    ensure_nginx_if_needed || exit 1
    debug_log "【调试】ensure_nginx_if_needed 已执行完成（如需 Nginx 则已确保安装/启动）"
    debug_log "【调试】即将判断是否进入 Argo 分支：need_argo=$(need_argo && echo yes || echo no)，vmag=${vmag:-<空>}"


    # =====================================================
    # 2. Argo 相关逻辑（仅在启用 argo + vmag 时）
    # =====================================================
   if need_argo && [ -n "$vmag" ]; then
        debug_log "【调试】已进入 Argo 启动分支（argo=${argo}，vmag=${vmag}）"
        echo
        echo "=========启用Cloudflared-argo内核========="

    
        # ✅ 3.1 仅在需要 argo 时才确保 cloudflared 存在
        ensure_cloudflared_if_needed || {
            red "❌ 已启用 Argo，但 cloudflared 准备失败，无法继续启用 Argo"
            exit 1
        }
        debug_log "【调试】cloudflared 已准备就绪（已通过 ensure_cloudflared_if_needed 检查）"

         # 2.2 计算 Argo 本地端口
        argoport="${argo_pt:-$ARGO_DEFAULT_PORT}"
        debug_log "【调试】Argo 本地回源端口 argoport=${argoport}（来自 argo_pt 或默认 ARGO_DEFAULT_PORT）"
        echo "$argoport" > "$SINGBOX_FOLDER_PATH/argoport.log"    


        # 仍然记录 Argo 输出节点类型（给 cip 用）
        if [ "$argo" = "vmpt" ]; then
          echo "Vmess" > "$SINGBOX_FOLDER_PATH/vlvm"
        elif [ "$argo" = "trpt" ]; then
          echo "Trojan" > "$SINGBOX_FOLDER_PATH/vlvm"
        fi


        # 2.3 生成 Argo 凭据（JSON / token）
        # 仅用于“当前启动流程”，不用于重启判断
        prepare_argo_credentials "$ARGO_AUTH" "$ARGO_DOMAIN" "$argoport"
        debug_log "【调试】prepare_argo_credentials 完成：ARGO_MODE=${ARGO_MODE:-<未设置>}，ARGO_DOMAIN=${ARGO_DOMAIN:-<空>}（固定隧道需域名+凭据）"

      

        # 2.4 启动 Argo（固定 / 临时）
        if [ -n "$ARGO_DOMAIN" ] && [ -n "$ARGO_AUTH" ]; then
            argo_tunnel_type="固定"
            debug_log "【调试】判定为固定 Argo 隧道（ARGO_DOMAIN + ARGO_AUTH 都存在）"

          if [ "${DEBUG_FLAG:-0}" = "1" ]; then
              _systemctl_path="$(command -v systemctl 2>/dev/null || true)"

              [ -n "$_systemctl_path" ] || _systemctl_path="无"
              _systemd_dir_status="$([ -d /run/systemd/system ] && echo 存在 || echo 不存在)"
              _pid1="$(ps -p 1 -o comm= 2>/dev/null | tr -d '[:space:]')"
              _pid1="$(ps -p 1 -o comm= 2>/dev/null | tr -d '[:space:]')"
              debug_log "【调试】systemd 判定：_has_systemd=$(has_systemd)systemctl=${_systemctl_path}，/run/systemd/system=${_systemd_dir_status}，PID1=${_pid1}"
          fi


          # systemd 判定
          if has_systemd && [ "$EUID" -eq 0 ]; then
              debug_log "【调试】启动方式：systemd 服务（install_argo_service_systemd），模式=${ARGO_MODE}"

              install_argo_service_systemd "$ARGO_MODE" "$ARGO_AUTH"

          elif command -v rc-service >/dev/null 2>&1 && [ "$EUID" -eq 0 ]; then

              debug_log "【调试】启动方式：openrc 服务（install_argo_service_openrc），模式=${ARGO_MODE}"
              install_argo_service_openrc "$ARGO_MODE" "$ARGO_AUTH"
          else
              # 无 systemd / openrc，直接后台启动
              debug_log "【调试】启动方式：无 systemd/openrc，直接后台启动（start_argo_no_daemon，模式=${ARGO_MODE}）"
              start_argo_no_daemon "$ARGO_MODE" "$ARGO_AUTH" "$argoport"
          fi

            # 与原版一致：固定 Argo 域名直接落盘
            echo "$ARGO_DOMAIN" > "$SINGBOX_FOLDER_PATH/sbargoym.log"
            # token 模式下才会有 sbargotoken.log
            [ "$ARGO_MODE" = "token" ] && echo "$ARGO_AUTH" > "$SINGBOX_FOLDER_PATH/sbargotoken.log"
        else
            # 临时 Argo（trycloudflare）
            argo_tunnel_type="临时"
            debug_log "【调试】判定为临时 Argo 隧道（未提供 ARGO_DOMAIN/ARGO_AUTH，走 trycloudflare）"
            debug_log "【调试】启动方式：临时隧道，直接后台启动（start_argo_no_daemon temp），模式=${ARGO_MODE}"
            start_argo_no_daemon "temp" "" "$argoport"
        fi

        # 2.5 等待并检查 Argo 申请结果（原版 sleep + grep 逻辑）
        debug_log "【调试】开始等待并检查 Argo 申请结果：tunnel_type=${argo_tunnel_type}，日志文件：$SINGBOX_FOLDER_PATH/argo.log"
        wait_and_check_argo "$argo_tunnel_type"
    fi

    # =====================================================
    # 3. 安装完成后的 legacy 收尾逻辑
    #    （进程检测）
    # =====================================================
    post_install_finalize_legacy
    debug_log "【调试】post_install_finalize_legacy 已执行完成"

    # ensure_singbox_shortcut
    # debug_log "【调试】ensure_singbox_shortcut 已执行完成（快捷命令/链接）"
}





# Write environment variables to files for persistence
write2SingboxFolders(){
  mkdir -p "$SINGBOX_FOLDER_PATH"

  echo "${vl_sni}"    > "$SINGBOX_FOLDER_PATH/vl_sni"
  echo "${hy_sni}"    > "$SINGBOX_FOLDER_PATH/hy_sni"
  echo "${tu_sni}"    > "$SINGBOX_FOLDER_PATH/tu_sni"
  # any_sni 在 anytls 配置生成时处理，这里不覆盖
  [ ! -s "$SINGBOX_FOLDER_PATH/any_sni" ] && echo "${any_sni}" > "$SINGBOX_FOLDER_PATH/any_sni"
  echo "${cdn_host}"  > "$SINGBOX_FOLDER_PATH/cdn_host"
  echo "${cdn_pt}"   > "$SINGBOX_FOLDER_PATH/cdn_pt"

  # ✅ 只写新变量
  echo "${nginx_pt}"  > "$SINGBOX_FOLDER_PATH/nginx_port"

  echo "${vl_sni_pt}" > "$SINGBOX_FOLDER_PATH/vl_sni_pt"

  # ✅ 订阅开关落盘（默认 false）
  echo "${subscribe}" > "$SINGBOX_FOLDER_PATH/subscribe"
}


#   show status
singbox_status() {
  purple "=========当前内核运行状态========="


  debug_log "【调试】进入 singbox_status() 函数，开始判断 sing-box 状态"
  # 1) sing-box
  if pgrep -f "$SINGBOX_FOLDER_PATH/sing-box" >/dev/null 2>&1; then
 
    # 兼容：sing-box version r1.12.13
    local singbox_version
    singbox_version=$("$SINGBOX_FOLDER_PATH/sing-box" version 2>/dev/null | sed -n 's/.*r\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p')
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

  debug_log "【调试】进入 singbox_status() 函数，开始判断 cloudflared 状态"
  # ✅ cloudflared 安装状态（不影响 Argo 是否启用）
  if [ -x "$SINGBOX_FOLDER_PATH/cloudflared" ] || command -v cloudflared >/dev/null 2>&1; then
    echo "cloudflared：✅ $(green "已安装")"
  else
    echo "cloudflared：❌ $(red "未安装")"
  fi

  # 2) Argo 状态（细分：不需要 / 需要但未运行 / 运行中）
  if ! $argo_needed; then
    debug_log "【调试】进入 singbox_status() 函数，当前场景无需 Argo，由于argo_needed=$argo_needed"
    echo "Argo：✅ $(purple "未启用")（当前场景无需 Argo）"
  else
    debug_log "【调试】进入 singbox_status() 函数，开始判断 cloudflared 状态，argo_needed=$argo_needed"
    if pgrep -f "$SINGBOX_FOLDER_PATH/cloudflared" >/dev/null 2>&1; then
      # 兼容：cloudflared version 2025.11.1
      local cloudflared_version
      cloudflared_version=$("$SINGBOX_FOLDER_PATH/cloudflared" version 2>/dev/null | sed -n 's/.*version \([0-9]\{4\}\.[0-9]\+\.[0-9]\+\).*/\1/p')
      echo "cloudflared Argo (版本V${cloudflared_version:-unknown})：✅ $(green "运行中")"
    else
        echo "Argo：❌ 未运行（已启用 Argo）"
        yellow "❗ 已启用 Argo，但 cloudflared 未运行"

    fi
  fi

  # 3) Nginx + subscribe 状态（细分：不需要 / 未安装 / 未运行 / 运行中）
  debug_log "【调试】进入 singbox_status() 函数，开始判断 Nginx 状态"
  local nginx_port sub_desc
  nginx_port="${nginx_pt:-$NGINX_DEFAULT_PORT}"
  [ -s "$SINGBOX_FOLDER_PATH/nginx_port" ] && nginx_port="$(cat "$SINGBOX_FOLDER_PATH/nginx_port" 2>/dev/null)"

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


  debug_log "【调试】进入 singbox_status() 函数，开始判断 Nginx 状态，进一步区分未安装/未运行/运行中,nginx_needed=$nginx_needed"
  # ✅ 需要 nginx：进一步区分未安装/未运行/运行中
  if ! command -v nginx >/dev/null 2>&1; then
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
  if [ ! -s "$SINGBOX_FOLDER_PATH/jh.txt" ]; then
    purple "❗ 订阅源文件不存在或为空：$SINGBOX_FOLDER_PATH/jh.txt（跳过生成 sub.txt）"
    return 0
  fi

  mkdir -p /var/www/singbox
  local out="/var/www/singbox/sub.txt"

  # ✅ 优先用 openssl（更通用）
  if command -v openssl >/dev/null 2>&1; then
    if openssl base64 -A -in "$SINGBOX_FOLDER_PATH/jh.txt" > "$out" 2>/dev/null; then
      purple "✅ sub.txt 生成成功：$out"
      return 0
    else
      red "❌ sub.txt 生成失败（openssl base64）"
      return 1
    fi
  fi

  # ✅ fallback：base64（兼容 busybox 与 GNU）
  if command -v base64 >/dev/null 2>&1; then
    if base64 -w 0 "$SINGBOX_FOLDER_PATH/jh.txt" 2>/dev/null > "$out"; then
      purple "✅  sub.txt 生成成功：$out"
      return 0
    fi

    # busybox base64 没有 -w 参数
    if base64 "$SINGBOX_FOLDER_PATH/jh.txt" 2>/dev/null | tr -d '\n' > "$out"; then
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
  [ -s "$SINGBOX_FOLDER_PATH/nginx_port" ] && port="$(cat "$SINGBOX_FOLDER_PATH/nginx_port")"

  local sub_uuid
  sub_uuid="$(cat "$SINGBOX_FOLDER_PATH/uuid" 2>/dev/null)"

  [ -z "$sub_uuid" ] && return 0


  local argodomain=$(cat "$SINGBOX_FOLDER_PATH/sbargoym.log" 2>/dev/null)

  local need_argo_flag=false
  vlvm=$(cat $SINGBOX_FOLDER_PATH/vlvm 2>/dev/null);
  # vlvm不为空，则代表一定有argo  
  if [ -n "$vlvm" ]; then
    need_argo_flag=true
  fi
 
    # 当 need_argo_flag 为 true 且 argodomain 为空且 argo.log 存在时
    if $need_argo_flag && [ -z "$argodomain" ] && [ -s "$SINGBOX_FOLDER_PATH/argo.log" ]; then
        argodomain=$(grep -aoE '[a-zA-Z0-9.-]+trycloudflare\.com' "$SINGBOX_FOLDER_PATH/argo.log" 2>/dev/null | tail -n1)
    fi
  
  # 当argodomain 不为空时
  if [ -n "$argodomain" ]; then
    echo "https://${argodomain}/sub/${sub_uuid}"
    return 0
  fi

  # 普通 http：IP:PORT
  local server_ip
  server_ip=$(cat "$SINGBOX_FOLDER_PATH/server_ip.log" 2>/dev/null)

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

  if [ -z "$reality_private" ] && [ -s "$SINGBOX_FOLDER_PATH/reality.key" ]; then
    reality_private="$(awk '/PrivateKey/{print $NF; exit}' "$SINGBOX_FOLDER_PATH/reality.key" 2>/dev/null)"
    reality_public="$(awk '/PublicKey/{print $NF; exit}' "$SINGBOX_FOLDER_PATH/reality.key" 2>/dev/null)"
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
  echo -e "$1" >> "$SINGBOX_FOLDER_PATH/jh.txt"
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




# show nodes
cip(){

    # 日志：只输出到 stderr，不污染 stdout
    debug_log() {
      [ "${DEBUG_FLAG:-0}" = "1" ] && echo -e "$*" >&2
    }
    
    echo
    # 显示 Singbox 状态
    singbox_status
    echo
    
    # 显示本机 v4/v6 + 地区，并在出口 IP 变更时提示
    show_local_ip_info_with_out_ip_hint

    rm -rf "$SINGBOX_FOLDER_PATH/jh.txt"; 
    uuid=$(cat "$SINGBOX_FOLDER_PATH/uuid"); 
    server_ip=$(cat "$SINGBOX_FOLDER_PATH/server_ip.log" 2>/dev/null); 
    sxname=$(cat "$SINGBOX_FOLDER_PATH/name" 2>/dev/null);

    echo "*********************************************************"; 
    purple "Singbox脚本输出节点配置如下："; 
    echo;
    # Hysteria2 protocol (hy2)
    if grep -q "hy2-sb" "$SINGBOX_FOLDER_PATH/sb.json"; then 
        port_hy2=$(cat "$SINGBOX_FOLDER_PATH/port_hy2"); 
        hy_sni=$(cat "$SINGBOX_FOLDER_PATH/hy_sni"); 
        hy2_link="hysteria2://$uuid@$server_ip:$port_hy2?security=tls&alpn=h3&insecure=1&allowInsecure=1&sni=${hy_sni}#${sxname}hy2-$hostname"; 
        yellow "💣【 Hysteria2 】(直连协议)"; 
        green "$hy2_link"
        append_jh "$hy2_link"
        echo; 
    fi
    
    
     # TUIC protocol (tuic or tupt)
    if grep -q "tuic-sb" "$SINGBOX_FOLDER_PATH/sb.json"; then
        port_tu=$(cat "$SINGBOX_FOLDER_PATH/port_tu")
        tu_sni=$(cat "$SINGBOX_FOLDER_PATH/tu_sni"); 
        password=$uuid

        tuic_link="tuic://${uuid}:${password}@${server_ip}:${port_tu}?sni=${tu_sni}&congestion_control=bbr&security=tls&udp_relay_mode=native&alpn=h3&allow_insecure=1#${sxname}tuic-$hostname"
        yellow "💣【 TUIC 】(直连协议)"
        green "$tuic_link" 
        append_jh "$tuic_link"
        echo;
    fi
    # VLESS-Reality-Vision protocol (vless-reality-vision)
    if grep -q "vless-reality-vision-sb" "$SINGBOX_FOLDER_PATH/sb.json"; then
        port_vlr=$(cat "$SINGBOX_FOLDER_PATH/port_vlr")
        public_key=$(sed -n '2p' "$SINGBOX_FOLDER_PATH/reality.key" | awk '{print $2}')
        short_id=$(cat "$SINGBOX_FOLDER_PATH/short_id")
        vl_sni=$(cat "$SINGBOX_FOLDER_PATH/vl_sni")

        debug_log "【调试】cip函数中的short_id,值为:$short_id"

       # vless_link="vless://${uuid}@${server_ip}:${port_vlr}?encryption=none&security=reality&sni=www.yahoo.com&fp=chrome&flow=xtls-rprx-vision&publicKey=${public_key}&shortId=${short_id}#${sxname}vless-reality-$hostname"
        
        vless_link="vless://${uuid}@${server_ip}:${port_vlr}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${vl_sni}&fp=chrome&pbk=${public_key}&sid=${short_id}&type=tcp&headerType=none#${sxname}vless-reality-$hostname" 
        yellow "💣【 VLESS-Reality-Vision 】(直连协议)"; 
        green "$vless_link"
        append_jh "$vless_link"
        echo;

        # 查看节点时提示用户保存私钥（方便下次保持节点一致）,一般这里的$1值为"key"
         print_reality_key "$1"
    fi
    # AnyTLS protocol output
    if grep -q "anytls-sb" "$SINGBOX_FOLDER_PATH/sb.json"; then
        port_any=$(cat "$SINGBOX_FOLDER_PATH/port_any")
        any_sni=$(cat "$SINGBOX_FOLDER_PATH/any_sni")

        anytls_link="anytls://${uuid}@${server_ip}:${port_any}?security=tls&sni=${any_sni}&fp=firefox&insecure=1&allowInsecure=1&type=tcp#${sxname}anytls-$hostname"
        yellow "🔐【 AnyTLS 】(直连协议)"; 
        green "$anytls_link"
        append_jh "$anytls_link"
        echo;
    fi
    #argodomain=$(cat "$SINGBOX_FOLDER_PATH/sbargoym.log" 2>/dev/null); [ -z "$argodomain" ] && argodomain=$(grep -a trycloudflare.com "$SINGBOX_FOLDER_PATH/argo.log" 2>/dev/null | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')
   
    argodomain=$(cat "$SINGBOX_FOLDER_PATH/sbargoym.log" 2>/dev/null)

    if need_argo && [ -z "$argodomain" ] && [ -s "$SINGBOX_FOLDER_PATH/argo.log" ]; then
        argodomain=$(grep -aoE '[a-zA-Z0-9.-]+trycloudflare\.com' "$SINGBOX_FOLDER_PATH/argo.log" 2>/dev/null | tail -n1)
    fi

    cdn_host=$(cat "$SINGBOX_FOLDER_PATH/cdn_host")
    cdn_pt=$(cat "$SINGBOX_FOLDER_PATH/cdn_pt" 2>/dev/null)
    cdn_pt="$(normalize_cdn_pt "$cdn_pt" 443)"

    if [ -n "$argodomain" ]; then
        vlvm=$(cat $SINGBOX_FOLDER_PATH/vlvm 2>/dev/null); uuid=$(cat "$SINGBOX_FOLDER_PATH/uuid")
        if [ "$vlvm" = "Vmess" ]; then
            vmatls_link1="vmess://$(echo "{\"v\":\"2\",\"ps\":\"${sxname}vmess-ws-tls-argo-$hostname-${cdn_pt}\",\"add\":\"${cdn_host}\",\"port\":\"${cdn_pt}\",\"id\":\"$uuid\",\"aid\":\"0\",\"net\":\"ws\",\"host\":\"$argodomain\",\"path\":\"/${uuid}-vm\",\"tls\":\"tls\",\"sni\":\"$argodomain\"}" | base64 | tr -d '\n\r')"
           
            tratls_link1=""
        elif [ "$vlvm" = "Trojan" ]; then
            tratls_link1="trojan://${uuid}@${cdn_host}:${cdn_pt}?security=tls&type=ws&host=${argodomain}&path=%2F${uuid}-tr&sni=${argodomain}&fp=chrome#${sxname}trojan-ws-tls-argo-$hostname-${cdn_pt}"
            vmatls_link1=""
        fi

        sbtk=$(cat "$SINGBOX_FOLDER_PATH/sbargotoken.log" 2>/dev/null); 
        yellow "---------------------------------------------------------"
        yellow "Argo隧道信息 (使用 ${vlvm}-ws 端口: $(cat $SINGBOX_FOLDER_PATH/argoport.log 2>/dev/null))"
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
    yellow "聚合节点: cat $SINGBOX_FOLDER_PATH/jh.txt"; 
    yellow "========================================================="; 
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
    elif command -v rc-service >/dev/null 2>&1; then
        rc-service nginx stop >/dev/null 2>&1
        rc-update del nginx default >/dev/null 2>&1
    fi
    echo "Nginx 已被清理(清理配置文件和禁止自启，nginx 服务已停止)。"
}


# Remove singbox folder
cleandel(){
    # Change to $HOME to avoid issues when deleting directories
   cd "$HOME" || exit 1

    yellow "开始卸载sing-box/cloudflared流程..."; 
    
    # 定义要清理的文件夹列表（兼容旧路径和新路径）
    local folders_to_clean=(
        "$SINGBOX_FOLDER_PATH"
        "$OLD_SINGBOX_FOLDER"
    )
    
    # 继续清理进程
    for P in /proc/[0-9]*; do
        if [ -L "$P/exe" ]; then
            TARGET=$(readlink -f "$P/exe" 2>/dev/null)
            # 检查是否匹配任何要清理的文件夹
            for folder in "${folders_to_clean[@]}"; do
                if echo "$TARGET" | grep -qE "$folder/(cloudflared|sing-box)"; then 
                    kill "$(basename "$P")" 2>/dev/null
                    break
                fi
            done
        fi
    done

    # 杀死进程（兼容两个路径）
    pkill -15 -f "$SINGBOX_FOLDER_PATH/sing-box" 2>/dev/null
    pkill -15 -f "$SINGBOX_FOLDER_PATH/cloudflared" 2>/dev/null
    pkill -15 -f "$OLD_SINGBOX_FOLDER/sing-box" 2>/dev/null
    pkill -15 -f "$OLD_SINGBOX_FOLDER/cloudflared" 2>/dev/null

    # 从配置文件中删除包含 'singbox' 的行
    # sed -i '/.*singbox.*/d' ~/.bashrc
   # sed -i '/.*export PATH="\$HOME\/bin:\$PATH".*/d' ~/.bashrc

    # 立即应用 .bashrc 的修改
    #. ~/.bashrc 2>/dev/null

    # 处理 crontab，兼容 Debian 和 Alpine
    # Debian/Ubuntu 和 Alpine 都支持 crontab，但需要检查 crontab 是否存在
    crontab -l > /tmp/crontab.tmp 2>/dev/null || touch /tmp/crontab.tmp
    sed -i '/.*singbox.*/d' /tmp/crontab.tmp
    sed -i '/.*agsb.*/d' /tmp/crontab.tmp
    crontab /tmp/crontab.tmp >/dev/null 2>&1
    rm /tmp/crontab.tmp

    # 删除快捷命令（兼容两个名称）
    if [ -d "$HOME/bin/singbox" ]; then
        rm -rf "$HOME/bin/singbox"
    fi
    if [ -d "$HOME/bin/agsb" ]; then
        rm -rf "$HOME/bin/agsb"
    fi
    
    # 删除软链接（兼容两个名称）
    rm -f "$HOME/.local/bin/singbox" 2>/dev/null
    rm -f "$HOME/.local/bin/agsb" 2>/dev/null
    rm -f "/usr/local/bin/singbox" 2>/dev/null
    rm -f "/usr/local/bin/agsb" 2>/dev/null
    rm -f "/usr/bin/singbox" 2>/dev/null
    rm -f "/usr/bin/agsb" 2>/dev/null

    if has_systemd; then
        for svc in sb argo singbox-service agsb-singbox; do
            systemctl stop "$svc" >/dev/null 2>&1
            systemctl disable "$svc" >/dev/null 2>&1
        done
        rm -f /etc/systemd/system/{sb.service,argo.service,singbox-service.service,agsb-singbox.service}
        systemctl daemon-reload >/dev/null 2>&1
    elif command -v rc-service >/dev/null 2>&1; then
        for svc in sing-box argo singbox agsb-singbox; do
            rc-service "$svc" stop >/dev/null 2>&1
            rc-update del "$svc" default >/dev/null 2>&1
        done
        rm -f /etc/init.d/{sing-box,argo,singbox,agsb-singbox}
    fi

  # 清理 nginx
  #  pkill -15 nginx >/dev/null 2>&1
  #  rm -f "$(nginx_conf_path)" 2>/dev/null

  yellow "开始卸载或者清理nginx流程..."; 
  cleanup_nginx

  # 清理文件夹（兼容两个路径）
  yellow "开始删除文件夹..."; 
  for folder in "${folders_to_clean[@]}"; do
    if [ -d "$folder" ]; then
      yellow "正在删除：$folder"
      rm -rf "$folder" 2>/dev/null && green "✅ 已删除：$folder" || red "❌ 删除失败：$folder"
    fi
  done

  # yellow "开始卸载或者清理快捷方式流程..."; 
  # cleanup_singbox_shortcut
  
  green "✅ 卸载完成"

}




# Restart sing-box
sbrestart(){
    pkill -15 -f "$SINGBOX_FOLDER_PATH/sing-box" 2>/dev/null

    if has_systemd; then
        systemctl restart sb
    elif command -v rc-service >/dev/null 2>&1; then
        rc-service sing-box restart
    else
        nohup "$SINGBOX_FOLDER_PATH/sing-box" run -c "$SINGBOX_FOLDER_PATH/sb.json" >/dev/null 2>&1 &
    fi
}




# Restart argo
argorestart(){
    # 先尽力停止现有 cloudflared 进程（原版行为）
   pkill -15 -f "$SINGBOX_FOLDER_PATH/cloudflared" 2>/dev/null

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
    if command -v rc-service >/dev/null 2>&1; then
        rc-service argo restart
        return
    fi

    # ===============================
    # 无 init 系统（nohup 启动）
    # 判断顺序非常重要！
    # ===============================

    # 1️⃣ JSON 固定隧道（最高优先级）
    if [ -f "$SINGBOX_FOLDER_PATH/tunnel.yml" ]; then
        nohup "$SINGBOX_FOLDER_PATH/cloudflared" tunnel \
          --edge-ip-version auto \
          --config "$SINGBOX_FOLDER_PATH/tunnel.yml" run \
          >/dev/null 2>&1 &
        return
    fi

    # 2️⃣ token 固定隧道
    if [ -f "$SINGBOX_FOLDER_PATH/sbargotoken.log" ]; then
        nohup "$SINGBOX_FOLDER_PATH/cloudflared" tunnel \
          --no-autoupdate \
          --edge-ip-version auto run \
          --token "$(cat "$SINGBOX_FOLDER_PATH/sbargotoken.log")" \
          >/dev/null 2>&1 &
        return
    fi

    # 3️⃣ 临时 Argo（trycloudflare）
    if [ -f "$SINGBOX_FOLDER_PATH/argoport.log" ]; then
        nohup "$SINGBOX_FOLDER_PATH/cloudflared" tunnel \
          --url "http://localhost:$(cat "$SINGBOX_FOLDER_PATH/argoport.log")" \
          --edge-ip-version auto \
          --no-autoupdate \
          > "$SINGBOX_FOLDER_PATH/argo.log" 2>&1 &
    fi
}


install_step(){
    echo "VPS系统：$op"; 
    echo "CPU架构：$cpu"; 
    echo "Singbox脚本开始安装/更新…………" && sleep 1

    # 获取操作系统名称
    os_name=$(awk -F= '/^NAME/{print $2}' /etc/os-release)

    debug_log "【调试】开始安装各种乱七八糟的依赖"
    install_deps

    debug_log "【调试】安装各种乱七八糟的依赖完成"

    if command -v iptables >/dev/null 2>&1; then
    setenforce 0 >/dev/null 2>&1
    iptables -F
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    fi


    # 检查是否是Debian/Ubuntu系统
    if [[ "$os_name" == *"Debian"* || "$os_name" == *"Ubuntu"* ]]; then
        command -v netfilter-persistent >/dev/null 2>&1 && netfilter-persistent save >/dev/null 2>&1
        mkdir -p /etc/iptables 2>/dev/null
        command -v iptables-save >/dev/null 2>&1 && iptables-save >/etc/iptables/rules.v4 2>/dev/null
        echo "iptables执行开放所有端口 (Debian/Ubuntu)"
    elif [[ "$os_name" == *"Alpine"* ]]; then
        # Alpine没有netfilter-persistent，可以直接保存iptables规则
          mkdir -p /etc/iptables 2>/dev/null
          command -v iptables-save >/dev/null 2>&1 && iptables-save > /etc/iptables/rules.v4 2>/dev/null
          echo "iptables执行开放所有端口 (Alpine)"
    else
        echo "不支持此操作系统"
    fi
    ins; 
    green "Singbox脚本安装完成！即将打印节点信息……"
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
  local vars="trpt vlrt hypt tupt anypt"
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




main(){

  check_port_conflicts_or_exit

  # 启动自定义端口
if [ "$1" = "autostart" ]; then
    enable_autostart
    exit
fi

  # 启动自定义端口
if [ "$1" = "autostart_off" ]; then
    disable_autostart
    exit
fi

# 启动 nginx
if [ "$1" = "nginx_start" ]; then
    nginx_start
    green "Nginx 已完成启动操作！"
    nginx_status
    exit
fi

# 停止 nginx
if [ "$1" = "nginx_stop" ]; then
    nginx_stop
    green "Nginx 已完成停止操作！"
    nginx_status
    exit
fi

# 重启 nginx
if [ "$1" = "nginx_restart" ]; then
    nginx_restart
     green "Nginx 已完成重启操作！"
    nginx_status
    exit
fi

# 查看 nginx 状态
if [ "$1" = "nginx_status" ]; then
    nginx_status
    exit
fi


# 卸载服务
if [ "$1" = "del" ]; then 
    cleandel; 
    rm -rf "$SINGBOX_FOLDER_PATH"; 
    echo "卸载完成"; 
    showmode; 
    exit;
 fi



# 查看可用的节点
if [ "$1" = "list" ]; then 
    
    cip "$2"
    exit; 
fi
# 更新sing-box内核
if [ "$1" = "ups" ]; then 
    pkill -15 -f "$SINGBOX_FOLDER_PATH/sing-box" 2>/dev/null

    upsingbox && sbrestart && echo "Sing-box内核更新完成" && sleep 2 && cip; 
    exit; 
fi
# 重启sing-box和cloudflared
if [ "$1" = "res" ]; then 
    sbrestart; argorestart; 
    sleep 5 && echo "重启完成" && sleep 3 && cip; 
    exit; 
fi

# 生成/更新/查看订阅文件
if [ "$1" = "sub" ]; then
  # 生成/更新订阅文件 sub.txt（函数内部会打印 subscribe 状态 + 生成结果）
  update_subscription_file

  echo -e "📌 节点订阅地址："
  if ! is_true "$(get_subscribe_flag)"; then
    purple "⛔ 未开启订阅"
  else
    u="$(show_sub_url)"
    green "$u"
    echo
  fi

  exit;
fi

# 覆盖式安装
if [ "$1" = "rep" ]; then 
    green "开始覆盖式安装流程..."; 
    green "1、即将开始清理操作..."; 
    cleandel; 
    rm -rf "$SINGBOX_FOLDER_PATH"/{sb.json,sbargoym.log,sbargotoken.log,argo.log,argoport.log,name,short_id,cdn_host,hy_sni,vl_sni,tu_sni,any_sni,vl_sni_pt,cdn_pt}; 
    green "1.1、清理操作完成..."; 
    sleep 2; 

    green "2、覆盖式安装开始..."; 
    install_step
    echo "覆盖式安装已完成... 再见👋"; 
    exit;
fi

# 只在明确 ins 时才安装；无参数只显示菜单
if [ "$1" = "ins" ]; then
    yellow "开始安装流程..."
    install_step
    exit
fi

# 无参数：只展示帮助/菜单
if [ -z "$1" ]; then
    showmode
    exit
fi

}

main "$@"
