#!/usr/bin/env bash
export LANG=en_US.UTF-8
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
    # 依赖包（用数组，最稳）
    # =========================
    # 公共依赖（各发行版基本一致）
    local COMMON_PKGS=(
        curl wget jq openssl
        iptables bc lsof
        psmisc
    )

    # Debian/Ubuntu
    local APT_PKGS=(
        "${COMMON_PKGS[@]}"
        uuid-runtime
        cron
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
            echo -e "${YELLOW}⚠️ 未检测到 fuser（psmisc），跳过 dpkg 锁检测${RESET}"
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

export cdnym=${cdnym:-''}; 
export argo=${argo:-''}; 
export ARGO_DOMAIN=${agn:-''}; 
export ARGO_AUTH=${agk:-''}; 
export ippz=${ippz:-''}; 
export name=${name:-''}; 
export oap=${oap:-''}

# 检查是否需要安装依赖
check_and_install_deps() {
    # 获取第一个参数作为操作类型
    local operation="$1"

    yellow "check_and_install_deps 函数开始执行..."

    # 如果没有传递参数或是传递了 install 参数，执行安装依赖
    if [ -z "$operation" ] || [ "$operation" = "install" ]; then
        white "正在安装依赖..."
        install_deps
    else
        # 否则跳过安装依赖
        yellow "跳过依赖安装，执行其他操作..."
    fi
}

# 在脚本的适当位置调用这个函数
check_and_install_deps "$1"

v46url="https://icanhazip.com"
agsburl="https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb000.sh"


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
  else
    echo "$HOME/.bashrc 文件已存在"
  fi
}

create_bashrc_if_missing

# ================== 系统bashrc函数 ==================
VERSION="1.0.3(2026-01-16)"
AUTHOR="littleDoraemon"

