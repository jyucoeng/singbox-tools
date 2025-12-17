#!/bin/bash

# =========================
# Hysteria2安装脚本 (精简版)
# hysteria2-version
# 最后更新时间: 2025.12.16
# =========================

export LANG=en_US.UTF-8

# 固定版本号
SINGBOX_VERSION="1.12.12"


# 项目信息常量
AUTHOR="LittleDoraemon"
VERSION="v1.0.1"

# 定义颜色
re="\033[0m"
red="\033[1;91m"
green="\e[1;32m"
yellow="\e[1;33m"
purple="\e[1;35m"
skyblue="\e[1;36m"
blue="\e[1;34m"
red() { echo -e "\e[1;91m$1\033[0m"; }
green() { echo -e "\e[1;32m$1\033[0m"; }
yellow() { echo -e "\e[1;33m$1\033[0m"; }
purple() { echo -e "\e[1;35m$1\033[0m"; }
skyblue() { echo -e "\e[1;36m$1\033[0m"; }
blue() { echo -e "\e[1;34m$1\033[0m"; }
reading() {
    local prompt="$1"
    local varname="$2"

    # 输出红色提示，不让 read 处理颜色格式（避免污染输入）
    echo -ne "$(red "$prompt")"

    # 读取输入
    read input_value

    # 将输入写入调用时传的变量名
    printf -v "$varname" "%s" "$input_value"
}


# 定义常量
server_name="sing-box"
work_dir="/etc/sing-box"
config_dir="${work_dir}/config.json"
client_dir="${work_dir}/url.txt"
export hy2_port=${PORT:-$(shuf -i 1-65535 -n 1)}

# 默认节点名称常量
# 根据文件名自动判断协议类型
if [[ "${0##*/}" == *"hy2"* || "${0##*/}" == *"hysteria2"* ]]; then
    DEFAULT_NODE_NAME="$AUTHOR-hysteria2"
else
    DEFAULT_NODE_NAME="$AUTHOR"
fi

# 检查是否为root下运行
[[ $EUID -ne 0 ]] && red "请在root用户下运行脚本" && exit 1

# 检查命令是否存在函数
command_exists() { command -v "$1" >/dev/null 2>&1; }

# 检查服务状态通用函数（输出不变）
check_service() {
    local service_name=$1

    # Alpine (OpenRC)
    if command_exists apk; then
        if rc-service "${service_name}" status >/dev/null 2>&1; then
            green "running"
            return 0
        else
            yellow "not running"
            return 1
        fi
    fi

    # systemd
    if systemctl list-unit-files | grep -q "^${service_name}"; then
        if systemctl is-active --quiet "${service_name}"; then
            green "running"
            return 0
        else
            yellow "not running"
            return 1
        fi
    else
        yellow "not installed"
        return 2
    fi
}


# 检查nginx状态
# 检查nginx状态
check_nginx() {
    if command_exists nginx; then
        check_service "nginx"
        return $?
    else
        yellow "not installed"
        return 2
    fi
}

check_singbox() {
    # 优先使用 systemd 的 sing-box.service
    if systemctl list-unit-files 2>/dev/null | grep -q "^sing-box.service"; then
        check_service "sing-box.service"
        return $?
    fi

    # 再尝试 OpenRC 名称（Alpine 常见）
    if command_exists apk && rc-service sing-box status >/dev/null 2>&1; then
        check_service "sing-box"
        return $?
    fi

    yellow "not installed"
    return 2
}

