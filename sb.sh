
#!/usr/bin/env bash
export LANG=en_US.UTF-8

# 颜色（仅在本函数内使用，避免外部未定义）

 # ================== 颜色函数 ==================
white(){ echo -e "\033[1;37m$1\033[0m"; }
red(){ echo -e "\e[1;91m$1\033[0m"; }
green(){ echo -e "\e[1;32m$1\033[0m"; }
yellow(){ echo -e "\e[1;33m$1\033[0m"; }
blue(){ echo -e "\e[1;34m$1\033[0m"; }
purple(){ echo -e "\e[1;35m$1\033[0m"; }

is_true() {
  [ "$(printf '%s' "${1:-}" | tr 'A-Z' 'a-z')" = "true" ]
}

get_subscribe_flag() {
  # 优先读落盘值（避免用户不带环境变量执行 agsb sub 时失效）
  if [ -s "$HOME/agsb/subscribe" ]; then
    cat "$HOME/agsb/subscribe"
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

need_argo() { [ "$argo" = "vmpt" ] || [ "$argo" = "trpt" ]; }

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


install_deps() {


    local RED="\033[31m"
    local GREEN="\033[32m"
    local YELLOW="\033[33m"
    local RESET="\033[0m"

    # 等待 apt/dpkg 锁的最大秒数（默认 180 秒，可通过环境变量覆盖）
    local max_wait="${APT_LOCK_WAIT:-180}"

    echo -e "${YELLOW}正在安装依赖...${RESET}"

    # =========================
    # 依赖包（❗注意：nginx不要在这里暴力安装，因为不是所有场景都要安装nginx的）
    # =========================
    # 公共依赖（各发行版基本一致）
    local COMMON_PKGS=(
        curl 
        wget 
        jq 
        openssl
        iptables 
        bc 
        lsof
        psmisc
        
    )

    # Debian/Ubuntu
    local APT_PKGS=(
        "${COMMON_PKGS[@]}"
        uuid-runtime
        cron
        netfilter-persistent
    )

    # CentOS/RHEL/Fedora（yum/dnf）
    local YUM_DNF_PKGS=(
        "${COMMON_PKGS[@]}"
        util-linux
        cronie
    )

    # Alpine
    local APK_PKGS=(
        "${COMMON_PKGS[@]}"
        util-linux
        cronie
    )

    # =========================
    # Debian / Ubuntu
    # =========================
    if command -v apt-get >/dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive

        # 等待 apt/dpkg 锁（避免死等）
        local waited=0
        if command -v fuser >/dev/null 2>&1; then
            while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || \
                  fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
                waited=$((waited + 1))
                if [ "$waited" -ge "$max_wait" ]; then
                    echo -e "${RED}❌ apt/dpkg 正在被占用超过 ${max_wait} 秒，退出。${RESET}"
                    echo -e "${YELLOW}可能原因：apt-daily / unattended-upgrades 正在后台运行${RESET}"
                    echo -e "${YELLOW}你可以尝试：${RESET}"
                    echo -e "  ${YELLOW}sudo systemctl stop apt-daily.service apt-daily.timer 2>/dev/null${RESET}"
                    echo -e "  ${YELLOW}sudo systemctl stop unattended-upgrades 2>/dev/null${RESET}"
                    echo -e "${YELLOW}或者等待后台更新结束后再运行脚本${RESET}"
                    echo -e "${YELLOW}也可以临时加大等待时间：${RESET}${GREEN}APT_LOCK_WAIT=600 bash sb.sh${RESET}"
                    exit 1
                fi
                sleep 1
            done
        else
            echo -e "${YELLOW}❗ 未检测到 fuser（psmisc），跳过 dpkg 锁检测${RESET}"
        fi

        echo -e "${YELLOW}正在执行 apt-get update...${RESET}"
        apt-get -o Acquire::Retries=3 \
                -o Acquire::http::Timeout=15 \
                -o Acquire::https::Timeout=15 \
                update || {
            echo -e "${RED}❌ apt-get update 失败（可能是 DNS / 网络 / 源不可用）${RESET}"
            exit 1
        }

        echo -e "${YELLOW}正在安装依赖包...${RESET}"
        apt-get -o Acquire::Retries=3 \
                -o Acquire::http::Timeout=15 \
                -o Acquire::https::Timeout=15 \
                install -y "${APT_PKGS[@]}" || {
            echo -e "${RED}❌ Debian/Ubuntu 依赖安装失败${RESET}"
            exit 1
        }

    # =========================
    # CentOS / RHEL (yum)
    # =========================
    elif command -v yum >/dev/null 2>&1; then
        echo -e "${YELLOW}正在使用 yum 安装依赖...${RESET}"
        yum install -y "${YUM_DNF_PKGS[@]}" || {
            echo -e "${RED}❌ CentOS/RHEL 依赖安装失败${RESET}"
            exit 1
        }

    # =========================
    # Fedora / RHEL (dnf)
    # =========================
    elif command -v dnf >/dev/null 2>&1; then
        echo -e "${YELLOW}正在使用 dnf 安装依赖...${RESET}"
        dnf install -y "${YUM_DNF_PKGS[@]}" || {
            echo -e "${RED}❌ Fedora/RHEL 依赖安装失败${RESET}"
            exit 1
        }

    # =========================
    # Alpine (apk)
    # =========================
    elif command -v apk >/dev/null 2>&1; then
        echo -e "${YELLOW}正在使用 apk 安装依赖...${RESET}"
        apk add --no-cache "${APK_PKGS[@]}" || {
            echo -e "${RED}❌ Alpine 依赖安装失败${RESET}"
            exit 1
        }

    else
        echo -e "${RED}❌ 未检测到支持的包管理器（apt/yum/dnf/apk）${RESET}"
        exit 1
    fi

    echo -e "${GREEN}✅ 依赖安装完成${RESET}"
}


# Environment variables for controlling CDN host and SNI values
export cdn_host=${cdn_host:-"cdn.7zz.cn"}  # Default CDN host for vmess or trojan  www.visa.com
export hy_sni=${hy_sni:-"www.bing.com"}    # Default SNI for hy2 protocol
export vl_sni=${vl_sni:-"www.ua.edu"}   # Default SNI for vless protocol   www.ua.edu www.yahoo.com
export tu_sni=${tu_sni:-"www.bing.com"}    # Default SNI for hy2 protocol


# Environment variables for ports and other settings
export uuid=${uuid:-''}; 
export port_vm_ws=${vmpt:-''}; 
export port_tr=${trpt:-''}; 
export port_hy2=${hypt:-''}; 
export port_vlr=${vlrt:-''}; 
export port_tu=${tupt:-''}; 

# 获取到的IP和出口ip不一样的时候，优先使用出口ip也就是out_ip
export out_ip=${out_ip:-''};

export argo=${argo:-''}; 
export ARGO_DOMAIN=${agn:-''}; 
export ARGO_AUTH=${agk:-''}; 
export ippz=${ippz:-''}; 
export name=${name:-''}; 

readonly NGINX_DEFAULT_PORT=8080
readonly ARGO_DEFAULT_PORT=8001

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

cdn_pt="${cdn_pt:-443}"
vl_sni_pt="${vl_sni_pt:-443}"


v46url="https://icanhazip.com"
agsburl="https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh"

CN_BING="www.bing.com"

v4_ok=false
v6_ok=false

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

# ================== 系统bashrc函数 ==================
# Create .bashrc file if missing
create_bashrc_if_missing() {
  if [ ! -f "$HOME/.bashrc" ]; then
    yellow "检测到系统缺失$HOME/.bashrc 文件,即将创建 $HOME/.bashrc 文件..."
    touch "$HOME/.bashrc"
    chmod 644 "$HOME/.bashrc"

    echo "$HOME/.bashrc 文件已创建并设置了权限"
  
  fi
}

create_bashrc_if_missing

# ================== 系统bashrc函数 ==================
VERSION="1.0.4(2026-01-26)"
AUTHOR="littleDoraemon"


# Ensure agsb shortcut

ensure_agsb_shortcut() {
  local wrapper="$HOME/agsb/agsb"
  local link_sys1="/usr/local/bin/agsb"
  local link_sys2="/usr/bin/agsb"
  local link_home="$HOME/bin/agsb"

  mkdir -p "$HOME/agsb" "$HOME/bin"

  # ✅ Alpine 最小系统可能没有 bash，提前检查
  if ! command -v bash >/dev/null 2>&1; then
    yellow "⚠️ 检测到系统未安装 bash，agsb 快捷命令需要 bash 才能运行"
    yellow "👉 Alpine 请先执行：apk add --no-cache bash"
    # 不直接 exit，继续创建文件（用户装好 bash 后立刻可用）
  fi

  # wrapper：优先本地脚本，否则在线拉取 agsburl
  cat > "$wrapper" <<EOF
#!/usr/bin/env bash
set -e
LOCAL_SCRIPT="$HOME/agsb/sb000.sh"

if [ -s "\$LOCAL_SCRIPT" ]; then
  exec bash "\$LOCAL_SCRIPT" "\$@"
else
  exec bash <(curl -Ls "$agsburl") "\$@"
fi
EOF
  chmod +x "$wrapper"

  # home 链接兜底
  ln -sf "$wrapper" "$link_home"
  chmod +x "$link_home"

  # ✅关键：系统目录（立刻生效）
  if [ "$(id -u)" -eq 0 ]; then
    # Alpine 有时 /usr/local/bin 不存在，创建它
    [ -d "/usr/local/bin" ] || mkdir -p /usr/local/bin 2>/dev/null

    if [ -d "/usr/local/bin" ] && [ -w "/usr/local/bin" ]; then
      ln -sf "$wrapper" "$link_sys1"
      chmod +x "$link_sys1"
    elif [ -d "/usr/bin" ] && [ -w "/usr/bin" ]; then
      ln -sf "$wrapper" "$link_sys2"
      chmod +x "$link_sys2"
    fi
  fi

  # 脚本进程内刷新 PATH（让脚本内部后续也能直接调用 agsb）
  export PATH="/usr/local/bin:/usr/bin:$HOME/bin:$PATH"
  hash -r 2>/dev/null || true

  # 写入 bashrc（下次登录兜底）
  if ! grep -qs 'export PATH="\$HOME/bin:\$PATH"' "$HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
  fi

  # ✅你要求的“用代码实现 source ~/.bashrc”
  if [ -n "$BASH_VERSION" ] && [ -f "$HOME/.bashrc" ]; then
    # shellcheck disable=SC1090
    source "$HOME/.bashrc" 2>/dev/null || true
  fi

  # 输出状态
  if command -v agsb >/dev/null 2>&1; then
    green "✅ 已创建快捷命令：agsb（已可用：$(command -v agsb)）"
    echo -e "👉 例如：agsb list / agsb rep / agsb del"
  else
    yellow "⚠️ 已创建快捷命令 agsb，但当前环境未识别到命令"
    yellow "👉 若 Alpine 未装 bash：apk add --no-cache bash"
  fi
}

cleanup_agsb_shortcut() {
  local wrapper="$HOME/agsb/agsb"
  local link_sys1="/usr/local/bin/agsb"
  local link_sys2="/usr/bin/agsb"
  local link_home="$HOME/bin/agsb"

  # 1) 删除快捷命令入口（系统级 + 用户级）
  rm -f "$link_sys1" "$link_sys2" "$link_home" 2>/dev/null
  rm -f "$wrapper" 2>/dev/null

  # 2) bashrc 清理（下次登录也不再出现）
  if [ -f "$HOME/.bashrc" ]; then
    # 清理：export PATH="$HOME/bin:$PATH"
    sed -i '/export PATH="\$HOME\/bin:\$PATH"/d' "$HOME/.bashrc" 2>/dev/null || true
  fi

  # 3) 立刻失效：刷新 shell 命令缓存（Debian/Alpine 都适用）
  # hash -r 是 bash 内建，command -v hash 成功说明当前shell支持
  hash -r 2>/dev/null || true
  command -v rehash >/dev/null 2>&1 && rehash 2>/dev/null || true

  # 4) 你要求的：用代码实现 “source ~/.bashrc”
  # 注意：只有当脚本是 source 执行时，才会影响当前终端环境；否则仅影响脚本进程本身
  if [ -n "$BASH_VERSION" ] && [ -f "$HOME/.bashrc" ]; then
    # shellcheck disable=SC1090
    source "$HOME/.bashrc" 2>/dev/null || true
    hash -r 2>/dev/null || true
  fi

  # 5) 输出确认：确保“当前进程内”已经不可用
  if command -v agsb >/dev/null 2>&1; then
    yellow "⚠️ 已执行清理，但当前环境仍能找到 agsb：$(command -v agsb)"
    yellow "👉 可能是你当前终端 PATH 里还有别的 agsb（例如你自己手动放过）"
    yellow "👉 你可以执行：which -a agsb 查看残留来源"
  else
    green "✅ 快捷命令 agsb 已清理（当前环境已立即失效）"
  fi
}





# Show script mode
showmode(){
    blue "===================================================="
    gradient "       singbox 一键脚本（vmess/trojan Argo选1,vless+hy2+tuic 3个直连）"
    green    "       作者：$AUTHOR"
    yellow   "       版本：$VERSION"
    blue "===================================================="
 
    yellow "主脚本：bash <(curl -Ls ${agsburl}) 或 bash <(wget -qO- ${agsburl})"
    yellow "显示节点信息：agsb list"
    yellow "安装命令： agsb或者 agsb ins（命令前面需要带上环境变量）"
    yellow "覆盖式安装命令： agsb rep（命令前面需要带上环境变量）"
    yellow "更新Singbox内核：agsb ups(属于预留命令)"
    yellow "重启脚本：agsb res(重启singbox和argo)"
    yellow "卸载脚本：agsb del"
    yellow "Nginx相关：agsb nginx_start | nginx_stop | nginx_restart | nginx_status"
    echo "---------------------------------------------------------"
}

install_nginx_pkg() {
  # 已安装就不重复装
  if command -v nginx >/dev/null 2>&1; then
    return 0
  fi

  yellow "👉 正在安装 Nginx..."

  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y >/dev/null 2>&1
    DEBIAN_FRONTEND=noninteractive apt-get install -y nginx >/dev/null 2>&1 || return 1

  elif command -v apt >/dev/null 2>&1; then
    apt update -y >/dev/null 2>&1
    DEBIAN_FRONTEND=noninteractive apt install -y nginx >/dev/null 2>&1 || return 1

  elif command -v yum >/dev/null 2>&1; then
    yum install -y nginx >/dev/null 2>&1 || return 1

  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y nginx >/dev/null 2>&1 || return 1

  elif command -v apk >/dev/null 2>&1; then
    apk add --no-cache nginx >/dev/null 2>&1 || return 1

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

    [ -z "$auth" ] && return

    # ---------- JSON 凭据 ----------
    if echo "$auth" | grep -q 'TunnelSecret'; then
        yellow "检测到 Argo JSON 凭据，使用 credentials-file 模式"

        if [ -z "$local_port" ]; then
            red "❌ prepare_argo_credentials: LOCAL_PORT 为空"
            return 1
        fi

        mkdir -p "$HOME/agsb"

        # 写入 tunnel.json
        #❗ 如果 ARGO_AUTH 里的 JSON 含有 \n、\r、\uXXXX 之类，echo 在某些 shell/实现里可能会解释转义，导致 tunnel.json 内容被破坏。 改法：用 printf 更可靠
        printf '%s' "$auth" > "$HOME/agsb/tunnel.json"


        # 提取 TunnelID
        local tunnel_id
        tunnel_id=$(echo "$auth" | sed -n 's/.*"TunnelID"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

        if [ -z "$tunnel_id" ]; then
            red "❌ Argo JSON 中未找到 TunnelID"
            return 1
        fi

        # 生成 tunnel.yml（对齐 s4.sh）
        cat > "$HOME/agsb/tunnel.yml" <<EOF
tunnel: $tunnel_id
credentials-file: $HOME/agsb/tunnel.json
protocol: http2

ingress:
  - hostname: ${domain}
    service: http://localhost:${local_port}
    originRequest:
      noTLSVerify: true
  - service: http_status:404
EOF

        ARGO_MODE="json"
    else
        # token 模式
        ARGO_MODE="token"
    fi

    export ARGO_MODE
}



# ================== 系统bashrc函数 ==================


echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"; 
echo "agsb一键无交互脚本💣 (Sing-box内核版)";  
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

hostname=$(uname -a | awk '{print $2}'); 
op=$(cat /etc/redhat-release 2>/dev/null || cat /etc/os-release 2>/dev/null | grep -i pretty_name | cut -d \" -f2); 
case $(uname -m) in aarch64) cpu=arm64;; x86_64) cpu=amd64;; *) echo "目前脚本不支持$(uname -m)架构" && exit; esac;
 mkdir -p "$HOME/agsb"
