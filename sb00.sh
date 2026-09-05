#!/bin/sh
# 若没有 bash 则自动安装
if [ -z "${BASH_VERSION}" ]; then
  if command -v apk >/dev/null 2>&1; then
    echo "正在安装 bash..."
    apk add --no-cache bash >/dev/null 2>&1
  fi
  if command -v bash >/dev/null 2>&1; then
    exec bash "$0" "$@"
  else
    echo "错误：需要 bash 运行此脚本，请先安装 bash。" >&2
    exit 1
  fi
fi


export LANG=en_US.UTF-8

# ================== 文件夹路径配置 ==================
# 统一定义文件夹名称和路径，方便后续修改
SB_FOLDER="doraemon"
SINGBOX_FOLDER_PATH="/root/$SB_FOLDER"
OLD_SINGBOX_FOLDER="/root/agsb" # 旧路径，用于兼容和清理
LOGS_DIR="$SINGBOX_FOLDER_PATH/logs" # 统一日志目录（所有脚本日志集中于此）
INSTALL_LOG="$LOGS_DIR/install.log" # 脚本安装日志（仅保留最近一次安装）
# ================== 文件夹路径配置 结束 ==================

VERSION="1.0.30(2026-09-05)"
AUTHOR="littleDoraemon"

# Environment variables for controlling CDN host and SNI values
export cdn_host=${cdn_host:-"saas.sin.fan"} # Default CDN host for vmess/trojan/vless  cdn.7zz.cn
export hy_sni=${hy_sni:-"www.apple.com"}    # Default SNI for hy2 protocol
export vl_sni=${vl_sni:-"www.apple.com"}    # Default SNI for vless protocol   www.ua.edu www.yahoo.com
export tu_sni=${tu_sni:-"www.apple.com"}    # Default SNI for hy2 protocol
export any_sni=${any_sni:-"www.apple.com"}  # Default SNI for anytls protocol

# Environment variables for ports and other settings
export uuid=${uuid:-''}
export port_vm_ws=${vmpt:-''}
export port_vl_ws=${vlpt:-''}
export port_tr=${trpt:-''}
export port_hy2=${hypt:-''}
export port_vlr=${vlrt:-''}
export port_tu=${tupt:-''}
export port_any=${anypt:-''}
export port_socks5=${socks5pt:-''}
export socks5_username=${socks5_username:-''}
export socks5_password=${socks5_password:-''}
export socks5_wl_flag=${socks5_wl_flag:-''}  # socks5 IP白名单开关: true/1=开启, 空/其他=关闭(默认)
export socks5_ips=${socks5_ips:-''}      # socks5 IP白名单列表, 逗号分隔 (如 "1.2.3.4,5.6.7.0/24")

# 获取到的IP和出口ip不一样的时候，优先使用出口ip也就是out_ip
export out_ip=${out_ip:-''}

# Argo 相关环境变量
export argo=${argo:-''}
export ARGO_DOMAIN=${agn:-''}
export ARGO_AUTH=${agk:-''}
export ippz=${ippz:-''}
export name=${name:-''}

# 默认端口
readonly NGINX_DEFAULT_PORT=8080
readonly ARGO_DEFAULT_PORT=8001

# iptables/ip6tables 规则标记常量（用于精确识别本脚本添加的防火墙规则）
readonly IPTABLES_COMMENT_SINGBOX="doraemon_singbox_rule"   # 非socks5协议 + 无白名单时的socks5
readonly IPTABLES_COMMENT_SOCKS5="socks5_rule"              # 有白名单时的socks5

#
export nginx_pt=${nginx_pt:-$NGINX_DEFAULT_PORT} # 订阅服务端口（Nginx）
export argo_pt=${argo_pt:-$ARGO_DEFAULT_PORT}    # Argo 回源入口端口（本地）

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
SCRIPT_URL="https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb00.sh"

CN_BING="www.bing.com"

v4_ok=false
v6_ok=false

# 调试日志开关
export DEBUG_FLAG=${DEBUG_FLAG:-'0'}

# ================== 常量和环境变量 结束 ==================

