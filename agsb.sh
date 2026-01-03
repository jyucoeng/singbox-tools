#!/bin/sh
export LANG=en_US.UTF-8


AUTHOR="littleDoraemon"
VERSION="1.0.4(2026-01-03)"


# ================== Argo 参数快照（彻底隔离 shell 环境） ==================
ARG_AG_VM_FLAG="${argo_vm_flag-}"
ARG_AG_VM_DOMAIN="${ag_vm_domain-}"
ARG_AG_VM_TOKEN="${ag_vm_token-}"

ARG_AG_TR_FLAG="${argo_tr_flag-}"
ARG_AG_TR_DOMAIN="${ag_tr_domain-}"
ARG_AGK_TR_TOKEN="${ag_tr_token-}"

# 立刻切断 shell 环境污染
unset argo_vm_flag ag_vm_domain ag_vm_token
unset argo_tr_flag ag_tr_domain ag_tr_token

# ================== 颜色函数 ==================
white(){ echo -e "\033[1;37m$1\033[0m"; }
red(){ echo -e "\e[1;91m$1\033[0m"; }
green(){ echo -e "\e[1;32m$1\033[0m"; }
yellow(){ echo -e "\e[1;33m$1\033[0m"; }
blue(){ echo -e "\e[1;34m$1\033[0m"; }
purple(){ echo -e "\e[1;35m$1\033[0m"; }

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

# ================== 协议开关 ==================
[ -z "${vmpt+x}" ] || vmp=yes
[ -z "${trpt+x}" ] || trp=yes
[ -z "${hypt+x}" ] || hyp=yes
[ -z "${vlrt+x}" ] || vlr=yes


# Argo / CDN 入口域名（仅用于 add，占位）
CDN_DOMAIN_DEFAULT="www.bing.com"

CONF_DIR="$HOME/agsb"
CONF_FILE="$CONF_DIR/config.env"


# ================== 基础变量 ==================
export uuid=${uuid:-''}
export port_vm_ws=${vmpt:-''} # vmess 端口
export port_tr=${trpt:-''}  # trojan 端口
export port_hy2=${hypt:-''}   # hy2 端口
export port_vlr=${vlrt:-''}  # vless 端口

v46url="https://icanhazip.com"
agsburl="https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/agsb.sh"

mkdir -p "$HOME/agsb"

showmode(){

    blue "===================================================="
    gradient "       agsb 一键脚本（双 Argo ·  4 协议）"
    green    "       作者：$AUTHOR"
    yellow   "       版本：$VERSION"
    blue "===================================================="
    echo ""
    yellow "------------------------------------------------"
    yellow "agsb list    查看节点"
    yellow "agsb res     重启"
    yellow "agsb ups     更新 sing-box"
    yellow "agsb rep     重置(会先卸载然后再安装)"
    yellow "agsb del     卸载"
    yellow "agsb help    查看功能菜单"
    yellow "------------------------------------------------"
}

check_root(){
    if [ "$EUID" -ne 0 ]; then
        red "依赖安装需要 root 权限，请使用 root 运行脚本"
        exit 1
    fi
}


get_cdn_domain() {
    local _cdn=""

    # 1. 环境变量优先
    if [ -n "$cdn" ]; then
        _cdn="$cdn"

    # 2. 已加载的脚本变量（load_cdn_domain 设置的）
    elif [ -n "$CDN_DOMAIN" ]; then
        _cdn="$CDN_DOMAIN"

    # 3. 配置文件
    elif [ -f "$CONF_FILE" ]; then
        _cdn=$( . "$CONF_FILE" 2>/dev/null; echo "$CDN_DOMAIN" )

    # 4. 默认值
    else
        _cdn="$CDN_DOMAIN_DEFAULT"
    fi

    echo "$_cdn"
}

load_cdn_domain() {
    CDN_DOMAIN=$(get_cdn_domain)
    blue "当前 CDN 域名：$CDN_DOMAIN"
}

persist_cdn_domain() {
    [ -n "$cdn" ] || return
    mkdir -p "$CONF_DIR"
    echo "CDN_DOMAIN=\"$CDN_DOMAIN\"" > "$CONF_FILE"
    green "CDN 域名已保存：$CDN_DOMAIN"
}



