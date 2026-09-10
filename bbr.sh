#!/bin/sh
# ============================================================
# 引导：确保在 bash 下运行。
# Alpine 默认可能没有安装 bash，这里用 POSIX sh 完成自动
# 检测/安装，然后重新交给 bash 执行。
# ============================================================
if [ -z "${BASH_VERSION:-}" ]; then
  if command -v bash >/dev/null 2>&1; then
    exec bash "$0" "$@"
  fi
  echo "本脚本需要 bash。" >&2
  if [ "$(id -u)" = "0" ]; then
    if command -v apk >/dev/null 2>&1; then
      apk add --no-cache bash >/dev/null 2>&1 || true
    elif command -v apt-get >/dev/null 2>&1; then
      apt-get update -qy >/dev/null 2>&1 || true
      apt-get install -y bash >/dev/null 2>&1 || true
    elif command -v dnf >/dev/null 2>&1; then
      dnf install -y bash >/dev/null 2>&1 || true
    elif command -v yum >/dev/null 2>&1; then
      yum install -y bash >/dev/null 2>&1 || true
    fi
    if command -v bash >/dev/null 2>&1; then
      exec bash "$0" "$@"
    fi
  fi
  echo "错误：无法自动安装 bash。请先手动安装（如: apk add bash / apt install bash）后重试。" >&2
  exit 1
fi
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

VERSION="1.4.2(2026-09-10)"
AUTHOR="jyucoeng"
INTERFACES_FILE="${INTERFACES_FILE:-}"
IFACE="${IFACE:-}"

APT_UPDATED=false

detect_init() {
  # /run/systemd/system 存在说明 systemd 正在作为 init 运行；
  # 否则即使装了 systemctl（例如 Docker 容器）也按非 systemd 处理
  if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
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

green() { echo -e "\033[1;32m$1\033[0m"; }

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
        pkg="busybox"
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

  # 执行安装（容忍非零——部分镜像的 trigger/postinst 可能报错但包已装上；
  # 是否真正可用由下面的 command -v 校验决定）
  case "$pm" in
    apt)
      if [[ "$APT_UPDATED" = false ]]; then
        echo "正在更新软件包列表..."
        apt-get update -qy || true
        APT_UPDATED=true
      fi
      apt-get install -y "${pkg}" || true
      ;;
    dnf)
      dnf install -y "${pkg}" || true
      ;;
    yum)
      if [[ "$cmd" == "tc" ]]; then
        # CentOS 8+ 使用 iproute-tc，CentOS 7 使用 iproute
        yum install -y iproute-tc 2>/dev/null || yum install -y iproute 2>/dev/null || true
      else
        yum install -y "${pkg}" || true
      fi
      ;;
    pacman)
      pacman -Sy --noconfirm "${pkg}" || true
      ;;
    apk)
      # Alpine glibc-compat trigger 可能报语法错误，但包通常已装上；
      # apk 的输出（包括 trigger 报错）正常显示，|| true 避免 set -e 中断
      apk add --no-cache "${pkg}" || true
      ;;
  esac

  if ! command -v "$cmd" >/dev/null 2>&1; then
    # 针对 RedHat 系 tc 命令的二次兼容处理
    if [[ "$cmd" == "tc" && ( "$pm" == "dnf" || "$pm" == "yum" ) ]]; then
      "${pm}" install -y iproute 2>/dev/null || true
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
    rc-update add "${name}" default 2>/dev/null || true
  else
    systemctl enable --now "${name}" >/dev/null 2>&1 || true
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
    rc-service "${name}" restart 2>/dev/null || rc-service "${name}" start 2>/dev/null || true
  else
    systemctl restart "${name}" >/dev/null 2>&1 || true
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
    systemctl daemon-reload >/dev/null 2>&1 || true
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
    if mkdir -p /etc/modules-load.d 2>/dev/null; then
      echo "tcp_bbr" > /etc/modules-load.d/tcp_bbr.conf 2>/dev/null || true
      echo "已配置 tcp_bbr 模块开机自动加载。"
    fi
  fi
}