# ================== 颜色函数 ==================
# 每个打印函数在终端显示的同时，把纯文本同步追加写入脚本安装日志
# （_log_write 仅在 run_install_logged 安装期间开启，其余时间为空操作）
white() { printf "\033[1;37m%s\033[0m\n" "$1"; _log_write "$1"; }
black() { printf "\033[1;30m%s\033[0m\n" "$1"; _log_write "$1"; }
red() { printf "\e[1;91m%s\e[0m\n" "$1"; _log_write "$1"; }
green() { printf "\e[1;32m%s\e[0m\n" "$1"; _log_write "$1"; }
yellow() { printf "\e[1;33m%s\e[0m\n" "$1"; _log_write "$1"; }
blue() { printf "\e[1;34m%s\e[0m\n" "$1"; _log_write "$1"; }
purple() { printf "\e[1;35m%s\e[0m\n" "$1"; _log_write "$1"; }
#彩虹打印
gradient() {
    local text="$1"
    local colors=(196 202 208 214 220 190 82 46 51 39 33)
    local i=0
    for ((n = 0; n < ${#text}; n++)); do
        printf "\033[38;5;${colors[i]}m%s\033[0m" "${text:n:1}"
        i=$(((i + 1) % ${#colors[@]}))
    done
    echo
    _log_write "$text"
}
# ================== 颜色函数 ==================

is_true() {
    [ "$(printf '%s' "${1:-}" | tr 'A-Z' 'a-z')" = "true" ]
}

debug_log() {
    [ "${DEBUG_FLAG:-0}" = "1" ] && echo -e "$*" >&2
}

debug_print() {
    [ "${DEBUG_FLAG:-0}" = "1" ] && "$@"
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
# trpt / hypt / vmpt / vlpt / vlrt / tupt / anypt / socks5pt
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

if [ -n "${vlpt+x}" ]; then
    vlp=yes
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

if [ -n "${socks5pt+x}" ]; then
    socksp=yes
fi

# 判断：至少启用一个协议
any_proto_enabled() {
    is_yes "$vlr" || is_yes "$vmp" || is_yes "$vlp" || is_yes "$trp" || is_yes "$hyp" || is_yes "$tup" || is_yes "$anyp" || is_yes "$socksp"
}

# 判断：是否需要 Argo
need_argo() {
    local argo_needed=0 # 0=false, 1=true（用数字更直观）
    local argo_src=""   # debug：值来源
    local argo_val=""   # debug：实际拿来判断的值

    if [ -n "${argo:-}" ]; then
        argo_src="env"
        argo_val="$argo"
        if [ "$argo_val" = "vmpt" ] || [ "$argo_val" = "trpt" ] || [ "$argo_val" = "vlpt" ]; then
            argo_needed=1
        fi
    elif [ -s "$SINGBOX_FOLDER_PATH/vlvm" ]; then
        argo_src="file"
        argo_val="$(cat "$SINGBOX_FOLDER_PATH/vlvm" 2> /dev/null | tr -d '\r\n')"
        if [ "$argo_val" = "Vmess" ] || [ "$argo_val" = "Trojan" ] || [ "$argo_val" = "Vless" ]; then
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
# 命令参数转小写，供顶层 guard 大小写不敏感比对
_cmd0="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')"

# 无参数或 menu 命令（交互式菜单）时跳过“必须设置协议变量”的守卫
if [ -n "$_cmd0" ] && [ "$_cmd0" != "menu" ]; then
    # 收窄为仅匹配本脚本安装路径的 sing-box 进程，避免误判系统中其他 sing-box
    if pgrep -f "$SINGBOX_FOLDER_PATH/sing-box" > /dev/null 2>&1; then
        # 已安装
        if [ "$_cmd0" = "rep" ]; then
            any_proto_enabled || {
                echo "提示：rep重置协议时，请在脚本前至少设置一个协议变量哦，再见！🎯"
                exit 1
            }
        fi
    else
        # 未安装
        if [ "$_cmd0" != "del" ]; then
            any_proto_enabled || {
                echo "提示：未安装脚本，请在脚本前至少设置一个协议变量哦，再见！🎯"
                exit 1
            }
        fi
    fi
fi

# 判断系统是否支持 systemd
has_systemd() {
    command -v systemctl > /dev/null 2>&1 || return 1
    [ -d /run/systemd/system ] || return 1
    # 可选：更严格，确保 PID1 就是 systemd（不想太严格可删掉这一行）
    [ "$(ps -p 1 -o comm= 2> /dev/null | tr -d '[:space:]')" = "systemd" ] || return 1
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
    local fail_log="$LOGS_DIR/deps_failed.log"
    mkdir -p "$LOGS_DIR" 2> /dev/null || true

    # 找出缺的命令
    local -a missing=()
    local c
    for c in "${NEED_CMDS[@]}"; do
        command -v "$c" > /dev/null 2>&1 || missing+=("$c")
    done

    # 都齐了就直接返回
    if [ "${#missing[@]}" -eq 0 ]; then
        debug_print green "✅ 依赖已齐全，跳过安装"
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

        pkg_installed() {
            local pkg="$1"
            case "$label" in
                apt-get)
                    dpkg -s "$pkg" > /dev/null 2>&1
                    ;;
                yum | dnf)
                    rpm -q "$pkg" > /dev/null 2>&1
                    ;;
                apk)
                    apk info -e "$pkg" > /dev/null 2>&1
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

            # 实时输出安装过程（安装日志会同步记录），失败包记录后跳过
            if "${_cmd[@]}" "$p"; then
                debug_log "【调试】 ✅ 安装成功：$p"
                green "✅ 安装成功：$p"
            else
                red "❌ 安装失败：${p}（已跳过）"
                failed+=("$p")
            fi
        done

        if [ "${#failed[@]}" -gt 0 ]; then
            yellow "❗ 以下包安装失败（已跳过）："
            yellow "   ${failed[*]}"
            {
                echo "----- $(date '+%F %T') ${label} failed pkgs -----"
                printf '%s\n' "${failed[@]}"
            } >> "$fail_log" 2> /dev/null || true
            yellow "📌 失败包已记录到：${fail_log}"
        fi

        return 0
    }

    # =========================
    # Debian/Ubuntu (apt-get)
    # =========================
    if command -v apt-get > /dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive

        # 等待 apt/dpkg 锁（避免死等；默认 180s，可用 APT_LOCK_WAIT 覆盖）
        local max_wait="${APT_LOCK_WAIT:-180}"
        local waited=0
        while fuser /var/lib/dpkg/lock-frontend > /dev/null 2>&1 \
            || fuser /var/lib/dpkg/lock > /dev/null 2>&1; do
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
            update || {
            red "❌ apt-get update 失败（DNS/网络/源不可用）"
            return 1
        }

        local -a APT_PKGS=(
            curl wget jq openssl
            iptables iproute2
            lsof
            psmisc
            coreutils
            ca-certificates
            vim-common # 提供 xxd（大多数 Debian/Ubuntu）
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
    elif command -v yum > /dev/null 2>&1 || command -v dnf > /dev/null 2>&1; then
        local pm="yum"
        command -v dnf > /dev/null 2>&1 && pm="dnf"

        local -a YUM_DNF_PKGS=(
            curl wget jq openssl
            iptables iproute
            lsof
            psmisc
            coreutils
            ca-certificates
            vim-common # 多数发行版提供 xxd
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
    elif command -v apk > /dev/null 2>&1; then
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
        if ! command -v xxd > /dev/null 2>&1; then
            yellow "👉 尝试补齐 xxd（可选）"
            apk add --no-cache xxd > /dev/null 2>&1 || apk add --no-cache vim > /dev/null 2>&1 || true
            command -v xxd > /dev/null 2>&1 && green "✅ xxd 已可用" || yellow "❗ xxd 仍不可用（不致命，继续）"
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
        command -v "$c" > /dev/null 2>&1 || miss=1
    done

    # 下载工具至少要有一个（curl 或 wget）
    if ! command -v curl > /dev/null 2>&1 && ! command -v wget > /dev/null 2>&1; then
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
    local timeout="${IP_CHECK_TIMEOUT:-2}" # 默认 2 秒（你也可以设成 1）
    local v4="" v6=""

    # IPv4
    v4="$(curl -s4 -m"$timeout" --connect-timeout "$timeout" "$v46url" 2> /dev/null \
        || wget -4 -qO- --tries=1 --timeout="$timeout" "$v46url" 2> /dev/null)"

    debug_log "[调试] check_ip_connectivity函数IPv4: $v4"
    # IPv6
    v6="$(curl -s6 -m"$timeout" --connect-timeout "$timeout" "$v46url" 2> /dev/null \
        || wget -6 -qO- --tries=1 --timeout="$timeout" "$v46url" 2> /dev/null)"
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
    if command -v systemctl > /dev/null 2>&1 && [ -d /run/systemd/system ]; then
        cat > /etc/systemd/system/${svc}.service << EOF
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
        systemctl enable --now "${svc}.service" > /dev/null 2>&1
        systemctl restart "${svc}.service" > /dev/null 2>&1
        echo "✅ 已开启开机自启（systemd）：${svc}"
        return 0
    fi

    # openrc (Alpine)
    if command -v rc-service > /dev/null 2>&1 && command -v rc-update > /dev/null 2>&1; then
        # ❗ 用 quoted heredoc（<< 'EOF'）写模板，再用 sed 替换占位符 __SB_PATH__。
        # 避免 bash 在写文件时把 openrc 脚本内部的 ${name}/$command/$pidfile/$command_args/$?
        # 当成当前 shell 变量展开（旧版 bug：生成文件变成 --exec ""，start/stop 全部失效）。
        cat > /etc/init.d/${svc} << 'OPENRC_SB00'
#!/sbin/openrc-run
name="singbox service"
description="singbox service"
command="__SB_PATH__/sing-box"
command_args="run -c __SB_PATH__/sb.json"
command_background="yes"
pidfile="/run/singbox.pid"

depend() {
  need net
  after firewall
}

start_pre() {
  [ -x __SB_PATH__/sing-box ] || return 1
  [ -s __SB_PATH__/sb.json ] || return 1
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
OPENRC_SB00

        sed -i "s|__SB_PATH__|${SINGBOX_FOLDER_PATH}|g" "/etc/init.d/${svc}"

        chmod +x /etc/init.d/${svc}
        rc-update add "${svc}" default > /dev/null 2>&1
        rc-service "${svc}" restart > /dev/null 2>&1
        echo "✅ 已开启开机自启（openrc）：${svc}"
        return 0
    fi

    echo "❗ 未检测到 systemd 或 openrc，无法设置开机自启"
    return 1
}

# 关闭自启
disable_autostart() {
    local svc="singbox-service"

    if command -v systemctl > /dev/null 2>&1 && [ -d /run/systemd/system ]; then
        systemctl disable --now "${svc}.service" > /dev/null 2>&1
        rm -f "/etc/systemd/system/${svc}.service"
        systemctl daemon-reload > /dev/null 2>&1
        echo "✅ 已关闭开机自启（systemd）：${svc}"
        return 0
    fi

    if command -v rc-service > /dev/null 2>&1 && command -v rc-update > /dev/null 2>&1; then
        rc-update del "${svc}" default > /dev/null 2>&1
        rc-service "${svc}" stop > /dev/null 2>&1
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
    cat > "$wrapper" << EOF
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
    chmod +x "$wrapper" 2> /dev/null || true

    # ✅ 用户级入口（建链接）
    ln -sf "$wrapper" "$link_local1" 2> /dev/null || true
    chmod +x "$link_local1" 2> /dev/null || true

    ln -sf "$wrapper" "$link_local2" 2> /dev/null || true
    chmod +x "$link_local2" 2> /dev/null || true

    # ✅ root：系统目录入口（通常立刻生效，且不需要改 PATH）
    if [ "$(id -u)" -eq 0 ]; then
        [ -d "/usr/local/bin" ] || mkdir -p /usr/local/bin 2> /dev/null || true
        if [ -d "/usr/local/bin" ] && [ -w "/usr/local/bin" ]; then
            ln -sf "$wrapper" "$link_sys1" 2> /dev/null || true
            chmod +x "$link_sys1" 2> /dev/null || true
        elif [ -d "/usr/bin" ] && [ -w "/usr/bin" ]; then
            ln -sf "$wrapper" "$link_sys2" 2> /dev/null || true
            chmod +x "$link_sys2" 2> /dev/null || true
        fi
    fi

    # ✅ 尽力让“当前 shell”立刻识别（不修改环境文件）
    hash -r 2> /dev/null || true
    command -v rehash > /dev/null 2>&1 && rehash 2> /dev/null || true

    # ✅ 输出结果
    if command -v singbox > /dev/null 2>&1; then
        echo ""
        purple " 已创建快捷命令：singbox（$(command -v singbox)）"
    else
        yellow "❗ 已创建 wrapper/软链接，但当前 PATH 未命中 singbox"
        yellow "👉 你仍可直接运行："
        green "   $wrapper"
        yellow "👉 或用以下任一路径（若已在 PATH 中则可直接敲 singbox）："
        green "   $link_local1"
        green "   $link_local2"
        [ "$(id -u)" -eq 0 ] && {
            green "   $link_sys1"
            green "   $link_sys2"
        }
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
    rm -f "$link_local1" 2> /dev/null || true
    rm -f "$link_local2" 2> /dev/null || true
    rm -f "$wrapper" 2> /dev/null || true

    # root 才能删系统目录入口
    if [ "$(id -u)" -eq 0 ]; then
        rm -f "$link_sys1" 2> /dev/null || true
        rm -f "$link_sys2" 2> /dev/null || true
    fi

    # 2) 刷新命令缓存
    hash -r 2> /dev/null || true
    command -v rehash > /dev/null 2>&1 && rehash 2> /dev/null || true

    # 3) 输出结果
    if command -v singbox > /dev/null 2>&1; then
        yellow "❗ cleanup 已执行，但当前会话仍能找到 singbox：$(command -v singbox)"
        yellow "👉 若你之前把某个路径手动加进 PATH，或 shell 有缓存，重新开一个终端/SSH 会话即可"
    else
        green "✅ 已清理快捷命令（wrapper/软链接）"
    fi
}

# 创建 sb 快捷命令（参照 lwsb.sh 的 /usr/bin/sb：本地脚本优先，否则在线拉取）
ensure_sb_shortcut() {
    local sbw="$SINGBOX_FOLDER_PATH/sb-cmd"

    mkdir -p "$SINGBOX_FOLDER_PATH" 2> /dev/null || true
    cat > "$sbw" << EOF
#!/usr/bin/env bash
set -e
SB_FOLDER="$SINGBOX_FOLDER_PATH"
LOCAL_SCRIPT="\$SB_FOLDER/sb.sh"

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
    chmod +x "$sbw" 2> /dev/null || true

    local done_link=""
    if [ "$(id -u)" -eq 0 ]; then
        [ -d "/usr/local/bin" ] || mkdir -p /usr/local/bin 2> /dev/null || true
        if [ -d "/usr/local/bin" ] && [ -w "/usr/local/bin" ]; then
            ln -sf "$sbw" /usr/local/bin/sb 2> /dev/null || true
            chmod +x /usr/local/bin/sb 2> /dev/null || true
            done_link="/usr/local/bin/sb"
        elif [ -d "/usr/bin" ] && [ -w "/usr/bin" ]; then
            ln -sf "$sbw" /usr/bin/sb 2> /dev/null || true
            chmod +x /usr/bin/sb 2> /dev/null || true
            done_link="/usr/bin/sb"
        fi
    fi

    # 尽力让“当前 shell”立刻识别
    hash -r 2> /dev/null || true
    command -v rehash > /dev/null 2>&1 && rehash 2> /dev/null || true

    if [ -n "$done_link" ] && [ -e "$done_link" ]; then
        echo ""
        green " ✅ 已创建快捷命令：sb（${done_link}）"
        echo ""
        print_sb_shortcut_help
    else
        echo ""
        yellow " ⚠️ 已生成 wrapper，但未能写入系统目录，请手动执行："
        green "   ln -sf $sbw /usr/local/bin/sb"
    fi
}

# 罗列 sb 快捷指令及功能（一条一行）
print_sb_shortcut_help() {
    green " 常用指令："
    green "    sb                 打开主菜单"
    green "    sb ins             安装节点"
    green "    sb rep             覆盖式安装/重置"
    green "    sb list            查看节点信息"
    green "    sb list key        查看节点 + vless Reality 私钥"
    green "    sb res             重启 sing-box 和 cloudflared"
    green "    sb rt              分流管理"
    green "    sb node            节点配置修改 (端口/订阅/SNI/Argo)"
    green "    sb sub             订阅管理"
    green "    sb del             卸载（保留二进制）"
    green "    sb delall          卸载全部并清理"
    green "    sb ups             更新 sing-box 内核"
    green "    sb sc              创建/刷新本快捷命令"
    green "    sb sc_off          删除本快捷命令"
    green "    sb autostart       开启开机自启"
    green "    sb autostart_off   关闭开机自启"
    green "    sb nginx_start     启动 Nginx"
    green "    sb nginx_stop      停止 Nginx"
    green "    sb nginx_restart   重启 Nginx"
    green "    sb nginx_status    查看 Nginx 状态"
    green "    sb logs            查看日志菜单（Sing-box/Argo/Nginx/安装日志）"
    green "    sb log_sb 100      查看 Sing-box 运行日志（最近100行）"
    green "    sb log_argo 100    查看 Argo 隧道日志（最近100行）"
    green "    sb log_ins         查看最近一次安装日志（全文）"
    green "    sb log_stop        查看服务停止原因日志（排查崩溃用）"
}

# 清理 sb 快捷命令
cleanup_sb_shortcut() {
    if [ "$(id -u)" -eq 0 ]; then
        rm -f /usr/local/bin/sb 2> /dev/null || true
        rm -f /usr/bin/sb 2> /dev/null || true
    fi
    rm -f "$SINGBOX_FOLDER_PATH/sb-cmd" 2> /dev/null || true

    hash -r 2> /dev/null || true
    command -v rehash > /dev/null 2>&1 && rehash 2> /dev/null || true

    if command -v sb > /dev/null 2>&1; then
        yellow "❗ cleanup 已执行，但当前会话仍能找到 sb：$(command -v sb)"
        yellow "👉 重新开一个终端/SSH 会话即可"
    else
        green "✅ 已清理 sb 快捷命令"
    fi
}

# sb 快捷命令（查看指令说明页面）
interactive_sb_shortcut_menu() {
    clear
    green "========= [6] sb 快捷命令 ========="
    echo ""
    if command -v sb > /dev/null 2>&1; then
        green " 当前状态：✅ 已安装（$(command -v sb)）"
    else
        yellow " 当前状态：未安装（安装/重装节点时会自动创建）"
    fi
    echo ""
    print_sb_shortcut_help
    echo ""
    menu_pause
}

# 显示菜单
showmode() {
    blue "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    green "     Sing-box 一键脚本"
    yellow "     协议: vmess/trojan/vless (Argo 选1)"
    yellow "          vless reality+hy2+tuic+anytls+socks5"
    green "     Author：$AUTHOR"
    green "     Version: ${VERSION}"
    blue "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# 安装 Nginx 包
install_nginx_pkg() {
    # 已安装就不重复装
    if command -v nginx > /dev/null 2>&1; then
        return 0
    fi

    yellow "👉 正在安装 Nginx..."

    # 统一把详细输出写到日志，失败时 tail 出来
    mkdir -p "$LOGS_DIR" 2> /dev/null
    local log="$LOGS_DIR/nginx_install.log"
    : > "$log" 2> /dev/null || true

    # Debian/Ubuntu (apt-get)
    if command -v apt-get > /dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive

        # 1) 等待 apt/dpkg 锁（默认最多等 20s，可用 APT_LOCK_WAIT 覆盖）
        local max_wait="${APT_LOCK_WAIT:-20}"
        local waited=0

        while fuser /var/lib/dpkg/lock-frontend > /dev/null 2>&1 \
            || fuser /var/lib/dpkg/lock > /dev/null 2>&1; do
            waited=$((waited + 1))

            # ✅ 写法B：每秒更新同一行（不刷屏）
            printf "\r\033[0K\e[1;33m⏳ 等待 apt/dpkg 锁释放... (%s/%ss)\033[0m" "$waited" "$max_wait"

            if [ "$waited" -ge "$max_wait" ]; then
                echo
                red "❌ 等待 apt/dpkg 锁超时：${max_wait}s"
                yellow "❗ 常见原因：apt-daily / unattended-upgrades 在后台更新"
                yellow "👉 解决：稍后重试，或临时加长：APT_LOCK_WAIT=180"
                # 给个线索（不杀进程，只展示）
                ps aux 2> /dev/null | grep -E 'apt|dpkg|unattended|apt-daily' | grep -v grep | head -n 10 || true
                return 1
            fi

            sleep 1
        done
        echo # 结束等待后换行，避免后续输出接在同一行

        # 2) 尝试修复 dpkg 中断（减少“莫名其妙失败”）
        dpkg --configure -a >> "$log" 2>&1 || true
        apt-get -f install -y >> "$log" 2>&1 || true

        # 3) update 加重试+超时（稳定很多）
        if ! apt-get -o Acquire::Retries=3 \
            -o Acquire::http::Timeout=15 \
            -o Acquire::https::Timeout=15 \
            update >> "$log" 2>&1; then
            red "❌ apt-get update 失败（可能是 DNS/网络/源问题），详见：$log"
            tail -n 60 "$log" 2> /dev/null || true
            return 1
        fi

        # 4) 安装 nginx（同样加重试+超时）
        if ! apt-get -o Acquire::Retries=3 \
            -o Acquire::http::Timeout=15 \
            -o Acquire::https::Timeout=15 \
            install -y nginx >> "$log" 2>&1; then
            red "❌ Nginx 安装失败，详见：$log"
            tail -n 80 "$log" 2> /dev/null || true
            return 1
        fi

    elif command -v apt > /dev/null 2>&1; then
        # 兜底：尽量用 apt-get，但这里保留 apt
        export DEBIAN_FRONTEND=noninteractive
        if ! apt update >> "$log" 2>&1 || ! apt install -y nginx >> "$log" 2>&1; then
            red "❌ Nginx 安装失败，详见：$log"
            tail -n 80 "$log" 2> /dev/null || true
            return 1
        fi

    elif command -v yum > /dev/null 2>&1; then
        yum install -y nginx >> "$log" 2>&1 || {
            red "❌ Nginx 安装失败，详见：$log"
            tail -n 80 "$log" 2> /dev/null || true
            return 1
        }

    elif command -v dnf > /dev/null 2>&1; then
        dnf install -y nginx >> "$log" 2>&1 || {
            red "❌ Nginx 安装失败，详见：$log"
            tail -n 80 "$log" 2> /dev/null || true
            return 1
        }

    elif command -v apk > /dev/null 2>&1; then
        apk add --no-cache nginx >> "$log" 2>&1 || {
            red "❌ Nginx 安装失败，详见：$log"
            tail -n 80 "$log" 2> /dev/null || true
            return 1
        }

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
    [ -z "$p" ] && {
        echo "$fallback"
        return 0
    }

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

# 随机端口（尽量避开已在监听的端口，最多重试 20 次）
rand_port() {
    local p="" tries=0
    while [ "$tries" -lt 20 ]; do
        # 优先用 shuf（最常见）
        if command -v shuf > /dev/null 2>&1; then
            p="$(shuf -i 10000-65535 -n 1)"
        elif command -v awk > /dev/null 2>&1; then
            # 备选：awk + 随机种子（兼容性很好）
            p="$(awk -v s="$(od -An -N4 -tu4 /dev/urandom 2>/dev/null)" 'BEGIN{srand(s); print int(10000 + rand()*55535)}')"
        else
            # 兜底：用时间戳拼一个（保证有结果）
            p=$((($(date +%s) % 55535) + 10000))
        fi
        tries=$((tries + 1))
        # 有 ss 时检查 TCP/UDP 是否已监听；被占用则换下一个
        if command -v ss > /dev/null 2>&1; then
            if { ss -ltn 2>/dev/null; ss -uln 2>/dev/null; } | grep -qE "[:.]${p}[[:space:]]"; then
                continue
            fi
        fi
        break
    done
    echo "$p"
}

# 生成 UUID v4
gen_uuid() {
    local _g
    _g="$(cat /proc/sys/kernel/random/uuid 2>/dev/null)"
    [ -z "$_g" ] && _g="$(uuidgen 2>/dev/null | tr '[:upper:]' '[:lower:]')"
    if [ -z "$_g" ]; then
        _g="$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')"
        _g="${_g:0:8}-${_g:8:4}-4${_g:13:3}-${_g:17:4}-${_g:21:12}"
    fi
    printf '%s' "$_g"
}

# 生成 reality_private（32 字节随机 base64）
gen_reality_private() {
    head -c 32 /dev/urandom 2>/dev/null | base64 | tr -d '\n'
}

gen_socks5_username() {
    tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 10
}

gen_socks5_password() {
    tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 12
}

init_socks5_credentials() {
    if [ -n "${socks5_username:-}" ]; then
        printf '%s\n' "$socks5_username" > "$SINGBOX_FOLDER_PATH/socks5_user"
    elif [ -s "$SINGBOX_FOLDER_PATH/socks5_user" ]; then
        socks5_username=$(cat "$SINGBOX_FOLDER_PATH/socks5_user")
    else
        socks5_username=$(gen_socks5_username)
        printf '%s\n' "$socks5_username" > "$SINGBOX_FOLDER_PATH/socks5_user"
    fi

    if [ -n "${socks5_password:-}" ]; then
        printf '%s\n' "$socks5_password" > "$SINGBOX_FOLDER_PATH/socks5_pass"
    elif [ -s "$SINGBOX_FOLDER_PATH/socks5_pass" ]; then
        socks5_password=$(cat "$SINGBOX_FOLDER_PATH/socks5_pass")
    else
        socks5_password=$(gen_socks5_password)
        printf '%s\n' "$socks5_password" > "$SINGBOX_FOLDER_PATH/socks5_pass"
    fi

    chmod 600 "$SINGBOX_FOLDER_PATH/socks5_user" "$SINGBOX_FOLDER_PATH/socks5_pass" 2> /dev/null || true
}

# 初始化 socks5 IP白名单配置：从环境变量或文件加载/保存
init_socks5_whitelist() {
    # 优先读文件（已安装场景），否则用环境变量
    if [ -s "$SINGBOX_FOLDER_PATH/socks5_wl_flag" ]; then
        socks5_wl_flag=$(cat "$SINGBOX_FOLDER_PATH/socks5_wl_flag" | tr -d '\r\n')
    fi
    if [ -s "$SINGBOX_FOLDER_PATH/socks5_ips" ]; then
        socks5_ips=$(cat "$SINGBOX_FOLDER_PATH/socks5_ips" | tr -d '\r\n')
    fi

    # 环境变量有值时写入文件（覆盖安装场景）
    if [ -n "${socks5_wl_flag}" ]; then
        printf '%s\n' "$socks5_wl_flag" > "$SINGBOX_FOLDER_PATH/socks5_wl_flag"
    fi
    if [ -n "${socks5_ips}" ]; then
        printf '%s\n' "$socks5_ips" > "$SINGBOX_FOLDER_PATH/socks5_ips"
    fi
}

# 清除本脚本添加的所有 iptables/ip6tables 规则（通过 --comment 标记识别）
flush_singbox_iptables_rules() {
    local _cmt
    for _cmt in "$IPTABLES_COMMENT_SINGBOX" "$IPTABLES_COMMENT_SOCKS5"; do
        if command -v iptables > /dev/null 2>&1; then
            while iptables -L INPUT -n --line-numbers 2>/dev/null | grep -q "$_cmt"; do
                local _ln
                _ln=$(iptables -L INPUT -n --line-numbers 2>/dev/null | grep "$_cmt" | head -1 | awk '{print $1}')
                [ -n "$_ln" ] && iptables -D INPUT "$_ln" 2>/dev/null || break
            done
        fi
        if command -v ip6tables > /dev/null 2>&1; then
            while ip6tables -L INPUT -n --line-numbers 2>/dev/null | grep -q "$_cmt"; do
                local _ln
                _ln=$(ip6tables -L INPUT -n --line-numbers 2>/dev/null | grep "$_cmt" | head -1 | awk '{print $1}')
                [ -n "$_ln" ] && ip6tables -D INPUT "$_ln" 2>/dev/null || break
            done
        fi
    done
}

# 保存 iptables/ip6tables 规则（跨重启持久化）
_save_iptables_rules() {
    local os_name=""
    [ -f /etc/os-release ] && os_name=$(awk -F= '/^NAME/{print $2}' /etc/os-release 2>/dev/null)
    mkdir -p /etc/iptables 2>/dev/null
    if command -v iptables-save > /dev/null 2>&1; then
        iptables-save > /etc/iptables/rules.v4 2>/dev/null
    fi
    if command -v ip6tables-save > /dev/null 2>&1; then
        ip6tables-save > /etc/iptables/rules.v6 2>/dev/null
    fi
    if [[ "$os_name" == *"Debian"* || "$os_name" == *"Ubuntu"* ]]; then
        command -v netfilter-persistent > /dev/null 2>&1 && netfilter-persistent save 2>/dev/null
    fi
}

# 为所有 sing-box 协议端口添加 iptables ACCEPT 规则（通过 --comment 标记识别）
# socks5 无白名单时用 doraemon_singbox_rule，有白名单时由 apply_socks5_whitelist 处理
apply_singbox_iptables_rules() {
    local sbj="$SINGBOX_FOLDER_PATH/sb.json"
    [ ! -s "$sbj" ] && return 0

    # 获取 socks5 端口和白名单状态
    local port_socks5=""
    local wl_flag=""
    [ -s "$SINGBOX_FOLDER_PATH/socks5_wl_flag" ] && wl_flag=$(cat "$SINGBOX_FOLDER_PATH/socks5_wl_flag" | tr -d '\r\n')
    port_socks5=$(jq -r '.inbounds[]? | select(.tag == "socks5-sb") | .listen_port // empty' "$sbj" 2>/dev/null)
    [ -z "$port_socks5" ] && [ -s "$SINGBOX_FOLDER_PATH/port_socks5" ] && port_socks5=$(cat "$SINGBOX_FOLDER_PATH/port_socks5" | tr -d '\r\n')

    # 获取所有协议端口和标签（排除 socks5）
    local _ports_tags=""
    _ports_tags=$(jq -r '.inbounds[]? | select(.tag != "socks5-sb") | "\(.tag)\t\(.listen_port // empty)"' "$sbj" 2>/dev/null | sort -t$'\t' -k2 -un)

    local _has_rule=false

    # 根据协议标签判断需要 TCP 还是 UDP
    # TCP: vmess/trojan/vless/anytls
    # UDP: hy2/tuic
    local OLD_IFS="$IFS"
    IFS=$'\n'
    for _pt in $_ports_tags; do
        [ -z "$_pt" ] && continue
        local _tag="${_pt%%	*}"
        local _port="${_pt#*	}"
        [ -z "$_port" ] && continue

        local _need_tcp=false _need_udp=false
        case "$_tag" in
            *hy2*)    _need_udp=true ;;
            *tuic*)   _need_udp=true ;;
            *)        _need_tcp=true ;;
        esac

        if command -v iptables > /dev/null 2>&1; then
            $_need_tcp && iptables -A INPUT -p tcp --dport "$_port" -j ACCEPT -m comment --comment "$IPTABLES_COMMENT_SINGBOX" 2>/dev/null && _has_rule=true
            $_need_udp && iptables -A INPUT -p udp --dport "$_port" -j ACCEPT -m comment --comment "$IPTABLES_COMMENT_SINGBOX" 2>/dev/null && _has_rule=true
        fi
        if command -v ip6tables > /dev/null 2>&1; then
            $_need_tcp && ip6tables -A INPUT -p tcp --dport "$_port" -j ACCEPT -m comment --comment "$IPTABLES_COMMENT_SINGBOX" 2>/dev/null && _has_rule=true
            $_need_udp && ip6tables -A INPUT -p udp --dport "$_port" -j ACCEPT -m comment --comment "$IPTABLES_COMMENT_SINGBOX" 2>/dev/null && _has_rule=true
        fi
    done
    IFS="$OLD_IFS"

    # 为 socks5 端口添加 ACCEPT 规则（仅当无白名单时，socks5 只用 TCP）
    if [ -n "$port_socks5" ] && ! is_true "$wl_flag"; then
        if command -v iptables > /dev/null 2>&1; then
            iptables -A INPUT -p tcp --dport "$port_socks5" -j ACCEPT -m comment --comment "$IPTABLES_COMMENT_SINGBOX" 2>/dev/null && _has_rule=true
        fi
        if command -v ip6tables > /dev/null 2>&1; then
            ip6tables -A INPUT -p tcp --dport "$port_socks5" -j ACCEPT -m comment --comment "$IPTABLES_COMMENT_SINGBOX" 2>/dev/null && _has_rule=true
        fi
    fi

    $_has_rule && _save_iptables_rules
}

# 工具函数：校验 IP/CIDR（IPv4 逐段校验 + 掩码范围；IPv6 宽松校验 + 掩码范围）用于 socks5 白名单
is_valid_cidr() {
    local c="${1:-}" ip="" mask=""
    [ -n "$c" ] || return 1
    # 拒绝嵌入 CR/LF（同上，防跨行绕过）
    [ "$c" = "$(printf '%s' "$c" | tr -d '\r\n')" ] || return 1
    # IPv4（支持 CIDR）
    if printf '%s' "$c" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?$'; then
        if printf '%s' "$c" | grep -q '/'; then
            ip="${c%%/*}"
            mask="${c##*/}"
            [ "$mask" -ge 0 ] && [ "$mask" -le 32 ] 2>/dev/null || return 1
        else
            ip="$c"
        fi
        local o1 o2 o3 o4
        IFS='.' read -r o1 o2 o3 o4 <<< "$ip"
        [ "${o1:-0}" -ge 0 ] && [ "${o1:-0}" -le 255 ] && [ "${o2:-0}" -ge 0 ] && [ "${o2:-0}" -le 255 ] \
            && [ "${o3:-0}" -ge 0 ] && [ "${o3:-0}" -le 255 ] && [ "${o4:-0}" -ge 0 ] && [ "${o4:-0}" -le 255 ]
        return $?
    fi
    # IPv6（宽松：含冒号即认为 IPv6；若带掩码校验 1-128）
    if printf '%s' "$c" | grep -q ':'; then
        if printf '%s' "$c" | grep -q '/'; then
            mask="${c##*/}"
            [ "$mask" -ge 0 ] && [ "$mask" -le 128 ] 2>/dev/null
            return $?
        fi
        return 0
    fi
    return 1
}

# 用 iptables 在网络层限制 socks5 端口的访问（仅白名单 IP 可连接）
# 原理：sing-box route rules 的 source_ip_cidr 匹配的是出站流量源IP（服务器自身），
#       无法过滤客户端连接，因此改用 iptables 在 TCP 层直接拦截非白名单 IP 的连接
apply_socks5_whitelist() {
    local sbj="$SINGBOX_FOLDER_PATH/sb.json"

    # 未启用白名单则跳过
    local wl_flag=""
    [ -s "$SINGBOX_FOLDER_PATH/socks5_wl_flag" ] && wl_flag=$(cat "$SINGBOX_FOLDER_PATH/socks5_wl_flag" | tr -d '\r\n')
    is_true "$wl_flag" || return 0

    # 无白名单 IP 列表则跳过
    [ ! -s "$SINGBOX_FOLDER_PATH/socks5_ips" ] && return 0
    local ips_raw
    ips_raw=$(cat "$SINGBOX_FOLDER_PATH/socks5_ips" | tr -d '\r\n')
    [ -z "$ips_raw" ] && return 0

    # 获取 socks5 端口
    local port_socks5=""
    if [ -s "$sbj" ]; then
        port_socks5=$(jq -r '.inbounds[]? | select(.tag == "socks5-sb") | .listen_port // empty' "$sbj" 2>/dev/null)
    fi
    [ -z "$port_socks5" ] && [ -s "$SINGBOX_FOLDER_PATH/port_socks5" ] && port_socks5=$(cat "$SINGBOX_FOLDER_PATH/port_socks5" | tr -d '\r\n')
    [ -z "$port_socks5" ] && return 0

    # 逐个 IP 添加 ACCEPT 规则（非法格式跳过并警告）
    local _has_rule=false _valid_ip=false
    local OLD_IFS="$IFS"
    IFS=','
    for ip in $ips_raw; do
        IFS="$OLD_IFS"
        ip=$(printf '%s' "$ip" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [ -z "$ip" ] && continue
        if ! is_valid_cidr "$ip"; then
            red "❗ 白名单 IP 格式非法，已跳过：${ip}"
            continue
        fi
        _valid_ip=true

        if printf '%s' "$ip" | grep -q ':'; then
            # IPv6 → ip6tables
            if command -v ip6tables > /dev/null 2>&1; then
                ip6tables -A INPUT -p tcp --dport "$port_socks5" -s "$ip" -j ACCEPT -m comment --comment "$IPTABLES_COMMENT_SOCKS5" 2>/dev/null && _has_rule=true
            fi
        else
            # IPv4 → iptables
            if command -v iptables > /dev/null 2>&1; then
                iptables -A INPUT -p tcp --dport "$port_socks5" -s "$ip" -j ACCEPT -m comment --comment "$IPTABLES_COMMENT_SOCKS5" 2>/dev/null && _has_rule=true
            fi
        fi
    done
    IFS="$OLD_IFS"

    # 有白名单 ACCEPT 规则才添加默认 DROP（拦截其余所有 IP）
    if $_has_rule; then
        if command -v iptables > /dev/null 2>&1; then
            iptables -A INPUT -p tcp --dport "$port_socks5" -j DROP -m comment --comment "$IPTABLES_COMMENT_SOCKS5" 2>/dev/null
        fi
        if command -v ip6tables > /dev/null 2>&1; then
            ip6tables -A INPUT -p tcp --dport "$port_socks5" -j DROP -m comment --comment "$IPTABLES_COMMENT_SOCKS5" 2>/dev/null
        fi
        _save_iptables_rules
        green "✅ Socks5 IP白名单已生效（仅允许：${ips_raw}）"
    elif [ "$_valid_ip" = false ]; then
        red "❗ 白名单配置无效（IP 全部非法），本次未生效，socks5 仍对所有 IP 开放"
        red "   请修改 $SINGBOX_FOLDER_PATH/socks5_ips 后重试"
    fi
}

# 校验域名（用于 Argo 固定隧道 / vless SNI 等，防注入）
is_valid_domain() {
    local d="${1:-}"
    [ -n "$d" ] || return 1
    # 拒绝嵌入 CR/LF（grep 按行匹配，需先整体校验无换行，防止跨行首行匹配绕过）
    [ "$d" = "$(printf '%s' "$d" | tr -d '\r\n')" ] || return 1
    printf '%s' "$d" | grep -qE '^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'
}

# 校验 Argo token（cloudflared token 是 base64url + 点分隔，不含空格/引号/换行）
is_valid_argo_token() {
    local t="${1:-}"
    [ -n "$t" ] || return 1
    # 拒绝嵌入 CR/LF（同 is_valid_domain，防跨行绕过）
    [ "$t" = "$(printf '%s' "$t" | tr -d '\r\n')" ] || return 1
    printf '%s' "$t" | grep -qE '^[A-Za-z0-9_-]+(\.[A-Za-z0-9_-]+)*$'
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

    # ---------- 域名校验（固定隧道必填且必须合法，防止拼进 tunnel.yml/service 造成注入） ----------
    if [ -n "$domain" ] && ! is_valid_domain "$domain"; then
        red "❌ Argo 固定隧道域名非法：${domain}"
        red "   域名只能包含字母/数字/'-'/'.'，如 cdn.example.com"
        return 1
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
        chmod 600 "$SINGBOX_FOLDER_PATH/tunnel.json" 2>/dev/null || true
        debug_log "【调试】prepare_argo_credentials：tunnel.json 已写入（大小=$(wc -c "$SINGBOX_FOLDER_PATH/tunnel.json" 2> /dev/null | awk '{print $1}') 字节）"

        # 提取 TunnelID
        local tunnel_id
        tunnel_id=$(printf '%s' "$auth" | sed -n 's/.*"TunnelID"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

        if [ -z "$tunnel_id" ]; then
            red "❌ Argo JSON 中未找到 TunnelID"
            debug_log "【调试】prepare_argo_credentials：失败：JSON 中未解析到 TunnelID"
            return 1
        fi
        debug_log "【调试】prepare_argo_credentials：已解析 TunnelID（前8位=${tunnel_id:0:8}...）"

        # 生成 tunnel.yml（对齐 s4.sh）
        cat > "$SINGBOX_FOLDER_PATH/tunnel.yml" << EOF
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
        chmod 600 "$SINGBOX_FOLDER_PATH/tunnel.yml" 2>/dev/null || true
        debug_log "【调试】prepare_argo_credentials：tunnel.yml 已生成（回源到 localhost:${local_port}，hostname=${domain:-<空>}）"

        ARGO_MODE="json"
        debug_log "【调试】prepare_argo_credentials：ARGO_MODE 已设为 json"

    else
        # token 模式
        if ! is_valid_argo_token "$auth"; then
            red "❌ Argo token 格式非法：只能包含字母/数字/'-'/'_'/'.'，且不允许空格、引号、换行"
            red "   请确认你粘贴的是完整的 cloudflared token（形如 ey...-xxx.xxx）"
            return 1
        fi
        ARGO_MODE="token"
        debug_log "【调试】prepare_argo_credentials：识别为 token 凭据（ARGO_MODE=token）"
    fi

    export ARGO_MODE
    debug_log "【调试】prepare_argo_credentials：结束（ARGO_MODE=${ARGO_MODE}）"
}

# 交互模式（无参数/menu）由 showmode 提供头部，不再打印启动横幅
case "${1:-}" in
    ""|menu|MENU) : ;;
    *)
        echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        echo "Sing-box 一键无交互脚本🎯 (Sing-box内核版)"
        echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        ;;
esac

# ================== IP→地区 本地缓存（含后台预取） ==================
# 探测入口：安装/覆盖安装/查看节点等需要展示 IP 地区的路径才会触发 geo_prefetch（幂等）。
# 按 IP 类型分文件缓存，每行 "IP=地区"：
#   .geo4  -> 仅 IPv4；.geo6 -> 仅 IPv6；.geo_out -> 仅 out_ip。
# 读取点 geo_get_ip 先按 IP 查对应本地文件：命中直接返回（不发网络）；未命中先等后台预取写入，仍无则现场查并写回。
GEO_V4_FILE="$SINGBOX_FOLDER_PATH/.geo4"
GEO_V6_FILE="$SINGBOX_FOLDER_PATH/.geo6"
GEO_OUT_FILE="$SINGBOX_FOLDER_PATH/.geo_out"
GEO_STARTED="$SINGBOX_FOLDER_PATH/.geo_started"

# 按 IP 类型返回对应缓存文件
geo_file_of() {
    if echo "$1" | grep -q ':'; then echo "$GEO_V6_FILE"; else echo "$GEO_V4_FILE"; fi
}
# 写入 .geo4/.geo6（按 IP 类型），同一 IP 只保留一行（临时文件 + mv 原子替换）
geo_set() {
    local _ip="$1" _region="$2" _f _tmp
    [ -z "$_ip" ] || [ -z "$_region" ] && return 1
    _f="$(geo_file_of "$_ip")"
    _tmp="$(mktemp "${_f}.XXXXXX" 2>/dev/null || echo "${_f}.tmp")"
    grep -v "^${_ip}=" "$_f" 2>/dev/null > "$_tmp" || true
    echo "$_ip=$_region" >> "$_tmp"
    mv -f "$_tmp" "$_f"
}
# 写入 .geo_out（out_ip），同一 IP 只保留一行
geo_set_out() {
    local _ip="$1" _region="$2" _tmp
    [ -z "$_ip" ] || [ -z "$_region" ] && return 1
    _tmp="$(mktemp "${GEO_OUT_FILE}.XXXXXX" 2>/dev/null || echo "${GEO_OUT_FILE}.tmp")"
    grep -v "^${_ip}=" "$GEO_OUT_FILE" 2>/dev/null > "$_tmp" || true
    echo "$_ip=$_region" >> "$_tmp"
    mv -f "$_tmp" "$GEO_OUT_FILE"
}

geo_prefetch() {
    [ -e "$GEO_STARTED" ] && return 0
    touch "$GEO_STARTED"
    {
        local _ip _r
        _ip="$(curl -s4 -m3 --connect-timeout 3 -k "$v46url" 2>/dev/null | tr -d '\r\n')"
        [ -z "$_ip" ] && _ip="$(wget -4 -qO- --tries=1 --timeout=3 "$v46url" 2>/dev/null | tr -d '\r\n')"
        _r="$(awk -F= -v ip="$_ip" '$1==ip{print $2}' "$GEO_V4_FILE" 2>/dev/null | tail -n1)"
        [ -z "$_r" ] && {
            _r="$(curl -s4 -m8 --connect-timeout 3 -k https://ip.fm 2>/dev/null \
                | sed -nE 's/.*Location: ([^,]+(, [^,]+)*),.*/\1/p' | head -n1)"
            [ -z "$_r" ] && _r="$(wget -4 -qO- --tries=1 --timeout=8 https://ip.fm 2>/dev/null \
                | sed -nE 's/.*Location: ([^,]+(, [^,]+)*),.*/\1/p' | head -n1)"
            geo_set "$_ip" "$_r"
        }
    } &
    {
        local _ip _r
        _ip="$(curl -s6 -m3 --connect-timeout 3 -k "$v46url" 2>/dev/null | tr -d '\r\n')"
        [ -z "$_ip" ] && _ip="$(wget -6 -qO- --tries=1 --timeout=3 "$v46url" 2>/dev/null | tr -d '\r\n')"
        _r="$(awk -F= -v ip="$_ip" '$1==ip{print $2}' "$GEO_V6_FILE" 2>/dev/null | tail -n1)"
        [ -z "$_r" ] && {
            _r="$(curl -s6 -m8 --connect-timeout 3 -k https://ip.fm 2>/dev/null \
                | sed -nE 's/.*Location: ([^,]+(, [^,]+)*),.*/\1/p' | head -n1)"
            [ -z "$_r" ] && _r="$(wget -6 -qO- --tries=1 --timeout=8 https://ip.fm 2>/dev/null \
                | sed -nE 's/.*Location: ([^,]+(, [^,]+)*),.*/\1/p' | head -n1)"
            geo_set "$_ip" "$_r"
        }
    } &
}
# 读取 IP 的地区：$1=IP。先查对应类型缓存命中即返回；未命中先等预取写入，仍无则现场查并写回缓存。
geo_get_ip() {
    local _ip="$1" _region="" _t=0 _proto _f
    [ -z "$_ip" ] && return 1
    _f="$(geo_file_of "$_ip")"
    _region="$(awk -F= -v ip="$_ip" '$1==ip{print $2}' "$_f" 2>/dev/null | tail -n1)"
    if [ -z "$_region" ] && [ -e "$GEO_STARTED" ]; then
        while [ "$_t" -lt 20 ]; do
            _region="$(awk -F= -v ip="$_ip" '$1==ip{print $2}' "$_f" 2>/dev/null | tail -n1)"
            [ -n "$_region" ] && break
            sleep 0.1; _t=$((_t+1))
        done
    fi
    if [ -z "$_region" ]; then
        if echo "$_ip" | grep -q ':'; then _proto="6"; else _proto="4"; fi
        _region="$(curl -s${_proto} -m8 --connect-timeout 3 -k https://ip.fm 2>/dev/null \
            | sed -nE 's/.*Location: ([^,]+(, [^,]+)*),.*/\1/p' | head -n1)"
        [ -z "$_region" ] && _region="$(wget -${_proto} -qO- --tries=1 --timeout=8 https://ip.fm 2>/dev/null \
            | sed -nE 's/.*Location: ([^,]+(, [^,]+)*),.*/\1/p' | head -n1)"
        [ -n "$_region" ] && geo_set "$_ip" "$_region"
    fi
    echo "$_region"
}

hostname=$(uname -a | awk '{print $2}')
op=$(cat /etc/redhat-release 2> /dev/null || cat /etc/os-release 2> /dev/null | grep -i pretty_name | cut -d \" -f2)
case $(uname -m) in aarch64) cpu=arm64 ;; x86_64) cpu=amd64 ;; *) echo "目前脚本不支持$(uname -m)架构" && exit 1 ;; esac
mkdir -p "$SINGBOX_FOLDER_PATH"
# Check and set IP version
v4v6() {
    # Check IPv4 connectivity
    debug_log "【调试】 Checking IPv4 and IPv6 connectivity, ready to get IP..."
    debug_log "【调试】 Checking IPv4 connectivity..."
    v4=$(curl -s4 -m2 --connect-timeout 2 -k "$v46url" 2> /dev/null || wget -4 -qO- --tries=2 --timeout=2 "$v46url" 2> /dev/null)
    if [ -n "$v4" ]; then
        v4_ok=true
    else
        v4_ok=false
    fi

    debug_log "【调试】 IPv4 connectivity check completed. ipv4=$v4"

    # Check IPv6 connectivity
    debug_log "【调试】 Checking IPv6 connectivity..."
    v6=$(curl -s6 -m2 --connect-timeout 2 -k "$v46url" 2> /dev/null || wget -6 -qO- --tries=2 --timeout=2 "$v46url" 2> /dev/null)
    if [ -n "$v6" ]; then
        v6_ok=true
    else
        v6_ok=false
    fi
    debug_log "【调试】 IPv6 connectivity check completed. ipv6=$v6"
    debug_log "【调试】 IP connectivity check completed. ipv4=$v4, ipv6=$v6"

}

# Set up name for nodes and IP version preference
set_sbyx() {
    if [ -n "$name" ]; then
        # 清洗 name：去掉 CR/LF，防止换行/控制符污染节点名与订阅
        name="$(printf '%s' "$name" | tr -d '\r\n')"
        sxname=$name-
        echo "$sxname" > "$SINGBOX_FOLDER_PATH/name"
        echo
        yellow "所有节点名称前缀：$name"
    fi
    debug_print echo "IP版本获取中……请稍候"
    v4v6 # This now sets both v4_ok and v6_ok

    # Determine which connection to prefer based on the availability of IPv4 and IPv6
    if [ "$ippz" = "4" ]; then
        if [ "$v4_ok" = true ]; then
            sbyx='ipv4_only'
        else
            sbyx='prefer_ipv4'
        fi
    elif [ "$ippz" = "6" ]; then
        if [ "$v6_ok" = true ]; then
            sbyx='ipv6_only'
        else
            sbyx='prefer_ipv6'
        fi
    elif [ "$v4_ok" = true ] && [ "$v6_ok" = true ]; then
        sbyx='prefer_ipv6'
    elif [ "$v4_ok" = true ] && [ "$v6_ok" != true ]; then
        sbyx='ipv4_only'
    elif [ "$v4_ok" != true ] && [ "$v6_ok" = true ]; then
        sbyx='ipv6_only'
    else
        sbyx='prefer_ipv6' # Default to prefer IPv6 if neither is available
    fi
}

# download Sing-box
# 检测已安装版本，需要更新时下载并安装 sing-box 二进制
update_singbox() {
    local sb_ver="1.13.14"

    # 版本检测：已安装且版本匹配则跳过下载
    if [ -x "$SINGBOX_FOLDER_PATH/sing-box" ]; then
        local current_ver
        current_ver=$("$SINGBOX_FOLDER_PATH/sing-box" version 2> /dev/null | head -1 | sed -n 's/.*\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p')
        if [ "$current_ver" = "$sb_ver" ]; then
            green "✅ Sing-box 已安装最新版 (v${sb_ver})，跳过下载"
            return 0
        fi
        yellow "Sing-box 版本不匹配 (当前: ${current_ver:-unknown}，期望: ${sb_ver})，开始下载新版..."
    fi

    # # 自定义库（旧源），如需切回取消注释下面这行，注释掉官方下载部分
    # local url="https://github.com/jyucoeng/singbox-tools/releases/download/singbox/sing-box-$cpu"

    # Alpine (musl) 需使用 musl 编译的二进制
    local sb_lib_suffix=""
    if [ -f /etc/alpine-release ]; then
        sb_lib_suffix="-musl"
    fi

    local archive="sing-box-${sb_ver}-linux-${cpu}${sb_lib_suffix}.tar.gz"
    # 本仓库自持源（由 sync-singbox.yml 从上游镜像），如需切回官方源，取消下行注释并注释上行
    local url="https://github.com/jyucoeng/singbox-tools/releases/download/v${sb_ver}/${archive}"
    # local url="https://github.com/SagerNet/sing-box/releases/download/v${sb_ver}/${archive}"
    local tmp_archive="/tmp/${archive}"

    (curl -Lo "$tmp_archive" -# --connect-timeout 5 --max-time 120 --retry 2 --retry-delay 2 --retry-all-errors "$url") \
        || (wget -O "$tmp_archive" --tries=2 --timeout=120 --dns-timeout=5 --read-timeout=60 "$url")

    if [ ! -s "$tmp_archive" ]; then
        debug_log "【调试】update_singbox：下载失败：文件为空"
        red "❌ 下载失败：${url}"
        exit 1
    fi

    # 完整性校验（运行时）：下载内容不是 HTML 错误页，且是合法 tar.gz 并包含 sing-box 二进制
    if head -c 256 "$tmp_archive" | grep -qiE '<!DOCTYPE|<html|404: Not Found' 2> /dev/null; then
        red "❌ 下载内容异常（疑似 HTML 错误页）：${url}"
        rm -f "$tmp_archive" 2> /dev/null
        exit 1
    fi
    if ! tar -tzf "$tmp_archive" 2> /dev/null | grep -q '/sing-box$'; then
        red "❌ 下载的压缩包内未找到 sing-box 二进制（可能损坏或被劫持）：${url}"
        rm -f "$tmp_archive" 2> /dev/null
        exit 1
    fi

    debug_log "【调试】update_singbox：下载完成，解压中…"

    tar -xzf "$tmp_archive" -C /tmp/ 2> /dev/null || {
        red "❌ 解压失败"
        exit 1
    }
    mv "/tmp/sing-box-${sb_ver}-linux-${cpu}${sb_lib_suffix}/sing-box" "$SINGBOX_FOLDER_PATH/sing-box"
    rm -f "$tmp_archive"
    rm -rf "/tmp/sing-box-${sb_ver}-linux-${cpu}" 2> /dev/null || true

    chmod +x "$SINGBOX_FOLDER_PATH/sing-box"
    # 完整性校验：二进制能运行且版本号必须等于期望版本，防止被替换/损坏
    sbcore=$("$SINGBOX_FOLDER_PATH/sing-box" version 2> /dev/null | head -1 | awk '/version/{print $NF}')
    if [ -z "$sbcore" ] || [ "$sbcore" != "$sb_ver" ]; then
        red "❌ sing-box 校验失败：期望 v${sb_ver}，实际 ${sbcore:-无法运行}（二进制可能损坏或被劫持）"
        rm -f "$SINGBOX_FOLDER_PATH/sing-box" 2> /dev/null
        exit 1
    fi
    debug_log "【调试】update_singbox：Sing-box 版本为 $sbcore"
    green "✅  已安装 Sing-box 正式版内核：${sbcore}"
}
# Generate UUID and save to file
insuuid() {
    if [ ! -e "$SINGBOX_FOLDER_PATH/sing-box" ]; then
        update_singbox
    fi

    if [ -z "$uuid" ] && [ ! -e "$SINGBOX_FOLDER_PATH/uuid" ]; then
        uuid=$("$SINGBOX_FOLDER_PATH/sing-box" generate uuid)
        echo "$uuid" > "$SINGBOX_FOLDER_PATH/uuid"
        chmod 600 "$SINGBOX_FOLDER_PATH/uuid" 2>/dev/null || true
    elif [ -n "$uuid" ]; then
        echo "$uuid" > "$SINGBOX_FOLDER_PATH/uuid"
        chmod 600 "$SINGBOX_FOLDER_PATH/uuid" 2>/dev/null || true
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

    # 兼容：如果脚本里没有 yellow/green，就用 printf
    command -v yellow > /dev/null 2>&1 || yellow() { printf "%s\n" "$*"; }
    command -v green > /dev/null 2>&1 || green() { printf "%s\n" "$*"; }

    _is_hex() { echo "$1" | grep -qiE '^[0-9a-f]{8}$'; }

    # 由 reality_private 推导一个稳定的 short_id
    # 仅使用 reality_private 推导（更可控、更干净）
    local rp="${reality_private:-}"
    if [ -n "${rp:-}" ]; then
        # 推导方式：sha256(reality_private) 取前 8 位 hex
        if command -v sha256sum > /dev/null 2>&1; then
            sid="$(printf "%s" "$rp" | sha256sum | awk '{print $1}' | cut -c1-8)"
        elif command -v openssl > /dev/null 2>&1; then
            sid="$(printf "%s" "$rp" | openssl dgst -sha256 2> /dev/null | awk '{print $NF}' | cut -c1-8)"
        elif command -v md5sum > /dev/null 2>&1; then
            sid="$(printf "%s" "$rp" | md5sum | awk '{print $1}' | cut -c1-8)"
        else
            # 兜底：仍然随机生成，但会落盘保持后续稳定
            sid="$(head -c 4 /dev/urandom 2> /dev/null | od -An -tx1 | tr -d ' \n' | cut -c1-8)"
        fi

        sid="${sid,,}"
        if _is_hex "$sid"; then
            # 如果文件存在但不一致，覆盖以保证“只传 reality_private 也稳定一致”
            if [ -f "$sid_file" ]; then
                local old_sid
                old_sid="$(cat "$sid_file" 2> /dev/null | tr -d ' \r\n')"
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
        sid="$(cat "$sid_file" 2> /dev/null | tr -d ' \r\n')"
        sid="${sid,,}"
        if _is_hex "$sid"; then
            yellow "从文件中读取 short_id, 值: $sid" >&2
            echo "$sid"
            return 0
        else
            yellow "❗ short_id 文件内容无效（必须是8位hex），将重新生成"
            rm -f "$sid_file" 2> /dev/null
        fi
    fi

    # 4) 随机生成（8位 hex，等价 openssl rand -hex 4）
    if command -v openssl > /dev/null 2>&1; then
        sid="$(openssl rand -hex 4 2> /dev/null)"
    else
        sid=""
    fi
    if [ -z "$sid" ]; then
        sid="$(head -c 4 /dev/urandom 2> /dev/null | od -An -tx1 | tr -d ' \n' | cut -c1-8)"
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
    if command -v xxd > /dev/null 2>&1 && command -v openssl > /dev/null 2>&1; then
        debug_log "🔐 【调试】 derive_reality_public_key: 使用【本地推导】(openssl + xxd)"

        local tmp_dir="$SINGBOX_FOLDER_PATH/.tmp_reality"
        mkdir -p "$tmp_dir" 2> /dev/null

        # base64url -> base64 (字符集替换)
        local b64
        b64="$(printf '%s' "$priv" | tr '_-' '/+')"

        # base64 padding 补齐
        local mod=$((${#b64} % 4))
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
            if echo "$b64" | base64 -d > "$tmp_dir/_x25519_priv_raw" 2> /dev/null; then
                :
            elif echo "$b64" | base64 -D > "$tmp_dir/_x25519_priv_raw" 2> /dev/null; then
                :
            elif echo "$b64" | openssl base64 -d -A > "$tmp_dir/_x25519_priv_raw" 2> /dev/null; then
                :
            else
                debug_log "❗ 【调试】 derive_reality_public_key: 本地解码失败（base64 -d/-D/openssl base64 均失败）"
                rm -f "$tmp_dir/_x25519_priv_raw" 2> /dev/null
            fi

            # 校验长度必须为 32 bytes
            if [ -s "$tmp_dir/_x25519_priv_raw" ]; then
                local priv_len
                priv_len="$(stat -c%s "$tmp_dir/_x25519_priv_raw" 2> /dev/null || stat -f%z "$tmp_dir/_x25519_priv_raw" 2> /dev/null || echo 0)"

                if [ "$priv_len" != "32" ]; then
                    debug_log "❗ 【调试】 derive_reality_public_key: 本地解码后长度不为 32 bytes（实际=${priv_len}）"
                    rm -f "$tmp_dir/_x25519_priv_raw" 2> /dev/null
                else
                    # PKCS#8 DER 前缀（X25519 固定头）
                    local prefix_hex="302e020100300506032b656e04220420"
                    local priv_hex
                    priv_hex="$(xxd -p -c 256 "$tmp_dir/_x25519_priv_raw" 2> /dev/null | tr -d '\n')"

                    if [ -n "$priv_hex" ]; then
                        printf "%s%s" "$prefix_hex" "$priv_hex" | xxd -r -p > "$tmp_dir/_x25519_priv_der" 2> /dev/null || true

                        if openssl pkcs8 -inform DER -in "$tmp_dir/_x25519_priv_der" -nocrypt -out "$tmp_dir/_x25519_priv_pem" 2> /dev/null \
                            && openssl pkey -in "$tmp_dir/_x25519_priv_pem" -pubout -outform DER > "$tmp_dir/_x25519_pub_der" 2> /dev/null \
                            && tail -c 32 "$tmp_dir/_x25519_pub_der" > "$tmp_dir/_x25519_pub_raw" 2> /dev/null; then

                            # raw 公钥 -> base64url（无 padding）
                            if command -v base64 > /dev/null 2>&1; then
                                pub="$(base64 < "$tmp_dir/_x25519_pub_raw" 2> /dev/null | tr -d '\n' | tr '+/' '-_' | sed -E 's/=+$//')"
                            elif command -v openssl > /dev/null 2>&1; then
                                pub="$(openssl base64 -A < "$tmp_dir/_x25519_pub_raw" 2> /dev/null | tr '+/' '-_' | sed -E 's/=+$//')"
                            fi

                            if [ -n "$pub" ]; then
                                debug_log "✅ 【调试】 derive_reality_public_key: 本地推导成功"

                                # 清理临时文件（可选）
                                rm -f "$tmp_dir/_x25519_priv_raw" "$tmp_dir/_x25519_priv_der" "$tmp_dir/_x25519_priv_pem" \
                                    "$tmp_dir/_x25519_pub_der" "$tmp_dir/_x25519_pub_raw" 2> /dev/null

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

        debug_log "❗ 【调试】 derive_reality_public_key: 本地推导失败"
    else
        debug_log "❗ 【调试】 derive_reality_public_key: 缺少 openssl 或 xxd，本地推导不可用"
    fi

    # ❗ 安全考虑：不再提供“在线推导”兜底。
    # 旧版会把 reality 私钥以 query 参数（?privateKey=...）明文发给第三方
    # （realitykey.cloudflare.now.cc），等于把私钥外发。这里直接返回失败，
    # 由调用方 init_reality_keypair 回退为生成一套新的 keypair。
    debug_log "❌ 【调试】 derive_reality_public_key: 本地推导失败，已拒绝在线推导（私钥不外发），返回失败"
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
# 标准 base64 → URL-safe base64（兼容旧版 reality.key，sing-box 1.13+ 使用 URL-safe 编码）
_to_urlsafe_base64() {
    local k="$1"
    k="${k//+/-}"      # + → -
    k="${k//\//_}"     # / → _
    k="${k//=/}"       # 去掉 = 填充
    echo "$k"
}

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
        file_priv="$(awk -F': ' '/PrivateKey/{print $2; exit}' "$key_file" 2> /dev/null)"
        file_pub="$(awk -F': ' '/PublicKey/{print $2; exit}' "$key_file" 2> /dev/null)"
        # 兼容旧版：标准 base64 → URL-safe base64（sing-box 1.13+ 使用 URL-safe 编码）
        file_priv="$(_to_urlsafe_base64 "$file_priv")"
        file_pub="$(_to_urlsafe_base64 "$file_pub")"
        debug_log "📄 【调试】 init_reality_keypair: 检测到已有 reality.key（priv=${#file_priv} chars, pub=${#file_pub} chars）"
    else
        debug_log "📄 【调试】 init_reality_keypair: 未找到 reality.key（首次安装或文件丢失）"
    fi

    # A) 用户传入了 reality_private（最高优先级）
    if [ -n "$env_priv" ]; then
        debug_log "🧩 【调试】 init_reality_keypair: 使用环境变量 reality_private（优先级最高）"

        # 兼容旧版：标准 base64 → URL-safe base64
        env_priv="$(_to_urlsafe_base64 "$env_priv")"
        priv="$env_priv"

        # 如果文件里私钥与传入相同，则优先复用文件里的公钥（避免变化）
        if [ -n "$file_priv" ] && [ "$file_priv" = "$priv" ] && [ -n "$file_pub" ]; then
            pub="$file_pub"
            debug_log "✅ 【调试】 init_reality_keypair: 文件私钥与传入一致，复用文件公钥"
        else
            debug_log "🔄 【调试】 init_reality_keypair: 尝试由私钥推导公钥（derive_reality_public_key）"
            pub="$(derive_reality_public_key "$priv" 2> /dev/null)" || pub=""

            if [ -n "$pub" ]; then
                debug_log "✅ 【调试】 init_reality_keypair: 推导公钥成功（pub=${#pub} chars）"
            else
                debug_log "❗ 【调试】 init_reality_keypair: 推导公钥失败，将回退为生成新 keypair（这会覆盖 reality_private）"

                # 推导失败：生成一套新的 keypair（回退）
                local kp
                kp="$("$SINGBOX_FOLDER_PATH/sing-box" generate reality-keypair 2> /dev/null)"
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
        kp="$("$SINGBOX_FOLDER_PATH/sing-box" generate reality-keypair 2> /dev/null)"
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
    mkdir -p "$(dirname "$key_file")" 2> /dev/null
    printf "PrivateKey: %s\nPublicKey: %s\n" "$priv" "$pub" > "$key_file" 2> /dev/null
    chmod 600 "$key_file" 2> /dev/null

    # 导出环境变量（给后续生成配置用）
    export reality_private="$priv"
    export reality_public="$pub"

    debug_log "💾 【调试】 init_reality_keypair: 已写入 ${key_file}（chmod 600）"
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

    mkdir -p "$(dirname "$key_path")" 2> /dev/null
    # P-256 证书即可
    openssl ecparam -genkey -name prime256v1 -out "$key_path" > /dev/null 2>&1 || return 1

    # 优先带 SAN（部分客户端只认 SAN 不认 CN）
    if openssl req -new -x509 -days "$days" -key "$key_path" -out "$cert_path" -subj "/CN=${cn}" -addext "subjectAltName=DNS:${cn}" > /dev/null 2>&1; then
        :
    else
        # 兼容旧 openssl：无 -addext 时回退
        openssl req -new -x509 -days "$days" -key "$key_path" -out "$cert_path" -subj "/CN=${cn}" > /dev/null 2>&1 || return 1
    fi

    return 0
}

# Install and configure Sing-box
installsb() {
    echo
    echo "=========开始下载/安装Sing-box内核========="

    # 版本检测：已安装且版本匹配则提示跳过
    if [ -x "$SINGBOX_FOLDER_PATH/sing-box" ]; then
        local current_ver sb_ver
        sb_ver="1.13.14"
        current_ver=$("$SINGBOX_FOLDER_PATH/sing-box" version 2> /dev/null | head -1 | sed -n 's/.*\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p')
        if [ "$current_ver" = "$sb_ver" ]; then
            green "✅ Sing-box 已安装 (v${current_ver})，跳过下载"
        else
            update_singbox
        fi
    else
        update_singbox
    fi

    insuuid
    write2SingboxFolders

    # Generate a self-signed cert for protocols that need TLS (hy2, tuic, anytls)
    if [ -n "$hyp" ] || [ -n "$tup" ] || [ -n "$anyp" ]; then
        gen_self_signed_cert "$SINGBOX_FOLDER_PATH/private.key" "$SINGBOX_FOLDER_PATH/cert.pem" "${CN_BING}" 36500
    fi

    local sbj="$SINGBOX_FOLDER_PATH/sb.json"
    local tmpj="$SINGBOX_FOLDER_PATH/.sb.tmp"

    # Initialize JSON with log config (matching index.js generateSingBoxConfig style)
    jq -n --arg logfile "$LOGS_DIR/singbox.log" '{log: {disabled: false, level: "info", timestamp: true, output: $logfile}, inbounds: []}' > "$sbj"

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
        port_tu=$(cat "$SINGBOX_FOLDER_PATH/port_tu")
        yellow "Tuic端口：$port_tu"

        jq --arg port "$port_tu" --arg uuid "$uuid" \
            --arg cert "$SINGBOX_FOLDER_PATH/cert.pem" --arg key "$SINGBOX_FOLDER_PATH/private.key" '
            .inbounds += [{
                type: "tuic", tag: "tuic-sb", listen: "::",
                listen_port: ($port | tonumber),
                users: [{uuid: $uuid, password: $uuid}],
                congestion_control: "bbr",
                tls: {enabled: true, alpn: ["h3"], certificate_path: $cert, key_path: $key}
            }]' "$sbj" > "$tmpj" && mv "$tmpj" "$sbj"
    fi

    # 添加hy2协议
    if [ -n "$hyp" ]; then
        if [ -z "$port_hy2" ] && [ ! -e "$SINGBOX_FOLDER_PATH/port_hy2" ]; then
            port_hy2=$(rand_port)
            echo "$port_hy2" > "$SINGBOX_FOLDER_PATH/port_hy2"
        elif [ -n "$port_hy2" ]; then
            echo "$port_hy2" > "$SINGBOX_FOLDER_PATH/port_hy2"
        fi
        port_hy2=$(cat "$SINGBOX_FOLDER_PATH/port_hy2")
        yellow "Hysteria2端口：$port_hy2"

        jq --arg port "$port_hy2" --arg uuid "$uuid" \
            --arg cert "$SINGBOX_FOLDER_PATH/cert.pem" --arg key "$SINGBOX_FOLDER_PATH/private.key" '
            .inbounds += [{
                type: "hysteria2", tag: "hy2-sb", listen: "::",
                listen_port: ($port | tonumber),
                users: [{password: $uuid}],
                tls: {enabled: true, alpn: ["h3"], certificate_path: $cert, key_path: $key}
            }]' "$sbj" > "$tmpj" && mv "$tmpj" "$sbj"
    fi

    # 添加trojan协议
    if [ -n "$trp" ]; then
        if [ -z "$port_tr" ] && [ ! -e "$SINGBOX_FOLDER_PATH/port_tr" ]; then
            port_tr=$(rand_port)
            echo "$port_tr" > "$SINGBOX_FOLDER_PATH/port_tr"
        elif [ -n "$port_tr" ]; then
            echo "$port_tr" > "$SINGBOX_FOLDER_PATH/port_tr"
        fi
        port_tr=$(cat "$SINGBOX_FOLDER_PATH/port_tr")
        yellow "Trojan端口(Argo本地使用)：$port_tr"

        jq --arg port "$port_tr" --arg uuid "$uuid" '
            .inbounds += [{
                type: "trojan", tag: "trojan-ws-sb", listen: "::",
                listen_port: ($port | tonumber),
                users: [{password: $uuid}],
                transport: {type: "ws", path: "/\($uuid)-tr"}
            }]' "$sbj" > "$tmpj" && mv "$tmpj" "$sbj"
    fi

    # 添加vmess协议
    if [ -n "$vmp" ]; then
        if [ -z "$port_vm_ws" ] && [ ! -e "$SINGBOX_FOLDER_PATH/port_vm_ws" ]; then
            port_vm_ws=$(rand_port)
            echo "$port_vm_ws" > "$SINGBOX_FOLDER_PATH/port_vm_ws"
        elif [ -n "$port_vm_ws" ]; then
            echo "$port_vm_ws" > "$SINGBOX_FOLDER_PATH/port_vm_ws"
        fi
        port_vm_ws=$(cat "$SINGBOX_FOLDER_PATH/port_vm_ws")
        yellow "Vmess-ws端口 (Argo本地使用)：$port_vm_ws"

        jq --arg port "$port_vm_ws" --arg uuid "$uuid" '
            .inbounds += [{
                type: "vmess", tag: "vmess-sb", listen: "::",
                listen_port: ($port | tonumber),
                users: [{uuid: $uuid, alterId: 0}],
                transport: {type: "ws", path: "/\($uuid)-vm"}
            }]' "$sbj" > "$tmpj" && mv "$tmpj" "$sbj"
    fi

    # 添加vless-ws协议（Argo 本地使用）
    if [ -n "$vlp" ]; then
        if [ -z "$port_vl_ws" ] && [ ! -e "$SINGBOX_FOLDER_PATH/port_vl_ws" ] && [ ! -e "$SINGBOX_FOLDER_PATH/port_vm_ws" ]; then
            port_vl_ws=$(rand_port)
            echo "$port_vl_ws" > "$SINGBOX_FOLDER_PATH/port_vl_ws"
        elif [ -n "$port_vl_ws" ]; then
            echo "$port_vl_ws" > "$SINGBOX_FOLDER_PATH/port_vl_ws"
        elif [ -s "$SINGBOX_FOLDER_PATH/port_vm_ws" ]; then
            # 兼容旧版本 vmess 端口文件，升级后复用同一端口
            port_vl_ws=$(cat "$SINGBOX_FOLDER_PATH/port_vm_ws")
            echo "$port_vl_ws" > "$SINGBOX_FOLDER_PATH/port_vl_ws"
        fi
        port_vl_ws=$(cat "$SINGBOX_FOLDER_PATH/port_vl_ws")
        yellow "Vless-ws端口 (Argo本地使用)：$port_vl_ws"

        jq --arg port "$port_vl_ws" --arg uuid "$uuid" '
            .inbounds += [{
                type: "vless", tag: "vless-ws-sb", listen: "::",
                listen_port: ($port | tonumber),
                users: [{uuid: $uuid}],
                transport: {type: "ws", path: "/\($uuid)-vl"}
            }]' "$sbj" > "$tmpj" && mv "$tmpj" "$sbj"
    fi

    # 添加vless-reality-vision协议
    if [ -n "$vlr" ]; then
        if [ -z "$port_vlr" ] && [ ! -e "$SINGBOX_FOLDER_PATH/port_vlr" ]; then
            port_vlr=$(rand_port)
            echo "$port_vlr" > "$SINGBOX_FOLDER_PATH/port_vlr"
        elif [ -n "$port_vlr" ]; then
            echo "$port_vlr" > "$SINGBOX_FOLDER_PATH/port_vlr"
        fi
        port_vlr=$(cat "$SINGBOX_FOLDER_PATH/port_vlr")
        yellow "VLESS-Reality-Vision端口：$port_vlr"

        if [ ! -f "$SINGBOX_FOLDER_PATH/reality.key" ]; then
            "$SINGBOX_FOLDER_PATH/sing-box" generate reality-keypair > "$SINGBOX_FOLDER_PATH/reality.key"
            chmod 600 "$SINGBOX_FOLDER_PATH/reality.key" 2>/dev/null || true
        fi

        # ✅ Reality Keypair：只传私钥即可（自动算公钥/或复用文件），节点输出保持一致
        init_reality_keypair
        private_key="${reality_private}"
        short_id="$(get_short_id "$SINGBOX_FOLDER_PATH/short_id")"

        jq --arg port "$port_vlr" --arg uuid "$uuid" \
            --arg sni "$vl_sni" --arg sni_pt "$vl_sni_pt" \
            --arg priv_key "$private_key" --arg sid "$short_id" '
            .inbounds += [{
                type: "vless", tag: "vless-reality-vision-sb", listen: "::",
                listen_port: ($port | tonumber),
                users: [{uuid: $uuid, flow: "xtls-rprx-vision"}],
                tls: {
                    enabled: true,
                    server_name: $sni,
                    reality: {
                        enabled: true,
                        handshake: {server: $sni, server_port: ($sni_pt | tonumber)},
                        private_key: $priv_key,
                        short_id: [$sid]
                    }
                }
            }]' "$sbj" > "$tmpj" && mv "$tmpj" "$sbj"
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

        port_any=$(cat "$SINGBOX_FOLDER_PATH/port_any")
        yellow "AnyTLS端口：$port_any"

        # 确保证书存在（如果 hy2/tuic 未启用，anytls 需要自己生成）
        if [ ! -s "$SINGBOX_FOLDER_PATH/cert.pem" ] || [ ! -s "$SINGBOX_FOLDER_PATH/private.key" ]; then
            gen_self_signed_cert "$SINGBOX_FOLDER_PATH/private.key" "$SINGBOX_FOLDER_PATH/cert.pem" "${CN_BING}" 36500
        fi

        jq --arg port "$port_any" --arg uuid "$uuid" \
            --arg sni "$any_sni" \
            --arg cert "$SINGBOX_FOLDER_PATH/cert.pem" --arg key "$SINGBOX_FOLDER_PATH/private.key" '
            .inbounds += [{
                 type: "anytls", tag: "anytls-sb", listen: "::",
                listen_port: ($port | tonumber),
                users: [{password: $uuid}],
                tls: {enabled: true, server_name: $sni, certificate_path: $cert, key_path: $key}
            }]' "$sbj" > "$tmpj" && mv "$tmpj" "$sbj"
    fi

    # 添加 socks5 协议
    if [ -n "$socksp" ]; then
        if [ -n "$port_socks5" ]; then
            echo "$port_socks5" > "$SINGBOX_FOLDER_PATH/port_socks5"
        elif [ -s "$SINGBOX_FOLDER_PATH/port_socks5" ]; then
            port_socks5=$(cat "$SINGBOX_FOLDER_PATH/port_socks5")
        else
            port_socks5=$(rand_port)
            echo "$port_socks5" > "$SINGBOX_FOLDER_PATH/port_socks5"
        fi

        init_socks5_credentials
        init_socks5_whitelist
        port_socks5=$(cat "$SINGBOX_FOLDER_PATH/port_socks5")
        yellow "Socks5端口：$port_socks5"
        yellow "Socks5用户名：$socks5_username"
        yellow "Socks5密码：$socks5_password"
        local _wl_flag_val=""
        [ -s "$SINGBOX_FOLDER_PATH/socks5_wl_flag" ] && _wl_flag_val=$(cat "$SINGBOX_FOLDER_PATH/socks5_wl_flag" | tr -d '\r\n')
        if is_true "$_wl_flag_val"; then
            local _wl_ips=""
            [ -s "$SINGBOX_FOLDER_PATH/socks5_ips" ] && _wl_ips=$(cat "$SINGBOX_FOLDER_PATH/socks5_ips" | tr -d '\r\n')
            if [ -n "$_wl_ips" ]; then
                yellow "Socks5白名单：已开启(防火墙规则)（允许：$_wl_ips）"
            else
                yellow "Socks5白名单：已开启（IP列表为空，等同于关闭）"
            fi
        else
            yellow "Socks5白名单：未开启（所有IP均可访问）"
        fi

        jq --arg port "$port_socks5" \
            --arg user "$socks5_username" --arg pass "$socks5_password" '
            .inbounds += [{
                type: "socks", tag: "socks5-sb",  listen: "::",
                listen_port: ($port | tonumber),
                users: [{username: $user, password: $pass}]
            }]' "$sbj" > "$tmpj" && mv "$tmpj" "$sbj"
    fi

    rm -f "$tmpj" 2> /dev/null || true

    # sb.json 内含全部协议口令，收紧权限
    chmod 600 "$sbj" 2>/dev/null || true

    # setup_warp_config   # 大陆外 VPS 不需要 WARP，注释掉
}
# Netflix/OpenAI/YouTube 走 WARP 解锁，其余直连
# ❗ setup_warp_config 已删除（调用点早已被注释掉，大陆外 VPS 不需要 WARP）。
#    sbbout() 里仍保留对旧 .warp_config 文件的读取逻辑，仅用于兼容历史安装，
#    该文件现在不会再被生成，因此这段分支实际不生效。

#  Generate Sing-box configuration file
sbbout() {
    if [ -e "$SINGBOX_FOLDER_PATH/sb.json" ]; then
    local sbj="$SINGBOX_FOLDER_PATH/sb.json"
    local tmpj="$SINGBOX_FOLDER_PATH/.sb.tmp"
    mkdir -p "$LOGS_DIR" 2> /dev/null

        # 读取 .warp_config：文件存在表示 WARP 已启用，内容为 true/false 表示 YouTube 是否走 WARP
        local warp_enabled=false need_youtube=false
        if [ -s "$SINGBOX_FOLDER_PATH/.warp_config" ]; then
            warp_enabled=true
            need_youtube=$(cat "$SINGBOX_FOLDER_PATH/.warp_config")
        fi

        jq --arg sbyx "$sbyx" --argjson warp "$warp_enabled" --argjson need_youtube "$need_youtube" '
            .outbounds = [{type: "direct", tag: "direct"}, {type: "block", tag: "block"}]
            | .route.final = "direct"
            | if $warp then
                if $need_youtube then
                    .route.rules = [{rule_set: ["netflix", "openai", "youtube"], outbound: "wireguard-out"}] + [{action: "sniff"}, {action: "resolve", strategy: $sbyx}]
                else
                    .route.rules = [{rule_set: ["netflix", "openai"], outbound: "wireguard-out"}] + [{action: "sniff"}, {action: "resolve", strategy: $sbyx}]
                end
              else
                .route.rules = [{action: "sniff"}, {action: "resolve", strategy: $sbyx}]
              end
        ' "$sbj" > "$tmpj" && mv "$tmpj" "$sbj"
        rm -f "$tmpj" 2> /dev/null || true
        # sb.json 内含全部协议口令，收紧权限（jq 写 tmp+mv 会重建文件，需重新 chmod）
        chmod 600 "$sbj" 2>/dev/null || true

        # 预创建 singbox.log，确保 sing-box 启动时文件已存在
        : > "$LOGS_DIR/singbox.log" 2>/dev/null

        if has_systemd && [ "$EUID" -eq 0 ]; then
            debug_log "【调试】sbbout：使用 systemd 管理/启动 sb 服务"
            cat > /etc/systemd/system/sb.service << EOF
[Unit]
Description=sb service
After=network.target
[Service]
Type=simple
NoNewPrivileges=yes
ExecStartPre=/bin/sh -c '[ -f /etc/iptables/rules.v4 ] && iptables-restore < /etc/iptables/rules.v4 2>/dev/null || true'
ExecStartPre=/bin/sh -c '[ -f /etc/iptables/rules.v6 ] && ip6tables-restore < /etc/iptables/rules.v6 2>/dev/null || true'
ExecStart=$SINGBOX_FOLDER_PATH/sing-box run -c $SINGBOX_FOLDER_PATH/sb.json
StandardOutput=append:$LOGS_DIR/singbox.log
StandardError=append:$LOGS_DIR/singbox.log
Restart=on-failure
RestartSec=5s
[Install]
WantedBy=multi-user.target
EOF
            systemctl daemon-reload
            systemctl enable sb
            systemctl start sb
            echo ""
            debug_print green "✅ sb 服务已启动,并开启开机自启服务（systemd）"
        elif command -v rc-service > /dev/null 2>&1 && [ "$EUID" -eq 0 ]; then
            debug_log "【调试】sbbout：使用 openrc 管理/启动 sb 服务"
            cat > /etc/init.d/sing-box << EOF
#!/sbin/openrc-run
description="sb service"
command="$SINGBOX_FOLDER_PATH/sing-box"
command_args="run -c $SINGBOX_FOLDER_PATH/sb.json"
command_background=yes
pidfile="/run/sing-box.pid"
depend() { need net; }
start_pre() {
    [ -f /etc/iptables/rules.v4 ] && iptables-restore < /etc/iptables/rules.v4 2>/dev/null || true
    [ -f /etc/iptables/rules.v6 ] && ip6tables-restore < /etc/iptables/rules.v6 2>/dev/null || true
}
EOF
            chmod +x /etc/init.d/sing-box
            if [ "${DEBUG_FLAG:-0}" = "1" ]; then
                rc-update add sing-box default
                rc-service sing-box start
            else
                rc-update add sing-box default > /dev/null 2>&1
                rc-service sing-box start > /dev/null 2>&1
            fi
            echo ""
            debug_print green "✅ sb 服务已启动,并开启开机自启服务（openrc）"
        else
            debug_log "【调试】sbbout：使用 nohup 模式运行 sb 服务"
            nohup "$SINGBOX_FOLDER_PATH/sing-box" run -c "$SINGBOX_FOLDER_PATH/sb.json" > /dev/null 2>&1 &
            echo ""
            debug_print green "✅  sb 服务已启动, 使用 nohup 模式运行"
        fi

        # 启动后检测 singbox.log 是否生成
        sleep 3
        if [ -s "$LOGS_DIR/singbox.log" ]; then
            debug_print green "✓ singbox.log 已生成"
        else
            yellow "⚠ singbox.log 为空，sing-box 可能启动失败，可用 sb log 查看"
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
    chmod 755 /var /var/www /var/www/singbox 2> /dev/null

    local vm_port vl_port tr_port uuid
    uuid="$(cat "$SINGBOX_FOLDER_PATH/uuid" 2> /dev/null)"
    vm_port="$(cat "$SINGBOX_FOLDER_PATH/port_vm_ws" 2> /dev/null)"
    if [ -s "$SINGBOX_FOLDER_PATH/port_vl_ws" ]; then
        vl_port="$(cat "$SINGBOX_FOLDER_PATH/port_vl_ws" 2> /dev/null)"
    else
        # 兼容旧版本 vmess 端口文件
        vl_port="$(cat "$SINGBOX_FOLDER_PATH/port_vm_ws" 2> /dev/null)"
    fi
    tr_port="$(cat "$SINGBOX_FOLDER_PATH/port_tr" 2> /dev/null)"

    local conf
    conf="$(nginx_conf_path)"
    mkdir -p "$(dirname "$conf")" > /dev/null 2>&1

    cat > "$conf" << EOF
server {
    listen ${port};
    listen 127.0.0.1:${argo_port};
    server_name _;
EOF

    # ✅ 订阅仅在 subscribe=true 才开放
    if is_true "$(get_subscribe_flag)" && [ -n "$uuid" ]; then
        cat >> "$conf" << EOF

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

    cat >> "$conf" << EOF

    # --------- ws 反代（固定 Argo 同域名下可代理节点） ---------
EOF

    if [ -n "$vm_port" ] && [ -n "$uuid" ]; then
        cat >> "$conf" << EOF
    location /${uuid}-vm {
        proxy_pass http://127.0.0.1:${vm_port};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }

EOF
    fi

    if [ -n "$vl_port" ] && [ -n "$uuid" ]; then
        cat >> "$conf" << EOF
    location /${uuid}-vl {
        proxy_pass http://127.0.0.1:${vl_port};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }

EOF
    fi

    if [ -n "$tr_port" ] && [ -n "$uuid" ]; then
        cat >> "$conf" << EOF
    location /${uuid}-tr {
        proxy_pass http://127.0.0.1:${tr_port};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
    }

EOF
    fi

    cat >> "$conf" << EOF
    location / {
        return 404;
    }
}
EOF

    nginx -t > /dev/null 2>&1 || {
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

        systemctl enable nginx > /dev/null 2>&1
        systemctl restart nginx > /dev/null 2>&1 || systemctl start nginx > /dev/null 2>&1
        echo ""
        debug_print green "✅ Nginx 服务已启动,并开启开机自启服务（systemd）"
        return 0
    fi

    # openrc
    if command -v rc-service > /dev/null 2>&1; then
        debug_log "【调试】start_nginx_service：使用 openrc 管理 Nginx 服务"
        rc-update add nginx default > /dev/null 2>&1
        rc-service nginx restart > /dev/null 2>&1 || rc-service nginx start > /dev/null 2>&1
        echo ""
        debug_print green "✅ Nginx 服务已启动,并开启开机自启服务（openrc）"
        return 0
    fi

    debug_log "【调试】start_nginx_service：使用 nohup 模式运行 Nginx 服务"
    # no init
    pkill -15 nginx > /dev/null 2>&1
    nohup nginx > /dev/null 2>&1 &
    echo ""
    debug_print green "✅ Nginx 服务已启动, 使用 nohup 模式运行"
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
        systemctl stop nginx > /dev/null 2>&1
        return 0
    fi

    # openrc
    if command -v rc-service > /dev/null 2>&1; then
        debug_log "【调试】nginx_stop：使用 openrc 管理 Nginx 服务"
        rc-service nginx stop > /dev/null 2>&1
        return 0
    fi

    # no init：直接杀进程
    pkill -15 -x nginx > /dev/null 2>&1
    debug_log "【调试】nginx_stop： Nginx 服务已停止"
    return 0
}

# 重启 Nginx 服务
nginx_restart() {
    debug_log "【调试】nginx_restart：开始重启 Nginx 服务"
    # systemd
    if has_systemd; then
        debug_log "【调试】nginx_restart：使用 systemd 管理 Nginx 服务"
        systemctl restart nginx > /dev/null 2>&1 || systemctl start nginx > /dev/null 2>&1
        echo
        green "✅ Nginx 服务已重启"
        return 0
    fi

    # openrc
    if command -v rc-service > /dev/null 2>&1; then
        debug_log "【调试】nginx_restart：使用 openrc 管理 Nginx 服务"
        rc-service nginx restart > /dev/null 2>&1 || rc-service nginx start > /dev/null 2>&1
        echo
        green "✅ Nginx 服务已重启"
        return 0
    fi

    debug_log "【调试】nginx_restart：使用 nohup 模式运行 Nginx 服务"
    # no init：优先 reload，不行就 stop+start
    if command -v nginx > /dev/null 2>&1; then
        debug_log "【调试】nginx_restart：使用 nohup 模式运行 Nginx 服务，尝试 reload"
        nginx -s reload > /dev/null 2>&1 && return 0
    fi

    debug_log "【调试】nginx_restart：使用 nohup 模式运行 Nginx 服务，尝试 stop+start"
    nginx_stop
    nginx_start
}

# 检查 Nginx 状态
nginx_status() {
    if pgrep -x nginx > /dev/null 2>&1; then
        echo "Nginx：$(green "运行中")"
    elif rc-service nginx status > /dev/null 2>&1; then
        echo "Nginx：$(green "运行中 (OpenRC)")"
    else
        echo "Nginx：$(red "未运行")"
    fi
}

# 确保 cloudflared 如果需要
ensure_cloudflared_if_needed() {
    # ✅ 仅当启用 argo=vmpt/trpt/vlpt 且 vmag 存在时才需要 cloudflared
    debug_log "【调试】ensure_cloudflared_if_needed：检查是否需要 cloudflared"
    if { [ "${argo:-}" != "vmpt" ] && [ "${argo:-}" != "trpt" ] && [ "${argo:-}" != "vlpt" ]; } || [ -z "${vmag:-}" ]; then
        debug_log "【调试】ensure_cloudflared_if_needed：未启用 Argo（或未启用 vmess/trojan/vless），跳过 cloudflared 下载/安装"
        purple "ℹ️ 未启用 Argo（或未启用 vmess/trojan/vless），跳过 cloudflared 下载/安装"
        return 0
    fi
    debug_log "【调试】ensure_cloudflared_if_needed：需要 cloudflared，开始下载/安装"
    ensure_cloudflared || return 1
    return 0
}

# 确保 cloudflared
ensure_cloudflared() {
    debug_log "【调试】ensure_cloudflared：开始下载/安装 cloudflared"

    # 已存在 → 版本比对
    if [ -x "$SINGBOX_FOLDER_PATH/cloudflared" ]; then
        local local_ver latest_ver
        local_ver=$("$SINGBOX_FOLDER_PATH/cloudflared" --version 2>/dev/null | grep -oE '[0-9]{4}\.[0-9]+\.[0-9]+' | head -1)
        latest_ver=$(curl -sI --max-time 10 "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$cpu" 2>/dev/null | grep -i 'location:' | grep -oE '[0-9]{4}\.[0-9]+\.[0-9]+')
        if [ -n "$local_ver" ] && [ -n "$latest_ver" ] && [ "$local_ver" = "$latest_ver" ]; then
            green "✅ Cloudflared 已安装最新版 (v${local_ver})，跳过下载"
            return 0
        fi
        if [ -n "$latest_ver" ]; then
            yellow "Cloudflared 版本不匹配 (当前: ${local_ver:-unknown}，最新: ${latest_ver})，开始下载新版…"
        else
            yellow "Cloudflared 版本检查失败（网络问题），保留现有版本"
            return 0
        fi
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

    # 完整性校验（运行时）：确保不是 HTML 错误页 / 截断文件，且版本可解析
    if head -c 256 "$out" | grep -qiE '<!DOCTYPE|<html|404: Not Found' 2> /dev/null; then
        red "❌ 下载内容异常（疑似 HTML 错误页）：$out"
        rm -f "$out" 2> /dev/null
        return 1
    fi

    debug_log "【调试】ensure_cloudflared：设置 cloudflared 二进制文件权限"
    chmod +x "$out" || return 1

    # 校验二进制能运行且版本格式正确（cloudflared version 2025.11.1）
    if ! "$out" --version 2> /dev/null | grep -qE '[0-9]{4}\.[0-9]+\.[0-9]+'; then
        red "❌ cloudflared 二进制校验失败（无法运行或版本异常），可能下载损坏"
        rm -f "$out" 2> /dev/null
        return 1
    fi

    debug_log "【调试】ensure_cloudflared：cloudflared 二进制文件权限设置成功"
    return 0
}

# 安装 Argo 服务（systemd）
install_argo_service_systemd() {
    local mode="$1" # json|token
    local token="$2"

    # 检查 systemd 是否存在
    if ! command -v systemctl > /dev/null 2>&1; then
        red "系统未检测到 systemd，跳过 systemd 服务安装！"
        return
    fi

    # 防注入：token 模式必须通过格式校验才能写进 systemd ExecStart
    if [ "$mode" != "json" ] && ! is_valid_argo_token "$token"; then
        red "❌ Argo token 格式非法，已中止写入 systemd 服务（防注入）"
        return 1
    fi

    if [ "$mode" = "json" ]; then
        debug_log "【调试】使用 json 模式安装 argo 服务(systemd)"

        cat > /etc/systemd/system/argo.service << EOF
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

        cat > /etc/systemd/system/argo.service << EOF
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
    debug_print green "✅ Argo 服务已启动并成功设置开机自启动（systemd）"
}

# 安装 Argo 服务（openrc）
install_argo_service_openrc() {
    local mode="$1" # json|token
    local token="$2"

    # 检查 openrc 是否存在
    if ! command -v rc-service > /dev/null 2>&1; then
        red "系统未检测到 openrc，跳过 openrc 服务安装！"
        return
    fi

    # 防注入：token 会写进 /etc/init.d/argo，由 openrc 当作 shell 脚本执行，必须校验格式
    if [ "$mode" != "json" ] && ! is_valid_argo_token "$token"; then
        red "❌ Argo token 格式非法，已中止写入 openrc 服务（防注入）"
        return 1
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

    cat > /etc/init.d/argo << EOF
#!/sbin/openrc-run
description="argo service"
command="${command_path}"
command_args="${args}"
command_background=yes
pidfile="/run/argo.pid"
depend() { need net; }
EOF

    chmod +x /etc/init.d/argo
    if [ "${DEBUG_FLAG:-0}" = "1" ]; then
        rc-update add argo default
        rc-service argo start
    else
        rc-update add argo default > /dev/null 2>&1
        rc-service argo start > /dev/null 2>&1
    fi
    debug_print green "✅ Argo 服务已成功安装并启动（openrc）"
}

# 无守护进程启动 Argo
start_argo_no_daemon() {
    local mode="$1"
    local token="$2"
    local port="$3"
    mkdir -p "$LOGS_DIR" 2> /dev/null

    if [ "$mode" = "json" ]; then
        debug_log "【调试】使用 json 模式，nohup 启动 argo"
        nohup "$SINGBOX_FOLDER_PATH/cloudflared" tunnel \
            --edge-ip-version auto \
            --config "$SINGBOX_FOLDER_PATH/tunnel.yml" run \
            > "$LOGS_DIR/argo.log" 2>&1 &
    elif [ -n "$token" ]; then
        debug_log "【调试】使用 token 模式，nohup 启动 argo"
        nohup "$SINGBOX_FOLDER_PATH/cloudflared" tunnel \
            --no-autoupdate \
            --edge-ip-version auto run \
            --token "$token" \
            > "$LOGS_DIR/argo.log" 2>&1 &
    else
        debug_log "【调试】使用 URL 模式，nohup 启动 argo"
        nohup "$SINGBOX_FOLDER_PATH/cloudflared" tunnel \
            --url "http://localhost:${port}" \
            --edge-ip-version auto \
            --no-autoupdate \
            > "$LOGS_DIR/argo.log" 2>&1 &
    fi
}

# 等待并检查 Argo
wait_and_check_argo() {
    local argo_tunnel_type="${1:-临时}" # 第一个参数：隧道类型（固定/临时）
    local argo_log="$LOGS_DIR/argo.log"
    local ym_log="$SINGBOX_FOLDER_PATH/argo_domain"
    local argodomain=""
    local i=0
    local max_wait=30

    # ✅ 没启用 argo：直接跳过
    if ! need_argo; then
        purple "ℹ️ 未启用 Argo，跳过 Argo 域名检查"
        return 0
    fi

    # ✅ 规范化隧道类型
    case "$argo_tunnel_type" in
        固定 | fixed | FIXED) argo_tunnel_type="固定" ;;
        临时 | temp | temporary | "") argo_tunnel_type="临时" ;;
        *)
            yellow "❗ 未知隧道类型：${argo_tunnel_type}，按【临时】处理" >&2
            argo_tunnel_type="临时"
            ;;
    esac

    # ✅ 固定 Argo：域名只允许来自 ARGO_DOMAIN 或 argo_domain
    if [ "$argo_tunnel_type" = "固定" ]; then
        if [ -n "${ARGO_DOMAIN}" ]; then
            argodomain="${ARGO_DOMAIN}"
        elif [ -s "$ym_log" ]; then
            argodomain="$(tail -n1 "$ym_log" 2> /dev/null | tr -d '\r\n')"
        fi

        # 校验：必须是通过 is_valid_domain 的合法域名（防注入）
        if [ -n "$argodomain" ] && is_valid_domain "$argodomain"; then
            export ARGO_DOMAIN="$argodomain"
            echo "$ARGO_DOMAIN" > "$ym_log" 2> /dev/null
            chmod 600 "$ym_log" 2>/dev/null || true
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
            argodomain="$(grep -aoE '[a-zA-Z0-9.-]+\.trycloudflare\.com' "$argo_log" 2> /dev/null | tail -n1)"
            if [ -n "$argodomain" ]; then
                export ARGO_DOMAIN="$argodomain"
                echo "$ARGO_DOMAIN" > "$ym_log" 2> /dev/null
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

# _legacy 后安装收尾
post_install_finalize_legacy() {
    # 用“最多等待 10 秒 + 检测到就立刻继续”替代固定 sleep
    for i in 1 2 3 4 5 6 7 8 9 10; do
        if pgrep -f "$SINGBOX_FOLDER_PATH/sing-box" > /dev/null 2>&1 || pgrep -f "$SINGBOX_FOLDER_PATH/cloudflared" > /dev/null 2>&1; then
            break
        fi
        sleep 1
    done
    echo

    # 只要 sing-box 或 cloudflared 进程存在，认为安装启动成功
    if pgrep -f "$SINGBOX_FOLDER_PATH/sing-box" > /dev/null 2>&1 || pgrep -f "$SINGBOX_FOLDER_PATH/cloudflared" > /dev/null 2>&1; then
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
    # 2) 启用 argo（vmpt/trpt/vlpt）
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

#工具函数：判断 IP 合法（宽松 IPv6：含冒号）
is_valid_ip_simple() {
    local ip
    ip="$(strip_ip_brackets_all "${1:-}")"

    [ -n "$ip" ] || return 1

    # IPv4
    if echo "$ip" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
        return 0
    fi

    # IPv6：包含冒号就是 IPv6（宽松判断，脚本内部用足够安全）
    if echo "$ip" | grep -q ':'; then
        return 0
    fi

    return 1
}

# 4) 工具函数：输出写入 server_ip 的最终形式（IPv6 自动加 []）
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
    IFS='|' read -r v4_local v6_local << EOF
$(printf '%s' "$v4v6_result" | tr -d '\r\n')
EOF
    v4_local="${v4_local:-}"
    v6_local="${v6_local:-}"

    debug_log "【调试】pick_server_ip_for_install：v4_local=${v4_local}，v6_local=${v6_local}"

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
            (curl -s4m2 -k "$v46url" 2> /dev/null) || (wget -4 -qO- --timeout=2 --tries=2 "$v46url" 2> /dev/null)
        )"
        debug_log "【调试】pick_server_ip_for_install函数：由于prefer_ip 为空或不合法，开始兜底抓公网ipv4,serip_raw=$serip_raw"
        if [ -z "$serip_raw" ]; then
            debug_log "【调试】pick_server_ip_for_install函数：由于prefer_ip 为空或不合法，开始兜底抓公网ipv4,ipv4 为空，开始抓ipv6……"
            serip_raw="$(
                (curl -s6m2 -k "$v46url" 2> /dev/null) || (wget -6 -qO- --timeout=2 --tries=2 "$v46url" 2> /dev/null)
            )"
            debug_log "【调试】pick_server_ip_for_install函数：由于prefer_ip 为空或不合法，抓公网ipv6结束,serip_raw=$serip_raw"
        fi
        server_ip="$(strip_ip_brackets_all "$serip_raw")"
        debug_log "【调试】pick_server_ip_for_install：最终抓取的公网IP,server_ip=$server_ip"
    fi

    debug_log "【调试】pick_server_ip_for_install：开始对比out_ip与server_ip，out_ip=${out_ip}，server_ip=${server_ip}"

    # 8) 处理 out_ip：去括号后再比较；若 out_ip 合法且与 server_ip 不同，则 out_ip 覆盖server_ip的值
    local out_norm
    out_norm="$(strip_ip_brackets_all "${out_ip:-}")"
    if is_valid_ip_simple "$out_norm" && [ -n "$out_norm" ]; then
        debug_log "【调试】pick_server_ip_for_install：out_ip经过处理格式后，out_norm=$out_norm"
        if [ -z "$server_ip" ] || ! is_valid_ip_simple "$server_ip" || [ "$out_norm" != "$(strip_ip_brackets_all "$server_ip")" ]; then
            debug_log "【调试】pick_server_ip_for_install：out_ip合法且与server_ip不同，out_norm=${out_norm}，server_ip=${server_ip}"
            server_ip="$out_norm"
        fi
    fi

    debug_log "【调试】pick_server_ip_for_install：最终选择的服务器IP，server_ip=$server_ip"

    # 9) 网络 / out_ip 都拿不到合法 IP 时，复用已有 server_ip 文件（无网络兜底）
    if [ -z "$server_ip" ] || ! is_valid_ip_simple "$server_ip"; then
        if [ -s "$SINGBOX_FOLDER_PATH/server_ip" ]; then
            local file_ip
            file_ip="$(cat "$SINGBOX_FOLDER_PATH/server_ip" 2>/dev/null || true)"
            file_ip="$(strip_ip_brackets_all "$file_ip")"
            if is_valid_ip_simple "$file_ip" && [ -n "$file_ip" ]; then
                yellow "⚠️ 网络获取 IP 失败，复用已有 server_ip 文件：${file_ip}"
                server_ip="$file_ip"
            fi
        fi
    fi

    # 10) 最终写入：IPv6 加 []，写入 $SINGBOX_FOLDER_PATH/server_ip
    mkdir -p "$SINGBOX_FOLDER_PATH" 2> /dev/null || true

    local ip_final
    ip_final="$(format_ip_for_log "$server_ip" 2> /dev/null || true)"
    debug_log "【调试】pick_server_ip_for_install：最终写入的IP文件形式，ip_final=$ip_final"
    echo "$ip_final" > "$SINGBOX_FOLDER_PATH/server_ip"

    debug_log "【调试】pick_server_ip_for_install：已写入 $SINGBOX_FOLDER_PATH/server_ip, ip_final=$ip_final"

}

# =========================
# 展示阶段：显示本机 v4/v6 + 地区，并在出口 IP 变更时提示
# =========================
show_local_ip_info_with_out_ip_hint() {
    local _old_suppress="$_SUPPRESS_LOG"
    _SUPPRESS_LOG=1
    # A) 获取本机 v4/v6
    local v4v6_result v4_local v6_local
    v4v6_result="$(check_ip_connectivity "${v46url:-https://icanhazip.com}")"
    IFS='|' read -r v4_local v6_local << EOF
$(printf '%s' "$v4v6_result" | tr -d '\r\n')
EOF
    v4_local="$(strip_ip_brackets_all "$v4_local")"
    v6_local="$(strip_ip_brackets_all "$v6_local")"

    # B) 读取地区（本地 IP→地区 缓存，未命中才查网络并写回）
    local v4dq="" v6dq=""
    v4dq="$(geo_get_ip "$v4_local")"
    v6dq="$(geo_get_ip "$v6_local")"
    [ -z "$v4dq" ] && v4dq="未知"
    [ -z "$v6dq" ] && v6dq="未知"

    # C) 决定 current_server_ip： server_ip
    local current_server_ip=""
    local out_norm
    out_norm="$(strip_ip_brackets_all "${out_ip:-}")"

    if [ -s "$SINGBOX_FOLDER_PATH/server_ip" ]; then
        current_server_ip="$(strip_ip_brackets_all "$(cat "$SINGBOX_FOLDER_PATH/server_ip" 2> /dev/null)")"
    fi

    # D) 输出本地 IP 地址
    green "=========当前服务器本地IP情况========="
    printf '%s\n' "=========当前服务器本地IP情况=========" >> "$INSTALL_LOG" 2>/dev/null

    # 输出 IPv4 地址
    if [ -n "$v4_local" ]; then
        echo "$(white "IPV4地址：")$(yellow "${v4_local}")$(white "(服务器地区：")$(green "${v4dq}")$(white ")")"
        printf '%s\n' "IPV4地址：${v4_local}(服务器地区：${v4dq})" >> "$INSTALL_LOG" 2>/dev/null
    else
        echo "$(white "IPV4地址：")$(yellow "无IPV4")"
        printf '%s\n' "IPV4地址：无IPV4" >> "$INSTALL_LOG" 2>/dev/null
    fi

    # 输出 IPv6 地址
    if [ -n "$v6_local" ]; then
        echo "$(white "IPV6地址：")$(purple "${v6_local}")$(white "(服务器地区：")$(green "${v6dq}")$(white ")")"
        printf '%s\n' "IPV6地址：${v6_local}(服务器地区：${v6dq})" >> "$INSTALL_LOG" 2>/dev/null
    else
        echo "$(white "IPV6地址：")$(purple "无IPV6")"
        printf '%s\n' "IPV6地址：无IPV6" >> "$INSTALL_LOG" 2>/dev/null
    fi

    echo
    printf '%s\n' "" >> "$INSTALL_LOG" 2>/dev/null

    # E) 打印"当前使用的IP"：
    if [ -n "$v4_local" ] && [ "$v4_local" = "$current_server_ip" ]; then
        echo "$(green "✅ 当前使用的IP：")$(yellow "${v4_local}")$(white " (IPv4)")"
        printf '%s\n' "✅ 当前使用的IP：${v4_local} (IPv4)" >> "$INSTALL_LOG" 2>/dev/null
    fi
    if [ -n "$v6_local" ] && [ "$v6_local" = "$current_server_ip" ]; then
        echo "$(green "✅ 当前使用的IP：")$(purple "${v6_local}")$(white " (IPv6)")"
        printf '%s\n' "✅ 当前使用的IP：${v6_local} (IPv6)" >> "$INSTALL_LOG" 2>/dev/null
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
            show_ip="$(format_ip_for_log "$current_server_ip" 2> /dev/null || echo "$current_server_ip")"
            yellow " ❗ 👉  由于你设置了单独的出口ip,出口IP已变更为：$show_ip   👈"
        fi
    fi
    _SUPPRESS_LOG="$_old_suppress"
}

ins() {
    debug_log "【调试】进入 ins() 安装流程"
    debug_log "【调试】关键参数：argo=${argo:-<空>}，vmag=${vmag:-<空>}，subscribe=$(get_subscribe_flag 2> /dev/null || echo ${subscribe:-false})，nginx_pt=${nginx_pt:-<空>}，argo_pt=${argo_pt:-<空>}"
    # =====================================================
    # 1. 安装并启动 sing-box
    # =====================================================
    installsb
    set_sbyx
    sbbout
    apply_singbox_iptables_rules
    apply_socks5_whitelist

    # 把ip写入server_ip
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
        echo "$argoport" > "$SINGBOX_FOLDER_PATH/argoport"

        # 仍然记录 Argo 输出节点类型（给 cip 用）
        if [ "$argo" = "vmpt" ]; then
            echo "Vmess" > "$SINGBOX_FOLDER_PATH/vlvm"
        elif [ "$argo" = "trpt" ]; then
            echo "Trojan" > "$SINGBOX_FOLDER_PATH/vlvm"
        elif [ "$argo" = "vlpt" ]; then
            echo "Vless" > "$SINGBOX_FOLDER_PATH/vlvm"
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
                _systemctl_path="$(command -v systemctl 2> /dev/null || true)"

                [ -n "$_systemctl_path" ] || _systemctl_path="无"
                _systemd_dir_status="$([ -d /run/systemd/system ] && echo 存在 || echo 不存在)"
                _pid1="$(ps -p 1 -o comm= 2> /dev/null | tr -d '[:space:]')"
                debug_log "【调试】systemd 判定：_has_systemd=$(has_systemd)systemctl=${_systemctl_path}，/run/systemd/system=${_systemd_dir_status}，PID1=${_pid1}"
            fi

            # systemd 判定
            if has_systemd && [ "$EUID" -eq 0 ]; then
                debug_log "【调试】启动方式：systemd 服务（install_argo_service_systemd），模式=${ARGO_MODE}"

                install_argo_service_systemd "$ARGO_MODE" "$ARGO_AUTH"

            elif command -v rc-service > /dev/null 2>&1 && [ "$EUID" -eq 0 ]; then

                debug_log "【调试】启动方式：openrc 服务（install_argo_service_openrc），模式=${ARGO_MODE}"
                install_argo_service_openrc "$ARGO_MODE" "$ARGO_AUTH"
            else
                # 无 systemd / openrc，直接后台启动
                debug_log "【调试】启动方式：无 systemd/openrc，直接后台启动（start_argo_no_daemon，模式=${ARGO_MODE}）"
                start_argo_no_daemon "$ARGO_MODE" "$ARGO_AUTH" "$argoport"
            fi

            # 与原版一致：固定 Argo 域名直接落盘
            echo "$ARGO_DOMAIN" > "$SINGBOX_FOLDER_PATH/argo_domain"
            chmod 600 "$SINGBOX_FOLDER_PATH/argo_domain" 2>/dev/null || true
            # token 模式下才会有 sbargotoken
            [ "$ARGO_MODE" = "token" ] && { echo "$ARGO_AUTH" > "$SINGBOX_FOLDER_PATH/sbargotoken"; chmod 600 "$SINGBOX_FOLDER_PATH/sbargotoken" 2>/dev/null || true; }
        else
            # 临时 Argo（trycloudflare）
            argo_tunnel_type="临时"
            debug_log "【调试】判定为临时 Argo 隧道（未提供 ARGO_DOMAIN/ARGO_AUTH，走 trycloudflare）"
            debug_log "【调试】启动方式：临时隧道，直接后台启动（start_argo_no_daemon temp），模式=${ARGO_MODE}"
            start_argo_no_daemon "temp" "" "$argoport"
        fi

        # 2.5 等待并检查 Argo 申请结果（原版 sleep + grep 逻辑）
        debug_log "【调试】开始等待并检查 Argo 申请结果：tunnel_type=${argo_tunnel_type}，日志文件：$LOGS_DIR/argo.log"
        wait_and_check_argo "$argo_tunnel_type"
    fi

    # =====================================================
    # 3. 安装完成后的 legacy 收尾逻辑
    #    （进程检测）
    # =====================================================
    post_install_finalize_legacy
    debug_log "【调试】post_install_finalize_legacy 已执行完成"

    # 创建 sb 快捷命令
    ensure_sb_shortcut
    debug_log "【调试】ensure_sb_shortcut 已执行完成（sb 快捷命令）"
}

# Write environment variables to files for persistence
write2SingboxFolders() {
    mkdir -p "$SINGBOX_FOLDER_PATH"

    echo "${vl_sni}" > "$SINGBOX_FOLDER_PATH/vl_sni"
    echo "${hy_sni}" > "$SINGBOX_FOLDER_PATH/hy_sni"
    echo "${tu_sni}" > "$SINGBOX_FOLDER_PATH/tu_sni"
    # any_sni 在 anytls 配置生成时处理，这里不覆盖
    [ ! -s "$SINGBOX_FOLDER_PATH/any_sni" ] && echo "${any_sni}" > "$SINGBOX_FOLDER_PATH/any_sni"
    echo "${cdn_host}" > "$SINGBOX_FOLDER_PATH/cdn_host"
    echo "${cdn_pt}" > "$SINGBOX_FOLDER_PATH/cdn_pt"

    # ✅ 只写新变量
    echo "${nginx_pt}" > "$SINGBOX_FOLDER_PATH/nginx_port"

    echo "${vl_sni_pt}" > "$SINGBOX_FOLDER_PATH/vl_sni_pt"

    # ✅ 订阅开关落盘（默认 false）
    echo "${subscribe}" > "$SINGBOX_FOLDER_PATH/subscribe"
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
    if command -v openssl > /dev/null 2>&1; then
        if openssl base64 -A -in "$SINGBOX_FOLDER_PATH/jh.txt" > "$out" 2> /dev/null; then
            purple "✅ sub.txt 生成成功：$out"
            return 0
        else
            red "❌ sub.txt 生成失败（openssl base64）"
            return 1
        fi
    fi

    # ✅ fallback：base64（兼容 busybox 与 GNU）
    if command -v base64 > /dev/null 2>&1; then
        if base64 -w 0 "$SINGBOX_FOLDER_PATH/jh.txt" 2> /dev/null > "$out"; then
            purple "✅  sub.txt 生成成功：$out"
            return 0
        fi

        # busybox base64 没有 -w 参数
        if base64 "$SINGBOX_FOLDER_PATH/jh.txt" 2> /dev/null | tr -d '\n' > "$out"; then
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
    sub_uuid="$(cat "$SINGBOX_FOLDER_PATH/uuid" 2> /dev/null)"

    [ -z "$sub_uuid" ] && return 0

    local argodomain=$(cat "$SINGBOX_FOLDER_PATH/argo_domain" 2> /dev/null)

    local need_argo_flag=false
    vlvm=$(cat "$SINGBOX_FOLDER_PATH/vlvm" 2> /dev/null)
    # vlvm不为空，则代表一定有argo
    if [ -n "$vlvm" ]; then
        need_argo_flag=true
    fi

    # 当 need_argo_flag 为 true 且 argodomain 为空且 argo.log 存在时
    if $need_argo_flag && [ -z "$argodomain" ] && [ -s "$LOGS_DIR/argo.log" ]; then
        argodomain=$(grep -aoE '[a-zA-Z0-9.-]+\.trycloudflare\.com' "$LOGS_DIR/argo.log" 2> /dev/null | tail -n1)
    fi

    # 当argodomain 不为空时
    if [ -n "$argodomain" ]; then
        echo "https://${argodomain}/sub/${sub_uuid}"
        return 0
    fi

    # 普通 http：IP:PORT
    local server_ip
    server_ip=$(cat "$SINGBOX_FOLDER_PATH/server_ip" 2> /dev/null)

    if [ -z "$server_ip" ]; then
        server_ip="$( (curl -s4m5 -k https://icanhazip.com) || (wget -4 -qO- --tries=2 https://icanhazip.com))"
        server_ip=$(update_server_ip "$server_ip" "$out_ip")
        server_ip=$(add_ipv6_brackets "$server_ip") # 确保 IPv6 地址加上中括号
    fi

    # ❗ 安全提示：无 Argo 时订阅只能走明文 HTTP，会暴露订阅 URL（内含所有节点口令）
    #    只应在可信网络使用；如需公网安全订阅请启用固定/临时 Argo（https）或关闭订阅
    yellow "⚠️ 订阅走明文 HTTP，且订阅 URL 内含全部节点口令，请勿在不可信网络分享/抓包"
    echo "http://${server_ip}:${port}/sub/${sub_uuid}"
}

ensure_and_print_reality_private_for_cip() {
    local want_print="${1:-0}"
    [ "$want_print" = "1" ] || return 0

    if [ -z "$reality_private" ] && [ -s "$SINGBOX_FOLDER_PATH/reality.key" ]; then
        reality_private="$(_to_urlsafe_base64 "$(awk '/PrivateKey/{print $NF; exit}' "$SINGBOX_FOLDER_PATH/reality.key" 2> /dev/null)")"
        reality_public="$(_to_urlsafe_base64 "$(awk '/PublicKey/{print $NF; exit}' "$SINGBOX_FOLDER_PATH/reality.key" 2> /dev/null)")"
    fi

    if [ -n "$reality_private" ]; then
        print_reality_keypair_hint 1
    fi
}

print_reality_key() {
    case "${1:-}" in
        key | rp | showkey)
            ensure_and_print_reality_private_for_cip 1
            ;;
    esac
}

append_jh() {
    # 只写纯文本到聚合文件，禁止任何颜色码污染订阅
    # ❗ 用 printf '%s\n' 而非 echo -e：防止节点名/域名里带 \n、\x.. 时被解释成转义注入订阅内容
    printf '%s\n' "$1" >> "$SINGBOX_FOLDER_PATH/jh.txt"
}

# 节点名称片段统一做 URL 编码（防空格/#/?/& 等特殊字符破坏链接，同时防换行污染订阅）
node_frag() { url_encode_component "$1"; }

url_encode_component() {
    local s="${1:-}"

    if command -v jq > /dev/null 2>&1; then
        printf '%s' "$s" | jq -sRr @uri
        return
    fi

    printf '%s' "$s" | sed -e 's/%/%25/g' -e 's/@/%40/g' -e 's/#/%23/g' -e 's/:/%3A/g' -e 's/+/%2B/g' -e 's/ /%20/g'
}

json_escape_string() {
    local s="${1:-}"

    if command -v jq > /dev/null 2>&1; then
        printf '%s' "$s" | jq -sRr @json
        return
    fi

    printf '"'
    printf '%s' "$s" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
    printf '"'
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
    local current_server_ip="$1"
    local out_ip_local="$2" # 修改变量名，避免与其他地方的 out_ip 混淆

    # 输出调试信息，显示传入的参数
    debug_log "[调试] 原始 current_server_ip: $current_server_ip"
    debug_log "[调试] 原始 out_ip_local: $out_ip_local"

    # 如果 current_server_ip 是 IPv6 地址（即包含中括号），去除中括号
    if echo "$current_server_ip" | grep -q '^\[' && echo "$current_server_ip" | grep -q '\]$'; then
        debug_log "[调试] 去掉 current_server_ip 中的中括号"
        current_server_ip=$(printf '%s' "$current_server_ip" | sed 's/^\[\(.*\)\]$/\1/') # 去掉中括号
        debug_log "[调试] 去掉中括号后的 current_server_ip: $current_server_ip"
    fi

    # 如果 out_ip_local 非空且包含中括号，则去除中括号
    if [ -n "$out_ip_local" ] && echo "$out_ip_local" | grep -q '^\[' && echo "$out_ip_local" | grep -q '\]$'; then
        debug_log "[调试] 去掉 out_ip_local 中的中括号"
        out_ip_local=$(printf '%s' "$out_ip_local" | sed 's/^\[\(.*\)\]$/\1/') # 去掉中括号
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
        echo "[$ipv6]" # 给 IPv6 地址加上中括号
    else
        echo "$ipv6" # 否则返回原始地址
    fi
}

# 去掉 IPv6 的中括号： [2001:db8::1] -> 2001:db8::1
strip_ip_brackets() {
    # todo 要去掉这个函数
    local ip="${1:-}"
    ip="${ip#[}" # 去掉开头的 [
    ip="${ip%]}" # 去掉结尾的 ]
    echo "$ip"
}

# show nodes
cip() {
    echo
    geo_prefetch
    if ! is_installed_sb; then
        red "  ⚠️  尚未安装节点，请先安装节点"
        echo ""
        return
    fi
    # 显示 Singbox 状态（与主菜单顶部一致）
    menu_status_block
    echo

    # 显示本机 v4/v6 + 地区，并在出口 IP 变更时提示
    show_local_ip_info_with_out_ip_hint

    regenerate_links_and_sub "$1"

    echo
    yellow "📌 节点订阅地址："
    if ! is_true "$(get_subscribe_flag)"; then
        purple "⛔ 未开启订阅"
    else
        green "$(show_sub_url)"
    fi

    echo
    yellow "聚合节点: cat $SINGBOX_FOLDER_PATH/jh.txt"
    yellow "========================================================="
    showmode

}

# 根据当前配置文件重新生成 jh.txt 并刷新订阅（SNI/端口/Argo 等变更后调用）
regenerate_links_and_sub() {
    local _cip_arg="${1:-}"
    local uuid server_ip sxname port_hy2 hy_sni SHA256_hy2 port_tu tu_sni password
    local port_vlr public_key short_id vl_sni port_any any_sni
    local argodomain cdn_host cdn_pt vlvm vmatls_link1 vlessws_link1 tratls_link1 sbtk
    local port_socks5 socks5_username socks5_password socks5_user_enc socks5_pass_enc socks5_link

    rm -rf "$SINGBOX_FOLDER_PATH/jh.txt"
    uuid=$(cat "$SINGBOX_FOLDER_PATH/uuid")
    server_ip=$(cat "$SINGBOX_FOLDER_PATH/server_ip" 2> /dev/null)
    # 清洗 name（去掉 CR/LF，防跨行注入订阅）
    sxname=$(cat "$SINGBOX_FOLDER_PATH/name" 2> /dev/null | tr -d '\r\n')

    echo "*********************************************************"
    purple "Singbox脚本输出节点配置如下："
    echo
    # Hysteria2 protocol (hy2)
    if grep -q "hy2-sb" "$SINGBOX_FOLDER_PATH/sb.json"; then
        port_hy2=$(cat "$SINGBOX_FOLDER_PATH/port_hy2")
        hy_sni=$(cat "$SINGBOX_FOLDER_PATH/hy_sni")
        SHA256_hy2=$(openssl x509 -in "$SINGBOX_FOLDER_PATH/cert.pem" -outform DER 2>/dev/null | sha256sum | awk '{print $1}')
        hy2_link="hysteria2://$uuid@$server_ip:$port_hy2/?sni=${hy_sni}&insecure=1&pinSHA256=${SHA256_hy2}&alpn=h3&obfs=none#$(node_frag "${sxname}hy2-${hostname}")"
        yellow "🎯【 Hysteria2 】(直连协议)"
        green "$hy2_link"
        append_jh "$hy2_link"
        echo
    fi

    # TUIC protocol (tuic or tupt)
    if grep -q "tuic-sb" "$SINGBOX_FOLDER_PATH/sb.json"; then
        port_tu=$(cat "$SINGBOX_FOLDER_PATH/port_tu")
        tu_sni=$(cat "$SINGBOX_FOLDER_PATH/tu_sni")
        password=$uuid

        tuic_link="tuic://${uuid}:${password}@${server_ip}:${port_tu}?sni=${tu_sni}&congestion_control=bbr&security=tls&udp_relay_mode=native&alpn=h3&allow_insecure=1#$(node_frag "${sxname}tuic-${hostname}")"
        yellow "🎯【 TUIC 】(直连协议)"
        green "$tuic_link"
        append_jh "$tuic_link"
        echo
    fi
    # VLESS-Reality-Vision protocol (vless-reality-vision)
    if grep -q "vless-reality-vision-sb" "$SINGBOX_FOLDER_PATH/sb.json"; then
        port_vlr=$(cat "$SINGBOX_FOLDER_PATH/port_vlr")
        public_key="$(_to_urlsafe_base64 "$(sed -n '2p' "$SINGBOX_FOLDER_PATH/reality.key" | awk '{print $2}')")"
        short_id=$(cat "$SINGBOX_FOLDER_PATH/short_id")
        vl_sni=$(cat "$SINGBOX_FOLDER_PATH/vl_sni")

        debug_log "【调试】regenerate_links_and_sub函数中的short_id,值为:$short_id"

        vless_link="vless://${uuid}@${server_ip}:${port_vlr}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${vl_sni}&fp=chrome&pbk=${public_key}&sid=${short_id}&type=tcp&headerType=none#$(node_frag "${sxname}vless-reality-${hostname}")"
        yellow "🎯【 VLESS-Reality-Vision 】(直连协议)"
        green "$vless_link"
        append_jh "$vless_link"
        echo

        # 查看节点时提示用户保存私钥（方便下次保持节点一致）,一般这里的$1值为"key"
        print_reality_key "$_cip_arg"
    fi
    # AnyTLS protocol output
    if grep -q "anytls-sb" "$SINGBOX_FOLDER_PATH/sb.json"; then
        port_any=$(cat "$SINGBOX_FOLDER_PATH/port_any")
        any_sni=$(cat "$SINGBOX_FOLDER_PATH/any_sni")

        anytls_link="anytls://${uuid}@${server_ip}:${port_any}?security=tls&sni=${any_sni}&fp=firefox&insecure=1&allowInsecure=1&type=tcp#$(node_frag "${sxname}anytls-${hostname}")"
        yellow "🔐【 AnyTLS 】(直连协议)"
        green "$anytls_link"
        append_jh "$anytls_link"
        echo
    fi

    argodomain=$(cat "$SINGBOX_FOLDER_PATH/argo_domain" 2> /dev/null)

    if need_argo && [ -z "$argodomain" ] && [ -s "$LOGS_DIR/argo.log" ]; then
        argodomain=$(grep -aoE '[a-zA-Z0-9.-]+\.trycloudflare\.com' "$LOGS_DIR/argo.log" 2> /dev/null | tail -n1)
    fi

    cdn_host=$(cat "$SINGBOX_FOLDER_PATH/cdn_host")
    cdn_pt=$(cat "$SINGBOX_FOLDER_PATH/cdn_pt" 2> /dev/null)
    cdn_pt="$(normalize_cdn_pt "$cdn_pt" 443)"

    if [ -n "$argodomain" ]; then
        vlvm=$(cat "$SINGBOX_FOLDER_PATH/vlvm" 2> /dev/null)
        uuid=$(cat "$SINGBOX_FOLDER_PATH/uuid")
        if [ "$vlvm" = "Vmess" ]; then
            vmatls_link1="vmess://$(printf '%s' "{\"v\":\"2\",\"ps\":$(json_escape_string "${sxname}vmess-ws-tls-argo-${hostname}-${cdn_pt}"),\"add\":$(json_escape_string "${cdn_host}"),\"port\":\"${cdn_pt}\",\"id\":\"$uuid\",\"aid\":\"0\",\"net\":\"ws\",\"host\":$(json_escape_string "${argodomain}"),\"path\":\"/${uuid}-vm\",\"tls\":\"tls\",\"sni\":$(json_escape_string "${argodomain}")}" | base64 | tr -d '\n\r')"

            vlessws_link1=""
            tratls_link1=""
        elif [ "$vlvm" = "Trojan" ]; then
            tratls_link1="trojan://${uuid}@${cdn_host}:${cdn_pt}?security=tls&type=ws&host=${argodomain}&path=%2F${uuid}-tr&sni=${argodomain}&fp=chrome#$(node_frag "${sxname}trojan-ws-tls-argo-${hostname}-${cdn_pt}")"
            vmatls_link1=""
            vlessws_link1=""
        elif [ "$vlvm" = "Vless" ]; then
            vlessws_link1="vless://${uuid}@${cdn_host}:${cdn_pt}?encryption=none&security=tls&type=ws&host=${argodomain}&path=%2F${uuid}-vl&sni=${argodomain}&fp=chrome#$(node_frag "${sxname}vless-ws-tls-argo-${hostname}-${cdn_pt}")"
            vmatls_link1=""
            tratls_link1=""
        fi

        sbtk=$(cat "$SINGBOX_FOLDER_PATH/sbargotoken" 2> /dev/null)
        yellow "---------------------------------------------------------"
        yellow "Argo隧道信息 (使用 ${vlvm}-ws 端口: $(cat $SINGBOX_FOLDER_PATH/argoport 2> /dev/null))"
        yellow "---------------------------------------------------------"

        green "Argo域名: ${argodomain}"

        #输出 argo token
        if [ -n "${sbtk}" ]; then
            green "Argo固定隧道token:"
            green "${sbtk}"
        fi

        green ""
        green "🎯 ${cdn_pt}端口 Argo-TLS 节点 (优选IP可替换):"
        green "${vmatls_link1}${vlessws_link1}${tratls_link1}"
        append_jh "${vmatls_link1}${vlessws_link1}${tratls_link1}"
        yellow "---------------------------------------------------------"

    fi

    # Socks5 protocol output
    if grep -q "socks5-sb" "$SINGBOX_FOLDER_PATH/sb.json"; then
        port_socks5=$(jq -r '.inbounds[] | select(.tag == "socks5-sb") | .listen_port' "$SINGBOX_FOLDER_PATH/sb.json")
        socks5_username=$(jq -r '.inbounds[] | select(.tag == "socks5-sb") | .users[0].username' "$SINGBOX_FOLDER_PATH/sb.json")
        socks5_password=$(jq -r '.inbounds[] | select(.tag == "socks5-sb") | .users[0].password' "$SINGBOX_FOLDER_PATH/sb.json")

        socks5_user_enc=$(url_encode_component "$socks5_username")
        socks5_pass_enc=$(url_encode_component "$socks5_password")
        socks5_link="socks5://${socks5_user_enc}:${socks5_pass_enc}@${server_ip}:${port_socks5}#$(node_frag "${sxname}socks5-${hostname}")"
        yellow "🧦【 Socks5 】(此协议请不要直接在客户端里直连使用)"
        green "$socks5_link"
        local _wl_flag_val=""
        [ -s "$SINGBOX_FOLDER_PATH/socks5_wl_flag" ] && _wl_flag_val=$(cat "$SINGBOX_FOLDER_PATH/socks5_wl_flag" | tr -d '\r\n')
        if is_true "$_wl_flag_val"; then
            local _wl_ips_val=""
            [ -s "$SINGBOX_FOLDER_PATH/socks5_ips" ] && _wl_ips_val=$(cat "$SINGBOX_FOLDER_PATH/socks5_ips" | tr -d '\r\n')
            if [ -n "$_wl_ips_val" ]; then
                yellow "   ↳ 入站白名单已开启(防火墙规则)，仅允许: ${_wl_ips_val}"
            else
                yellow "   ↳ 入站白名单已开启（IP列表为空，等同于关闭）"
            fi
        else
            yellow "   ↳ 入站白名单未开启，所有IP均可访问"
        fi
        append_jh " "
        append_jh "$socks5_link"
        echo
    fi

    update_subscription_file

    # jh.txt 内含全部节点口令，收紧权限
    chmod 600 "$SINGBOX_FOLDER_PATH/jh.txt" 2>/dev/null || true
}

# SNI/端口等配置修改后统一调用：先刷新订阅，最后重启 sing-box 使新配置生效
refresh_sb_and_sub() {
    regenerate_links_and_sub
    sbrestart
}

cleanup_nginx() {

    # 清理 nginx
    pkill -15 nginx > /dev/null 2>&1
    rm -f "$(nginx_conf_path)" 2> /dev/null

    # 禁用 nginx 自启（避免卸载后 nginx 仍然起来）
    if has_systemd; then
        timeout 5 systemctl stop nginx > /dev/null 2>&1 || true
        systemctl disable nginx > /dev/null 2>&1
    elif command -v rc-service > /dev/null 2>&1; then
        timeout 5 rc-service nginx stop > /dev/null 2>&1 || true
        rc-update del nginx default > /dev/null 2>&1
    fi
    green "  ✓ Nginx 已清理（配置已删除，自启已禁用）"
}

# Remove singbox folder
cleandel() {
    local mode="${1:-del}"  # del（保留二进制）/ delall（全部删除）
    cd /root 2> /dev/null || cd "$HOME" 2> /dev/null || exit 1

    debug_print yellow "开始卸载sing-box/cloudflared流程..."

    # 定义要清理的文件夹列表（兼容旧路径和新路径）
    local folders_to_clean=(
        "$SINGBOX_FOLDER_PATH"
        "$OLD_SINGBOX_FOLDER"
    )

    # 杀死进程（兼容两个路径）
    white "  ▸ 终止进程..."
    pkill -15 -f "$SINGBOX_FOLDER_PATH/sing-box" 2> /dev/null
    pkill -15 -f "$SINGBOX_FOLDER_PATH/cloudflared" 2> /dev/null
    pkill -15 -f "$OLD_SINGBOX_FOLDER/sing-box" 2> /dev/null
    pkill -15 -f "$OLD_SINGBOX_FOLDER/cloudflared" 2> /dev/null
    green "  ✓ 进程已终止"

    # 处理 crontab，兼容 Debian 和 Alpine
    white "  ▸ 清理定时任务..."
    # 用 mktemp 避免固定路径 /tmp/crontab.tmp 被本地用户 symlink 劫持
    local ct_tmp
    ct_tmp="$(mktemp /tmp/crontab.XXXXXX 2> /dev/null)" || ct_tmp="/tmp/crontab.tmp.$$"
    crontab -l > "$ct_tmp" 2> /dev/null || : > "$ct_tmp"
    sed -i '/.*singbox.*/d' "$ct_tmp"
    sed -i '/.*agsb.*/d' "$ct_tmp"
    crontab "$ct_tmp" > /dev/null 2>&1
    rm -f "$ct_tmp"

    # 删除快捷命令（兼容两个名称）
    if [ -d "$HOME/bin/singbox" ]; then
        rm -rf "$HOME/bin/singbox"
    fi
    if [ -d "$HOME/bin/agsb" ]; then
        rm -rf "$HOME/bin/agsb"
    fi

    # 删除软链接（兼容两个名称）
    rm -f "$HOME/.local/bin/singbox" 2> /dev/null
    rm -f "$HOME/.local/bin/agsb" 2> /dev/null
    rm -f "/usr/local/bin/singbox" 2> /dev/null
    rm -f "/usr/local/bin/agsb" 2> /dev/null
    rm -f "/usr/bin/singbox" 2> /dev/null
    rm -f "/usr/bin/agsb" 2> /dev/null

    if has_systemd; then
        white "  ▸ 停止系统服务..."
        for svc in sb argo singbox-service agsb-singbox; do
            timeout 5 systemctl stop "$svc" > /dev/null 2>&1 || true
            systemctl disable "$svc" > /dev/null 2>&1
        done
        rm -f /etc/systemd/system/{sb.service,argo.service,singbox-service.service,agsb-singbox.service}
        systemctl daemon-reload > /dev/null 2>&1
        green "  ✓ 系统服务已停止并清理"
    elif command -v rc-service > /dev/null 2>&1; then
        white "  ▸ 停止 OpenRC 服务..."
        for svc in sing-box argo singbox agsb-singbox; do
            timeout 5 rc-service "$svc" stop > /dev/null 2>&1 || true
            rc-update del "$svc" default > /dev/null 2>&1
        done
        rm -f /etc/init.d/{sing-box,argo,singbox,agsb-singbox}
        green "  ✓ OpenRC 服务已停止并清理"
    fi

    # 清理 nginx
    white "  ▸ 清理 Nginx..."
    cleanup_nginx

    # 清理本脚本添加的 iptables/ip6tables 规则
    white "  ▸ 清理防火墙规则..."
    flush_singbox_iptables_rules
    _save_iptables_rules
    green "  ✓ 防火墙规则已清理"

    # 清理文件夹
    white "  ▸ 清理配置文件..."
    for folder in "${folders_to_clean[@]}"; do
        if [ -d "$folder" ]; then
            if [ "$mode" = "delall" ]; then
                debug_print yellow "正在删除（全部）：$folder"
                rm -rf "$folder" 2> /dev/null && green "✅ 已删除：$folder" || red "❌ 删除失败：$folder"
            else
                debug_print yellow "正在清理配置（保留 sing-box/cloudflared 二进制）：$folder"
                for item in "$folder"/*; do
                    [ -e "$item" ] || continue
                    case "$(basename "$item")" in
                        sing-box|cloudflared|logs) continue ;;
                        *) rm -rf "$item" 2>/dev/null ;;
                    esac
                done
                green "✅ 已清理配置：${folder}（二进制已保留）"
            fi
        fi
    done

    white "  ▸ 清理快捷命令..."
    cleanup_sb_shortcut
    cleanup_singbox_shortcut

    green "✅ 卸载完成"

}

# 旧版日志迁移：doraemon 根目录下的散落日志移动到 logs/ 目录（同分区 mv，systemd 打开的句柄不受影响）
migrate_logs_dir() {
    [ -d "$SINGBOX_FOLDER_PATH" ] || return 0
    mkdir -p "$LOGS_DIR" 2> /dev/null || return 0
    local f
    for f in singbox.log argo.log install.log deps_failed.log; do
        if [ -s "$SINGBOX_FOLDER_PATH/$f" ] && [ ! -s "$LOGS_DIR/$f" ]; then
            mv -f "$SINGBOX_FOLDER_PATH/$f" "$LOGS_DIR/$f" 2> /dev/null
        fi
    done
}

# Restart sing-box
sbrestart() {
    if has_systemd; then
        # systemd 管理：直接 restart，不要手动 pkill
        # 手动 pkill 会导致进程脱离 cgroup 管理，systemd stop 时找不到进程 → 状态标记 failed → start 被拒绝
        systemctl restart sb
    elif command -v rc-service > /dev/null 2>&1; then
        rc-service sing-box restart
    else
        pkill -15 -f "$SINGBOX_FOLDER_PATH/sing-box" 2> /dev/null
        nohup "$SINGBOX_FOLDER_PATH/sing-box" run -c "$SINGBOX_FOLDER_PATH/sb.json" > /dev/null 2>&1 &
    fi
}

# Restart argo
argorestart() {
    # ===============================
    # systemd 管理：直接 restart，不要手动 pkill（同 sbrestart 原理）
    # ===============================
    if has_systemd; then
        systemctl restart argo
        return
    fi

    # ===============================
    # openrc 管理
    # ===============================
    # ===============================
    if command -v rc-service > /dev/null 2>&1; then
        rc-service argo restart
        return
    fi

    # ===============================
    # 无 init 系统（nohup 启动）
    # 判断顺序非常重要！
    # ===============================
    pkill -15 -f "$SINGBOX_FOLDER_PATH/cloudflared" 2> /dev/null

    # 1️⃣ JSON 固定隧道（最高优先级）
    if [ -f "$SINGBOX_FOLDER_PATH/tunnel.yml" ]; then
        nohup "$SINGBOX_FOLDER_PATH/cloudflared" tunnel \
            --edge-ip-version auto \
            --config "$SINGBOX_FOLDER_PATH/tunnel.yml" run \
            > /dev/null 2>&1 &
        return
    fi

    # 2️⃣ token 固定隧道
    if [ -f "$SINGBOX_FOLDER_PATH/sbargotoken" ]; then
        nohup "$SINGBOX_FOLDER_PATH/cloudflared" tunnel \
            --no-autoupdate \
            --edge-ip-version auto run \
            --token "$(cat "$SINGBOX_FOLDER_PATH/sbargotoken")" \
            > /dev/null 2>&1 &
        return
    fi

    # 3️⃣ 临时 Argo（trycloudflare）
    if [ -f "$SINGBOX_FOLDER_PATH/argoport" ]; then
        mkdir -p "$LOGS_DIR" 2> /dev/null
        nohup "$SINGBOX_FOLDER_PATH/cloudflared" tunnel \
            --url "http://localhost:$(cat "$SINGBOX_FOLDER_PATH/argoport")" \
            --edge-ip-version auto \
            --no-autoupdate \
            > "$LOGS_DIR/argo.log" 2>&1 &
    fi
}

# ================== 脚本安装日志（仅保留最近一次安装） ==================
# 原理：终端输出完全不经过管道/重定向（apt/wget 等子进程照常识别终端，保持原生实时刷新），
# 由颜色打印函数和 echo 在输出时把纯文本同步追加写入安装日志。

INSTALL_LOGGING=0 # 安装日志记录开关（run_install_logged 安装期间置 1）

# 追加一行纯文本到安装日志（未开启时静默跳过）
_SUPPRESS_LOG=0 # 临时抑制日志写入（menu_status_block 等场景）
# 用纯 bash 正则剥离可能嵌套进来的 ANSI 颜色码（如 $(green ...) 拼接场景），无外部依赖、各平台行为一致
_log_write() {
    [ "${INSTALL_LOGGING}" = "1" ] || return 0
    [ "${_SUPPRESS_LOG}" = "1" ] && return 0
    local _s="$*" _re=$'\033\\[[0-9;?]*[A-Za-z]'
    while [[ "$_s" =~ $_re ]]; do
        _s="${_s/"${BASH_REMATCH[0]}"/}"
    done
    printf '%s\n' "$_s" >> "$INSTALL_LOG" 2> /dev/null
    return 0
}

# 接管内建 echo：终端照常显示，安装期间同时写入日志
# 只在 stdout 为终端时写入日志，避免 echo "$var" > file 产生脏记录
echo() {
    case "$1" in
        -n | -e | -E | -ne | -en)
            command echo "$@"
            ;;
        *)
            command echo "$@"
            [ -t 1 ] && _log_write "$*"
            ;;
    esac
}

# 清空旧日志并写入头部
install_log_begin() {
    mkdir -p "$LOGS_DIR" 2> /dev/null
    : > "$INSTALL_LOG" 2> /dev/null
    {
        echo "==================================================="
        echo " Sing-box 脚本安装日志（每次安装覆盖重写）"
        echo " 模式    : $1"
        echo " 版本    : $VERSION"
        echo " 开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "==================================================="
    } >> "$INSTALL_LOG" 2> /dev/null
}

# 收尾：终端打印结束标记并写入日志
install_log_end() {
    local _rc="$1"
    INSTALL_LOGGING=0
    yellow "===== 安装流程结束（退出码 ${_rc}） $(date '+%Y-%m-%d %H:%M:%S') ====="
    {
        echo ""
        echo "===== 安装流程结束（退出码 ${_rc}） $(date '+%Y-%m-%d %H:%M:%S') ====="
        echo ""
    } >> "$INSTALL_LOG" 2> /dev/null
}

# 包装器：run_install_logged <模式说明> <安装函数名>...
# 直接执行安装函数（无管道无子壳），失败时沿用原行为退出整个脚本
run_install_logged() {
    local _label="$1"; shift
    local _rc
    INSTALL_LOGGING=0
    install_log_begin "$_label"
    INSTALL_LOGGING=1
    "$@"
    _rc=$?
    if [ "$_rc" -ne 0 ]; then
        install_log_end "$_rc"
        exit "$_rc"
    fi
    green "📜 本次安装日志已保存：$INSTALL_LOG （菜单[10]-4 可查看）"
    install_log_end 0
}

install_step() {
    echo "VPS系统：$op"
    echo "CPU架构：$cpu"
    echo "Singbox脚本开始安装/更新…………" && sleep 1

    # 获取操作系统名称
    os_name=$(awk -F= '/^NAME/{print $2}' /etc/os-release)

    debug_log "【调试】开始安装各种乱七八糟的依赖"
    install_deps

    debug_log "【调试】安装各种乱七八糟的依赖完成"

    # ⚠️ SELinux 处理：仅在 SELinux 处于 Enforcing 时才临时禁用它，并明确提示用户（不写入配置文件）
    if command -v getenforce > /dev/null 2>&1 && [ "$(getenforce 2>/dev/null)" = "Enforcing" ]; then
        yellow "⚠️ 检测到 SELinux 为 Enforcing，为兼容 sing-box 端口绑定，本脚本将临时执行 setenforce 0"
        yellow "   （仅本次生效，重启后恢复；如不希望关闭请先自行处理 SELinux 策略）"
        setenforce 0 > /dev/null 2>&1 || red "⚠️ setenforce 0 执行失败，请手动处理 SELinux，否则端口可能被拦截"
    fi
    flush_singbox_iptables_rules

    _save_iptables_rules
    debug_print echo "覆盖安装：已清除旧防火墙规则并保存当前状态"
    ins
    green "Singbox脚本安装完成！即将打印节点信息……"
    # 显示节点信息 这里的key是一个定值，为了打印私钥
    cip "key"
}

# ================== 端口冲突检测（subscribe=true 或 need_argo 才检查 nginx_pt/argo_pt） ==================
check_port_conflicts_or_exit() {
    _is_port_int() {
        [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]
    }

    # subscribe 优先读落盘值，保持一致
    local subscribe_val
    subscribe_val=$(get_subscribe_flag)

    # ✅ 在函数内部计算"有效端口"（不修改全局变量）
    #  ❗ argo_pt 默认 8001；nginx_pt 默认 8080
    #  ❗ :- 不会发生"把 argo_pt 默认值写进去"的副作用；只有 := 才会。
    local argo_eff="${argo_pt:-8001}"
    local nginx_eff="${nginx_pt:-8080}"
    local need_nginx=false
    if is_true "$subscribe_val" || need_argo; then
        need_nginx=true
    fi

    # ✅ 规则：需要 Nginx 时 argo_pt 和 nginx_pt 不能同时为 8001（按有效端口判断）
    if $need_nginx && [[ "$argo_eff" == "8001" && "$nginx_eff" == "8001" ]]; then
        echo
        red "❌ 端口冲突：argo_pt 和 nginx_pt 不能同时等于 8001"
        yellow "原因：由于 8001 作为 argo_pt 的内部默认值（nginx_pt 默认 8080），因此不要把 nginx_pt 也设成 8001"
        yellow "当前值：argo_pt=${argo_eff} | nginx_pt=${nginx_eff}"
        echo
        exit 1
    fi

    # 固定检查协议端口；subscribe=true 时才额外检查 nginx_pt
    local vars="vmpt vlpt trpt vlrt hypt tupt anypt socks5pt"
    if $need_nginx; then
        vars="$vars argo_pt nginx_pt"
    fi

    declare -A used # port -> "name=value, name=value..."
    local has_conflict=0

    local k v
    for k in $vars; do
        if [[ "$k" == "nginx_pt" ]]; then
            v="$nginx_eff" # 用有效默认值参与检查，但不改 nginx_pt 本身
        elif [[ "$k" == "socks5pt" ]]; then
            v="$port_socks5" # socks5pt= 且 PORT=xxx 时，用实际端口参与检查
        else
            v="${!k}" # 动态取值：协议端口
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

    # ⚠️ 系统已监听端口检测（非阻断，仅提示）：ss 可用时，确认端口没被其他进程占用
    #     本脚本栈自带的 sing-box/cloudflared/nginx 监听不算冲突（rep 覆盖安装前旧实例还在，马上会被清理）
    if command -v ss > /dev/null 2>&1; then
        local p_check _tcp _udp
        for p_check in "${!used[@]}"; do
            _tcp="$(ss -ltnp 2>/dev/null | grep -E "[:.]${p_check} " | head -n1)"
            _udp="$(ss -ulnp 2>/dev/null | grep -E "[:.]${p_check} " | head -n1)"
            [ -z "$_tcp" ] && [ -z "$_udp" ] && continue
            if [ -n "$_tcp" ] && printf '%s' "$_tcp" | grep -qE 'sing-box|cloudflared|nginx'; then _tcp=""; fi
            if [ -n "$_udp" ] && printf '%s' "$_udp" | grep -qE 'sing-box|cloudflared|nginx'; then _udp=""; fi
            [ -z "$_tcp" ] && [ -z "$_udp" ] && continue
            yellow "⚠️ 端口 ${p_check}（${used[$p_check]}）当前已被其他进程监听，安装后可能无法绑定"
        done
    fi
}
# ================== 端口冲突检测 END ================

# ================== 交互式菜单模式 ==================
# 与命令行非交互模式共存：带参数走原逻辑，无参数或 menu 命令进入交互菜单

reading() {
    read -r -p "$(yellow "$1")" "$2"
}

# 静默输入（用于 token / 密码 / 私钥，防终端回显与 shoulder-surfing）
reading_secret() {
    read -r -s -p "$(yellow "$1")" "$2"
    echo >&2
}

is_installed_sb() {
    pgrep -f "$SINGBOX_FOLDER_PATH/sing-box" > /dev/null 2>&1 \
        || [ -x "$SINGBOX_FOLDER_PATH/sing-box" ] \
        || [ -s "$SINGBOX_FOLDER_PATH/sb.json" ]
}

menu_pause() {
    reading "按回车返回菜单..." _
}

# 捕获服务停止原因并写入日志
# 参数：服务名（sb/argo）+ 可选 "quiet" 静默模式（不打印提示）
capture_stop_reason() {
    local svc="${1:-sb}" quiet="${2:-}" stop_log="$LOGS_DIR/stop_reason.log"
    mkdir -p "$LOGS_DIR" 2>/dev/null

    local ts reason oom_info log_err
    ts=$(date '+%Y-%m-%d %H:%M:%S')

    # 1) journalctl 最近日志（含 exit code）
    reason=""
    if command -v journalctl > /dev/null 2>&1; then
        reason=$(journalctl -u "$svc" --no-pager -n 20 --since "10 min ago" 2>/dev/null)
    fi

    # 2) OOM killer
    oom_info=""
    if command -v dmesg > /dev/null 2>&1; then
        oom_info=$(dmesg 2>/dev/null | grep -iE "oom|killed process|out of memory" | tail -5)
    fi

    # 3) sing-box / argo 自身日志最后的 error/fatal 行
    log_err=""
    local _app_log="$LOGS_DIR/singbox.log"
    [ "$svc" = "argo" ] && _app_log="$LOGS_DIR/argo.log"
    if [ -s "$_app_log" ]; then
        log_err=$(grep -iE "fatal|error|panic|fail|segfault" "$_app_log" 2>/dev/null | tail -10)
    fi

    # 5 分钟内已记录过则跳过（避免每次刷新菜单重复写入）
    local _dedup="$LOGS_DIR/.stop_reason_${svc}_ts"
    if [ -f "$_dedup" ]; then
        local _last _now _diff
        _last=$(cat "$_dedup" 2>/dev/null)
        _now=$(date +%s)
        _diff=$((_now - _last))
        [ "$_diff" -lt 300 ] && return 0
    fi
    date +%s > "$_dedup" 2>/dev/null
    if [ -n "$reason" ] || [ -n "$oom_info" ] || [ -n "$log_err" ]; then
        {
            echo "========================================"
            echo "检测时间: $ts | 服务: $svc"
            [ -n "$reason" ]   && echo "--- journalctl -u $svc ---" && echo "$reason"
            [ -n "$oom_info" ] && echo "--- OOM Killer ---"         && echo "$oom_info"
            [ -n "$log_err" ]  && echo "--- 应用日志 ---"           && echo "$log_err"
            echo ""
        } >> "$stop_log" 2>/dev/null

        [ "$quiet" != "quiet" ] && yellow "⚠️ 已记录 $svc 停止原因 → $stop_log"
    fi
}

# 主菜单状态：sing-box / cloudflared / Argo / nginx（状态 + 具体版本）
# 绿●运行中 / 红■已停止 / 黄○未安装 / 紫○未启用
menu_status_block() {
    local _old_suppress="$_SUPPRESS_LOG"
    _SUPPRESS_LOG=1
    local sub_flag argo_needed st_sb st_cf v_sb v_cf v_nginx
    sub_flag="$(get_subscribe_flag)"
    argo_needed=false
    need_argo && argo_needed=true

    # sing-box
    v_sb=""
    if [ -x "$SINGBOX_FOLDER_PATH/sing-box" ]; then
        local _ver
        _ver=$("$SINGBOX_FOLDER_PATH/sing-box" version 2> /dev/null | head -1 | sed -n 's/.*\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p')
        [ -n "$_ver" ] && v_sb="V$_ver"
    fi
    if pgrep -f "$SINGBOX_FOLDER_PATH/sing-box" > /dev/null 2>&1; then
        st_sb="$(green "● 运行中")"
    elif [ -n "$v_sb" ]; then
        st_sb="$(red "■ 已停止")"
        capture_stop_reason sb quiet 2>/dev/null
    else
        st_sb="$(yellow "○ 未安装")"
    fi

    # cloudflared
    v_cf=""
    if [ -x "$SINGBOX_FOLDER_PATH/cloudflared" ]; then
        local _ver
        _ver=$("$SINGBOX_FOLDER_PATH/cloudflared" version 2> /dev/null | sed -n 's/.*version \([0-9]\{4\}\.[0-9]\+\.[0-9]\+\).*/\1/p')
        [ -n "$_ver" ] && v_cf="V$_ver"
    elif command -v cloudflared > /dev/null 2>&1; then
        local _ver
        _ver=$(cloudflared version 2> /dev/null | sed -n 's/.*version \([0-9]\{4\}\.[0-9]\+\.[0-9]\+\).*/\1/p')
        [ -n "$_ver" ] && v_cf="V$_ver"
    fi
    if [ -x "$SINGBOX_FOLDER_PATH/cloudflared" ] || command -v cloudflared > /dev/null 2>&1; then
        if pgrep -f "$SINGBOX_FOLDER_PATH/cloudflared" > /dev/null 2>&1; then
            st_cf="$(green "● 运行中")"
        else
            st_cf="$(red "■ 已停止")"
            capture_stop_reason argo quiet 2>/dev/null
        fi
    else
        st_cf="$(yellow "○ 未安装")"
    fi

    # nginx
    v_nginx=""
    local st_nginx=""
    if command -v nginx > /dev/null 2>&1; then
        local _ver
        _ver=$(nginx -v 2>&1 | sed -n 's/.*nginx\/\([0-9.]*\).*/\1/p')
        [ -n "$_ver" ] && v_nginx="V$_ver"
    fi
    if ps aux | grep -v grep | grep -q nginx; then
        st_nginx="$(green "● 运行中")"
    elif command -v nginx > /dev/null 2>&1; then
        st_nginx="$(red "■ 已停止")"
    else
        st_nginx="$(yellow "○ 未安装")"
    fi
    # 订阅细分：订阅开启/未开启 + 端口
    local sub_desc nginx_port
    if is_true "$sub_flag"; then
        sub_desc="✅ $(green "订阅已开启")"
    else
        sub_desc="⛔ $(purple "订阅未开启")"
    fi
    nginx_port="${nginx_pt:-$NGINX_DEFAULT_PORT}"
    [ -s "$SINGBOX_FOLDER_PATH/nginx_port" ] && nginx_port="$(cat "$SINGBOX_FOLDER_PATH/nginx_port" 2> /dev/null)"
    _SUPPRESS_LOG="$_old_suppress"

    green "  Sing-box    : $st_sb   $v_sb"
    green "  Cloudflared : $st_cf   $v_cf"
    # Argo 状态行（色值与 Nginx 一致：紫○未启用 / 黄○未安装 / 绿●运行中 / 红■已停止，均带端口）
    local argo_port
    argo_port="${argo_pt:-$ARGO_DEFAULT_PORT}"
    if ! $argo_needed; then
        local st_argo_off="$(purple "○ 未启用")"
        green "  Argo        : ${st_argo_off}（当前场景无需 Argo，端口：${argo_port}）"
    elif [ -x "$SINGBOX_FOLDER_PATH/cloudflared" ] || command -v cloudflared > /dev/null 2>&1; then
        if pgrep -f "$SINGBOX_FOLDER_PATH/cloudflared" > /dev/null 2>&1; then
            green "  Argo        : ${st_cf}（端口：${argo_port}）"
        else
            green "  Argo        : ${st_cf}（已启用 Argo，端口：${argo_port}）"
        fi
    else
        local st_argo_miss="$(yellow "○ 未安装")"
        green "  Argo        : ${st_argo_miss}（已启用 Argo，端口：${argo_port}）"
    fi
    if ! $argo_needed && ! is_true "$sub_flag"; then
        green "  Nginx       : $(purple "○ 未启用（订阅未开启，无需）")"
    elif ! command -v nginx > /dev/null 2>&1; then
        green "  Nginx       : ${st_nginx}（${sub_desc}，端口：${nginx_port}）"
    elif ps aux | grep -v grep | grep -q nginx; then
        green "  Nginx       : ${st_nginx}${v_nginx:+ $v_nginx}（${sub_desc}，端口：${nginx_port}）"
    else
        green "  Nginx       : ${st_nginx}（${sub_desc}，端口：${nginx_port}）"
    fi
}

# 根据 *pt 环境变量重新推导协议开关与端口变量（交互模式设置环境变量后调用）
menu_reload_proto_flags() {
    trp=; vmag=; hyp=; vmp=; vlp=; vlr=; tup=; anyp=; socksp=
    [ -n "${trpt+x}" ] && { trp=yes; vmag=yes; }
    [ -n "${hypt+x}" ] && hyp=yes
    [ -n "${vmpt+x}" ] && { vmp=yes; vmag=yes; }
    [ -n "${vlpt+x}" ] && { vlp=yes; vmag=yes; }
    [ -n "${vlrt+x}" ] && vlr=yes
    [ -n "${tupt+x}" ] && tup=yes
    [ -n "${anypt+x}" ] && anyp=yes
    [ -n "${socks5pt+x}" ] && socksp=yes
    export trp hyp vmp vlp vlr tup anyp socksp vmag
    # 重新绑定端口变量（与文件顶部一致）
    export port_vm_ws=${vmpt:-''} port_vl_ws=${vlpt:-''} port_tr=${trpt:-''} port_hy2=${hypt:-''} \
           port_vlr=${vlrt:-''} port_tu=${tupt:-''} port_any=${anypt:-''} \
           port_socks5=${socks5pt:-''}
}

# 读取端口；空则返回空（表示随机生成）
menu_ask_port() {
    local _proto="$1" _def="$2" _in="" _rp=""
    while true; do
        reading "  请输入 ${_proto} 监听端口 (回车=${_def:-随机}): " _in
        if [ -z "$_in" ]; then
            if [ -n "$_def" ]; then
                green "  ↳ ${_proto} 端口: ${_def} (默认)" >&2
                echo "" >&2
                echo "$_def"
            else
                _rp="$(rand_port)"
                green "  ↳ ${_proto} 端口: ${_rp} (随机)" >&2
                echo "" >&2
                echo "$_rp"
            fi
            return 0
        fi
        if [[ "$_in" =~ ^[0-9]+$ ]] && [ "$_in" -ge 1 ] && [ "$_in" -le 65535 ]; then
            green "  ↳ ${_proto} 端口: ${_in}" >&2
            echo "" >&2
            echo "$_in"
            return 0
        fi
        red "  ❌ 端口无效 (1-65535)，请重新输入" >&2
        echo "" >&2
    done
}

# 交互收集安装参数并设置环境变量
# 查询 out_ip 的地区（优先本地 .geo_out 缓存，未命中才查 ip-api.com 并写回缓存）
query_ip_region() {
    local _ip="$1" _json _region _rn _ci
    _region="$(awk -F= -v ip="$_ip" '$1==ip{print $2}' "$GEO_OUT_FILE" 2>/dev/null | tail -n1)"
    [ -n "$_region" ] && { echo "$_region"; return 0; }
    _json="$(curl -s -m5 "http://ip-api.com/json/${_ip}?fields=status,country,regionName,city" 2>/dev/null)"
    case "$_json" in
        *'"status":"success"'*)
            _region="$(printf '%s' "$_json" | sed -nE 's/.*"country":"([^"]*)".*/\1/p')"
            [ -z "$_region" ] && return 1
            _rn="$(printf '%s' "$_json" | sed -nE 's/.*"regionName":"([^"]*)".*/\1/p')"
            _ci="$(printf '%s' "$_json" | sed -nE 's/.*"city":"([^"]*)".*/\1/p')"
            [ -n "$_rn" ] && [ "$_rn" != "$_region" ] && _region="$_region $_rn"
            [ -n "$_ci" ] && [ "$_ci" != "$_rn" ] && _region="$_region $_ci"
            geo_set_out "$_ip" "$_region"
            echo "$_region"
            ;;
    esac
    return 0
}

menu_collect_install() {
    local _ans _ch _sel _has_all _has_vmess _has_trojan

    echo ""
    purple "===== 日志调试 ====="
    yellow "  仅用于安装时日志调试，默认关闭"
    reading "是否开启日志调试? [y/N]: " _ans
    if [ "$_ans" = "y" ] || [ "$_ans" = "Y" ]; then
        export DEBUG_FLAG="1"
        green "  ↳ 日志调试: 开启"
    else
        export DEBUG_FLAG="0"
        green "  ↳ 日志调试: 关闭 (默认)"
    fi

    purple "===== 基础设置 ====="
    reading "IP偏好 [4=仅IPv4 / 6=仅IPv6 / 回车=自动]: " _ans
    if [ "$_ans" = "4" ] || [ "$_ans" = "6" ]; then
        export ippz="$_ans"
        green "  ↳ IP偏好: 仅IPv${_ans}"
    else
        green "  ↳ IP偏好: 自动 (默认)"
    fi

    # 服务器 IP 确认：检测并回显（地区为全局预取缓存），若与预期不符可输入 out_ip
    echo ""
    purple "===== 服务器 IP 确认 ====="
    local _ipres _ipv4 _ipv6 _use_ip _use_label _v4dq _v6dq
    _ipres="$(check_ip_connectivity "${v46url:-https://icanhazip.com}")"
    _ipv4="$(printf '%s' "${_ipres%%|*}" | tr -d '\r\n')"
    _ipv6="$(printf '%s' "${_ipres##*|}" | tr -d '\r\n')"
    _v4dq="$(geo_get_ip "$_ipv4")"
    _v6dq="$(geo_get_ip "$_ipv6")"
    [ -z "$_v4dq" ] && _v4dq="未知"
    [ -z "$_v6dq" ] && _v6dq="未知"
    if [ "$ippz" = "6" ]; then
        green "  ↳ 检测到 IPv4: ${_ipv4:-无} (${_v4dq}) / IPv6: ${_ipv6:-无} (${_v6dq})"
        _use_ip="$_ipv6"; _use_label="ipv6"
    elif [ "$ippz" = "4" ]; then
        green "  ↳ 检测到 IPv4: ${_ipv4:-无} (${_v4dq}) / IPv6: ${_ipv6:-无} (${_v6dq})"
        _use_ip="$_ipv4"; _use_label="ipv4"
    else
        green "  ↳ 检测到 IPv4: ${_ipv4:-无} (${_v4dq}) / IPv6: ${_ipv6:-无} (${_v6dq})"
        if [ -n "$_ipv4" ]; then
            _use_ip="$_ipv4"; _use_label="ipv4"
        elif [ -n "$_ipv6" ]; then
            _use_ip="$_ipv6"; _use_label="ipv6"
        else
            _use_ip=""; _use_label=""
        fi
    fi
    if [ -n "$_use_ip" ]; then
        green "  ↳ 你将使用 ${_use_label}(${_use_ip}) 作为出口 IP"
        reading "  请留空回车直接使用当前出口 IP (${_use_ip})；如需特殊 IP 作为出口，请输入 IP: " _ans
    else
        yellow "  ↳ 未检测到可用出口 IP"
        reading "  请手动输入出口 IP (回车=稍后自动检测): " _ans
    fi
    if [ -n "$_ans" ]; then
        export out_ip="$_ans"
        local _odq
        _odq="$(query_ip_region "$_ans" 2>/dev/null)"
        green "  ↳ 使用自定义 IP (out_ip): ${_ans} (${_odq:-未知})"
    else
        green "  ↳ 使用检测到的 IP: ${_use_ip}"
    fi

    reading "UUID (回车自动生成): " _ans
    if [ -n "$_ans" ]; then
        export uuid="$_ans"
        green "  ↳ UUID: ${_ans}"
    else
        local _g
        _g="$(gen_uuid)"
        export uuid="$_g"
        green "  ↳ UUID: ${_g} (自动生成)"
    fi

    echo ""
    purple "===== 选择要安装的直连协议 (可多选，空格或逗号分隔) ====="
    green "  b) VLESS-Reality-Vision"
    green "  c) Hysteria2"
    green "  d) TUIC"
    green "  e) AnyTLS"
    reading "输入选项 (回车默认=全部直连协议 b c d e): " _ch
    [ -z "$_ch" ] && _ch="b c d e"
    _ch="$(printf '%s' "$_ch" | tr ',' ' ' | tr '[:upper:]' '[:lower:]')"
    local _names=""
    for _sel in $_ch; do
        case "$_sel" in
            b) _names="$_names,VLESS" ;;
            c) _names="$_names,Hysteria2" ;;
            d) _names="$_names,TUIC" ;;
            e) _names="$_names,AnyTLS" ;;
        esac
    done
    green "  ↳ 直连协议: ${_ch} (${_names#,})"

    # Argo 隧道协议：三选一或选零
    echo ""
    purple "===== 选择 Argo 隧道协议 (三选一，回车=不选) ====="
    green "  f) Vmess-WS-TLS"
    green "  g) Trojan-WS-TLS"
    green "  v) Vless-WS-TLS"
    reading "输入选项 (回车=不选): " _ans
    _ans="$(printf '%s' "$_ans" | tr '[:upper:]' '[:lower:]')"
    case "$_ans" in
        *g*) _ch="$_ch g"; green "  ↳ Argo 协议: Trojan-WS-TLS" ;;
        *v*) _ch="$_ch v"; green "  ↳ Argo 协议: Vless-WS-TLS" ;;
        *f*) _ch="$_ch f"; green "  ↳ Argo 协议: Vmess-WS-TLS" ;;
        *) : ; green "  ↳ Argo 协议: 不选 (默认)" ;;
    esac

    # Socks5 协议：可要可不要
    echo ""
    purple "===== Socks5 协议 (可要可不要) ====="
    reading "是否安装 Socks5? [y/N] (回车默认=不要): " _ans
    case "$_ans" in
        y|Y) _ch="$_ch h"; green "  ↳ Socks5: 安装" ;;
        *) : ; green "  ↳ Socks5: 不安装 (默认)" ;;
    esac

    # 标记选中的协议（空值=随机端口，先只做启用标记）
    for _sel in $_ch; do
        case "$_sel" in
            b) export vlrt="" ;;
            c) export hypt="" ;;
            d) export tupt="" ;;
            e) export anypt="" ;;
            f) export vmpt="" ;;
            g) export trpt="" ;;
            v) export vlpt="" ;;
            h) export socks5pt="" ;;
            *) yellow "  跳过未知选项: $_sel" ;;
        esac
    done

    menu_reload_proto_flags

    # 端口设置：全部随机 或 逐个定制
    echo ""
    purple "===== 端口设置 ====="
    green "  1) 全部随机生成"
    green "  2) 逐个自定义端口 (推荐)"
    reading "输入选择 (回车默认=2): " _ans
    if [ -z "$_ans" ] || [ "$_ans" = "2" ]; then
        green "  ↳ 端口: 逐个自定义 (默认)"
        [ -n "$trp" ] && export trpt="$(menu_ask_port "Trojan-WS (Argo)")"
        [ -n "$vmp" ] && export vmpt="$(menu_ask_port "Vmess-WS (Argo)")"
        [ -n "$vlp" ] && export vlpt="$(menu_ask_port "Vless-WS (Argo)")"
        for _sel in vlr hyp tup anyp; do
            case "$_sel" in
                vlr)  [ -n "$vlr" ]  && export vlrt="$(menu_ask_port "VLESS-Reality")" ;;
                hyp)  [ -n "$hyp" ]  && export hypt="$(menu_ask_port "Hysteria2")" ;;
                tup)  [ -n "$tup" ]  && export tupt="$(menu_ask_port "TUIC")" ;;
                anyp) [ -n "$anyp" ] && export anypt="$(menu_ask_port "AnyTLS")" ;;
            esac
        done
        [ -n "$trp$vmp$vlp" ] && export argo_pt="$(menu_ask_port "Argo" 8001)"
    else
        green "  ↳ 端口: 全部随机生成"
        [ -n "$trp" ] && { trpt="$(rand_port)"; export trpt; green "  ↳ Trojan-WS (Argo) 端口: ${trpt} (随机)"; }
        [ -n "$vmp" ] && { vmpt="$(rand_port)"; export vmpt; green "  ↳ Vmess-WS (Argo) 端口: ${vmpt} (随机)"; }
        [ -n "$vlp" ] && { vlpt="$(rand_port)"; export vlpt; green "  ↳ Vless-WS (Argo) 端口: ${vlpt} (随机)"; }
        [ -n "$vlr" ] && { vlrt="$(rand_port)"; export vlrt; green "  ↳ VLESS-Reality 端口: ${vlrt} (随机)"; }
        [ -n "$hyp" ] && { hypt="$(rand_port)"; export hypt; green "  ↳ Hysteria2 端口: ${hypt} (随机)"; }
        [ -n "$tup" ] && { tupt="$(rand_port)"; export tupt; green "  ↳ TUIC 端口: ${tupt} (随机)"; }
        [ -n "$anyp" ] && { anypt="$(rand_port)"; export anypt; green "  ↳ AnyTLS 端口: ${anypt} (随机)"; }
        [ -n "$trp$vmp$vlp" ] && { argo_pt="${argo_pt:-8001}"; export argo_pt; green "  ↳ Argo 端口: ${argo_pt} (默认)"; }
    fi

    menu_reload_proto_flags

    # Argo 隧道配置（vmess/trojan/vless 已强制三选一，这里最多启用一个）
    if [ -n "$vmp" ]; then
        export argo=vmpt
    elif [ -n "$trp" ]; then
        export argo=trpt
    elif [ -n "$vlp" ]; then
        export argo=vlpt
    else
        export argo=""
    fi

    if [ -n "$argo" ]; then
        echo ""
        purple "===== Argo 隧道配置 ====="
        purple "选择 Argo 隧道类型:"
        green "  1) 临时隧道 (trycloudflare 免费域名)"
        green "  2) 固定隧道 (需要自己的域名 + Token/JSON)"
        reading "输入编号 (回车默认=2): " _ans
        if [ "$_ans" = "1" ]; then
            green "  ↳ Argo 隧道: 临时隧道"
        else
            green "  ↳ Argo 隧道: 固定隧道 (默认)"
            reading "  请输入 Argo 域名: " _ans
            [ -n "$_ans" ] && export ARGO_DOMAIN="$_ans"
            green "  ↳ Argo 域名: ${ARGO_DOMAIN:-未设置}"
            reading_secret "  请输入 Argo Token 或粘贴 JSON 凭据（输入不回显）: " _ans
            [ -n "$_ans" ] && export ARGO_AUTH="$_ans"
            green "  ↳ Argo Token/JSON: 已设置"
        fi
    fi

    # 订阅
    echo ""
    reading "是否开启节点订阅 [y/N]: " _ans
    if [ "$_ans" = "y" ] || [ "$_ans" = "Y" ]; then
        export subscribe=true
        green "  ↳ 订阅: 开启"
        reading "订阅服务端口 Nginx (回车默认=8080): " _ans
        if [ -n "$_ans" ]; then
            export nginx_pt="$_ans"
        else
            export nginx_pt=8080
        fi
        green "  ↳ 订阅端口: ${nginx_pt}"
    else
        green "  ↳ 订阅: 不开启 (默认)"
    fi

    # VLESS 才询问 reality_private
    if [ -n "$vlr" ]; then
        echo ""
        reading_secret "reality_private (回车=自动生成): " _ans
        if [ -n "$_ans" ]; then
            export reality_private="$_ans"
            green "  ↳ reality_private: 已输入"
        else
            local _rp
            _rp="$(gen_reality_private)"
            if [ -n "$_rp" ]; then
                export reality_private="$_rp"
                green "  ↳ reality_private: ${_rp} (自动生成)"
            else
                green "  ↳ reality_private: 自动生成 (默认)"
            fi
        fi
    fi

    # SNI / CDN 值设定
    echo ""
    purple "===== SNI / CDN 设置 ====="
    green "  1) 全部使用默认值(偷懒就用默认)"
    green "     默认值：CDN 优选域名=saas.sin.fan, CDN 端口=443(仅限 HTTPS 系端口 ${HTTPS_CDN_PORTS[*]}),"
    green "             Hysteria2 伪装域名=www.apple.com, VLESS 伪装域名=www.apple.com,"
    green "             VLESS 伪装端口=443, TUIC 伪装域名=www.apple.com"
    green "  2) 逐个展开单独设置（可自定义，推荐）"
    reading "输入选择 (回车默认=1): " _ans
    if [ "$_ans" = "2" ]; then
        green "  ↳ SNI/CDN: 逐个设置"
        reading "  CDN 优选域名 (默认=saas.sin.fan): " _ans
        [ -n "$_ans" ] && export cdn_host="$_ans"
        green "  ↳ CDN 优选域名: ${cdn_host:-saas.sin.fan}"
        yellow "  可选 CDN 优选端口(仅限 HTTPS 系端口)：${HTTPS_CDN_PORTS[*]}"
        reading "  CDN 端口 (默认=443): " _ans
        if [ -n "$_ans" ]; then
            local _p _cdn_ok=false
            for _p in "${HTTPS_CDN_PORTS[@]}"; do
                [ "$_ans" = "$_p" ] && { _cdn_ok=true; break; }
            done
            if $_cdn_ok; then
                export cdn_pt="$_ans"
                green "  ↳ CDN 端口: ${cdn_pt}"
            else
                yellow "  ❌ CDN 端口仅限 HTTPS 系端口 (${HTTPS_CDN_PORTS[*]})，已用默认 443"
                export cdn_pt="443"
                green "  ↳ CDN 端口: ${cdn_pt} (默认)"
            fi
        else
            green "  ↳ CDN 端口: ${cdn_pt:-443} (默认)"
        fi
        reading "  Hysteria2 伪装域名 (默认=www.apple.com): " _ans
        [ -n "$_ans" ] && export hy_sni="$_ans"
        green "  ↳ Hysteria2 伪装域名: ${hy_sni:-www.apple.com}"
        reading "  VLESS 伪装域名 (默认=www.apple.com): " _ans
        [ -n "$_ans" ] && export vl_sni="$_ans"
        green "  ↳ VLESS 伪装域名: ${vl_sni:-www.apple.com}"
        reading "  VLESS 伪装端口 (默认=443): " _ans
        [ -n "$_ans" ] && export vl_sni_pt="$_ans"
        green "  ↳ VLESS 伪装端口: ${vl_sni_pt:-443}"
        reading "  TUIC 伪装域名 (默认=www.apple.com): " _ans
        [ -n "$_ans" ] && export tu_sni="$_ans"
        green "  ↳ TUIC 伪装域名: ${tu_sni:-www.apple.com}"
    else
        green "  ↳ SNI/CDN: 全部使用默认值"
        green "  ↳ CDN 优选域名=${cdn_host:-saas.sin.fan}, CDN 端口=${cdn_pt:-443},"
        green "  ↳ Hysteria2 伪装域名=${hy_sni:-www.apple.com}, VLESS 伪装域名=${vl_sni:-www.apple.com},"
        green "  ↳ VLESS 伪装端口=${vl_sni_pt:-443}, TUIC 伪装域名=${tu_sni:-www.apple.com}"
    fi

    # 节点名称前缀（最后询问）
    echo ""
    reading "节点名称前缀 (回车跳过): " _ans
    if [ -n "$_ans" ]; then
        export name="$_ans"
        green "  ↳ 节点名称前缀: ${_ans}"
    else
        green "  ↳ 节点名称前缀: 跳过 (默认)"
    fi
}

