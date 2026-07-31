#!/usr/bin/env bash
set -Eeuo pipefail

MTU="${MTU:-1500}"
FQ_QUANTUM="${FQ_QUANTUM:-18028}"
FQ_INITIAL_QUANTUM="${FQ_INITIAL_QUANTUM:-90140}"
TCP_WMEM_MAX="${TCP_WMEM_MAX:-33554432}"
TCP_RMEM_MAX="${TCP_RMEM_MAX:-33554432}"
TCP_LIMIT_OUTPUT_BYTES="${TCP_LIMIT_OUTPUT_BYTES:-4194304}"
SYSCTL_FILE="${SYSCTL_FILE:-/etc/sysctl.d/99-singleflow-tcp-optimization.conf}"
SERVICE_FILE="${SERVICE_FILE:-}"
SERVICE_NAME="singleflow-fq-quantum"
NETPLAN_FILE="${NETPLAN_FILE:-}"

VERSION="1.1.0(2026-07-31)"
AUTHOR="jyucoeng"
INTERFACES_FILE="${INTERFACES_FILE:-}"
IFACE="${IFACE:-}"

APT_UPDATED=false

detect_init() {
  if command -v systemctl >/dev/null 2>&1; then
    echo "systemd"
  elif command -v rc-service >/dev/null 2>&1; then
    echo "openrc"
  else
    echo "unknown"
  fi
}

detect_distro() {
  if [[ -f /etc/alpine-release ]]; then
    echo "alpine"
  elif [[ -f /etc/os-release ]]; then
    . /etc/os-release
    echo "${ID}"
  else
    echo "linux"
  fi
}

get_service_file() {
  local init_name
  init_name="${1:-$(detect_init)}"
  if [[ "$init_name" == "openrc" ]]; then
    echo "${SERVICE_FILE:-/etc/init.d/${SERVICE_NAME}}"
  else
    echo "${SERVICE_FILE:-/etc/systemd/system/${SERVICE_NAME}.service}"
  fi
}

green() { echo -e "\e[1;32m$1\033[0m"; }

need_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "错误：请使用 root 权限运行此脚本。" >&2
    exit 1
  fi
}

# 自动解析并安装缺失的命令依赖
resolve_and_install() {
  local cmd="$1"
  local pm=""
  
  # 检测包管理器
  if command -v apt-get >/dev/null 2>&1; then
    pm="apt"
  elif command -v dnf >/dev/null 2>&1; then
    pm="dnf"
  elif command -v yum >/dev/null 2>&1; then
    pm="yum"
  elif command -v pacman >/dev/null 2>&1; then
    pm="pacman"
  elif command -v apk >/dev/null 2>&1; then
    pm="apk"
  fi

  if [[ -z "$pm" ]]; then
    echo "错误：未检测到支持的包管理器 (apt/dnf/yum/pacman/apk)，无法自动安装 ${cmd}。请手动安装。" >&2
    exit 1
  fi

  # 映射命令到对应的软件包名称
  local pkg=""
  case "$cmd" in
    ip)
      if [[ "$pm" == "apt" || "$pm" == "pacman" || "$pm" == "apk" ]]; then
        pkg="iproute2"
      else
        pkg="iproute"
      fi
      ;;
    tc)
      if [[ "$pm" == "apt" || "$pm" == "pacman" || "$pm" == "apk" ]]; then
        pkg="iproute2"
      else
        pkg="iproute-tc"
      fi
      ;;
    sysctl)
      if [[ "$pm" == "apt" ]]; then
        pkg="procps"
      elif [[ "$pm" == "apk" ]]; then
        pkg="busybox-suid"
      else
        pkg="procps-ng"
      fi
      ;;
    systemctl)
      if [[ "$pm" == "apk" ]]; then
        echo "错误：Alpine Linux 不支持 systemd。请使用 OpenRC。" >&2
        exit 1
      fi
      pkg="systemd"
      ;;
    rc-service|rc-update)
      pkg="openrc"
      ;;
    python3)
      pkg="python3"
      ;;
    *)
      pkg="$cmd"
      ;;
  esac

  echo "检测到缺少必需命令: ${cmd}，正在尝试通过 ${pm} 自动安装依赖包: ${pkg}..."

  # 执行安装
  case "$pm" in
    apt)
      if [[ "$APT_UPDATED" = false ]]; then
        echo "正在更新软件包列表..."
        apt-get update -qy || true
        APT_UPDATED=true
      fi
      apt-get install -y "${pkg}"
      ;;
    dnf)
      dnf install -y "${pkg}"
      ;;
    yum)
      if [[ "$cmd" == "tc" ]]; then
        # CentOS 8+ 使用 iproute-tc，CentOS 7 使用 iproute
        yum install -y iproute-tc || yum install -y iproute
      else
        yum install -y "${pkg}"
      fi
      ;;
    pacman)
      pacman -Sy --noconfirm "${pkg}"
      ;;
    apk)
      apk add --no-cache "${pkg}"
      ;;
  esac

  if ! command -v "$cmd" >/dev/null 2>&1; then
    # 针对 RedHat 系 tc 命令的二次兼容处理
    if [[ "$cmd" == "tc" && ( "$pm" == "dnf" || "$pm" == "yum" ) ]]; then
      "${pm}" install -y iproute
    fi
    
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "错误：自动安装 ${cmd} 失败。请手动安装该依赖后重试。" >&2
      exit 1
    fi
  fi
  echo "依赖 ${cmd} 安装成功。"
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    resolve_and_install "$1"
  fi
}