detect_iface() {
  if [[ -n "${IFACE:-}" ]]; then
    echo "${IFACE}"
    return
  fi
  local detected
  # 先查 IPv4 默认路由；IPv6-only 环境回退查询 IPv6 默认路由
  detected="$(ip route show default 2>/dev/null | awk 'NR==1 {for (i=1; i<=NF; i++) if ($i=="dev") {print $(i+1); exit}}')"
  if [[ -z "${detected}" ]]; then
    detected="$(ip -6 route show default 2>/dev/null | awk 'NR==1 {for (i=1; i<=NF; i++) if ($i=="dev") {print $(i+1); exit}}')"
  fi
  if [[ -z "${detected}" ]]; then
    echo "错误：无法检测默认网络接口（IPv4/IPv6）。请设置 IFACE=<接口名> 后重试。" >&2
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
  local backup="${file}.bak.singleflow"
  # 只在首次创建备份，保留配置文件被优化前的原始内容；
  # 重复执行 ins 不会覆盖原始备份，保证 del 能完整还原。
  if [[ -f "${file}" && ! -f "${backup}" ]]; then
    cp -a "${file}" "${backup}"
    echo "已备份原始配置: ${backup}"
  fi
}

get_current_mtu() {
  local iface="$1"
  ip link show dev "${iface}" 2>/dev/null | grep -o 'mtu [0-9]*' | head -n 1 | awk '{print $2}'
}

set_netplan_mtu() {
  local iface="$1"
  local file="$2"
  local mac=""
  local cur
  cur="$(get_current_mtu "${iface}")"
  if [[ -z "${file}" || ! -f "${file}" ]]; then
    echo "未找到 netplan 文件。仅应用运行时 MTU。" >&2
    if [[ "${cur}" != "${MTU}" ]]; then
      ip link set dev "${iface}" mtu "${MTU}"
      return 0
    fi
    return 1
  fi
  backup_file "${file}"
  if [[ -r "/sys/class/net/${iface}/address" ]]; then
    mac="$(tr '[:upper:]' '[:lower:]' < "/sys/class/net/${iface}/address")"
  fi
  python3 - "$file" "$iface" "$MTU" "$mac" <<'PY' || true
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
  # 运行时 MTU 与目标不一致时才应用 netplan，避免重复触发网络重配置
  if [[ "${cur}" != "${MTU}" ]]; then
    netplan generate 2>/dev/null || true
    netplan apply 2>/dev/null || true
    ip link set dev "${iface}" mtu "${MTU}" 2>/dev/null || true
    return 0
  fi
  return 1
}

set_interfaces_mtu() {
  local iface="$1"
  local file="$2"
  local cur
  cur="$(get_current_mtu "${iface}")"
  if [[ -z "${file}" || ! -f "${file}" ]]; then
    echo "未找到 interfaces 文件。仅应用运行时 MTU。" >&2
    if [[ "${cur}" != "${MTU}" ]]; then
      ip link set dev "${iface}" mtu "${MTU}"
      return 0
    fi
    return 1
  fi
  backup_file "${file}"
  python3 - "$file" "$iface" "$MTU" <<'PY' || true
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
    sys.stderr.write(
        f"警告：未在 {path} 中找到接口 {iface} 的配置，"
        f"跳过配置文件修改（避免错误的 IPv4 配置影响 IPv6 环境），仅应用运行时 MTU。\n"
    )
    sys.exit(0)
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
  if [[ "${cur}" != "${MTU}" ]]; then
    ip link set dev "${iface}" mtu "${MTU}"
    return 0
  fi
  return 1
}

write_sysctl() {
  mkdir -p "$(dirname "${SYSCTL_FILE}")"
  # 内容一致则跳过，避免重复写文件/重复触发 sysctl -p（幂等）
  local tmp
  tmp="$(mktemp)"
  {
    echo "net.ipv4.tcp_congestion_control = bbr"
    if [[ -f /proc/sys/net/core/default_qdisc ]]; then
      echo "net.core.default_qdisc = fq"
    fi
    echo "net.ipv4.tcp_wmem = 4096 16384 ${TCP_WMEM_MAX}"
    echo "net.ipv4.tcp_rmem = 4096 131072 ${TCP_RMEM_MAX}"
    echo "net.ipv4.tcp_limit_output_bytes = ${TCP_LIMIT_OUTPUT_BYTES}"
  } > "${tmp}"
  if [[ -f "${SYSCTL_FILE}" ]] && cmp -s "${SYSCTL_FILE}" "${tmp}"; then
    rm -f "${tmp}"
    return 1
  fi
  mv -f "${tmp}" "${SYSCTL_FILE}"
  sysctl -p "${SYSCTL_FILE}" 2>/dev/null || true
  return 0
}