# Check and set IP version
v4v6(){
    # Check IPv4 connectivity
    echo "Checking IPv4 and IPv6 connectivity, ready to get IP..."
    echo "Checking IPv4 connectivity..."
    v4=$(curl -s4 -m5 --connect-timeout 5 -k "$v46url" 2>/dev/null || wget -4 -qO- --tries=2 --timeout=5 "$v46url" 2>/dev/null)
    if [ -n "$v4" ]; then
        v4_ok=true
    else
        v4_ok=false
    fi

    echo "IPv4 connectivity check completed. ipv4=$v4"

    # Check IPv6 connectivity
    echo "Checking IPv6 connectivity..."
    v6=$(curl -s6 -m5 --connect-timeout 5 -k "$v46url" 2>/dev/null || wget -6 -qO- --tries=2 --timeout=5 "$v46url" 2>/dev/null)
    if [ -n "$v6" ]; then
        v6_ok=true
    else
        v6_ok=false
    fi
    echo "IPv6 connectivity check completed. ipv6=$v6"
    echo "IP connectivity check completed. ipv4=$v4, ipv6=$v6"

    
}

# Set up name for nodes and IP version preference
set_sbyx(){
    if [ -n "$name" ]; then
        sxname=$name-
        echo "$sxname" > "$HOME/agsb/name"
        echo
        yellow "所有节点名称前缀：$name"
    fi
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
    out="$HOME/agsb/sing-box"
    (curl -Lo "$out" -# --connect-timeout 5 --max-time 120  --retry 2 --retry-delay 2 --retry-all-errors "$url") || (wget -O "$out" --tries=2 --timeout=120 --dns-timeout=5 --read-timeout=60 "$url")


    # 下载结果校验：防止拿到空文件/错误页导致后续假安装
    if [ ! -s "$out" ]; then
        red "❌ 下载失败：文件为空 $out"
        exit 1
    fi


    chmod +x "$HOME/agsb/sing-box"
    sbcore=$("$HOME/agsb/sing-box" version 2>/dev/null | awk '/version/{print $NF}')
    echo "已安装Sing-box正式版内核：$sbcore"
}
# Generate UUID and save to file
insuuid(){
    if [ ! -e "$HOME/agsb/sing-box" ]; then 
        upsingbox;
    fi

    if [ -z "$uuid" ] && [ ! -e "$HOME/agsb/uuid" ]; then
        uuid=$("$HOME/agsb/sing-box" generate uuid)
        echo "$uuid" > "$HOME/agsb/uuid"
    elif [ -n "$uuid" ]; then
        echo "$uuid" > "$HOME/agsb/uuid"
    fi
    uuid=$(cat "$HOME/agsb/uuid")
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
  local sid_file="${1:-$HOME/agsb/short_id}"
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
      green "✅ short_id 已由 reality_private 稳定推导, 值: $sid" >&2
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

  # 只输出到 stderr，不污染 stdout（stdout 必须保持纯公钥）
  _rk_log() {
    [ "${DEBUG_REALITY:-0}" = "1" ] && echo -e "$*" >&2
  }

  # 私钥为空直接失败
  [ -z "$priv" ] && return 1

  # 1) 优先本地推导（openssl + xxd）
  if command -v xxd >/dev/null 2>&1 && command -v openssl >/dev/null 2>&1; then
    _rk_log "🔐 derive_reality_public_key: 使用【本地推导】(openssl + xxd)"

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
      _rk_log "❗ derive_reality_public_key: 私钥 base64 长度不合法（mod=1）"
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
        _rk_log "❗ derive_reality_public_key: 本地解码失败（base64 -d/-D/openssl base64 均失败）"
        rm -f "$tmp_dir/_x25519_priv_raw" 2>/dev/null
      fi

      # 校验长度必须为 32 bytes
      if [ -s "$tmp_dir/_x25519_priv_raw" ]; then
        local priv_len
        priv_len="$(stat -c%s "$tmp_dir/_x25519_priv_raw" 2>/dev/null || stat -f%z "$tmp_dir/_x25519_priv_raw" 2>/dev/null || echo 0)"

        if [ "$priv_len" != "32" ]; then
          _rk_log "❗ derive_reality_public_key: 本地解码后长度不为 32 bytes（实际=$priv_len）"
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
                _rk_log "✅ derive_reality_public_key: 本地推导成功"

                # 清理临时文件（可选）
                rm -f "$tmp_dir/_x25519_priv_raw" "$tmp_dir/_x25519_priv_der" "$tmp_dir/_x25519_priv_pem" \
                      "$tmp_dir/_x25519_pub_der" "$tmp_dir/_x25519_pub_raw" 2>/dev/null

                echo "$pub"
                return 0
              else
                _rk_log "❗ derive_reality_public_key: 本地推导成功但编码公钥失败（缺少 base64 工具？）"
              fi
            else
              _rk_log "❗ derive_reality_public_key: openssl 推导公钥失败（pkcs8/pkey/pubout）"
            fi
          else
            _rk_log "❗ derive_reality_public_key: xxd 读取私钥失败"
          fi
        fi
      fi
    fi

    _rk_log "❗ derive_reality_public_key: 本地推导失败，准备在线兜底"
  else
    _rk_log "❗ derive_reality_public_key: 缺少 openssl 或 xxd，本地推导不可用"
  fi

  # 2) 在线兜底推导（curl/wget）
  _rk_log "🌐 derive_reality_public_key: 使用【在线推导】(realitykey.cloudflare.now.cc)"

  if command -v curl >/dev/null 2>&1; then
    pub="$(curl -s --max-time 2 "https://realitykey.cloudflare.now.cc/?privateKey=${priv}" \
      | awk -F '"' '/publicKey/{print $4; exit}')"
  elif command -v wget >/dev/null 2>&1; then
    pub="$(wget --no-check-certificate -qO- --tries=3 --timeout=2 "https://realitykey.cloudflare.now.cc/?privateKey=${priv}" \
      | awk -F '"' '/publicKey/{print $4; exit}')"
  else
    _rk_log "❗ derive_reality_public_key: curl/wget 都不存在，在线推导不可用"
    return 1
  fi

  if [ -n "$pub" ]; then
    _rk_log "✅ derive_reality_public_key: 在线推导成功"
    echo "$pub"
    return 0
  fi

  _rk_log "❗ derive_reality_public_key: 在线推导失败（未获取到 publicKey）"
  return 1
}