service_enable() {
  local name="$1"
  if [[ "$(detect_init)" == "openrc" ]]; then
    rc-update add "${name}" default
  else
    systemctl enable --now "${name}" >/dev/null
  fi
}

service_disable() {
  local name="$1"
  if [[ "$(detect_init)" == "openrc" ]]; then
    rc-update del "${name}" 2>/dev/null || true
  else
    systemctl disable --now "${name}" 2>/dev/null || true
  fi
}

service_restart() {
  local name="$1"
  if [[ "$(detect_init)" == "openrc" ]]; then
    rc-service "${name}" restart 2>/dev/null || rc-service "${name}" start
  else
    systemctl restart "${name}"
  fi
}

service_stop() {
  local name="$1"
  if [[ "$(detect_init)" == "openrc" ]]; then
    rc-service "${name}" stop 2>/dev/null || true
  else
    systemctl stop "${name}" 2>/dev/null || true
  fi
}

daemon_reload() {
  if [[ "$(detect_init)" != "openrc" ]]; then
    systemctl daemon-reload
  fi
}

ensure_bbr_module() {
  if ! sysctl net.ipv4.tcp_available_congestion_control 2>/dev/null | grep -qi bbr; then
    modprobe tcp_bbr 2>/dev/null || true
    if ! sysctl net.ipv4.tcp_available_congestion_control 2>/dev/null | grep -qi bbr; then
      echo "警告：tcp_bbr 模块不可用，当前内核可能不支持 BBR。" >&2
      echo "请确保内核已启用 CONFIG_TCP_CONG_BBR。" >&2
    fi
  fi
  if [[ ! -f /etc/modules-load.d/tcp_bbr.conf ]]; then
    echo "tcp_bbr" > /etc/modules-load.d/tcp_bbr.conf 2>/dev/null || true
    echo "已配置 tcp_bbr 模块开机自动加载。"
  fi
}

detect_iface() {
  if [[ -n "${IFACE}" ]]; then
    echo "${IFACE}"
    return
  fi
  local detected
  detected="$(ip route show default 2>/dev/null | awk 'NR==1 {for (i=1; i<=NF; i++) if ($i=="dev") {print $(i+1); exit}}')"
  if [[ -z "${detected}" ]]; then
    echo "错误：无法检测默认网络接口。请设置 IFACE=enp0s6 后重试。" >&2
    exit 1
  fi
  echo "${detected}"
}

detect_netplan_file() {
  if [[ "$(detect_distro)" == "alpine" ]]; then
    echo ""
    return
  fi
  if [[ -n "${NETPLAN_FILE}" ]]; then
    echo "${NETPLAN_FILE}"
    return
  fi
  local file
  file="$(find /etc/netplan -maxdepth 1 -type f \( -name '*.yaml' -o -name '*.yml' \) 2>/dev/null | sort | head -n 1)"
  if [[ -z "${file}" ]]; then
    echo ""
    return
  fi
  echo "${file}"
}

detect_interfaces_file() {
  if [[ -n "${INTERFACES_FILE}" ]]; then
    echo "${INTERFACES_FILE}"
    return
  fi
  if [[ -f "/etc/network/interfaces" ]]; then
    echo "/etc/network/interfaces"
    return
  fi
  echo ""
}

