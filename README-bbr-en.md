[简体中文](README-bbr.md) | **English**

# bbr.sh (BBR Single-Stream Performance Optimization One-Click Script)

`bbr.sh` is a BBR + TCP single-stream performance optimization script that supports both **interactive menu** and **non-interactive argument** modes.
It runs under **Alpine / Debian / Ubuntu** (requires **KVM / a dedicated kernel**; OpenVZ containers are not supported, see the next section),
is compatible with **IPv4 / IPv6** environments, and supports repeated execution (idempotent).

---

## ⚠️ Environment Requirements: OpenVZ / LXC Containers Are Not Supported

**The core features of this script (BBR + the fq queue) cannot take effect inside OpenVZ / LXC containers.**

Spend 10 seconds first to confirm your machine type:

| Check Command | Matching Result | Meaning |
|---|---|---|
| `systemd-detect-virt` | `openvz` / `lxc` | Container, not supported |
| `ip -br link` | `venet0` appears | OpenVZ, not supported |
| `tc qdisc show dev venet0` | `qdisc noqueue` | This network interface cannot attach a qdisc |
| `sysctl net.ipv4.tcp_available_congestion_control` | `bbr` not in the list | The host kernel has not enabled BBR |

If any of these checks matches, **neither BBR nor fq will take effect**, for the following reasons:

- `venet0` is OpenVZ's virtual network interface; the kernel **does not allow** attaching a qdisc to it, so `tc qdisc add` is bound to fail and the boot service will also be `failed`;
- Containers **share the kernel** with the host; `modprobe tcp_bbr` inside the container is ineffective, and BBR depends entirely on the host kernel;
- In OpenVZ, many `/proc/sys/net/ipv4/*` entries are read-only or missing, and `sysctl` writes fail silently.

In this case the script can only apply a few globally writable parameters (`tcp_fastopen`, `somaxconn`, etc.),
with very limited improvement to latency and throughput.

> **For BBR, switch to a machine with KVM architecture.**
> The script does not pretend to succeed on OpenVZ: it will skip fq, leave `tcp_congestion_control` unwritten,
> and output "partially applied" plus a list of items that did not take effect.

---

## 1. Features

After running, the script completes the following optimizations in order:

| Item | Description |
|---|---|
| TCP congestion control | Loads and enables `bbr` (`net.ipv4.tcp_congestion_control=bbr`) |
| Queue scheduling | Replaces the network interface's root qdisc with `fq` and enlarges `quantum` / `initial_quantum` to improve single-stream throughput |
| MTU | Modifies the network interface MTU (default 1500), supporting three methods — netplan / `/etc/network/interfaces` / runtime-only — and persists the change |
| TCP buffers | Adjusts `tcp_wmem` / `tcp_rmem` / `tcp_limit_output_bytes`, written to `/etc/sysctl.d/99-singleflow-tcp-optimization.conf` |
| Low-latency tuning | `tcp_notsent_lowat` / `tcp_slow_start_after_idle=0` / `tcp_fastopen=3` / `tcp_tw_reuse` / `tcp_fin_timeout` / `tcp_mtu_probing` / `netdev_max_backlog` etc.; can be disabled with `LATENCY_TUNING=0` |
| Autostart on boot | systemd writes `/etc/systemd/system/singleflow-fq-quantum.service`; OpenRC writes `/etc/init.d/singleflow-fq-quantum`; in init-less environments such as containers it is applied directly at runtime |
| Config backup | On first installation, backs up the original network configuration to `<config file>.bak.singleflow`, fully restored on uninstall/restore |

All operations are **idempotent**: `ins` / `del` / `reset` can be executed repeatedly, producing no redundant backups, no duplicate network restarts, and consistent results.

---

## 2. Quick Start

```bash
# Recommended: interactive menu
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/bbr.sh)
```