#根据系统类型安装、卸载依赖
manage_packages() {
    if [ $# -lt 2 ]; then
        red "Unspecified package name or action" 
        return 1
    fi

    action=$1
    shift

    for package in "$@"; do
        if [ "$action" == "install" ]; then
            if command_exists "$package"; then
                green "${package} already installed"
                continue
            fi
            yellow "正在安装 ${package}..."
            if command_exists apt; then
                DEBIAN_FRONTEND=noninteractive apt install -y "$package"
            elif command_exists dnf; then
                dnf install -y "$package"
            elif command_exists yum; then
                yum install -y "$package"
            elif command_exists apk; then
                apk update
                apk add "$package"
            else
                red "Unknown system!"
                return 1
            fi
        elif [ "$action" == "uninstall" ]; then
            if ! command_exists "$package"; then
                yellow "${package} is not installed"
                continue
            fi
            yellow "正在卸载 ${package}..."
            if command_exists apt; then
                apt remove -y "$package" && apt autoremove -y
            elif command_exists dnf; then
                dnf remove -y "$package" && dnf autoremove -y
            elif command_exists yum; then
                yum remove -y "$package" && yum autoremove -y
            elif command_exists apk; then
                apk del "$package"
            else
                red "Unknown system!"
                return 1
            fi
        else
            red "Unknown action: $action"
            return 1
        fi
    done

    return 0
}

# 获取ip
get_realip() {
    ip=$(curl -4 -sm 2 ip.sb)
    ipv6() { curl -6 -sm 2 ip.sb; }
    if [ -z "$ip" ]; then
        echo "[$(ipv6)]"
    elif curl -4 -sm 2 http://ipinfo.io/org | grep -qE 'Cloudflare|UnReal|AEZA|Andrei'; then
        echo "[$(ipv6)]"
    else
        resp=$(curl -sm 8 "https://status.eooce.com/api/$ip" | jq -r '.status')
        if [ "$resp" = "Available" ]; then
            echo "$ip"
        else
            v6=$(ipv6)
            [ -n "$v6" ] && echo "[$v6]" || echo "$ip"
        fi
    fi
}

# 处理防火墙
allow_port() {
    has_ufw=0
    has_firewalld=0
    has_iptables=0
    has_ip6tables=0

    command_exists ufw && has_ufw=1
    command_exists firewall-cmd && systemctl is-active firewalld >/dev/null 2>&1 && has_firewalld=1
    command_exists iptables && has_iptables=1
    command_exists ip6tables && has_ip6tables=1

    # 出站和基础规则
    [ "$has_ufw" -eq 1 ] && ufw --force default allow outgoing >/dev/null 2>&1
    [ "$has_firewalld" -eq 1 ] && firewall-cmd --permanent --zone=public --set-target=ACCEPT >/dev/null 2>&1
    [ "$has_iptables" -eq 1 ] && {
        iptables -C INPUT -i lo -j ACCEPT 2>/dev/null || iptables -I INPUT 3 -i lo -j ACCEPT
        iptables -C INPUT -p icmp -j ACCEPT 2>/dev/null || iptables -I INPUT 4 -p icmp -j ACCEPT
        iptables -P FORWARD DROP 2>/dev/null || true
        iptables -P OUTPUT ACCEPT 2>/dev/null || true
    }
    [ "$has_ip6tables" -eq 1 ] && {
        ip6tables -C INPUT -i lo -j ACCEPT 2>/dev/null || ip6tables -I INPUT 3 -i lo -j ACCEPT
        ip6tables -C INPUT -p icmp -j ACCEPT 2>/dev/null || ip6tables -I INPUT 4 -p icmp -j ACCEPT
        ip6tables -P FORWARD DROP 2>/dev/null || true
        ip6tables -P OUTPUT ACCEPT 2>/dev/null || true
    }

    # 入站
    for rule in "$@"; do
        port=${rule%/*}
        proto=${rule#*/}
        [ "$has_ufw" -eq 1 ] && ufw allow in ${port}/${proto} >/dev/null 2>&1
        [ "$has_firewalld" -eq 1 ] && firewall-cmd --permanent --add-port=${port}/${proto} >/dev/null 2>&1
        [ "$has_iptables" -eq 1 ] && (iptables -C INPUT -p ${proto} --dport ${port} -j ACCEPT 2>/dev/null || iptables -I INPUT 4 -p ${proto} --dport ${port} -j ACCEPT)
        [ "$has_ip6tables" -eq 1 ] && (ip6tables -C INPUT -p ${proto} --dport ${port} -j ACCEPT 2>/dev/null || ip6tables -I INPUT 4 -p ${proto} --dport ${port} -j ACCEPT)
    done

    [ "$has_firewalld" -eq 1 ] && firewall-cmd --reload >/dev/null 2>&1

    # 规则持久化
    if command_exists rc-service 2>/dev/null; then
        [ "$has_iptables" -eq 1 ] && iptables-save > /etc/iptables/rules.v4 2>/dev/null
        [ "$has_ip6tables" -eq 1 ] && ip6tables-save > /etc/iptables/rules.v6 2>/dev/null
    else
        if ! command_exists netfilter-persistent; then
            manage_packages install iptables-persistent || yellow "请手动安装netfilter-persistent或保存iptables规则" 
            netfilter-persistent save >/dev/null 2>&1
        elif command_exists service; then
            service iptables save 2>/dev/null
            service ip6tables save 2>/dev/null
        fi
    fi
}

# 下载并安装 sing-box
install_singbox() {
    clear
    purple "正在准备sing-box中，请稍后..."
    # 检查并安装必要的依赖包
    if ! command_exists tar; then
        manage_packages install tar
    fi
    # 判断系统架构

    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64) ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        armv7l) ARCH="armv7" ;;
        i386|i686) ARCH="i386" ;;
        mips64el) ARCH="mips64le" ;;
        riscv64) ARCH="riscv64" ;;
        ppc64le) ARCH="ppc64le" ;;
        s390x) ARCH="s390x" ;;
        *)
            echo "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac

    FILE="sing-box-${SINGBOX_VERSION}-linux-${ARCH}.tar.gz"
    DOWNLOAD_URL="https://github.com/SagerNet/sing-box/releases/download/v${SINGBOX_VERSION}/${FILE}"

    echo "Downloading ${FILE}..."
    curl -fsSL "$DOWNLOAD_URL" -o "$FILE"

    echo "Extracting..."
    tar -xzf "$FILE"

    # 进入正确目录
    cd "sing-box-${SINGBOX_VERSION}-linux-${ARCH}"

 
   # 下载完成并解压后，假设当前目录有 ./sing-box
    chmod +x sing-box

    # 将可执行文件移动到你定义的 work_dir
    mv sing-box "${work_dir}/${server_name}"

    echo "可执行文件已安装到：${work_dir}/${server_name}"

    # 创建工作目录
    mkdir -p "${work_dir}"

    # 检查是否通过环境变量提供了参数
    local use_env_vars=false
    if [ -n "$PORT" ] || [ -n "$UUID" ] || [ -n "$RANGE_PORTS" ]; then
        use_env_vars=true
    fi
    # 获取端口
    if [ -n "$PORT" ]; then
        hy2_port=$PORT
    else
        # 非交互式模式下直接生成随机端口
        if [ "$use_env_vars" = true ]; then
            hy2_port=$(shuf -i 1-65535 -n 1)
        else
            hy2_port=$(get_user_port)
        fi
    fi

    # 生成随机端口和UUID
    nginx_port=$(($hy2_port + 1)) 
    
    # 获取UUID
    if [ -n "$UUID" ]; then
        uuid=$UUID
    else
        # 非交互式模式下直接生成随机UUID
        if [ "$use_env_vars" = true ]; then
            uuid=$(cat /proc/sys/kernel/random/uuid)
        else
            uuid=$(get_user_uuid)
        fi
    fi

    # 如果提供了RANGE_PORTS环境变量，则记录相关信息
    if [ -n "$RANGE_PORTS" ]; then
        # 解析端口范围
        if [[ "$RANGE_PORTS" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            min_port="${BASH_REMATCH[1]}"
            max_port="${BASH_REMATCH[2]}"
            
            # 验证端口范围
            if [ "$max_port" -le "$min_port" ]; then
                red "错误：RANGE_PORTS端口范围无效，结束端口必须大于起始端口"
                # 不再unset RANGE_PORTS，让quick_install函数来处理
            fi
        else
            red "错误：RANGE_PORTS格式无效，应为 起始端口-结束端口 (例如: 20000-50000)"
            # 不再unset RANGE_PORTS，让quick_install函数来处理
        fi
    fi
    
    # 确保工作目录存在
    [ ! -d "${work_dir}" ] && mkdir -p "${work_dir}"
    
    # 生成自签名证书
    openssl ecparam -genkey -name prime256v1 -out "${work_dir}/private.key"
    openssl req -new -x509 -days 3650 -key "${work_dir}/private.key" -out "${work_dir}/cert.pem" -subj "/CN=bing.com"

    # 放行端口
    allow_port $hy2_port/udp > /dev/null 2>&1

    # 检测网络类型并设置DNS策略
    dns_strategy=$(ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1 && echo "prefer_ipv4" || (ping -c 1 -W 3 2001:4860:4860::8888 >/dev/null 2>&1 && echo "prefer_ipv6" || echo "prefer_ipv4"))

   # 生成配置文件 (只保留Hysteria2协议)
cat > "${config_dir}" << EOF
{
  "log": {
    "disabled": false,
    "level": "error",
    "output": "$work_dir/sb.log",
    "timestamp": true
  },
  "dns": {
    "servers": [
      {
        "tag": "local",
        "address": "local",
        "strategy": "$dns_strategy"
      }
    ]
  },
  "ntp": {
    "enabled": true,
    "server": "time.apple.com",
    "server_port": 123,
    "interval": "30m"
  },
  "inbounds": [
    {
      "type": "hysteria2",
      "tag": "hysteria2",
      "listen": "::",
      "listen_port": $hy2_port,
      "users": [
        {
          "password": "$uuid"
        }
      ],
      "ignore_client_bandwidth": false,
      "masquerade": "https://bing.com",
      "tls": {
        "enabled": true,
        "alpn": ["h3"],
        "min_version": "1.3",
        "max_version": "1.3",
        "certificate_path": "$work_dir/cert.pem",
        "key_path": "$work_dir/private.key"
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
    "final": "direct"
  }
}
EOF

    # RANGE_PORTS的处理已移到install_singbox函数外部
    

}
# debian/ubuntu/centos 守护进程
main_systemd_services() {
    cat > /etc/systemd/system/sing-box.service << EOF
[Unit]
Description=sing-box service
Documentation=https://sing-box.sagernet.org
After=network.target nss-lookup.target

[Service]
User=root
WorkingDirectory=/etc/sing-box
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
ExecStart=/etc/sing-box/sing-box run -c /etc/sing-box/config.json
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=infinity

[Install]
WantedBy=multi-user.target
EOF

    
    if [ -f /etc/centos-release ]; then
        yum install -y chrony
        systemctl start chronyd
        systemctl enable chronyd
        chronyc -a makestep
        yum update -y ca-certificates
        bash -c 'echo "0 0" > /proc/sys/net/ipv4/ping_group_range'
    fi
    systemctl daemon-reload 
    systemctl enable sing-box
    systemctl start sing-box
}

# 适配alpine 守护进程
alpine_openrc_services() {
    cat > /etc/init.d/sing-box << 'EOF'
#!/sbin/openrc-run

description="sing-box service"
command="/etc/sing-box/sing-box"
command_args="run -c /etc/sing-box/config.json"
command_background=true
pidfile="/var/run/sing-box.pid"
EOF

    
    chmod +x /etc/init.d/sing-box
    rc-update add sing-box default > /dev/null 2>&1
}

# 生成节点和订阅链接
get_info() {  
  yellow "\nip检测中,请稍等...\n"
  server_ip=$(get_realip)
  clear
  
  # 检查是否通过环境变量提供了节点名称
  if [ -n "$NODE_NAME" ]; then
      node_name="$NODE_NAME"
  else
      # ==============================
      # 获取节点名称（增强版，带 fallback）
      # ==============================
      node_name=$(
          # 1) 尝试 ipapi.co（带速率限制保护）
          curl -fs --max-time 3 https://ipapi.co/json 2>/dev/null | \
          sed -n 's/.*"country_code":"\([^\"]*\)".*"org":"\([^\"]*\)".*/\1-\2/p' | \
          sed 's/ /_/g'
      )

      # 2) 如果 ipapi.co 不可用，尝试 ip.sb + ipinfo.io/org
      if [ -z "$node_name" ]; then
          country=$(curl -fs --max-time 3 ip.sb/country 2>/dev/null | tr -d '\r\n')
          org=$(curl -fs --max-time 3 ipinfo.io/org 2>/dev/null | awk '{$1=""; print $0}' | sed 's/^ //; s/ /_/g')
          if [ -n "$country" ] && [ -n "$org" ]; then
              node_name="$country-$org"
          fi
      fi

      [ -z "$node_name" ] && node_name="$DEFAULT_NODE_NAME"
  fi


  # 检查是否配置了端口跳跃
  if [ -n "$RANGE_PORTS" ] && [[ "$RANGE_PORTS" =~ ^([0-9]+)-([0-9]+)$ ]]; then
      min_port="${BASH_REMATCH[1]}"
      max_port="${BASH_REMATCH[2]}"
      cat > ${work_dir}/url.txt <<EOF
hysteria2://${uuid}@${server_ip}:${hy2_port}/?insecure=1&alpn=h3&obfs=none&mport=${hy2_port},${min_port}-${max_port}#${node_name}
EOF
  else
      cat > ${work_dir}/url.txt <<EOF
hysteria2://${uuid}@${server_ip}:${hy2_port}/?insecure=1&alpn=h3&obfs=none#${node_name}
EOF
  fi
echo ""
while IFS= read -r line; do echo -e "${purple}$line"; done < ${work_dir}/url.txt
base64 -w0 ${work_dir}/url.txt > ${work_dir}/sub.txt
chmod 644 ${work_dir}/sub.txt
yellow "\n温馨提醒：需打开V2rayN或其他软件里的 "跳过证书验证"，或将节点的Insecure或TLS里设置为"true"\n"
green "V2rayN,Shadowrocket,Nekobox,Loon,Karing,Sterisand订阅链接：http://${server_ip}:${nginx_port}/${password}\n"
generate_qr "http://${server_ip}:${nginx_port}/${password}"
yellow "\n=========================================================================================="
green "\n\nClash,Mihomo系列订阅链接：https://sublink.eooce.com/clash?config=http://${server_ip}:${nginx_port}/${password}\n"
generate_qr "https://sublink.eooce.com/clash?config=http://${server_ip}:${nginx_port}/${password}"
yellow "\n=========================================================================================="
green "\n\nSing-box订阅链接：https://sublink.eooce.com/singbox?config=http://${server_ip}:${nginx_port}/${password}\n"
generate_qr "https://sublink.eooce.com/singbox?config=http://${server_ip}:${nginx_port}/${password}"
yellow "\n=========================================================================================="
green "\n\nSurge订阅链接：https://sublink.eooce.com/surge?config=http://${server_ip}:${nginx_port}/${password}\n"
generate_qr "https://sublink.eooce.com/surge?config=http://${server_ip}:${nginx_port}/${password}"
yellow "\n==========================================================================================\n"
}

# nginx订阅配置
add_nginx_conf() {
    if ! command_exists nginx; then
        red "nginx未安装,无法配置订阅服务"
        return 1
    else
        manage_service "nginx" "stop" > /dev/null 2>&1
        pkill nginx  > /dev/null 2>&1
    fi

    mkdir -p /etc/nginx/conf.d

    [[ -f "/etc/nginx/conf.d/sing-box.conf" ]] && cp /etc/nginx/conf.d/sing-box.conf /etc/nginx/conf.d/sing-box.conf.bak.sb

    cat > /etc/nginx/conf.d/sing-box.conf << EOF
# sing-box 订阅配置
server {
    listen $nginx_port;
    listen [::]:$nginx_port;
    server_name _;

    # 安全设置
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";

    location = /$password {
        alias /etc/sing-box/sub.txt;
        default_type 'text/plain; charset=utf-8';
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
    }

    location / {
        return 404;
    }

    # 禁止访问隐藏文件
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}
EOF

    # 检查主配置文件是否存在
    if [ -f "/etc/nginx/nginx.conf" ]; then
        cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak.sb > /dev/null 2>&1
        sed -i -e '15{/include \/etc\/nginx\/modules\/\*\.conf/d;}' -e '18{/include \/etc\/nginx\/conf\.d\/\*\.conf/d;}' /etc/nginx/nginx.conf > /dev/null 2>&1
        # 检查是否已包含配置目录
        if ! grep -q "include.*conf.d" /etc/nginx/nginx.conf; then
            http_end_line=$(grep -n "^}" /etc/nginx/nginx.conf | tail -1 | cut -d: -f1)
            if [ -n "$http_end_line" ]; then
                sed -i "${http_end_line}i \    include /etc/nginx/conf.d/*.conf;" /etc/nginx/nginx.conf > /dev/null 2>&1
            fi
        fi
    else 
        cat > /etc/nginx/nginx.conf << EOF
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log  /var/log/nginx/access.log  main;
    sendfile        on;
    keepalive_timeout  65;
    
    include /etc/nginx/conf.d/*.conf;
}
EOF
    fi

    # 检查nginx配置语法
    if nginx -t > /dev/null 2>&1; then
    
        if nginx -s reload > /dev/null 2>&1; then
            green "nginx订阅配置已加载"
        else
            start_nginx  > /dev/null 2>&1
        fi
    else
        yellow "nginx配置失败,订阅不可应,但不影响节点使用, issues反馈: https://github.com/eooce/Sing-box/issues"
        restart_nginx  > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            green "nginx订阅配置已生效"
        else
            [[ -f "/etc/nginx/nginx.conf.bak.sb" ]] && cp "/etc/nginx/nginx.conf.bak.sb" /etc/nginx/nginx.conf > /dev/null 2>&1
            restart_nginx  > /dev/null 2>&1
        fi
    fi
}

# 通用服务管理函数
manage_service() {
    local service_name="$1"
    local action="$2"

    if [ -z "$service_name" ] || [ -z "$action" ]; then
        red "缺少服务名或操作参数\n"
        return 1
    fi
    
    local status=$(check_service "$service_name" 2>/dev/null)

    case "$action" in
        "start")
            if [ "$status" == "running" ]; then 
                yellow "${service_name} 正在运行\n"
                return 0
            elif [ "$status" == "not installed" ]; then 
                yellow "${service_name} 尚未安装!\n"
                return 1
            else 
                yellow "正在启动 ${service_name} 服务\n"
                if command_exists rc-service; then
                    rc-service "$service_name" start
                elif command_exists systemctl; then
                    systemctl daemon-reload
                    systemctl start "$service_name"
                fi
                
                if [ $? -eq 0 ]; then
                    green "${service_name} 服务已成功启动\n"
                    return 0
                else
                    red "${service_name} 服务启动失败\n"
                    return 1
                fi
            fi
            ;;
            
        "stop")
            if [ "$status" == "not installed" ]; then 
                yellow "${service_name} 尚未安装！\n"
                return 2
            elif [ "$status" == "not running" ]; then
                yellow "${service_name} 未运行\n"
                return 1
            else
                yellow "正在停止 ${service_name} 服务\n"
                if command_exists rc-service; then
                    rc-service "$service_name" stop
                elif command_exists systemctl; then
                    systemctl stop "$service_name"
                fi
                
                if [ $? -eq 0 ]; then
                    green "${service_name} 服务已成功停止\n"
                    return 0
                else
                    red "${service_name} 服务停止失败\n"
                    return 1
                fi
            fi
            ;;
            
        "restart")
            if [ "$status" == "not installed" ]; then
                yellow "${service_name} 尚未安装！\n"
                return 1
            else
                yellow "正在重启 ${service_name} 服务\n"
                if command_exists rc-service; then
                    rc-service "$service_name" restart
                elif command_exists systemctl; then
                    systemctl daemon-reload
                    systemctl restart "$service_name"
                fi
                
                if [ $? -eq 0 ]; then
                    green "${service_name} 服务已成功重启\n"
                    return 0
                else
                    red "${service_name} 服务重启失败\n"
                    return 1
                fi
            fi
            ;;
            
        *)
            red "无效的操作: $action\n"
            red "可用操作: start, stop, restart\n"
            return 1
            ;;
    esac
}

# 启动 sing-box
start_singbox() {
    manage_service "sing-box" "start"
}

# 停止 sing-box
stop_singbox() {
    manage_service "sing-box" "stop"
}

# 重启 sing-box
restart_singbox() {
    manage_service "sing-box" "restart"
}



# 启动 nginx
start_nginx() {
    manage_service "nginx" "start"
}

# 重启 nginx
restart_nginx() {
    manage_service "nginx" "restart"
}

# 卸载 sing-box
uninstall_singbox() {
   reading "确定要卸载 sing-box 吗? (y/n): " choice
   case "${choice}" in
       y|Y)
           yellow "正在卸载 sing-box"
           if command_exists rc-service; then
                rc-service sing-box stop

                rm /etc/init.d/sing-box
                rc-update del sing-box default
           else
                # 停止 sing-box服务
                systemctl stop "${server_name}"
                # 禁用 sing-box 服务
                systemctl disable "${server_name}"


                # 重新加载 systemd
                systemctl daemon-reload || true
            fi
           # 删除配置文件和日志
           rm -rf "${work_dir}" || true
           rm -rf "${log_dir}" || true
           rm -rf /etc/systemd/system/sing-box.service > /dev/null 2>&1
           rm  -rf /etc/nginx/conf.d/sing-box.conf > /dev/null 2>&1           
           # 卸载Nginx
           reading "\n是否卸载 Nginx？${green}(卸载请输入 ${yellow}y${re} ${green}回车将跳过卸载Nginx) (y/n): ${re}" choice
            case "${choice}" in
                y|Y)
                    manage_packages uninstall nginx
                    ;;
                 *) 
                    yellow "取消卸载Nginx\n\n"
                    ;;
            esac

            green "\nsing-box 卸载成功\n\n" && exit 0
           ;;
       *)
           purple "已取消卸载操作\n\n"
           ;;
   esac
}


# 变更配置
change_config() {
    # 检查sing-box状态
    local singbox_status=$(check_singbox 2>/dev/null)
    local singbox_installed=$?
    
    if [ $singbox_installed -eq 2 ]; then
        yellow "sing-box 尚未安装！"
        sleep 1
        menu
        return
    fi
    
    clear
    echo ""
    green "=== 修改节点配置 ===\n"
    green "sing-box当前状态: $singbox_status\n"
    green "1. 修改端口"
    skyblue "------------"
    green "2. 修改UUID"
    skyblue "------------"
    green "3. 修改节点名称"
    skyblue "------------"
    green "4. 添加Hysteria2端口跳跃"
    skyblue "------------"
    green "5. 删除Hysteria2端口跳跃"
    skyblue "------------"
    purple "0. 返回主菜单"
    skyblue "------------"
    reading "请输入选择: " choice
    case "${choice}" in
        1)
            reading "\n请输入hysteria2端口 (回车跳过将使用随机端口): " new_port
            [ -z "$new_port" ] && new_port=$(shuf -i 1-65535 -n 1)
            sed -i '/"type": "hysteria2"/,/listen_port/ s/"listen_port": [0-9]\+/"listen_port": '"$new_port"'/' $config_dir
            restart_singbox
            allow_port $new_port/udp > /dev/null 2>&1
            while IFS= read -r line; do echo -e "${purple}$line"; done < ${work_dir}/url.txt
            green "\nhysteria2端口已修改成：${purple}$new_port${re} ${green}请更新订阅或手动更改hysteria2端口${re}\n"
            ;;
        2)
            reading "\n请输入新的UUID: " new_uuid
            [ -z "$new_uuid" ] && new_uuid=$(cat /proc/sys/kernel/random/uuid)
            sed -i -E '
                s/"password": "([a-zA-Z0-9-]+)"/"password": "'"$new_uuid"'"/g;
            ' $config_dir

            restart_singbox
            sed -i -E 's/(hysteria2:\/\/)[^@]*(@.*)/\1'"$new_uuid"'\2/' $client_dir
            base64 -w0 $client_dir > /etc/sing-box/sub.txt
            while IFS= read -r line; do yellow "$line"; done < ${work_dir}/url.txt
            green "\nUUID已修改为：${purple}${new_uuid}${re} ${green}请更新订阅或手动更改所有节点的UUID${re}\n"
            ;;
        3)
            reading "\n请输入新的节点名称: " new_node_name
            [ -z "$new_node_name" ] && new_node_name="$DEFAULT_NODE_NAME"
            
            # 更新url.txt中的节点名称
            sed -i "s/\(hysteria2://[^#]*#\).*/\1$new_node_name/" $client_dir
            
            # 重新生成订阅文件
            base64 -w0 $client_dir > /etc/sing-box/sub.txt
            
            restart_singbox
            
            while IFS= read -r line; do yellow "$line"; done < ${work_dir}/url.txt
            green "\n节点名称已修改为：${purple}${new_node_name}${re} ${green}请更新订阅或手动更改节点名称${re}\n"
            ;;
        4)  
            # 交互式获取端口范围（不考虑外界环境变量）
            while true; do
                purple "端口跳跃需确保跳跃区间的端口没有被占用，nat鸡请注意可用端口范围，否则可能造成节点不通\n"
                reading "请输入跳跃起始端口 (回车跳过将使用随机端口): " min_port
                [ -z "$min_port" ] && min_port=$(shuf -i 1-65535 -n 1)
                yellow "你的起始端口为：$min_port"
                reading "\n请输入跳跃结束端口 (需大于起始端口): " max_port
                [ -z "$max_port" ] && max_port=$(($min_port + 100))
                
                # 检查端口范围有效性
                if [ "$max_port" -le "$min_port" ]; then
                    red "错误：结束端口必须大于起始端口\n"
                    reading "是否重新输入？(y/n): " retry
                    [ "$retry" != "y" ] && break
                else
                    break
                fi
            done
            
            yellow "你的结束端口为：$max_port\n"
            purple "正在安装依赖，并设置端口跳跃规则中，请稍等...\n"
            listen_port=$(sed -n '/"tag": "hysteria2"/,/}/s/.*"listen_port": \([0-9]*\).*/\1/p' $config_dir)
            # 放行跳跃端口范围
            allow_port $min_port-$max_port/udp > /dev/null 2>&1
            iptables -t nat -A PREROUTING -p udp --dport $min_port:$max_port -j DNAT --to-destination :$listen_port > /dev/null
            command -v ip6tables &> /dev/null && ip6tables -t nat -A PREROUTING -p udp --dport $min_port:$max_port -j DNAT --to-destination :$listen_port > /dev/null
            if command_exists rc-service 2>/dev/null; then
                iptables-save > /etc/iptables/rules.v4
                command -v ip6tables &> /dev/null && ip6tables-save > /etc/iptables/rules.v6

                cat << 'EOF' > /etc/init.d/iptables
#!/sbin/openrc-run

depend() {
    need net
}

start() {
    [ -f /etc/iptables/rules.v4 ] && iptables-restore < /etc/iptables/rules.v4
    command -v ip6tables &> /dev/null && [ -f /etc/iptables/rules.v6 ] && ip6tables-restore < /etc/iptables/rules.v6
}
EOF

                chmod +x /etc/init.d/iptables && rc-update add iptables default && /etc/init.d/iptables start
            elif [ -f /etc/debian_version ]; then
                DEBIAN_FRONTEND=noninteractive apt install -y iptables-persistent > /dev/null 2>&1 && netfilter-persistent save > /dev/null 2>&1 
                systemctl enable netfilter-persistent > /dev/null 2>&1 && systemctl start netfilter-persistent > /dev/null 2>&1
            elif [ -f /etc/redhat-release ]; then
                manage_packages install iptables-services > /dev/null 2>&1 && service iptables save > /dev/null 2>&1
                systemctl enable iptables > /dev/null 2>&1 && systemctl start iptables > /dev/null 2>&1
                command -v ip6tables &> /dev/null && service ip6tables save > /dev/null 2>&1
                systemctl enable ip6tables > /dev/null 2>&1 && systemctl start ip6tables > /dev/null 2>&1
            else
                red "未知系统,请自行将跳跃端口转发到主端口" && exit 1
            fi            
            restart_singbox
            ip=$(get_realip)
            uuid=$(sed -n 's/.*hysteria2:\/\/\([^@]*\)@.*/\1/p' $client_dir)
            line_number=$(grep -n 'hysteria2://' $client_dir | cut -d':' -f1)
            isp=$(curl -s --max-time 2 https://speed.cloudflare.com/meta | awk -F\" '{print $26"-"$18}' | sed -e 's/ /_/g' || echo "vps")
            sed -i.bak "/hysteria2:/d" $client_dir
            sed -i "${line_number}i hysteria2://$uuid@$ip:$listen_port?peer=www.bing.com&insecure=1&alpn=h3&obfs=none&mport=$listen_port,$min_port-$max_port#$isp" $client_dir
            base64 -w0 $client_dir > /etc/sing-box/sub.txt
            while IFS= read -r line; do yellow "$line"; done < ${work_dir}/url.txt
            green "\nhysteria2端口跳跃已开启,跳跃端口为：${purple}$min_port-$max_port${re} ${green}请更新订阅或手动复制以上hysteria2节点${re}\n"
            ;;
        5)  
            iptables -t nat -F PREROUTING  > /dev/null 2>&1
            command -v ip6tables &> /dev/null && ip6tables -t nat -F PREROUTING  > /dev/null 2>&1
            if command_exists rc-service 2>/dev/null; then
                rc-update del iptables default && rm -rf /etc/init.d/iptables 
            elif [ -f /etc/redhat-release ]; then
                netfilter-persistent save > /dev/null 2>&1
                service iptables save > /dev/null 2>&1
                command -v ip6tables &> /dev/null && service ip6tables save > /dev/null 2>&1
            else
                manage_packages uninstall iptables ip6tables iptables-persistent iptables-service > /dev/null 2>&1
            fi
            sed -i '/hysteria2/s/&mport=[^#&]*//g' /etc/sing-box/url.txt
            base64 -w0 $client_dir > /etc/sing-box/sub.txt
            green "\n端口跳跃已删除\n"
            ;;
        0)  menu ;;
        *)  red "无效的选项！" ;; 
    esac
}
disable_open_sub() {
    local singbox_status=$(check_singbox 2>/dev/null)
    local singbox_installed=$?
    
    if [ $singbox_installed -eq 2 ]; then
        yellow "sing-box 尚未安装！"
        sleep 1
        menu
        return
    fi
    
    clear
    echo ""
    green "=== 管理节点订阅 ===\n"
    skyblue "------------"
    green "1. 关闭节点订阅"
    skyblue "------------"
    green "2. 开启节点订阅"
    skyblue "------------"
    green "3. 更换订阅端口"
    skyblue "------------"
    purple "0. 返回主菜单"
    skyblue "------------"
    reading "请输入选择: " choice
    case "${choice}" in
        1)
            if command -v nginx &>/dev/null; then
                if command_exists rc-service 2>/dev/null; then
                    rc-service nginx status | grep -q "started" && rc-service nginx stop || red "nginx not running"
                else 
                    [ "$(systemctl is-active nginx)" = "active" ] && systemctl stop nginx || red "ngixn not running"
                fi
            else
                yellow "Nginx is not installed"
            fi

            green "\n已关闭节点订阅\n"     
            ;; 
        2)
            green "\n已开启节点订阅\n"
            server_ip=$(get_realip)
            password=$(tr -dc A-Za-z < /dev/urandom | head -c 32) 
            sed -i "s|\(location = /\)[^ ]*|\1$password|" /etc/nginx/conf.d/sing-box.conf
        sub_port=$(port=$(grep -E 'listen [0-9]+;' "/etc/nginx/conf.d/sing-box.conf" | awk '{print $2}' | sed 's/;//'); if [ "$port" -eq 80 ]; then echo ""; else echo "$port"; fi)
            start_nginx
            (port=$(grep -E 'listen [0-9]+;' "/etc/nginx/conf.d/sing-box.conf" | awk '{print $2}' | sed 's/;//'); if [ "$port" -eq 80 ]; then echo ""; else green "订阅端口：$port"; fi); link=$(if [ -z "$sub_port" ]; then echo "http://$server_ip/$password"; else echo "http://$server_ip:$sub_port/$password"; fi); green "\n新的节点订阅链接：$link\n"
            ;; 
        3)
            reading "请输入新的订阅端口(1-65535):" sub_port
            [ -z "$sub_port" ] && sub_port=$(shuf -i 1-65535 -n 1)
            # 检查端口是否被占用
            until [[ -z $(lsof -iTCP:"$sub_port" -sTCP:LISTEN -t) ]]; do
                if [[ -n $(lsof -iTCP:"$sub_port" -sTCP:LISTEN -t) ]]; then
                    echo -e "${red}端口 $sub_port 已经被其他程序占用，请更换端口重试${re}"
                    reading "请输入新的订阅端口(1-65535):" sub_port
                    [[ -z $sub_port ]] && sub_port=$(shuf -i 1-65535 -n 1)
                fi
            done

            # 备份当前配置
            if [ -f "/etc/nginx/conf.d/sing-box.conf" ]; then
                cp "/etc/nginx/conf.d/sing-box.conf" "/etc/nginx/conf.d/sing-box.conf.bak.$(date +%Y%m%d)"
            fi
            
            # 更新端口配置
            sed -i 's/listen [0-9]\+;/listen '$sub_port';/g' "/etc/nginx/conf.d/sing-box.conf"
            sed -i 's/listen \[::\]:[0-9]\+;/listen [::]:'$sub_port';/g' "/etc/nginx/conf.d/sing-box.conf"
            path=$(sed -n 's|.*location = /\([^ ]*\).*|\1|p' "/etc/nginx/conf.d/sing-box.conf")
            server_ip=$(get_realip)
            
            # 放行新端口
            allow_port $sub_port/tcp > /dev/null 2>&1
            
            # 测试nginx配置
            if nginx -t > /dev/null 2>&1; then
                # 尝试重新加载配置
                if nginx -s reload > /dev/null 2>&1; then
                    green "nginx配置已重新加载，端口更换成功"
                else
                    yellow "配置重新加载失败，尝试重启nginx服务..."
                    restart_nginx
                fi
                green "\n订阅端口更换成功\n"
                green "新的订阅链接为：http://$server_ip:$sub_port/$path\n"
            else
                red "nginx配置测试失败，正在恢复原有配置..."
                if [ -f "/etc/nginx/conf.d/sing-box.conf.bak."* ]; then
                    latest_backup=$(ls -t /etc/nginx/conf.d/sing-box.conf.bak.* | head -1)
                    cp "$latest_backup" "/etc/nginx/conf.d/sing-box.conf"
                    yellow "已恢复原有nginx配置"
                fi
                return 1
            fi
            ;; 
        0)  menu ;; 
        *)  red "无效的选项！" ;;
    esac
}

