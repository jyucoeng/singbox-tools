# bbr.sh（BBR 单流性能优化一键脚本）

`bbr.sh` 是一个 BBR + TCP 单流性能优化脚本，支持 **交互式菜单** 与 **无交互参数** 两种模式，
可在 **Alpine / Debian / Ubuntu** 下运行（需 **KVM / 独立内核**，OpenVZ 容器用不了，见下节），
兼容 **IPv4 / IPv6** 环境，且支持重复执行（幂等）。

---

## ⚠️ 环境要求：OpenVZ / LXC 容器用不了

**本脚本的核心功能（BBR + fq 队列）在 OpenVZ / LXC 容器里无法生效。**

先花 10 秒确认机器类型：

| 检查命令 | 命中结果 | 含义 |
|---|---|---|
| `systemd-detect-virt` | `openvz` / `lxc` | 容器，不支持 |
| `ip -br link` | 出现 `venet0` | OpenVZ，不支持 |
| `tc qdisc show dev venet0` | `qdisc noqueue` | 该网卡挂不了 qdisc |
| `sysctl net.ipv4.tcp_available_congestion_control` | 列表里没有 `bbr` | 宿主机内核没开 BBR |

只要命中任意一条，**BBR 和 fq 都不会生效**，原因：

- `venet0` 是 OpenVZ 的虚拟网卡，内核**不允许**给它挂 qdisc，`tc qdisc add` 必然失败，开机服务也会 `failed`；
- 容器与宿主机**共用内核**，容器内 `modprobe tcp_bbr` 无效，BBR 完全取决于宿主机内核；
- OpenVZ 里大量 `/proc/sys/net/ipv4/*` 是只读或缺失的，`sysctl` 写入会静默失败。

这种情况下脚本只能应用少数全局可写的参数（`tcp_fastopen`、`somaxconn` 等），
对延迟和吞吐的提升非常有限。

> **想要 BBR 请换 KVM 架构的机器。**
> 脚本在 OpenVZ 上不会假装成功：会跳过 fq、不写 `tcp_congestion_control`，
> 并输出「优化部分生效」+ 未生效项清单。

---

## 1、功能说明

运行后脚本会依次完成以下优化：

| 项目 | 说明 |
|---|---|
| TCP 拥塞控制 | 加载并启用 `bbr`（`net.ipv4.tcp_congestion_control=bbr`） |
| 队列调度 | 网卡根 qdisc 更换为 `fq`，并调大 `quantum` / `initial_quantum`，提升单流吞吐 |
| MTU | 修改网卡 MTU（默认 1500），支持 netplan / `/etc/network/interfaces` / 仅运行时 三种方式并持久化 |
| TCP 缓冲 | 调整 `tcp_wmem` / `tcp_rmem` / `tcp_limit_output_bytes`，写入 `/etc/sysctl.d/99-singleflow-tcp-optimization.conf` |
| 低延迟调优 | `tcp_notsent_lowat` / `tcp_slow_start_after_idle=0` / `tcp_fastopen=3` / `tcp_tw_reuse` / `tcp_fin_timeout` / `tcp_mtu_probing` / `netdev_max_backlog` 等，可用 `LATENCY_TUNING=0` 关闭 |
| 开机自启 | systemd 写入 `/etc/systemd/system/singleflow-fq-quantum.service`；OpenRC 写入 `/etc/init.d/singleflow-fq-quantum`；容器等无 init 环境直接运行时应用 |
| 配置备份 | 首次安装时备份原始网络配置到 `<配置文件>.bak.singleflow`，卸载/恢复时完整还原 |

所有操作均 **幂等**：`ins` / `del` / `reset` 可重复执行，不产生多余备份、不重复重启网络、效果一致。

---

## 2、快速开始

```bash
# 推荐：交互式菜单
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/bbr.sh)
```

> 若需绕过 CDN 缓存获取最新版，使用 commit SHA 直链（见仓库提交记录中的路径）。
> 服务器端可在安装前执行 `chmod +x bbr.sh`，然后 `./bbr.sh` 运行。

菜单功能一览（均带对应命令注释）：

```
请选择操作:
  1. 安装应用优化      # ins
  2. 卸载并还原配置    # reset (del)
  3. 查看当前BBR状态   # status
  4. 退出
```

---

## 3、无交互命令（可加参数）

```bash
./bbr.sh <命令> [接口名]
```

| 命令 | 别名 | 说明 |
|---|---|---|
| `ins` | `install`, `req`, `-i` | 一键安装并应用优化（非交互，可重复执行） |
| `reset` | `del`, `uninstall`, `-u`, `-r` | 卸载并完整还原默认配置（非交互，可重复执行） |
| `status` | `check`, `-s` | 查看当前 BBR / 网络 / TCP 状态 |
| `menu` | – | 交互菜单（默认无参数时的行为） |
| `version` | `-v` | 显示版本信息 |
| `help` | `-h`, `--help` | 显示帮助 |

第二个参数（`[接口名]`）等价于设置 `IFACE` 环境变量。

### 常用示例

```bash
# 自动检测网卡，一键安装（需 root）
./bbr.sh ins

# 指定网卡安装
./bbr.sh ins eth0

# 指定 MTU 安装（PPPoE 常用 1492）
MTU=1492 ./bbr.sh ins eth0

# 指定接口 + MTU 非交互安装
MTU=1420 IFACE=ens18 ./bbr.sh ins

# 卸载并还原（reset 与 del 等价）
./bbr.sh reset eth0

# 查看状态
./bbr.sh status
```