menu_show_selection() {
    green "  ========== 将安装的协议 =========="
    [ -n "$vlr" ]    && green "    - VLESS-Reality-Vision"
    [ -n "$hyp" ]    && green "    - Hysteria2"
    [ -n "$tup" ]    && green "    - TUIC"
    [ -n "$anyp" ]   && green "    - AnyTLS"
    [ -n "$socksp" ] && green "    - Socks5"
    [ -n "$vmp" ]    && green "    - Vmess-WS-TLS (Argo)"
    [ -n "$vlp" ]    && green "    - Vless-WS-TLS (Argo)"
    [ -n "$trp" ]    && green "    - Trojan-WS-TLS (Argo)"
    echo ""
}

interactive_install() {
    local _ans
    # 已安装（进程在跑 / 有二进制 / 有配置）时禁止重复安装
    if pgrep -f "$SINGBOX_FOLDER_PATH/sing-box" > /dev/null 2>&1 \
       || [ -x "$SINGBOX_FOLDER_PATH/sing-box" ] \
       || [ -s "$SINGBOX_FOLDER_PATH/sb.json" ]; then
        red "⚠️ 已检测到 Sing-box 已安装，不能重复安装！"
        yellow "如需重新部署请使用一级菜单中的「覆盖式安装/重置」"
        sleep 2
        return
    fi
    while true; do
        clear
        green "========== [1] 交互式安装 Sing-box =========="
        menu_collect_install
        if ! any_proto_enabled; then
            red "❌ 未选择任何协议，请重新选择。"
            sleep 2
            continue
        fi
        menu_show_selection
        reading "设置完毕，即将生成配置并部署服务，确认继续? [Y/n]: " _ans
        if [ -z "$_ans" ] || [ "$_ans" = "y" ] || [ "$_ans" = "Y" ]; then
            break
        else
            red "已取消安装。"
            sleep 1
            return
        fi
    done

    check_port_conflicts_or_exit
    _install_menu_flow() {
        install_step
        green "✅ 安装完成！"
        sleep 2
    }
    run_install_logged "菜单[1] 交互式安装" _install_menu_flow
}