# ================== Reality Keypair BEGIN ==================

print_reality_keypair_hint() {
  [ "${1:-0}" = "1" ] || return 0
  [ -n "${reality_private:-}" ] || return 0

  echo
  yellow "🔐 Reality 私钥（请保存，后续可将此参数值放在安装参数里，可保持reality协议节点一致）"
  green "reality_private=${reality_private}"
  echo
}


init_reality_keypair() {
  local key_file="$HOME/agsb/reality.key"
  local file_priv="" file_pub=""
  local env_priv="${reality_private:-}"
  local priv="" pub=""
  local print_reality_private=0

  # 日志：只输出到 stderr，不污染 stdout
  _rk_log() {
    [ "${DEBUG_REALITY:-0}" = "1" ] && echo -e "$*" >&2
  }

  _rk_log "🔑 init_reality_keypair: 开始初始化 Reality Keypair..."
  _rk_log "📌 init_reality_keypair: key_file=$key_file"

  # 读取文件中的 keypair（如果存在）
  if [ -f "$key_file" ]; then
    file_priv="$(awk -F': ' '/PrivateKey/{print $2; exit}' "$key_file" 2>/dev/null)"
    file_pub="$(awk -F': ' '/PublicKey/{print $2; exit}' "$key_file" 2>/dev/null)"
    _rk_log "📄 init_reality_keypair: 检测到已有 reality.key（priv=${#file_priv} chars, pub=${#file_pub} chars）"
  else
    _rk_log "📄 init_reality_keypair: 未找到 reality.key（首次安装或文件丢失）"
  fi

  # A) 用户传入了 reality_private（最高优先级）
  if [ -n "$env_priv" ]; then
    _rk_log "🧩 init_reality_keypair: 使用环境变量 reality_private（优先级最高）"

    priv="$env_priv"

    # 如果文件里私钥与传入相同，则优先复用文件里的公钥（避免变化）
    if [ -n "$file_priv" ] && [ "$file_priv" = "$priv" ] && [ -n "$file_pub" ]; then
      pub="$file_pub"
      _rk_log "✅ init_reality_keypair: 文件私钥与传入一致，复用文件公钥"
    else
      _rk_log "🔄 init_reality_keypair: 尝试由私钥推导公钥（derive_reality_public_key）"
      pub="$(derive_reality_public_key "$priv" 2>/dev/null)" || pub=""

      if [ -n "$pub" ]; then
        _rk_log "✅ init_reality_keypair: 推导公钥成功（pub=${#pub} chars）"
      else
        _rk_log "❗ init_reality_keypair: 推导公钥失败，将回退为生成新 keypair（这会覆盖 reality_private）"

        # 推导失败：生成一套新的 keypair（回退）
        local kp
        kp="$("$HOME/agsb/sing-box" generate reality-keypair 2>/dev/null)"
        priv="$(awk '/PrivateKey/{print $NF; exit}' <<< "$kp")"
        pub="$(awk '/PublicKey/{print $NF; exit}' <<< "$kp")"

        if [ -z "$priv" ] || [ -z "$pub" ]; then
          _rk_log "❗ init_reality_keypair: 生成 keypair 失败（sing-box generate reality-keypair 无输出）"
          return 1
        fi

        print_reality_private=1
        _rk_log "✅ init_reality_keypair: 已生成新的 Reality Keypair（priv/pub 均已获得）"
      fi
    fi

  # B) 没传私钥，但文件里有 → 直接复用（稳定）
  elif [ -n "$file_priv" ] && [ -n "$file_pub" ]; then
    _rk_log "♻️ init_reality_keypair: 未传入 reality_private，复用 reality.key 中的 keypair（稳定模式）"

    export reality_private="$file_priv"
    export reality_public="$file_pub"

    _rk_log "✅ init_reality_keypair: 复用成功（priv=${#file_priv} chars, pub=${#file_pub} chars）"
    return 0

  # C) 既没传私钥，文件也没有 → 首次生成
  else
    _rk_log "🆕 init_reality_keypair: 无传入私钥且无本地文件，生成新的 Reality Keypair"

    local kp
    kp="$("$HOME/agsb/sing-box" generate reality-keypair 2>/dev/null)"
    priv="$(awk '/PrivateKey/{print $NF; exit}' <<< "$kp")"
    pub="$(awk '/PublicKey/{print $NF; exit}' <<< "$kp")"

    if [ -z "$priv" ] || [ -z "$pub" ]; then
      _rk_log "❗ init_reality_keypair: 生成 keypair 失败（sing-box generate reality-keypair 无输出）"
      return 1
    fi

    print_reality_private=1
    _rk_log "✅ init_reality_keypair: 首次生成成功（priv/pub 均已获得）"
  fi

  # 写入 reality.key（统一落盘）
  mkdir -p "$(dirname "$key_file")" 2>/dev/null
  printf "PrivateKey: %s\nPublicKey: %s\n" "$priv" "$pub" > "$key_file" 2>/dev/null
  chmod 600 "$key_file" 2>/dev/null

  # 导出环境变量（给后续生成配置用）
  export reality_private="$priv"
  export reality_public="$pub"

  _rk_log "💾 init_reality_keypair: 已写入 $key_file（chmod 600）"
  _rk_log "✅ init_reality_keypair: 完成（priv=${#priv} chars, pub=${#pub} chars）"

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
    echo; echo "=========启用Sing-box内核========="

    if [ ! -e "$HOME/agsb/sing-box" ]; then 
        upsingbox; 
    fi


    cat > "$HOME/agsb/sb.json" <<EOF
{"log": { "disabled": false, "level": "info", "timestamp": true },
"inbounds": [
EOF
    insuuid
    write2AgsbFolders

   # Generate a self-signed cert for hy2（CN 与 hy_sni 解耦）
    gen_self_signed_cert "$HOME/agsb/private.key" "$HOME/agsb/cert.pem" "${CN_BING}" 36500


    # 添加tuic协议
    if [ -n "$tup" ]; then
        if [ -n "$port_tu" ]; then
            echo "$port_tu" > "$HOME/agsb/port_tu"
        elif [ -s "$HOME/agsb/port_tu" ]; then
            port_tu=$(cat "$HOME/agsb/port_tu")
        else
            port_tu=$(rand_port)
            echo "$port_tu" > "$HOME/agsb/port_tu"
        fi

        
        port_tu=$(cat "$HOME/agsb/port_tu"); 
        password=$uuid

        yellow "Tuic端口：$port_tu"

         cat >> "$HOME/agsb/sb.json" <<EOF
{"type": "tuic", "tag": "tuic-sb", "listen": "::", "listen_port": ${port_tu}, "users": [ {  "uuid": "$uuid", "password": "$password" } ],"congestion_control": "bbr", "tls": { "enabled": true,"alpn": ["h3"], "certificate_path": "$HOME/agsb/cert.pem", "key_path": "$HOME/agsb/private.key" }},
EOF
    fi

    # 添加hy2协议
    if [ -n "$hyp" ]; then
        if [ -z "$port_hy2" ] && [ ! -e "$HOME/agsb/port_hy2" ]; then port_hy2=$(rand_port); echo "$port_hy2" > "$HOME/agsb/port_hy2"; elif [ -n "$port_hy2" ]; then echo "$port_hy2" > "$HOME/agsb/port_hy2"; fi
        
        port_hy2=$(cat "$HOME/agsb/port_hy2"); 
        yellow "Hysteria2端口：$port_hy2"

        cat >> "$HOME/agsb/sb.json" <<EOF
{"type": "hysteria2", "tag": "hy2-sb", "listen": "::", "listen_port": ${port_hy2},"users": [ { "password": "${uuid}" } ],"tls": { "enabled": true, "alpn": ["h3"], "certificate_path": "$HOME/agsb/cert.pem", "key_path": "$HOME/agsb/private.key" }},
EOF
    fi
    
    # 添加trojan协议
    if [ -n "$trp" ]; then
        if [ -z "$port_tr" ] && [ ! -e "$HOME/agsb/port_tr" ]; then port_tr=$(rand_port); echo "$port_tr" > "$HOME/agsb/port_tr"; elif [ -n "$port_tr" ]; then echo "$port_tr" > "$HOME/agsb/port_tr"; fi
        
        port_tr=$(cat "$HOME/agsb/port_tr"); 
        yellow "Trojan端口(Argo本地使用)：$port_tr"

        cat >> "$HOME/agsb/sb.json" <<EOF
{"type": "trojan", "tag": "trojan-ws-sb", "listen": "::", "listen_port": ${port_tr},"users": [ { "password": "${uuid}" } ],"transport": { "type": "ws", "path": "/${uuid}-tr" }},
EOF
    fi

   # 添加vmess协议
    if [ -n "$vmp" ]; then
        if [ -z "$port_vm_ws" ] && [ ! -e "$HOME/agsb/port_vm_ws" ]; then port_vm_ws=$(rand_port); echo "$port_vm_ws" > "$HOME/agsb/port_vm_ws"; elif [ -n "$port_vm_ws" ]; then echo "$port_vm_ws" > "$HOME/agsb/port_vm_ws"; fi
        
        port_vm_ws=$(cat "$HOME/agsb/port_vm_ws"); 
        yellow "Vmess-ws端口 (Argo本地使用)：$port_vm_ws"

        cat >> "$HOME/agsb/sb.json" <<EOF
{"type": "vmess", "tag": "vmess-sb", "listen": "::", "listen_port": ${port_vm_ws},"users": [ { "uuid": "${uuid}", "alterId": 0 } ],"transport": { "type": "ws", "path": "/${uuid}-vm" }},
EOF
    fi
    # 添加vless-reality-vision协议
    if [ -n "$vlr" ]; then
        if [ -z "$port_vlr" ] && [ ! -e "$HOME/agsb/port_vlr" ];  then 
            port_vlr=$(rand_port); 
            echo "$port_vlr" > "$HOME/agsb/port_vlr"; 
        elif [ -n "$port_vlr" ]; then 
            echo "$port_vlr" > "$HOME/agsb/port_vlr"; 
        fi
        
        port_vlr=$(cat "$HOME/agsb/port_vlr"); 
        yellow "VLESS-Reality-Vision端口：$port_vlr"

        if [ ! -f "$HOME/agsb/reality.key" ]; then 
            "$HOME/agsb/sing-box" generate reality-keypair > "$HOME/agsb/reality.key"; 
        fi

          # ✅ Reality Keypair：只传私钥即可（自动算公钥/或复用文件），节点输出保持一致
        init_reality_keypair
        private_key="${reality_private}"
        short_id="$(get_short_id "$HOME/agsb/short_id")"


        # www.ua.edu
        cat >> "$HOME/agsb/sb.json" <<EOF
{"type": "vless", "tag": "vless-reality-vision-sb", "listen": "::", "listen_port": ${port_vlr},"sniff": true,"users": [{"uuid": "${uuid}","flow": "xtls-rprx-vision"}],"tls": {"enabled": true,"server_name": "${vl_sni}","reality": {"enabled": true,"handshake": {"server": "${vl_sni}","server_port": ${vl_sni_pt}},"private_key": "${private_key}","short_id": ["${short_id}"]}}},
EOF
    fi
}
#  Generate Sing-box configuration file
sbbout(){
    if [ -e "$HOME/agsb/sb.json" ]; then
        sed -i '$ s/,[[:space:]]*$//' "$HOME/agsb/sb.json"

        cat >> "$HOME/agsb/sb.json" <<EOF
],
"outbounds": [ { "type": "direct", "tag": "direct" }, { "type": "block", "tag": "block" } ],
"route": { "rules": [ { "action": "sniff" }, { "action": "resolve", "strategy": "${sbyx}" } ], "final": "direct" }
}
EOF
        if pidof systemd >/dev/null 2>&1 && [ "$EUID" -eq 0 ]; then
            cat > /etc/systemd/system/sb.service <<EOF
[Unit]
Description=sb service
After=network.target
[Service]
Type=simple
NoNewPrivileges=yes
ExecStart=$HOME/agsb/sing-box run -c $HOME/agsb/sb.json
Restart=on-failure
RestartSec=5s
[Install]
WantedBy=multi-user.target
EOF
            systemctl daemon-reload; systemctl enable sb; systemctl start sb
        elif command -v rc-service >/dev/null 2>&1 && [ "$EUID" -eq 0 ]; then
            cat > /etc/init.d/sing-box <<EOF
#!/sbin/openrc-run
description="sb service"
command="$HOME/agsb/sing-box"
command_args="run -c $HOME/agsb/sb.json"
command_background=yes
pidfile="/run/sing-box.pid"
depend() { need net; }
EOF
            chmod +x /etc/init.d/sing-box; rc-update add sing-box default; rc-service sing-box start
        else
            nohup "$HOME/agsb/sing-box" run -c "$HOME/agsb/sb.json" >/dev/null 2>&1 &
        fi
    fi
}


