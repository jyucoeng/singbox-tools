# bbr.sh（BBR 单流性能优化一键脚本）

`bbr.sh` 是一个 BBR + TCP 单流性能优化脚本，支持 **交互式菜单** 与 **无交互参数** 两种模式，
可在 **Alpine / Debian / Ubuntu** 下运行，兼容 **IPv4 / IPv6** 环境，且支持重复执行（幂等）。

---

## 1、功能说明

运行后脚本会依次完成以下优化：

| 项目 | 说明 |
|---|---|
| TCP 拥塞控制 | 加载并启用 `bbr`（`net.ipv4.tcp_congestion_control=bbr`） |
| 队列调度 | 网卡根 qdisc 更换为 `fq`，并调大 `quantum` / `initial_quantum`，提升单流吞吐 |
| MTU | 修改网卡 MTU（默认 1500），支持 netplan / `/etc/network/interfaces` / 仅运行时 三种方式并持久化 |
| TCP 缓冲 | 调整 `tcp_wmem` / `tcp_rmem` / `tcp_limit_output_bytes`，写入 `/etc/sysctl.d/99-singleflow-tcp-optimization.conf` |
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
- 依赖：`ip` / `tc` / `sysctl` / `python3`（缺失时脚本会自动调用 `apt` / `dnf` / `yum` / `pacman` / `apk` 安装）

> 使用 `./bbr.sh` 时自动以 root 校验；非 root 请用 `sudo` 运行。

---

## 6、卸载与还原

- **`reset`**（`del` 为别名）：完整卸载——删除开机服务、恢复 fq_codel 等默认 TCP/sysctl 参数、从备份还原网络配置、清理备份文件。
- 备份文件命名：`<配置文件>.bak.singleflow`；卸载完成后自动清理，重新 `ins` 会再次备份。
- `ins` / `reset` 均可重复执行（幂等）。

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

---

> 版本：`1.4.1(2026-09-10)`