interactive_reinstall() {
    local _ans
    while true; do
        clear
        green "========== [2] 覆盖式安装 (重置) =========="
        yellow "将清理现有配置后重新安装，需要至少启用一个协议。"
        menu_collect_install
        if ! any_proto_enabled; then
            red "❌ 未选择任何协议，请重新选择。"
            sleep 2
            continue
        fi
        menu_show_selection
        reading "设置完毕，即将生成配置并部署服务，确认继续? [Y/n]: " _ans
        if [ -z "$_ans" ] || [ "$_ans" = "y" ] || [ "$_ans" = "Y" ]; then
            break
        else
            red "已取消。"
            sleep 1
            return
        fi
    done

    check_port_conflicts_or_exit
    _reinstall_menu_flow() {
        cleandel
        install_step
        green "✅ 覆盖式安装完成！"
        sleep 2
    }
    run_install_logged "菜单[2] 覆盖式安装(重置)（含卸载清理）" _reinstall_menu_flow
}

# ========== 服务管理（重启/更新内核/Nginx/状态） ==========
interactive_nginx_menu() {
    local _ch
    while true; do
        clear
        green "========= [3][3] Nginx 管理 ========="
        nginx_status
        echo ""
        green "  1) 启动 Nginx"
        green "  2) 停止 Nginx"
        green "  3) 重启 Nginx"
        purple "  0) 返回上级菜单"
        reading "请输入选择: " _ch
        case "$_ch" in
            0) return ;;
            1) nginx_start; green "✅ Nginx 已启动"; menu_pause ;;
            2) nginx_stop; green "✅ Nginx 已停止"; menu_pause ;;
            3) nginx_restart; green "✅ Nginx 已重启"; menu_pause ;;
            *) yellow "无效选项"; sleep 1 ;;
        esac
    done
}