# ================== Nginx 订阅服务 ==================

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
  echo "$port" > "$HOME/agsb/nginx_port"


    # ✅端口相同会导致 nginx listen 冲突
    if [ "$port" = "$argo_port" ]; then
        red "❌ nginx_pt($port) 和 argo_pt($argo_port) 不能相同，否则 Nginx 监听冲突"
        return 1
    fi
  

  local webroot="/var/www/agsb"
  mkdir -p "$webroot"
  chmod 755 /var /var/www /var/www/agsb 2>/dev/null

  local vm_port tr_port uuid
  uuid="$(cat "$HOME/agsb/uuid" 2>/dev/null)"
  vm_port="$(cat "$HOME/agsb/port_vm_ws" 2>/dev/null)"
  tr_port="$(cat "$HOME/agsb/port_tr" 2>/dev/null)"

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
        alias /var/www/agsb/sub.txt;
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


start_nginx_service() {
    # systemd
    if pidof systemd >/dev/null 2>&1 && command -v systemctl >/dev/null 2>&1; then
        systemctl enable nginx >/dev/null 2>&1
        systemctl restart nginx >/dev/null 2>&1 || systemctl start nginx >/dev/null 2>&1
        return 0
    fi

    # openrc
    if command -v rc-service >/dev/null 2>&1; then
        rc-update add nginx default >/dev/null 2>&1
        rc-service nginx restart >/dev/null 2>&1 || rc-service nginx start >/dev/null 2>&1
        return 0
    fi

    # no init
    pkill -15 nginx >/dev/null 2>&1
    nohup nginx >/dev/null 2>&1 &
}


nginx_start() {
    start_nginx_service
}

nginx_stop() {
    # systemd
    if pidof systemd >/dev/null 2>&1 && command -v systemctl >/dev/null 2>&1; then
        systemctl stop nginx >/dev/null 2>&1
        return 0
    fi

    # openrc
    if command -v rc-service >/dev/null 2>&1; then
        rc-service nginx stop >/dev/null 2>&1
        return 0
    fi

    # no init：直接杀进程
    pkill -15 -x nginx >/dev/null 2>&1
}

nginx_restart() {
    # systemd
    if pidof systemd >/dev/null 2>&1 && command -v systemctl >/dev/null 2>&1; then
        systemctl restart nginx >/dev/null 2>&1 || systemctl start nginx >/dev/null 2>&1
        return 0
    fi

    # openrc
    if command -v rc-service >/dev/null 2>&1; then
        rc-service nginx restart >/dev/null 2>&1 || rc-service nginx start >/dev/null 2>&1
        return 0
    fi

    # no init：优先 reload，不行就 stop+start
    if command -v nginx >/dev/null 2>&1; then
        nginx -s reload >/dev/null 2>&1 && return 0
    fi

    nginx_stop
    nginx_start
}

nginx_status() {
    if pgrep -x nginx >/dev/null 2>&1; then
        echo "Nginx：$(green "运行中")"
    else
        echo "Nginx：$(red "未运行")"
    fi
}


ensure_cloudflared_if_needed() {
  # ✅ 仅当启用 argo=vmpt/trpt 且 vmag 存在时才需要 cloudflared
  if { [ "${argo:-}" != "vmpt" ] && [ "${argo:-}" != "trpt" ]; } || [ -z "${vmag:-}" ]; then
    purple "ℹ️ 未启用 Argo（或未启用 vmess/trojan），跳过 cloudflared 下载/安装"
    return 0
  fi

  ensure_cloudflared || return 1
  return 0
}




ensure_cloudflared() {
  # 已存在就不重复下载
  if [ -x "$HOME/agsb/cloudflared" ]; then
    return 0
  fi

  yellow "下载 Cloudflared Argo 内核中…"
  local url out

  # 下面为备用链接，里面的版本为2025.11.1，当有latest问题在切回我的仓库去
  # url="https://github.com/jyucoeng/singbox-tools/releases/download/cloudflared/cloudflared-linux-$cpu";


  url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$cpu"
  out="$HOME/agsb/cloudflared"

  (curl -Lo "$out" -# --connect-timeout 5 --max-time 120 \
    --retry 2 --retry-delay 2 --retry-all-errors "$url") \
  || (wget -O "$out" --tries=2 --timeout=60 --dns-timeout=5 --read-timeout=60 "$url")

  if [ ! -s "$out" ]; then
    red "❌ 下载失败：文件为空 $out"
    return 1
  fi

  chmod +x "$out" || return 1
  return 0
}