# ================== 依赖管理模块（彩色版） ==================

# ---------- OS 检测 ----------
detect_os() {
    if [ -f /etc/alpine-release ]; then
        OS_FAMILY="alpine"
        PKG_MGR="apk"
        green "系统识别：Alpine Linux"
    elif [ -f /etc/debian_version ]; then
        OS_FAMILY="debian"
        PKG_MGR="apt"
        green "系统识别：Debian / Ubuntu"
    else
        red "不支持的系统（仅支持 Alpine / Debian / Ubuntu）"
        exit 1
    fi
}

# ---------- 命令是否存在 ----------
has_cmd() {
    command -v "$1" >/dev/null 2>&1
}

# ---------- 包是否已安装 ----------
pkg_installed() {
    case "$OS_FAMILY" in
        alpine)
            apk info -e "$1" >/dev/null 2>&1
            ;;
        debian)
            dpkg -s "$1" >/dev/null 2>&1
            ;;
    esac
}

# ---------- 软件源更新 ----------
pkg_update() {
    purple "更新系统软件源..."

    case "$OS_FAMILY" in
        alpine)
            apk update >/dev/null 2>&1
            ;;
        debian)
            export DEBIAN_FRONTEND=noninteractive
            apt update -y >/dev/null 2>&1
            ;;
    esac

    green "软件源更新完成"
}

# ---------- 安装单个包 ----------
install_pkg() {
    pkg="$1"

    if pkg_installed "$pkg"; then
        blue "依赖已存在：$pkg"
        return
    fi

    yellow "正在安装依赖：$pkg"

    case "$OS_FAMILY" in
        alpine)
            apk add --no-cache "$pkg" \
                && green "安装完成：$pkg" \
                || red "安装失败：$pkg"
            ;;
        debian)
            export DEBIAN_FRONTEND=noninteractive
            apt install -y "$pkg" \
                && green "安装完成：$pkg" \
                || red "安装失败：$pkg"
            ;;
    esac
}

# ---------- 依赖检查入口 ----------
ensure_deps() {
    blue "=========================================="
    blue "        开始检查系统运行依赖"
    blue "=========================================="

    detect_os
    pkg_update

    # ---- 基础安全依赖 ----
    install_pkg ca-certificates

    # ---- 加密依赖（HY2 / Reality 必需）----
    install_pkg openssl

    # ---- 下载工具（curl / wget 二选一）----
    if has_cmd curl; then
        blue "下载工具：curl 已存在"
    elif has_cmd wget; then
        blue "下载工具：wget 已存在"
    else
        yellow "未检测到下载工具，安装 curl"
        install_pkg curl
    fi

    green "系统依赖检查与安装完成"
    blue "=========================================="
}


# ================== 架构判断 ==================
case $(uname -m) in
    aarch64) cpu=arm64 ;;
    x86_64) cpu=amd64 ;;
    *) echo "不支持的架构：$(uname -m)" && exit 1 ;;
esac

# ================== IP 探测 ==================
v4v6(){
    v4=$( (curl -s4m5 -k "$v46url") || (wget -4 -qO- --tries=2 "$v46url") )
    v6=$( (curl -s6m5 -k "$v46url") || (wget -6 -qO- --tries=2 "$v46url") )
}