backup_file() {
  local file="$1"
  if [[ -f "${file}" ]]; then
    cp -a "${file}" "${file}.bak.singleflow.$(date +%Y%m%d%H%M%S)"
  fi
}

set_netplan_mtu() {
  local iface="$1"
  local file="$2"
  local mac=""
  if [[ -z "${file}" || ! -f "${file}" ]]; then
    echo "未找到 netplan 文件。仅应用运行时 MTU。" >&2
    ip link set dev "${iface}" mtu "${MTU}"
    return
  fi
  backup_file "${file}"
  if [[ -r "/sys/class/net/${iface}/address" ]]; then
    mac="$(tr '[:upper:]' '[:lower:]' < "/sys/class/net/${iface}/address")"
  fi
  python3 - "$file" "$iface" "$MTU" "$mac" <<'PY'
import pathlib
import re
import sys
path = pathlib.Path(sys.argv[1])
iface = sys.argv[2]
mtu = sys.argv[3]
runtime_mac = sys.argv[4].lower()
text = path.read_text()
lines = text.splitlines()
def indent_of(line):
    return len(line) - len(line.lstrip(" "))
def block_end(start, indent):
    end = len(lines)
    for i in range(start + 1, len(lines)):
        stripped = lines[i].strip()
        if not stripped or stripped.startswith("#"):
            continue
        if indent_of(lines[i]) <= indent:
            end = i
            break
    return end
ethernets_line = None
ethernets_indent = None
for i, line in enumerate(lines):
    if re.match(r"^\s*ethernets:\s*$", line):
        ethernets_line = i
        ethernets_indent = indent_of(line)
        break
if ethernets_line is None:
    raise SystemExit(f"未在 {path} 中找到 'ethernets:' 部分")
ethernets_end = block_end(ethernets_line, ethernets_indent)
candidates = []
i = ethernets_line + 1
while i < ethernets_end:
    stripped = lines[i].strip()
    if not stripped or stripped.startswith("#"):
        i += 1
        continue
    indent = indent_of(lines[i])
    m = re.match(r"^\s*([^#\s][^:]*):\s*$", lines[i])
    if m and indent > ethernets_indent:
        key = m.group(1).strip().strip("'\"")
        end = block_end(i, indent)
        block = "\n".join(lines[i + 1:end])
        candidates.append((key, i, indent, end, block))
        i = end
        continue
    i += 1
if not candidates:
    raise SystemExit(f"未在 {path} 中找到以太网接口配置")
def block_has_set_name(block, name):
    pat = r"(?m)^\s*set-name:\s*['\"]?" + re.escape(name) + r"['\"]?\s*$"
    return re.search(pat, block) is not None
def block_has_mac(block, mac):
    if not mac:
        return False
    for m in re.finditer(r"(?im)^\s*macaddress:\s*['\"]?([0-9a-f:.-]+)['\"]?\s*$", block):
        if m.group(1).lower() == mac:
            return True
    return False
chosen = None
for candidate in candidates:
    if candidate[0] == iface:
        chosen = candidate
        break
if chosen is None:
    for candidate in candidates:
        if block_has_set_name(candidate[4], iface):
            chosen = candidate
            break
if chosen is None:
    for candidate in candidates:
        if block_has_mac(candidate[4], runtime_mac):
            chosen = candidate
            break
if chosen is None and len(candidates) == 1:
    chosen = candidates[0]
if chosen is None:
    found = ", ".join(c[0] for c in candidates)
    raise SystemExit(
        f"无法匹配运行时接口 {iface!r}。"
        f"找到的 netplan 配置: {found}"
    )
_, iface_line, iface_indent, end, _ = chosen
for i in range(iface_line + 1, len(lines)):
    stripped = lines[i].strip()
    if not stripped or stripped.startswith("#"):
        continue
    indent = indent_of(lines[i])
    if indent <= iface_indent:
        end = i
        break
mtu_idx = None
for i in range(iface_line + 1, end):
    if re.match(r"^\s*mtu:\s*", lines[i]):
        mtu_idx = i
        break
child_indent = None
for i in range(iface_line + 1, end):
    stripped = lines[i].strip()
    if stripped and not stripped.startswith("#"):
        indent = indent_of(lines[i])
        if indent > iface_indent:
            child_indent = indent
            break
if child_indent is None:
    child_indent = iface_indent + 2
new_line = " " * child_indent + f"mtu: {mtu}"
if mtu_idx is not None:
    lines[mtu_idx] = new_line
else:
    lines.insert(end, new_line)
path.write_text("\n".join(lines) + "\n")
PY
  chmod 600 "${file}" || true
  netplan generate
  netplan apply
}