install_argo_service_systemd() {
    local mode="$1"
    local token="$2"

     # 检查 systemd 是否存在
    if ! command -v systemctl >/dev/null 2>&1; then
        red "系统未检测到 systemd，跳过 systemd 服务安装！"
        return
    fi

    if [ "$mode" = "json" ]; then
        cat > /etc/systemd/system/argo.service <<EOF
[Unit]
Description=argo service
After=network.target

[Service]
Type=simple
NoNewPrivileges=yes
ExecStart=$HOME/agsb/cloudflared tunnel --edge-ip-version auto --config $HOME/agsb/tunnel.yml run
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    else
        cat > /etc/systemd/system/argo.service <<EOF
[Unit]
Description=argo service
After=network.target

[Service]
Type=simple
NoNewPrivileges=yes
ExecStart=$HOME/agsb/cloudflared tunnel --no-autoupdate --edge-ip-version auto run --token ${token}
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
    fi

    systemctl daemon-reload
    systemctl enable argo
    systemctl start argo
    green "Argo 服务已成功安装并启动（systemd）"
}



install_argo_service_openrc() {
    local mode="$1"
    local token="$2"

      # 检查 openrc 是否存在
    if ! command -v rc-service >/dev/null 2>&1; then
        red "系统未检测到 openrc，跳过 openrc 服务安装！"
        return
    fi

    local command_path="$HOME/agsb/cloudflared"
    local args=""

    if [ "$mode" = "json" ]; then
        args="tunnel --edge-ip-version auto --config $HOME/agsb/tunnel.yml run"
    else
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
    green "Argo 服务已成功安装并启动（openrc）"
}





start_argo_no_daemon() {
    local mode="$1"
    local token="$2"
    local port="$3"

    if [ "$mode" = "json" ]; then
        nohup "$HOME/agsb/cloudflared" tunnel \
          --edge-ip-version auto \
          --config "$HOME/agsb/tunnel.yml" run \
          > "$HOME/agsb/argo.log" 2>&1 &
    elif [ -n "$token" ]; then
        nohup "$HOME/agsb/cloudflared" tunnel \
          --no-autoupdate \
          --edge-ip-version auto run \
          --token "$token" \
          > "$HOME/agsb/argo.log" 2>&1 &
    else
        nohup "$HOME/agsb/cloudflared" tunnel \
          --url "http://localhost:${port}" \
          --edge-ip-version auto \
          --no-autoupdate \
          > "$HOME/agsb/argo.log" 2>&1 &
    fi
}


wait_and_check_argo() {
  local argo_tunnel_type="${1:-临时}"  # 第一个参数：隧道类型（固定/临时）
  local argo_log="$HOME/agsb/argo.log"
  local ym_log="$HOME/agsb/sbargoym.log"
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
      green "✅ 固定 Argo 域名：$ARGO_DOMAIN"
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

   if pidof systemd >/dev/null 2>&1 || (command -v rc-service >/dev/null 2>&1 && [ "$EUID" -eq 0 ]); then
        return
   fi


    # 固定 Argo（token / JSON）
    if [ -n "${ARGO_DOMAIN}" ] && [ -n "${ARGO_AUTH}" ]; then
        if [ "$ARGO_MODE" = "json" ]; then
            echo '@reboot sleep 10 && nohup $HOME/agsb/cloudflared tunnel --edge-ip-version auto --config $HOME/agsb/tunnel.yml run >/dev/null 2>&1 &' \
                >> /tmp/crontab.tmp
        else
            echo '@reboot sleep 10 && nohup $HOME/agsb/cloudflared tunnel --no-autoupdate --edge-ip-version auto run --token $(cat $HOME/agsb/sbargotoken.log) >/dev/null 2>&1 &' \
                >> /tmp/crontab.tmp
        fi

    # 临时 Argo
    else
        echo '@reboot sleep 10 && nohup $HOME/agsb/cloudflared tunnel --url http://localhost:$(cat $HOME/agsb/argoport.log) --edge-ip-version auto --no-autoupdate > $HOME/agsb/argo.log 2>&1 &' \
            >> /tmp/crontab.tmp
    fi
}


post_install_finalize_legacy() {
    sleep 5
    echo

    if pgrep -f "$HOME/agsb/sing-box" >/dev/null 2>&1 || pgrep -f "$HOME/agsb/cloudflared" >/dev/null 2>&1; then

        [ -f ~/.bashrc ] || touch ~/.bashrc
        sed -i '/agsb/d' ~/.bashrc

        SCRIPT_PATH="$HOME/bin/agsb"
        mkdir -p "$HOME/bin"

        # ✅ 下载主脚本：加超时/重试，避免卡住
        (curl -sL --connect-timeout 5 --max-time 120 \
              --retry 2 --retry-delay 2 --retry-all-errors \
              "$agsburl" -o "$SCRIPT_PATH") \
        || (wget -qO "$SCRIPT_PATH" --tries=2 --timeout=60 "$agsburl")

        # ✅ 下载结果校验：防止空文件/错误页
        if [ ! -s "$SCRIPT_PATH" ]; then
            red "❌ 下载主脚本失败：文件为空 $SCRIPT_PATH"
            exit 1
        fi

        chmod +x "$SCRIPT_PATH"

        # 仅在无 systemd / openrc 时写 bashrc 自启
        if ! pidof systemd >/dev/null 2>&1 && ! command -v rc-service >/dev/null 2>&1; then
            # ✅ 更安全的 bashrc 写入方式：heredoc（避免引号地狱）
            # 说明：
            # - 这里写入的是“固定文本”，里面包含 ${name} 这类变量的展开值（在写入时已经被替换成具体值）
            # - bashrc 运行时只负责 export，并调用 $HOME/bin/agsb
            cat >> "$HOME/.bashrc" <<EOF
# agsb auto start (added by installer)
if ! pgrep -f 'agsb/sing-box' >/dev/null 2>&1; then
  export \
    vl_sni="${vl_sni}" \
    tu_sni="${tu_sni}" \
    hy_sni="${hy_sni}" \
    cdn_host="${cdn_host}" \
    cdn_pt="${cdn_pt}" \
    vl_sni_pt="${vl_sni_pt}" \
    short_id="${short_id}" \
    name="${name}" \
    ippz="${ippz}" \
    argo="${argo}" \
    uuid="${uuid}" \
    vmpt="${port_vm_ws}" \
    trpt="${port_tr}" \
    hypt="${port_hy2}" \
    tupt="${port_tu}" \
    vlrt="${port_vlr}" \
    nginx_pt="${nginx_pt}" \
    argo_pt="${argo_pt}" \
    agn="${ARGO_DOMAIN}" \
    agk="${ARGO_AUTH}"
  bash "\$HOME/bin/agsb"
fi
EOF
        fi

        # PATH 注入
        sed -i '/export PATH="\$HOME\/bin:\$PATH"/d' ~/.bashrc
        echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.bashrc"
        grep -qxF 'source ~/.bashrc' ~/.bash_profile 2>/dev/null || echo 'source ~/.bashrc' >> ~/.bash_profile
        . ~/.bashrc 2>/dev/null

        # crontab 处理
        crontab -l > /tmp/crontab.tmp 2>/dev/null

        # sing-box cron（仅无 systemd / openrc）
        if ! pidof systemd >/dev/null 2>&1 && ! command -v rc-service >/dev/null 2>&1; then
            sed -i '/agsb\/sing-box/d' /tmp/crontab.tmp
            echo '@reboot sleep 10 && nohup $HOME/agsb/sing-box run -c $HOME/agsb/sb.json >/dev/null 2>&1 &' \
                >> /tmp/crontab.tmp
        fi

        # 清理旧的 cloudflared cron
        sed -i '/agsb\/cloudflared/d' /tmp/crontab.tmp

        # 写入 Argo cron（token / JSON / 临时三态）
        append_argo_cron_legacy

        crontab /tmp/crontab.tmp >/dev/null 2>&1
        rm /tmp/crontab.tmp

        green "agsb脚本进程启动成功，安装完毕"
        sleep 2
    else
        red "agsb脚本进程未启动，安装失败"
        exit 1
    fi
}


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
    : > /var/www/agsb/sub.txt
  fi

  # ✅ 启动 nginx
  start_nginx_service
  return 0
}




ins(){
    # =====================================================
    # 1. 安装并启动 sing-box
    # =====================================================
    installsb
    set_sbyx
    sbbout

    # 2. Nginx（按需：subscribe=true 或启用 argo 才需要）
   ensure_nginx_if_needed || exit 1


    # =====================================================
    # 2. Argo 相关逻辑（仅在启用 argo + vmag 时）
    # =====================================================
   if need_argo && [ -n "$vmag" ]; then
        echo
        echo "=========启用Cloudflared-argo内核========="

    
        # ✅ 3.1 仅在需要 argo 时才确保 cloudflared 存在
        ensure_cloudflared_if_needed || {
            red "❌ 已启用 Argo，但 cloudflared 准备失败，无法继续启用 Argo"
            exit 1
        }

         # 2.2 计算 Argo 本地端口
        argoport="${argo_pt:-$ARGO_DEFAULT_PORT}"
        echo "$argoport" > "$HOME/agsb/argoport.log"    


        # 仍然记录 Argo 输出节点类型（给 cip 用）
        if [ "$argo" = "vmpt" ]; then
          echo "Vmess" > "$HOME/agsb/vlvm"
        elif [ "$argo" = "trpt" ]; then
          echo "Trojan" > "$HOME/agsb/vlvm"
        fi


        # 2.3 生成 Argo 凭据（JSON / token）
        # 仅用于“当前启动流程”，不用于重启判断
        prepare_argo_credentials "$ARGO_AUTH" "$ARGO_DOMAIN" "$argoport"

        # 2.4 启动 Argo（固定 / 临时）
        if [ -n "$ARGO_DOMAIN" ] && [ -n "$ARGO_AUTH" ]; then
            argo_tunnel_type="固定"

            if pidof systemd >/dev/null 2>&1 && [ "$EUID" -eq 0 ]; then
                install_argo_service_systemd "$ARGO_MODE" "$ARGO_AUTH"
            elif command -v rc-service >/dev/null 2>&1 && [ "$EUID" -eq 0 ]; then
                install_argo_service_openrc "$ARGO_MODE" "$ARGO_AUTH"
            else
                # 无 systemd / openrc，直接后台启动
                start_argo_no_daemon "$ARGO_MODE" "$ARGO_AUTH" "$argoport"
            fi

            # 与原版一致：固定 Argo 域名直接落盘
            echo "$ARGO_DOMAIN" > "$HOME/agsb/sbargoym.log"
            # token 模式下才会有 sbargotoken.log
            [ "$ARGO_MODE" = "token" ] && echo "$ARGO_AUTH" > "$HOME/agsb/sbargotoken.log"
        else
            # 临时 Argo（trycloudflare）
            argo_tunnel_type="临时"
            start_argo_no_daemon "temp" "" "$argoport"
        fi

        # 2.5 等待并检查 Argo 申请结果（原版 sleep + grep 逻辑）
        wait_and_check_argo "$argo_tunnel_type"
    fi

    # =====================================================
    # 3. 安装完成后的 legacy 收尾逻辑
    #    （进程检测 / bashrc / cron / 自启）
    # =====================================================
    post_install_finalize_legacy

    ensure_agsb_shortcut
}