# singbox 管理
manage_singbox() {
    # 检查sing-box状态
    local singbox_status=$(check_singbox 2>/dev/null)
    local singbox_installed=$?
    
    clear
    echo ""
    green "=== sing-box 管理 ===\n"
    green "sing-box当前状态: $singbox_status\n"
    green "1. 启动sing-box服务"
    skyblue "-------------------"
    green "2. 停止sing-box服务"
    skyblue "-------------------"
    green "3. 重启sing-box服务"
    skyblue "-------------------"
    purple "0. 返回主菜单"
    skyblue "------------"
    reading "\n请输入选择: " choice
    case "${choice}" in
        1) start_singbox ;;  
        2) stop_singbox ;;
        3) restart_singbox ;;
        0) menu ;;
        *) red "无效的选项！" && sleep 1 && manage_singbox;;
    esac
}

# 查看节点信息和订阅链接
check_nodes() {
    echo ""
    purple "======================= 节点信息 ======================="
    cat ${work_dir}/url.txt | while IFS= read -r line; do 
        purple "$line"
    done
    purple "======================================================"
    server_ip=$(get_realip)
    lujing=$(sed -n 's|.*location = /\([^ ]*\).*|\1|p' "/etc/nginx/conf.d/sing-box.conf")
    sub_port=$(sed -n 's/^\s*listen \([0-9]\+\);/\1/p' "/etc/nginx/conf.d/sing-box.conf")
    base64_url="http://${server_ip}:${sub_port}/${lujing}"
    green "\n\nSurge订阅链接: ${purple}https://sublink.eooce.com/surge?config=${base64_url}${re}\n"
    green "sing-box订阅链接: ${purple}https://sublink.eooce.com/singbox?config=${base64_url}${purple}\n"
    green "Mihomo/Clash系列订阅链接: ${purple}https://sublink.eooce.com/clash?config=${base64_url}${re}\n"
    green "V2rayN,Shadowrocket,Nekobox,Loon,Karing,Sterisand订阅链接: ${purple}${base64_url}${re}\n"
}