set_interfaces_mtu() {
  local iface="$1"
  local file="$2"
  if [[ -z "${file}" || ! -f "${file}" ]]; then
    echo "未找到 interfaces 文件。仅应用运行时 MTU。" >&2
    ip link set dev "${iface}" mtu "${MTU}"
    return
  fi
  backup_file "${file}"
  python3 - "$file" "$iface" "$MTU" <<'PY'
import sys
import re
import pathlib
path = pathlib.Path(sys.argv[1])
iface = sys.argv[2]
mtu = sys.argv[3]
text = path.read_text()
lines = text.splitlines()
target_idx = -1
for i, line in enumerate(lines):
    if re.match(r"^\s*iface\s+" + re.escape(iface) + r"\b", line):
        target_idx = i
        break
if target_idx == -1:
    lines.append("")
    lines.append(f"auto {iface}")
    lines.append(f"iface {iface} inet dhcp")
    lines.append(f"    mtu {mtu}")
else:
    mtu_idx = -1
    insert_idx = target_idx + 1
    for i in range(target_idx + 1, len(lines)):
        line_str = lines[i].strip()
        if not line_str:
            continue
        if re.match(r"^\s*(iface|auto|allow-|source|source-directory)\b", lines[i]):
            insert_idx = i
            break
        if re.match(r"^\s*mtu\b", lines[i]):
            mtu_idx = i
            break
    else:
        insert_idx = len(lines)
    if mtu_idx != -1:
        indent = len(lines[mtu_idx]) - len(lines[mtu_idx].lstrip())
        if indent == 0: indent = 4
        lines[mtu_idx] = " " * indent + f"mtu {mtu}"
    else:
        indent = 4
        if target_idx + 1 < len(lines) and lines[target_idx + 1].strip() and not re.match(r"^\s*(iface|auto|allow-|source)\b", lines[target_idx + 1]):
            indent = len(lines[target_idx + 1]) - len(lines[target_idx + 1].lstrip())
        lines.insert(insert_idx, " " * indent + f"mtu {mtu}")
path.write_text("\n".join(lines) + "\n")
PY
  ip link set dev "${iface}" mtu "${MTU}"
}

write_sysctl() {
  {
    echo "net.ipv4.tcp_congestion_control = bbr"
    if [[ -f /proc/sys/net/core/default_qdisc ]]; then
      echo "net.core.default_qdisc = fq"
    fi
    echo "net.ipv4.tcp_wmem = 4096 16384 ${TCP_WMEM_MAX}"
    echo "net.ipv4.tcp_rmem = 4096 131072 ${TCP_RMEM_MAX}"
    echo "net.ipv4.tcp_limit_output_bytes = ${TCP_LIMIT_OUTPUT_BYTES}"
  } > "${SYSCTL_FILE}"
  sysctl -p "${SYSCTL_FILE}" 2>/dev/null || true
}

write_qdisc_service() {
  local iface="$1"
  local init
  init="$(detect_init)"
  local svc_file
  svc_file="$(get_service_file "$init")"
  local tc_path
  tc_path="$(command -v tc)"

  if [[ "$init" == "openrc" ]]; then
    cat > "${svc_file}" <<EOF
#!/sbin/openrc-run
description="Set fq qdisc quantum for single-flow throughput"

depend() {
  need net
}

start() {
  ebegin "Setting fq qdisc on ${iface}"
  ${tc_path} qdisc add dev ${iface} root fq quantum ${FQ_QUANTUM} initial_quantum ${FQ_INITIAL_QUANTUM}
  eend \$?
}

stop() {
  ebegin "Removing fq qdisc from ${iface}"
  ${tc_path} qdisc del dev ${iface} root
  eend \$?
}
EOF
    chmod +x "${svc_file}"
  else
    cat > "${svc_file}" <<EOF
[Unit]
Description=Set fq qdisc quantum for single-flow throughput
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStartPre=-${tc_path} qdisc del dev ${iface} root
ExecStart=${tc_path} qdisc add dev ${iface} root fq quantum ${FQ_QUANTUM} initial_quantum ${FQ_INITIAL_QUANTUM}
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
  fi

  daemon_reload
  service_enable "$(basename "${svc_file}")"
  service_restart "$(basename "${svc_file}")" || true
}