# ================== 安装 / 更新 sing-box ==================
upsingbox(){
    url="https://github.com/jyucoeng/singbox-tools/releases/download/singbox/sing-box-$cpu"
    out="$HOME/agsb/sing-box"
    (curl -Lo "$out" -# --retry 2 "$url") || (wget -O "$out" --tries=2 "$url")
    chmod +x "$out"
    sbcore=$("$out" version 2>/dev/null | awk '/version/{print $NF}')
    green "已安装 sing-box 内核：$sbcore"
}

# ================== UUID 处理 ==================
insuuid(){
    [ -e "$HOME/agsb/sing-box" ] || upsingbox
    if [ -z "$uuid" ] && [ ! -e "$HOME/agsb/uuid" ]; then
        uuid=$("$HOME/agsb/sing-box" generate uuid)
        echo "$uuid" > "$HOME/agsb/uuid"
    elif [ -n "$uuid" ]; then
        echo "$uuid" > "$HOME/agsb/uuid"
    fi
    uuid=$(cat "$HOME/agsb/uuid")
    echo "UUID：$uuid"
}

# ================== 生成 sing-box 配置 ==================
installsb(){
    echo "====== 配置 sing-box Inbounds ======"
    [ -e "$HOME/agsb/sing-box" ] || upsingbox

    cat > "$HOME/agsb/sb.json" <<EOF
{
"log": { "level": "info", "timestamp": true },
"inbounds": [
EOF

    insuuid

    # ---------- TLS 证书（HY2） ----------
    openssl ecparam -genkey -name prime256v1 -out "$HOME/agsb/private.key" >/dev/null 2>&1
    openssl req -new -x509 -days 36500 -key "$HOME/agsb/private.key" \
        -out "$HOME/agsb/cert.pem" -subj "/CN=$CDN_DOMAIN" >/dev/null 2>&1

    # ================== Hysteria2 ==================
    if [ -n "$hyp" ]; then
        [ -n "$port_hy2" ] || port_hy2=$(shuf -i 10000-65535 -n 1)
        echo "$port_hy2" > "$HOME/agsb/port_hy2"
        echo "HY2 端口：$port_hy2"

cat >> "$HOME/agsb/sb.json" <<EOF
{
"type": "hysteria2",
"tag": "hy2",
"listen": "::",
"listen_port": $port_hy2,
"users": [{ "password": "$uuid" }],
"tls": {
  "enabled": true,
  "alpn": ["h3"],
  "certificate_path": "$HOME/agsb/cert.pem",
  "key_path": "$HOME/agsb/private.key"
}
},
EOF
    fi

    # ================== Trojan WS ==================
    if [ -n "$trp" ]; then
        [ -n "$port_tr" ] || port_tr=$(shuf -i 10000-65535 -n 1)
        echo "$port_tr" > "$HOME/agsb/port_tr"
        echo "Trojan WS 端口：$port_tr"

cat >> "$HOME/agsb/sb.json" <<EOF
{
"type": "trojan",
"tag": "trojan-ws",
"listen": "::",
"listen_port": $port_tr,
"users": [{ "password": "$uuid" }],
"transport": {
  "type": "ws",
  "path": "/$uuid-tr"
}
},
EOF
    fi

    # ================== VMess WS ==================
    if [ -n "$vmp" ]; then
        [ -n "$port_vm_ws" ] || port_vm_ws=$(shuf -i 10000-65535 -n 1)
        echo "$port_vm_ws" > "$HOME/agsb/port_vm_ws"
        echo "VMess WS 端口：$port_vm_ws"

cat >> "$HOME/agsb/sb.json" <<EOF
{
"type": "vmess",
"tag": "vmess-ws",
"listen": "::",
"listen_port": $port_vm_ws,
"users": [{ "uuid": "$uuid", "alterId": 0 }],
"transport": {
  "type": "ws",
  "path": "/$uuid-vm"
}
},
EOF
    fi

    # ================== VLESS Reality ==================
    if [ -n "$vlr" ]; then
        [ -n "$port_vlr" ] || port_vlr=$(shuf -i 10000-65535 -n 1)
        echo "$port_vlr" > "$HOME/agsb/port_vlr"
        echo "VLESS Reality 端口：$port_vlr"

        [ -f "$HOME/agsb/reality.key" ] || \
            "$HOME/agsb/sing-box" generate reality-keypair > "$HOME/agsb/reality.key"

        private_key=$(awk 'NR==1{print $2}' "$HOME/agsb/reality.key")
        public_key=$(awk 'NR==2{print $2}' "$HOME/agsb/reality.key")

        [ -f "$HOME/agsb/short_id" ] || openssl rand -hex 4 > "$HOME/agsb/short_id"
        short_id=$(cat "$HOME/agsb/short_id")


cat >> "$HOME/agsb/sb.json" <<EOF
{
"type": "vless",
"tag": "vless-reality",
"listen": "::",
"listen_port": $port_vlr,
"users": [{ "uuid": "$uuid", "flow": "xtls-rprx-vision" }],
"tls": {
  "enabled": true,
  "server_name": "$CDN_DOMAIN",
  "reality": {
    "enabled": true,
    "handshake": { "server": "$CDN_DOMAIN", "server_port": 443 },
    "private_key": "$private_key",
    "short_id": ["$short_id"]
  }
}
},
EOF
    fi
}

# ================== 完成 sb.json + 启动 sing-box ==================
sbbout(){
    sed -i '${s/,\s*$//}' "$HOME/agsb/sb.json"
    cat >> "$HOME/agsb/sb.json" <<EOF
],
"outbounds": [
  { "type": "direct", "tag": "direct" },
  { "type": "block", "tag": "block" }
],
"route": {
  "rules": [
    { "action": "sniff" },
    { "action": "resolve", "strategy": "prefer_ipv6" }
  ],
  "final": "direct"
}
}
EOF

    if pidof systemd >/dev/null 2>&1 && [ "$EUID" -eq 0 ]; then
        cat > /etc/systemd/system/sb.service <<EOF
[Unit]
Description=sing-box service
After=network.target

[Service]
Type=simple
ExecStart=$HOME/agsb/sing-box run -c $HOME/agsb/sb.json
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable sb
        systemctl restart sb
    elif command -v rc-service >/dev/null 2>&1 && [ "$EUID" -eq 0 ]; then
        cat > /etc/init.d/sing-box <<EOF
#!/sbin/openrc-run
command="$HOME/agsb/sing-box"
command_args="run -c $HOME/agsb/sb.json"
command_background=yes
pidfile="/run/sing-box.pid"
EOF
        chmod +x /etc/init.d/sing-box
        rc-update add sing-box default
        rc-service sing-box restart
    else
        nohup "$HOME/agsb/sing-box" run -c "$HOME/agsb/sb.json" >/dev/null 2>&1 &
    fi
}

# ================== 安装 cloudflared ==================
install_cloudflared(){
    [ -e "$HOME/agsb/cloudflared" ] && return
    url="https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-$cpu"
    out="$HOME/agsb/cloudflared"
    (curl -Lo "$out" -# --retry 2 "$url") || (wget -O "$out" "$url")
    chmod +x "$out"
}

create_argo_vm_service(){
    cat > /etc/systemd/system/argo-vm.service <<EOF
[Unit]
Description=Cloudflare Argo Tunnel (VMess)
After=network.target sb.service
Requires=sb.service

[Service]
Type=simple
EnvironmentFile=$HOME/agsb/argo-vm.env

# 使用 sh -c，确保重定向与变量展开行为一致
ExecStart=/bin/sh -c '$HOME/agsb/cloudflared tunnel \
  --no-autoupdate \
  --edge-ip-version auto \
  --url http://localhost:\${VM_PORT} \
  run --token \${VM_TOKEN} \
  >/dev/null 2>&1'

Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
}




create_argo_vm_openrc(){
    cat > /etc/init.d/argo-vm <<EOF
#!/sbin/openrc-run
description="Cloudflare Argo Tunnel (VMess)"

command="$HOME/agsb/cloudflared"
pidfile="/run/argo-vm.pid"

start_pre() {
    . "$HOME/agsb/argo-vm.env"
}

command_args="tunnel --no-autoupdate --edge-ip-version auto \
  --url http://localhost:\${VM_PORT} \
  run --token ${VM_TOKEN} \
  >/dev/null 2>&1"

depend() {
    need net
}
EOF
    chmod +x /etc/init.d/argo-vm
}







create_argo_tr_service(){
    cat > /etc/systemd/system/argo-tr.service <<EOF
[Unit]
Description=Cloudflare Argo Tunnel (Trojan)
After=network.target sb.service
Requires=sb.service

[Service]
Type=simple
EnvironmentFile=$HOME/agsb/argo-tr.env

# 使用 sh -c，确保变量展开与输出重定向行为一致
ExecStart=/bin/sh -c '$HOME/agsb/cloudflared tunnel \
  --no-autoupdate \
  --edge-ip-version auto \
  --url http://localhost:\${TR_PORT} \
  run --token \${TR_TOKEN} \
  >/dev/null 2>&1'

Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF
}



create_argo_tr_openrc(){
    cat > /etc/init.d/argo-tr <<EOF
#!/sbin/openrc-run
description="Cloudflare Argo Tunnel (Trojan)"

command="$HOME/agsb/cloudflared"
command_background="yes"
pidfile="/run/argo-tr.pid"

start_pre() {
    if [ -f "$HOME/agsb/argo-tr.env" ]; then
        . "$HOME/agsb/argo-tr.env"
    else
        echo "Argo Trojan env 文件不存在"
        return 1
    fi
}

command_args="tunnel --no-autoupdate --edge-ip-version auto \
  --url http://localhost:\${TR_PORT} \
  run --token \${TR_TOKEN} \
  >/dev/null 2>&1"

depend() {
    need net
}
EOF
    chmod +x /etc/init.d/argo-tr
}





# ================== 启动 VMess Argo ==================

start_argo_vm(){
    [ -z "$ARG_AG_VM_FLAG" ] && return
    [ -z "$ARG_AG_VM_TOKEN" ] && return

    [ -z "$port_vm_ws" ] && return

    install_cloudflared

    # systemd
   if command -v systemctl >/dev/null 2>&1 && pidof systemd >/dev/null 2>&1; then
        create_argo_vm_service
        echo "VM_PORT=$port_vm_ws" > "$HOME/agsb/argo-vm.env"
        echo "VM_TOKEN=$ARG_AG_VM_TOKEN" >> "$HOME/agsb/argo-vm.env"
        systemctl daemon-reload
        systemctl enable argo-vm >/dev/null 2>&1
        systemctl restart argo-vm
        return
    fi

    # openrc (Alpine)
    if command -v rc-service >/dev/null 2>&1; then
        create_argo_vm_openrc
        echo "VM_PORT=$port_vm_ws" > "$HOME/agsb/argo-vm.env"
        echo "VM_TOKEN=$ARG_AG_VM_TOKEN" >> "$HOME/agsb/argo-vm.env"
        rc-update add argo-vm default >/dev/null 2>&1
        rc-service argo-vm restart
        return
    fi
}




# ================== 启动 Trojan Argo（完全正确版） ==================
start_argo_tr(){
    [ -z "$ARG_AG_TR_FLAG" ] && return
    [ -z "$ARG_AGK_TR_TOKEN" ] && return
    [ -z "$port_tr" ] && return

    install_cloudflared

    # systemd
    if command -v systemctl >/dev/null 2>&1 && pidof systemd >/dev/null 2>&1; then
        create_argo_tr_service
        echo "TR_PORT=$port_tr" > "$HOME/agsb/argo-tr.env"
        echo "TR_TOKEN=$ARG_AGK_TR_TOKEN" >> "$HOME/agsb/argo-tr.env"
        systemctl daemon-reload
        systemctl enable argo-tr >/dev/null 2>&1
        systemctl restart argo-tr
        return
    fi

    # openrc (Alpine)
    if command -v rc-service >/dev/null 2>&1; then
        create_argo_tr_openrc
        echo "TR_PORT=$port_tr" > "$HOME/agsb/argo-tr.env"
        echo "TR_TOKEN=$ARG_AGK_TR_TOKEN" >> "$HOME/agsb/argo-tr.env"
        rc-update add argo-tr default >/dev/null 2>&1
        rc-service argo-tr restart
        return
    fi
}


# ================== 主安装流程 ==================
ins(){
    ensure_deps
    persist_cdn_domain
    installsb
    sbbout
    start_argo_vm
    start_argo_tr
    echo "所有服务启动完成"
}


# ================== 状态检查 ==================

agsbstatus(){
    echo "========= 当前运行状态 ========="

    if pidof systemd >/dev/null 2>&1; then
        systemctl is-active sb >/dev/null && echo "Sing-box：运行中" || echo "Sing-box：未运行"
        [ -n "$ARG_AG_VM_FLAG" ] && (systemctl is-active argo-vm >/dev/null && echo "VMess Argo：运行中" || echo "VMess Argo：未运行")
        [ -n "$ARG_AG_TR_FLAG" ] && (systemctl is-active argo-tr >/dev/null && echo "Trojan Argo：运行中" || echo "Trojan Argo：未运行")
    elif command -v rc-service >/dev/null 2>&1; then
        rc-service sing-box status >/dev/null 2>&1 && echo "Sing-box：运行中" || echo "Sing-box：未运行"
        [ -n "$ARG_AG_VM_FLAG" ] && (rc-service argo-vm status >/dev/null 2>&1 && echo "VMess Argo：运行中" || echo "VMess Argo：未运行")
        [ -n "$ARG_AG_TR_FLAG" ] && (rc-service argo-tr status >/dev/null 2>&1 && echo "Trojan Argo：运行中" || echo "Trojan Argo：未运行")
    fi
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
    echo ""
    yellow "二维码链接："
    echo "https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${link}"
    echo ""
    echo ""
}


# ================== IP & 节点输出 ==================
cip(){
    v4v6
    [ -f "$HOME/agsb/uuid" ] || {
        red "未找到 UUID，请先运行安装"
    return 1
}
    uuid=$(cat "$HOME/agsb/uuid")

  

    server_v4=""
    server_v6=""

    [ -n "$v4" ] && server_v4="$v4"
    [ -n "$v6" ] && server_v6="[$v6]"

    cdn_domain=$(get_cdn_domain)

    [ -n "$cdn_domain" ] || {
        red "CDN 域名为空，配置异常"
        return 1
    }



    echo
    purple "================ 节点信息 ================"

    # ================= IPv4 =================
    if [ -n "$server_v4" ]; then
        purple "----------- IPv4 -----------"

        # Hysteria2
        if [ -f "$HOME/agsb/port_hy2" ]; then
            port_hy2=$(cat "$HOME/agsb/port_hy2")
            yellow "【Hysteria2】"
            content="hysteria2://$uuid@$server_v4:$port_hy2?security=tls&alpn=h3&insecure=1&sni=$cdn_domain"
            green "$content"
           # generate_qr "$content"
            echo
        fi

        # VLESS Reality
        if [ -f "$HOME/agsb/port_vlr" ]; then
            port_vlr=$(cat "$HOME/agsb/port_vlr")
            public_key=$(awk 'NR==2{print $2}' "$HOME/agsb/reality.key")
            short_id=$(cat "$HOME/agsb/short_id")
            yellow "【VLESS Reality】"
            content="vless://$uuid@$server_v4:$port_vlr?encryption=none&security=reality&sni=$cdn_domain&fp=chrome&flow=xtls-rprx-vision&publicKey=$public_key&shortId=$short_id"
            green "$content"
           # generate_qr "$content"
            echo
        fi
    fi

    # ================= IPv6 =================
    if [ -n "$server_v6" ]; then
        purple "----------- IPv6 -----------"

        # Hysteria2
        if [ -f "$HOME/agsb/port_hy2" ]; then
            port_hy2=$(cat "$HOME/agsb/port_hy2")
            yellow "【Hysteria2】"
            content="hysteria2://$uuid@$server_v6:$port_hy2?security=tls&alpn=h3&insecure=1&sni=$cdn_domain"
            green "$content"
           # generate_qr "$content"
            echo
        fi

        # VLESS Reality
        if [ -f "$HOME/agsb/port_vlr" ]; then
            port_vlr=$(cat "$HOME/agsb/port_vlr")
            public_key=$(awk 'NR==2{print $2}' "$HOME/agsb/reality.key")
            short_id=$(cat "$HOME/agsb/short_id")
            yellow "【VLESS Reality】"
            content="vless://$uuid@$server_v6:$port_vlr?encryption=none&security=reality&sni=$cdn_domain&fp=chrome&flow=xtls-rprx-vision&publicKey=$public_key&shortId=$short_id"
            green "$content"
          #  generate_qr "$content"
            echo
        fi
    fi

    # ================= Argo（不分 IP） =================
    if [ -n "$ARG_AG_VM_FLAG" ] && [ -n "$ARG_AG_VM_DOMAIN" ]; then
        purple "----------- Argo -----------"
        vmess_json=$(printf '{"v":"2","ps":"vmess-argo","add":"%s","port":"443","id":"%s","aid":"0","net":"ws","type":"none","host":"%s","path":"/%s-vm","tls":"tls","sni":"%s"}' \
            "$cdn_domain" "$uuid" "$ARG_AG_VM_DOMAIN" "$uuid" "$ARG_AG_VM_DOMAIN")
        
        vmess_b64=$(echo "$vmess_json" | base64 | tr -d '\n')

        yellow "【VMess Argo】"
        content="vmess://$vmess_b64"
        green "$content"
       # generate_qr "$content"
        echo
    fi

    if [ -n "$ARG_AG_TR_FLAG" ] && [ -n "$ARG_AG_TR_DOMAIN" ]; then
        yellow "【Trojan Argo】"
        content="trojan://$uuid@$cdn_domain:443?security=tls&type=ws&host=$ARG_AG_TR_DOMAIN&path=/$uuid-tr&sni=$ARG_AG_TR_DOMAIN&fp=chrome"
        green "$content"
      #  generate_qr "$content"
        echo
    fi

    purple "==============节点信息到这里就结束了======================="
}


# ================== 清理 / 卸载 ==================

# ================== 清理 Argo 服务（systemd / openrc） ==================
cleanup_argo(){
    for name in argo-vm argo-tr; do

        # ----- systemd -----
        if command -v systemctl >/dev/null 2>&1 && pidof systemd >/dev/null 2>&1; then
            systemctl stop "$name" >/dev/null 2>&1 || true
            systemctl disable "$name" >/dev/null 2>&1 || true
            rm -f "/etc/systemd/system/$name.service"
        fi

        # ----- openrc -----
        if command -v rc-service >/dev/null 2>&1; then
            rc-service "$name" stop >/dev/null 2>&1 || true
            rc-update del "$name" default >/dev/null 2>&1 || true
            rm -f "/etc/init.d/$name"
        fi

        # ----- runtime files -----
        rm -f "/run/$name.pid"
        rm -f "$HOME/agsb/${name}.pid"
        rm -f "$HOME/agsb/${name}.log"
        rm -f "$HOME/agsb/${name}.env"
    done
}


cleandel(){
    echo "正在卸载 agsb"
    cleanup_argo

    # systemd
    if pidof systemd >/dev/null 2>&1; then
        systemctl stop sb argo-vm argo-tr 2>/dev/null
        systemctl disable sb argo-vm argo-tr 2>/dev/null
        rm -f /etc/systemd/system/sb.service
        rm -f /etc/systemd/system/argo-vm.service
        rm -f /etc/systemd/system/argo-tr.service
        systemctl daemon-reload
    fi

    # openrc
    if command -v rc-service >/dev/null 2>&1; then
        rc-service sing-box stop 2>/dev/null
        rc-service argo-vm stop 2>/dev/null
        rc-service argo-tr stop 2>/dev/null
        rc-update del sing-box default 2>/dev/null
        rc-update del argo-vm default 2>/dev/null
        rc-update del argo-tr default 2>/dev/null
        rm -f /etc/init.d/sing-box
        rm -f /etc/init.d/argo-vm
        rm -f /etc/init.d/argo-tr
    fi

    rm -rf "$HOME/agsb"

    echo "agsb 已彻底卸载"
}





# ================== 重启 ==================


sbrestart(){
    echo "重启 sing-box 与 Argo"

    if pidof systemd >/dev/null 2>&1; then
        systemctl restart sb
    elif command -v rc-service >/dev/null 2>&1; then
        rc-service sing-box restart
    else
        pkill -f "$HOME/agsb/sing-box" 2>/dev/null
        nohup "$HOME/agsb/sing-box" run -c "$HOME/agsb/sb.json" >/dev/null 2>&1 &
    fi

    # Argo 统一走 start 函数
    start_argo_vm
    start_argo_tr

    echo "重启完成"
}


# ================== 更新 sing-box ==================
ups(){
    pkill -f agsb/sing-box 2>/dev/null
    upsingbox
    sbrestart
}





main(){

    #安装依赖
    check_root
    load_cdn_domain

    showmode
    

    # ================== 参数入口 ==================
    case "$1" in
        list)
            cip
            ;;
        res)
            sbrestart
            cip
            ;;
        ups)
            red "暂不支持内核升级，因为我懒得去做下载包"
            ;;
        rep)
            cleandel
            ins
            cip
            ;;
        del)
            cleandel
            ;;
        help)
            showmode
            ;;
        *)
            ins
            cip
            ;;
    esac
}

main "$@"