interactive_service_menu() {
    local _ch
    while true; do
        clear
        green "========= [3] 服务管理 ========="
        echo ""
        green "  1) 重启服务 (sing-box + Argo)"
        green "  2) 更新内核 (ups)"
        green "  3) Nginx 管理"
        purple "  0) 返回主菜单"
        reading "请输入选择: " _ch
        case "$_ch" in
            0) return ;;
            1) sbrestart; argorestart; sleep 2; green "✅ 重启完成"; menu_pause ;;
            2) update_singbox && sbrestart; green "✅ 内核更新完成"; menu_pause ;;
            3) interactive_nginx_menu ;;
            *) yellow "无效选项"; sleep 1 ;;
        esac
    done
}

interactive_sub_menu() {
    local _ch
    while true; do
        clear
        green "========= [9] 订阅管理 ========="
        update_subscription_file
        echo ""
        if is_true "$(get_subscribe_flag)"; then
            green "📌 节点订阅地址: $(show_sub_url)"
        else
            yellow "订阅未开启。"
        fi
        echo ""
        green "  1) 重新生成订阅文件"
        purple "  0) 返回主菜单"
        reading "请输入选择: " _ch
        case "$_ch" in
            0) return ;;
            1) regenerate_links_and_sub; menu_pause ;;
            *) yellow "无效选项"; sleep 1 ;;
        esac
    done
}