### 直接远程执行（无需下载文件）

```bash
# 一键安装
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/bbr.sh) ins

# 指定 MTU 并安装
MTU=1492 bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/bbr.sh) ins eth0

# 卸载（reset 与 del 等价）
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/bbr.sh) reset
```

---

## 4、可调参数（环境变量）

| 变量 | 默认值 | 说明 |
|---|---|---|
| `MTU` | `1500` | 网卡 MTU（PPPoE 用 1492，特殊线路可调小） |
| `FQ_QUANTUM` | `18028` | `fq` 调度的 quantum |
| `FQ_INITIAL_QUANTUM` | `90140` | `fq` 调度的 initial_quantum |
| `TCP_WMEM_MAX` | `33554432` | TCP 写缓冲最大值 |
| `TCP_RMEM_MAX` | `33554432` | TCP 读缓冲最大值 |
| `TCP_LIMIT_OUTPUT_BYTES` | `4194304` | 单次发送配额上限 |
| `IFACE` | 自动检测 | 指定网卡名 |
| `SYSCTL_FILE` | `/etc/sysctl.d/99-singleflow-tcp-optimization.conf` | sysctl 配置文件路径 |
| `SERVICE_FILE` | 自动 | 服务文件路径（OpenRC 为 `/etc/init.d/singleflow-fq-quantum`，systemd 为 `/etc/systemd/system/singleflow-fq-quantum.service`） |
| `NETPLAN_FILE` | 自动检测 | 指定 netplan 配置文件 |
| `INTERFACES_FILE` | 自动检测 | 指定 interfaces 配置文件 |
| `LATENCY_TUNING` | `1` | 低延迟附加调优开关（`0` 关闭，只保留 BBR + 单流吞吐参数） |
| `TCP_NOTSENT_LOWAT` | `131072` | 未发送数据上限，降低发送侧排队延迟 |
| `NETDEV_MAX_BACKLOG` | `16384` | 网卡收包 backlog，CPU 繁忙时减少丢包 |
| `SOMAXCONN` | `8192` | 全连接队列上限 |
| `TCP_MAX_SYN_BACKLOG` | `8192` | 半连接队列上限 |
| `STATE_FILE` | `/etc/singleflow-bbr.state` | 记录安装前的原始 MTU / sysctl 值，供卸载精确还原 |

示例（多参数组合）：

```bash
MTU=1480 \
FQ_QUANTUM=16000 \
FQ_INITIAL_QUANTUM=90000 \
TCP_WMEM_MAX=33554432 \
TCP_RMEM_MAX=33554432 \
./bbr.sh ins eth0
```

---

## 5、支持的环境

- 发行版：**Alpine**（自动安装 bash 并走 OpenRC）、**Debian / Ubuntu**（systemd / netplan）
- 网络栈：**IPv4 / IPv6 / IPv6-only** 均可（自动检测默认路由：先 IPv4 后 IPv6）
- 容器环境：无 systemd / openrc 也能运行（直接应用运行时配置，命令全部容错）
- OpenVZ/LXC 等容器：**核心功能不可用**，详见上文「⚠️ 环境要求」；脚本会跳过 fq、不写 BBR 配置，并如实报告「部分生效」
- 依赖：`ip` / `tc` / `sysctl` / `python3`（缺失时脚本会自动调用 `apt` / `dnf` / `yum` / `pacman` / `apk` 安装）

> 使用 `./bbr.sh` 时自动以 root 校验；非 root 请用 `sudo` 运行。

---

## 6、卸载与还原

- **`reset`**（`del` 为别名）：完整卸载——停止并删除开机服务、还原安装前的原始 sysctl 值与 MTU（来自 `STATE_FILE`）、把 qdisc 换回 `fq_codel`、移除 `/etc/modules-load.d/tcp_bbr.conf`、从备份还原网络配置、清理备份与状态文件。
- 备份文件命名：`<配置文件>.bak.singleflow`；卸载完成后自动清理，重新 `ins` 会再次备份。
- `ins` / `reset` 均可重复执行（幂等）：
  - 第二次 `ins` 不会重启服务，也不会重启网络；
  - 只有 MTU / 网络配置真的变化时才重启网络，单纯改 sysctl 不重启网络（避免 SSH 断连）；
  - 配置文件内容未变化时不重写（mtime 不变）。

---

## 7、验证优化效果

```bash
# TCP 拥塞控制应为 bbr
sysctl net.ipv4.tcp_congestion_control

# 队列调度应为 fq 且带量子参数
tc qdisc show dev eth0

# 查看脚本状态（也可用脚本自带 status）
./bbr.sh status eth0
```

---

## 8、注意事项

- 需要 root 权限（`ins` / `del` / `reset` / `status` 内部均有校验）。
- 修改 MTU / 重启网络期间 SSH 可能短暂断开，属正常现象。
- 较老的 iproute2 内核可能不支持 `initial_quantum`，qdisc 应用失败时脚本会提示“未应用”，不影响其余优化。
- 本脚本只做 TCP 单流优化，不修改 iptables / 防火墙 / 路由策略。
- 若服务器 CPU 长期满载（压测进程、编译任务等），收包软中断会被饿死，表现为 RTT 周期性尖峰（常见 50~100ms）。这类延迟不是 TCP 参数能解决的，需要降低 CPU 负载或增加 vCPU；`netdev_max_backlog` 只能缓解，不能消除。

---

> 版本：`1.5.3(2026-10-20)`