restart_network() {
  echo "正在重启网络服务..."
  if [[ -d "/etc/netplan" ]]; then
    netplan generate
    netplan apply
  elif [[ "$(detect_init)" == "openrc" ]]; then
    rc-service networking restart 2>/dev/null || true
  else
    systemctl restart networking
  fi
  echo "网络服务已重启。"
}

show_status() {
  local iface="$1"
  local config_type="$2"
  local config_file="$3"
  local svc_name
  svc_name="$(basename "$(get_service_file)")"
  echo
  echo "========== BBR优化应用成功 =========="
  echo
  echo "接口信息："
  ip link show dev "${iface}" | head -n 1
  echo
  echo "TCP 系统参数："
  sysctl net.ipv4.tcp_congestion_control \
         net.core.default_qdisc \
         net.ipv4.tcp_wmem \
         net.ipv4.tcp_rmem \
         net.ipv4.tcp_limit_output_bytes
  echo
  echo "队列调度规则："
  tc qdisc show dev "${iface}"
  echo
  echo "服务状态："
  if [[ "$(detect_init)" == "openrc" ]]; then
    rc-service "${svc_name}" status || true
  else
    systemctl is-enabled "${svc_name}"
    systemctl is-active "${svc_name}"
  fi
  echo
  if [[ "${config_type}" != "none" ]]; then
    echo "配置方式: ${config_type}"
    echo "配置文件: ${config_file}"
    echo "备份文件: ${config_file}.bak.singleflow.*"
  else
    echo "配置方式: 仅运行时"
  fi
  echo "Sysctl 配置: ${SYSCTL_FILE}"
  echo "服务文件: $(get_service_file)"
  echo "========================================"
  echo
}

check_current_status() {
  need_root
  local iface
  iface="$(detect_iface)"
  echo
  echo "========== 当前网络状态 =========="
  echo
  echo "网络接口: ${iface}"
  echo "MTU 设置: $(ip link show dev "${iface}" | grep -o 'mtu [0-9]*' || echo '未设置')"
  echo "TCP 拥塞控制: $(sysctl -n net.ipv4.tcp_congestion_control)"
  echo "队列调度器: $(sysctl -n net.core.default_qdisc)"
  echo "TCP 写缓冲: $(sysctl -n net.ipv4.tcp_wmem)"
  echo "TCP 读缓冲: $(sysctl -n net.ipv4.tcp_rmem)"
  echo "TCP 输出字节限制: $(sysctl -n net.ipv4.tcp_limit_output_bytes)"
  echo
  echo "队列规则:"
  tc qdisc show dev "${iface}"
  echo
  echo "======================================"
  echo
}

install_optimization() {
  need_root
  # 检查并自动安装缺失的依赖
  need_cmd ip
  need_cmd tc
  need_cmd sysctl
  need_cmd python3

  local init_sys
  init_sys="$(detect_init)"
  if [[ "$init_sys" == "systemd" ]]; then
    need_cmd systemctl
  elif [[ "$init_sys" == "openrc" ]]; then
    need_cmd rc-service
    need_cmd rc-update
  fi
  
  local iface
  local netplan_file
  local interfaces_file
  local config_type="none"
  local config_file=""
  
  iface="$(detect_iface)"
  netplan_file="$(detect_netplan_file)"
  interfaces_file="$(detect_interfaces_file)"
  
  if [[ ! -d "/sys/class/net/${iface}" ]]; then
    echo "错误：接口不存在: ${iface}" >&2
    exit 1
  fi
  
  if [[ -n "${netplan_file}" ]]; then
    config_type="netplan"
    config_file="${netplan_file}"
  elif [[ -n "${interfaces_file}" ]]; then
    config_type="interfaces"
    config_file="${interfaces_file}"
  fi
  
  echo
  echo "========== 优化配置参数 =========="
  echo "接口: ${iface}"
  echo "MTU: ${MTU}"
  echo "FQ 量子: ${FQ_QUANTUM}"
  echo "FQ 初始量子: ${FQ_INITIAL_QUANTUM}"
  echo "TCP 写缓冲最大: ${TCP_WMEM_MAX}"
  echo "TCP 读缓冲最大: ${TCP_RMEM_MAX}"
  echo "TCP 输出字节限制: ${TCP_LIMIT_OUTPUT_BYTES}"
  echo "检测到配置方式: ${config_type}"
  echo "=================================="
  echo
  
  if [[ "${config_type}" == "netplan" ]]; then
    set_netplan_mtu "${iface}" "${netplan_file}"
  elif [[ "${config_type}" == "interfaces" ]]; then
    set_interfaces_mtu "${iface}" "${interfaces_file}"
  else
    echo "未检测到配置文件。仅应用运行时配置..."
    ip link set dev "${iface}" mtu "${MTU}"
  fi
  
  ensure_bbr_module
  write_sysctl
  modprobe sch_fq 2>/dev/null || true
  write_qdisc_service "${iface}"
  restart_network
  show_status "${iface}" "${config_type}" "${config_file}"
  green "感谢使用，再见👋"
}