write_qdisc_service() {
  local iface="$1"
  local changed="${2:-false}"
  local init
  init="$(detect_init)"
  local svc_file
  svc_file="$(get_service_file "$init")"
  local svc_name
  svc_name="$(basename "${svc_file}")"
  local tc_path
  tc_path="$(command -v tc)"
  mkdir -p "$(dirname "${svc_file}")"

  # 判断服务文件是否已由本脚本写入（幂等判断依据）
  local svc_matches=false
  if [[ -f "${svc_file}" ]] && grep -q "Generated by singleflow-bbr" "${svc_file}" 2>/dev/null; then
    svc_matches=true
  fi

  if [[ "$init" == "openrc" ]]; then
    cat > "${svc_file}" <<EOF
#!/sbin/openrc-run
# Generated by singleflow-bbr (bbr.sh)，请勿手动编辑
description="Set fq qdisc quantum for single-flow throughput"

depend() {
  need net
}

start() {
  ebegin "Setting fq qdisc on ${iface}"
  ${tc_path} qdisc del dev ${iface} root 2>/dev/null
  ${tc_path} qdisc add dev ${iface} root fq quantum ${FQ_QUANTUM} initial_quantum ${FQ_INITIAL_QUANTUM}
  eend \$?
}

stop() {
  ebegin "Removing fq qdisc from ${iface}"
  ${tc_path} qdisc del dev ${iface} root 2>/dev/null
  eend \$?
}
EOF
    chmod +x "${svc_file}"
  else
    cat > "${svc_file}" <<EOF
# Generated by singleflow-bbr (bbr.sh)，请勿手动编辑
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
  service_enable "${svc_name}"

  local qdisc_fq=false
  if tc qdisc show dev "${iface}" 2>/dev/null | grep -q ' qdisc fq '; then
    qdisc_fq=true
  fi

  # 仅在「有变更 / 服务是新建 / qdisc 尚未应用」时才重启服务，
  # 保证重复执行 ins 不产生额外扰动（幂等）。
  if [[ "${changed}" == "true" || "${svc_matches}" != "true" || "${qdisc_fq}" != "true" ]]; then
    service_restart "${svc_name}" || true
  fi

  # 无 systemd/openrc 的环境（如容器）：直接应用运行时队列规则
  if [[ "$init" == "unknown" ]]; then
    if [[ "${changed}" == "true" || "${qdisc_fq}" != "true" ]]; then
      ${tc_path} qdisc del dev "${iface}" root 2>/dev/null || true
      ${tc_path} qdisc add dev "${iface}" root fq quantum "${FQ_QUANTUM}" initial_quantum "${FQ_INITIAL_QUANTUM}" 2>/dev/null || true
    fi
  fi
}