# Write environment variables to files for persistence
write2AgsbFolders(){
  mkdir -p "$HOME/agsb"

  echo "${vl_sni}"    > "$HOME/agsb/vl_sni"
  echo "${hy_sni}"    > "$HOME/agsb/hy_sni"
  echo "${tu_sni}"    > "$HOME/agsb/tu_sni"
  echo "${cdn_host}"  > "$HOME/agsb/cdn_host"
  echo "${cdn_pt}"   > "$HOME/agsb/cdn_pt"

  # ✅ 只写新变量
  echo "${nginx_pt}"  > "$HOME/agsb/nginx_port"

  echo "${vl_sni_pt}" > "$HOME/agsb/vl_sni_pt"

  # ✅ 订阅开关落盘（默认 false）
  echo "${subscribe}" > "$HOME/agsb/subscribe"
}


#   show status
agsbstatus() {
  purple "=========当前内核运行状态========="

  # 1) sing-box
  if pgrep -f "$HOME/agsb/sing-box" >/dev/null 2>&1; then
    # 兼容：sing-box version r1.12.13
    local singbox_version
    singbox_version=$("$HOME/agsb/sing-box" version 2>/dev/null | sed -n 's/.*r\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p')
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

  # ✅ cloudflared 安装状态（不影响 Argo 是否启用）
  if [ -x "$HOME/agsb/cloudflared" ] || command -v cloudflared >/dev/null 2>&1; then
    echo "cloudflared：✅ $(green "已安装")"
  else
    echo "cloudflared：❌ $(red "未安装")"
  fi

  # 2) Argo 状态（细分：不需要 / 需要但未运行 / 运行中）
  if ! $argo_needed; then
    echo "Argo：✅ $(purple "未启用")（当前场景无需 Argo）"
  else
    if pgrep -f "$HOME/agsb/cloudflared" >/dev/null 2>&1; then
      # 兼容：cloudflared version 2025.11.1
      local cloudflared_version
      cloudflared_version=$("$HOME/agsb/cloudflared" version 2>/dev/null | sed -n 's/.*version \([0-9]\{4\}\.[0-9]\+\.[0-9]\+\).*/\1/p')
      echo "cloudflared Argo (版本V${cloudflared_version:-unknown})：✅ $(green "运行中")"
    else
      echo "Argo：❌ $(red "未运行")（已启用 Argo）"
      yellow "❗ 已启用 Argo，但 cloudflared 未运行：请执行 agsb start 或检查 cloudflared"
    fi
  fi

  # 3) Nginx + subscribe 状态（细分：不需要 / 未安装 / 未运行 / 运行中）
  local nginx_port sub_desc
  nginx_port="${nginx_pt:-$NGINX_DEFAULT_PORT}"
  [ -s "$HOME/agsb/nginx_port" ] && nginx_port="$(cat "$HOME/agsb/nginx_port" 2>/dev/null)"

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

  if pgrep -x nginx >/dev/null 2>&1; then
    echo "Nginx：✅ $(green "运行中")（${sub_desc}，端口：${nginx_port}）"
  else
    echo "Nginx：❌ $(red "未运行")（${sub_desc}，端口：${nginx_port}）"
    if is_true "$subscribe_flag"; then
      yellow "❗ 订阅已开启，但 Nginx 未运行：请执行 agsb start 或重启 nginx"
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
    green "📌 subscribe = true ✅（订阅已开启）"
  else
    purple "📌 subscribe = false ⛔（订阅未开启）"
    return 0
  fi

  # ✅ 没有节点文件就不生成
  if [ ! -s "$HOME/agsb/jh.txt" ]; then
    purple "❗ 订阅源文件不存在或为空：$HOME/agsb/jh.txt（跳过生成 sub.txt）"
    return 0
  fi

  mkdir -p /var/www/agsb
  local out="/var/www/agsb/sub.txt"

  # ✅ 优先用 openssl（更通用）
  if command -v openssl >/dev/null 2>&1; then
    if openssl base64 -A -in "$HOME/agsb/jh.txt" > "$out" 2>/dev/null; then
      purple "✅ sub.txt 生成成功：$out"
      return 0
    else
      red "❌ sub.txt 生成失败（openssl base64）"
      return 1
    fi
  fi

  # ✅ fallback：base64（兼容 busybox 与 GNU）
  if command -v base64 >/dev/null 2>&1; then
    if base64 -w 0 "$HOME/agsb/jh.txt" 2>/dev/null > "$out"; then
      purple "✅ sub.txt 生成成功：$out"
      return 0
    fi

    # busybox base64 没有 -w 参数
    if base64 "$HOME/agsb/jh.txt" 2>/dev/null | tr -d '\n' > "$out"; then
      purple "✅ sub.txt 生成成功：$out"
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
  [ -s "$HOME/agsb/nginx_port" ] && port="$(cat "$HOME/agsb/nginx_port")"

  local sub_uuid
  sub_uuid="$(cat "$HOME/agsb/uuid" 2>/dev/null)"

  [ -z "$sub_uuid" ] && return 0

  # 固定 Argo（JSON 或 Token）
  if [ -n "${ARGO_DOMAIN}" ] && [ -n "${ARGO_AUTH}" ]; then
    echo "https://${ARGO_DOMAIN}/sub/${sub_uuid}"
    return 0
  fi

  # 普通 http：IP:PORT
  local server_ip
  server_ip=$(cat "$HOME/agsb/server_ip.log" 2>/dev/null)

  if [ -z "$server_ip" ]; then
    server_ip="$( (curl -s4m5 -k https://icanhazip.com) || (wget -4 -qO- --tries=2 https://icanhazip.com) )"
    server_ip=$(update_server_ip "$server_ip" "$out_ip")
    server_ip=$(add_ipv6_brackets "$server_ip")  # 确保 IPv6 地址加上中括号
  fi

  # IPv6 加中括号
  # if echo "$server_ip" | grep -q ':' && ! echo "$server_ip" | grep -q '^\['; then
  #   server_ip="[$server_ip]"
  # fi

  echo "http://${server_ip}:${port}/sub/${sub_uuid}"
}


ensure_and_print_reality_private_for_cip() {
  local want_print="${1:-0}"
  [ "$want_print" = "1" ] || return 0

  if [ -z "$reality_private" ] && [ -s "$HOME/agsb/reality.key" ]; then
    reality_private="$(awk '/PrivateKey/{print $NF; exit}' "$HOME/agsb/reality.key" 2>/dev/null)"
    reality_public="$(awk '/PublicKey/{print $NF; exit}' "$HOME/agsb/reality.key" 2>/dev/null)"
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
  echo -e "$1" >> "$HOME/agsb/jh.txt"
}

# 定义验证 IP 地址是否合法的函数
is_valid_ip() {
    local ip="$1"
    
    # 如果 IP 为空，视为无效 IP
    if [ -z "$ip" ]; then
        return 1  # 返回 1 表示无效的 IP 地址
    fi

    # 检查是否是有效的 IPv4 地址
    if echo "$ip" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
        return 0  # 返回 0 表示是有效的 IPv4 地址
    # 检查是否是有效的 IPv6 地址
    elif echo "$ip" | grep -qE '^([a-fA-F0-9:]+:+)+[a-fA-F0-9]+$'; then
        return 0  # 返回 0 表示是有效的 IPv6 地址
    else
        return 1  # 返回 1 表示无效的 IP 地址
    fi
}