> To fetch the latest version while bypassing the CDN cache, use a commit SHA direct link (see the path in the repository's commit history).
> On the server side, you may run `chmod +x bbr.sh` before installation, then run `./bbr.sh`.

Overview of menu functions (each with the corresponding command as a comment):

```
Please select an action:
  1. Install and apply optimization   # ins
  2. Uninstall and restore configuration # reset (del)
  3. View current BBR status          # status
  4. Exit
```

---

## 3. Non-Interactive Commands (Arguments Supported)

```bash
./bbr.sh <command> [interface name]
```

| Command | Aliases | Description |
|---|---|---|
| `ins` | `install`, `req`, `-i` | One-click installation and apply optimization (non-interactive, repeatable) |
| `reset` | `del`, `uninstall`, `-u`, `-r` | Uninstall and fully restore default configuration (non-interactive, repeatable) |
| `status` | `check`, `-s` | View current BBR / network / TCP status |
| `menu` | – | Interactive menu (default behavior when run without arguments) |
| `version` | `-v` | Show version information |
| `help` | `-h`, `--help` | Show help |

The second argument (`[interface name]`) is equivalent to setting the `IFACE` environment variable.

### Common Examples

```bash
# Auto-detect the network interface, one-click installation (root required)
./bbr.sh ins

# Install with a specified network interface
./bbr.sh ins eth0

# Install with a specified MTU (PPPoE commonly uses 1492)
MTU=1492 ./bbr.sh ins eth0

# Non-interactive installation with interface + MTU
MTU=1420 IFACE=ens18 ./bbr.sh ins

# Uninstall and restore (reset is equivalent to del)
./bbr.sh reset eth0

# View status
./bbr.sh status
```

### Direct Remote Execution (No File Download Needed)

```bash
# One-click installation
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/bbr.sh) ins

# Install with a specified MTU
MTU=1492 bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/bbr.sh) ins eth0

# Uninstall (reset is equivalent to del)
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/bbr.sh) reset
```

---

## 4. Tunable Parameters (Environment Variables)

| Variable | Default Value | Description |
|---|---|---|
| `MTU` | `1500` | Network interface MTU (PPPoE uses 1492; can be lowered for special lines) |
| `FQ_QUANTUM` | `18028` | The `quantum` of `fq` scheduling |
| `FQ_INITIAL_QUANTUM` | `90140` | The `initial_quantum` of `fq` scheduling |
| `TCP_WMEM_MAX` | `33554432` | Maximum TCP write buffer |
| `TCP_RMEM_MAX` | `33554432` | Maximum TCP read buffer |
| `TCP_LIMIT_OUTPUT_BYTES` | `4194304` | Upper limit of the per-send quota |
| `IFACE` | Auto-detected | Specify the network interface name |
| `SYSCTL_FILE` | `/etc/sysctl.d/99-singleflow-tcp-optimization.conf` | Path to the sysctl configuration file |
| `SERVICE_FILE` | Auto | Path to the service file (OpenRC: `/etc/init.d/singleflow-fq-quantum`; systemd: `/etc/systemd/system/singleflow-fq-quantum.service`) |
| `NETPLAN_FILE` | Auto-detected | Specify the netplan configuration file |
| `INTERFACES_FILE` | Auto-detected | Specify the interfaces configuration file |
| `LATENCY_TUNING` | `1` | Toggle for the additional low-latency tuning (`0` disables it, keeping only BBR + single-stream throughput parameters) |
| `TCP_NOTSENT_LOWAT` | `131072` | Cap on unsent data, reducing sender-side queuing delay |
| `NETDEV_MAX_BACKLOG` | `16384` | Network interface receive backlog; reduces packet loss when the CPU is busy |
| `SOMAXCONN` | `8192` | Upper limit of the fully-established connection queue |
| `TCP_MAX_SYN_BACKLOG` | `8192` | Upper limit of the half-open connection queue |
| `STATE_FILE` | `/etc/singleflow-bbr.state` | Records the original MTU / sysctl values before installation, for precise restoration on uninstall |

Example (combining multiple parameters):

```bash
MTU=1480 \
FQ_QUANTUM=16000 \
FQ_INITIAL_QUANTUM=90000 \
TCP_WMEM_MAX=33554432 \
TCP_RMEM_MAX=33554432 \
./bbr.sh ins eth0
```

---

## 5. Supported Environments

- Distributions: **Alpine** (automatically installs bash and uses OpenRC), **Debian / Ubuntu** (systemd / netplan)
- Network stacks: **IPv4 / IPv6 / IPv6-only** all work (auto-detects the default route: IPv4 first, then IPv6)
- Container environments: can run without systemd / openrc (applies runtime configuration directly; all commands are fault-tolerant)
- Containers such as OpenVZ/LXC: **core features unavailable**, see the "⚠️ Environment Requirements" section above; the script will skip fq, leave the BBR configuration unwritten, and honestly report "partially applied"
- Dependencies: `ip` / `tc` / `sysctl` / `python3` (when missing, the script automatically installs them via `apt` / `dnf` / `yum` / `pacman` / `apk`)

> When using `./bbr.sh`, root verification is automatic; if not root, run it with `sudo`.

---

## 6. Uninstall and Restore

- **`reset`** (`del` is an alias): full uninstall — stops and removes the boot service, restores the original sysctl values and MTU from before installation (from `STATE_FILE`), switches the qdisc back to `fq_codel`, removes `/etc/modules-load.d/tcp_bbr.conf`, restores the network configuration from the backup, and cleans up the backup and state files.
- Backup file naming: `<config file>.bak.singleflow`; automatically cleaned up after uninstall completes; a fresh `ins` backs up again.
- Both `ins` / `reset` can be executed repeatedly (idempotent):
  - A second `ins` neither restarts the service nor restarts the network;
  - The network is restarted only when the MTU / network configuration actually changes; changing sysctl alone does not restart the network (to avoid SSH disconnection);
  - The configuration file is not rewritten when its content is unchanged (mtime stays unchanged).

---

## 7. Verifying the Optimization

```bash
# TCP congestion control should be bbr
sysctl net.ipv4.tcp_congestion_control

# Queue scheduling should be fq with the quantum parameters
tc qdisc show dev eth0

# View the script status (the script's built-in status also works)
./bbr.sh status eth0
```

---

## 8. Notes

- Root privileges are required (`ins` / `del` / `reset` / `status` all verify internally).
- SSH may disconnect briefly while the MTU is modified / the network is restarted; this is normal.
- Older iproute2 kernels may not support `initial_quantum`; if the qdisc fails to apply, the script reports "not applied", which does not affect the other optimizations.
- This script performs TCP single-stream optimization only; it does not modify iptables / firewall / routing policies.
- If the server's CPU is under sustained full load (stress-test processes, compilation jobs, etc.), receive softirqs are starved, manifesting as periodic RTT spikes (commonly 50~100ms). This kind of latency cannot be solved by TCP parameters; you need to lower CPU load or add vCPUs; `netdev_max_backlog` can only mitigate it, not eliminate it.

---

> Version: `1.5.3(2026-10-20)`