# 检测运行模式
is_interactive_mode() {
    # 检查是否有环境变量参数
    if [ -n "$PORT" ] || [ -n "$UUID" ] || [ -n "$RANGE_PORTS" ]; then
        return 1  # 非交互式模式
    else
        return 0  # 交互式模式
    fi
}

# 非交互式模式下的快速安装函数
quick_install() {
    # 直接安装sing-box，使用环境变量参数
    manage_packages install nginx jq openssl lsof coreutils
    install_singbox
    
    # 启动服务
    if command_exists systemctl; then
        main_systemd_services
    elif command_exists rc-update; then
        alpine_openrc_services
        change_hosts
        rc-service sing-box restart
    else
        red "系统不支持的初始化系统"
        exit 1 
    fi
    
    sleep 5
    # 处理RANGE_PORTS环境变量
    handle_range_ports
    get_info
    add_nginx_conf
}

# 主循环
main_loop() {
    while true; do
       menu
       case "${choice}" in
            1)  
                check_singbox &>/dev/null; check_singbox=$?
                if [ ${check_singbox} -eq 0 ]; then
                    yellow "sing-box 已经安装！\n"
                else
                    manage_packages install nginx jq openssl lsof coreutils
                    install_singbox
                    
                    if command_exists systemctl; then
                        main_systemd_services
                    elif command_exists rc-update; then
                        alpine_openrc_services
                        change_hosts
                        rc-service sing-box restart
                    else
                        red "系统不支持"
                        exit 1 
                    fi

                    sleep 5
                    # 处理RANGE_PORTS环境变量
                    handle_range_ports
                    get_info
                    add_nginx_conf
                fi
               ;;
            2) uninstall_singbox ;;
            3) manage_singbox ;;
            4) check_nodes ;;
            5) change_config ;;
            6) disable_open_sub ;;
            7) 
               clear
               bash <(curl -Ls ssh_tool.eooce.com)
               ;;           
            0) exit 0 ;;
            *) red "无效的选项，请输入 0 到 7" ;;
       esac
       read -n 1 -s -r -p $'\033[1;91m按任意键返回...\033[0m'
    done
}