# Show script mode
showmode(){
    blue "===================================================="
    gradient "       agsb 一键脚本（vmess/trojan Argo选1,vless+hy2+tuic 3个直连）"
    green    "       作者：$AUTHOR"
    yellow   "       版本：$VERSION"
    blue "===================================================="
 
    yellow "主脚本：bash <(curl -Ls ${agsburl}) 或 bash <(wget -qO- ${agsburl})"
    yellow "显示节点信息：agsb list"
    yellow "覆盖式安装的： agsb rep"
    yellow "更新Singbox内核：agsb ups"
    yellow "重启脚本：agsb res"
    yellow "卸载脚本：agsb del"
    echo "---------------------------------------------------------"
}
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
        #⚠️ 如果 ARGO_AUTH 里的 JSON 含有 \n、\r、\uXXXX 之类，echo 在某些 shell/实现里可能会解释转义，导致 tunnel.json 内容被破坏。 改法：用 printf 更可靠
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
    v4=$( (curl -s4m5 -k "$v46url" 2>/dev/null) || (wget -4 -qO- --tries=2 "$v46url" 2>/dev/null) )
    v6=$( (curl -s6m5 -k "$v46url" 2>/dev/null) || (wget -6 -qO- --tries=2 "$v46url" 2>/dev/null) )
}
# Set up name for nodes and IP version preference
set_sbyx(){
    if [ -n "$name" ]; then sxname=$name-; echo "$sxname" > "$HOME/agsb/name"; echo; yellow "所有节点名称前缀：$name"; fi
    v4v6
    if (curl -s4m5 -k "$v46url" >/dev/null 2>&1) || (wget -4 -qO- --tries=2 "$v46url" >/dev/null 2>&1); then v4_ok=true; fi
    if (curl -s6m5 -k "$v46url" >/dev/null 2>&1) || (wget -6 -qO- --tries=2 "$v46url" >/dev/null 2>&1); then v6_ok=true; fi
    if [ "$v4_ok" = true ] && [ "$v6_ok" = true ]; then 
        sbyx='prefer_ipv6'; 
    elif [ "$v4_ok" = true ] && [ "$v6_ok" != true ]; then 
        sbyx='ipv4_only'; 
    elif [ "$v4_ok" != true ] && [ "$v6_ok" = true ]; then 
        sbyx='ipv6_only'; 
    else sbyx='prefer_ipv6'; 
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
    # Generate a new private key and certificate for hy2
    openssl ecparam -genkey -name prime256v1 -out "$HOME/agsb/private.key" >/dev/null 2>&1
    openssl req -new -x509 -days 36500 -key "$HOME/agsb/private.key" -out "$HOME/agsb/cert.pem" -subj "/CN=${hy_sni}" >/dev/null 2>&1

    # Generate a new private key and certificate for tuic
    openssl ecparam -genkey -name prime256v1 -out "$HOME/agsb/tuic_private.key" >/dev/null 2>&1
    openssl req -new -x509 -key "$HOME/agsb/tuic_private.key" -out "$HOME/agsb/tuic_cert.pem" -days 3650 -subj "/CN=${tu_sni}" >/dev/null 2>&1


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
{"type": "tuic", "tag": "tuic-sb", "listen": "::", "listen_port": ${port_tu}, "users": [ {  "uuid": "$uuid", "password": "$password" } ],"congestion_control": "bbr", "tls": { "enabled": true,"alpn": ["h3"], "certificate_path": "$HOME/agsb/tuic_cert.pem", "key_path": "$HOME/agsb/tuic_private.key","server_name": "${tu_sni}" }},
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

        private_key=$(sed -n '1p' "$HOME/agsb/reality.key" | awk '{print $2}')

        if [ -f "$HOME/agsb/short_id" ]; then
            short_id=$(cat "$HOME/agsb/short_id")
            yellow "从文件中读取short_id,值: $short_id"
        else
            short_id=$(openssl rand -hex 4)
            echo "$short_id" > "$HOME/agsb/short_id"
            green "随机生成short_id,值: $short_id"
        fi

        # www.ua.edu
        cat >> "$HOME/agsb/sb.json" <<EOF
{"type": "vless", "tag": "vless-reality-vision-sb", "listen": "::", "listen_port": ${port_vlr},"sniff": true,"users": [{"uuid": "${uuid}","flow": "xtls-rprx-vision"}],"tls": {"enabled": true,"server_name": "${vl_sni}","reality": {"enabled": true,"handshake": {"server": "${vl_sni}","server_port": 443},"private_key": "${private_key}","short_id": ["${short_id}"]}}},
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


ensure_cloudflared() {
    if [ -x "$HOME/agsb/cloudflared" ]; then
        return
    fi

    echo "下载 Cloudflared Argo 内核中…"
    # 下面为备用链接，里面的版本为2025.11.1，当有latest问题在切回我的仓库去
     # url="https://github.com/jyucoeng/singbox-tools/releases/download/cloudflared/cloudflared-linux-$cpu";

    url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$cpu"
    out="$HOME/agsb/cloudflared"

    (curl -Lo "$out" -# --connect-timeout 5 --max-time 120 \
      --retry 2 --retry-delay 2 --retry-all-errors "$url") \
|| (wget -O "$out" --tries=2 --timeout=60 --dns-timeout=5 --read-timeout=60 "$url")

    if [ ! -s "$out" ]; then
        red "❌ 下载失败：文件为空 $out"
        exit 1
    fi


    chmod +x "$out"
}

calc_argo_port() {
    case "$argo" in
        vmpt)
            echo "Vmess" > "$HOME/agsb/vlvm"
            cat "$HOME/agsb/port_vm_ws"
            ;;
        trpt)
            echo "Trojan" > "$HOME/agsb/vlvm"
            cat "$HOME/agsb/port_tr"
            ;;
        *)
            return 1
            ;;
    esac
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
    local argoname="$1"
    local argodomain=""

    yellow "申请Argo${argoname}隧道中……请稍等"
    sleep 8

    if [ -n "${ARGO_DOMAIN}" ] && [ -n "${ARGO_AUTH}" ]; then
        # 固定 Argo：直接读取保存的域名
        argodomain=$(cat "$HOME/agsb/sbargoym.log" 2>/dev/null)
    else
        # 临时 Argo：从日志中解析 trycloudflare 域名
        argodomain=$(grep -a trycloudflare.com "$HOME/agsb/argo.log" 2>/dev/null \
            | awk 'NR==2{print}' \
            | awk -F// '{print $2}' \
            | awk '{print $1}')
    fi

    if [ -n "${argodomain}" ]; then
        green "Argo${argoname}隧道申请成功"
    else
        purple "Argo${argoname}隧道申请失败"
    fi
}