uninstall_optimization() {
  need_root
  local iface
  local netplan_file
  local interfaces_file
  local config_file=""
  
  iface="$(detect_iface)"
  netplan_file="$(detect_netplan_file)"
  interfaces_file="$(detect_interfaces_file)"
  
  echo
  echo "========== 开始卸载优化 =========="
  echo
  
  local init
  init="$(detect_init)"
  local svc_file
  svc_file="$(get_service_file "$init")"

  if [[ -f "${svc_file}" ]]; then
    echo "停止服务: $(basename "${svc_file}")"
    service_disable "$(basename "${svc_file}")"
    rm -f "${svc_file}"
    daemon_reload
  fi
  
  echo "移除 TC 队列规则..."
  tc qdisc del dev "${iface}" root 2>/dev/null || true
  
  if [[ -f "${SYSCTL_FILE}" ]]; then
    echo "移除 sysctl 配置文件..."
    rm -f "${SYSCTL_FILE}"
    echo "还原默认 TCP 参数..."
    sysctl -w net.ipv4.tcp_congestion_control=cubic || true
    sysctl -w net.core.default_qdisc=fq_codel || true
    sysctl -w net.ipv4.tcp_wmem="4096 16384 4194304" || true
    sysctl -w net.ipv4.tcp_rmem="4096 87380 6291456" || true
    sysctl -w net.ipv4.tcp_limit_output_bytes=262144 || true
    sysctl --system >/dev/null 2>&1 || true
  fi
  
  if [[ -n "${netplan_file}" ]]; then
    config_file="${netplan_file}"
  elif [[ -n "${interfaces_file}" ]]; then
    config_file="${interfaces_file}"
  fi
  
  if [[ -n "${config_file}" ]]; then
    local backup
    backup="$(find "$(dirname "${config_file}")" -maxdepth 1 -type f -name "$(basename "${config_file}").bak.singleflow.*" 2>/dev/null | sort | tail -n 1)"
    if [[ -n "${backup}" && -f "${backup}" ]]; then
      echo "从备份还原配置: ${backup}"
      cp -pf "${backup}" "${config_file}"
      if [[ "${config_file}" == *"netplan"* ]]; then
        netplan apply
      elif [[ "$(detect_init)" == "openrc" ]]; then
        rc-service networking restart
      else
        systemctl restart networking
      fi
    else
      echo "警告：未找到备份文件，无法自动还原网络配置。"
    fi
  fi
  
  echo "还原网络接口 MTU..."
  ip link set dev "${iface}" mtu 1500 || true
  restart_network
  
  echo
  echo "========== 卸载完成 =========="
  echo "网络和 TCP 设置已还原为默认值。"
  echo
  green "感谢使用，再见👋"
}

show_menu() {
  echo
  echo "╔═══════════════════════════════════╗"
  echo "            BBR性能优化工具           "
  echo "╠═══════════════════════════════════╣"
  printf "   作者: %-25s\\n" "${AUTHOR}"
  printf "   版本: %-25s\\n" "${VERSION}"
  echo "╚═══════════════════════════════════╝"
  echo
  echo "请选择操作:"
  echo "  1. 安装应用优化"
  echo "  2. 卸载并还原配置"
  echo "  3. 查看当前BBR状态"
  echo "  4. 退出"
  echo
}

main() {
  while true; do
    show_menu
    read -p "请输入序号 [1-4]: " choice
    case $choice in
      1)
        install_optimization
        ;;
      2)
        uninstall_optimization
        ;;
      3)
        check_current_status
        ;;
       4)
         echo "退出程序。"
         exit 0
        ;;
      *)
        echo "错误：无效的选择，请输入 1-4 之间的数字。"
        ;;
    esac
  done
}

main "$@"