# sb00.sh 落盘文件笔记（开发者备忘，独立于用户向 README）

> 适用版本：`VERSION="2.0.1(2026-09-06)"`（sb00.sh）
> 路径统一为 `$SINGBOX_FOLDER_PATH` = `/root/doraemon/`
> ⚠️ 下文行号为该版本 sb00.sh 的行号，改动后会偏移，仅作定位参考。

## 一、Argo 三协议链路（核心）

| 文件 | 存什么 | 默认/示例 | 写入处 | 读取处 |
|---|---|---|---|---|
| `vlvm` | 当前 argo 用哪个协议 | `Vmess`/`Trojan`/`Vless` | 安装:3346-3350；`sb node`:5349-5367 | need_argo:226；节点:3807；list/node:5262/5335 |
| `port_vm_ws` | vmess 的 sing-box 监听端口 | `41234` | 2235/2237 | nginx 反代:2533 |
| `port_tr` | trojan 的 sing-box 监听端口 | `41235` | 2215/2217 | nginx 反代:2540 |
| `port_vl_ws` | vless 的 sing-box 监听端口 | `41236` | 2255/2257/2261 | nginx 反代:2535 |
| `argoport` | argo 回源本地入口端口（=argo_pt） | `8001` | 3342 | cip 输出:3826 |
| `cdn_host` | 节点链接里对外域名 | `saas.sin.fan` | 3427；`sb node`:5185 | 生成节点:3802 |
| `cdn_pt` | 节点链接里对外端口 | `443` | 3428；`sb node`:5196 | 生成节点:3803 |

**对应关系**：`vlvm` 决定协议 → 该协议的 sing-box 监听端口在
`port_vm_ws`（vmess）/ `port_tr`（trojan）/ `port_vl_ws`（vless）；
对外客户端地址是 `cdn_pt` + `cdn_host`（三协议共用）。

## 二、其它端口 / 凭据 / 隧道文件

| 文件 | 存什么 | 写入处 |
|---|---|---|
| `port_hy2` `port_vlr` `port_tu` `port_any` `port_socks5` | 直连协议监听端口 | 2194/2279/2169/2319/2356 |
| `socks5_user` `socks5_pass` `socks5_wl_flag` `socks5_ips` | socks5 凭据/白名单 | 1177-1212 |
| `nginx_port` | 订阅 nginx 端口（默认8080） | 2519、3431、5136 |
| `subscribe` | 订阅开关 true/false | 3436、5146 |
| `uuid` | 节点 UUID | 1769/1772 |
| `reality.key` `short_id` | reality 私钥/短ID | 2287 等 |
| `argo_domain` | 固定隧道域名 | 3389 |
| `sbargotoken` | argo token | 3392 |
| `tunnel.json` `tunnel.yml` | argo JSON 凭据配置 | 1473/1489 |
| `vl_sni` `hy_sni` `tu_sni` `any_sni` `vl_sni_pt` | 各协议 SNI/伪装端口 | 3422-3433、5204-5234 |
| `name` | 节点名前缀 | 1657 |
| `server_ip` | 出口 IP | 3212 |
| `jh.txt` | 节点链接汇总 | 3570 |
| `sb.json` | 最终生效 sing-box 配置 | 脚本生成 |

## 三、生命周期（关键）

- **维护命令**（`list`/`node`/`sub`/`res`/`logs`…）：**读文件、认可落盘值**，文件保留。
- **`rep` 覆盖安装**：`cleandel` 先清掉所有配置文件（只留 `sing-box`/`cloudflared` 二进制 + `logs/`），再全新重建 ——
  端口重新随机、`cdn_*` 回默认、凭据重新生成（除非命令里显式再传）。
- **`del` 卸载**：清配置保留二进制；**`delall`**：整个 `/root/doraemon` 目录删除。

**记住一句话**：
`vlvm` 决定"哪个协议走 argo"；`port_*`(vm/tr/vl) 决定"sing-box 监听端口"；
`cdn_pt/cdn_host` 决定"客户端连哪个地址"；`argoport` 是"内部回源入口"。
前三类 `rep` 会清，维护命令认文件。

## 四、argo 取值与端口策略（V2.0.1 新增/变更）

- `argo` 值统一转小写，仅 `vmess` / `vless` / `trojan` 有效（三选一），留空=不启用 Argo；
  旧值 `vmpt`/`trpt`/`vlpt` 已废弃。
- 合法性校验**只在 `ins`/`rep`** 时拦截外界传入的非法值；维护命令与菜单不校验，已落盘 `vlvm` 依然认可。
- `vmpt`/`vlpt`/`trpt` 三个端口开关已彻底废弃（脚本不再读取），vmess/trojan/vless 完全由 `argo=` 驱动，
  本地回源端口由脚本随机/复用落盘文件。

## 五、端口占用记录机制（内存，不落盘）

端口占用记录在**脚本进程内存的全局数组**里，脚本退出即清空，**不写入任何文件**：

- 变量：`declare -a SB_TAKEN_PORTS=()`  （sb00.sh:1059）
- `sb_take_port <port>`：登记端口为已占用（幂等；校验 1-65535，非法忽略）  （sb00.sh:1062）
- `sb_port_taken <port>`：查询端口是否已登记  （sb00.sh:1077）
- `sb_take_known_ports`：批量登记三类端口  （sb00.sh:1087）
  1. 环境变量显式协议端口（`hypt/vlrt/tupt/anypt/socks5pt`；`vmpt/vlpt/trpt` 已废弃故恒空）
  2. 服务端口 `nginx_pt`（默认8080）、`argo_pt`（默认8001）
  3. 已落盘的 `port_*` 文件值
- 触发时机：
  - 脚本启动时（CLI 就位）：sb00.sh:1101
  - `installsb` 配置生成开始时：sb00.sh:2146
  - `menu_reload_proto_flags`（菜单选定/随机端口后）：sb00.sh:4488
  - `rand_port` 随机出一个端口后自动登记：sb00.sh:1131
- `rand_port` 防冲突流程（sb00.sh:1104-1133）：随机 10000-65535
  → 已登记？（含本运行已随机/显式/服务/文件端口）→重试
  → `ss` 正被监听？→重试 → 通过 → 登记并返回

> 一句话：保证本次运行内"显式端口、服务端口、历史文件端口、已随机出的端口"互不冲突；不落盘、退出即清空。

## 六、端口打印的 debug 文件说明（V2.0.1）

8 个协议端口打印后都补了一条 **debug 模式专用**的"端口写入哪个文件"说明：

- 正常安装输出不变：`yellow "端口：xxx"`；
- 仅当 `DEBUG_FLAG=1` 时追加 `debug_log " [调试] xxx端口已写入文件：/root/doraemon/port_*"`（走 stderr，不进 install.log）。

| 协议 | debug 时显示的落盘文件 | debug_log 位置 |
|---|---|---|
| Tuic | `port_tu` | 2163 |
| Hysteria2 | `port_hy2` | 2186 |
| Trojan (Argo) | `port_tr` | 2208 |
| Vmess-ws (Argo) | `port_vm_ws` | 2229 |
| Vless-ws (Argo) | `port_vl_ws` | 2254 |
| VLESS-Reality-Vision | `port_vlr` | 2275 |
| AnyTLS | `port_any` | 2327 |
| Socks5 | `port_socks5` | 2360 |