# 获取用户输入的端口（确保端口未被占用）
get_user_port() {
    local user_port
    
    while true; do
        reading "请输入端口号 (1-65535)，或按回车跳过使用随机端口: " user_port
        
        # 如果用户直接按回车，使用随机端口
        if [ -z "$user_port" ]; then
            user_port=$(shuf -i 1-65535 -n 1)
            echo "$user_port"
            return
        fi
        
        # 验证端口范围
        if ! [[ "$user_port" =~ ^[0-9]+$ ]] || [ "$user_port" -lt 1 ] || [ "$user_port" -gt 65535 ]; then
            red "端口号必须是1-65535之间的整数"
            echo "请重新输入"
            continue
        fi
        
        # 检查端口是否已被占用
        if netstat -tuln | grep -q ":$user_port " || netstat -tuln6 | grep -q ":$user_port " || netstat -tuln | grep -q ":$user_port$" || netstat -tuln6 | grep -q ":$user_port$"; then
            red "端口 $user_port 已被占用，请选择其他端口"
            echo "请重新输入"
            continue
        fi
        
        # 端口有效且未被占用
        echo "$user_port"
        return
    done
}

# 获取用户输入的UUID
get_user_uuid() {
    local user_uuid
    reading "请输入UUID，或按回车跳过使用随机UUID: " user_uuid
    
    # 如果用户直接按回车，生成随机UUID
    if [ -z "$user_uuid" ]; then
        user_uuid=$(cat /proc/sys/kernel/random/uuid)
    fi
    
    echo "$user_uuid"
}