# ================== 节点配置修改（node） ==================

# 读取端口文件值（存在则输出，否则空）
read_port_file() { [ -s "$SINGBOX_FOLDER_PATH/$1" ] && cat "$SINGBOX_FOLDER_PATH/$1"; }

# 校验 1-65535 端口
is_valid_port() { [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le 65535 ]; }

# 询问新端口：留空回车 = 随机（结果写入全局 NEW_PORT，避免 prompt 污染 stdout）
ask_new_port() {
    local _proto="$1" _in
    reading "请输入新的 ${_proto} 端口 (留空回车=随机): " _in
    if [ -z "$_in" ]; then
        _in="$(rand_port)"
        green "  ↳ ${_proto} 端口: ${_in} (随机)"
    elif is_valid_port "$_in"; then
        green "  ↳ ${_proto} 端口: ${_in}"
    else
        red "❌ 端口无效 (1-65535)"; return 1
    fi
    NEW_PORT="$_in"
}

# 更新 sb.json 中指定 tag 的 inbound 监听端口
update_inbound_port() {
    local _tag="$1" _port="$2"
    jq --arg tag "$_tag" --argjson p "$_port" \
        '(.inbounds[]? | select(.tag == $tag)) .listen_port = $p' \
        "$SINGBOX_FOLDER_PATH/sb.json" > "$SINGBOX_FOLDER_PATH/.sb.tmp" \
        && mv "$SINGBOX_FOLDER_PATH/.sb.tmp" "$SINGBOX_FOLDER_PATH/sb.json"
}

# 刷新 nginx 配置并重启（trojan/vmess/argo 端口变更时需要）
regen_nginx_and_restart() {
    export nginx_pt="${nginx_pt:-$(read_port_file nginx_port)}"
    export argo_pt="${argo_pt:-$(read_port_file argoport)}"
    setup_nginx_subscribe > /dev/null 2>&1 && nginx_restart
}

# 端口修改子菜单
edit_ports_menu() {
    local _sel _port _is_port _desc _tag _need_nginx _need_argo
    while true; do
        clear
        green "========= [4][1] 节点配置修改 → 端口修改 ========="
        echo ""
        green "  1) Trojan-WS (Argo) 端口"
        yellow "       当前: $(read_port_file port_tr)"
        green "  2) Vmess-WS (Argo) 端口"
        yellow "       当前: $(read_port_file port_vm_ws)"
        green "  3) Vless-WS (Argo) 端口"
        yellow "       当前: $(read_port_file port_vl_ws)"
        green "  4) VLESS-Reality 端口"
        yellow "       当前: $(read_port_file port_vlr)"
        green "  5) Hysteria2 端口"
        yellow "       当前: $(read_port_file port_hy2)"
        green "  6) TUIC 端口"
        yellow "       当前: $(read_port_file port_tu)"
        green "  7) AnyTLS 端口"
        yellow "       当前: $(read_port_file port_any)"
        green "  8) Argo 端口"
        yellow "       当前: $(read_port_file argoport)"
        purple "  0) 返回上级菜单"
        echo ""
        yellow "注：仅显示已安装的协议，未安装的协议修改会被忽略。"
        reading "请输入选择: " _sel
        case "$_sel" in
            0) return ;;
            1|2|3|4|5|6|7|8) ;;
            *) yellow "无效选项"; menu_pause; continue ;;
        esac
        case "$_sel" in
            1) _desc="Trojan-WS (Argo)"; _file=port_tr; _tag=trojan-ws-sb; _need_nginx=1 ;;
            2) _desc="Vmess-WS (Argo)"; _file=port_vm_ws; _tag=vmess-sb; _need_nginx=1 ;;
            3) _desc="Vless-WS (Argo)"; _file=port_vl_ws; _tag=vless-ws-sb; _need_nginx=1 ;;
            4) _desc="VLESS-Reality"; _file=port_vlr; _tag=vless-reality-vision-sb ;;
            5) _desc="Hysteria2"; _file=port_hy2; _tag=hy2-sb ;;
            6) _desc="TUIC"; _file=port_tu; _tag=tuic-sb ;;
            7) _desc="AnyTLS"; _file=port_any; _tag=anytls-sb ;;
            8) _desc="Argo"; _file=argoport; _tag=""; _need_argo=1 ;;
        esac

        if [ ! -s "$SINGBOX_FOLDER_PATH/$_file" ]; then
            red "❌ 未安装 ${_desc} 协议，无法修改。"; menu_pause; continue
        fi
        NEW_PORT=""
        ask_new_port "$_desc" || { menu_pause; continue; }
        _port="$NEW_PORT"
        echo "$_port" > "$SINGBOX_FOLDER_PATH/$_file"

        if [ -n "$_need_argo" ]; then
            # Argo 端口：更新 tunnel.yml 回源端口 + nginx 监听 + 重启 cloudflared
            if [ -s "$SINGBOX_FOLDER_PATH/tunnel.yml" ]; then
                sed -i.bak "s|http://localhost:[0-9]*|http://localhost:${_port}|g" "$SINGBOX_FOLDER_PATH/tunnel.yml" 2>/dev/null
                rm -f "$SINGBOX_FOLDER_PATH/tunnel.yml.bak" 2>/dev/null
            fi
            export argo_pt="$_port"
            regen_nginx_and_restart
            argorestart
            green "✅ Argo 端口修改操作已完成！新端口: ${_port}"
            menu_pause
            continue
        fi

        update_inbound_port "$_tag" "$_port"
        [ -n "$_need_nginx" ] && regen_nginx_and_restart
        refresh_sb_and_sub
        green "✅ ${_desc} 端口修改操作已完成！新端口: ${_port}"
        menu_pause
    done
}

# 订阅设置子菜单（修改订阅端口 / 取消订阅）
edit_subscription_menu() {
    local _sel _np
    while true; do
        clear
        green "========= [4][2] 节点配置修改 → 订阅设置 ========="
        echo ""
        if is_true "$(get_subscribe_flag)"; then
            green "  📌 订阅状态: 已开启"
            yellow "  订阅端口: $(read_port_file nginx_port)"
            green "  订阅地址: $(show_sub_url)"
        else
            yellow "  📌 订阅状态: 未开启"
        fi
        echo ""
        green "  1) 修改订阅端口 (Nginx)"
        red   "  2) 取消节点订阅"
        purple "  0) 返回上级菜单"
        reading "请输入选择: " _sel
        case "$_sel" in
            0) return ;;
            1)
                NEW_PORT=""
                ask_new_port "订阅 (Nginx)" || { menu_pause; continue; }
                _np="$NEW_PORT"
                echo "$_np" > "$SINGBOX_FOLDER_PATH/nginx_port"
                export nginx_pt="$_np"
                export subscribe="$(get_subscribe_flag)"
                setup_nginx_subscribe > /dev/null 2>&1 && nginx_restart
                update_subscription_file
                green "✅ 订阅端口修改操作已完成！新端口: ${_np}"
                green "  新订阅地址: $(show_sub_url)"
                menu_pause
                ;;
            2)
                echo "false" > "$SINGBOX_FOLDER_PATH/subscribe"
                export subscribe="false"
                setup_nginx_subscribe > /dev/null 2>&1 && nginx_restart
                green "✅ 取消节点订阅操作已完成！订阅已关闭。"
                menu_pause
                ;;
            *) yellow "无效选项"; menu_pause ;;
        esac
    done
}

# SNI / CDN 修改子菜单
edit_snis_menu() {
    local _sel _val
    while true; do
        clear
        green "========= [4][3] 节点配置修改 → SNI / CDN 设置 ========="
        echo ""
        green "  1) CDN 优选域名"
        yellow "       当前: $(cat "$SINGBOX_FOLDER_PATH/cdn_host" 2>/dev/null)"
        green "  2) CDN 端口 (仅限 HTTPS 系端口 ${HTTPS_CDN_PORTS[*]})"
        yellow "       当前: $(read_port_file cdn_pt)"
        green "  3) Hysteria2 伪装域名"
        yellow "       当前: $(cat "$SINGBOX_FOLDER_PATH/hy_sni" 2>/dev/null)"
        green "  4) VLESS 伪装域名"
        yellow "       当前: $(cat "$SINGBOX_FOLDER_PATH/vl_sni" 2>/dev/null)"
        green "  5) VLESS 伪装端口"
        yellow "       当前: $(read_port_file vl_sni_pt)"
        green "  6) TUIC 伪装域名"
        yellow "       当前: $(cat "$SINGBOX_FOLDER_PATH/tu_sni" 2>/dev/null)"
        green "  7) AnyTLS 伪装域名"
        yellow "       当前: $(cat "$SINGBOX_FOLDER_PATH/any_sni" 2>/dev/null)"
        purple "  0) 返回上级菜单"
        reading "请输入选择: " _sel
        case "$_sel" in
            0) return ;;
            1)
                reading "请输入新的 CDN 优选域名 (留空=取消): " _val
                [ -z "$_val" ] && { yellow "已取消"; menu_pause; continue; }
                echo "$_val" > "$SINGBOX_FOLDER_PATH/cdn_host"
                refresh_sb_and_sub
                green "✅ CDN 优选域名修改操作已完成！新值: ${_val}"
                menu_pause
                ;;
            2)
                reading "请输入新的 CDN 端口 (${HTTPS_CDN_PORTS[*]}, 留空=取消): " _val
                [ -z "$_val" ] && { yellow "已取消"; menu_pause; continue; }
                if ! printf '%s\n' "${HTTPS_CDN_PORTS[@]}" | grep -qx "$_val"; then
                    red "❌ CDN 端口仅限 HTTPS 系端口 (${HTTPS_CDN_PORTS[*]})"; menu_pause; continue
                fi
                echo "$_val" > "$SINGBOX_FOLDER_PATH/cdn_pt"
                refresh_sb_and_sub
                green "✅ CDN 端口修改操作已完成！新值: ${_val}"
                menu_pause
                ;;
            3)
                reading "请输入新的 Hysteria2 伪装域名 (留空=取消): " _val
                [ -z "$_val" ] && { yellow "已取消"; menu_pause; continue; }
                echo "$_val" > "$SINGBOX_FOLDER_PATH/hy_sni"
                refresh_sb_and_sub
                green "✅ Hysteria2 伪装域名修改操作已完成！新值: ${_val}"
                menu_pause
                ;;
            4)
                reading "请输入新的 VLESS 伪装域名 (留空=取消): " _val
                [ -z "$_val" ] && { yellow "已取消"; menu_pause; continue; }
                echo "$_val" > "$SINGBOX_FOLDER_PATH/vl_sni"
                [ -s "$SINGBOX_FOLDER_PATH/sb.json" ] && \
                    jq --arg v "$_val" '(.inbounds[]? | select(.tag == "vless-reality-vision-sb")) .tls.server_name = $v | (.inbounds[]? | select(.tag == "vless-reality-vision-sb")) .tls.reality.handshake.server = $v' \
                    "$SINGBOX_FOLDER_PATH/sb.json" > "$SINGBOX_FOLDER_PATH/.sb.tmp" && mv "$SINGBOX_FOLDER_PATH/.sb.tmp" "$SINGBOX_FOLDER_PATH/sb.json"
                refresh_sb_and_sub
                green "✅ VLESS 伪装域名修改操作已完成！新值: ${_val}"
                menu_pause
                ;;
            5)
                NEW_PORT=""
                ask_new_port "VLESS 伪装" || { menu_pause; continue; }
                _val="$NEW_PORT"
                echo "$_val" > "$SINGBOX_FOLDER_PATH/vl_sni_pt"
                jq --argjson p "$_val" '(.inbounds[]? | select(.tag == "vless-reality-vision-sb")) .tls.reality.handshake.server_port = $p' \
                    "$SINGBOX_FOLDER_PATH/sb.json" > "$SINGBOX_FOLDER_PATH/.sb.tmp" && mv "$SINGBOX_FOLDER_PATH/.sb.tmp" "$SINGBOX_FOLDER_PATH/sb.json"
                refresh_sb_and_sub
                green "✅ VLESS 伪装端口修改操作已完成！新值: ${_val}"
                menu_pause
                ;;
            6)
                reading "请输入新的 TUIC 伪装域名 (留空=取消): " _val
                [ -z "$_val" ] && { yellow "已取消"; menu_pause; continue; }
                echo "$_val" > "$SINGBOX_FOLDER_PATH/tu_sni"
                refresh_sb_and_sub
                green "✅ TUIC 伪装域名修改操作已完成！新值: ${_val}"
                menu_pause
                ;;
            7)
                reading "请输入新的 AnyTLS 伪装域名 (留空=取消): " _val
                [ -z "$_val" ] && { yellow "已取消"; menu_pause; continue; }
                echo "$_val" > "$SINGBOX_FOLDER_PATH/any_sni"
                [ -s "$SINGBOX_FOLDER_PATH/sb.json" ] && \
                    jq --arg v "$_val" '(.inbounds[]? | select(.tag == "anytls-sb")) .tls.server_name = $v' \
                    "$SINGBOX_FOLDER_PATH/sb.json" > "$SINGBOX_FOLDER_PATH/.sb.tmp" && mv "$SINGBOX_FOLDER_PATH/.sb.tmp" "$SINGBOX_FOLDER_PATH/sb.json"
                refresh_sb_and_sub
                green "✅ AnyTLS 伪装域名修改操作已完成！新值: ${_val}"
                menu_pause
                ;;
            *) yellow "无效选项"; menu_pause ;;
        esac
    done
}