restart_network() {
  echo "正在重启网络服务..."
  if [[ -d "/etc/netplan" ]]; then
    netplan generate 2>/dev/null || true
    netplan apply 2>/dev/null || true
  elif [[ "$(detect_init)" == "openrc" ]]; then
    rc-service networking restart 2>/dev/null || true
  else
    systemctl restart networking 2>/dev/null || true
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
  sysctl net.ipv4.tcp_congestion_control 2>/dev/null || echo "net.ipv4.tcp_congestion_control: 不可用"
  sysctl net.core.default_qdisc 2>/dev/null || echo "net.core.default_qdisc: 不可用"
  sysctl net.ipv4.tcp_wmem 2>/dev/null || echo "net.ipv4.tcp_wmem: 不可用"
  sysctl net.ipv4.tcp_rmem 2>/dev/null || echo "net.ipv4.tcp_rmem: 不可用"
  sysctl net.ipv4.tcp_limit_output_bytes 2>/dev/null || echo "net.ipv4.tcp_limit_output_bytes: 不可用"
  echo
  echo "队列调度规则："
  tc qdisc show dev "${iface}"
  echo
  echo "服务状态："
  if [[ "$(detect_init)" == "openrc" ]]; then
    rc-service "${svc_name}" status || true
  elif [[ "$(detect_init)" == "systemd" ]]; then
    systemctl is-enabled "${svc_name}" 2>/dev/null || echo "启用状态: 未知"
    systemctl is-active "${svc_name}" 2>/dev/null || echo "运行状态: 未知"
  else
    echo "服务管理: 未检测到 systemd/openrc（容器等环境）"
    if tc qdisc show dev "${iface}" 2>/dev/null | grep -q 'fq'; then
      echo "队列规则: 已应用"
    else
      echo "队列规则: 未应用"
    fi
  fi
  echo
  if [[ "${config_type}" != "none" ]]; then
    echo "配置方式: ${config_type}"
    echo "配置文件: ${config_file}"
    echo "备份文件: ${config_file}.bak.singleflow"
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
  echo "TCP 拥塞控制: $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo '不可用')"
  echo "队列调度器: $(sysctl -n net.core.default_qdisc 2>/dev/null || echo '不可用')"
  echo "TCP 写缓冲: $(sysctl -n net.ipv4.tcp_wmem 2>/dev/null || echo '不可用')"
  echo "TCP 读缓冲: $(sysctl -n net.ipv4.tcp_rmem 2>/dev/null || echo '不可用')"
  echo "TCP 输出字节限制: $(sysctl -n net.ipv4.tcp_limit_output_bytes 2>/dev/null || echo '不可用')"
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

  # 幂等标志：只有发生实际变更时才触发网络重启/服务重启
  local changed=false

  if [[ "${config_type}" == "netplan" ]]; then
    if set_netplan_mtu "${iface}" "${netplan_file}"; then
      changed=true
    fi
  elif [[ "${config_type}" == "interfaces" ]]; then
    if set_interfaces_mtu "${iface}" "${interfaces_file}"; then
      changed=true
    fi
  else
    echo "未检测到配置文件。仅应用运行时配置..."
    if [[ "$(get_current_mtu "${iface}")" != "${MTU}" ]]; then
      ip link set dev "${iface}" mtu "${MTU}"
      changed=true
    fi
  fi

  ensure_bbr_module
  if write_sysctl; then
    changed=true
  fi
  modprobe sch_fq 2>/dev/null || true

  # 幂等：仅当确有变更时才重启网络，重复执行 ins 不会无谓地重启网络
  if [[ "${changed}" == "true" ]]; then
    restart_network
  fi

  write_qdisc_service "${iface}" "${changed}"
  show_status "${iface}" "${config_type}" "${config_file}"
  green "感谢使用，再见👋"
}