# 开机自启argo
append_argo_cron_legacy() {
    # 只在启用了 argo + vmag 的情况下处理
    if [ -z "$argo" ] || [ -z "$vmag" ]; then
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
    short_id="${short_id}" \
    cdnym="${cdnym}" \
    name="${name}" \
    ippz="${ippz}" \
    argo="${argo}" \
    uuid="${uuid}" \
    vmpt="${port_vm_ws}" \
    trpt="${port_tr}" \
    hypt="${port_hy2}" \
    tupt="${port_tu}" \
    vlrt="${port_vlr}" \
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




ins(){
    # =====================================================
    # 1. 安装并启动 sing-box
    # =====================================================
    installsb
    set_sbyx
    sbbout

    # =====================================================
    # 2. Argo 相关逻辑（仅在启用 argo + vmag 时）
    # =====================================================
    if [ -n "$argo" ] && [ -n "$vmag" ]; then
        echo
        echo "=========启用Cloudflared-argo内核========="

        # 2.1 确保 cloudflared 内核存在
        ensure_cloudflared

        # 2.2 计算 Argo 本地端口
        argoport=$(calc_argo_port) || {
            red "无法确定 Argo 本地端口"
            exit 1
        }
        echo "$argoport" > "$HOME/agsb/argoport.log"

        # 2.3 生成 Argo 凭据（JSON / token）
        # 仅用于“当前启动流程”，不用于重启判断
        prepare_argo_credentials "$ARGO_AUTH" "$ARGO_DOMAIN" "$argoport"

        # 2.4 启动 Argo（固定 / 临时）
        if [ -n "$ARGO_DOMAIN" ] && [ -n "$ARGO_AUTH" ]; then
            argoname="固定"

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
            argoname="临时"
            start_argo_no_daemon "temp" "" "$argoport"
        fi

        # 2.5 等待并检查 Argo 申请结果（原版 sleep + grep 逻辑）
        wait_and_check_argo "$argoname"
    fi

    # =====================================================
    # 3. 安装完成后的 legacy 收尾逻辑
    #    （进程检测 / bashrc / cron / 自启）
    # =====================================================
    post_install_finalize_legacy
}




# Write environment variables to files for persistence
write2AgsbFolders(){
    # Write environment variables to files for persistence
    echo "${vl_sni}" > "$HOME/agsb/vl_sni"
    echo "${hy_sni}" > "$HOME/agsb/hy_sni"
    echo "${tu_sni}" > "$HOME/agsb/tu_sni"
    echo "${cdn_host}" > "$HOME/agsb/cdn_host"
}

#   show status
agsbstatus() {
    purple "=========当前内核运行状态========="

    cloudflared_version=$("$HOME/agsb/cloudflared" version 2>/dev/null | grep -oP '\d+\.\d+\.\d+')

    #singbox 的版本格式为r.1.12.13 这样，返回1.12.13
    singbox_version=$("$HOME/agsb/sing-box" version 2>/dev/null | grep -oP '(?<=r)\d+\.\d+\.\d+')





    if [ -n "$singbox_version" ]; then
         echo "Sing-box (版本V$singbox_version)：$(green "运行中")"
    else
         echo "Sing-box：$(red "未启用")" 
    fi

    if [ -n "$cloudflared_version" ]; then
      echo "cloudflared Argo (版本V$cloudflared_version)：$(green "运行中")" 
    else
        echo "Argo：$(red "未启用")"
    fi

}


# show nodes
cip(){
    ipbest(){ serip=$( (curl -s4m5 -k "$v46url") || (wget -4 -qO- --tries=2 "$v46url") ); if echo "$serip" | grep -q ':'; then server_ip="[$serip]"; else server_ip="$serip"; fi; echo "$server_ip" > "$HOME/agsb/server_ip.log"; }
    ipchange(){
        v4v6
        v4dq=$( (curl -s4m5 -k https://ip.fm 2>/dev/null | sed -E 's/.*Location: ([^,]+(, [^,]+)*),.*/\1/') || (wget -4 -qO- --tries=2 https://ip.fm 2>/dev/null | grep '<span class="has-text-grey-light">Location:' | tail -n1 | sed -E 's/.*>Location: <\/span>([^<]+)<.*/\1/') )
        v6dq=$( (curl -s6m5 -k https://ip.fm 2>/dev/null | sed -E 's/.*Location: ([^,]+(, [^,]+)*),.*/\1/') || (wget -6 -qO- --tries=2 https://ip.fm 2>/dev/null | grep '<span class="has-text-grey-light">Location:' | tail -n1 | sed -E 's/.*>Location: <\/span>([^<]+)<.*/\1/') )
        if [ -z "$v4" ]; then vps_ipv4='无IPV4'; vps_ipv6="$v6"; location=$v6dq; elif [ -n "$v4" ] && [ -n "$v6" ]; then vps_ipv4="$v4"; vps_ipv6="$v6"; location=$v4dq; else vps_ipv4="$v4"; vps_ipv6='无IPV6'; location=$v4dq; fi
        echo; agsbstatus; echo; green "=========当前服务器本地IP情况========="; yellow "本地IPV4地址：$vps_ipv4"; purple "本地IPV6地址：$vps_ipv6"; green "服务器地区：$location"; echo; sleep 2
        if [ "$ippz" = "4" ]; then if [ -z "$v4" ]; then ipbest; else server_ip="$v4"; echo "$server_ip" > "$HOME/agsb/server_ip.log"; fi; elif [ "$ippz" = "6" ]; then if [ -z "$v6" ]; then ipbest; else server_ip="[$v6]"; echo "$server_ip" > "$HOME/agsb/server_ip.log"; fi; else ipbest; fi
    }
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
        hy2_link="hysteria2://$uuid@$server_ip:$port_hy2?security=tls&alpn=h3&insecure=1&sni=${hy_sni}#${sxname}hy2-$hostname"; 
        yellow "💣【 Hysteria2 】(直连协议)"; 
        green "$hy2_link" | tee -a "$HOME/agsb/jh.txt"; 
        echo; 
    fi
    
    
     # TUIC protocol (tuic or tupt)
    if grep -q "tuic-sb" "$HOME/agsb/sb.json"; then
        port_tu=$(cat "$HOME/agsb/port_tu")
        tu_sni=$(cat "$HOME/agsb/tu_sni"); 
        password=$uuid

        tuic_link="tuic://${uuid}:${password}@${server_ip}:${port_tu}?sni=${tu_sni}&congestion_control=bbr&security=tls&udp_relay_mode=native&alpn=h3&allow_insecure=1#${sxname}tuic-$hostname"
        yellow "💣【 TUIC 】(直连协议)"
        green "$tuic_link" | tee -a "$HOME/agsb/jh.txt"
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
        yellow "💣【 VLESS-Reality-Vision 】(直连协议)"; green "$vless_link" | tee -a "$HOME/agsb/jh.txt"; echo;
    fi
    argodomain=$(cat "$HOME/agsb/sbargoym.log" 2>/dev/null); [ -z "$argodomain" ] && argodomain=$(grep -a trycloudflare.com "$HOME/agsb/argo.log" 2>/dev/null | awk 'NR==2{print}' | awk -F// '{print $2}' | awk '{print $1}')
    cdn_host=$(cat "$HOME/agsb/cdn_host")

    if [ -n "$argodomain" ]; then
        vlvm=$(cat $HOME/agsb/vlvm 2>/dev/null); uuid=$(cat "$HOME/agsb/uuid")
        if [ "$vlvm" = "Vmess" ]; then
            vmatls_link1="vmess://$(echo "{\"v\":\"2\",\"ps\":\"${sxname}vmess-ws-tls-argo-$hostname-443\",\"add\":\"${cdn_host}\",\"port\":\"443\",\"id\":\"$uuid\",\"aid\":\"0\",\"net\":\"ws\",\"host\":\"$argodomain\",\"path\":\"/${uuid}-vm\",\"tls\":\"tls\",\"sni\":\"$argodomain\"}" | base64 | tr -d '\n')"
           
            tratls_link1=""
        elif [ "$vlvm" = "Trojan" ]; then
            tratls_link1="trojan://${uuid}@${cdn_host}:443?security=tls&type=ws&host=${argodomain}&path=%2F${uuid}-tr&sni=${argodomain}&fp=chrome#${sxname}trojan-ws-tls-argo-$hostname-443"
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
        green "💣 443端口 Argo-TLS 节点 (优选IP可替换):"
        green "${vmatls_link1}${tratls_link1}" | tee -a "$HOME/agsb/jh.txt"

        yellow "---------------------------------------------------------"


    fi
    echo; yellow "聚合节点: cat $HOME/agsb/jh.txt"; yellow "========================================================="; purple "相关快捷方式如下："; showmode
}

# Remove agsb folder
cleandel(){
    # Change to $HOME to avoid issues when deleting directories
   cd "$HOME" || exit 1

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



if [ "$1" = "del" ]; then 
    cleandel; 
    rm -rf "$HOME/agsb"; 
    echo "卸载完成"; 
    showmode; 
    exit;
 fi
if [ "$1" = "rep" ]; then 
    cleandel; 
    rm -rf "$HOME/agsb"/{sb.json,sbargoym.log,sbargotoken.log,argo.log,argoport.log,cdnym,name,short_id,cdn_host,hy_sni,vl_sni,tu_sni}; 
    echo "重置完成..."; 
    sleep 2; 
fi

if [ "$1" = "list" ]; then 
    
    cip; 
    exit; 
fi
if [ "$1" = "ups" ]; then 
    pkill -15 -f "$HOME/agsb/sing-box" 2>/dev/null

    upsingbox && sbrestart && echo "Sing-box内核更新完成" && sleep 2 && cip; 
    exit; 
fi
if [ "$1" = "res" ]; then 
    sbrestart; argorestart; 
    sleep 5 && echo "重启完成" && sleep 3 && cip; 
    exit; 
fi
if ! pgrep -f 'agsb/sing-box' >/dev/null 2>&1 && [ "$1" != "rep" ]; then
    cleandel
fi
if ! pgrep -f 'agsb/sing-box' >/dev/null 2>&1 || [ "$1" = "rep" ]; then
    if [ -z "$( (curl -s4m5 -k "$v46url") || (wget -4 -qO- --tries=2 "$v46url") )" ]; then 
        cp -f /etc/resolv.conf /etc/resolv.conf.bak.agsb 2>/dev/null
        echo -e "nameserver 1.1.1.1\nnameserver 8.8.8.8\nnameserver 2606:4700:4700::1111\nnameserver 2001:4860:4860::8888" > /etc/resolv.conf
    
    fi
    echo "VPS系统：$op"; 
    echo "CPU架构：$cpu"; 
    echo "agsb脚本开始安装/更新…………" && sleep 1

    if [ -n "$oap" ]; then 
        setenforce 0 >/dev/null 2>&1; 
        iptables -F; 
        iptables -P INPUT ACCEPT; 
        netfilter-persistent save >/dev/null 2>&1;
        echo "iptables执行开放所有端口"; 
    fi
    ins; 
    cip
else
    echo "agsb脚本已安装"; 
    echo; 
    agsbstatus; 
    echo; 
    echo "相关快捷方式如下："; 
    showmode; 
    exit
fi