# 根据 out_ip_local 更新 current_server_ip 的函数，确保返回的 IPv6 不包含中括号
update_server_ip() {
    # 定义调试日志函数
    _rk_log() {
        [ "${DEBUG_REALITY:-0}" = "1" ] && echo -e "$*" >&2  # 如果 DEBUG_REALITY 为 1，则打印日志
    }

    local current_server_ip="$1"
    local out_ip_local="$2"  # 修改变量名，避免与其他地方的 out_ip 混淆

    # 输出调试信息，显示传入的参数
    _rk_log "[调试] 原始 current_server_ip: $current_server_ip"
    _rk_log "[调试] 原始 out_ip_local: $out_ip_local"

    # 如果 current_server_ip 是 IPv6 地址（即包含中括号），去除中括号
    if echo "$current_server_ip" | grep -q '^[' && echo "$current_server_ip" | grep -q ']$'; then
        _rk_log "[调试] 去掉 current_server_ip 中的中括号"
        current_server_ip=$(echo "$current_server_ip" | sed 's/^\[\(.*\)\]$/\1/')  # 去掉中括号
        _rk_log "[调试] 去掉中括号后的 current_server_ip: $current_server_ip"
    fi

    # 如果 out_ip_local 非空且包含中括号，则去除中括号
    if [ -n "$out_ip_local" ] && echo "$out_ip_local" | grep -q '^[' && echo "$out_ip_local" | grep -q ']$'; then
        _rk_log "[调试] 去掉 out_ip_local 中的中括号"
        out_ip_local=$(echo "$out_ip_local" | sed 's/^\[\(.*\)\]$/\1/')  # 去掉中括号
        _rk_log "[调试] 去掉中括号后的 out_ip_local: $out_ip_local"
    fi

    # 检查 out_ip_local 是否有效，并且与 current_server_ip 不同，并且确保它们类型一致（IPv4 或 IPv6）
    if [ -n "$out_ip_local" ] && is_valid_ip "$out_ip_local" && [ "$current_server_ip" != "$out_ip_local" ]; then
        # 检查是否是 IPv6 地址，并且确保类型一致
        if echo "$current_server_ip" | grep -q ':' && echo "$out_ip_local" | grep -q ':'; then
            # 都是 IPv6 地址
            _rk_log "[调试] current_server_ip 和 out_ip_local 都是 IPv6，进行更新"
            current_server_ip="$out_ip_local"
        # 检查是否是 IPv4 地址，并且确保类型一致
        elif ! echo "$current_server_ip" | grep -q ':' && ! echo "$out_ip_local" | grep -q ':'; then
            # 都是 IPv4 地址
            _rk_log "[调试] current_server_ip 和 out_ip_local 都是 IPv4，进行更新"
            current_server_ip="$out_ip_local"
        else
            _rk_log "[调试] current_server_ip 和 out_ip_local 类型不同（IPv4 和 IPv6），不进行更新"
        fi
    else
        _rk_log "[调试] out_ip_local 为空、无效或与 current_server_ip 相同，不进行更新"
    fi

    # 输出最终的 server_ip 和 out_ip_local，方便对比
    _rk_log "[调试] 最终的 server_ip: $current_server_ip"
    _rk_log "[调试] 最终的 out_ip_local: $out_ip_local"

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




# ipbest 函数，获取并更新 server_ip 并写入日志
ipbest() {
    # 获取公网 IP 地址
    serip=$( (curl -s4m5 -k "$v46url") || (wget -4 -qO- --tries=2 "$v46url") )

    serip=$(update_server_ip "$serip" "$out_ip")
    serip=$(add_ipv6_brackets "$serip")

    # 保存更新后的 server_ip 到文件
    echo "$serip" > "$HOME/agsb/server_ip.log"
}




# 检查 IPv4 和 IPv6 的连通性
check_ip_connectivity() {
    local v46url="$1"
    local v4 v6
    # 检查 IPv4 连通性
    v4=$(curl -s4 -m5 --connect-timeout 5 -k "$v46url" 2>/dev/null || wget -4 -qO- --tries=2 --timeout=5 "$v46url" 2>/dev/null)
    # 检查 IPv6 连通性
    v6=$(curl -s6 -m5 --connect-timeout 5 -k "$v46url" 2>/dev/null || wget -6 -qO- --tries=2 --timeout=5 "$v46url" 2>/dev/null)
    
    # 返回 IPv4 和 IPv6 结果
    echo "$v4 $v6"
}

# 从 IP 服务中提取位置
get_location_from_ip_service() {
    local ip_service_url="$1"
    echo $(curl -s4m5 -k "$ip_service_url" 2>/dev/null | sed -E 's/.*Location: ([^,]+(, [^,]+)*),.*/\1/' || \
          wget -4 -qO- --tries=2 "$ip_service_url" 2>/dev/null | grep '<span class="has-text-grey-light">Location:' | tail -n1 | sed -E 's/.*>Location: <\/span>([^<]+)<.*/\1/')
}

# 如果 out_ip 是有效的且与 current_server_ip 不同，则更新 current_server_ip
update_server_ip_if_valid() {
    local current_server_ip="$1"
    local out_ip="$2"

    current_server_ip=$(update_server_ip "$current_server_ip" "$out_ip")
    current_server_ip=$(add_ipv6_brackets "$current_server_ip")
    
    echo "$current_server_ip"
}

# 精简版 ipchange 函数，输出 IPv4、IPv6 地址、位置和变更后的出口 IP（仅当实际变化时）
ipchange000() {
    # 获取 IPv4 和 IPv6 的连通性和位置
    v4v6_result=$(check_ip_connectivity "$v46url")
    v4=$(echo "$v4v6_result" | awk '{print $1}')
    v6=$(echo "$v4v6_result" | awk '{print $2}')

    v4dq=$(get_location_from_ip_service "https://ip.fm")
    v6dq=$(get_location_from_ip_service "https://ip.fm")

    # 确定 vps 的 IPv4 和 IPv6 地址及其位置
    if [ -z "$v4" ]; then
        vps_ipv4='无IPV4'
        vps_ipv6="$v6"
        location=$v6dq
    elif [ -n "$v4" ] && [ -n "$v6" ]; then
        vps_ipv4="$v4"
        vps_ipv6="$v6"
        location=$v4dq
    else
        vps_ipv4="$v4"
        vps_ipv6='无IPV6'
        location=$v4dq
    fi

    # 输出 IPv4 和 IPv6 地址、位置
    echo
    agsbstatus
    echo
    green "=========当前服务器本地IP情况========="
    yellow "本地IPV4地址：$vps_ipv4"
    purple "本地IPV6地址：$vps_ipv6"
    green "服务器地区：$location"
    echo

    # 记录原始的 server_ip
    original_server_ip="$server_ip"

    # 更新并确保 server_ip 只在变化时更新
    server_ip=$(update_server_ip_if_valid "$out_ip_local" "$server_ip")

    # 如果 server_ip 确实发生变化，输出变更后的出口 IP
    if [ "$server_ip" != "$original_server_ip" ]; then
        yellow "变更后的出口IP：$server_ip"
    fi

    # 更新并保存变更后的出口 IP 到日志
    echo "$server_ip" > "$HOME/agsb/server_ip.log"
}


ipchange() {
    # 第一步：检查 IPv4 和 IPv6 的连通性
    v4v6_result=$(check_ip_connectivity "$v46url")
    v4=$(echo "$v4v6_result" | awk '{print $1}')
    v6=$(echo "$v4v6_result" | awk '{print $2}')

    # 第二步：获取 IPv4 和 IPv6 地址的位置信息
    v4dq=$(get_location_from_ip_service "https://ip.fm")
    v6dq=$(get_location_from_ip_service "https://ip.fm")

    # 第三步：根据连通性设置 vps 的 IPv4 和 IPv6 地址以及位置
    if [ -z "$v4" ]; then
        vps_ipv4='无IPV4'
        vps_ipv6="$v6"
        location=$v6dq
    elif [ -n "$v4" ] && [ -n "$v6" ]; then
        vps_ipv4="$v4"
        vps_ipv6="$v6"
        location=$v4dq
    else
        vps_ipv4="$v4"
        vps_ipv6='无IPV6'
        location=$v4dq
    fi

    # 输出当前的 IPv4 和 IPv6 地址以及位置
    echo
    agsbstatus
    echo
    green "=========当前服务器本地IP情况========="
    yellow "本地IPV4地址：$vps_ipv4"
    purple "本地IPV6地址：$vps_ipv6"
    green "服务器地区：$location"
    echo
    sleep 2

    # 第四步：根据 ippz 值更新 server_ip
    if [ "$ippz" = "4" ]; then
        if [ -z "$v4" ]; then
            ipbest  # 如果没有 v4 地址，则调用 ipbest 获取公网 IP
        else
            # 使用 update_server_ip 函数更新 server_ip
            server_ip=$(update_server_ip "$v4" "$server_ip")
            server_ip=$(add_ipv6_brackets "$server_ip")  # 确保 IPv6 地址加上中括号
            echo "$server_ip" > "$HOME/agsb/server_ip.log"
        fi
    elif [ "$ippz" = "6" ]; then
        if [ -z "$v6" ]; then
            ipbest  # 如果没有 v6 地址，则调用 ipbest 获取公网 IP
        else
            # 使用 update_server_ip 函数更新 server_ip
            server_ip=$(update_server_ip "$v6" "$server_ip")
            server_ip=$(add_ipv6_brackets "$server_ip")  # 确保 IPv6 地址加上中括号
            echo "$server_ip" > "$HOME/agsb/server_ip.log"
        fi
    else
        ipbest  # 如果 ippz 值不是 4 或 6，则直接调用 ipbest 获取公网 IP
    fi

    # 第五步：如果 server_ip 发生变化，则输出变更后的出口 IP
    current_server_ip=$(cat "$HOME/agsb/server_ip.log")  # 从日志文件读取当前的 server_ip
    if [ "$server_ip" != "$current_server_ip" ]; then
        yellow "👉 由于你设置了单独的出口ip,出口IP已变更为：$server_ip"  # 仅在出口 IP 发生变化时输出变更后的 IP
    fi
}



# show nodes
cip(){
    
    ipchange; 
    rm -rf "$HOME/agsb/jh.txt"; 
    uuid=$(cat "$HOME/agsb/uuid"); 
    server_ip=$(cat "$HOME/agsb/server_ip.log"); 
    sxname=$(cat "$HOME/agsb/name" 2>/dev/null);

    echo "*********************************************************"; 
    purple "agsb脚本输出节点配置如下："; 
    echo;
    # Hysteria2 protocol (hy2)
    if grep -q "hy2-sb" "$HOME/agsb/sb.json"; then 
        port_hy2=$(cat "$HOME/agsb/port_hy2"); 
        hy_sni=$(cat "$HOME/agsb/hy_sni"); 
        hy2_link="hysteria2://$uuid@$server_ip:$port_hy2?security=tls&alpn=h3&insecure=1&allowInsecure=1&sni=${hy_sni}#${sxname}hy2-$hostname"; 
        yellow "💣【 Hysteria2 】(直连协议)"; 
        green "$hy2_link"
        append_jh "$hy2_link"
        echo; 
    fi
    
    
     # TUIC protocol (tuic or tupt)
    if grep -q "tuic-sb" "$HOME/agsb/sb.json"; then
        port_tu=$(cat "$HOME/agsb/port_tu")
        tu_sni=$(cat "$HOME/agsb/tu_sni"); 
        password=$uuid

        tuic_link="tuic://${uuid}:${password}@${server_ip}:${port_tu}?sni=${tu_sni}&congestion_control=bbr&security=tls&udp_relay_mode=native&alpn=h3&allow_insecure=1#${sxname}tuic-$hostname"
        yellow "💣【 TUIC 】(直连协议)"
        green "$tuic_link" 
        append_jh "$tuic_link"
        echo;
    fi
    # VLESS-Reality-Vision protocol (vless-reality-vision)
    if grep -q "vless-reality-vision-sb" "$HOME/agsb/sb.json"; then
        port_vlr=$(cat "$HOME/agsb/port_vlr")
        public_key=$(sed -n '2p' "$HOME/agsb/reality.key" | awk '{print $2}')
        short_id=$(cat "$HOME/agsb/short_id")
        vl_sni=$(cat "$HOME/agsb/vl_sni")
        white "cip函数中的short_id,值为:$short_id"

       # vless_link="vless://${uuid}@${server_ip}:${port_vlr}?encryption=none&security=reality&sni=www.yahoo.com&fp=chrome&flow=xtls-rprx-vision&publicKey=${public_key}&shortId=${short_id}#${sxname}vless-reality-$hostname"
        
        vless_link="vless://${uuid}@${server_ip}:${port_vlr}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${vl_sni}&fp=chrome&pbk=${public_key}&sid=${short_id}&type=tcp&headerType=none#${sxname}vless-reality-$hostname" 
        yellow "💣【 VLESS-Reality-Vision 】(直连协议)"; 
        green "$vless_link"
        append_jh "$vless_link"
        echo;

        # 查看节点时提示用户保存私钥（方便下次保持节点一致）,一般这里的$1值为"key"
         print_reality_key "$1"
    fi
    #argodomain=$(cat "$HOME/agsb/sbargoym.log" 2>/dev/null); [ -z "$argodomain" ] && argodomain=$(grep -a trycloudflare.com "$HOME/agsb/argo.log" 2>/dev/null | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')
   
    argodomain=$(cat "$HOME/agsb/sbargoym.log" 2>/dev/null)

    if need_argo && [ -z "$argodomain" ] && [ -s "$HOME/agsb/argo.log" ]; then
        argodomain=$(grep -aoE '[a-zA-Z0-9.-]+trycloudflare\.com' "$HOME/agsb/argo.log" 2>/dev/null | tail -n1)
    fi

    cdn_host=$(cat "$HOME/agsb/cdn_host")
    cdn_pt=$(cat "$HOME/agsb/cdn_pt" 2>/dev/null)
    cdn_pt="$(normalize_cdn_pt "$cdn_pt" 443)"

    if [ -n "$argodomain" ]; then
        vlvm=$(cat $HOME/agsb/vlvm 2>/dev/null); uuid=$(cat "$HOME/agsb/uuid")
        if [ "$vlvm" = "Vmess" ]; then
            vmatls_link1="vmess://$(echo "{\"v\":\"2\",\"ps\":\"${sxname}vmess-ws-tls-argo-$hostname-${cdn_pt}\",\"add\":\"${cdn_host}\",\"port\":\"${cdn_pt}\",\"id\":\"$uuid\",\"aid\":\"0\",\"net\":\"ws\",\"host\":\"$argodomain\",\"path\":\"/${uuid}-vm\",\"tls\":\"tls\",\"sni\":\"$argodomain\"}" | base64 | tr -d '\n\r')"
           
            tratls_link1=""
        elif [ "$vlvm" = "Trojan" ]; then
            tratls_link1="trojan://${uuid}@${cdn_host}:${cdn_pt}?security=tls&type=ws&host=${argodomain}&path=%2F${uuid}-tr&sni=${argodomain}&fp=chrome#${sxname}trojan-ws-tls-argo-$hostname-${cdn_pt}"
            vmatls_link1=""
        fi

        sbtk=$(cat "$HOME/agsb/sbargotoken.log" 2>/dev/null); 
        yellow "---------------------------------------------------------"
        yellow "Argo隧道信息 (使用 ${vlvm}-ws 端口: $(cat $HOME/agsb/argoport.log 2>/dev/null))"
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
    yellow "聚合节点: cat $HOME/agsb/jh.txt"; 
    yellow "========================================================="; 
    purple "相关快捷方式如下："; 
    showmode
    
}


cleanup_nginx() {
  
    # 清理 nginx
    pkill -15 nginx >/dev/null 2>&1
    rm -f "$(nginx_conf_path)" 2>/dev/null

    # 禁用 nginx 自启（避免卸载后 nginx 仍然起来）
    if pidof systemd >/dev/null 2>&1; then
        systemctl stop nginx >/dev/null 2>&1
        systemctl disable nginx >/dev/null 2>&1
    elif command -v rc-service >/dev/null 2>&1; then
        rc-service nginx stop >/dev/null 2>&1
        rc-update del nginx default >/dev/null 2>&1
    fi
    echo "Nginx 已被清理(清理配置文件和禁止自启，nginx 服务已停止)。"
}


# Remove agsb folder
cleandel(){
    # Change to $HOME to avoid issues when deleting directories
   cd "$HOME" || exit 1

    yellow "开始卸载sing-box/cloudflared流程..."; 
    # Continue with the cleanup
    for P in /proc/[0-9]*; do
        if [ -L "$P/exe" ]; then
            TARGET=$(readlink -f "$P/exe" 2>/dev/null)
            if echo "$TARGET" | grep -qE '/agsb/cloudflared|/agsb/sing-box'; then 
                kill "$(basename "$P")" 2>/dev/null
            fi
        fi
    done

    pkill -15 -f "$HOME/agsb/sing-box" 2>/dev/null
    pkill -15 -f "$HOME/agsb/cloudflared" 2>/dev/null

    sed -i '/agsb/d' ~/.bashrc
    sed -i '/export PATH="\$HOME\/bin:\$PATH"/d' ~/.bashrc
    . ~/.bashrc 2>/dev/null

    crontab -l > /tmp/crontab.tmp 2>/dev/null
    sed -i '/agsb/d' /tmp/crontab.tmp
    crontab /tmp/crontab.tmp >/dev/null 2>&1
    rm /tmp/crontab.tmp
    rm -rf "$HOME/bin/agsb"

    if pidof systemd >/dev/null 2>&1; then
        for svc in sb argo; do
            systemctl stop "$svc" >/dev/null 2>&1
            systemctl disable "$svc" >/dev/null 2>&1
        done
        rm -f /etc/systemd/system/{sb.service,argo.service}
    elif command -v rc-service >/dev/null 2>&1; then
        for svc in sing-box argo; do
            rc-service "$svc" stop >/dev/null 2>&1
            rc-update del "$svc" default >/dev/null 2>&1
        done
        rm -f /etc/init.d/{sing-box,argo}
    fi

  # 清理 nginx
  #  pkill -15 nginx >/dev/null 2>&1
  #  rm -f "$(nginx_conf_path)" 2>/dev/null

  yellow "开始卸载或者清理nginx流程..."; 
  cleanup_nginx

  yellow "开始卸载或者清理快捷方式流程..."; 
  cleanup_agsb_shortcut

}

# Restart sing-box
sbrestart(){
    pkill -15 -f "$HOME/agsb/sing-box" 2>/dev/null

    if pidof systemd >/dev/null 2>&1; then
        systemctl restart sb
    elif command -v rc-service >/dev/null 2>&1; then
        rc-service sing-box restart
    else
        nohup "$HOME/agsb/sing-box" run -c "$HOME/agsb/sb.json" >/dev/null 2>&1 &
    fi
}




# Restart argo
argorestart(){
    # 先尽力停止现有 cloudflared 进程（原版行为）
   pkill -15 -f "$HOME/agsb/cloudflared" 2>/dev/null

    # ===============================
    # systemd 管理
    # ===============================
    if pidof systemd >/dev/null 2>&1; then
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
    if [ -f "$HOME/agsb/tunnel.yml" ]; then
        nohup "$HOME/agsb/cloudflared" tunnel \
          --edge-ip-version auto \
          --config "$HOME/agsb/tunnel.yml" run \
          >/dev/null 2>&1 &
        return
    fi

    # 2️⃣ token 固定隧道
    if [ -f "$HOME/agsb/sbargotoken.log" ]; then
        nohup "$HOME/agsb/cloudflared" tunnel \
          --no-autoupdate \
          --edge-ip-version auto run \
          --token "$(cat "$HOME/agsb/sbargotoken.log")" \
          >/dev/null 2>&1 &
        return
    fi

    # 3️⃣ 临时 Argo（trycloudflare）
    if [ -f "$HOME/agsb/argoport.log" ]; then
        nohup "$HOME/agsb/cloudflared" tunnel \
          --url "http://localhost:$(cat "$HOME/agsb/argoport.log")" \
          --edge-ip-version auto \
          --no-autoupdate \
          > "$HOME/agsb/argo.log" 2>&1 &
    fi
}


install_step(){
  echo "VPS系统：$op"; 
    echo "CPU架构：$cpu"; 
    echo "agsb脚本开始安装/更新…………" && sleep 1

    # 获取操作系统名称
    os_name=$(awk -F= '/^NAME/{print $2}' /etc/os-release)

    install_deps

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
    # 显示节点信息 这里的key是一个定值，为了打印私钥
    cip "key"
}

main(){

# 启动 nginx
if [ "$1" = "nginx_start" ]; then
    nginx_start
    nginx_status
    exit
fi

# 停止 nginx
if [ "$1" = "nginx_stop" ]; then
    nginx_stop
    nginx_status
    exit
fi

# 重启 nginx
if [ "$1" = "nginx_restart" ]; then
    nginx_restart
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
    rm -rf "$HOME/agsb"; 
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
    pkill -15 -f "$HOME/agsb/sing-box" 2>/dev/null

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
    rm -rf "$HOME/agsb"/{sb.json,sbargoym.log,sbargotoken.log,argo.log,argoport.log,name,short_id,cdn_host,hy_sni,vl_sni,tu_sni,vl_sni_pt,cdn_pt}; 
    green "1.1、清理操作完成..."; 
    sleep 2; 

    green "2、覆盖式安装开始..."; 
    install_step
    echo "覆盖式安装已完成... 再见👋"; 
    exit;
fi

# 安装步骤(不带参数或者参数为 ins)
if [ -z "$1" ] || [ "$1" = "ins" ]; then
    yellow "开始安装流程..."; 
    install_step
fi

}

main "$@"