# Argo 隧道修改子菜单（切换固定/临时、取消、切换协议）
edit_argo_menu() {
    local _sel _vlvm _argodomain _mode _tmp _d _a
    while true; do
        clear
        green "========= [4][4] 节点配置修改 → Argo 隧道修改 ========="
        echo ""
        _vlvm=$(cat "$SINGBOX_FOLDER_PATH/vlvm" 2>/dev/null)
        _argodomain=$(cat "$SINGBOX_FOLDER_PATH/argo_domain" 2>/dev/null)
        if [ -n "$_argodomain" ]; then
            _mode="固定隧道"
            [ -s "$SINGBOX_FOLDER_PATH/tunnel.yml" ] && _mode="固定隧道 (JSON)"
            [ -s "$SINGBOX_FOLDER_PATH/sbargotoken" ] && _mode="固定隧道 (Token)"
        elif [ -s "$SINGBOX_FOLDER_PATH/argoport" ]; then
            _mode="临时隧道 (trycloudflare)"
        else
            _mode="未启用"
        fi
        green "  Argo 状态: ${_mode}"
        green "  Argo 使用协议: ${_vlvm:--}"
        [ -n "$_argodomain" ] && green "  Argo 域名: ${_argodomain}"
        [ -s "$SINGBOX_FOLDER_PATH/argoport" ] && yellow "  Argo 本地端口: $(cat "$SINGBOX_FOLDER_PATH/argoport")"
        echo ""
        green "  1) 切换固定 Argo 隧道"
        green "  2) 切换临时 Argo 隧道"
        red   "  3) 取消使用 Argo 隧道"
        purple "  0) 返回上级菜单"
        reading "请输入选择: " _sel
        case "$_sel" in
            0) return ;;
            1)
                reading "请输入 Argo 域名: " _d
                [ -z "$_d" ] && { red "❌ 域名不能为空"; menu_pause; continue; }
                if ! is_valid_domain "$_d"; then
                    red "❌ 域名非法（只能含字母/数字/'-'/'.'）：${_d}"; menu_pause; continue
                fi
                reading_secret "请输入 Argo Token 或粘贴 JSON 凭据: " _a
                [ -z "$_a" ] && { red "❌ Token/JSON 不能为空"; menu_pause; continue; }
                rm -f "$SINGBOX_FOLDER_PATH/tunnel.yml" "$SINGBOX_FOLDER_PATH/tunnel.json" "$SINGBOX_FOLDER_PATH/sbargotoken"
                # 先校验（含域名/凭据格式），通过后再落盘，避免失败时留下不一致状态
                if ! prepare_argo_credentials "$_a" "$_d" "$(cat "$SINGBOX_FOLDER_PATH/argoport" 2>/dev/null)"; then
                    red "❌ Argo 凭据校验失败，未切换"; menu_pause; continue
                fi
                echo "$_d" > "$SINGBOX_FOLDER_PATH/argo_domain"
                chmod 600 "$SINGBOX_FOLDER_PATH/argo_domain" 2>/dev/null || true
                if [ "$ARGO_MODE" = "json" ]; then
                    echo "" > /dev/null
                elif [ "$ARGO_MODE" = "token" ]; then
                    echo "$_a" > "$SINGBOX_FOLDER_PATH/sbargotoken"
                    chmod 600 "$SINGBOX_FOLDER_PATH/sbargotoken" 2>/dev/null || true
                fi
                argorestart
                green "✅ 切换固定 Argo 隧道操作已完成！"
                menu_pause
                ;;
            2)
                rm -f "$SINGBOX_FOLDER_PATH/tunnel.yml" "$SINGBOX_FOLDER_PATH/tunnel.json" "$SINGBOX_FOLDER_PATH/sbargotoken" "$SINGBOX_FOLDER_PATH/argo_domain"
                argorestart
                green "✅ 切换临时 Argo 隧道操作已完成！"
                menu_pause
                ;;
            3)
                pkill -15 -f "$SINGBOX_FOLDER_PATH/cloudflared" 2> /dev/null
                [ -x "$SINGBOX_FOLDER_PATH/cloudflared" ] && pkill -15 -f "$SINGBOX_FOLDER_PATH/cloudflared" 2> /dev/null
                rm -f "$SINGBOX_FOLDER_PATH/tunnel.yml" "$SINGBOX_FOLDER_PATH/tunnel.json" "$SINGBOX_FOLDER_PATH/sbargotoken" "$SINGBOX_FOLDER_PATH/argo_domain" "$LOGS_DIR/argo.log"
                green "✅ 取消使用 Argo 隧道操作已完成！"
                menu_pause
                ;;
            *) yellow "无效选项"; menu_pause ;;
        esac
    done
}

# 切换 Argo 使用协议（Vmess-WS-TLS / Trojan-WS-TLS / Vless-WS-TLS）
edit_argo_protocol_menu() {
    local _vlvm _tmp
    while true; do
        clear
        green "========= [4][5] 节点配置修改 → 切换 Argo 使用协议 ========="
        echo ""
        _vlvm=$(cat "$SINGBOX_FOLDER_PATH/vlvm" 2>/dev/null)
        green "  当前 Argo 使用协议: ${_vlvm:-未设置}"
        echo ""
        green "  1) Vmess-WS-TLS (Argo)"
        green "  2) Trojan-WS-TLS (Argo)"
        green "  3) Vless-WS-TLS (Argo)"
        purple "  0) 返回上级菜单"
        reading "请输入选择: " _tmp
        case "$_tmp" in
            0) return ;;
            1)
                if [ ! -s "$SINGBOX_FOLDER_PATH/port_vm_ws" ]; then
                    red "❌ 未安装 Vmess-WS 协议，无法切换。"; menu_pause; continue
                fi
                echo "Vmess" > "$SINGBOX_FOLDER_PATH/vlvm"
                green "✅ 已切换 Argo 使用协议为 Vmess-WS-TLS 操作已完成！"
                regenerate_links_and_sub
                menu_pause
                ;;
            2)
                if [ ! -s "$SINGBOX_FOLDER_PATH/port_tr" ]; then
                    red "❌ 未安装 Trojan-WS 协议，无法切换。"; menu_pause; continue
                fi
                echo "Trojan" > "$SINGBOX_FOLDER_PATH/vlvm"
                green "✅ 已切换 Argo 使用协议为 Trojan-WS-TLS 操作已完成！"
                regenerate_links_and_sub
                menu_pause
                ;;
            3)
                if [ ! -s "$SINGBOX_FOLDER_PATH/port_vl_ws" ] && [ ! -s "$SINGBOX_FOLDER_PATH/port_vm_ws" ]; then
                    red "❌ 未安装 Vless-WS 协议，无法切换。"; menu_pause; continue
                fi
                echo "Vless" > "$SINGBOX_FOLDER_PATH/vlvm"
                green "✅ 已切换 Argo 使用协议为 Vless-WS-TLS 操作已完成！"
                regenerate_links_and_sub
                menu_pause
                ;;
            *) yellow "无效选项"; menu_pause ;;
        esac
    done
}

# ================== Socks5 IP白名单管理 ==================
# 重建白名单：先清除旧的 iptables 规则，再重新插入
_rebuild_socks5_whitelist_rules() {
    # 1) 清除旧的所有脚本防火墙规则
    flush_singbox_iptables_rules
    # 2) 重新应用所有协议端口规则 + 白名单规则
    apply_singbox_iptables_rules
    apply_socks5_whitelist
    # 3) 确保保存（即使白名单关闭也要保存，确保清除干净）
    _save_iptables_rules
}

edit_socks5_whitelist_menu() {
    local _ch
    while true; do
        clear
        green "========= Socks5 IP白名单管理 ========="
        echo ""

        # 显示当前状态
        local _wl_flag=""
        local _wl_ips=""
        [ -s "$SINGBOX_FOLDER_PATH/socks5_wl_flag" ] && _wl_flag=$(cat "$SINGBOX_FOLDER_PATH/socks5_wl_flag" | tr -d '\r\n')
        [ -s "$SINGBOX_FOLDER_PATH/socks5_ips" ] && _wl_ips=$(cat "$SINGBOX_FOLDER_PATH/socks5_ips" | tr -d '\r\n')

        if [ "$_wl_flag" = "true" ]; then
            green "  当前状态：✅ 已开启"
            if [ -n "$_wl_ips" ]; then
                green "  白名单IP：${_wl_ips}"
            else
                yellow "  白名单IP：（空，等同于关闭）"
            fi
        else
            yellow "  当前状态：❌ 未开启（所有IP均可访问）"
        fi
        echo ""
        green "  1) 开启白名单"
        green "  2) 关闭白名单"
        green "  3) 修改白名单IP列表"
        green "  4) 查看当前白名单IP"
        purple "  0) 返回上级菜单"
        reading "请输入选择: " _ch
        case "$_ch" in
            0) return ;;
            1)
                printf '%s\n' "true" > "$SINGBOX_FOLDER_PATH/socks5_wl_flag"
                if [ -s "$SINGBOX_FOLDER_PATH/socks5_ips" ] && [ -n "$(cat "$SINGBOX_FOLDER_PATH/socks5_ips" | tr -d '\r\n')" ]; then
                    _rebuild_socks5_whitelist_rules
                    sbrestart
                    green "✅ Socks5 IP白名单已开启"
                else
                    yellow "⚠️ 白名单已开启，但IP列表为空，请先设置白名单IP"
                    green "   设置后才会生效"
                fi
                menu_pause
                ;;
            2)
                printf '%s\n' "false" > "$SINGBOX_FOLDER_PATH/socks5_wl_flag"
                _rebuild_socks5_whitelist_rules
                sbrestart
                green "✅ Socks5 IP白名单已关闭（所有IP均可访问）"
                menu_pause
                ;;
            3)
                echo ""
                yellow "请输入允许访问Socks5的IP地址（支持IP和CIDR）"
                yellow "多个IP用逗号分隔，如：1.2.3.4,5.6.7.0/24,10.0.0.1"
                yellow "留空则清除所有白名单IP"
                local _input=""
                reading "白名单IP: " _input
                if [ -n "$_input" ]; then
                    # 去除首尾空格
                    _input=$(printf '%s' "$_input" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                    printf '%s\n' "$_input" > "$SINGBOX_FOLDER_PATH/socks5_ips"
                    green "✅ 白名单IP已更新：${_input}"
                    # 自动开启白名单
                    printf '%s\n' "true" > "$SINGBOX_FOLDER_PATH/socks5_wl_flag"
                    _rebuild_socks5_whitelist_rules
                    sbrestart
                    green "✅ Socks5 IP白名单已生效"
                else
                    printf '' > "$SINGBOX_FOLDER_PATH/socks5_ips"
                    printf '%s\n' "false" > "$SINGBOX_FOLDER_PATH/socks5_wl_flag"
                    _rebuild_socks5_whitelist_rules
                    sbrestart
                    yellow "白名单IP已清空，白名单已关闭"
                fi
                menu_pause
                ;;
            4)
                echo ""
                if [ -s "$SINGBOX_FOLDER_PATH/socks5_ips" ] && [ -n "$(cat "$SINGBOX_FOLDER_PATH/socks5_ips" | tr -d '\r\n')" ]; then
                    green "当前白名单IP列表："
                    cat "$SINGBOX_FOLDER_PATH/socks5_ips" | tr ',' '\n' | while read -r _ip; do
                        [ -n "$_ip" ] && green "  - $_ip"
                    done
                else
                    yellow "白名单IP列表为空"
                fi
                menu_pause
                ;;
            *) yellow "无效选项"; sleep 1 ;;
        esac
    done
}

# 节点配置修改主菜单
node_config_menu() {
    local _ch
    while true; do
        clear
        green "========= [4] 节点配置修改 (node) ========="
        echo ""
        green "  1) 端口修改"
        green "  2) 订阅设置 (修改订阅端口 / 取消订阅)"
        green "  3) SNI / CDN 设置修改"
        green "  4) Argo 隧道修改"
        green "  5) 切换 Argo 使用协议 (Vmess-WS-TLS / Trojan-WS-TLS / Vless-WS-TLS)"
        if grep -q "socks5-sb" "$SINGBOX_FOLDER_PATH/sb.json" 2>/dev/null; then
            local _wl_status="未开启"
            local _wl_menu_flag=""
            [ -s "$SINGBOX_FOLDER_PATH/socks5_wl_flag" ] && _wl_menu_flag=$(cat "$SINGBOX_FOLDER_PATH/socks5_wl_flag" | tr -d '\r\n')
            if is_true "$_wl_menu_flag"; then
                _wl_status="已开启"
            fi
            green "  6) Socks5 IP白名单管理 (当前：${_wl_status})"
        fi
        purple "  0) 返回主菜单"
        reading "请输入选择: " _ch
        case "$_ch" in
            0) return ;;
            1) edit_ports_menu ;;
            2) edit_subscription_menu ;;
            3) edit_snis_menu ;;
            4) edit_argo_menu ;;
            5) edit_argo_protocol_menu ;;
            6) edit_socks5_whitelist_menu ;;
            *) yellow "无效选项"; sleep 1 ;;
        esac
    done
}

# 显示日志文件尾部（剥离 ANSI 颜色码）；参数：文件路径 标题 空文件提示 [行数]
show_log_file() {
    local _log="$1" _title="$2" _hint="$3" _lines="${4:-100}" _e
    echo "$_lines" | grep -qE '^[0-9]+$' || _lines=100
    # 显示时剥离 ANSI 颜色码（兼容安装被中断后日志残留颜色码的情况）
    _e=$(printf '\033')
    echo ""
    green "=== $_title (最近 $_lines 行) ==="
    if [ -s "$_log" ]; then
        tail -n "$_lines" "$_log" | sed "s/$_e\[[0-9;?]*[A-Za-z]//g"
    else
        yellow "$_hint"
    fi
    echo ""
}

interactive_log_menu() {
    local _ch _log _title _hint _lines
    while true; do
        clear
        green "========= [10] 查看日志 ========="
        echo ""
        green "  1) Sing-box 日志"
        green "  2) Argo (cloudflared) 日志"
        green "  3) Nginx 日志"
        green "  4) 脚本安装日志 (最近一次安装)"
        green "  5) 服务停止原因日志 (排查崩溃用)"
        purple "  0) 返回主菜单"
        reading "请输入选择: " _ch
        case "$_ch" in
            0) return ;;
            1)
                _log="$LOGS_DIR/singbox.log"
                _title="Sing-box 日志"
                _hint="暂无日志：$_log" ;;
            2)
                _log="$LOGS_DIR/argo.log"
                _title="Argo (cloudflared) 日志"
                _hint="暂无日志：$_log" ;;
            3)
                _log="/var/log/nginx/error.log"
                _title="Nginx 日志"
                _hint="暂无日志：$_log" ;;
            4)
                # 安装日志：直接显示全文，不问行数
                _log="$LOGS_DIR/install.log"
                if [ ! -s "$_log" ]; then
                    yellow "暂无安装日志：执行 ins/rep 或菜单安装后自动生成"
                    menu_pause
                    continue
                fi
                green "=== 脚本安装日志（仅保留最近一次安装） ==="
                cat "$_log"
                menu_pause
                continue ;;
            5)
                _log="$LOGS_DIR/stop_reason.log"
                _title="服务停止原因日志"
                _hint="暂无停止记录：服务运行正常时不会产生记录" ;;
            *) yellow "无效选项"; sleep 1; continue ;;
        esac
        _lines=100
        reading "显示最近行数 (默认100): " _lines
        show_log_file "$_log" "$_title" "$_hint" "$_lines"
        menu_pause
    done
}

# ================== 分流管理 (rt) ==================
# 参照 lwsb.sh 的 WARP 分流管理实现，适配 sb00 单文件配置 (sb.json)
# 分流规则插入在 sniff 之后、resolve 之前，保留 sing-box 默认行为

# 分流服务 tag -> 远程规则集 URL
rt_rule_set_url() {
    local tag="$1"
    case "$tag" in
        openai)   echo "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo-lite/geosite/openai.srs" ;;
        claude)   echo "https://main.ssss.nyc.mn/claude.srs" ;;
        gemini)   echo "https://main.ssss.nyc.mn/gemini.srs" ;;
        google)   echo "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo-lite/geosite/google.srs" ;;
        tiktok)   echo "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo-lite/geosite/tiktok.srs" ;;
        twitter)  echo "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo-lite/geosite/twitter.srs" ;;
        youtube)  echo "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo-lite/geosite/youtube.srs" ;;
        netflix)  echo "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo-lite/geosite/netflix.srs" ;;
        telegram) echo "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo-lite/geosite/telegram.srs" ;;
    esac
}

# 确保 wireguard-out (WARP) endpoint 存在（默认分流出口，参照 lwsb endpoints.json）
rt_ensure_wireguard() {
    local sbj="$SINGBOX_FOLDER_PATH/sb.json"
    jq -e '.endpoints[]? | select(.tag == "wireguard-out")' "$sbj" > /dev/null 2>&1 && return 0
    jq '.endpoints = (.endpoints // []) + [{
            type: "wireguard",
            tag: "wireguard-out",
            mtu: 1280,
            address: ["172.16.0.2/32", "2606:4700:110:8dfe:d141:69bb:6b80:925/128"],
            private_key: "YFYOAdbw1bKTHlNNi+aEjBM3BO7unuFC5rOkMRAz9XY=",
            peers: [{
                address: "engage.cloudflareclient.com",
                port: 2408,
                public_key: "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=",
                allowed_ips: ["0.0.0.0/0", "::/0"],
                reserved: [78, 135, 76]
            }]
        }]' "$sbj" > "$SINGBOX_FOLDER_PATH/.sb.tmp" && mv "$SINGBOX_FOLDER_PATH/.sb.tmp" "$sbj"
}

# 确保 route.rule_set 中已定义该 tag 的远程规则集
rt_ensure_rule_set() {
    local tag="$1" url
    url="$(rt_rule_set_url "$tag")"
    local sbj="$SINGBOX_FOLDER_PATH/sb.json"
    jq --arg tag "$tag" --arg url "$url" '
        .route.rule_set = (.route.rule_set // [])
        | if ([.route.rule_set[] | .tag] | index($tag)) == null then
            .route.rule_set += [{tag: $tag, type: "remote", format: "binary", url: $url, download_detour: "direct"}]
          else . end
    ' "$sbj" > "$SINGBOX_FOLDER_PATH/.sb.tmp" && mv "$SINGBOX_FOLDER_PATH/.sb.tmp" "$sbj"
}

# 清理 route.rule_set 中已无规则引用的定义
rt_remove_unused_rule_sets() {
    local sbj="$SINGBOX_FOLDER_PATH/sb.json"
    jq '(
        . as $doc
        | ($doc.route.rules // []) as $R
        | ([ $R[] | .rule_set[]? ] | unique) as $used
        | $doc
        | .route.rule_set = [.route.rule_set[]? | select((.tag // "") as $t | $used | index($t))]
    )' "$sbj" > "$SINGBOX_FOLDER_PATH/.sb.tmp" && mv "$SINGBOX_FOLDER_PATH/.sb.tmp" "$sbj"
}

# 读取现有 resolve 规则的 DNS 策略（无则用 prefer_ipv6）
rt_get_strategy() {
    jq -r '.route.rules[]? | select(.action == "resolve") | .strategy // empty' \
        "$SINGBOX_FOLDER_PATH/sb.json" | head -1
}

# 分流管理入口
rt_manage() {
    if ! is_installed_sb; then
        yellow "sing-box 尚未安装！请先安装节点。"; menu_pause; return
    fi
    local sbj="$SINGBOX_FOLDER_PATH/sb.json"
    local _ch _rules _outs
    while true; do
        clear
        green "========= [5] 分流管理 (rt) ========="
        echo ""
        green "当前已启用的分流规则集:"
        _rules=$(jq -r '.route.rules[]? | select(.rule_set != null) | .rule_set[]?' "$sbj" 2>/dev/null | sort -u)
        if [ -n "$_rules" ]; then
            echo "$_rules" | while read -r _tag; do
                green "  - $_tag"
            done
        else
            yellow "  无"
        fi
        echo ""
        green "已添加的 socks/http 代理出站:"
        _outs=$(jq -r '
            . as $doc
            | [.outbounds[]? | select(.type == "socks" or .type == "http")] as $os
            | [$os[] | (.tag as $t
                | ([$doc.route.rules[]? | select(.inbound != null and .outbound == $t) | .inbound[]?]) as $a
                | "  - \($t) [\(.type)]" + (if ($a | length) > 0 then " (附着: \($a | join(", ")))" else "" end))]
            | .[]
        ' "$sbj" 2>/dev/null)
        if [ -n "$_outs" ]; then
            echo "$_outs"
        else
            yellow "  无"
        fi
        echo ""
        yellow "  匹配优先级: 网站分流 > 协议附着代理 > 原IP直连（先命中分流，分流不中再走协议附着的代理）"
        echo ""
        green "  1) 设置分流服务 (未添加socks/http直接设置则使用WARP)"
        red   "  2) 删除分流服务"
        green "  3) 添加 Socks5/HTTP 出站"
        green "  4) 查看代理下附着了哪些协议"
        red   "  5) 删除 Socks5/HTTP 出站"
        green "  6) 查看各协议对应的代理出口"
        green "  7) 修改各协议使用的代理"
        purple "  0) 返回主菜单"
        reading "请输入选择: " _ch
        case "$_ch" in
            1) add_rule_menu ;;
            2) delete_rule_menu ;;
            3) add_socks5_proxy ;;
            4) view_proxy_protocols ;;
            5) delete_socks5_proxy ;;
            6) rt_proxy_map ;;
            7) edit_protocol_proxy ;;
            0) return ;;
            *) yellow "无效选项"; menu_pause ;;
        esac
    done
}

# 查看各协议对应的代理出口（无代理 = 原IP出站）
rt_proxy_map() {
    local sbj="$SINGBOX_FOLDER_PATH/sb.json" _p _out _cnt=0
    local _order=(vmess-sb vless-ws-sb trojan-ws-sb vless-reality-vision-sb hy2-sb tuic-sb anytls-sb)
    clear
    green "========= [5][6] 分流管理 → 各协议对应的代理出口 ========="
    echo ""
    for _p in "${_order[@]}"; do
        if ! jq -e --arg t "$_p" '.inbounds[]? | select(.tag == $t)' "$sbj" >/dev/null 2>&1; then
            continue
        fi
        _out=$(jq -r --arg p "$_p" '[.route.rules[]? | select(.inbound != null) | select(.inbound | index($p)) | .outbound // empty] | .[0] // empty' "$sbj" 2>/dev/null)
        if [ -n "$_out" ]; then
            green "  ${_p} -----> ${_out}"
        else
            yellow "  ${_p} -----> 原ip出站"
        fi
        _cnt=$((_cnt+1))
    done
    if [ "$_cnt" -eq 0 ]; then
        yellow "  未检测到已安装的协议入站"
    fi
    echo ""
    yellow "  提示: 网站分流 > 协议附着代理 > 原IP直连"
    echo ""
    menu_pause
}

# 查看每个 socks/http 代理下附着了哪些协议
view_proxy_protocols() {
    local sbj="$SINGBOX_FOLDER_PATH/sb.json" _tags _t _attached
    clear
    green "========= [5][4] 分流管理 → 查看代理下附着的协议 ========="
    echo ""
    _tags=$(jq -r '[.outbounds[]? | select(.type == "socks" or .type == "http") | .tag] | .[]' "$sbj" 2>/dev/null)
    if [ -z "$_tags" ]; then
        yellow "当前没有 socks/http 代理出站。"
        menu_pause; return
    fi
    while read -r _t; do
        [ -z "$_t" ] && continue
        _attached=$(jq -r --arg tag "$_t" '[.route.rules[]? | select(.inbound != null and .outbound == $tag) | .inbound[]?] | join(", ")' "$sbj" 2>/dev/null)
        if [ -n "$_attached" ]; then
            green "  $_t → $_attached"
        else
            yellow "  $_t → 未附着任何协议"
        fi
    done <<< "$_tags"
    echo ""
    yellow "  提示: 网站分流 > 协议附着代理 > 原IP直连"
    echo ""
    menu_pause
}