# 处理RANGE_PORTS环境变量
handle_range_ports() {
    # 如果提供了RANGE_PORTS环境变量，则自动配置端口跳跃
    if [ -n "$RANGE_PORTS" ]; then
        # 解析端口范围
        if [[ "$RANGE_PORTS" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            local min_port="${BASH_REMATCH[1]}"
            local max_port="${BASH_REMATCH[2]}"
            
            # 验证端口范围
            if [ "$max_port" -gt "$min_port" ]; then
                yellow "检测到RANGE_PORTS环境变量，正在自动配置端口跳跃: $min_port-$max_port"
                configure_port_jump "$min_port" "$max_port"
            else
                red "错误：RANGE_PORTS端口范围无效，结束端口必须大于起始端口"
            fi
        else
            red "错误：RANGE_PORTS格式无效，应为 起始端口-结束端口 (例如: 20000-50000)"
        fi
    fi
}

# 配置端口跳跃功能
configure_port_jump() {
    local min_port=$1
    local max_port=$2
    
    # 放行跳跃端口范围
    allow_port $min_port-$max_port/udp > /dev/null 2>&1
    listen_port=$(sed -n '/"tag": "hysteria2"/,/}/s/.*"listen_port": \([0-9]*\).*/\1/p' $config_dir)
    iptables -t nat -A PREROUTING -p udp --dport $min_port:$max_port -j DNAT --to-destination :$listen_port > /dev/null
    command -v ip6tables &> /dev/null && ip6tables -t nat -A PREROUTING -p udp --dport $min_port:$max_port -j DNAT --to-destination :$listen_port > /dev/null
    
    if command_exists rc-service 2>/dev/null; then
        iptables-save > /etc/iptables/rules.v4
        command -v ip6tables &> /dev/null && ip6tables-save > /etc/iptables/rules.v6

        cat << 'EOF' > /etc/init.d/iptables
#!/sbin/openrc-run

depend() {
    need net
}

start() {
    [ -f /etc/iptables/rules.v4 ] && iptables-restore < /etc/iptables/rules.v4
    command -v ip6tables &> /dev/null && [ -f /etc/iptables/rules.v6 ] && ip6tables-restore < /etc/iptables/rules.v6
}
EOF

        chmod +x /etc/init.d/iptables && rc-update add iptables default && /etc/init.d/iptables start
    elif [ -f /etc/debian_version ]; then
        DEBIAN_FRONTEND=noninteractive apt install -y iptables-persistent > /dev/null 2>&1 && netfilter-persistent save > /dev/null 2>&1 
        systemctl enable netfilter-persistent > /dev/null 2>&1 && systemctl start netfilter-persistent > /dev/null 2>&1
    elif [ -f /etc/redhat-release ]; then
        manage_packages install iptables-services > /dev/null 2>&1 && service iptables save > /dev/null 2>&1
        systemctl enable iptables > /dev/null 2>&1 && systemctl start iptables > /dev/null 2>&1
        command -v ip6tables &> /dev/null && service ip6tables save > /dev/null 2>&1
        systemctl enable ip6tables > /dev/null 2>&1 && systemctl start ip6tables > /dev/null 2>&1
    else
        red "未知系统,请自行将跳跃端口转发到主端口" && exit 1
    fi            
    
    restart_singbox
    
    # 更新订阅链接以包含端口跳跃信息
    if [ -f "$client_dir" ]; then
        ip=$(get_realip)
        uuid=$(sed -n 's/.*hysteria2:\/\/\([^@]*\)@.*/\1/p' $client_dir)
        line_number=$(grep -n 'hysteria2://' $client_dir | cut -d':' -f1)
        node_name=$(curl -s --max-time 2 https://speed.cloudflare.com/meta | awk -F\" '{print $26"-"$18}' | sed -e 's/ /_/g' || echo "vps")
        sed -i.bak "/hysteria2:/d" $client_dir
        sed -i "${line_number}i hysteria2://$uuid@$ip:$listen_port?peer=www.bing.com&insecure=1&alpn=h3&obfs=none&mport=$listen_port,$min_port-$max_port#$node_name" $client_dir
        base64 -w0 $client_dir > /etc/sing-box/sub.txt
    fi
    
    green "\nhysteria2端口跳跃已开启,跳跃端口为：${purple}$min_port-$max_port${re} ${green}请更新订阅或手动复制以上hysteria2节点${re}\n"
}

# 主菜单
menu() {
   singbox_status=$(check_singbox 2>/dev/null)
   nginx_status=$(check_nginx 2>/dev/null)
   
   clear
   echo ""
   blue "==============================================="
   blue "          sing-box 一键安装管理脚本"
   blue "          （Hysteria2精简版）"
   skyblue "          作者: $AUTHOR"
   yellow "          版本: $VERSION"
   blue "==============================================="
   echo ""
   green "老王的Github地址: ${purple}https://github.com/eooce/sing-box${re}\n"
   echo ""
   purple "--Nginx 状态: ${nginx_status}"
   purple "singbox 状态: ${singbox_status}\n"
   green "1. 安装sing-box(Hysteria2)"
   red "2. 卸载sing-box"
   echo "==============="
   green "3. sing-box管理"
   echo  "==============="
   green  "4. 查看节点信息"
   green  "5. 修改节点配置"
   green  "6. 管理节点订阅"
   echo  "==============="
   purple "7. 老王ssh综合工具箱"
   echo  "==============="
   red "0. 退出脚本"
   echo "==========="
   reading "请输入选择(0-7): " choice
   echo ""
}
# 捕获 Ctrl+C 退出信号
trap 'red "已取消操作"; exit' INT

# 启动主循环
main() {
    is_interactive_mode
    if [ $? -eq 0 ]; then
        # 交互式模式 - 显示菜单
        main_loop
    else
        # 非交互式模式 - 快速安装
        quick_install
        # 安装完成后提示用户按任意键进入主循环菜单
        green "\n非交互式安装已完成！"
        read -n 1 -s -r -p $'\033[1;91m按任意键进入主菜单...\033[0m'
        main_loop
    fi
}
generate_qr() {
    local TEXT="$1"

    echo
    echo "========================================"
    echo "📱 请手机扫码以下二维码链接（全球可用）："
    encoded=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$TEXT")
    QR_URL="https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=$encoded"

    # 下载二维码 PNG 到本地
    curl -s -o qr.png "$QR_URL"

    # 尝试在终端显示二维码图片（如果终端支持）
    if command -v imgcat >/dev/null 2>&1; then
        imgcat qr.png
    elif command -v viu >/dev/null 2>&1; then
        viu qr.png
    else
        echo "终端不支持直接显示 PNG，请使用支持图片预览的终端（Kitty/iTerm2）"
    fi
    echo "$QR_URL"
    echo "========================================"

    echo
    echo "🔧 如果终端无法扫码，请手动复制以下配置："
    echo "$TEXT"
}


# 调用主函数
main