uninstall_optimization() {
  need_root
  need_cmd ip
  need_cmd tc
  local iface
  local netplan_file
  local interfaces_file
  local config_file=""
  local changed=false
  local config_restored=false

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
    changed=true
  fi

  if tc qdisc show dev "${iface}" 2>/dev/null | grep -q ' qdisc fq '; then
    echo "移除 TC 队列规则..."
    tc qdisc del dev "${iface}" root 2>/dev/null || true
    changed=true
  fi

  if [[ -f "${SYSCTL_FILE}" ]]; then
    echo "移除 sysctl 配置文件..."
    rm -f "${SYSCTL_FILE}"
    echo "还原默认 TCP 参数..."
    sysctl -w net.ipv4.tcp_congestion_control=cubic || true
    sysctl -w net.core.default_qdisc=fq_codel || true
    sysctl -w net.ipv4.tcp_wmem="4096 16384 4194304" || true
    sysctl -w net.ipv4.tcp_rmem="4096 87380 6291456" || true
    sysctl -w net.ipv4.tcp_limit_output_bytes=262144 || true
    if [[ "$(detect_init)" == "openrc" ]]; then
      rc-service sysctl restart 2>/dev/null || true
    else
      sysctl --system >/dev/null 2>&1 || true
    fi
    changed=true
  fi

  if [[ -n "${netplan_file}" ]]; then
    config_file="${netplan_file}"
  elif [[ -n "${interfaces_file}" ]]; then
    config_file="${interfaces_file}"
  fi

  if [[ -n "${config_file}" && -f "${config_file}" ]]; then
    local backup="${config_file}.bak.singleflow"
    if [[ -f "${backup}" ]]; then
      if ! cmp -s "${config_file}" "${backup}"; then
        echo "从备份还原配置: ${backup}"
        cp -pf "${backup}" "${config_file}"
        if [[ "${config_file}" == *"netplan"* ]]; then
          netplan apply 2>/dev/null || true
        elif [[ "$(detect_init)" == "openrc" ]]; then
          rc-service networking restart 2>/dev/null || true
        else
          systemctl restart networking 2>/dev/null || true
        fi
        changed=true
      else
        echo "配置已与备份一致，无需还原。"
      fi
      config_restored=true
      # 还原/确认后清理备份，保持干净状态，方便下次 ins 重新备份
      rm -f "${backup}"
    else
      echo "未找到备份文件 ${backup}，跳过配置还原。"
    fi
  fi

  # 有配置文件且已还原时以配置为准；否则（仅运行时安装）恢复默认 MTU 1500
  if [[ "${config_restored}" != "true" ]]; then
    if [[ "$(get_current_mtu "${iface}")" != "1500" ]]; then
      echo "还原网络接口 MTU 为 1500..."
      ip link set dev "${iface}" mtu 1500 || true
      changed=true
    fi
  fi

  # 有实际变更才重启网络；配置文件已还原应用过则无需再重启
  if [[ "${changed}" == "true" && "${config_restored}" != "true" ]]; then
    restart_network
  fi

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
  echo "  1. 安装应用优化      # ins"
  echo "  2. 卸载并还原配置    # reset (del)"
  echo "  3. 查看当前BBR状态   # status"
  echo "  4. 退出"
  echo
  echo "提示: 也可非交互执行 ./bbr.sh ins|reset|status [接口名]"
  echo
}

show_usage() {
  echo "用法: $0 <命令> [接口名]"
  echo
  echo "命令:"
  echo "  ins          一键安装并应用 BBR + TCP 优化（非交互，可重复执行）"
  echo "  reset        卸载并还原默认配置（非交互，可重复执行，等价 del）"
  echo "  del          reset 的别名（等同 reset）"
  echo "  status       查看当前 BBR / 网络 / TCP 状态"
  echo "  menu         显示交互菜单（默认无参数时的行为）"
  echo "  version      显示版本信息"
  echo "  help         显示本帮助"
  echo
  echo "参数:"
  echo "  [接口名]     可选，指定网卡（等价于设置 IFACE 环境变量）"
  echo
  echo "环境变量:"
  echo "  IFACE MTU FQ_QUANTUM FQ_INITIAL_QUANTUM TCP_WMEM_MAX TCP_RMEM_MAX"
  echo "  TCP_LIMIT_OUTPUT_BYTES SYSCTL_FILE SERVICE_FILE NETPLAN_FILE INTERFACES_FILE"
  echo
  echo "示例:"
  echo "  $0 ins                      # 自动检测网卡并一键安装"
  echo "  $0 ins eth0                 # 指定网卡 eth0 一键安装"
  echo "  $0 reset eth0               # 卸载并还原默认配置（del 等同）"
  echo "  echo '1' | $0 menu          # 等同交互菜单"
  echo "  MTU=1420 IFACE=pppoe0 $0 ins eth0"
  echo
}

loop_menu() {
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

main() {
  local cmd="${1:-}"
  # 可选的第二个参数当作网卡名（等价于 IFACE=xxx）
  if [[ -z "${IFACE:-}" && -n "${2:-}" ]]; then
    IFACE="$2"
  fi
  case "${cmd}" in
    "")
      loop_menu
      ;;
    ins | install | req | -i)
      install_optimization
      ;;
    del | uninstall | reset | -u | -r)
      uninstall_optimization
      ;;
    status | check | -s)
      check_current_status
      ;;
    menu)
      loop_menu
      ;;
    version | -v)
      echo "bbr.sh ${VERSION} (author: ${AUTHOR})"
      ;;
    help | -h | --help)
      show_usage
      ;;
    *)
      echo "错误：未知命令 '${cmd}'。" >&2
      show_usage
      exit 1
      ;;
  esac
}

main "$@"