# 修改某协议使用的代理（选已添加的 socks/http 代理，0=直连原IP出口，回车=取消）
edit_protocol_proxy() {
    local sbj="$SINGBOX_FOLDER_PATH/sb.json"
    local _letters=(b c d e f g h) _ptags=(vless-reality-vision-sb hy2-sb tuic-sb anytls-sb vmess-sb trojan-ws-sb vless-ws-sb)
    local _protos=() _n _p _tag _cur _plist _choice
    clear
    green "========= [5][7] 分流管理 → 修改各协议使用的代理 ========="
    echo ""
    for _n in "${!_letters[@]}"; do
        if jq -e --arg t "${_ptags[$_n]}" '.inbounds[]? | select(.tag == $t)' "$sbj" >/dev/null 2>&1; then
            _protos+=("${_letters[$_n]}:${_ptags[$_n]}")
        fi
    done
    if [ ${#_protos[@]} -eq 0 ]; then
        yellow "未检测到已安装的协议入站（tuic/hy2/vmess/vless 等）。"; menu_pause; return
    fi

    green "已安装协议:"
    for _n in "${!_protos[@]}"; do
        green "  ${_protos[$_n]%%:*}) ${_protos[$_n]#*:}"
    done
    echo ""
    yellow "  提示: 网站分流 > 协议附着代理 > 原IP直连"
    echo ""
    reading "输入要修改的协议编号: " _choice
    _choice=$(echo "$_choice" | tr '[:upper:]' '[:lower:]' | xargs)
    _tag=""
    for _entry in "${_protos[@]}"; do
        [ "${_entry%%:*}" = "$_choice" ] && { _tag="${_entry#*:}"; break; }
    done
    if [ -z "$_tag" ]; then
        red "无效的协议编号！"; menu_pause; return
    fi

    _cur=$(jq -r --arg p "$_tag" '[.route.rules[]? | select(.inbound != null) | select(.inbound | index($p)) | .outbound // empty] | .[0] // empty' "$sbj" 2>/dev/null)
    if [ -n "$_cur" ]; then
        green "$_tag 当前使用的代理: $_cur"
    else
        yellow "$_tag 当前未使用任何代理（直连原IP出口）"
    fi

    echo ""
    green "可选代理（已添加的 socks/http 出站）:"
    _plist=$(jq -r '[.outbounds[]? | select(.type == "socks" or .type == "http") | .tag] | to_entries | .[] | "  \(.key+1)) \(.value)"' "$sbj" 2>/dev/null)
    if [ -n "$_plist" ]; then
        echo "$_plist"
    else
        yellow "  无已添加的 socks/http 代理"
    fi
    echo ""
    yellow "选择要使用的代理编号（0=直连原IP出口，直接回车=取消）:"
    reading "请输入: " _choice
    [ -z "$_choice" ] && { yellow "已取消，未做任何修改。"; menu_pause; return; }

    if [ "$_choice" = "0" ]; then
        # 直连：从所有 inbound 规则中移除该协议
        if jq --arg p "$_tag" '
            . as $doc
            | ($doc.route.rules // []) as $R
            | ($R | map(select(.action == "sniff"))) as $sniff
            | ($R | map(select(.action == "resolve"))) as $resolve
            | ($R | map(select(.action != "sniff" and .action != "resolve" and (.inbound == null or ((.inbound | index($p)) | not))))) as $splits
            | $doc
            | .route.rules = $sniff + $splits + $resolve
        ' "$sbj" > "$SINGBOX_FOLDER_PATH/.sb.tmp" && mv "$SINGBOX_FOLDER_PATH/.sb.tmp" "$sbj"; then
            sbrestart
            green "✅ $_tag 已改为直连（原IP出口）"
        else
            red "❌ 写入 sb.json 失败，配置未更新，请检查磁盘空间或权限。"
        fi
        menu_pause; return
    fi

    # 选择某个代理：把该协议移动到目标代理的 inbound 规则
    _p=$(jq -r --arg idx "$_choice" '[.outbounds[]? | select(.type == "socks" or .type == "http") | .tag] | .[($idx | tonumber) - 1] // empty' "$sbj" 2>/dev/null)
    if [ -z "$_p" ]; then
        red "无效的代理编号！"; menu_pause; return
    fi
    if jq --arg p "$_p" --arg proto "$_tag" '
        . as $doc
        | ($doc.route.rules // []) as $R
        | ($R | map(select(.action == "sniff"))) as $sniff
        | ($R | map(select(.action == "resolve"))) as $resolve
        | ($R | map(select(.action != "sniff" and .action != "resolve" and .inbound == null))) as $others
        | ($R | map(select(.action != "sniff" and .action != "resolve" and .inbound != null and .outbound == $p))) as $target
        | ($R | map(select(.action != "sniff" and .action != "resolve" and .inbound != null and .outbound != $p and ((.inbound | index($proto)) | not)))) as $inb_others
        | $doc
        | .route.rules = $sniff + ($others + $inb_others + [
            if ($target | length) > 0 then
                (if ($target[0].inbound | index($proto)) then $target[0] else ($target[0] | .inbound += [$proto]) end)
            else
                {inbound: [$proto], outbound: $p}
            end
          ] | sort_by(if .rule_set != null then 0 elif .inbound != null then 1 else 2 end)) + $resolve
    ' "$sbj" > "$SINGBOX_FOLDER_PATH/.sb.tmp" && mv "$SINGBOX_FOLDER_PATH/.sb.tmp" "$sbj"; then
        sbrestart
        green "✅ $_tag 已改用代理: $_p"
    else
        red "❌ 写入 sb.json 失败，配置未更新，请检查磁盘空间或权限。"
    fi
    menu_pause
}

# 选择要分流的服务并设置出站
add_rule_menu() {
    local _add_choice rule_tag
    clear
    green "========= [5][1] 分流管理 → 设置分流服务 ========="
    echo ""
    green "  1)  OpenAI"
    green "  2)  Claude"
    green "  3)  Gemini"
    green "  4)  Google"
    green "  5)  Tiktok"
    green "  6)  Twitter"
    green "  7)  YouTube"
    green "  8)  Netflix"
    green "  9)  Telegram"
    echo ""
    green "  10) 设置全局代理出站 (所有流量走指定代理)"
    green "  11) 恢复服务器原IP出站 (所有流量走服务器ip)"
    purple "  0)  返回上级菜单"
    reading "请输入选择: " _add_choice
    case "$_add_choice" in
        1)  rule_tag="openai"   ;;
        2)  rule_tag="claude"   ;;
        3)  rule_tag="gemini"   ;;
        4)  rule_tag="google"   ;;
        5)  rule_tag="tiktok"   ;;
        6)  rule_tag="twitter"  ;;
        7)  rule_tag="youtube"  ;;
        8)  rule_tag="netflix"  ;;
        9)  rule_tag="telegram" ;;
        10) set_global_outbound; return ;;
        11) restore_direct_outbound; return ;;
        0)  return ;;
        *)  red "无效选项"; menu_pause; add_rule_menu; return ;;
    esac

    local sbj="$SINGBOX_FOLDER_PATH/sb.json"
    local tmpj="$SINGBOX_FOLDER_PATH/.sb.tmp"

    if jq -e --arg tag "$rule_tag" \
        '.route.rules[]? | select(.rule_set != null) | .rule_set[]? | select(. == $tag)' \
        "$sbj" > /dev/null 2>&1; then
        yellow "规则集 '${rule_tag}' 已启用。"; menu_pause; return
    fi

    # 选择分流流量要走的出站（排除 direct/block，参照 lwsb 排除 direct）
    local out_tags=($(jq -r '.outbounds[]? | select(.tag != "direct" and .tag != "block") | .tag' "$sbj" 2>/dev/null))
    local selected_out _out_choice
    if [ ${#out_tags[@]} -eq 0 ]; then
        selected_out="wireguard-out"
        rt_ensure_wireguard
        yellow "未找到其他出站，将自动使用 wireguard-out (WARP)。"
    else
        echo ""
        green "请选择分流流量要走的出站:"
        for i in "${!out_tags[@]}"; do
            green "  $((i+1)). ${out_tags[$i]}"
        done
        reading "请输入编号: " _out_choice
        if [[ ! "$_out_choice" =~ ^[0-9]+$ ]] || \
           [ "$_out_choice" -lt 1 ] || \
           [ "$_out_choice" -gt "${#out_tags[@]}" ]; then
            red "无效选择"; menu_pause; return
        fi
        selected_out="${out_tags[$((_out_choice-1))]}"
    fi

    # 注入 rule_set 定义（sb00 默认不预置，需按需添加）
    rt_ensure_rule_set "$rule_tag"

    jq --arg tag "$rule_tag" --arg out "$selected_out" '
        . as $doc
        | ($doc.route.rules // []) as $R
        | ($R | map(select(.action == "sniff"))) as $sniff
        | ($R | map(select(.action == "resolve"))) as $resolve
        | ($R | map(select(.action != "sniff" and .action != "resolve"))) as $splits
        | ($splits | map(select(.rule_set != null and .outbound == $out)) | length > 0) as $has_out
        | $doc
        | if $has_out then
            .route.rules = $sniff + ([$splits[] | if (.rule_set != null and .outbound == $out) then .rule_set += [$tag] else . end]
                | sort_by(if .rule_set != null then 0 elif .inbound != null then 1 else 2 end)) + $resolve
          else
            .route.rules = $sniff + ($splits + [{rule_set: [$tag], outbound: $out}]
                | sort_by(if .rule_set != null then 0 elif .inbound != null then 1 else 2 end)) + $resolve
          end
    ' "$sbj" > "$tmpj" && mv "$tmpj" "$sbj"
    rm -f "$tmpj" 2> /dev/null || true

    sbrestart
    green "'${rule_tag}' 已分流至出站 '${selected_out}'"
    menu_pause
}

# 删除分流规则集
delete_rule_menu() {
     local _del_input _tag _count
     clear
     green "========= [5][2] 分流管理 → 删除分流服务 ========="
     echo ""
     green "当前已启用的分流规则集:"
    _count=$(jq -r '[.route.rules[]? | select(.rule_set != null) | .rule_set[]?] | length' "$SINGBOX_FOLDER_PATH/sb.json" 2>/dev/null)
    if [ "$_count" -eq 0 ] 2>/dev/null || [ -z "$_count" ]; then
        yellow "  无"
        menu_pause; return
    fi
    jq -r '.route.rules[]? | select(.rule_set != null) | .rule_set[]?' "$SINGBOX_FOLDER_PATH/sb.json" | nl -w2 -s'. '
    reading "输入要删除的规则名称或序号: " _del_input
    if [[ "$_del_input" =~ ^[0-9]+$ ]]; then
        _tag=$(jq -r --arg idx "$_del_input" '[.route.rules[]? | select(.rule_set != null) | .rule_set[]] | .[(($idx | tonumber) - 1)]' "$SINGBOX_FOLDER_PATH/sb.json")
    else
        _tag="$_del_input"
    fi
    if [ -z "$_tag" ] || [ "$_tag" = "null" ]; then
        red "无效的选择"; menu_pause; return
    fi
    jq --arg tag "$_tag" '
        . as $doc
        | ($doc.route.rules // []) as $R
        | ($R | map(select(.action == "sniff"))) as $sniff
        | ($R | map(select(.action == "resolve"))) as $resolve
        | ($R | map(select(.action != "sniff" and .action != "resolve"))) as $splits
        | $doc
        | .route.rules = $sniff + ([$splits[] | if .rule_set != null then .rule_set -= [$tag] | select((.rule_set | length) > 0) else . end]
            | sort_by(if .rule_set != null then 0 elif .inbound != null then 1 else 2 end)) + $resolve
    ' "$SINGBOX_FOLDER_PATH/sb.json" > "$SINGBOX_FOLDER_PATH/.sb.tmp" && mv "$SINGBOX_FOLDER_PATH/.sb.tmp" "$SINGBOX_FOLDER_PATH/sb.json"
    rt_remove_unused_rule_sets
    sbrestart
    green "规则集 '${_tag}' 已禁用。"
    menu_pause
}

# 添加 Socks5/HTTP 代理出站
add_socks5_proxy() {
     local _proxy_url _proto _outbound_type _after_proto _tag_from_url _user_pass _host_port
     local _user _password _decoded _server _port _check_proto _is_local _proxy_auth
     local _tag _force_add _test_result
     clear
     green "========= [5][3] 分流管理 → 添加 Socks5/HTTP 出站 ========="
     echo ""
     reading "请输入代理URL (支持socks://,socks5://,http:// 支持v2rayN导出的节点链接): " _proxy_url
    [ -z "$_proxy_url" ] && { red "输入为空！"; menu_pause; return; }

    if [[ "$_proxy_url" =~ ^([a-zA-Z0-9]+):// ]]; then
        _proto="${BASH_REMATCH[1]}"
    else
        red "URL格式错误"; menu_pause; return
    fi
    [[ ! "$_proto" =~ ^(socks5|socks|http)$ ]] && { red "不支持的协议"; menu_pause; return; }
    case "$_proto" in
        socks|socks5) _outbound_type="socks" ;;
        http)         _outbound_type="http" ;;
    esac

    _after_proto="${_proxy_url#*://}"
    if [[ "$_after_proto" == *"#"* ]]; then
        _tag_from_url="${_after_proto##*#}"; _after_proto="${_after_proto%%#*}"
    else
        _tag_from_url=""
    fi

    if [[ "$_after_proto" == *"@"* ]]; then
        _user_pass="${_after_proto%%@*}"; _host_port="${_after_proto##*@}"
    else
        _user_pass=""; _host_port="$_after_proto"
    fi

    _user=""; _password=""
    if [ -n "$_user_pass" ]; then
        _decoded=$(echo "$_user_pass" | base64 -d 2>/dev/null)
        if [ -n "$_decoded" ] && [[ "$_decoded" != "$_user_pass" ]] && [[ "$_decoded" == *":"* ]]; then
            _user="${_decoded%%:*}"; _password="${_decoded#*:}"
        elif [[ "$_user_pass" == *":"* ]]; then
            _user="${_user_pass%%:*}"; _password="${_user_pass#*:}"
        else
            _user="$_user_pass"
        fi
    fi

    _server="${_host_port%%:*}"; _port="${_host_port##*:}"
    [ -z "$_server" ] || [ -z "$_port" ] && { red "格式错误：缺少ip或端口"; menu_pause; return; }

    [[ "$_proto" == "socks" || "$_proto" == "socks5" ]] && _check_proto="socks5" || _check_proto="$_proto"

    # 本地地址跳过外部 API 检测，直接用 curl 测试
    _is_local=false
    if [[ "$_server" == "127.0.0.1" || "$_server" == "::1" || "$_server" == "localhost" ]]; then
        _is_local=true
    fi

    _proxy_auth=""
    [ -n "$_user" ] && [ -n "$_password" ] && _proxy_auth="${_user}:${_password}@" || \
        { [ -n "$_user" ] && _proxy_auth="${_user}@"; }

    if [ "$_is_local" = true ]; then
        yellow "检测到本地代理 ${_check_proto}://${_server}:${_port}，跳过外部API检测，正在用curl测试连通性..."
        _test_result=$(curl -s --max-time 8 --proxy "${_check_proto}://${_proxy_auth}${_server}:${_port}" "https://api.ip.sb/ip" 2>/dev/null)
        if [ -z "$_test_result" ]; then
            yellow "警告：通过本地代理访问外网失败，请确认代理服务正在运行。"
            reading "是否仍然添加此代理？(y/n): " _force_add
            [[ ! "$_force_add" =~ ^[yY]$ ]] && { yellow "已取消"; menu_pause; return; }
        else
            green "本地代理可用，出口IP: $_test_result"
        fi
    else
        yellow "正在测试代理 ${_check_proto}://${_server}:${_port} ..."
        local _api_response _success _error_msg _exit_ip
        _api_response=$(curl -s --max-time 8 -G \
            --data-urlencode "proxy=${_check_proto}://${_proxy_auth}${_server}:${_port}" \
            "https://check.socks5.cmliussss.net/check" 2>/dev/null)
        [ -z "$_api_response" ] && { red "API 请求失败"; menu_pause; return; }
        _success=$(echo "$_api_response" | jq -r '.success')
        if [ "$_success" != "true" ]; then
            _error_msg=$(echo "$_api_response" | jq -r '.error // "未知错误"')
            red "代理不可用: $_error_msg"; menu_pause; return
        fi
        _exit_ip=$(echo "$_api_response" | jq -r '.exit.ip // empty')
        green "代理可用"
        [ -n "$_exit_ip" ] && green "出口 IP: $_exit_ip"
    fi

    [ -n "$_tag_from_url" ] && _tag="$_tag_from_url" || _tag="${_outbound_type}-${_server}-${_port}"
    case "$_tag" in
        direct|block|wireguard-out|socks5-sb)
            red "标签 '$_tag' 为系统保留，请换一个名称"
            menu_pause; return ;;
    esac
    if jq -e --arg tag "$_tag" '[.outbounds[]?.tag, .inbounds[]?.tag, .endpoints[]?.tag, .route.rule_set[]?.tag] | index($tag)' "$SINGBOX_FOLDER_PATH/sb.json" >/dev/null 2>&1; then
        red "标签 '$_tag' 已存在"; menu_pause; return
    fi

    # 根据是否有账号密码，决定写入字段，避免空字符串导致 sing-box 报错
    if [ -n "$_user" ] && [ -n "$_password" ]; then
        jq --arg type "$_outbound_type" --arg tag "$_tag" --arg server "$_server" \
           --arg port "$_port" --arg user "$_user" --arg password "$_password" \
           '.outbounds = (.outbounds // []) + [{"type":$type,"tag":$tag,"server":$server,"server_port":($port|tonumber),"username":$user,"password":$password}]' \
           "$SINGBOX_FOLDER_PATH/sb.json" > "$SINGBOX_FOLDER_PATH/.sb.tmp" && mv "$SINGBOX_FOLDER_PATH/.sb.tmp" "$SINGBOX_FOLDER_PATH/sb.json"
    else
        jq --arg type "$_outbound_type" --arg tag "$_tag" --arg server "$_server" \
           --arg port "$_port" \
           '.outbounds = (.outbounds // []) + [{"type":$type,"tag":$tag,"server":$server,"server_port":($port|tonumber)}]' \
           "$SINGBOX_FOLDER_PATH/sb.json" > "$SINGBOX_FOLDER_PATH/.sb.tmp" && mv "$SINGBOX_FOLDER_PATH/.sb.tmp" "$SINGBOX_FOLDER_PATH/sb.json"
    fi

    sbrestart
    green "$_tag 代理出站已添加"
    reading "是否为此代理指定附着的协议？(y/n，直接回车=否): " _attach_now
    if [[ "$_attach_now" =~ ^[yY]$ ]]; then
        attach_socks5_proxy "$_tag" 3
    fi
    menu_pause
}

# 删除 Socks5/HTTP 代理出站
delete_socks5_proxy() {
     local _out_list _del_input _tag _del_type _used_inbound _used_rule _del_confirm
     clear
     green "========= [5][5] 分流管理 → 删除 Socks5/HTTP 出站 ========="
     echo ""
     green "当前 socks/http 代理出站（可删除）:"
    _out_list=$(jq -r '[.outbounds[]? | select(.type == "socks" or .type == "http")] | to_entries | .[] | "\(.key+1). \(.value.tag) [\(.value.type)]"' "$SINGBOX_FOLDER_PATH/sb.json" 2>/dev/null)
    [ -z "$_out_list" ] && { yellow "没有可删除的 socks/http 代理出站。"; menu_pause; return; }
    echo "$_out_list"

    reading "输入要删除的代理编号或标签: " _del_input
    if [[ "$_del_input" =~ ^[0-9]+$ ]]; then
        _tag=$(jq -r --arg idx "$_del_input" '.outbounds | map(select(.type == "socks" or .type == "http")) | .[($idx | tonumber)-1].tag // empty' "$SINGBOX_FOLDER_PATH/sb.json")
        [ -z "$_tag" ] && { red "编号无效！"; menu_pause; return; }
    else
        _tag="$_del_input"
        _del_type=$(jq -r --arg tag "$_tag" '.outbounds[]? | select(.tag == $tag) | .type' "$SINGBOX_FOLDER_PATH/sb.json" 2>/dev/null)
        [ -z "$_del_type" ] && { red "标签 '$_tag' 不存在！"; menu_pause; return; }
        if [ "$_del_type" != "socks" ] && [ "$_del_type" != "http" ]; then
            red "'$_tag' 不是 socks/http 代理出站，不可删除！"
            menu_pause; return
        fi
    fi
    [ "$_tag" = "wireguard-out" ] && { red "wireguard-out 为系统内置，不可删除！"; menu_pause; return; }

    # 检查该代理是否正被协议/分流规则使用
    _used_inbound=$(jq -r --arg tag "$_tag" '
        [.route.rules[]? | select(.inbound != null and .outbound == $tag) | .inbound[]?] | join(", ")
    ' "$SINGBOX_FOLDER_PATH/sb.json" 2>/dev/null)
    _used_rule=$(jq -r --arg tag "$_tag" '
        [.route.rules[]? | select(.rule_set != null and .outbound == $tag) | .rule_set[]?] | join(", ")
    ' "$SINGBOX_FOLDER_PATH/sb.json" 2>/dev/null)
    if [ -n "$_used_inbound" ] || [ -n "$_used_rule" ]; then
        echo ""
        yellow "⚠️  该代理当前正在被以下对象使用："
        [ -n "$_used_inbound" ] && yellow "    附着协议: ${_used_inbound}"
        [ -n "$_used_rule" ] && yellow "    分流规则: ${_used_rule}"
        echo ""
        yellow "删除后将自动解除这些关联（相关协议/服务改走服务器原IP出站）。"
        reading "确认删除该被使用中的代理？(y/n，直接回车=否): " _del_confirm
        if ! [[ "$_del_confirm" =~ ^[yY]$ ]]; then
            green "已取消删除，未做任何修改。"; menu_pause; return
        fi
    fi

    jq --arg tag "$_tag" 'del(.outbounds[] | select(.tag == $tag))' "$SINGBOX_FOLDER_PATH/sb.json" > "$SINGBOX_FOLDER_PATH/.sb.tmp" && mv "$SINGBOX_FOLDER_PATH/.sb.tmp" "$SINGBOX_FOLDER_PATH/sb.json"
    # 同步删除引用该出站的分流规则
    jq --arg tag "$_tag" '
        . as $doc
        | ($doc.route.rules // []) as $R
        | ($R | map(select(.action == "sniff"))) as $sniff
        | ($R | map(select(.action == "resolve"))) as $resolve
        | ($R | map(select(.action != "sniff" and .action != "resolve"))) as $splits
        | $doc
        | .route.rules = $sniff + ([$splits[] | select(.outbound != $tag)]
            | sort_by(if .rule_set != null then 0 elif .inbound != null then 1 else 2 end)) + $resolve
    ' "$SINGBOX_FOLDER_PATH/sb.json" > "$SINGBOX_FOLDER_PATH/.sb.tmp2" && mv "$SINGBOX_FOLDER_PATH/.sb.tmp2" "$SINGBOX_FOLDER_PATH/sb.json"
    rt_remove_unused_rule_sets
    sbrestart
    green "$_tag 代理出站已删除。"
    menu_pause
}

# 设置 socks/http 出站附着的协议（生成 inbound 路由规则，多选，0=清除全部关联，回车=取消）
# 编号与安装时一致且按字母升序：a=全选 b=VLESS c=Hysteria2 d=TUIC e=AnyTLS f=Vmess-WS g=Trojan-WS h=Vless-WS
attach_socks5_proxy() {
     local sbj="$SINGBOX_FOLDER_PATH/sb.json"
     local _tag="$1" _parent="${2:-3}"
     local _letters=(b c d e f g h) _ptags=(vless-reality-vision-sb hy2-sb tuic-sb anytls-sb vmess-sb trojan-ws-sb vless-ws-sb)
     local _protos=() _letters_all _attached _attach_input _selected=() _failed=() _n _p _conflict _inbs
     clear
     green "========= [5][${_parent}] 分流管理 → 附着协议到代理 ========="
     echo ""
     yellow "  提示: 网站分流 > 协议附着代理 > 原IP直连（分流优先，分流不中才走此处附着）"
     echo ""
     for _n in "${!_letters[@]}"; do
         if jq -e --arg t "${_ptags[$_n]}" '.inbounds[]? | select(.tag == $t)' "$sbj" >/dev/null 2>&1; then
             _protos+=("${_letters[$_n]}:${_ptags[$_n]}")
         fi
     done
     if [ ${#_protos[@]} -eq 0 ]; then
         yellow "未检测到已安装的协议入站（tuic/hy2/vmess/vless 等）。"; menu_pause; return
     fi

     echo ""
     _attached=$(jq -r --arg tag "$_tag" '.route.rules[]? | select(.inbound != null and .outbound == $tag) | .inbound[]?' "$sbj" 2>/dev/null)
     if [ -n "$_attached" ]; then
         green "$_tag 当前附着的协议:"
         echo "$_attached" | while read -r _p; do green "  - $_p"; done
     else
         yellow "$_tag 当前未附着任何协议"
     fi

     echo ""
     green "可附着的已安装协议:"
     for _n in "${!_protos[@]}"; do
         green "  ${_protos[$_n]%%:*}) ${_protos[$_n]#*:}"
     done
     echo ""
     yellow "输入要附着的协议编号（多选用空格分隔，a=全选，0=清除全部关联，直接回车=取消）:"
     reading "请输入: " _attach_input
     [ -z "$_attach_input" ] && { yellow "已取消，未做任何修改。"; menu_pause; return; }
     _attach_input=$(echo "$_attach_input" | tr ',' ' ' | tr '[:upper:]' '[:lower:]')
     if [ "$_attach_input" = "0" ]; then
         _inbs="[]"
     else
         _letters_all=""
         for _entry in "${_protos[@]}"; do _letters_all="$_letters_all ${_entry%%:*}"; done
         for _n in $_attach_input; do
             [ "$_n" = "a" ] && { _attach_input="$_attach_input $_letters_all"; break; }
         done
         _failed=()
         for _n in $_attach_input; do
             _p=""
             for _entry in "${_protos[@]}"; do
                 [ "${_entry%%:*}" = "$_n" ] && { _p="${_entry#*:}"; break; }
             done
             if [ -z "$_p" ]; then
                 _failed+=("$_n")
                 continue
             fi
             _conflict=$(jq -r --arg p "$_p" --arg tag "$_tag" '
                 [.route.rules[]? | select(.inbound != null and .outbound != $tag and (.inbound | index($p))) | .outbound]
                 | .[0] // empty' "$sbj" 2>/dev/null)
             if [ -n "$_conflict" ]; then
                 red "❌ ${_p} 附着失败：已被代理 '${_conflict}' 占用（一个协议只能附着到一个代理）"
                 _failed+=("$_p")
             else
                 _selected+=("$_p")
             fi
         done
         if [ ${#_selected[@]} -eq 0 ]; then
             red "❌ 附着失败，未做任何修改。"
             [ ${#_failed[@]} -gt 0 ] && yellow "  未附着: ${_failed[*]}"
             menu_pause; return
         fi
         _inbs=$(printf '%s\n' "${_selected[@]}" | jq -R . | jq -s .)
     fi

    # 删除该出站旧的 inbound 规则，写入新的（空数组 = 只清除关联）
    if jq --arg tag "$_tag" --argjson inbs "$_inbs" '
        . as $doc
        | ($doc.route.rules // []) as $R
        | ($R | map(select(.action == "sniff"))) as $sniff
        | ($R | map(select(.action == "resolve"))) as $resolve
        | ($R | map(select(.action != "sniff" and .action != "resolve" and (.inbound == null or .outbound != $tag)))) as $splits
        | $doc
        | if ($inbs | length) > 0 then
            .route.rules = $sniff + ($splits + [{inbound: $inbs, outbound: $tag}]
                | sort_by(if .rule_set != null then 0 elif .inbound != null then 1 else 2 end)) + $resolve
          else
            .route.rules = $sniff + $splits + $resolve
          end
    ' "$sbj" > "$SINGBOX_FOLDER_PATH/.sb.tmp" && mv "$SINGBOX_FOLDER_PATH/.sb.tmp" "$sbj"; then
        sbrestart
        if [ "$_attach_input" = "0" ]; then
            green "✅ $_tag 关联已清除"
        else
            green "✅ $_tag 已附着到: ${_selected[*]}"
        fi
        if [ ${#_failed[@]} -gt 0 ]; then
            yellow "⚠️ 以下协议未附着（已跳过）: ${_failed[*]}"
        fi
    else
        red "❌ 写入 sb.json 失败，配置未更新，请检查磁盘空间或权限。"
    fi
}

# 选择一个 socks/http 出站，重新设置它附着的协议
edit_socks5_proxy() {
     local sbj="$SINGBOX_FOLDER_PATH/sb.json"
     local _out_list _edit_input _tag _e_type
     clear
     green "========= [5][4] 分流管理 → 修改 Socks5/HTTP 出站关联的协议 ========="
     echo ""
     green "当前 socks/http 代理出站（可修改关联协议）:"
    _out_list=$(jq -r '[.outbounds[]? | select(.type == "socks" or .type == "http")] | to_entries | .[] | "\(.key+1). \(.value.tag) [\(.value.type)]"' "$sbj" 2>/dev/null)
    [ -z "$_out_list" ] && { yellow "没有可修改的 socks/http 代理出站。"; menu_pause; return; }
    echo "$_out_list"
    echo ""
    reading "输入要修改的代理编号或标签: " _edit_input
    if [[ "$_edit_input" =~ ^[0-9]+$ ]]; then
        _tag=$(jq -r --arg idx "$_edit_input" '.outbounds | map(select(.type == "socks" or .type == "http")) | .[($idx | tonumber)-1].tag // empty' "$sbj")
        [ -z "$_tag" ] && { red "编号无效！"; menu_pause; return; }
    else
        _tag="$_edit_input"
        _e_type=$(jq -r --arg tag "$_tag" '.outbounds[]? | select(.tag == $tag) | .type' "$sbj" 2>/dev/null)
        if [ -z "$_e_type" ]; then
            red "标签 '$_tag' 不存在！"; menu_pause; return
        elif [ "$_e_type" != "socks" ] && [ "$_e_type" != "http" ]; then
            red "'$_tag' 不是 socks/http 代理出站，不可修改！"; menu_pause; return
        fi
    fi
    attach_socks5_proxy "$_tag" 4
}

# 设置全局代理出站（所有流量走指定 socks/http 代理）
set_global_outbound() {
    local sbj="$SINGBOX_FOLDER_PATH/sb.json"
    local proxy_tags _out_choice _selected_out _strat
    proxy_tags=($(jq -r '.outbounds[]? | select(.tag != "direct" and .tag != "block" and .tag != "wireguard-out") | .tag' "$sbj" 2>/dev/null))

    if [ ${#proxy_tags[@]} -eq 0 ]; then
        yellow "当前没有可用的 socks5/http 代理出站。"
        yellow "请先返回 → 设置分流服务 → 添加 Socks5/HTTP 出站，再设置全局代理。"
        menu_pause; add_rule_menu; return
    fi

    echo ""
    green "请选择全局代理出站:"
    for i in "${!proxy_tags[@]}"; do
        green "  $((i+1)). ${proxy_tags[$i]}"
    done
    echo ""
    reading "请输入编号: " _out_choice
    if [[ ! "$_out_choice" =~ ^[0-9]+$ ]] || \
       [ "$_out_choice" -lt 1 ] || \
       [ "$_out_choice" -gt "${#proxy_tags[@]}" ]; then
        red "无效选择"; menu_pause; add_rule_menu; return
    fi
    _selected_out="${proxy_tags[$((_out_choice-1))]}"

    # 清空分流规则并让 final 指向代理，实现"所有流量走代理"
    _strat="$(rt_get_strategy)"
    [ -z "$_strat" ] && _strat="prefer_ipv6"
    jq --arg out "$_selected_out" --arg strat "$_strat" '
        .route.final = $out
        | .route.rules = [{action: "sniff"}, {action: "resolve", strategy: $strat}]
    ' "$sbj" > "$SINGBOX_FOLDER_PATH/.sb.tmp" && mv "$SINGBOX_FOLDER_PATH/.sb.tmp" "$sbj"
    sbrestart
    green "已设置全局代理出站：$_selected_out"
    yellow "所有流量将通过 $_selected_out 转发，如需恢复请选择「恢复服务器原IP出站」"
    menu_pause
}

# 恢复服务器原IP出站（final 回 direct，保留/复位默认 sniff+resolve 规则）
restore_direct_outbound() {
    local sbj="$SINGBOX_FOLDER_PATH/sb.json" _strat _sip
    yellow "正在恢复默认路由配置..."

    # 确保 direct 出站存在（不存在则插入到数组最前面）
    if ! jq -e '.outbounds[]? | select(.tag == "direct")' "$sbj" > /dev/null 2>&1; then
        jq '.outbounds = [{"type": "direct", "tag": "direct"}] + .outbounds' \
            "$sbj" > "$SINGBOX_FOLDER_PATH/.sb.tmp" && mv "$SINGBOX_FOLDER_PATH/.sb.tmp" "$sbj"
    fi

    _strat="$(rt_get_strategy)"
    [ -z "$_strat" ] && _strat="prefer_ipv6"
    jq --arg strat "$_strat" '
        .route.final = "direct"
        | .route.rules = [{action: "sniff"}, {action: "resolve", strategy: $strat}]
    ' "$sbj" > "$SINGBOX_FOLDER_PATH/.sb.tmp" && mv "$SINGBOX_FOLDER_PATH/.sb.tmp" "$sbj"
    sbrestart
    _sip=$(cat "$SINGBOX_FOLDER_PATH/server_ip" 2> /dev/null)
    if [ -n "$_sip" ]; then
        green "已恢复服务器原IP出站（${_sip}），所有流量走 direct。"
    else
        green "已恢复服务器原IP出站，所有流量走 direct。"
    fi
    menu_pause
}

interactive_main() {
    local _ch
    geo_prefetch
    while true; do
        clear
        showmode
        menu_status_block
        echo ""
        yellow "  【安 装】"
        green "    [1] 安装节点"
        green "    [2] 覆盖式安装/重置 (rep)"
        echo ""
        yellow "  【管 理】"
        green "    [3] 服务管理"
        green "    [4] 节点配置修改 (node)"
        green "    [5] 分流管理 (rt)"
        green "    [6] sb 快捷命令 (sc)"
        echo ""
        yellow "  【查 看】"
        green "    [7] 查看节点信息 (list)"
        green "    [8] 查看运行状态"
        green "    [9] 订阅管理 (sub)"
        echo ""
        yellow "  【日 志】"
        green "    [10] 查看日志 (logs)"
        echo ""
        red   "  【危险操作】"
        red   "    [11] 卸载 (del, 保留二进制)"
        red   "    [12] 卸载全部并清理 (delall)"
        echo ""
        purple "    [0] 退出"
        echo ""
        reading "  请输入选项: " _ch
        case "$_ch" in
            0|q|Q) echo "再见 👋"; exit 0 ;;
            1) interactive_install; menu_pause ;;
            2) interactive_reinstall; menu_pause ;;
            3) interactive_service_menu ;;
            4) node_config_menu ;;
            5) rt_manage ;;
            6) interactive_sb_shortcut_menu ;;
            7) cip; menu_pause ;;
            8) menu_status_block; show_local_ip_info_with_out_ip_hint; menu_pause ;;
            9) interactive_sub_menu ;;
            10) interactive_log_menu ;;
            11)
                reading "确认卸载? (y/N): " _ch
                if [ "$_ch" = "y" ] || [ "$_ch" = "Y" ]; then
                    cleandel
                    green "✅ 已卸载 (保留二进制)"
                fi
                menu_pause ;;
            12)
                reading "确认卸载全部并清理? (y/N): " _ch
                if [ "$_ch" = "y" ] || [ "$_ch" = "Y" ]; then
                    cleandel delall
                    green "✅ 已卸载全部并清理"
                    echo "再见 👋"
                    exit 0
                fi
                menu_pause ;;
            *) yellow "无效选项"; sleep 1 ;;
        esac
    done
}
# ================== 交互式菜单模式 END ==================

main() {

    # 日志目录迁移（老版本散落在 doraemon 根目录的日志归拢到 logs/）
    migrate_logs_dir

    # 命令转小写，支持大小写不敏感
    local _cmd
    _cmd="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')"

    # 端口冲突检查仅在安装/覆盖安装时进行（维护命令如 del/list/sub 不受端口参数影响）
    if [ "$_cmd" = "ins" ] || [ "$_cmd" = "rep" ]; then
        check_port_conflicts_or_exit
    fi

    # 启动自定义端口
    if [ "$_cmd" = "autostart" ]; then
        enable_autostart
        exit
    fi

    # 启动自定义端口
    if [ "$_cmd" = "autostart_off" ]; then
        disable_autostart
        exit
    fi

    # 启动 nginx
    if [ "$_cmd" = "nginx_start" ]; then
        nginx_start
        green "Nginx 已完成启动操作！"
        nginx_status
        exit
    fi

    # 停止 nginx
    if [ "$_cmd" = "nginx_stop" ]; then
        nginx_stop
        green "Nginx 已完成停止操作！"
        nginx_status
        exit
    fi

    # 重启 nginx
    if [ "$_cmd" = "nginx_restart" ]; then
        nginx_restart
        green "Nginx 已完成重启操作！"
        nginx_status
        exit
    fi

    # 查看 nginx 状态
    if [ "$_cmd" = "nginx_status" ]; then
        nginx_status
        exit
    fi

    # 查看日志菜单
    if [ "$_cmd" = "logs" ]; then
        interactive_log_menu
        exit
    fi

    # 查看 Sing-box 运行日志（可带行数：sb log_sb 50）
    if [ "$_cmd" = "log_sb" ]; then
        show_log_file "$LOGS_DIR/singbox.log" "Sing-box 日志" "暂无日志：$LOGS_DIR/singbox.log" "${2:-100}"
        exit
    fi

    # 查看 Argo 隧道日志（可带行数）
    if [ "$_cmd" = "log_argo" ]; then
        show_log_file "$LOGS_DIR/argo.log" "Argo (cloudflared) 日志" "暂无日志：$LOGS_DIR/argo.log" "${2:-100}"
        exit
    fi

    # 查看脚本安装日志（直接显示全文）
    if [ "$_cmd" = "log_ins" ]; then
        local _log="$LOGS_DIR/install.log"
        if [ -s "$_log" ]; then
            green "=== 脚本安装日志（仅保留最近一次安装） ==="
            cat "$_log"
        else
            yellow "暂无安装日志：执行 ins/rep 或菜单安装后自动生成"
        fi
        exit
    fi

    # 查看服务停止原因日志
    if [ "$_cmd" = "log_stop" ]; then
        show_log_file "$LOGS_DIR/stop_reason.log" "服务停止原因日志" "暂无停止记录：服务运行正常时不会产生记录" "${2:-100}"
        exit
    fi

    # 卸载服务
    if [ "$_cmd" = "delall" ]; then
        cleandel "delall"
        echo "卸载完成（全部删除）"
        showmode
        exit
    fi

    if [ "$_cmd" = "del" ]; then
        cleandel
        echo "卸载完成（二进制已保留）"
        showmode
        exit
    fi

    # 查看可用的节点
    if [ "$_cmd" = "list" ]; then
        geo_prefetch
        cip "$2"
        exit
    fi
    # 更新sing-box内核
    if [ "$_cmd" = "ups" ]; then
        geo_prefetch
        pkill -15 -f "$SINGBOX_FOLDER_PATH/sing-box" 2> /dev/null

        update_singbox && sbrestart && echo "Sing-box内核更新完成" && sleep 2 && cip
        exit
    fi
    # 重启sing-box和cloudflared
    if [ "$_cmd" = "res" ]; then
        geo_prefetch
        sbrestart
        argorestart
        sleep 5 && echo "重启完成" && sleep 3 && cip
        exit
    fi

    # 生成/更新/查看订阅文件
    if [ "$_cmd" = "sub" ]; then
        # 重新生成 jh.txt 节点链接 + sub.txt 订阅（函数内部会打印 subscribe 状态 + 生成结果）
        regenerate_links_and_sub

        echo -e "📌 节点订阅地址："
        if ! is_true "$(get_subscribe_flag)"; then
            purple "⛔ 未开启订阅"
        else
            u="$(show_sub_url)"
            green "$u"
            echo
        fi

        exit
    fi

    # 覆盖式安装（全流程记录：geo预取 + 卸载清理 + 安装）
    if [ "$_cmd" = "rep" ]; then
        _rep_flow_cli() {
            geo_prefetch
            green "开始覆盖式安装流程..."
            green "1、即将开始清理操作（保留二进制）..."
            cleandel
            green "1.1、清理操作完成..."
            sleep 2

            green "2、覆盖式安装开始..."
            install_step
            echo "覆盖式安装已完成... 再见👋"
        }
        run_install_logged "命令行 rep 覆盖式安装（含卸载清理）" _rep_flow_cli
        exit
    fi

    # 只在明确 ins 时才安装；无参数只显示菜单（全流程记录：geo预取 + 安装）
    if [ "$_cmd" = "ins" ]; then
        _ins_flow_cli() {
            geo_prefetch
            yellow "开始安装流程..."
            install_step
        }
        run_install_logged "命令行 ins 安装" _ins_flow_cli
        exit
    fi

    # 无参数 或 menu 命令：进入交互式菜单
    if [ -z "$1" ] || [ "$_cmd" = "menu" ]; then
        interactive_main
        exit
    fi

    # 分流管理
    if [ "$_cmd" = "rt" ] || [ "$_cmd" = "rule" ]; then
        rt_manage
        exit
    fi

    # 节点配置修改（端口/订阅/SNI/Argo）
    if [ "$_cmd" = "node" ] || [ "$_cmd" = "nc" ]; then
        node_config_menu
        exit
    fi

    # 创建/刷新 sb 快捷命令
    if [ "$_cmd" = "sc" ] || [ "$_cmd" = "shortcut" ]; then
        ensure_sb_shortcut
        exit
    fi

    # 清理 sb 快捷命令
    if [ "$_cmd" = "sc_off" ] || [ "$_cmd" = "shortcut_off" ]; then
        cleanup_sb_shortcut
        exit
    fi

    # 无效命令提示
    echo
    red "❌ 无效命令：$1"
    yellow "可用命令：menu / ins / rep / del / delall / list / sub / res / ups / rt / node / sc / sc_off / autostart / autostart_off / nginx_start / nginx_stop / nginx_restart / nginx_status"
    showmode
    exit 1

}

main "$@"