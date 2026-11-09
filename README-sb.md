# sing-box 一键安装脚本

支持两种安装方式：

- **交互式**：直接运行 `bash sb.sh`（不带参数），按菜单提示完成安装、卸载、查看等操作。
- **非交互式**：用环境变量 + 参数一行完成（见下方示例），也可搭配 [命令生成版界面](https://github.com/jyucoeng/singbox-tools-interface)（部署后用自己的域名访问） 使用。

安装后可用 **`sb` 快捷指令**：`sb` 打开主菜单，`sb ins` / `sb rep` / `sb list` / `sb rt` / `sb node` / `sb sub` / `sb del` 一步直达对应功能（完整清单见 [sb 快捷指令](#26-sb-快捷指令)）。

<a id="c1"></a>

#### 📌 快速定位
#### [**① 基础命令**](#mod-1)　[**② 直连协议片段**](#mod-2)　[**③ Argo 协议片段**](#mod-3)　[**④ 回源协议片段**](#mod-4)　[**⑤ Nginx 模块**](#mod-5)
#### [**综合示例（直连 + Argo + 回源全开）**](#full-example)　[**如何卸载**](#uninstall)　
#### [**🌐 CF（Cloudflare）回源规则部署**](#cf-origin)　[**第 1 章 · 安装与卸载**](#c1)　[**第 2 章 · 其余说明**](#c2)

# 1、 sing-box 安装与卸载
## 支持的协议

vmess / trojan / vless（走 Argo，可多选）+ Hysteria2 + VLESS-Reality + TUIC + AnyTLS + Socks5，以及 vmess / vless / trojan 的 ws_cdn CDN 回源；这些协议可自由组合。

下面按「基础命令 + 协议片段」列出所有环境变量。

> **⚠️ 引号规则**：非数字的值请用**英文单引号**包起来，例如 `name='小叮当'`、`socks5_password='a@b#c'`。这样密码里的 `$`、`!`、`#` 等字符不会被 shell 提前展开；纯数字（端口、`ippz`、`DEBUG_FLAG`）不用引号。

**用法：基础命令只写一次，协议片段按需拼在基础命令上方。** 拼好后就是一条完整命令；删掉某行即不启用对应协议。

> ②③④ 的片段只列变量，最后一行带 `\`，直接接 ① 的变量区即可（结尾仍是 `bash ... rep`）。

<a id="mod-1"></a>
## ① 基础命令（所有协议共用；结尾的 `bash <(...) rep` 只写这一处）

```bash
uuid=00000000-0000-4000-8000-000000000000 \
ippz=4 \
name='小叮当-美国加州' \
nginx_pt=41007 \
subscribe=true \
DEBUG_FLAG=0 \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

> 可选变量（需要时加到 `DEBUG_FLAG` 之前，不需要就别写）：
> - `out_ip='216.166.22.30'`：出口 IP 与 SSH IP 不一致时，指定节点里显示的 IP
> - `direct_host='node.example.com'`：直连协议链接里的 IP 换成域名（需自行加 DNS 记录并关闭小黄云）

> **基础命令变量说明：**
>
> - `uuid`：节点 UUID，不传则自动生成
> - `ippz`：出口 IP 偏好（`4`=仅 IPv4、`6`=仅 IPv6，不传=自动，优先 IPv4）
> - `name`：节点名称前缀
> - `subscribe` / `nginx_pt`：开启订阅及订阅端口（`nginx_pt` 也是 ws_cdn 回源端口）
> - `out_ip`：特殊出口 IP（仅当出口 IP 与服务器 IP 不一致时，配合 `ippz` 使用；一般不填）
> - `direct_host`：直连协议对外域名（把直连协议链接里的 IP 换成该域名；需自行在 Cloudflare DNS 加 A/AAAA 记录并关闭「小黄云」）
> - `DEBUG_FLAG`：日志调试开关（`0`=关，`1`=开，调试输出写入 `doraemon/debug.log`）
>
> 逐项详细说明：

### 1、 命令参数：rep / del / delall / list / list key

| 参数 | 作用 |
|---|---|
| `rep` | 覆盖安装（先卸载再安装） |
| `del` | 卸载，保留 sing-box / cloudflared 等二进制 |
| `delall` | 彻底卸载，连二进制和配置一起删 |
| `list` | 查看节点 |
| `list key` | 查看节点 + VLESS Reality 私钥 |

- 不带参数 = 进入交互菜单。
- `list key` 是把 `list` 和 `key` 两个参数一起传，不是两条命令。

### 2、 uuid（节点 UUID，可选）

**含义**
- 不传 `uuid` → 脚本自动生成
- 传 `uuid` → 使用你指定的 UUID


### 3、 ippz 和 out_ip（IP显示策略和特殊出口 IP，可选）

| ippz | 含义 |
|---|---|
| `4` | 只用 IPv4 |
| `6` | 只用 IPv6 |
| 不传 | 自动（优先 IPv4，没有 IPv4 再用 IPv6） |

`ippz` 决定节点里写 IPv4 还是 IPv6，也会影响 sing-box / nginx 是否监听 IPv6（`ippz=4` 时不监听 `[::]`）。

`out_ip` 用于「SSH 连的 IP」和「脚本探测到的出口 IP」不一致的情况：脚本默认把探测到的出口 IP 写进节点，但客户端要连的是你 SSH 的那个 IP，这时用 `out_ip` 指定后者：

- IPv4：`out_ip='216.166.22.30' ippz=4`
- IPv6：`out_ip='2602:294:0:b7:1234:1234:d9d4:0001' ippz=6`


 <img width="602" height="132" alt="CleanShot 2026-01-26 at 12 57 34" src="https://github.com/user-attachments/assets/57c1a329-9292-45b5-aa23-3c59cd3e3356" />


### 4、 direct_host（直连协议对外域名，掩盖 IP，可选）

👉 `direct_host='你的对外域名'`：脚本把直连协议（hy2/tuic/vless-reality/anytls/socks5）链接里的 host 从「服务器 IP」替换成该域名。

**前提（脚本不处理 DNS，需自行完成）：**
1. 到 [Cloudflare 控制台](https://dash.cloudflare.com/) 的对应域名下的 DNS 给该域名添加解析记录，指向服务器**真正绑定的对外 IP**：IPv4 用 A 记录、IPv6 用 AAAA 记录（脚本安装时的 `direct_host` 提示会根据 out_ip / 检测到的 IP 自动算出该绑的地址）；
2. **务必关闭「小黄云」(Proxy / 橙色云)，保持灰云 (DNS only)**；否则 UDP 直连(hy2/tuic)无法穿透，节点不通；
3. 端口不变 = 直连协议各自的本地监听端口（`hypt`/`vlrt`/`tupt`/`anypt`/`socks5pt`）。

👉 不传则直连链接继续显示真实服务器 IP，不影响服务运行。该变量**只影响直连协议链接输出**，Argo / CDN 回源链路不受影响。安装后可在菜单 `node → 直连对外域名 (掩盖IP)` 查看、修改或清除。


### 5、 nginx_pt（nginx 订阅端口，默认 8080）

- 不传：默认 8080
- 传：nginx 订阅监听该端口

❗`nginx_pt` 不能和 `argo_pt` 相同。`argo_pt` 默认 8001，所以不改 `argo_pt` 时，`nginx_pt` 不要设成 8001。


### 6、 subscribe（订阅开关，默认 false，即不需要 nginx 订阅）

- `false`（默认）：不生成订阅；但如果启用了 Argo，Nginx 仍会因回源反代被安装
- `true`：生成订阅，建议同时指定 `nginx_pt`（订阅端口，不指定默认 8080）



### 7、 name（节点名称前缀）

- 不传 → 默认 hostname
- 传 → 节点名前加前缀

**例子：**
- name=HK
- ➡ HK-vmess / HK-vless


### 8、 DEBUG_FLAG 调试日志开关（默认 0）

- `0`（默认）→ 关闭调试输出
- `1` → 开启调试模式，脚本会把入口参数、解析结果、各命令目标等调试信息写入 `doraemon/debug.log`，排障时用

示例：
```bash
DEBUG_FLAG=1 \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```
<a id="mod-2"></a>
## ② 直连协议片段（VLESS-Reality + Hysteria2 + TUIC + AnyTLS + Socks5）

> 拼到基础命令上方（这段最后一行以 `\` 结尾，直接接基础命令的第一行变量即可）；删掉某个端口行（`vlrt / hypt / tupt / anypt / socks5pt`）= 不装对应协议；`socks5_*` 仅在启用 Socks5 时填。`out_ip` / `direct_host` 属基础命令（①），不写在这里。

```bash
vl_sni='www.apple.com' \
vl_sni_pt=443 \
vlrt=41003 \
reality_private='GHxxxxxxxxxxxxx-xxxxxx-VnXH6FjxxA' \
hy_sni='www.apple.com' \
hypt=41004 \
tu_sni='www.apple.com' \
tupt=41005 \
any_sni='www.apple.com' \
anypt=41006 \
socks5pt=41017 \
socks5_username='你的用户名' \
socks5_password='你的密码' \
socks5_wl_flag=true \
socks5_ips='1.2.3.4,5.6.7.0/24' \
```

> **直连片段变量说明（按协议归拢）：**
> - VLESS-Reality：`vl_sni` / `vl_sni_pt` / `vlrt` / `reality_private`
> - Hysteria2：`hy_sni` / `hypt`
> - TUIC：`tu_sni` / `tupt`
> - AnyTLS：`any_sni` / `anypt`
> - Socks5：`socks5pt` / `socks5_username` / `socks5_password` / `socks5_wl_flag` / `socks5_ips`
> - **删除某个端口行（`vlrt / hypt / tupt / anypt / socks5pt`）= 不装对应协议**
>
> 逐项详细说明：

### 1、 伪装 SNI 通用说明（hy_sni / vl_sni / tu_sni / any_sni）

各直连协议的伪装 SNI 一览（不会填就留空或删掉，脚本会用默认值）：

| 变量 | 协议 | 说明 | 缺省值 |
|------|------|------|--------|
| `hy_sni` | Hysteria2 | hy2 的伪装域名，可自定义 | `www.apple.com` |
| `vl_sni` | VLESS-Reality | vless 的伪装域名，可自定义 | `www.apple.com` |
| `vl_sni_pt` | VLESS-Reality | vless 伪装域名对应的握手端口，安装时绑定（https 系：443,2053,2083,2087,2096,8443 任选），不能在客户端乱改 | 443 |
| `tu_sni` | TUIC | tuic 的伪装域名，可自定义 | `www.apple.com` |
| `any_sni` | AnyTLS | anytls 的伪装域名，可自定义 | `www.apple.com` |

**SNI 最佳实践**（不要用会被恶意扫描当作无限流量转发端口的域名；不知道写什么就留空，脚本内置默认值）：
- ❌ Cloudflare 相关：`www.cloudflare.com`、`dash.cloudflare.com`
- ❌ CDN 服务：`www.akamai.com`、`www.fastly.com`
- ❌ 代理 / VPN 服务：任何代理服务的域名
- ❌ 你自己的服务器域名（会形成循环）
- ✅ 推荐：`www.apple.com`（默认）/ `www.yahoo.com` / `www.google.com` / 任何大型正常网站

### 2、 VLESS-Reality

- `vl_sni` / `vl_sni_pt`：伪装 SNI / SNI 端口（默认 443）
- `vlrt`：VLESS-Reality 端口
- `reality_private`：Reality 私钥。传它是为了安装/重装时 vless 节点保持一致，不用来回导入；不传自动生成，并在安装或重装完成时打印一次。忘记保存可重装，或 `sb list key` 再次打印；不要乱填，正确值应为 43 个字符。
- `reality_public`（可选）：Reality 节点对外暴露的公钥。一般不传——脚本会根据 `reality_private` 自动推导配套公钥；只有当你已经持有公钥并希望强制指定它时才需要传，传了 `reality_private` 时以私钥推导为准。

### 3、 Hysteria2 (hy2)

- `hy_sni`：伪装 SNI
- `hypt`：Hysteria2 端口

### 4、 TUIC

- `tu_sni`：伪装 SNI
- `tupt`：TUIC 端口

### 5、 AnyTLS

- `any_sni`：伪装 SNI
- `anypt`：AnyTLS 端口

<a id="socks5"></a>
### 6、 Socks5

- `socks5pt`：Socks5 端口，不传就不启用 socks5。`socks5_username` / `socks5_password` 不传则自动随机生成。
- ⚠️ 如果 `socks5_password` 含 `!`、`#`、`$` 等特殊字符，必须用单引号 `'...'` 包裹整个密码串。
- `socks5_wl_flag` / `socks5_ips`（IP 白名单，可选）：

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `socks5_wl_flag` | 白名单开关，`true`/`1`/`True`/`TRUE` 均可（大小写不敏感），空或其他值=关闭 | 空（关闭） |
| `socks5_ips` | 允许访问 Socks5 的源 IP 列表，逗号分隔，支持单个 IP 和 CIDR（如 `1.2.3.4,5.6.7.0/24`），IPv4/IPv6 均支持 | 空 |

  - 不传这两个参数 → Socks5 对所有 IP 开放（默认行为）；传 `socks5_wl_flag=true` 且 `socks5_ips` 非空 → 仅白名单中的 IP 可以连接。
  - **实现原理**：白名单开启时，iptables/ip6tables INPUT 链——白名单 IP ACCEPT（放行，标记 `socks5_rule`），其余 DROP（拦截，标记 `socks5_rule`）；其他协议端口 ACCEPT 标记 `doraemon_singbox_rule`。卸载/覆盖安装只清理本脚本规则，不影响其他程序。
  - 安装后可用交互菜单 →「Socks5 IP白名单管理」管理；节点输出里白名单状态显示在链接正下方：

```
🧦【 Socks5 】(此协议请不要直接在客户端里直连使用)
socks5://user:pass@ip:port#name
   ↳ 入站白名单已开启，仅允许: 1.2.3.4,5.6.7.0/24
```

### 7、 端口命名与端口行约定

- `hypt` / `vlrt` / `tupt` / `anypt` / `socks5pt`：分别对应 hy2 / vless-reality / tuic / anytls / socks5 的端口；`pt` 为 port 的简写，`rt` 为 reality port 的简写。
- ⚠️ vmess / trojan / vless 这三个协议的启用由 `argo` 决定（可多选，逗号分隔，如 `argo=vmess,vless`），其本地回源端口不接受指定（旧变量 `trpt` / `vmpt` / `vlpt` 已废弃），端口由脚本自动随机或复用落盘文件。
- **删除某个端口行（`vlrt / hypt / tupt / anypt / socks5pt`）= 不装对应协议**




### 组合示例
> 常见组合示例：整段可复制直接运行，删除某行即不启用对应功能。

### 组合 1：只装 1 个直连协议（`hypt` / `vlrt` / `tupt` / `anypt` 选一个）

#### 仅 hy2 协议

```bash
hypt=2082 \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

#### 仅 vless Reality 协议

```bash
vlrt=2083 \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

#### 仅 tuic 协议

```bash
tupt=2082 \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

#### 仅 anytls 协议

```bash
anypt=2082 \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

#### 仅 socks5 协议

```bash
# 密码含特殊字符(!#$等)必须用单引号包裹；socks5_wl_flag 可选：开启IP白名单；socks5_ips 可选：白名单IP，CIDR
socks5pt=31017 \
socks5_username='你的s5用户名' \
socks5_password='你的s5密码' \
socks5_wl_flag=true \
socks5_ips='1.2.3.4,5.6.7.0/24' \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

### 组合 2：装 2 个直连协议（同时写 `hypt` 和 `vlrt`）

```bash
hypt=2082 \
vlrt=2083 \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

<a id="mod-3"></a>
## ③ Argo 协议片段（VMess-WS-TLS / Trojan-WS-TLS / VLESS-WS-TLS 走 Cloudflare Tunnel）

> 拼到基础命令上方；不启用 Argo 就整段不贴；`argo` 支持多选：`'vmess'` / `'trojan'` / `'vless'`，逗号组合如 `'vmess,vless,trojan'`。

```bash
argo='vmess,vless,trojan' \
argo_cf_host='saas.sin.fan' \
argo_cf_pt=443 \
argo_pt=8001 \
agn='固定Argo隧道域名' \
agk='固定Argo隧道token' \
argo_vmess_cf_host='vm.example.com' \
argo_vmess_cf_pt=443 \
argo_vless_cf_host='vl.example.com' \
argo_vless_cf_pt=443 \
argo_trojan_cf_host='tr.example.com' \
argo_trojan_cf_pt=443 \
```

- 前 6 行三种 Argo 协议共用；后 6 行按协议覆盖共享的 `argo_cf_host` / `argo_cf_pt`，不写就用共享值。
- `agn` / `agk` 不填 = 临时 trycloudflare 隧道；`agk` 是 token 或 Auth JSON（`ey` 开头的那串是 token）。

下面逐项说明。

### 1、 argo_cf_host / argo_cf_pt（共享对外域名/端口）

- 三种 Argo 协议共用的对外域名和端口，默认 `saas.sin.fan` / `443`；端口只能选 https 系：443、2053、2083、2087、2096、8443。
- 也可以填自己的域名或优选 IP（如 `www.visa.com`）；不填就用默认值。

### 2、 每协议独立指定（可选，未填回退共享）

- `argo_vmess_cf_host` / `argo_vmess_cf_pt`、`argo_vless_cf_host` / `argo_vless_cf_pt`、`argo_trojan_cf_host` / `argo_trojan_cf_pt`

### 3、 兼容旧名

- `cdn_host` / `cdn_pt` 仍可用（`argo_cf_host` / `argo_cf_pt` 优先，旧名兜底），方便旧命令直接复用。
- 例如旧命令里的 `cdn_host` / `cdn_pt` 会被当作 `argo_cf_host` / `argo_cf_pt`：
```
trojan://00000000-0000-4000-8000-000000000001@cdns.doon.eu.org:8443?...
```

### 4、 argo（Cloudflare Argo 开关，可多选）

- `argo=vmess` 启用 VMess Argo；`argo=trojan` 启用 Trojan Argo；`argo=vless` 启用 VLESS Argo
- 可多选：`argo=vmess,vless`、`argo=vmess,trojan,vless` 等任意组合；留空或不传 → 不启用 Argo
- ⚠️ Argo 只能用于 VMess / Trojan / VLESS，支持多选，可与 ws_cdn 同时存在；对 `hypt / vlrt / tupt` 无效
- ⚠️ argo 值统一转小写后校验（接受任意 vmess / vless / trojan 组合）；旧值 `vmpt / trpt / vlpt` 已废弃；这三个协议的启用完全由 `argo=` 决定，本地回源端口不接受指定（自动随机/复用文件）

### 5、 argo_pt（Argo 本地回源端口）

- 本地监听端口默认 8001，一般不改。若你在 Cloudflare Tunnel 的 Public Hostname 里写死了 `http://localhost:8001`，改这里后要同步改。

<img width="1514" height="621" alt="CleanShot 2026-01-25 at 12 50 32" src="https://github.com/user-attachments/assets/ec1d2396-4832-4b1b-9da7-cbda4e9c56f1" />

### 6、 agn / agk（Argo 固定隧道）

- `agn='固定隧道域名'`、`agk='隧道 token 或 Auth JSON'`；不传 = 临时 trycloudflare 隧道（前提是 `argo` 已启用）。
- 只有你自己有 CF Tunnel 时才需要填。
- **JSON 写法**：JSON 本身含双引号，外面必须用**英文单引号**包住，例如 `agk='{"AccountTag":"...","TunnelID":"..."}'`；普通 token 用单引号或双引号都行。



#### 附：JSON 格式的 Argo Tunnel 怎么获取
- 在线生成：<https://fscarmen.cloudflare.now.cc>
- 图文说明：<https://github.com/fscarmen/sing-box/blob/main/README.md#5json-argo-tunnel-%E8%8E%B7%E5%8F%96-%E6%8E%A8%E8%8D%90>


### 组合 3：Argo 单协议（VMess / Trojan / VLESS 任选）

#### 使用 VMess Argo 时

```bash
ippz=4 \
argo=vmess \
agn='test-vmess.xxxx.xyz' \
agk='ey开头的那一串' \
name='小叮当-韩国春川vmess' \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

#### 使用 Trojan Argo 时

```bash
ippz=4 \
argo=trojan \
agn='test-trojan.xxxx.xyz' \
agk='ey开头的那一串' \
name='小叮当-韩国春川trojan' \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

#### 使用 VLESS Argo 时

```bash
ippz=4 \
argo=vless \
agn='test-vless.xxxx.xyz' \
agk='ey开头的那一串' \
name='小叮当-韩国春川vless' \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

### 组合 3（多选）：Argo 同时启用多个协议

```bash
ippz=4 \
argo=vmess,trojan \
argo_cf_host='saas.sin.fan' \
argo_cf_pt=443 \
agn='test-xxx.xxxx.xyz' \
agk='ey开头的那一串' \
name='小叮当-韩国春川' \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

> `argo_cf_host` / `argo_cf_pt` 是共享值（默认 `saas.sin.fan` / `443`）；每个协议也可以单独填 `argo_vmess_cf_host` / `argo_trojan_cf_host` 等覆盖。

### 组合 4：VMess(Argo) + Hysteria2 + VLESS-Reality

```bash
ippz=4 \
hypt=41001 \
vlrt=41002 \
argo=vmess \
agn='test-vmess.xxxx.xyz' \
agk='ey开头的那一串' \
name='小叮当-韩国春川' \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```


#### JSON token 场景（JSON 外层必须用英文单引号）

```bash
uuid=00000000-0000-4000-8000-000000000001 \
ippz=4 \
vlrt=41003 \
hypt=41004 \
tupt=41005 \
argo='trojan' \
agn='northCarolina.xxxx.xyz' \
agk='{"AccountTag":"xxxxxxxxxxxxxx","TunnelSecret":"xxxxxxxxxxxxxx","TunnelID":"xxxxxxxxxxxxxx","Endpoint":""}' \
name='小叮当-美国北卡' \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

<a id="mod-4"></a>
## ④ 回源协议片段（ws_cdn：vmess / vless / trojan 经自己的 CDN 反代回 nginx）

> 拼到基础命令上方；不启用回源就整段不贴（或删掉 `ws_cdn` 开头的行）；`ws_cdn` 支持多选（可与 Argo 共存）。订阅开关 `subscribe` / 订阅端口 `nginx_pt` 已放到「① 基础命令」里。

```bash
ws_cdn='vmess,vless,trojan' \
ws_cdn_cf_host='cdn.example.com' \
ws_cdn_sni='cdn.example.com' \
ws_cdn_cf_pt=443 \
```

下面逐项说明。

### 1、 ws_cdn（VMess / VLESS / Trojan WS 走 CDN 回源，不使用 Argo）

让 vmess / vless / trojan 的 WS 节点直接经过你自己的 **CDN / 反代** 转发到服务器 nginx（回源到服务器 `nginx_pt`，通常 8080），**不启用 cloudflared**。

```
客户端 --wss--> CDN(ws_cdn_cf_pt, 默认443) --http--> 服务器 nginx_pt --http--> sing-box ws 端口
```

- **开关**：`ws_cdn=vmess,vless,trojan`（逗号分隔，可多选）
- **域名支持每个协议不同**（适用于 Cloudflare origin rule 泛域名 + 多回源域名同 A 记录），优先级：`协议专属 > 共享 ws_cdn_* > 默认 saas.sin.fan/443`

| 变量 | 说明 | 默认 |
|------|------|------|
| `ws_cdn` | 开关：vmess/vless/trojan 逗号分隔 | 空（不启用） |
| `ws_cdn_vmess_cf_host` 等 | 各协议专属 CF 优选域名（连接地址 add） | 为空时回退共享 ws_cdn_cf_host |
| `ws_cdn_vmess_sni` 等 | 各协议专属回源域名（host/SNI） | 为空时回退共享 ws_cdn_sni |
| `ws_cdn_vmess_cf_pt` 等 | 各协议专属 CF 优选端口 | 为空时回退共享 ws_cdn_cf_pt |
| `ws_cdn_cf_host` | 共享 CF 优选域名（各协议**连接地址 add** 兜底；可填优选 IP/域名） | 为空时回退默认 saas.sin.fan |
| `ws_cdn_sni` | 共享回源域名（真实回源域名；作为节点 host/SNI 与**订阅地址**域名，Cloudflare 按此域名匹配回源规则转发到你的 nginx_pt） | 为空时回退该协议的 `ws_cdn_*_cf_host`（最终 `saas.sin.fan`；host 是 IP 时不回退） |
| `ws_cdn_cf_pt` | 共享 CDN 端口（仅限 https 系端口） | 443 |

### 2、 完整示例（共享 + 专属混合）

> vless 和 trojan 用不同的 CF 域名（同时作为回源 SNI），vmess 用共享：

```bash
ws_cdn='vmess,vless,trojan' \
ws_cdn_cf_host='cdn.example.com' \
ws_cdn_vless_cf_host='vless.example.com' \
ws_cdn_trojan_cf_host='trojan.example.com' \
subscribe=true \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) ins
```

### 3、 回源端口

CDN 回源到服务器 `nginx_pt`（默认 8080），去 Cloudflare 后台把 origin 指向该端口（或用 origin rule 泛域名回源）。

### 4、 订阅地址用哪个域名（自动判定）

按 ①→②→③→④→⑤ 顺序，取第一个可用的：

```
① 固定 Argo 隧道域名（非 trycloudflare，且隧道存活） → https://固定Argo域名/sub/{uuid}
 ↓ 没有固定 Argo 或隧道没活
② 共享回源域名 ws_cdn_sni → https://共享回源域名:端口/sub/{uuid}
 ↓ 没配
③ 专属回源域名（vmess → vless → trojan，取第一个非空） → https://专属回源域名:端口/sub/{uuid}
 ↓ 没配
④ 临时 Argo 域名（xxx.trycloudflare.com，隧道存活） → https://临时域名/sub/{uuid}
 ↓ 没有 Argo
⑤ http://服务器IP:nginx_pt/sub/{uuid}（明文，含节点口令，仅建议可信网络）
```

- **有固定 Argo 时，②③④ 都不用配**：订阅地址直接是 `https://固定Argo域名/sub/{uuid}`。
- 回源域名（②③）的作用：没有固定 Argo 时，让订阅走一个稳定的 https 域名，而不是明文 HTTP。

- **为什么任意一个回源域名都行**：回源域名在 Cloudflare 里按 Origin Rule/DNS 回源到**同一个 nginx 端口（nginx_pt，默认 8080）**，而 nginx 是 `server_name _`（不分 hostname、按路径干活）。所以 `vmess.example.com/sub/{uuid}`、`vless.example.com/sub/{uuid}`、`trojan.example.com/sub/{uuid}` **任何一个都能访问订阅**——用哪个都通。

**②③ 顺延到下一个非空举例**（假设均已启用 ws_cdn）：

| 你配置的回源域名 | 订阅 URL 用的域名 | 说明 |
|---|---|---|
| `ws_cdn_sni=cdn.example.com`，任意协议有专属 | `cdn.example.com` | **共享优先**（②），专属不用 |
| 共享空，`ws_cdn_vmess_sni=vm.example.com` 有值 | `vm.example.com` | ③ 固定顺序第一个非空 |
| 共享空，vmess 空，`ws_cdn_vless_sni=vl.example.com` 有值 | `vl.example.com` | **跳过空的 vmess，顺延到 vless** |
| 共享空，vmess/vless 都空，`ws_cdn_trojan_sni=tr.example.com` 有值 | `tr.example.com` | 顺延到 trojan |
| 共享 + 三个专属全空 | （无回源域名）→ 顺延 ④⑤ | 只有回源域名全空才会继续跌 |

> 参数里写几个、写哪个的顺序都无所谓：**只要回源域名有一个非空就够**，规则永远是「共享 ws_cdn_sni → vmess → vless → trojan，取第一个非空」；回源域名全部为空才继续走「④ 临时 Argo → ⑤ http」。

**与 Argo 并存**：可同时开 `ws_cdn` 和 `argo`，两者节点都输出（共用同一本地 ws 端口与 nginx 反代，仅客户端握手域名不同）。

<a id="cf-origin"></a>
### 5、 🌐 CF（Cloudflare）回源规则如何配置？（⚠️ 三步缺一不可）

> [!IMPORTANT]
> **三步缺一不可：① Origin Rules 改回源端口 → ② 加 DNS 记录 → ③ SSL 模式设「灵活」。**
> 最容易漏的是 ③：漏了只有 WS-CDN 节点全挂（525），Argo / 直连却正常。

| 步骤 | 做什么 | 漏了会怎样 |
|---|---|---|
| **①** | Origin Rules：`*node.你的域名` 的回源端口改成 `nginx_pt` | **521 / 522 / 523** |
| **②** | 给每个当 SNI 用的域名加 **A 记录** | **530（Origin DNS Error）** |
| **③** | node 子域 **SSL/TLS = 灵活（Flexible）** | **525（SSL Handshake Failed）** |

WS-CDN 回源链路：`客户端 → CDN(ws_cdn_cf_pt) → 服务器 nginx_pt(默认 8080)`。

#### 步骤 1：🟦 添加回源端口规则（Origin Rules）

进入 Cloudflare，点击具体域名（如 `xxxx.nyc.mn`）→ **规则** → **页面规则**，在页面右侧**流量序列**里找到 **Origin Rules · 更改目标源服务器**，点击它 → 点右上角**+ 创建规则**（蓝色按钮）→ 选中**源服务器规则**，进入 **Origin Rules**：

- 填写规则名称，如 `xxxx.nyc.mn-31007`
- 选中**自定义筛选表达式**：
  - **字段** 选 **主机名**
  - **运算符** 选 **通配符**
  - **值** 填 `*node.xxxx.nyc.mn`
- 然后下面的**目标端口** 重写到 **31007**（这个 31007 端口就是你的 **nginx 订阅端口 nginx_pt** 的值，按你实际配置的 `nginx_pt` 填写）

> 规则里的 `*node.xxxx.nyc.mn` 通配符能覆盖你实际用的三个回源域名：`vmess` / `vless` / `trojan`（这3个协议可以共用一个回源域名，也可以用三个不同的域名）。

#### 步骤 2：🟩 添加 DNS 记录

添加下面三条 **A 记录**，其中 `192.9.100.***` 为你的小鸡（服务器）的 IPv4：

```
vmess-node.xxxx.nyc.mn    →  192.9.100.***   （小黄云开不开都可以）
vless-node.xxxx.nyc.mn    →  192.9.100.***   （小黄云开不开都可以）
trojan-node.xxxx.nyc.mn   →  192.9.100.***   （小黄云开不开都可以）
```

- 可以每个协议一个 DNS 记录，也可以 3 个协议共用一个 DNS 记录，这个子域名记录指向**同一个 IPv4**（同一台服务器），配合上面的 Origin Rules 泛域名回源到 nginx_pt。
- `小黄云`（Cloudflare 橙色云代理）开或不开都可以——开=走 CDN+CDN TLS 终结，关=仅 CDN 反代一样能到 nginx。
- **⚠️ 当 SNI 用的回源域名必须有 DNS 记录**：节点里的 `sni/host` 取自 `ws_cdn_vmess_sni` / `ws_cdn_vless_sni` / `ws_cdn_trojan_sni`（没设专属就回退 `ws_cdn_sni`）。缺哪条记录，对应节点就报 **530（Origin DNS Error）**。

#### 步骤 3：🟥 SSL 加密模式必须设成「灵活（Flexible）」（否则回源必定 525）

> [!CAUTION]
> **这是最容易漏、漏了三个 CDN 节点全连不上的一步。**
> 现象：Argo / 直连都正常，只有 WS-CDN 节点不通 —— 先回来检查这里。

只要 A 记录开了**橙云（已代理）**，Cloudflare 会先替客户端终止 TLS，然后**再向源站发起一次连接**。第二次连接用什么协议，由这个域名（或子域）的 **SSL/TLS 加密模式** 决定：

| 加密模式 | 边缘 → 源站 nginx_pt 的连接 | 结果 |
|---|---|---|
| 完全 / 完全（严格）Full | 用 **TLS** 去连 nginx_pt，但 nginx 只有 HTTP | ❌ 握手失败 → **525** |
| **灵活（Flexible）** | 用 **明文 HTTP** 去连 nginx_pt | ✅ 通 |

**做法 A（推荐，只影响 node 子域，不动整站）：配置规则**

1. Cloudflare 后台 → 选域名 `xxxx.nyc.mn` → 左侧 **规则（Rules）** → 顶部页签选 **配置规则（Configuration Rules）**（⚠️ 不是**页面规则**，也不是上面用到的 **Origin Rules**）
2. 点 **创建规则**
   - **规则名称**：随便填，如 `node-回源-明文`
   - **表达式**（自定义筛选表达式）：字段选 **主机名**，运算符选 **通配符**，值填 `*node.xxxx.nyc.mn`
   - **然后（Then）操作**：选 **SSL**，值选 **灵活（Flexible）**
3. **保存 / 部署**

**做法 B（简单，整站生效）**：`域名 → SSL/TLS → 加密模式 → 灵活（Flexible）`。如果这个域名下还有别的服务，建议用做法 A，避免影响它们。

> 无论选哪种，**客户端 → Cloudflare 这段始终是 HTTPS**（节点链接不变），只是 Cloudflare → 你服务器这段变成明文 HTTP。如果你必须保持全链路加密（完全/完全严格），则需给服务器的 nginx_pt 配 TLS 证书（属于改脚本，工作量更大），否则只能设「灵活」。

#### 步骤 4：🔎 与脚本参数对应关系速查

| 你在哪填 | 对应的脚本变量 | 说明 |
|---|---|---|
| A 记录里的回源域名 | `ws_cdn_vmess_sni` / `ws_cdn_vless_sni` / `ws_cdn_trojan_sni`（也可同时填到对应的 `_cf_host`） | 既作为节点 SNI，也常作为客户端连接地址 |
| Origin Rules 的目标端口 | `nginx_pt`（默认 8080） | CDN 回源到服务器 nginx 的端口 |
| 客户端连 CDN 的端口 | `ws_cdn_cf_pt`（默认 443） | CDN 对外 HTTPS 端口 |
| 各协议/共享 SNI（真实域名） | `ws_cdn_vmess_sni` 等 / `ws_cdn_sni` | 对应上面 A 记录的某个回源域名 |
| CF 的 SSL/TLS 加密模式 | 无脚本变量（Cloudflare 后台） | node 子域必须「灵活」，否则回源 525 |

### 6、 排错：三个 CDN 节点连不上？先对号入座

> 典型现象：**Argo 节点、直连协议全部正常，唯独 3 个 WS-CDN 节点连不上**。按下面错误码一步步排除即可。

| 表现 | Cloudflare 错误码 | 原因 | 解决 |
|---|---|---|---|
| 🔴 vmess/vless/trojan-WS-CDN 全不通，Argo/直连正常 | **525** | 橙云记录 + SSL 模式「完全/完全严格」，Cloudflare 用 TLS 回源，而 nginx_pt 只讲 HTTP | 按上面**步骤 3** 把 node 子域 SSL 加密模式设成「灵活」 |
| 🟠 trojan-WS-CDN（或某个协议）单独不通 | **530**（Origin DNS Error） | 该协议当 SNI 用的回源域名（如 `trojan-cdn-node.xxxx.nyc.mn`）**没有 DNS 记录** | 在 DNS 里补一条 A/CNAME 记录，见**步骤 2** 警告 |
| 🟡 所有 WS / Argo 都不通 | 521 / 522 / 523 | nginx 没运行、回源端口被防火墙挡、Origin Rules 端口没对上 | 检查 `nginx` 状态、防火墙放行 nginx_pt、Origin Rules 目标端口是否正确 |



### 组合示例
> 常见组合示例：整段可复制直接运行，删除某行即不启用对应功能。

### 组合 5：WS-CDN 直连（不经 Argo，客户端经自己的 CDN 反代到服务器 nginx）

#### 三个协议用一个共享 CF 优选域名 + 共享回源域名

```bash
# ws_cdn_cf_host=共享 CF 优选域名（各协议连接地址 add 兜底）；ws_cdn_sni=共享回源域名（真实回源域名，也是订阅地址域名）
ws_cdn='vmess,vless,trojan' \
ws_cdn_cf_host='saas.sin.fan' \
ws_cdn_sni='cdn.example.com' \
subscribe=true \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

#### 每个协议不同专属域名（CF 优选域名 + 回源域名，Cloudflare origin rule 泛域名 + 多回源域名同 A 记录）

```bash
# 各协议可选不同专属 CF 优选域名（连接地址）与专属回源域名（Host/SNI）
ws_cdn='vmess,vless,trojan' \
ws_cdn_cf_host='saas.sin.fan' \
ws_cdn_sni='cdn.example.com' \
ws_cdn_vmess_cf_host='vm.example.com' \
ws_cdn_vmess_sni='vm-cdn.example.com' \
ws_cdn_vless_cf_host='vl.example.com' \
ws_cdn_vless_sni='vl-cdn.example.com' \
ws_cdn_trojan_cf_host='tr.example.com' \
ws_cdn_trojan_sni='tr-cdn.example.com' \
subscribe=true \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

> CDN 回源端口 = 服务器 nginx_pt（默认 8080）。可同时配固定 Argo 并存（两者节点都输出）；订阅地址有固定 Argo 则直接用固定 Argo，没有才用回源域名 ws_cdn_sni（或专属 ws_cdn_{p}_sni）。

> **完整命令 = ① 基础命令 + 任意组合的协议片段**（把选中的片段按顺序拼在基础命令上方，结尾只保留基础命令里的 `bash <(...) rep` 一行）。例如「直连 + 回源」：②直连片段 + ④回源片段 + ①基础命令 拼成一条；「只 Argo」就是 ③Argo 片段 + ①基础命令。




<a id="mod-5"></a>
## ⑤ Nginx 模块（Nginx 何时安装 · 反代路径一览）

### 1、 Nginx 何时安装（速查）

Nginx 只在以下任一情况满足时才安装/配置：

| 场景 | subscribe 订阅 | argo | 是否安装 Nginx |
|---|---|---|---|
| 纯直连（hy2/vless-reality/tuic/anytls/socks5） | 关 | 关 | ❌ 不安装 |
| 只开 Argo（argo=vmess/trojan/vless，可多选） | 关 | 开 | ✅ 安装（argo 回源走 Nginx 反代） |
| 只开订阅 | 开 | 关 | ✅ 安装（对外提供订阅地址） |
| Argo + 订阅都有 | 开 | 开 | ✅ 安装 |

> 即使不开启订阅，只要启用 Argo 就会安装 Nginx：因为 Argo 的数据链路是
> `cloudflared → 127.0.0.1:8001(Nginx) → sing-box 对应 ws 端口`，Nginx 负责按路径反代。

### 2、 Nginx 反代各协议路径一览

Nginx 的一份配置里同时监听 `nginx_pt`（默认 8080，对外）和 `127.0.0.1:argo_pt`（默认 8001，仅本机给 cloudflared 回源），`server_name _` 按路径分发到 sing-box 各协议本地端口：

| 场景 | Nginx location 路径 | 反代目标（sing-box 本地端口） | 说明 |
|---|---|---|---|
| VMess-WS（Argo 回源） | `/{uuid}-vm` | `http://127.0.0.1:{vm_port}` | `{vm_port}` = `port_vm_ws`；链路：cloudflared → 127.0.0.1:argo_pt → `/{uuid}-vm` |
| VLESS-WS（Argo 回源） | `/{uuid}-vl` | `http://127.0.0.1:{vl_port}` | `{vl_port}` = `port_vl_ws` |
| Trojan-WS（Argo 回源） | `/{uuid}-tr` | `http://127.0.0.1:{tr_port}` | `{tr_port}` = `port_tr` |
| VMess-WS（ws_cdn 回源） | `/{uuid}-vm-cdn` | `http://127.0.0.1:{cdn_vm_port}` | `{cdn_vm_port}` = `port_vmess_ws_cdn`；链路：CDN → nginx_pt → `/{uuid}-vm-cdn` |
| VLESS-WS（ws_cdn 回源） | `/{uuid}-vl-cdn` | `http://127.0.0.1:{cdn_vl_port}` | `{cdn_vl_port}` = `port_vless_ws_cdn` |
| Trojan-WS（ws_cdn 回源） | `/{uuid}-tr-cdn` | `http://127.0.0.1:{cdn_tr_port}` | `{cdn_tr_port}` = `port_trojan_ws_cdn` |
| 订阅输出 | `^~ /sub/{uuid}` | alias `/var/www/singbox/sub.txt` | subscribe=true 才生成；对外地址 `http://IP:nginx_pt/sub/{uuid}` |
| 其他所有路径 | `/` | 无（`return 404`） | 兜底，防端口扫描 |

> `{uuid}` 为安装时的 UUID；`port_vm_ws / port_vl_ws / port_tr` 为 Argo 各协议的本地 ws 端口，`port_vmess_ws_cdn / port_vless_ws_cdn / port_trojan_ws_cdn` 为 ws_cdn 独立回源端口（均由脚本自动随机或复用落盘文件，不对外公开）。
> 直连协议（VLESS-Reality / Hysteria2 / TUIC / AnyTLS / Socks5）**不走 Nginx**，客户端直接连各自端口 `vlrt / hypt / tupt / anypt / socks5pt`。


<a id="c2"></a>
# 2、 完整示例

<a id="full-example"></a>
## 2.1 聚合节点文件（所有已选协议都会输出到 jh.txt）

> 下面把基础命令 + 直连 + Socks5 + Argo + 回源写在一起，只作变量清单参考。**`out_ip`、`direct_host`、`agn`、`agk`、`reality_private` 是占位值，必须改成真实值或整行删掉**，否则会安装失败；不需要的行（连同行尾 `\`）直接删。

```bash
uuid=00000000-0000-4000-8000-000000000000 \
ippz=4 \
name='小叮当-美国加州' \
nginx_pt=41007 \
subscribe=true \
out_ip='特殊出口IP' \
direct_host='你的对外域名' \
DEBUG_FLAG=0 \
hy_sni='www.apple.com' \
vl_sni='www.apple.com' \
vl_sni_pt=443 \
tu_sni='www.apple.com' \
any_sni='www.apple.com' \
vlrt=41003 \
hypt=41004 \
tupt=41005 \
anypt=41006 \
reality_private='GHxxxxxxxxxxxxx-xxxxxx-VnXH6FjxxA' \
socks5pt=41017 \
socks5_username='zhangsan' \
socks5_password='Zsztm4gdsg!' \
socks5_wl_flag=true \
socks5_ips='1.2.3.4,5.6.7.0/24' \
argo='vmess,vless,trojan' \
argo_cf_host='saas.sin.fan' \
argo_cf_pt=443 \
argo_pt=8001 \
agn='固定Argo隧道域名' \
agk='固定Argo隧道token' \
argo_vmess_cf_host='vm.example.com' \
argo_vmess_cf_pt=443 \
argo_vless_cf_host='vl.example.com' \
argo_vless_cf_pt=443 \
argo_trojan_cf_host='tr.example.com' \
argo_trojan_cf_pt=443 \
ws_cdn='vmess,vless,trojan' \
ws_cdn_cf_host='cdn.example.com' \
ws_cdn_sni='cdn.example.com' \
ws_cdn_cf_pt=443 \
ws_cdn_vmess_cf_host='vm-cdn.example.com' \
ws_cdn_vmess_sni='vm-cdn.example.com' \
ws_cdn_vmess_cf_pt=443 \
ws_cdn_vless_cf_host='vl-cdn.example.com' \
ws_cdn_vless_sni='vl-cdn.example.com' \
ws_cdn_vless_cf_pt=443 \
ws_cdn_trojan_cf_host='tr-cdn.example.com' \
ws_cdn_trojan_sni='tr-cdn.example.com' \
ws_cdn_trojan_cf_pt=443 \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```





<a id="uninstall"></a>
## 2.2 如何卸载
```bash
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) delall
```

> `delall`：与 `del` 效果类似，但会 **完全删除** sing-box 文件夹（不保留二进制文件 / 配置），相当于彻底卸载。




### 3、 沙箱 Nginx 的服务托管与自启

沙箱 Nginx 装在 `$SINGBOX_FOLDER_PATH/nginx`（默认 `/root/doraemon/nginx`），用 jirutka 的静态二进制，**不碰系统的 `nginx` 包，也不写 `/etc/nginx`**。它与系统 Nginx 可以同时存在、各管各的端口。

自 v3.2.24 起，沙箱 Nginx 交给系统的服务管理器托管，不再靠 cron 看门狗兜底：

| 项目 | systemd | openrc |
|---|---|---|
| 服务名 | `sb-nginx.service` | `/etc/init.d/sb-nginx` |
| 开机自启 | `systemctl is-enabled sb-nginx` | `rc-update show default \| grep sb-nginx` |
| 进程类型 | `Type=forking` + `PIDFile` | `supervise-daemon`（无则 `command_background`） |
| 被杀自动拉起 | `Restart=always`，`RestartSec=10s` | `respawn_delay=10` |
| 熔断 | `StartLimitBurst=5` / `StartLimitIntervalSec=300` | `respawn_max=5` / `respawn_period=300` |

几点设计取舍：

- **服务名固定 `sb-nginx`**，永远不与系统的 `nginx.service` 撞名，`cleanup_nginx` 卸载时也只删这一个文件
- **`Restart=always` 带熔断而非无限重启**：Nginx 的故障（端口被占、配置写错）多是持久性的，无限重启只会把 `error.log` 刷爆；连续 5 次失败后停在 `failed` 等人工介入，在菜单里手动启动时会先 `reset-failed` 复位
- **人工停止不会被自动拉回**：`systemctl stop sb-nginx` / `sb nginx_stop` 之后服务保持 `inactive`，这是 systemd 的正常语义，`Restart=always` 只针对异常退出
- **看门狗避让**：出现了 unit 之后，cron 那个每 2 分钟的 `singbox-watchdog.sh` 会跳过 Nginx 分支，避免两边同时拉起撞端口
- **单元文件带 `# unit-rev: 2` 标记**：老版本装过的机器再跑一次脚本会自动重写 unit，不需要手工删

常用操作：

```bash
sb nginx_status     查看 Nginx 状态
sb nginx_start      启动（等价 systemctl start sb-nginx）
sb nginx_stop       停止（不会被 Restart=always 拉回）
sb nginx_restart    重启
```

实测（Debian 13）：`kill -9` master 后第 11 秒自动拉起；`systemctl stop` 后不再复活；整机 `reboot` 后随系统自启，`NRestarts=0` 一次起成功。


## 2.3 协议组合速查

| 你设置了什么 | 实际生成的节点 |
|---|---|
| 单个直连（`hypt` / `vlrt` / `tupt` / `anypt` / `socks5pt`） | 1 |
| 多个直连 | 直连协议数 |
| `argo=vmess,trojan` 等 | 选中的 Argo 协议数（1~3） |
| `ws_cdn=vmess,vless` 等 | 选中的 CDN 回源协议数（1~3） |
| 直连 + Argo + ws_cdn 混用 | 三者相加（互不冲突） |
| 例：`hypt` + `vlrt` + `argo=vmess,vless` + `ws_cdn=vmess` | 5（2 直连 + 2 Argo + 1 CDN） |
| 例：`argo=vmess` + `ws_cdn=vmess` | 2（同一协议可同时走 Argo 和 CDN） |

## 2.4 日志查看

sing-box 和 cloudflared 启动失败时，可以通过下面命令定位问题。

> 以下 `doraemon` 为默认安装目录，若安装时改了 `sb_dir`，请替换成实际目录。

### 快捷命令（推荐）

```bash
sb logs              打开日志菜单（Sing-box / Argo / Nginx / 安装日志）
sb log_sb 100        查看 Sing-box 运行日志（最近100行）
sb log_argo 100      查看 Argo 隧道日志（最近100行）
sb log_ins           查看最近一次安装日志（全文）
sb log_stop          查看服务停止原因日志（排查崩溃用）
```

### 手动查看

```bash
# 实时查看 sing-box 运行日志（通用所有模式）
tail -f /root/doraemon/logs/singbox.log

# 查看最新 200 行
tail -200 /root/doraemon/logs/singbox.log

# 实时查看 cloudflared 运行日志（nohup / 临时隧道模式）
tail -f /root/doraemon/logs/argo.log

# 查看最新 200 行
tail -200 /root/doraemon/logs/argo.log
```


## 2.5 防火墙规则排查（Debian/Ubuntu/Alpine 通用）

### 查看本脚本的规则

脚本通过 `--comment` 标记所有规则，有两种标记：

| 标记 | 说明 |
|------|------|
| `doraemon_singbox_rule` | 所有协议端口的 ACCEPT 规则（vmess/trojan/vless/socks5） |
| `socks5_rule` | Socks5 白名单专用（ACCEPT 放行 + DROP 拦截） |

**IPv4：**
```bash
# 查看所有脚本规则
iptables -S | grep -E "socks5_rule|doraemon_singbox_rule"

# 查看完整规则链（含包数/字节数）
iptables -L INPUT -n -v --line-numbers | grep -E "socks5_rule|doraemon_singbox_rule"

# 只看 socks5 白名单规则
iptables -S | grep socks5_rule
```

**IPv6：**
```bash
ip6tables -S | grep -E "socks5_rule|doraemon_singbox_rule"
ip6tables -L INPUT -n -v --line-numbers | grep -E "socks5_rule|doraemon_singbox_rule"
```

### 规则正常状态对照

- **未开启白名单时**：所有端口只有 `doraemon_singbox_rule` 标记的 ACCEPT 规则
  - TCP 协议（vmess/trojan/vless/anytls/socks5）→ TCP 规则
  - UDP 协议（hy2/tuic）→ UDP 规则
- **开启白名单后**：
  - `doraemon_singbox_rule`：其他协议端口的 ACCEPT 规则（不含 socks5 端口）
  - `socks5_rule`：socks5 端口的 ACCEPT 规则（每个白名单 IP 一条 TCP）+ 一条 DROP 默认规则（TCP）

### 持久化规则检查

重启后规则会由 systemd/OpenRC 自动恢复。检查持久化文件：

```bash
# Debian/Ubuntu
cat /etc/iptables/rules.v4
cat /etc/iptables/rules.v6

# Alpine（同路径）
cat /etc/iptables/rules.v4
cat /etc/iptables/rules.v6
```

### 白名单状态检查

```bash
# 查看白名单开关
cat /root/doraemon/socks5_wl_flag

# 查看白名单 IP 列表
cat /root/doraemon/socks5_ips

# 查看 socks5 端口
cat /root/doraemon/port_socks5
```


## 2.6 sb 快捷指令

安装后会在系统创建 `sb` 快捷命令，常用指令如下：

```
sb                 打开主菜单
sb ins             安装节点
sb rep             覆盖式安装/重置
sb list            查看节点信息
sb list key        查看节点 + vless Reality 私钥
sb res             重启 sing-box 和 cloudflared
sb rt              分流管理
sb node            节点配置修改 (端口/订阅/SNI/Argo/身份信息/服务器地址)
sb sub             订阅管理
sb report          上报节点到 sub-merge（自动上报层）
sb report status   查看上报状态（开关 / 最近一次时间与结果 / 地址 / 凭证）
sb report on|off   开/关自动上报
sb rstatus         同 sb report status
sb del             卸载（保留二进制）
sb delall          卸载全部并清理
sb ups             更新 sing-box 内核
sb opt             系统优化（按系统自动选 Alpine/Debian/Ubuntu 后端，默认不改 SSH）
sb opt upgrade     优化 + 升级系统包（apk / apt）
sb opt menu        打开系统优化子菜单（等价主菜单 [14]）
sb sc              创建/刷新本快捷命令
sb sc_off          删除本快捷命令
sb autostart       开启开机自启
sb autostart_off   关闭开机自启
sb nginx_start     启动 Nginx
sb nginx_stop      停止 Nginx
sb nginx_restart   重启 Nginx
sb nginx_status    查看 Nginx 状态
sb logs            查看日志菜单（Sing-box/Argo/Nginx/安装日志）
sb log_sb 100      查看 Sing-box 运行日志（最近100行）
sb log_argo 100    查看 Argo 隧道日志（最近100行）
sb log_ins         查看最近一次安装日志（全文）
sb log_stop        查看服务停止原因日志（排查崩溃用）
```

## 2.6.1 上报节点到 sub-merge（v3.2.29 新增）

把本机 `jh.txt` 里的全部节点链接上报到自己的订阅聚合服务（sub-merge），服务端存成这台机器的「自动上报」层，立刻进入合并订阅；本机的手动层不受影响。`sb.sh` 与 `sb00.sh` 两份脚本都已支持（除 `SB_SCRIPT_NAME` 外保持一致）。

**默认不上报**。两种用法：

```
sb report           # 手动上报一次（配置已存在时一条命令搞定）
sb                  # 主菜单 → [13] 上报到 sub-merge（配置/预览/上报/自动开关）
```

自动上报由 `REPORT_FLAG` 控制，只有等于 `1` 才在每次生成节点后推送：

```bash
# 装完顺手带上三件套，一次配好（值会落盘，下次不用再带）
REPORT_FLAG=1 \
REPORT_BASE=https://你的-sub-merge-域名 \
REPORT_TOKEN=<上报凭证> \
bash <(curl -Ls ...)    # 或 sb report 里手工配置
```

- `REPORT_BASE` **没有默认值**：每个人的 sub-merge 域名都不一样，必须自己填；没填时上报会直接跳过并提示（不会偷偷发到别人的域名）
- 机器名取值优先级：`REPORT_MACHINE`（界面会下发，值就是 ④ 的 `name`）> 配置文件里的 `SUBMERGE_MACHINE` > `/root/doraemon/name`（安装时填的节点名前缀）> 服务器 hostname。也就是**只有 `REPORT_MACHINE` 没传或为空时，才回落到 `name`**
- 来源默认留空即可（服务端本来就把空来源记成 `default`），只有同一台机器要分多份数据时才需要填
- `REPORT_FLAG` 未设置或为 `0` → 生成节点后什么都不做（默认行为）
- `REPORT_FLAG=1` → 每次 `sb ins / rep / sub` 生成节点后自动推送一次；失败只在末尾黄字提示，不影响节点生成
- 也可以不设环境变量，进 `sb report` 子菜单选 `2) 打开自动上报`，开关写在配置文件里
- 每次上报（手动 / 自动）都会把结果记到 `/root/doraemon/submerge.state`，用 `sb report status` 或子菜单 `1)` 随时查

#### 一份可直接抄的完整写法（四个变量 + 逐行含义）

```bash
REPORT_FLAG='1' \
REPORT_BASE='sub.******.de5.net' \
REPORT_TOKEN='6a4a254255397ced700008cc9fd7df958035be1df0000ad' \
REPORT_EXCLUDE='socks5' \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```

| 变量 | 含义 |
| --- | --- |
| `REPORT_FLAG='1'` | **自动上报总开关**，`1`=开、`0`/不传=关（默认）。开启后每次 `sb ins` / `sb rep` / `sb sub` 生成完节点都会自动往 sub-merge 推一次；推送失败只在末尾黄字提示，不影响节点生成。 |
| `REPORT_BASE='sub.******.de5.net'` | **你自己的 sub-merge 域名**（不是 sing-box 节点域名，是那个聚合订阅站）。脚本里没有任何默认值，不填就跳过上报。**写不写 `https://` 都行**：脚本会先规范化再落盘——去首尾空白与结尾斜杠；**什么都没写协议**时自动补 `https://`；**自己写了 `http://` 就照原样用，不强行升级**（自建反代、内网 http 环境能跑；但 Cloudflare Workers 上的 sub-merge 只认 https，写 `http://` 会被 301 拒掉，脚本不会替你改，需自己写对）。之所以要补：上报固定用 `curl -sS -m 20 -X POST`，没带 `-L`（`-L` 会把 POST 降级成 GET），裸域名会被 curl 当 `http://` 发、服务端 301 跳到 https 后脚本只拿到 301，就判 `❌ 上报失败（HTTP 301）` 了。 |
| `REPORT_TOKEN='6a4a…0000ad'` | **上报凭证**，取 sub-merge 里给你的 `REPORT_TOKEN`。注意：**别用主订阅 token**，那个调上报接口会返回 401。凭证会以 600 权限落盘到 `/root/doraemon/submerge.conf`，之后 `sb report status` 只显示打码后的前几位。 |
| `REPORT_EXCLUDE='socks5'` | **不参与上报的节点类型**，英文逗号分隔。**不填 = 不拦截任何协议，全部上报**（脚本不做任何默认排除；但**界面生成命令时会默认勾上 Socks5**，据此显式下发 `REPORT_EXCLUDE='socks5'`——过滤范围以界面勾选为准，手工跑脚本不传就完全不过滤）。上面示例写 `socks5` 只是拿它举例——多数客户端不吃 socks5 节点，混在订阅里会刷客户端报错，你可以按需勾掉。可选值：`vless` `vmess` `trojan` `hysteria2`（可写 `hy2`/`hy`/`hysteria`）`tuic` `anytls` `socks5`，以及按脚本生成形态细分的 `vless-reality` `vless-argo` `vless-cdn` `vmess-argo` `vmess-cdn` `trojan-argo` `trojan-cdn`；写 `vless` 等于把三种 vless 一起排掉。要恢复「全部上报」：不传这个变量、或在 `sb report` 菜单里把排除项清空，都行——传空字符串 `` 也行，脚本按「没填」处理。 |

几点补充：

- 四个值都建议用单引号包起来：token 里若出现 `#` `?` `&` 之类字符才不会被 shell 提前截断。注意空串 `REPORT_XXX=''` 等于「没传」——脚本用 `-n` 判空，空值不会写进配置文件（正因如此，想清空排除项才要用 `-` 占位，见上）。
- 这条命令只跑一次即可：`REPORT_*` 只要非空就会写进 `/root/doraemon/submerge.conf`（root:root、600），下次直接 `sb rep` 不用再带；要改就再带一次新值，或进 `sb report` 子菜单选 `3)`。
- 顺序无关、也不要求和 `bash <(...)` 写在同一行（`\` 续行只是便于阅读）；但用 `sudo` 执行时环境变量会被 sudo 丢掉，所以直接在 root 下跑，或写成 `sudo REPORT_FLAG=1 … bash <(...)`。

子菜单：

```
1) 查看上报状态（开关 / 最近一次时间与结果 / 地址 / 凭证）
2) 立即上报当前节点
3) 修改上报配置（地址 / 凭证 / 机器名 / 来源）
4) 查看上报配置（凭证打码 + 自动上报开关状态）
5) 上传前预览（节点条数 / base64 长度 / 目标地址）
6) 切换自动上报开关（开 / 关，写进配置文件）
7) 清除上报配置（连状态记录一起清）
```

### 上报状态查询（v3.2.31 新增）

上报结果会落盘，装完/覆盖装/改配置触发的自动上报同样记录：

```bash
sb report status     # 或 sb rstatus，或主菜单 [13] → 1)
```

输出示例：

```
========= 上报状态 =========
  自动上报：已开启（1）
    开关来源：/root/doraemon/submerge.conf 里的 SUBMERGE_AUTO
  上报地址：https://sub.你的域名/api/v1/report/小叮当-淡-美国北卡莱罗纳
  上报凭证：6a4a25****44ad
  机器名　：hk-1    来源：airportA

  最近一次：2026-11-02 18:53:55  成功 (HTTP 200)
    结果：内容已更新，节点 6 条（自动 6 + 手动 0）
    节点：6 条
    目标：https://sub.你的域名/api/v1/report/小叮当-淡-美国北卡莱罗纳
  最近成功：2026-11-02 18:53:55
  状态文件：/root/doraemon/submerge.state
  配置文件：/root/doraemon/submerge.conf
```

- 开关：显示开/关与取值来源（环境变量 `REPORT_FLAG` 优先于配置文件）
- 地址：完整上报路径（含 `?source=`，可直接复制给别的机器用）
- 凭证：打码显示（前 6 位 + 后 4 位）
- 最近一次：时间 + 成功/失败 + HTTP 码 + 结果说明 + 节点数；另存「最近成功」时间，失败不会覆盖它
- 状态文件 `/root/doraemon/submerge.state`（root:root、600，脚本每次写入后重新 `chmod 600`），键：`LAST_TIME` `LAST_RESULT` `LAST_HTTP` `LAST_MSG` `LAST_NODES` `LAST_MACHINE` `LAST_SOURCE` `LAST_URL` `LAST_OK_TIME`
- 自动上报也会记录：`sb ins` / `sb rep` / `sb sub` / 配置修改后只要开关是开的，都会写一条结果

配置落盘在 `/root/doraemon/submerge.conf`（属主 root、权限 600，只有 root 能读；含上报凭证，别外传。换凭证、打开/关闭上报、改地址都会重写这个文件，脚本每次写完都会重新 `chmod 600`，不会因为 umask 变松）：

```
SUBMERGE_BASE=https://你的-sub-merge-域名   # 必填，没有默认值
SUBMERGE_TOKEN=<上报凭证 REPORT_TOKEN>      # 必填，只认 REPORT_TOKEN
SUBMERGE_MACHINE=小叮当-淡-美国北卡莱罗纳    # 可不填：默认取全局配置里的 name
SUBMERGE_SOURCE=                            # 可不填：留空即 default，多来源时才填
SUBMERGE_AUTO=0                  # 自动上报开关：0 关（默认）/ 1 开
```

环境变量与会自动落盘的对应关系（给过值就写进上面这个文件，之后不带环境变量也生效）：

| 环境变量 | 落盘键 | 说明 |
| --- | --- | --- |
| `REPORT_FLAG` | `SUBMERGE_AUTO` | `1` 才自动上报，默认 `0` |
| `REPORT_BASE` | `SUBMERGE_BASE` | 你自己的 sub-merge 域名（必填，无默认值；`https://` 可省略，脚本自动补） |
| `REPORT_TOKEN` | `SUBMERGE_TOKEN` | 上报凭证（只认 `REPORT_TOKEN`，主 token 会 401） |
| `REPORT_MACHINE` | `SUBMERGE_MACHINE` | 机器名；界面会把 ④ 的 `name` 作为它下发。不传/为空才回落到 `name`，再退到 hostname |
| `REPORT_EXCLUDE` | `SUBMERGE_EXCLUDE` | 不上报的协议（**脚本不填 = 不过滤，全部上报**；界面默认勾选 Socks5 并显式下发），英文逗号分隔；可选 `hysteria2 tuic anytls socks5 vless-reality vless-argo vmess-argo trojan-argo vless-cdn vmess-cdn trojan-cdn`（也接受 `vless`/`trojan` 这类前缀，等于把该协议所有形态一起排掉），空=全部上报 |
| `REPORT_SOURCE` | `SUBMERGE_SOURCE` | 来源名，默认 `default` |
| `REPORT_CLEAR` | — | `1` 时先把 `submerge.conf` 清空回默认（地址/凭证/机器名/来源清空、排除项回 `socks5`、自动上报关），再走上面的覆盖逻辑。要「清掉」就用它，不要靠传空字符串。**别把它写进常驻环境变量**（如 workflow 的 `env:`）——那样每次运行都会先清一次，配置存不住；它在一次进程内只生效一次 |

优先级：环境变量 > 配置文件 > 默认值（给过值就写回 `submerge.conf`，所以不会出现「传了新的却被旧值压住」）。

有两件事靠「传空字符串」表达不了，需要单独说：

- **清空**：`REPORT_TOKEN=""` 和完全不传 `REPORT_TOKEN`，在 `[ -n "${REPORT_TOKEN:-}" ]` 判断下无法区分；而 CI 里 `secrets.REPORT_TOKEN` 没配就是空串，拿空串表达「我要清掉」会误伤别人的工作流。所以清空走 `REPORT_CLEAR=1`：`REPORT_CLEAR=1 bash <(curl -Ls ...) rep`。同一个命令里带 `REPORT_*` 会先清后填
- **卸载不删这个文件**：`sb del` 的白名单里有 `submerge.conf`（连同 `sing-box`/`cloudflared`/`logs`/`nginx` 一起保留），原因是 `SUBMERGE_TOKEN` 只能去 sub-merge 后台重新创建，重装时最难恢复的就是它。`submerge.state`（上次上报时间等）仍然删除，避免重装后显示陈旧记录。要彻底清干净用 `sb delall`（删整个目录），或者在子菜单 `3) 修改配置` 的地址处填 `-`、跑一次 `REPORT_CLEAR=1`

- **凭证**：只认 sub-merge 的 `REPORT_TOKEN`，主订阅 token 上报会被 401 拒绝（订阅链接泄露也写不了数据）
- **内容**：脚本自动把 `jh.txt` 整段 base64 后 POST，不用手工编码；`jh.txt` 不存在时会先按当前配置重新生成
- **幂等**：内容没变化时服务端返回 `changed:false` 且不重复写库，脚本会明确提示「内容与上次一致」
- **机器名支持中文**：内部按百分号编码，`小叮当-淡-美国北卡莱罗纳` 这类名字照填
- **失败提示**：401 凭证错、400 机器名/内容不合规、413 超过 512KB、连不上域名，都会给对应的中文提示

## 2.7 版本变更信息

v3.2.76 (2026-11-09)
 > 系统优化子菜单按实际使用收成两项：`[1]` 立即优化（默认，不改 SSH 登录策略）、`[2]` 优化 + 升级系统包（apk / apt），另 `[0]` 返回。演练与「允许改 SSH」从菜单与快捷指令里撤掉（`sb opt dry` / `sb opt ssh` 仍可用，只是不再对外列出）。

v3.2.75 (2026-11-09)
 > 系统优化从「一行直达命令」补成「有子菜单」：主菜单 [14] 进去可选 立即优化 / 演练 / 优化+升级包 / 允许改 SSH。

- 新增 `os_tune_menu()`：主菜单 `[14] 系统优化 (opt)` 不再直接开跑，而是进子菜单（1 立即优化、2 演练、3 优化+升级、4 优化并改 SSH，0 返回）
- 新增快捷指令 `sb opt menu`（等价主菜单 [14]）；原有 `sb opt` / `sb opt dry` / `sb opt upgrade` / `sb opt ssh` 行为完全不变
- 选 4（改 SSH）前多一道 `y/N` 确认，避免误放密码登录
- 非 Alpine/Debian/Ubuntu 系统进入子菜单时直接提示不在支持范围
- 同步：`singbox-tools-interface` 的「sb 快捷指令速查」表补上这 5 条

v3.2.74 (2026-11-09)
 > 修 3.2.73 的下载顺序：raw 直链的 CDN 会长期留旧副本，`?ts=` 也压不住，导致「下到的是旧版 vps-tune」。

- 实测：`https://raw.githubusercontent.com/jyucoeng/vps-tune/main/vps-tune.sh?ts=…` 在 Debian 12 上拿到的仍是 v1.0.0（md5 不符），而文件语法合法，`bash -n` 校验一样通过 → 被当成「下载成功」，静默用旧逻辑跑
- 修法：`os_tune_fetch()` 改成 **GitHub API `contents` 优先**（`Accept: application/vnd.github.raw`，不吃这层 CDN 缓存），API 失败（限流 / 403）再回落 raw 直链；仍是 `grep vps-tune` + `bash -n` 双重校验后才落盘
- 同步：`vps-tune` 自身的后端下载（`tune-alpine.sh` / `tune-debian.sh`）也改成 API 优先（vps-tune v1.0.2），并修掉下载进度写 stdout 污染 `$(resolve_backend)` 的 bug（v1.0.3）

v3.2.73 (2026-11-09)
 > 系统优化从「只管 Alpine」扩到「按系统自动选」：外链换成新仓库 jyucoeng/vps-tune，Debian / Ubuntu 也自动吃上 sysctl / BBR / journald / limits 调优。

- 新仓库 [jyucoeng/vps-tune](https://github.com/jyucoeng/vps-tune)（v1.0.0）把两个脚本合成一个入口：`vps-tune.sh` 识别 Alpine / Debian / Ubuntu → `tune-alpine.sh`（原 alpine-onekey v2.1）/ `tune-debian.sh`（原 ovz-tune v1.1.0）
- sb 侧改名：`ALPINE_OPT_URL/FILE/ARGS/ON_INSTALL` → `OS_TUNE_URL` / `OS_TUNE_API` / `OS_TUNE_FILE`（`$SINGBOX_FOLDER_PATH/vps-tune.sh`）/ `OS_TUNE_ARGS` / `OS_TUNE_ON_INSTALL`；`is_alpine` + `alpine_optimize` → `is_tunable_os` + `os_tune`。旧变量 `ALPINE_OPT_ARGS` / `ALPINE_OPT_ON_INSTALL` 仍作为默认值兼容
- `is_tunable_os()` 同时认 `/etc/alpine-release` 与 `/etc/os-release` 的 `ID`/`ID_LIKE`（debian / ubuntu 系），非这三家直接跳过
- 下载仍是两条路：raw 直链（带 `?ts=` 绕 CDN）→ 失败换 GitHub API `contents`（`Accept: application/vnd.github.raw`）→ 再回落本地缓存；落盘前 `grep vps-tune` + `bash -n` 双重校验，HTML 错误页会被拒
- 语义变化：`os_tune run` 传 `--apply`、`os_tune dry-run` 传 `--dry-run`（vps-tune 默认演练，与旧脚本默认执行相反）；`--ssh` 仍需显式给，默认不碰 sshd
- 菜单 [14] 与 `sb opt` 文案改成「系统优化」，Debian / Ubuntu 机器上也会出现该项；`sb opt upgrade` 在两个系统上都是包升级（apk / apt）
- 兼容：`sb opt` / `opt dry` / `opt upgrade` / `opt ssh` 四个子命令行为不变

v3.2.72 (2026-11-09)
 > openrc `sb-nginx` 第三次修正：`status` 仍报 stopped，且 `stop` 会把 start-stop-daemon 打崩。

- 实测本机 `start-stop-daemon`（openrc 0.62.6）两个坑：
  - 不支持 `--remove-pidfile` → `unrecognized option` + 打印 usage
  - `--test --stop --retry 10` 同用会 **Segmentation fault**
  3.2.71 的 `stop()` 两个都用了，所以 `rc-service sb-nginx restart` 输出一堆 usage + `Segmentation fault`
- openrc 的 `rc-service X status` 不走我们覆盖的 `started()`，仍报 `stopped`；`status()` 也要显式覆盖
- 3.2.72 定稿（`unit-rev: 5`）：`started()` 先看 pidfile 是否存在再 `--test --stop --quiet`；`status()` 直接 `echo "status: started|stopped"` 并返回 0/3；`start()` 已有则幂等返回 0、否则先删残留 pidfile 再 `eval set -- $command_args` 启动；`stop()` 只发 SIGTERM（不带 --retry/--remove-pidfile）+ `rm -f` pidfile；`reload()` 按 pidfile 发 HUP

v3.2.71 (2026-11-09)
 > 补齐 3.2.70 的尾巴：openrc 下 `sb-nginx` 的 `status` / `stop` / `start` 仍然认不出 nginx。

- 3.2.70 去掉 `supervise-daemon` 后，openrc 自带的 `started()` 认不出「命令已 fork 退出、进程还在」的守护进程，于是出现三连：
  - `rc-service sb-nginx status` → `stopped`（实际在跑）
  - `rc-service sb-nginx stop` → `WARNING: sb-nginx is already stopped`（停不掉真正的 master）
  - `rc-service sb-nginx start` → `start-stop-daemon: nginx is already running` → `Failed to start`
  实测 `start-stop-daemon --test --stop --pidfile … --exec …` 返回 0（判定为在跑），说明只有 openrc 的判定逻辑不对
- 修法：`/etc/init.d/sb-nginx` 里显式覆盖 `started()` / `start()` / `stop()`，全部改用 `start-stop-daemon --pidfile … --exec …` 判定与发信号；`reload()` 同样按 pidfile 发 HUP。`start()` 遇到已在跑直接返回 0（幂等）
- 模板标记 `unit-rev: 3` → `unit-rev: 4`，老机器下次 `ins`/`rep`/`sb nginx_start` 自动重写
- Alpine 官方 `main/nginx/nginx.initd` 也是「只给 command + pidfile」的思路，但它的 stop 依赖 openrc 默认 `started()`；我们的脚本里 nginx 是带 `-p` 的独立沙箱实例，故显式覆盖

v3.2.70 (2026-11-09)
 > 修 Alpine(openrc) 下 `sb-nginx` 服务永远显示 `stopped`、nginx error.log 被 `bind() ... failed (98: Address in use)` 刷屏的问题。

- 根因：openrc 模板给 nginx 挂了 `supervisor="supervise-daemon"`，但 nginx.conf 里是 `daemon on;`——nginx 父进程 fork 完立刻退出，supervise-daemon 认为它崩了，每 10 秒重拉一次（`respawn_max=5`），每次重拉都撞上已被真 master 占着的 `31007`/`8001`，于是
  `[emerg] bind() to [::]:31007 failed (98: Address in use)` × 5 之后放弃。最终：`rc-service sb-nginx status` = **stopped**（实际上在跑）、error.log 每次安装多 15 行垃圾、`rc-service sb-nginx stop` 停不掉真正的 master
- 复现：Alpine 3.22 + 122MB 小机，装着 `sb-nginx` 的机器 `grep -c 'Address in use' /root/doraemon/nginx/logs/error.log` 每次 `ins`/`rep` 都会 +15
- 修法：openrc 模板改成 Alpine 官方 `main/nginx/nginx.initd` 的做法——**只给 `command` + `pidfile`，不挂 supervisor、不设 command_background**，由 nginx 自己写 pid 文件，openrc 用 pidfile 判定 start/stop/status；顺带补 `reload()`（`start-stop-daemon --signal HUP`）
- 模板标记 `unit-rev: 2` → `unit-rev: 3`，老机器下次 `ins`/`rep`/`sb nginx_start` 会自动重写 `/etc/init.d/sb-nginx`
- 取舍：不再有自动重启（上游 nginx 也没有），换来 status 准确、stop 真能停、日志干净；systemd 侧本来就是 `Type=forking` + `PIDFile`，未改动
v3.2.69 (2026-11-09)
 > GitHub 的 `releases/download` 链路偶发 **504 Gateway Time-out**（返回 HTML 错误页），导致 `rep` 卡在下载 sing-box 内核。现在下载改成三级回落：本仓库直链 → 本仓库 **REST API asset 接口** → 上游 `SagerNet/sing-box` 同名资产。cloudflared 同样处理。

- 现象：Alpine 机器跑 `rep`，`update_singbox` 打印 `❌ 下载内容异常（疑似 HTML 错误页）`，而同一 URL 用浏览器/其它机器也可能打不开；重试 3 次全部 `http=504`
- 根因：`https://github.com/<repo>/releases/download/<tag>/<file>` 会 302 跳到 `objects.githubusercontent.com`，这条 CDN 链路这次持续 504。**同一个资产**走 `https://api.github.com/repos/<repo>/releases/assets/<id>`（带 `Accept: application/octet-stream`）却能 200 拿到完整 22.6 MB —— 说明文件没丢、仓库没问题，只是直链的跳转链路挂了
- 新增 `dl_result_ok()` / `gh_asset_id()` / `dl_github_release()`：直链失败后自动查 `releases/tags/<tag>`（或 `/releases/latest`）拿 asset id，再走 API 下载；每个候选都做「非空 + 不是 HTML/网关错误页」校验
- `update_singbox` 三级回落：本仓库直链 → 本仓库 API asset → **上游 SagerNet 同名资产**（本仓库的包本来就是从上游镜像的，`sing-box-<ver>-linux-<arch>[-musl].tar.gz` 命名与内容一致）
- `ensure_cloudflared` 三级回落：`cloudflare/cloudflared` 的 `latest` 直链 → 其 API asset → 本仓库 `cloudflared` 固定版本资产（2025.11.1）
- 顺带：失败时的提示补上「可稍后重试 / 手动把文件放到 `/tmp/<archive>` 再重跑」，不再是干巴巴一行 `❌ 下载失败`

v3.2.68 (2026-11-09)
 > Alpine 机器终于有内核层优化了：安装完成后自动调用 [jyucoeng/alpine-onekey](https://github.com/jyucoeng/alpine-onekey) 的 `alpine-optimize-safe.sh`（apk 源锁当前分支、常用工具、时区、sysctl+BBR、开机重放）。默认带 `--no-ssh`，**不会**改动 sshd。

- 背景：`low_mem_tune()` 只在 systemd 下生效（非 systemd 直接 return），而 `sb.sh` 通篇没有 `sysctl -w` / `/etc/sysctl.d` 写入，所以 Alpine / LXC / OpenVZ 小鸡装完从来拿不到 BBR 和那批内核参数
- 为什么不把 sysctl 抄进 sb：外链脚本自带版本演进（apk 源锁分支、容器可写键白名单、`/etc/local.d` 开机重放），抄一遍就得分叉维护。sb 只负责**下载→`sh -n` 校验→调用**
- 新增常量：`ALPINE_OPT_URL`（默认 raw 地址）、`ALPINE_OPT_FILE`（默认 `$SINGBOX_FOLDER_PATH/alpine-optimize-safe.sh`，兼作下载失败时的本地缓存）、`ALPINE_OPT_ARGS`（额外透传参数）、`ALPINE_OPT_ON_INSTALL`（默认 `1`，安装流程里自动跑；设 `0` 关掉只保留手动）
- 新增函数：`is_alpine()`、`alpine_opt_fetch()`、`alpine_opt_supports()`、`alpine_optimize()`
- **`--no-ssh` 是硬要求**：外链脚本会 `ensure_kv PasswordAuthentication yes` / `PermitRootLogin yes`，改完重启 sshd。sb 的机器大多是密钥登录，自动放开密码直登属于安全降级 → 默认一律带 `--no-ssh`；取到的脚本若是旧版（不认这个参数）则**中止并提示**，绝不硬塞
- 新增命令：`sb opt`（执行）、`sb opt dry`（dry-run）、`sb opt upgrade`（额外 `apk upgrade`）、`sb opt ssh`（显式允许改 sshd，慎用）；菜单在 Alpine 上多一项 `[14] Alpine 系统优化`
- 安装/重装流程：`install_deps` 完成后自动跑一次，失败只告警不阻断（`ALPINE_OPT_ON_INSTALL=0` 可关）
- 配套改动在 alpine-onekey 侧（同日 v2.1）：新增 `--no-ssh` / `--no-tools` / `--no-tz` / `--sysctl-only`，可任意组合裁剪

v3.2.67 (2026-11-08)
 > 修 openrc 机器上 `argo.log` 永远是 0 字节：cloudflared 的日志走 **stderr**，模板只重定向了 stdout，于是全被丢进 `/dev/null`。现在 `output_log` 与 `error_log` 都指向同一个文件。

- 现象：Alpine 机器上 `/root/doraemon/logs/argo.log`、`supervise-argo.log` 常年 0 字节，重启 argo 也不出内容，看上去像「cloudflared 没日志 / 隧道没连上」
- 根因：`supervise-daemon` 托管的 init 脚本只写了 `output_log="..."`（对应 fd 1）。实测 `ls -l /proc/<cloudflared pid>/fd/1` → `argo.log`、`fd/2` → `/dev/null`，而 cloudflared 的 logrus 默认输出是 **stderr**：所有 `INF/WRN/ERR` 全写 fd 2 → 全丢。只有 token 之类的致命用法错误走 `fmt` 打到 stdout（这也是「坏 token 反而有 15 KB 输出」的原因）
- 修法：openrc 的 argo 模板补一行 `error_log="'"$LOGS_DIR"'/argo.log"'`；nginx 的 `supervise-daemon` 模板同样补 `error_log=.../nginx-supervise.log`。systemd 分支不受影响（`StandardOutput`/`StandardError` 本来就都给了 journal）
- 现场验证（122 MB 的 Alpine 小鸡）：补 `error_log` 后 `rc-service argo restart`，`argo.log` 立刻 6110 字节，`connIndex=0/1/2/3` 四条 `Registered tunnel connection` 全部落盘 —— 同时坐实了 v3.2.65 的 4 条连接确实生效
- 老 openrc 机器临时修（不用重装）：在 `/etc/init.d/argo` 的 `output_log=` 下一行加 `error_log="<同一个路径>"`，`rc-service argo restart`

v3.2.66 (2026-11-08)
 > 补齐 v3.2.65 漏掉的两处：`sb-bak.sh` 里同样的「小内存降成 1 条」还在，`argorestart()` 的 nohup 分支则根本没带上这个参数。现在三个脚本、四条路径全部同源。

- `sb-bak.sh` 同步到 v3.2.66（它长期跟着主脚本走，只是一直落后一个版本，所以这次的常量块、`argo_ha_flag()`、三处调用一并补齐）
- **`argorestart()` 补丁**：无 init 系统（Alpine / LXC 等没有 systemd、openrc 的环境）走 `sb res` 重启 Argo 时，JSON 固定隧道与 token 固定隧道这两条命令行是手写的，此前不带 `--ha-connections` → 会回落到 cloudflared 默认 4 条，`ARGO_HA_CONNECTIONS=2` 在那条路径上等于没设。现已改成 `${_argo_ha}`，与其余三条路径同源
- 三条 `--url`（trycloudflare 临时隧道）分支刻意不动：临时隧道不需要边缘冗余，也避免给这条路径引入未验证的参数
- 全仓库复核：`grep 'ha-connections 1'` 在 `sb.sh` / `sb00.sh` / `sb-bak.sh` 中已零命中；`sb.sh` 与 `sb-bak.sh` 除第 9 行 `SB_SCRIPT_NAME` 外逐字节一致
- `README-sb.md` 里 v3.2.5x 的旧 changelog 保持原样：那些条目记录的是当时的行为，不是现行文档

v3.2.65 (2026-11-08)
 > 把 Argo 边缘连接数从「小内存硬编码 1 条」改成顶部常量 `ARGO_HA_CONNECTIONS`（默认 4）：Cloudflare 面板上的「降级」可一键消掉，也方便按 1 / 2 / 3 / 4 逐档调试。

- 背景：cloudflared 默认向 4 个边缘节点各建一条 QUIC 连接，Cloudflare 只按「边缘冗余够不够」判定隧道状态 —— **1 条 = 降级（degraded）**，4 / 8 条 = 健康（healthy）。此前脚本对 `MemTotal < 1048576`（即 < 1 GiB）的机器写死 `--ha-connections 1`，而标称 1 GB 的小鸡 `MemTotal` 实测只有 96 ~ 100 万 KB，必然 < 1048576，于是台台显示降级
- 新增常量（脚本顶部，与 `ARGO_DEFAULT_PORT` 同段）：`export ARGO_HA_CONNECTIONS="${ARGO_HA_CONNECTIONS:-4}"`，systemd / openrc / nohup 三条安装路径统一读它；调试时改这一行，或命令行临时覆盖 `ARGO_HA_CONNECTIONS=2 bash sb.sh`
- 新增 `argo_ha_flag()`：只接受 1 ~ 8 的纯数字，空 / 非数字 / 0 / 超范围一律返回空串 → 不传该参数，回落到 cloudflared 默认值，避免写出「启动即失败」的 unit
- 内存分支保留不动：`MemTotal < 1 GiB` 时仍写 `GOMEMLIMIT=25%MiB` / `GOGC=40` / `GOMAXPROCS=1` / `MemoryHigh=30%` / `MemoryMax=40%`，只是不再顺带改连接数
- 实测代价：1500 MB 机器上 4 条连接的 cloudflared RSS 只有 24.5 MB，1 → 4 多出来的是「几 MB ~ 十几 MB」量级，`MemoryMax` 40% 远够用；「降级」只是面板标签，不影响回源、不限速、不降权
- 老机器想让面板立刻变健康：unit 里已有 `--ha-connections 1` 的，把它换成 4 后 `systemctl daemon-reload && systemctl restart argo`；unit 里本来没有这个参数的，已经是默认 4 条，无需改动

v3.2.63 (2026-11-05)
 > 修「IPv6-only 机器 + WARP 提供 IPv4 时，多打一条连不上的 `-IPv4` 节点」：CDN / CGNAT / 私有段不再当节点地址，IPv4 也不再被套上方括号。

- 现象：机器只有公网 v6、v4 由 WARP 提供时，`Hysteria2 - IPv4` 打出 `@[104.28.204.144]:31004` —— 地址是 Cloudflare 边缘 IP，客户端永远连不回来；而且 IPv4 被加了 `[]`，多数客户端直接判为非法
- 根因：`ip_v4` 文件只判「格式合法且是 v4」（`is_valid_ip_simple`），不看这个地址能不能入站；WARP 出口（`104.28.x`）虽然是「出口 IP」，却不对本机端口做入站
- 新增 `_ipv4_in_cidr()`（纯 awk 整数运算，busybox awk 可用）、`_ipv4_is_public()`、`_ipv6_is_global()`：纯本地计算，不联网
- `_ipv4_is_public()` 排除段：`0/8`、`10/8`、`100.64/10`、`127/8`、`169.254/16`、`172.16/12`、`192.0.0/24`、`192.0.2/24`、`192.88.99/24`、`192.168/16`、`198.18/15`、`198.51.100/24`、`203.0.113/24`、`224/4`、`240/4`，以及 Cloudflare 全部段（`104.16/13`、`104.24/14`、**`104.28/14`**、`172.64/13`、`162.158/15`、`173.245.48/20` … 等）和 Fastly 主流段（`151.101/16`、`199.232/16`）
- `pick_server_ip_for_install` 写 `ip_v4` / `ip_v6` 前先过筛：不合格**不写并 `rm -f` 旧文件**，覆盖安装后不会再拿旧值打节点
- `alt_family_addr()` 打印前再筛一次（兼容老安装留下的 `ip_v4`）：不合格直接不打印这条；返回时 **IPv6 才加 `[]`，IPv4 绝不加括号**
- 老机器不必重装：`sb rep` / 重新生成订阅时就会走新逻辑，坏文件自动失效

v3.2.62 (2026-11-05)
 > 修「nginx 进程明明在跑、订阅也正常，面板却显示 ■ 已停止」：pid 文件被服务管理器删掉后，脚本会按 exe 认领存活实例并把 pid 写回。

- 现场成因：安装既直跑 `nginx -p … -c conf/nginx.conf`，又启用了 openrc 的 `sb-nginx`（`supervise-daemon`）；服务那份起第二个实例时端口已被占 → `bind() failed (98: Address in use)` → 重试到 `respawn_max` 放弃、服务转 stopped，openrc 按 init 脚本里的 `pidfile=` 把**两边共用的 pid 文件**删了，而在服务的那份 master 没被碰
- `sb_nginx_running()` 原来第一行就是 `[ -s "$SB_NGINX_PID" ] || return 1`，文件一没就永久判「已停止」；`singbox-watchdog.sh` 又写死「没有 pid 文件 = 用户主动停的，不碰」→ 谁都救不回来
- 新增 `_sb_nginx_master_pids()`：只认 `/proc/<pid>/exe` 等于 `$SB_NGINX_BIN` 且 cmdline 含 `master process` 的进程（宝塔/系统 nginx 的 exe 不是这个二进制，绝不会误伤）
- `sb_nginx_running()` 改为：pid 文件有效就用；缺失/失效时按上面的方法认领，**顺手把 pid 写回** `$SB_NGINX_PID`，面板 / watchdog / `nginx_stop` 立刻恢复对得上号
- 新增 `_sb_nginx_reap_stray()`：`nginx_stop()` 与 `_sb_nginx_stop_raw()`（systemd / openrc 两条分支）停完之后再收一次尾，仍活着的本项目 master 一律 TERM→KILL，杜绝「提示已停止、进程还在跑」
- watchdog 模板同步：pid 文件不存在时先按 exe 认领一遍，认到就写回并记一行 `nginx: pid 文件丢失但进程在跑（pid=…），已写回 pid 文件`，不再直接当成用户手动停
- 真机验证（Alpine + openrc）：`stop` → 实例 0 / 端口 0；`start` → 实例 2（master+worker）/ pid 文件正确；`restart` → 只 reload，`error.log` 零新增行，订阅 200

v3.2.61 (2026-11-05)
 > v4 / v6 都有效时，直连节点里额外多打印一条"另一地址族"节点；同一台机器换个地址族也能连。

- 主节点链接里只能放一个地址，IPv6 机器连 v4 地址、或客户端所在网络只有单栈时，往往要手工改链接才能用
- 安装时把本次探测到的公网 v4 / v6 分别落到 `ip_v4`、`ip_v6`；打印节点时若两族都有值，就用**另一族**再生成一条同协议的节点，名字带 `-IPv4` / `-IPv6` 后缀
- 这条紧跟在**它所属协议**的输出之后打印（补的 Hysteria2 就排在 Hysteria2 下面），标签是 `🎯【 Hysteria2 - IPv6 】(直连协议，另一地址族)`
- 优先级按打印顺序 `Hysteria2 → TUIC → VLESS-Reality-Vision → AnyTLS`，**只补一条**（`_ALT_DONE` 标记），参数（端口/sni/pinSHA256/pbk/sid）与主节点完全一致，客户端里可直接互换
- 写入 `jh.txt` 时用 `prepend_jh` 放到**第一行**，nginx 订阅（`sub.txt` 由 jh.txt base64 而来）同样排最前，客户端列表里一眼可见
- 以下几种情况不补：只探测到一族地址、设置了 `direct_host`（对外域名掩码，地址不是 IP 也就没有"另一族"）、当前没有直连协议（纯 socks5）

v3.2.60 (2026-11-04)
 > Argo 节点段输出结束后补一个空行，最后一条 `trojan-ws-tls-argo` 链接不再和后面的日志粘在一起。

- 三个 argo 协议（vmess/trojan/vless）在同一循环里打印，块与块之间原本靠下一轮的 `green ""` 分隔 → 最后一块后面没有空行
- 循环结束后按 `_argo_printed` 补一次 `echo`，只在真的打印过 argo 节点时才补

v3.2.59 (2026-11-04)
 > `sb report` → 4) 查看详情：状态 / 配置 / 预览三段不再互相重复；预览每条带序号、条间空行。

- 原来「状态」里塞了地址/凭证/机器名/不上报/会上报/节点分布，和「配置」「预览」重复三遍；现在状态页只留开关、最近一次/最近成功、状态文件、配置文件
- 「配置」页区分两个概念：`上报地址`＝你的 sub-merge 域名，`上报 URL`＝真正 POST 的 `/api/v1/report/<机器名>`；来源内部值 `default` 显示为「（默认）」
- 配置页去掉重复的「自动上报」「配置文件」两行（状态页已有）
- 预览：去掉重复的「来源」，标题行统一缩进，每个节点前加 `1) 2) 3)` 序号、每条后空一行，长链接不再糊成一片

v3.2.58 (2026-11-04)
 > `sb report` → 3) 改成二级菜单，逐项修改，随时 `0` 返回上级。

- 原来是一次性问 5 个问题，不想改也得一路回车走到底；现在是列表形式：`1) 上报地址 2) 上报凭证 3) 机器名 4) 来源 5) 不上报的协议 6) 清空全部配置 0) 返回上级菜单`，每项旁直接显示当前值（凭证打码）
- 改完一项打印结果并回本级，可以继续改下一项；`0` 或 `q`/`b`/`exit` 回上级菜单
- 单项输入时 `q`/`b`/`0` = 放弃这一项，不写盘
- 「清空全部配置」独立成第 6 项，带 `(y/N)` 二次确认；地址处 `-` 的清空快捷键保留
- 来源显示：内部值 `default` 统一显示为「（默认）」

v3.2.57 (2026-11-04)
 > `sb report` → 3) 修改配置 支持中途取消，取消后不写入任何改动。

- 原来 5 个提示只能一路回车走到底，想反悔没法退回菜单；现在任意一步输入 `q`（`quit` / `exit` / `b` / `back` / `0` 同样有效）即取消，直接回菜单
- 改成「全部问完才写盘」：以前边问边 `submerge_conf_set`，中途取消会留下半套配置；现在先攒在局部变量里，最后一次性写入
- 全部回车 = 没有改动，明确提示「没有改动（全部回车保持原值）」，不再误报「已保存」
- 地址处 `-`（清空全部配置）与排除协议处 `-`（清空排除项）语义不变

v3.2.56 (2026-11-04)
 > 上报时间单独一行并标明用途：`上报时间：2026-11-04 12:04:20（UTC）`。

- 原来时间是接在 `✅ 上报成功：节点 N 条（…）` 同一行末尾，容易和节点数挤在一起；现在另起一行、缩进两格、带 `上报时间：` 前缀
- `✅ 上报成功`、`✅ 上报成功，但内容与上次完全一致`、`❌ 上报失败（HTTP xxx）` 三种情况同样处理（失败行把时间放在紧接的下一行）
- 自动上报的摘要过滤加上 `上报时间`，否则新加的那行会被 grep 掉；失败时 `tail -n 4` 改成 `tail -n 6`，保证时间与建议不被截断

v3.2.55 (2026-11-04)
 > 上报预览完整打印节点链接，不再截断成 72 字符 + `...`。

- `submerge_preview` 原来 `sed -n '1,5p'` 只取前 5 条、再 `cut -c1-72` 并补 `...`，核对时看不到 uuid / pbk / sni / path 这些关键字段
- 现在原串逐行完整输出、不限条数（`while IFS= read -r` 直接读文件，避免管道子进程）；预览内容仍按「不上报的协议」过滤后再列

v3.2.54 (2026-11-04)
 > 自动上报成功后直接打印本次上报时间，与 `sb report` 菜单里显示的完全一致。

- `✅ 上报成功：节点 N 条（自动 a + 手动 b）` 行尾补 `YYYY-MM-DD HH:MM:SS（UTC）`；`✅ 上报成功`、`✅ 上报成功，但内容与上次完全一致`、`❌ 上报失败（HTTP xxx）` 同样补上
- 新增 `submerge_now_utc()`；`submerge_report` 进入时只取一次时间戳，控制台输出与状态文件 `LAST_TIME` 共用这个值（`submerge_record` 增加第 5 个可选参数传入时间），所以控制台那条与菜单「最近上报」永远是同一个时刻
- 时间统一 UTC 取值，与 v3.2.53 的 `date -u` 保持一致

v3.2.53 (2026-11-04)
 > 上报时间统一标注 UTC，消除跨时区误读。

- `submerge_record()` 改用 `date -u` 记录：状态文件里的时间从此明确是 UTC（服务器时区各不相同，原来按本机时区写，别人看到 `11:51:11` 会当成自己本地时间）
- 展示处补 `（UTC）`：交互菜单 `最近上报：… （UTC） 成功/失败`、状态页 `最近一次：… （UTC）` 与 `最近成功：… （UTC）`
- 兼容旧记录：老状态文件里存的是当时服务器的本地时间，不做换算（多数机器本来就是 UTC）

v3.2.52 (2026-11-03)
 > 临时 argo 隧道加自启与域名跟随，域名一变就重新生成节点并上报。

- trycloudflare 每次启动都换域名、旧域名永久失效；看门狗新增一段专管临时隧道（判定：有 `argoport` 且既无 `tunnel.yml` 也无 `sbargotoken`），进程不在就直接拉起 `cloudflared tunnel --url`
- 从 `argo.log` 抓新域名写入 `argo_domain`，域名变化则重新生成 argo 节点并触发上报；固定隧道由 `argo.service` 托管、域名不变，这段逻辑完全不碰

v3.2.51 (2026-11-03)
 > 上报失败时把服务端的 message / hint 一起打出来。

- 原来只印 `error`，`D1_ERROR: no such table: machine_former` 这类关键说明被丢掉，用户只能看到一个 500
- 现在解析 `message`、`hint`：有就分别打 `服务端说明：…` / `处理建议：…`；500 且无 hint 时提示多半是 D1 未建表，重跑一次上报或访问 `/api/v1/admin/schema`

v3.2.50 (2026-11-03)
 > 不再拿「日志为空」推断启动失败，消除安装后的虚惊。

- 原来 `singbox.log` 为空就直接打 `⚠ singbox.log 为空，sing-box 可能启动失败`；而 openrc/supervise 有缓冲、sing-box 常在首个连接后才写第一行 —— 装成功也会报
- 现在先 `pgrep -f "$SINGBOX_FOLDER_PATH/sing-box"`：进程在跑 → 只写调试日志 `✓ sing-box 已在运行（日志暂无内容，属正常）`；确认进程不在 → `⚠ sing-box 未在运行，可用 sb log_stop 查看停止原因`（指向真正能定位的入口）

v3.2.49 (2026-11-03)
 > 上报摘要的配色与对齐与「安装参数」其它行统一。

- 由黄色（与告警同色）改为绿色；只有真正异常的值（未开启/未配置）才用黄色提示
- 缩进改两空格、冒号改半角、键名用 `节点上报 / 上报域名 / 上报凭证 / 上报机器名 / 排除协议`，与 `订阅:`、`节点名称前缀:` 一列对齐

v3.2.48 (2026-11-03)
 > 上报配置摘要挪进「========= 安装参数 =========」块内。

- 位置从 `set_sbyx()`（跟在「所有节点名称前缀」之后、安装参数块外面）改为安装参数块末尾、`节点名称前缀` 与分隔线之间，和端口/协议一次看完
- 只在「有上报配置」时打印（`SUBMERGE_CONF` 存在，或传了 `REPORT_BASE`/`REPORT_TOKEN`/`REPORT_FLAG`）；完全没配的用户，安装参数块不变
- 机器名显示优先用本次传入的 `name`：安装参数阶段 `$SINGBOX_FOLDER_PATH/name` 还没落盘，原逻辑会显示成主机名，与最终上报用的机器名不一致

v3.2.47 (2026-11-03)
 > 孤儿沙箱 Nginx 的清理改为静默，不再在卸载/重装时刷黄字提示。

- 原来清完会打印 `↳ 发现不受 pid 文件管理的沙箱 Nginx 残留（pid: …），先清理再继续`，容易被当成错误；现在只写调试日志（`sb log_ins` / 调试模式可见），正常流程只留 `▸ 终止进程... ✓ 进程已终止`
- 清理逻辑本身不变：仍按 `/proc/<pid>/exe` 判定、先 TERM 再 KILL

v3.2.46 (2026-11-03)
 > 上报配置摘要补一行「排除协议」。

- 新增 `排除协议：socks5（这几类不上报，其余照常）` / `排除协议：无（全部上报）`
- 取值与 `sb report status` 的「不上报」一致：走 `submerge_exclude_list()`，认 `hysteria2/socks5/tuic/anytls/vless-reality/vmess-argo/vless-argo/trojan-argo/*-cdn`，`hy2` 归一成 `hysteria2`，不认识的写法直接忽略（不会把 `vless` 这种非 kind 词当排除项）

v3.2.45 (2026-11-03)
 > 安装参数区连带打印节点上报（sub-merge）配置，装完就知道会不会上报。

- **打印内容**：`节点上报：已开启/未开启`、`上报域名：<地址>/（未配置，装完不会上报）`、`上报凭证：已配置 6a4a25****44ad / 未配置`、`上报机器名：<机器名>`，与 `sb report status` 同一套取值（`REPORT_MACHINE` > 配置文件 > 节点名前缀 > 主机名 > `sb-node`）
- **凭证只显示首尾**（前 6 + 后 4），不会把整段 token 写进安装日志
- **完全没配过**（无地址、无凭证、未开自动上报）时只打印一行 `节点上报：未配置（如需汇总到自己的 sub-merge，见 sb report）`，避免对不用上报的用户刷屏
- 位置：`set_sbyx()` 里紧跟「所有节点名称前缀」那行之后

v3.2.44 (2026-11-03)
 > 修「覆盖安装开头把自己遗留的沙箱 Nginx 当成外部进程报警，吓到用户」。

- **现象**：`sb rep` 开头的端口体检会打印 `⚠️ 端口 8001（argo_pt=8001）当前已被其他进程监听 / 占用者进程: nginx (pid=...) / 确认非必要服务后，可手动释放端口: kill ...`，而那个 nginx 其实是本脚本上一轮安装留下的沙箱 nginx（pid 文件已丢，见 v3.2.43），紧接着的清理阶段就把它杀掉了 —— 属于自己人误报
- **修法**：端口归属判定 `_p_listener_kind()` 新增通道 2.5——按 `/proc/<pid>/exe` 的真实路径判断，exe 等于 `$SB_NGINX_BIN`（含二进制被替换后的 `... (deleted)` 形式）即视为**本脚本栈自身**，不再报警；仍不按进程名判断，宝塔/系统 nginx（`/usr/sbin/nginx`）照旧算外部进程并提示
- **行为**：自己的沙箱 nginx 占着端口 → 静默（清理阶段会杀）；真正的外部进程 → 照旧报警并给出 kill 提示

v3.2.43 (2026-11-03)
 > 修「卸载/重装后沙箱 Nginx 变成孤儿，占着端口导致下次安装起不来」。

- **新增 `sb_nginx_kill_orphan()`**：按 `/proc/<pid>/exe` 的真实路径判断，只清理 exe 等于本项目 `$SB_NGINX_DIR/sbin/nginx` 且不受 pid 文件管理的进程（系统/宝塔 nginx 的 exe 是 `/usr/sbin/nginx` 等，绝不会被误杀）。先 `TERM` 再 `KILL`，受管实例（pid 文件正指向它）跳过，交给 `nginx_stop`
- **触发场景**：旧版卸载只按 pid 文件停 nginx，而 pid 文件常在更早的清理里已被删除 → master 变孤儿，继续占着 `nginx_pt` / `argo_pt`；下次安装要 `listen 127.0.0.1:${argo_pt}` 时 bind 失败 → nginx 启动即退出，而 `sb nginx_status` 显示「未运行」，日志只留一句「启动后立即退出」，很难定位
- **三处调用**：`start_nginx_service()` 起之前、`cleanup_nginx()` 停之后、`uninstall()` 的终止进程块（原来只 `pkill` sing-box / cloudflared，漏了 nginx）

v3.2.42 (2026-11-03)
 > 上报地址自动补 https；排除项改为「不填=不过滤」。

- **`REPORT_BASE` 可省略 `https://`**：新增 `submerge_norm_base()`，配置读入 / 环境变量 / 菜单输入 / 落盘四处统一规范化——去首尾空白与结尾斜杠、没写协议自动补 `https://`、写了 `http://` 就照原样用、不强行升级（自建反代 / 内网 http 环境要能跑），只有「什么协议都没写」时才补 `https://`。原因：上报固定用 `curl -sS -m 20 -X POST` 且不带 `-L`（`-L` 会把 POST 降级成 GET），裸域名会被 curl 按 `http://` 发，服务端 301 跳 https 后脚本只拿到 301，直接判「上报失败（HTTP 301）」——所以裸域名必须补 https；但用户显式写了协议就得尊重
- **`REPORT_EXCLUDE` 不填 = 不拦截任何协议**：删掉「未配置时默认 socks5」的注入，`REPORT_CLEAR` 分支也改为把排除项置空（原来置回 socks5）。要排掉某类协议就显式写 `REPORT_EXCLUDE='socks5'`，不写就全部上报 —— v3.2.41 说明里的默认值行为作废
- **「已自动上报到 sub-merge」前加一个空行**：这条提示紧贴节点链接输出，挤在一起不好读

v3.2.41 (2026-11-02)
 > 卸载保留上报配置；新增 REPORT_CLEAR 显式清除；配置文件展示取值优先级。

- **`sb del` 不再删上报配置**：`cleandel` 的白名单从 `sing-box|cloudflared|logs|nginx` 增加 `submerge.conf`。原来 `del`（自称「保留二进制便于重装」）会把 `submerge.conf` 一起 `rm`，而里面的 `SUBMERGE_TOKEN` 只能去 sub-merge 后台重新创建，重装时最难恢复的偏偏是它。`submerge.state`（上次上报时间等历史记录）仍然删除，留着重装后会显示「3 天前上报成功」，反而误导。`delall` 行为不变，整目录删干净
- **新增 `REPORT_CLEAR=1`**：保留配置文件之后，「我想清掉上报配置」就没了出口 —— `REPORT_TOKEN=""` 和完全不传在 `[ -n ]` 判断下无法区分，而 CI 里 `secrets.REPORT_TOKEN` 没配就是空串，拿空串表达「清除」会误伤。现在用独立开关：`REPORT_CLEAR=1 bash <(curl -Ls ...) rep` 把 `submerge.conf` 清空并回到默认（地址/凭证/机器名/来源清空，排除项回 `socks5`，自动上报关）。同一个命令里带 `REPORT_*` 会先清后填
- **修清除时的排除项默认值**：清除后若把 `SUBMERGE_EXCLUDE` 置空，后面「conf 里已有 `SUBMERGE_EXCLUDE` 行就不再注入默认值」的判断会让本次运行拿到空值（= 完全不过滤，socks5 也会被报上去）。清除块直接置 `socks5`，与「未配置时默认 socks5」保持一致
- **配置展示补两行**：`sb report → 4) 查看详情` 增加 `取值顺序：环境变量 REPORT_* > 配置文件 > 默认值（传参会写回配置文件）` 与 `清除配置：REPORT_CLEAR=1 重装一次，或 sb report → 3) 地址处填 - `，解决「我传了到底有没有生效」的疑问
- **卸载提示写清删留清单**：`[11] 卸载` 前打印「将删除：节点配置、uuid、reality 密钥、argo 凭证、上报状态记录 / 将保留：二进制、logs、上报配置」，`[12] 卸载全部` 提示「将删除整个目录」。原来只有一句「确认卸载? (y/N)」，用户不知道会连带清掉上报凭证

v3.2.40 (2026-11-02)
 > 上报菜单直接显示「排除什么 / 会报什么」；修 SNI 里带 -tr 被误判成 trojan-argo。

- **菜单可见**：`sb report` 子菜单和 `sb report status` 新增两行 —— `不上报：<排除列表>`、`会上报：<实际会发出去的形态>`；本机有 `jh.txt` 时再多一行 `当前节点：vless-argo×2 trojan-argo×1 …（共 N 条，排除后上报 M 条）`，一眼就能看出这次到底会报什么、少了几条
- **`3) 修改配置` 的提示补全**：原来只列了 `vless,vmess,trojan,hysteria2,tuic,anytls` 六个，现在把 `socks5` 和 8 个细分形态（`vless-reality vless-argo vless-cdn vmess-argo vmess-cdn trojan-argo trojan-cdn`）一并列出，并显示当前会上报的形态
- **修误判**：`submerge_kind_of()` 原来拿整条链接匹配 `*-tr*`，用户把 SNI/host 填成 `xxx-tr.example.com` 时，一条 vless 会被判成 `trojan-argo`，于是勾了「排除 trojan」就连它一起被丢掉。现在形态标记只从 `path=` 参数取，`security=reality` 仍按 query 判定
- **vmess 兼容 `#fragment`**：`vmess://<base64>#名称` 这种手写/外部导入的链接原来整串送进 base64 解码会失败，直接退化成 `vmess` 粗粒度；现在先剥掉 `#` 之后的部分再解码，`-vm` / `-vm-cdn` 能正常认出来（脚本自己生成的 vmess 不带 fragment，不受影响）

v3.2.39 (2026-11-02)
 > Socks5 默认不上报；勾选项按栅格对齐。

 - **默认排除 socks5**：环境变量没给、`submerge.conf` 里也没有 `SUBMERGE_EXCLUDE` 这一行时，`submerge_load()` 自动设成 `socks5`（多数客户端不吃这个协议）
 - **想全报**：`sb report` → `3) 修改配置` → 不上报的协议处直接回车后再输入 `-`，或手写 `SUBMERGE_EXCLUDE=`（空值也算「显式选择不过滤」，不会再被默认值覆盖）
 - 实测：空配置 → `不上报：socks5`；conf 里留空 → `（不过滤，全部上报）`；`REPORT_EXCLUDE=trojan` → 环境变量优先
 - 界面：`singbox-tools-interface` 的 Socks5 勾选框默认选中，三行按 60px 标签 + 3 等分栅格对齐

v3.2.38 (2026-11-02)
 > 排除项按 sb00.sh 实际的节点形态细分，而不是只看 scheme。

 - **细分依据**（对照脚本生成逻辑）：直连 `hysteria2 / tuic / vless-reality（security=reality）/ anytls / socks5`；Argo `vless-argo / vmess-argo / trojan-argo`（path 为 `<uuid>-vl|-vm|-tr`）；CDN 回源 `vless-cdn / vmess-cdn / trojan-cdn`（path 为 `-vl-cdn|-vm-cdn|-tr-cdn`）
 - **`submerge_kind_of()`**：vless/trojan 看 `security=reality` 与 path 标记；vmess 的 path 在 base64 JSON 里，先 `base64 -d` 再匹配；其它 scheme 直接返回自身
 - **前缀匹配**：`submerge_kind_excluded()` 除精确相等外还认前缀，`vless` → 三种 vless 全排；`vmess-cdn` 只排 vmess 的 CDN 形态
 - **白名单**同步扩到 14 个 token，`ss`/`foo` 之类未知值仍静默丢弃
 - **界面**：`singbox-tools-interface` 的勾选框改成 11 个，按「直连 / Argo / CDN 回源」分组

v3.2.37 (2026-11-02)
 > 支持「不上报的协议」：勾上的协议不参与上报。

 - **配置**：`REPORT_EXCLUDE`（环境变量，界面下发）→ `SUBMERGE_EXCLUDE`（`submerge.conf`）；值形如 `vless,trojan`
 - **规范化**：`submerge_exclude_list()` 统一小写、去空格、去重、只保留已知协议（`vless vmess trojan hysteria2 tuic anytls`），并接受 `hy2`/`hysteria` 别名；未知值（如 `ss`）静默丢弃
 - **过滤**：`submerge_filter_nodes()` 按链接 scheme 精确匹配（`^scheme://`），空行顺手丢掉；上报与预览都走它
 - **行为**：`submerge_report()` 过滤后重新编码，「📤 正在上报」里显示「已排除 …」；全部被排除时直接报错并记一条失败状态（`排除协议后没有节点`），不会发空 body
 - **可见性**：`查看详情`/`查看配置`/`查看状态` 都多一行「不上报：vless,trojan」或「（不过滤，全部上报）」；`3) 修改配置` 增加该项（输入 `-` 清空）
 - 实测：6 条节点（hy2/tuic/vless/vmess/trojan/anytls）排除 `vless,trojan` → 上报 4 条；服务端只认 3 条是因为那条 vmess 是手工构造的残缺样本（缺 port/id）解析失败，不是 anytls 的问题——单报 anytls、单报 socks5 都能正常进库

v3.2.36 (2026-11-02)
 > 机器名统一由 `REPORT_MACHINE` 下发，脚本只在它为空时才取 `name`。

 - **取值链**：`REPORT_MACHINE`（环境变量） > `SUBMERGE_MACHINE`（`submerge.conf`） > `$SINGBOX_FOLDER_PATH/name` > `hostname` > `sb-node`
 - **名字怎么写**：建议 `<地区>-<序号>`，比如 `hk-1`、`圣何塞-1`、`jp-osaka`。`sub_merge` 会从机器名里认地区（中文地区词或两字母国家码都行）来决定默认排序，认不出来的机器会被排到最后，界面上标「无地区」。机器名跟节点名是两回事：它只是上报标识，改它不会影响客户端里显示的节点名。
 - **空白容错**：`REPORT_MACHINE="   "` 以前会被当成「有值」写进 conf（机器名却回落成 name，两边不一致），现在先 trim，只有非空白才落盘；`REPORT_MACHINE=`（空串）同理
 - **界面配套**：`singbox-tools-interface` 的第 ⑧ 张卡片会把机器名（跟随 ④ 的 `name`）作为 `REPORT_MACHINE=…` 一起下发，两边值永远一致
 - 实测：不传 → `小叮当-淡-美国北卡莱罗纳`；`REPORT_MACHINE=HK-2` → `HK-2` 且写入 conf；空白 → 回落 `name` 且不写 conf；name 也没有 → `hostname`

v3.2.35 (2026-11-02)
 > 上报子菜单从 7 项砍到 4 项，头部压到三行。

```
========= 上报到 sub-merge =========

  自动上报：已开启（生成节点后自动推送）
  服务端：https://你的域名    凭证：已配置
  最近上报：2026-11-02 19:10 成功

  1) 立即上报一次
  2) 关掉自动上报          ← 开/关时文案自动变
  3) 修改配置（地址 / 凭证 / 机器名 / 来源 / 清除）
  4) 查看详情（状态 / 配置 / 预览）
```

 - 合并：原「查看上报状态」「查看上报配置」「上传前预览」并成 `4) 查看详情`；「清除上报配置」并进 `3)`（地址处输入 `-`）
 - 开关项文案随状态变化（`打开自动上报` / `关掉自动上报`），不用再记「当前：开/关」
 - 头部只留三行：开关状态、服务端+凭证、最近上报结果
 - 未配置时提示带引导色（黄字「未配置（选 3 填你自己的 sub-merge 域名）」）

v3.2.34 (2026-11-02)
 > 上报子菜单在「没配地址/来源为空」时不再显示空白。

 - 头部「服务端：」在未配置时改为黄字「（未配置，选 3 填你自己的 sub-merge 域名）」；「来源：」为空时显示「默认」；开关打开时若还没填地址，提示「选 3 补上之后才会真正推送」
 - 菜单结构不变：`1 状态 / 2 立即上报 / 3 修改配置（地址·凭证·机器名·来源）/ 4 查看配置 / 5 预览 / 6 切换自动上报开关 / 7 清除配置`

v3.2.33 (2026-11-02)
 > 状态页显示配置文件的真实权限；修全角括号紧跟变量名导致的乱码。

 - **修 bug**：`状态文件：$SUBMERGE_STATE（600）` 这种「变量名后直接跟全角括号」的写法，在 bash 里会把 `（` 的首字节吞进变量名解析，输出成 `submerge.state` 缺失 + 乱码（`：��600）`）。改成 `${SUBMERGE_STATE}（600）` / `${SUBMERGE_CONF}（…）`，并全文扫了一遍同类写法
 - **权限可见**：新增 `submerge_conf_perm()`（`ls -l` 取实际权限位，`-rw-------` → 「600，仅 root 可读写」，没建过 → 「未创建」）；状态页与「查看上报配置」都显示，说明改写后会重新 `chmod 600`
 - 实测：未创建 → `（未创建）`；创建后 → `（600，仅 root 可读写）`；`umask 000` 下写入仍是 `-rw-------`（`submerge_conf_set` 写临时文件 + `mv` 后统一 `chmod 600`）；目录 `/root/doraemon` 保持 755，但文件内容只有 root 能读

v3.2.32 (2026-11-02)
 > 上报地址不再内置默认域名；机器名自动取全局配置的 name；来源默认留空。

 - **背景**：上一版内置了一个固定的示例域名当默认值，谁装都往那个域名推；机器名还得单独填一次，其实 ④ 全局配置里的 `name` 就是节点名前缀，本来就该当机器名；来源绝大多数人用不到
 - **改法**：`SUBMERGE_DEFAULT_BASE=""`，`submerge_report()` 与 `submerge_auto_report()` 在地址为空时直接给中文提示并跳过（同时记一条失败状态 `未配置上报地址`）；`submerge_load()` 里机器名默认读 `/root/doraemon/name`（去掉结尾 `-`），没填过才退回 hostname；`SUBMERGE_SOURCE` 不再兜底成 `default`，空值时不拼 `?source=`
 - **界面**：`singbox-tools-interface` 删除「机器名」「来源」两个输入框（改为只读说明：机器名取 ④ 的 name、来源默认空），只留开关 / 上报地址 / 上报凭证；地址 placeholder 改成「你自己的 sub-merge 域名（必填）」；开关打开但地址或凭证为空时两个输入框同时标红提示

v3.2.31 (2026-11-02)
 > 上报结果落盘 + 状态查询：开关、最近一次时间与结果、目标路径与凭证，菜单和命令行都能查。

 - **背景**：自动上报是「装完就推、推完不吭声」，事后想知道「到底推没推、推成功没有、推到哪个地址」得自己翻日志
 - **记录**：每次上报（手动 / 自动 / 失败）都写 `/root/doraemon/submerge.state`（600）：`LAST_TIME` / `LAST_RESULT`(`ok|fail`) / `LAST_HTTP` / `LAST_MSG` / `LAST_NODES` / `LAST_MACHINE` / `LAST_SOURCE` / `LAST_URL` / `LAST_OK_TIME`（最近成功时间，失败不覆盖）
 - **触发面**：`submerge_report()` 的每条出口都记录 —— 未配置凭证、节点文件为空、base64 失败、HTTP 200（`changed:true/false` 分别写「内容已更新」/「内容未变」+ 节点数）、非 200（HTTP 码 + 服务端 error 文案）
 - **菜单**：`[13] 上报到 sub-merge` 顶部多一行「最近上报：<时间> 成功/失败」；新增 `1) 查看上报状态`，其余选项顺延（立即上报→2、改配置→3、看配置→4、预览→5、切开关→6、清配置→7，清配置会连状态一起删）
 - **命令行**：`sb report status`（别名 `sb rstatus` / `sb reportstatus`）打状态；`sb report on|off` 直接开关自动上报；未知参数给用法提示
 - **状态页内容**：开关 + 取值来源（环境变量 `REPORT_FLAG` 优先于 conf）、完整上报地址（含 `?source=`）、打码凭证、机器名/来源、最近一次（时间/成功失败/HTTP/说明/节点数/目标 URL）、最近成功时间、状态文件与配置文件路径
 - **实测**（抽取函数对线上跑）：未配置时显示「已关闭 + 还没有上报记录」；配置后手动上报写入 `ok 200 内容已更新 节点 2 条`；错凭证写入 `fail 401 unauthorized` 且「最近成功」保持不变；开启自动上报后 `submerge_auto_report` 触发同一套记录（`内容未变`）；`sb report status` / `sb report bogus` 输出符合预期

v3.2.30 (2026-11-02)
 > 上报默认关闭：只有 `REPORT_FLAG=1` 才自动上报；地址与凭证落盘到 `submerge.conf`。

 - **背景**：上一版把「上报」做成了手动命令，但用户希望「装完就自动推、默认又别偷偷往外发数据」
 - **改动**：新增 `submerge_auto_flag()` / `submerge_auto_enabled()` / `submerge_auto_report()`，挂在 `regenerate_links_and_sub()` 末尾（`sb ins` / `sb rep` / `sb sub` / 配置修改后都会经过这里）；默认 `REPORT_FLAG` 未设置或 `0` 时完全静默，`1` 才推送
 - **持久化**：`submerge_load()` 支持环境变量 `REPORT_BASE` / `REPORT_TOKEN` / `REPORT_MACHINE` / `REPORT_SOURCE` / `REPORT_FLAG`，给过值就写进 `/root/doraemon/submerge.conf`（600），下次不带环境变量也在；配过凭证后连默认地址和自动开关也一起固化
 - **交互**：子菜单新增 `5) 切换自动上报开关`（写 `SUBMERGE_AUTO`），`3) 查看配置` 会显示「自动上报：已开启/已关闭」；`REPORT_FLAG` 存在时切换会提醒环境变量优先
 - **失败不影响安装**：自动上报失败只输出几行黄色提示，节点生成/订阅刷新照常完成
 - **实测**：无 `REPORT_FLAG` 静默、`REPORT_FLAG=0` 不上报、`REPORT_FLAG=1` 自动推送成功并落盘 `SUBMERGE_BASE/TOKEN/MACHINE/SOURCE/AUTO` 五项；清掉环境变量后仅凭 conf 仍判定为开启

v3.2.29 (2026-11-02)
 > 新增「上报节点到 sub-merge」：`sb report` 一条命令把本机全部节点推到自己的订阅聚合服务。

 - **背景**：自己拿 sub-merge 管订阅时，一台机器装完节点还得手工把链接贴进网页，节点多了容易漏
 - **改动**：新增 `submerge_report()` 等一组函数（`submerge_load` / `submerge_conf_set` / `submerge_b64_file` / `submerge_urlencode` / `submerge_report` / `submerge_preview` / `submerge_conf_show` / `submerge_configure` / `interactive_submerge_menu`），主菜单加 `[13] 上报到 sub-merge`，命令行加 `sb report`（别名 `sb up`）
 - **实现**：读 `/root/doraemon/jh.txt` → 整段 base64（openssl 优先，busybox/GNU base64 兜底）→ `POST /api/v1/report/<机器名>` + `Authorization: Bearer <REPORT_TOKEN>`；机器名按字节百分号编码，中文名可用
 - **配置**：`/root/doraemon/submerge.conf`（600）存 `SUBMERGE_BASE` / `SUBMERGE_TOKEN` / `SUBMERGE_MACHINE` / `SUBMERGE_SOURCE`；`jh.txt` 缺失时先调 `regenerate_links_and_sub` 再上报
 - **返回处理**：不依赖 jq，用 `grep -oE` 解出 `changed` / `nodes` / `auto_nodes` / `manual_nodes` / `updated_at` / `error`；`changed:false` 明确提示「内容与上次一致」，401/400/413/连不上分别给中文排查提示
 - **实测**（macOS 上用抽取的函数对线上服务跑通）：4 条节点首次上报 `changed:true, nodes:4, auto_nodes:4`；原样再报 `changed:false`；改一条名字后 `changed:true`；错误凭证 `HTTP 401 unauthorized`；中文机器名 + 自定义 `source` 均正常；测试机器已从线上删除

v3.2.28 (2026-11-02)
 > 节点名不再拼服务器 hostname：`小叮当-淡-美国北卡莱罗纳-tuic-NC6KW8` 里的 `-NC6KW8` 去掉。

 - **背景**：节点名一直是 `${sxname}<协议>-${hostname}`，`hostname` 取 `uname -a` 的第 2 段。云厂商给的默认主机名常是随机串（本例 `NC6KW8`），于是分享链接里多出一段看不懂的尾巴，客户端列表里也显得脏
 - **改动**：11 处节点名模板统一去掉 `-${hostname}`：hy2、tuic、vless-reality、anytls、socks5、vless-ws-cdn、vmess-ws-cdn、trojan-ws-cdn，以及 argo 的 trojan/vless/vmess；argo 那三处同时去掉端口后缀，名字就是 `-argo`（同一台机若开多个 argo 端口，节点名会一致，需自行区分）
 - **保留**：`hostname` 变量本身没删（`uname -a` 那行留着，避免影响别处可能的引用），只是不再参与节点命名
 - **实测**（`sxname=小叮当-淡-美国北卡莱罗纳-`、`hostname=NC6KW8` 渲染全部 11 条模板）：`…-hy2`、`…-tuic`、`…-vless-reality`、`…-anytls`、`…-socks5`、`…-vless-ws-cdn`、`…-vmess-ws-cdn`、`…-trojan-ws-cdn`、`…-trojan-ws-tls-argo`、`…-vless-ws-tls-argo`、`…-vmess-ws-tls-argo`，均无 `-NC6KW8`、无端口后缀

v3.2.26 (2026-10-31)
 > 统一 sing-box 的服务名：`sb autostart` 不再造出与 `sb.service` 重名的单元抢端口。

 - **背景**：`sb autostart`（`enable_autostart`）一直用 `singbox-service` 当服务名，而正常安装路径（`sbbout`）写的是 `sb.service`，两者的 `ExecStart` 完全相同
 - **后果 1（真机实证）**：装完再跑一次 `sb autostart`，两个单元同时 enabled。重启机器双开，后起的那个报 `FATAL start service: start inbound/tuic[tuic-sb]: listen udp 0.0.0.0:31005: bind: address already in use` → `Restart=always` 每 2 秒重启一次，5 次后 `Failed with result 'exit-code'`，日志被刷爆
 - **后果 2**：`sb autostart_off` 只删 `singbox-service`，`sb.service` 照样自启 —— 用户以为关了，实际没关
 - **修法**：抽出 `gen_sb_unit_systemd()` / `gen_sb_unit_openrc()` 两个模板函数，`sbbout()` 与 `enable_autostart()` 共用一份，服务名统一为 systemd 的 `sb` / openrc 的 `sing-box`
 - `enable_autostart` 先清理历史遗留的 `singbox-service`（disable + 删文件 + 黄色提示）；已有 `sb.service` 就只补 `enable`（保留 sbbout 写的 iptables 恢复 / 日志重定向 / 内存上限），没有才按模板重建
 - `disable_autostart` 两套名字都收，都没找到时给明确提示，而不是假装成功
 - **顺带修 argo 的同类问题**：`install_argo_service_systemd` 与 openrc 分支原来用 `start`，对已 active 的单元是空操作 —— 覆盖安装换了 tunnel token 后旧进程继续按旧配置跑。改为 `restart`（`sb.service` 早前踩过同一个坑）
 - **`systemctl enable sb` / `enable argo` / `rc-update add` 补结果校验**：失败时黄色告警，不再静默
 - 实测（Debian 13）：`sb autostart` 只产出 `sb.service`；手工造一个遗留 `singbox-service.service` 后会自动清理；`sb autostart_off` 正确关停；重装 3.2.26 后整机 reboot，`sb` / `argo` / `sb-nginx` 全部自启、三个 `NRestarts` 均为 0、订阅 200

v3.2.25 (2026-10-31)
 > 3.2.24 刚加的 unit 在真机上起不来：systemd 读不到 pid，僵在 `activating` 死循环。

 - **根因 1（致命）**：`PIDFile="$SB_NGINX_PID"` 带了引号。`PIDFile=` 与 `ExecStart` 不同，**不做引号解析**，`"` 被当成路径字符，实际去找 `/run/"/root/doraemon/nginx/logs/nginx.pid"`，报 `Can't open PID file (yet?)` → 等满 `TimeoutStartSec=30` → `Failed with result 'timeout'` → `Restart=always` 立刻重启 → 无限循环。表象很坑：进程在跑、订阅 200，但 `ActiveState=activating`、`MainPID=0`
 - **修法 1**：`PIDFile=$SB_NGINX_PID` 去掉引号。`ExecStart` / `ExecStop` / `ExecReload` 的引号**保留**（那几项 systemd 会正常剥掉，用来兼容安装目录含空格）
 - **根因 2**：`_sb_nginx_stop_raw` 只看 unit 文件存在就 `systemctl stop`。老安装升级上来的那一次，unit 是刚建的、nginx 还是脚本手工起的进程（不在 systemd 的 cgroup 里）——`systemctl stop` 停不掉它，却会执行 `ExecStop=nginx -s quit`，拿 pid 文件**误杀一个不受 systemd 管理的进程**
 - **修法 2**：先看 `systemctl is-active`，只有 `active` / `activating` / `reloading` 才交给服务管理器，否则回退按 pid 文件停
 - unit 模板标记 `unit-rev: 2`，装过 3.2.24 的机器下次执行脚本会自动重写 unit，无需手工删文件
 - 实测（Debian 13 / VPS）：`kill -9` master → 第 11s 自动拉起、订阅恢复 200；`systemctl stop` 后 12s 仍 `inactive`（人工停的不复活）；`systemctl start` 恢复；`systemctl reload` 平滑重载、`MainPID` 不变；整机 `reboot` 后 55s 起来，`sb-nginx` 自启、`NRestarts=0`

v3.2.24 (2026-10-31)
 > 沙箱 Nginx 接入服务托管：随开机自启 + 被杀自动拉起。

 - **问题**：沙箱 nginx 一直完全脱离服务管理器，只有 cron 看门狗（每 2 分钟）兜底
   - 被 OOM 杀掉后最多躺 2 分钟
   - **整机重启后根本不起来**：pid 文件不在了，而看门狗按设计「没有 pid 文件 = 用户主动停的」不碰 → 订阅入口长期 404，直到用户再跑一次脚本
 - **新增 unit**：systemd 用 `sb-nginx.service`，openrc 用 `/etc/init.d/sb-nginx`；服务名固定 `sb-nginx`，**绝不与系统的 `nginx.service` 撞名**
 - **`Type=forking` + `PIDFile`**：`nginx.conf` 里是 `daemon on;`，想用 `Type=simple` 就得 `-g 'daemon off;'`，但那会和配置文件里的 `daemon on;` 撞 `"daemon" directive is duplicate`，nginx 直接起不来
 - **`Restart=always` 但带熔断**（`RestartSec=10s` / `StartLimitBurst=5` / `StartLimitIntervalSec=300`）：nginx 与 sing-box 不同，端口被占、配置写错都是**持久性**故障，无限重启只会把 `error.log` 刷爆；5 次后停在 `failed` 等人工，用户在菜单里手动启动时会 `reset-failed` 复位
 - **openrc 侧**优先 `supervise-daemon`（`respawn_delay=10` / `respawn_max=5` / `respawn_period=300`），无此能力时回退 `command_background`
 - `start_nginx_service` 改走统一入口 `_sb_nginx_start_raw`；`nginx_stop` 走服务管理器（否则 `Restart=always` 会立刻把刚停的进程拉回来）
 - **看门狗避让**：`gen_watchdog_script` 生成的脚本检测到 unit 存在就跳过 nginx 分支，避免两边同时拉起撞端口
 - `cleanup_nginx` 先调 `remove_nginx_unit`（stop → disable → 删文件 → `daemon-reload`）
 - 新增函数：`_sb_nginx_unit_exists` / `install_nginx_unit` / `_sb_nginx_start_raw` / `_sb_nginx_stop_raw` / `remove_nginx_unit`

v3.2.23 (2026-10-31)
 > 旧版遗留的系统 Nginx 抢端口时自动治愈 —— 修掉「订阅 200 假成功」。

 - **背景**：2.0.x 时期脚本会 `apt-get install -y nginx` / `yum install -y nginx` / `apk add nginx`，并把订阅站点写进 `/etc/nginx/conf.d/singbox.conf`（或 `/etc/nginx/http.d/`）
 - **根因**：3.2.22 的 `cleanup_legacy_system_nginx_conf` **只 `rm` 不 reload**。系统 nginx 内存里旧 server 块继续占着 31007 / 8001，而旧 location 又正好 serve 新生成的 `sub.txt`（uuid 还是同一个）→ **订阅 HTTP 200，但服务者是系统 nginx 不是沙箱 nginx**。用户以为装好了，一旦 `systemctl restart nginx` 或重启机器，配置重读、旧块消失，订阅立刻 404
 - **修法**：删完遗留配置补一次**平滑重载**，端口立刻让出来，沙箱 nginx 自己就能起来
   - 新增 `_system_nginx_bin()`：候选 `/usr/sbin/nginx`、`/usr/local/sbin/nginx`、`/usr/local/nginx/sbin/nginx`、`/www/server/nginx/sbin/nginx`（宝塔）
   - 新增 `_system_nginx_running()`：`pgrep` 优先，`ps -A | grep 'nginx: master process'` 兜底（busybox）
   - 新增 `_reload_system_nginx_if_safe()`：**先 `nginx -t`，配置不过就绝不 reload**；然后 `systemctl reload nginx` → `rc-service nginx reload` → `"$bin" -s reload` 三级回退；**绝不 stop / disable 外部 nginx**
 - `nginx_port_owner_diagnose` 加自愈分支：占用者是 nginx 时先试一次 reload，`sleep 1` 后**重新检测端口归属**，真释放了才 `green` 放行；没释放说明是用户自己的站点，照旧报诊断、不掩盖真实冲突
 - **顺带修一个显示 bug**：`_fcomm` 的 sed 表达式 `s/users:(("\([^"]*\)".*/\1/p` 在 GNU/BSD sed 上都是「字面反斜杠 + 字面括号」，永远匹配不到，结果整行 `ss` 输出被当进程名打印成 `占用者进程: LISTEN 0 511 127.0.0.1:8001 ... nginx (pid=...)`。改用 `grep -o` 提取，并且多 pid 时**优先挑 `ppid=1` 的 master**（`ss` 里 worker 常排在 master 前面，照老逻辑会提示用户去 kill 一个 worker，白干）
 - 实测（Debian 13，系统 nginx `active+enabled`）：遗留配置场景零 `❌` 自动接管、订阅 200；用户自有站点场景正确报诊断、站点仍返回原内容、系统 nginx 保持 `active+enabled`；`systemctl restart nginx` 后沙箱 nginx 不受牵连、31007 归属不变

v3.2.22 (2026-10-31)
 > 修端口归属判定：沙箱 nginx 的 worker 不再被误判成系统 nginx。

 - 3.2.21 上真机后立刻暴露两个 bug（macOS 本地无 `ss` / `/proc`，测不出来）
 - **bug 1**：`ss -tln` **缺 `-p`** → 根本不输出 `users:(...)` 段 → 永远解析不到 pid，每次都退化到 `/proc` 全扫兜底。能出结果所以本地看不出，但明显变慢
 - **bug 2**：worker 被误判。真实输出 `users:(("nginx",pid=510688,fd=5),("nginx",pid=510687,fd=5))` —— **worker 排在 master 前面**，而 worker 的 cmdline 只有 `nginx: worker process`，不含安装路径。旧逻辑「取第一个 pid + cmdline 匹配 prefix」一旦 ss 分支修好就会把自家 worker 报成「系统 / 宝塔 Nginx」，天天误报
 - **修法**：`_listener_pid_of_port` → `_listener_pids_of_port`，返回该端口**全部** pid；新增 `_pid_ppid()`（从最后一个 `) ` 之后切，兼容 comm 含空格/括号）；归属判定改为三条任一成立即放行 —— 命中 master 本人 / `_pid_ppid` 等于 master（认亲 worker）/ cmdline 带 `$SB_NGINX_DIR`
 - 实测：`_listener_pids_of_port 31007` 返回 `510687 510688`；`_pid_ppid 510688` = 510687；诊断静默放行零误报。`apk add nginx` 造真系统 nginx 后诊断正确报「占用者是【系统 / 宝塔 Nginx】」

v3.2.21 (2026-10-31)
 > 系统 Nginx 抢端口时给出明确诊断；订阅失败不再中断安装。

 - **背景**：旧版装过系统 nginx 的机器，`nginx_pt` / `argo_pt` 被占 → `ins()` 里 `ensure_nginx_if_needed || exit 1` 直接中断，用户看到「安装失败」，但 sing-box 节点其实已经通了，只是订阅 404
 - 新增 `_listener_pid_of_port()`：`ss` 优先，`/proc/net/tcp` LISTEN inode 扫 `/proc/*/fd` 兜底（无 `ss` 的极简环境）
 - 新增 `nginx_port_owner_diagnose()`：区分系统/宝塔 nginx 与沙箱 nginx，给出三选一解法 —— `systemctl disable --now nginx` / `rc-update del nginx` / `nginx_pt=18080` 换端口重装
 - `start_nginx_service` 在 bind 之前插入诊断，把「谁占了端口」直接说清楚，而不是等 bind 失败后只丢一句 `error.log`
 - **订阅失败不再中断安装**：改为 `NGINX_SETUP_FAILED=1` + 黄色告警，`ins()` 末尾收尾说明「sing-box 已就绪，但订阅服务（沙箱 Nginx）未就绪」，退出码 0
 - 修文案 bug：`bash <(curl -Ls 安装地址) rep 前设置 nginx_pt` → `nginx_pt=18080 bash <(curl -Ls 安装地址) rep`（`rep` 不吃位置参数，端口只能走环境变量）

v3.2.20 (2026-10-29)
 > Argo token 校验过严：带 `=` 的**合法** token 被拒。

 - **根因**：`is_valid_argo_token` 用的是白名单正则 `^[A-Za-z0-9_-]+(\.[A-Za-z0-9_-]+)*$`。Cloudflare 下发的 token 是 `base64(base64url(JSON))`，长度不整除 3 时自带 `=` 填充（尾部 `In0=` 就是 `"}` 的填充），合法 token 会被直接判非法，`prepare_argo_credentials` 中止安装
 - **改为黑名单**：只拒绝真正会破坏落地处的字符，其余全部放行
   - 空白 / 控制字符（CR LF TAB）：systemd `ExecStart` 会按空白分词；写 unit 与 init 脚本时行被断开
   - `"` `'`：破坏引号包裹（unit `ExecStart` / init 的 `command_args` / `--token "$token"`）
   - `` ` `` `$` `\`：shell 与 init 脚本里会被当作命令替换、变量展开、转义
   - `%`：systemd unit 的指符展开（`%i` / `%n` 等），`%` 后接未知字母会让 unit 直接报错
   - 放行：`= + / @ : , . ; # ! * ? & | < > ( ) [ ] { } ~ ^ _ -` 以及全部字母数字
 - **`argo.service` 的 `ExecStart` 给 token 补双引号**：原来 `--token ${token}` 未加引号，是三个落地点（systemd / openrc / nohup）里唯一没有引号保护的
 - **`sbargotoken` 落盘 `echo` → `printf '%s\n'`**：token 以 `-n` / `-e` 开头时 `echo` 会把它们当选项吞掉，文件内容被写坏（读回时 token 缺头）
 - 影响面：`prepare_argo_credentials`、`install_argo_service`（systemd）、`install_argo_service_openrc`、`start_argo_no_daemon` 共用这一个校验函数，改一处全链路生效；`sb.sh` 与 `sb00.sh` 同步修改

v3.2.19 (2026-10-23)
 - **`cron_running()` 在 Alpine 上误报「cron 没在运行」**：用的是 `pgrep -x cron/crond`，而 busybox 的 `-x` 是「整条命令行精确匹配」，`crond` 的 cmdline 是 `/usr/sbin/crond -c /etc/crontabs -f`，永远匹配不到；`ps -ef` 兜底在 busybox 上也不可用（只支持 `-o`/`-T`）。改为按 `/proc/<pid>/comm` 匹配，`ps` 兜底同时保留 `ps -ef` 与裸 `ps` 两种写法

v3.2.18 (2026-10-23)
 > 状态面板的「内存占用」显示错误（Alpine/OpenRC 上显示 1M）。

 - **根因**：原来用 `pgrep -f "<安装路径>/sing-box"` 找 pid。OpenRC 的 `supervise-daemon` 命令行是 `supervise-daemon --exec /root/doraemon/sing-box ...`，里面也带这个路径，而它的 pid 比真正的服务进程小，`head -1` 一定选中它 —— 守护进程 RSS 只有几百 KB，面板就把 1M 当成了服务内存
 - **修法**：按 `/proc/<pid>/comm` 精确匹配进程名（`sing-box` / `cloudflared`），多个同名进程的 `VmRSS` 求和；不再依赖 `pgrep` 的匹配语义
 - **实测**（Alpine 3.22 / MemTotal 125MB）：修复前 sing-box `1M`、cloudflared `1M`；修复后 `29M` / `28M`，与 `ps -o rss` 一致
 - 「运行中 / 已停止」判定改用同一份 pid 快照，不再因为守护进程还活着而误报运行中
 - 顺带记录：`pgrep -x sing-box` 在 busybox 上是「整条命令行精确匹配」，永远匹配不到，不能用来找服务进程

v3.2.17 (2026-10-23)
 > Alpine / OpenRC 适配。

 - **看门狗在 Alpine 上原本是空转的**：OpenRC 下 `sb` 的服务名是 **`sing-box`**（`/etc/init.d/sing-box`），而 systemd 下是 `sb`。原来两处都传 `sb`，Alpine 上永远匹配不到。现在按 init 系统分别处理
 - **OpenRC 分支增加「是否开机自启」判断**：用 `/etc/runlevels/default/<服务>` 软链判断（等价于 systemd 的 `is-enabled`），用户 `rc-update del` 掉的服务不会被看门狗拉起来
 - **`low_mem_tune` 在 Alpine 上不再打印误导性横幅**：Alpine 既没有 journald 也没有 apt 定时器，直接跳过并只写 debug 日志
 - 其余改动本身与 init 系统无关（`GOMEMLIMIT` / `GOGC` / `GOMAXPROCS` 已同时写进 OpenRC 的 init 脚本，`--ha-connections 1` 在 systemd / openrc / nohup 三处都生效）

v3.2.16 (2026-10-23)
 > OOM 被杀可以接受，但被杀之后必须能自己回来。

 - **`sb.service` / `argo.service` 加 `StartLimitIntervalSec=0`**：systemd 默认「10 秒内启动 5 次」就放弃并把单元停在 `failed`，之后没有任何东西再去拉它。设为 0 后配合 `Restart=always`，OOM 反复杀也会一直重试，内存缓过来自己就起来了
 - **新增服务看门狗** `singbox-watchdog.sh`（cron 每 2 分钟，纯 sh + systemctl，占用 <2MB）：
   - systemd 只处理 `failed`、openrc 只处理 `crashed` —— **手动 `systemctl stop` / `rc-service stop` / `disable` 的一律不碰**
   - **沙箱 nginx 不在 systemd 里**，被杀就永远躺那儿；看门狗靠 pid 文件判断：pid 文件在但进程没了（被 OOM 杀）才重启，而 `nginx_stop` 会删 pid 文件，所以主动停的不受影响；pid 被系统复用给别的进程时会先校验 `/proc/<pid>/comm`
   - 日志写 `logs/watchdog.log`（超过 128KB 自动清空），卸载时连 crontab 条目一起清掉

v3.2.15 (2026-10-23)
 - **`argo.service` 不再设 `OOMScoreAdjust=500`**：这个键只在「整机 / 容器级 OOM」时参与挑受害者；argo 撞到自己 `MemoryMax` 时是 cgroup 内部 OOM，组里只有它一个进程，设不设都是它自己死。真正决定 argo 会不会被杀的是 `GOMEMLIMIT` / `MemoryMax` / `--ha-connections 1`，这三样都保留。想恢复「整机吃紧先牺牲 argo」在 unit 里加回一行即可

v3.2.14 (2026-10-23)
 > 面向 128MB 小内存机器的稳定性修复。不减少协议、不影响 Argo。

 - **不再挂裸 `sniff`**：sing-box 的 sniff 默认超时 300ms，纯直连节点没有域名规则时每条连接都要白等 300ms（日志里表现为 `inbound connection from` → `inbound connection to` 固定 350~430ms，且与目标无关）。`resolve` 保留，继续承载 `sbyx` 的 IPv4/IPv6 策略
 - **改配置不再清空自定义出站 / 分流规则**：`sbbout()` 原来 `.outbounds = [direct, block]`、`.route.rules = [...]` 整体覆盖 —— 覆盖安装、改协议、改订阅开关之后，`[5] 分流管理` 里加的落地出站和「附着协议到代理」的规则会被静默抹掉，流量退回 `direct`。现在只补 `direct`/`block`，保留已有出站与非 sniff/resolve 规则
 - **修掉遗留 `.warp_config` 分支的悬空引用**：规则指向 `wireguard-out`，但出站表里已经没有它，sing-box 会直接起不来；现在只有该出站存在时才生成对应规则
 - **`sb.service` 补齐内存约束**：systemd 分支原来完全没有限制（只有 openrc 写了 `GOMEMLIMIT`）。小内存机器按 MemTotal 注入 `GOMEMLIMIT` / `GOGC=30` / `GOMAXPROCS=1` / `MemoryHigh` / `MemoryMax`，并加 `LimitNOFILE=65535`；≥1G 的机器不受影响
 - **`argo.service` 同样加内存约束**（`OOMScoreAdjust=500` 在 v3.2.15 已去掉，见上）
 - **小内存机器 Argo 边缘连接数 4 → 1**（`--ha-connections 1`）：每条 QUIC 连接都有自己的收发缓冲和 goroutine，只影响边缘冗余，断了会自动重连
 - **沙箱 nginx 的 WS 反代补超时**：6 个 `/{uuid}-*` location 加 `proxy_read_timeout` / `proxy_send_timeout 3600s`、`proxy_buffering off`、`proxy_socket_keepalive on`、`access_log off`。nginx 默认 60s 会把空闲的 VMess/VLESS/Trojan over WS 直接断开（隧道模式下只有上游读写挂定时器），表现为「用着用着就掉线」
 - **nginx `worker_connections` 1024 → 512**：128MB 上 1024 是浪费，重连风暴时 512 也远超实际并发
 - **日志默认级别 `info` → `warn`**：info 会给每条连接写 2 行、每次 DNS 解析再写 N 行，小机器上既费 CPU 又费 768MB 的盘。排查连接问题时临时切回：`jq '.log.level="info"' /root/doraemon/sb.json > /tmp/sb.json && mv /tmp/sb.json /root/doraemon/sb.json && sb res`
 - **下载前磁盘预检**：sing-box 需 ≥120MB、cloudflared 需 ≥80MB，不够直接给清理命令（768MB 盘装完两个二进制就所剩无几，写满后 sing-box 直接崩）
 - **<256MB 机器自动瘦身**：journald 限到 16MB、停掉 `apt-daily.timer` / `apt-daily-upgrade.timer` / `unattended-upgrades.service`（apt 峰值 50MB+，很多小机器就是凌晨这个窗口被 OOM 杀的）。全部可逆，`systemctl enable --now` 即可恢复

v3.2.12 (2026-10-21)
 - **日志轮转的 cron 现在会自动补装并启动**：`install_deps` 把 `crontab` 纳入依赖检查——Debian/Ubuntu 补 `cron`、RHEL 系补 `cronie`、Alpine 仅在 busybox 没带 `crontab` 时补 `dcron`（避免和 busybox 冲突）；装完由 `install_log_rotate` 把守护进程拉起来
   - 容器里 `apt install cron` 常被 policy-rc.d 拦住不会自动启动，旧版只会提示「需自行安排定时执行」；现在按 systemd → openrc → sysvinit（`service cron start`）→ 直接拉进程的顺序兜底，全都失败才退回手动提示
   - 不再要求用户自己 `crontab -e`，日志轮转开箱即用

v3.2.11 (2026-10-19)
 > 体检第三批（P2：低频 / 体验 / 隐患）。全部在 VPS 上实测过。

 - **vless-ws 端口不再每次覆盖安装都变**：其它协议都会先回读 `port_vl_ws`，只有 vless 漏了这一步，导致每次 `sb ins` 都重新随机一个端口（客户端节点全废）
 - **nginx 端口冲突时不再落脏值**：`nginx_port` 原来在「nginx_pt 与 argo_pt 相同」校验**之前**就写盘，冲突中断后脏端口被持久化
 - **`[4][5]` 改完 Argo 协议立即生效**：`_set_argo_proto` 只写文件不 `export argo`，而 `argo_proto_list`/`need_argo` 都是环境变量优先 → 装完马上进菜单改会改不动（要重开脚本）
 - **交互式安装不再带上上一轮的协议勾选**：`vlrt/hypt/tupt/anypt/socks5pt` 只在选中时 export、从不清理，同一次会话里取消安装再进菜单，上一轮的 Hysteria2/TUIC/AnyTLS/Socks5 会被一起装上
 - **Socks5 密码输入不再明文回显**：提示写着「已设置（不回显）」但用的是 `reading`，改为 `reading_secret`（`read -s`）
 - **编号输入 0 不再删错对象**：`.[(($idx|tonumber)-1)]` 遇到 `0` 会变成 `.[-1]` 取最后一条，两处（代理编号 / 规则序号）都加了「必须 ≥ 1」校验
 - **IPv6 代理地址能正确解析**：`socks5://[2001:db8::1]:1080` 原来按 `:` 切会得到 `_server="[2001"`，现在走方括号分支
 - **不再依赖 bash 4.3**：`install_pkgs_resilient` 用的 `local -n`（nameref）在 CentOS 7 的 bash 4.2 上直接报错，依赖安装会静默失败；改成按值复制数组
 - **UUID 兜底不再生成 35 位**：`/proc/sys/kernel/random/uuid` 不可用时的兜底拼接漏了第 12、16 位，末段只剩 11 字符 → 非法 UUID
 - **在线 wrapper 不再泄漏临时文件**：`mktemp "${SB_FOLDER}/..."` 在生成 wrapper 时就被展开成相对路径 `doraemon/…`（CWD 不对就落到 /tmp），且 `exec bash` 导致每次 `sb` 都留一份 ~350KB 脚本。现在正确转义为运行时展开，并用 `trap` 清理（实测跑完 0 残留）
 - **卸载不再误删用户自己的定时任务**：原来 `sed '/.*singbox.*/d'` 会把任何含 `singbox` 的无关 cron（比如用户自己的 `/root/backup-singbox-config.sh`）一起删掉，现在只删本脚本的 `singbox-log-rotate` / `agsb` 行
 - **证书缺失时不再生成必然连不上的 `pinSHA256`**：`openssl | sha256sum` 在 `cert.pem` 不存在时会给出空输入的固定哈希，现在没证书就不带 `pinSHA256`
 - **删除死代码** `edit_socks5_proxy`（定义了但没有任何调用点，且与 `[5][4]` 标签重复）

v3.2.10 (2026-10-19)
 > 体检第二批（P1：功能静默失效 / 安全隐患）。全部在 VPS 上实测过。

 - **`socks5_wl_flag=1` 现在真的能开白名单**：注释写的是 `true/1=开启`，但 `is_true` 只认 `"true"`，传 `1` 时白名单完全不生效、端口对全网放行，界面还显示「已开启」。`is_true` 改为接受 `true/1/yes/on`，`init_socks5_whitelist` 落盘前统一归一化成 `true`/`false`
 - **白名单开关终于关得掉**：`init_socks5_whitelist` 原本「文件覆盖环境变量」，已装过的机器 `sb ins socks5_wl_flag=false` 永远无效。改为环境变量优先、文件兜底
 - **覆盖安装不再静默关订阅 / 重置端口**：`write2SingboxFolders` 无条件 `echo "${subscribe}"`、`"${nginx_pt}"`、`"${ws_cdn}"` 落盘，而这三个变量启动时就被赋了默认值 → `sb ins` 会把订阅关掉、端口改回 8080。现在只在**显式传参**时覆盖，否则保留落盘值；安装横幅也改用生效值显示（不再出现「显示不开启、实际开着」）
 - **依赖装不上就中止**：`install_deps` 的返回码原本被丢弃，缺 jq/openssl 也照样打印「安装完成」
 - **改 Argo 凭据会重建服务单元**：token 是写死在 unit / init.d 的 `ExecStart` 里的，原来只 `argorestart`，换 token 等于没换；token→JSON 时 unit 还指向已删除的 `tunnel.yml`。现在统一走 `rebuild_argo_service`
 - **改 Argo 凭据失败会回滚**：原来先 `rm -f` 旧凭据再校验，校验失败就两头空（旧隧道没了、新的也没成）。现在先备份、失败自动还原
 - **「取消 Argo」真的能取消**：原来只 `pkill`，systemd `Restart=always` / openrc `supervise-daemon` 5 秒后又拉起来；且没清 `argo`/`vlvm`，`need_argo()` 仍为真。现在先 `stop+disable` 服务、再结束进程、再清协议清单，最后重新生成订阅
 - **切换 Argo 隧道后会重新生成节点/订阅**：原来改完域名不刷新，订阅里还是旧域名
 - **`sbrestart` 重启前校验配置**：schema 用 `sing-box check`，**引用完整性另用 jq 补校验**（`route.final` / `rule.outbound` 指向不存在的出站时，`check` 返回 0 但运行时 FATAL `default outbound not found`，随后被 supervise 拉成崩溃循环）。校验不过就不重启，保留当前进程；`SB_SKIP_CHECK=1` 可强制
 - **删除 socks5 代理不再把配置删坏**：删之前先看 `route.final` 是否指向它（指向则改回 `direct`），否则 final 悬空 → sing-box 起不来
 - **改协议代理不再误伤同规则里的其它协议**：「改为直连」原本把整条 inbound 规则删掉，一条规则挂 `hy2-sb` + `vless-reality-vision-sb` 时改 hy2 会把 vless 一起变直连。现在只从 `.inbound` 数组里摘掉目标协议，数组空了才删规则（换代理同理）
 - **沙箱 Nginx 的 pid 会校验身份**：原来只 `kill -0`，重启后 pid 被别的进程复用时，`nginx_stop` 会以 root 给无关进程发 TERM/KILL。现在校验 `/proc/<pid>/comm` 含 `nginx`
 - **cloudflared 改为下载到临时文件 + 校验后原子替换**：原来 `curl -Lo` 直接覆盖运行中的二进制，且 curl 没有 `-f`，404 的 HTML 错误页也会被当成「下载成功」；失败分支还会删掉原本可用的文件

v3.2.9 (2026-10-19)
 > 全脚本体检的第一批（P0：会导致服务起不来 / 配置写坏 / 删数据）。每条都在代码里核实过。

 - **修复可能删除整个安装目录的隐患**：状态采集里 `_tmpd="$(mktemp -d 2>/dev/null || printf '%s' "$SINGBOX_FOLDER_PATH")"`，`mktemp` 失败时回退成安装目录，而函数末尾会 `rm -rf "$_tmpd"` → 整个 `doraemon/` 被删光。现在 `mktemp` 失败直接跳过状态采集，并在 `rm -rf` 前加白名单校验（绝不碰安装目录）
 - **修复「取值函数把提示打到 stdout」污染返回值**（`get_short_id` / `normalize_cdn_pt` / `show_sub_url`）：这些函数被 `$(...)` 调用，里面的 `yellow`/`green` 提示会一起被捕获。`get_short_id` 触发时（升级后 sid 与私钥推导值不一致，很常见）返回「ANSI + 中文 + 换行 + sid」，被 `jq --arg` 写进 `short_id`，sing-box 校验 hex 失败直接起不来；`normalize_cdn_pt` 同理会写坏 `cdn_pt`。现在三处提示全部改走 `>&2`
 - **修复 `timeout` 包 shell 函数导致功能永久失效**：`timeout 8 _resolve_domain_ips_impl ...`、`timeout 6 query_ip_region ...` —— `timeout` 是外部命令，无法执行 shell 函数（execvp 找不到，127 退出且 stderr 被丢弃），所以**域名反查与地区查询在所有目标机上永远返回空**，合法域名一直被误报「未在 DNS 生效」。改为自研的「后台执行 + 看门狗 kill」限时器 `_sb_run_with_timeout`
   - 顺带修好 DNS 反查结果里混入本地解析器地址的问题（busybox nslookup 会把 `10.10.0.1:53` 当结果打出来），现在只保留真正的 IPv4/IPv6
 - **修复覆盖安装后新配置不生效**：`sbbout` 用 `systemctl start sb` / `rc-service sing-box start`，服务已在运行时 `start` 是空操作 → 旧进程继续占旧端口，而 nginx/订阅已按新端口生成，全节点 502。改为 `restart`；nohup 分支先 `pkill` 再拉起
 - **修复 nginx 配置改了不生效**：`ensure_nginx_if_needed` 调 `start_nginx_service`，后者在「已在运行」时直接 `return 0`。改为「已在运行则 `nginx_restart` 重载，否则启动」，并**把失败码透传**给 `ins` 的 `|| exit 1`（此前无条件 `return 0`，nginx 起不来也照样打印「安装完成」）

v3.2.8 (2026-10-19)
 - **安装时选 `server_ip` 也加了 CDN 归属判断**（此前只有 `[4][10]` 有）：`pick_server_ip_for_install` 若发现出口 IPv4 属于 Cloudflare / Fastly / Akamai，说明 v4 出口被 WARP / 云厂商 NAT 之类代理了，拿它当节点地址客户端连的是 CDN 边缘节点，节点必然不通——此时自动改用 IPv6
   - **软判断**：只有明确识别出 CDN 厂商 **且** 本机有可用 IPv6 才替换；ip-api.com 不可达时按原逻辑继续，不影响装机成功率
   - `ippz=4` 显式指定时尊重用户选择，保留 IPv4，只告警
   - `out_ip` 显式指定时直接采用，但若属于 CDN 会告警
   - **日志**：判断结果写进安装日志（`yellow`/`white` 都会落盘），例如
     `▸ 出口 IPv4 x.x.x.x 未命中三大 CDN（Cloudflare/Fastly/Akamai），按原逻辑使用`、
     `⚠️ 出口 IPv4 x.x.x.x 属于 Cloudflare（CDN 厂商），已改用 IPv6 ...`、
     `⚠️ 出口 IPv4 x.x.x.x 属于 Cloudflare（CDN 厂商），但本机没有可用 IPv6，仍沿用 IPv4`、
     `⚠️ out_ip x.x.x.x 属于 Fastly（CDN 厂商）...`
   - 另有 `debug_log` 逐分支调试信息（`DEBUG_FLAG=1` 时输出到终端）

v3.2.7 (2026-10-19)
 - **`[4][10]` 自动检测增加 CDN 归属判断**：出口 IPv4 若属于 **Cloudflare / Fastly / Akamai**，说明 v4 出口被 WARP / 云厂商 NAT 之类代理了——拿它当节点地址，客户端连到的是 CDN 边缘节点而不是本机。此时自动改用 IPv6
   - 判定走 ip-api.com 的 ASN + 组织名双保险：Cloudflare（AS13335 / 132892 / 202623 / 203898 / 394536）、Fastly（AS54113）、Akamai（AS20940 / 16625 / 21342 / 18717 / 32787），ASN 没命中再按名称兜底
   - **自动模式**：v4 命中 CDN 且有可用 v6 → 用 v6 并提示原因；没有 v6 → 仍用 v4，并提示「属于哪家 CDN」
   - **显式选 4**：尊重用户选择照用 v4，但会提示该地址属于哪家 CDN
   - **手动指定 IP**：同样会提示
   - 查询失败（ip-api.com 不可达）时不阻断，退回原逻辑

v3.2.6 (2026-10-19)
 - **修正 `[4][10]` 自动检测的地址族选择**：原来按「当前 server_ip 的地址族」猜（当前是 IPv6 就优先 IPv6），换机器 / 换出口时可能把只配了 v4 出口的节点悄悄改成 v6 地址，客户端全连不上
   - 现在改为**当场选择地址族**，语义与安装时的 `ippz` 一致：`4=仅 IPv4` / `6=仅 IPv6` / 回车=`自动`（优先 IPv4，无 v4 再退回 v6）
   - 检测失败时按所选族给出准确原因（「未检测到 IPv6 出口地址」而不是笼统的网络错误）
   - 仍不落盘：`ippz` 在脚本里本就是安装期参数，落盘会让后续 nginx 重生成时 `listen [::]` 的判断跟着变，容易把 IPv6 回源改坏

v3.2.5 (2026-10-19)
 - **新增 `[4][10] 服务器地址 (server_ip)`**：换机器 / 换出口 IP 后可直接改节点里显示的地址，不必重装
   - `1) 自动重新检测`：走 `check_ip_connectivity` 取出口 IP，地址族由当场选择（见 v3.2.6）
   - `2) 手动指定 IP`：只接受 IPv4 / IPv6（域名请走 `[4][6]`），IPv6 自动加 `[]` 落盘
   - 改完立即重生成节点链接与订阅；结果与当前值相同时直接提示「无需修改」，不做无谓重启
   - 菜单里同时显示当前 `direct_host` 状态，并说明两者关系（设了 direct_host 时直连链接用域名，server_ip 仅作回退）
 - `[4][6] 直连对外域名` 菜单补一行指引：想改「真实服务器 IP」本身去 `[4][10]`
 - 说明：`ippz`（IP 偏好 4/6/自动）**不**做成菜单项——它是安装期语义，还决定 `sb.json` 各 inbound 的 `listen` 与 nginx 是否 `listen [::]`，装完再改容易把 IPv6 回源改坏；需要时用环境变量重装

v3.2.4 (2026-10-19)
 - `[4] 节点配置修改` 里 `8) 身份信息` 的标题补充「Reality 密钥」，与新加的密钥轮换入口对应（`UUID / 名称前缀 / Socks5 账号 / Reality 密钥`）

v3.2.3 (2026-10-19)
 - **`[4][8] 身份信息` 新增「重新生成 Reality 密钥对」**（`reality_private` 此前只能安装时传入，密钥泄露后无法轮换）
   - 三处必须同步，漏一处客户端就连不上：`reality.key`（链接里的 `pbk`）、`short_id` 文件（链接里的 `sid`，由私钥 sha256 前 8 位推导）、`sb.json` 的 `tls.reality.private_key` / `short_id`
   - 先生成新密钥对 → 写入临时配置并用 `sing-box check` 校验 → 通过才落盘；校验失败不动现网配置
   - 旧密钥自动备份到 `reality.key.bak`（每次轮换覆盖）
   - 与改 UUID 一样需要输入 `yes` 二次确认，并提示「所有 Reality 节点立即失效、客户端需重新导入」
   - 菜单里直接显示当前 public key，方便和客户端对照

v3.2.2 (2026-10-19)
 - **新增 `[4][9] WS-CDN 回源协议开关`**：装完后可直接开启/关闭 vmess / vless / trojan 的 CDN 回源（此前只能带 `ws_cdn=` 重装）。CDN 回源是独立 inbound（`*-ws-cdn-sb`）+ 独立端口文件 + 独立 nginx location，开启时自动分配回源端口、追加 inbound、重生成 nginx 配置并刷新订阅；关闭时删除 inbound / 端口文件 / location，节点随即失效
   - 开启时会提示回源地址与本机 nginx 端口；若还没配置回源 SNI，会明确告知「暂时不会生成节点链接」，引导去 `[4][3]` 配置
 - 安装菜单：Socks5 安装时可选 **IP 白名单**（`socks5_wl_flag` / `socks5_ips`，支持 CIDR、逗号分隔），此前只能装完进 `[4][7]` 配
 - 安装菜单：**未开订阅但启用了 Argo / WS-CDN 回源**时，会单独询问回源 Nginx 端口（此前静默用 8080，想改只能先开一次订阅）
 - 修复 `ensure_nginx_if_needed` 只认环境变量 `ws_cdn`、不认落盘文件的问题（菜单改完 ws_cdn 后可能不触发 nginx 准备）

v3.2.1 (2026-10-19)
 - **消除脚本名硬编码，sb00.sh 与 sb.sh 现在只差 `SB_SCRIPT_NAME` 一行**：
   - 二进制版本缓存文件名由 `SB_SCRIPT_NAME` 推导（`${SB_SCRIPT_NAME%.sh}_sb_ver` / `_cf_ver` / `_ng_ver`），不再写死 `sb00_*`。sb00.sh 仍落在 `sb00_*_ver`（无需迁移），sb.sh 落在 `sb_*_ver`，两个脚本放同一目录也不会互相覆盖缓存
   - openrc 单元的 heredoc 定界符 `OPENRC_SB00` → `OPENRC_UNIT`
   - 日志轮转脚本头部注释、分流相关注释里的 `sb00` 改为 `$SB_SCRIPT_NAME` / 中性表述
   - 审计结果：全文件除 `SB_SCRIPT_NAME="sb00.sh"` 外已无 `sb00`/`SB00` 字面量，搬到 sb.sh 时只需改这一行
 - **升级提示（仅 sb.sh 用户）**：旧版 sb.sh 写的是 `sb00_*_ver`，升级后改读 `sb_*_ver`，首次打开状态面板版本号可能短暂为空（有 `timeout 3` 探测兜底，不影响功能），下次安装/更新会自动补齐。想立刻显示可执行：
   ```bash
   cd /root/doraemon && for k in sb cf ng; do [ -f sb00_${k}_ver ] && cp -p sb00_${k}_ver sb_${k}_ver; done
   ```

v3.2.0 (2026-10-19)
 - **`node` 节点配置修改菜单补齐 5 处缺口**（此前这些变量只能在安装时通过环境变量设置，装完没有入口）：
   - `[4][1] 端口修改` 新增 **Socks5 端口**（`socks5pt`）；顺带修复「改过 ws 端口后，后续改任何端口都会连带重启 nginx」的标记残留问题
   - `[4][2] 订阅设置` 新增 **开启节点订阅**（此前只能关不能开）：自动安装/配置沙箱 Nginx、放行端口、生成 `sub.txt` 并回显订阅地址
   - 新增 **`[4][8] 身份信息`**：修改 UUID、节点名称前缀、Socks5 用户名/密码
   - `[4][3] SNI / CDN 设置` 新增 **每协议专属参数**（14~25 项）：`ws_cdn_{vmess,vless,trojan}_sni` / `_cf_pt`、`argo_{vmess,vless,trojan}_cf_host` / `_cf_pt`；留空取消、输入 `-` 清除并回退共享值
   - 安装菜单补齐 **AnyTLS 伪装域名 `any_sni`**、**Socks5 端口/用户名/密码**（此前 socks5 端口永远随机、账号密码只能自动生成）
 - **改 UUID 需二次确认**：UUID 同时影响用户凭据、ws transport 路径、nginx 反代 location 与订阅地址，改动后所有已下发节点立即失效；现在会先提示影响范围，输入 `yes` 才执行
 - **修复订阅端口被悄悄改回 8080**：`setup_nginx_subscribe` 原先用 `${nginx_pt:-8080}` 取值，而 `nginx_pt` 启动时已被赋默认值，导致任何菜单触发的 nginx 重生成都会把订阅端口写回 8080（订阅地址随即 404）。现统一用 `_eff_nginx_pt` / `_eff_argo_pt` 解析：显式传入（非默认值）> 落盘 `nginx_port` / `argoport` > 默认值

v3.1.11 (2026-10-19)
 - 日志轮转扩展到沙箱 Nginx 的 `access.log` / `error.log` 与 `logs/stop_reason.log`；轮转脚本改为 `rotate_dir()` 支持多目录（nginx 同样以 `O_APPEND` 打开日志，copy-truncate 后无需 USR1 reopen）

v3.1.10 (2026-10-19)
 - **openrc 服务改用 `supervise-daemon`**：sing-box / cloudflared 崩溃后自动拉起（此前只有 `command_background=yes`，进程死掉不会重启）；systemd 单元 `Restart=on-failure` 改为 `Restart=always`
 - 小内存机器（MemTotal < 1G）自动导出 `GOMEMLIMIT`（物理内存 50%），降低 cgroup OOM 概率
 - 新增日志轮转：每小时检查 `logs/` 下日志，超过 `LOG_ROTATE_SIZE_KB`（默认 10 MB）用「复制+清空」轮转，只保留 1 份历史

v3.1.8 (2026-09-23)
 - **修复安装流程退出码误报**：脚本重定义的 `echo` 函数在非 TTY（后台/nohup 运行）时，末尾 `[ -t 1 ] && _log_write ...` 会整体返回 1，导致整个安装/覆盖安装流程以「退出码 1」收尾（终端 TTY 下则正常为 0）。现强制 `return 0`，后台安装的退出码恢复正确

v3.1.7 (2026-09-23)
 - 补充 `ins` 流程 sing-box 「已安装跳过下载」分支的版本缓存写入（与 `update_singbox` 路径一致）

v3.1.6 (2026-09-23)
 - **修复状态面板 Sing-box / Cloudflared 版本不显示**：版本改 为「安装/更新成功时落盘缓存」，状态面板优先读缓存文件（`sb00_sb_ver` / `sb00_cf_ver` / `sb00_ng_ver`），仅在缓存缺失时才执行二进制探测；彻底避免对运行中的 cloudflared 隧道反复执行 `version`（隧道运行时该探测会挂住/超时，导致版本为空）

v3.1.5 (2026-09-23)
 - **修复状态/菜单卡死**：`menu_status_block` 对 sing-box / cloudflared / nginx 的版本探测全部加上 `timeout 3` 超时保护，并改用「轮询 + 总超时 6s」代替裸 `wait`。实测 cloudflared 隧道运行时 `cloudflared version` 会永久挂起，旧版会导致状态面板卡在「获取服务状态中...」；现在探测超时自动跳过，状态面板最多延迟 6 秒
 - 探测超时后显式终止残留探测进程，确保菜单/状态任何情况下都不被卡死

v3.1.4 (2026-09-23)
 - **状态面板新增内存占用显示**：Sing-box / Cloudflared / Nginx 状态行各追加「内存: xM」（取自 `/proc/<pid>/status` 的 VmRSS）
 - Nginx 内存 = master + 全部 worker 求和，且严格按 pid 文件归属（只认本沙箱 nginx 的 pid，不按名匹配，杜绝误算系统 nginx）

v3.1.3 (2026-09-23)
 - **端口冲突提示升级**：安装/重装时若端口被外部进程（非本脚本）占用，现在会显示「占用者进程 + pid + 释放命令 `kill <pid>`」，配合 `ss -tlnp | grep :<端口>` 可一键定位释放

v3.1.2 (2026-09-23)
 - Nginx 启动失败时自动从 error.log 解析 `bind() to <ip>:<port> failed (98: Address in use)`，精确指出哪个端口被占用，并给出释放命令（`ss -tlnp | grep :<端口>` + `kill <pid>`，无 ss 时用 lsof 兜底）

v3.1.1 (2026-09-23)
 - **修复端口冲突检测误判系统 nginx 为「自有」**：按端口查占用进程时不再按 `comm=nginx`/命令行含 `nginx` 匹配（会把系统/宝塔 nginx 误认成本脚本的沙箱 nginx，导致端口冲突被跳过）；沙箱 nginx 仅通过 pid 文件归属判定

v3.1.0 (2026-09-23)
 - **沙箱 Nginx 双源下载兜底**：主源 github.com（jirutka/nginx-binaries）失败/校验不过时，自动切换备用源 cdn.jsdelivr.net（内容哈希与主源一致），每个源带重试；两个源都不行才回退旧版
 - 新增 `SB_NGINX_URL_BACKUP` 可整体覆盖备用源

v3.0.9 (2026-09-23)
 - **沙箱 Nginx 下载 SHA256 固化**：内置 x86_64 / aarch64 两个架构的静态二进制 SHA256，下载后强制校验，防供应链投毒/下载损坏；可用 `SB_NGINX_SHA256` 整体覆盖

v3.0.0 (2026-09-08)
 - **命名重构，彻底消除 `cdn_host`/`cdn_pt` 歧义**：Argo 共享改为 `argo_cf_host` / `argo_cf_pt`（专属 `argo_vmess_cf_host` 等）；CDN 回源共享改为 `ws_cdn_cf_host` / `ws_cdn_cf_pt` / `ws_cdn_sni`（专属 `ws_cdn_vmess_cf_host` / `ws_cdn_vmess_sni` 等）。**`cdn_host` / `cdn_pt` 正式退役**，仅作为旧 Argo 兼容别名，新版不再使用这两个环境变量
 - **旧用户升级零改造成本**（兼容旧版 `cdn_host` / `cdn_pt`）：
   - 旧命令传 `cdn_host=xxx cdn_pt=2083` 继续生效（→ `argo_cf_host` / `argo_cf_pt`，新名优先）
   - 旧落盘文件 `cdn_host` / `cdn_pt` / `vlvm`（单协议）升级后 `cip`/`list` 自动读取，**输出的节点串与旧版完全一致**
   - `rep` 重装时不传新名也不丢配置：旧 `cdn_host`/`cdn_pt` 文件值自动迁移到 `argo_cf_*`
 - **订阅地址完全兼容**：旧版订阅只有「Argo / http」两条分支，新版仅在配置了回源域名 `ws_cdn_sni`（或专属 `ws_cdn_{p}_sni`）时才新增「CDN 回源」订阅分支，旧用户（无 ws_cdn 文件）不受影响，订阅链接升级后保持不变
 - 落盘改为「保留/迁移」策略（`fs_write_or_keep`）：env 值>已有文件>旧名文件迁移>默认，不覆盖用户已有配置

 - **新增 ws_cdn 功能**：Vmess/Vless/Trojan WS 走 CDN 直连（不使用 Argo）
 - 新增开关 `ws_cdn=vmess,vless,trojan`（逗号分隔，可多选）；与 Argo 共存时节点两者都输出
 - 域名支持每个协议不同（适用 Cloudflare origin rule 泛域名 + 多回源域名同 A 记录）：`ws_cdn_vmess_cf_host` / `ws_cdn_vless_cf_host` / `ws_cdn_trojan_cf_host`（+ 各自 `_sni`/`_pt`）
 - 共享兜底参数：`ws_cdn_cf_host` / `ws_cdn_sni` / `ws_cdn_cf_pt`（默认 443）；优先级「协议专属 > 共享 > 默认 saas.sin.fan/443」
 - 复用现有本地 ws 端口（port_vm_ws / port_vl_ws / port_tr）与 nginx 反代（/${uuid}-vm/-vl/-tr），**不新增端口文件 / 不新增 inbound / 不新增 nginx location**
 - CDN 回源端口 = 服务器 `nginx_pt`（默认 8080）；nginx 安装条件与 8080 防火墙放行加入 ws_cdn 场景
 - 订阅地址新优先级（show_sub_url）：固定 Argo（隧道存活）> 共享回源域名 ws_cdn_sni > 专属回源域名 ws_cdn_{p}_sni > 临时 Argo > http；支持 `sub_domain=argo/cdn` 强制指定
 - 新增生效值解析函数 `ws_cdn_val / ws_cdn_eff_host/sni/pt / ws_cdn_proto_enabled`；配置落盘 + 环境变量优先
 - 交互菜单新增「Vmess/Vless/Trojan WS 走 CDN 直连」选择块（多选协议 + 逐协议回源域名 + 共享 host/sni/端口）
 - 安全：所有动态赋值（落盘/菜单注入）改用间接展开 + `printf -v`，不再用 `eval`
 - 顺带修复：端口设置菜单按 `vmag` 判断是否需要 Argo 端口（此前 ws_cdn 触发 vmp/vlp/trp 会误问 Argo 端口）

 - **Argo 协议由「三选一」升级为「可多选」**：`argo=vmess,vless` 等任意组合（逗号分隔）；cip 显示 / jh.txt / 订阅 / nginx 反代均按多协议输出对应节点，每个节点可用不同优选域名/端口
 - 新增每协议 Argo 专属优选域名/端口：`argo_vmess_cf_host` / `argo_vmess_cf_pt`、`argo_vless_cf_host` / `argo_vless_cf_pt`、`argo_trojan_cf_host` / `argo_trojan_cf_pt`；未填回退共享 `argo_cf_host` / `argo_cf_pt`
 - 共享 CF 优选域名/端口变量由 `cdn_host` / `cdn_pt` 更名为 `argo_cf_host` / `argo_cf_pt`（旧名 `cdn_host` / `cdn_pt` 继续兼容，新名优先），脚本内部节点生成/回退逻辑仍用归一化值
 - 修复 WS-CDN 回源节点链接 path 缺少 `-cdn` 后缀（此前与 nginx 反代 / inbound 的 `/{uuid}-{p}-cdn` 不匹配，导致 ws_cdn 节点无法回源）
 - CLI 交互菜单：Argo 选择支持多选（f/g/v 组合），新增「Argo CF 优选域名/端口 统一或分开」填写环节；Argo 协议切换菜单改为逐个 toggle
 - 分流管理（socks/http 附着协议、查看代理出口）补充支持 WS-CDN 独立 inbound（`vmess-ws-cdn-sb` / `vless-ws-cdn-sb` / `trojan-ws-cdn-sb`）

v2.0.2 (2026-09-07)
 - **安全加固**
 - 新增 root 权限检查：非 root 运行直接拒绝（脚本会写 /root、/etc/systemd、(openrc) init.d、/etc/iptables 等系统目录）
 - 安装日志权限收紧：`logs/` 目录 700、`install.log` 600（日志内含 UUID / reality 私钥 / socks5 口令，旧版默认 644 世界可读）
 - 修复维护命令污染安装日志：`list`/`cip` 等场景直写 `install.log` 改由 `INSTALL_LOGGING` 控制，不再破坏"仅保留最近一次安装"
 - Argo token 落盘权限收紧：systemd `/etc/systemd/system/argo.service` / openrc `/etc/init.d/argo` 现在 chmod 600，旧版 644 任何本地用户可窃取隧道 token
 - **修复 `sb.json` 改写后权限回落 644**：分流管理 / 改端口 / 改 SNI / 增删代理等 25+ 处 `jq > tmp && mv` 写回统一走新增的 `sbj_save()`（校验 tmp 为合法 JSON + 强制 chmod 600），`sb.json` 内含全部协议口令
 - uuid 增加字符集校验（仅允许 `[0-9a-fA-F-]`）：用户传入 uuid 会拼进 nginx location 与订阅路径，防换行/控制符配置注入
 - 快捷命令 wrapper 加固（`gen_online_wrapper()`）：执行前校验被拉取脚本含 `VERSION` 声明（拦截错误页/被篡改内容）、版本与生成时不一致给出提示（发现 raw.githubusercontent CDN 缓存 / 拉取异常）；顺带修复 `singbox` wrapper 依赖未导出 `SINGBOX_FOLDER_PATH` 导致永远走在线拉取的 bug
 - 移除"把含账号密码的代理 URL 发给第三方检测 API（check.socks5.cmliussss.net）"的逻辑，改本机 curl 穿代理自测，凭据只到达代理本身
 - 新增可选下载校验和：设置 `SINGBOX_ARCHIVE_SHA256` / `CLOUDFLARED_SHA256` 环境变量可强制校验 sing-box / cloudflared 下载文件（未设置则维持原有 内容嗅探 + 结构 + 版本号 校验）
 - 地区查询（ip-api.com）改为 https 优先、失败回退 http
 - **功能 / Bug 修复**
 - nginx 订阅端口加入防火墙：`apply_singbox_iptables_rules` 在 subscribe=true 或启用 Argo 时为 nginx_pt 添加 ACCEPT；新增统一 `refresh_firewall_rules()`（flush + 重放 + 白名单 + 保存），`ins`、端口修改菜单、订阅端口修改菜单统一调用，修复「改端口后防火墙不刷新、新端口被挡旧端口仍放行」的问题
 - 端口占用检测内存化：`SB_TAKEN_PORTS` 改用关联数组 O(1) 查重；`rand_port` 用启动时 ss 快照预筛 + 实时 ss 兜底（安装等集中分配流程省去重复 fork，交互菜单等长停留场景仍实时检测保证准确）
 - 修复未安装时 `list`/`sub`/`node`/`rt`/`logs` 等维护命令被"至少设置一个协议变量"守卫误拦的问题（仅 ins/rep 强制要求）
 - 修复 vless-ws 端口复用在 `port_vm_ws` 为空文件时端口为空、jq `tonumber("")` 失败导致 vless-ws 入站静默丢失的边界 bug

v2.0.1 (2026-09-06)
 - argo 取值变更为 `vmess / vless / trojan`（支持多选，逗号分隔，如 `argo=vmess,vless`）；旧值 `vmpt/trpt/vlpt` 彻底废弃，不再读取
 - 外部传入非法 argo（含旧值）在安装/覆盖安装时直接提示并退出；已落盘配置（vlvm）依然认可
 - vmess/trojan/vless 的启用完全由 `argo=` 决定；三个协议本地回源端口不接受外部指定，由脚本自动随机（或复用落盘 port_*），天然适配 NAT 机
 - 新增端口占用登记机制：随机端口自动避开「显式端口 / 服务端口(nginx_pt/argo_pt) / 已落盘 port_* / 本机正在监听的端口」，杜绝多协议端口互撞
 - 交互菜单 Argo 协议选择改为直接设置 argo 新值，端口设置不再询问 argo 三端口
 - 安装日志新增打印 `Argo协议: xxx`；协议端口打印在 `DEBUG_FLAG=1` 时附带其落盘文件提示
 - Nginx 安装条件明确：subscribe=true **或** 启用 Argo 都会安装 Nginx（Argo 回源走 Nginx 反代）
 - README 同步新取值与示例；新增 Nginx 何时安装速查表
 
v1.0.30 (2026-09-05)
 - **安全加固**
 - **修复 reality_private 被忽略的问题**：本地推导公钥不再依赖 `xxd`（Debian 12/13 起 `/usr/bin/xxd` 是独立 `xxd` 包，`vim-common` 不再提供），改用 `openssl pkey -inform DER` 直接读 PKCS#8 DER，只要 openssl 在即可推导。旧版在无 xxd 的环境会推导失败→静默生成新 keypair，导致传了 `reality_private` 却节点不一致
 - 删除 Reality 私钥在线推导兜底：旧版本地推导失败时会通过 `?privateKey=` 把私钥明文发给第三方（realitykey.cloudflare.now.cc），现改为直接失败并回退生成新 keypair，私钥不再外发
 - Argo 凭据/域名校验：新增 `is_valid_domain` / `is_valid_argo_token`（含嵌入换行/CR 校验，防 grep 跨行绕过），非法 token/域名拒绝写入 systemd ExecStart / openrc command_args / tunnel.yml（防命令与配置注入）
 - 二进制下载完整性运行时校验：sing-box（拦截 HTML 错误页、校验归档内含 sing-box 二进制、版本必须等于 1.13.14）、cloudflared（拦截 HTML 错误页、`--version` 必须可解析）
 - 凭据文件统一 chmod 600：tunnel.json / tunnel.yml / sbargotoken / argo_domain / reality.key / uuid / sb.json / jh.txt
 - Socks5 白名单 IP/CIDR 格式校验（`is_valid_cidr`）：非法条目跳过并警告；全部非法时报错，不再"显示已开启但实际未生效"
 - 订阅走明文 HTTP 时打印风险警告（订阅 URL 内含全部节点口令，仅建议可信网络使用）
 - `setenforce 0` 仅在 SELinux=Enforcing 时执行并打印提示，不再静默关掉 SELinux
 - 交互输入 Argo token / reality_private 改用 `read -s` 静默输入，防终端回显
 - pkill/pgrep 匹配收窄到本脚本安装路径，避免误杀系统中其他同名进程
 - crontab 清理改用 `mktemp` 临时文件，消除固定路径 `/tmp/crontab.tmp` 的符号链接攻击面
 - **Bug 修复**
 - 修复 Alpine(openrc) `sb autostart` 生成损坏的 init 脚本：heredoc 内 `${name}`/`$command`/`$pidfile`/`$command_args`/`$?` 被 bash 提前展开为空，start/stop 全部失效
 - 随机端口避开已在监听的 TCP/UDP 端口（ss 检测 + 最多重试 20 次）
 - 端口冲突检查新增"系统已监听端口"提示（本脚本栈自带的 sing-box/cloudflared/nginx 监听不计为冲突，避免 rep 覆盖安装时旧实例被误报）
 - 节点链接 fragment 统一 URL 编码：`name` 中的空格 / `#` / `?` / `&` 不再破坏链接；vmess 节点的 `ps`/`add`/`host`/`sni` 字段做 JSON 转义
 - `append_jh` 改用 `printf` 写订阅文件，防 `\n`/`\x` 转义注入订阅内容；节点名清洗掉 CR/LF
 - 删除死代码：`setup_warp_config` / `singbox_status` / `interactive_uninstall_menu`
 - 版本号推进为 1.0.30

v1.0.29 (2026-08-27)
 - **修复覆盖安装会清除所有 iptables 规则的 bug**：旧版 `install_step()` 中 `iptables -F` 会暴力清除所有防火墙规则（包括其他程序添加的），现改为仅清除本脚本标记的规则
 - 新增 iptables/ip6tables 规则标记体系：所有协议端口标记 `doraemon_singbox_rule`，白名单 socks5 标记 `socks5_rule`，通过 `--comment` 精确识别
 - 新增 `apply_singbox_iptables_rules()`：为所有协议端口（vmess/trojan/vless/socks5）添加 iptables ACCEPT 规则
 - 重构 `flush_singbox_iptables_rules()`：统一清除两种标记的所有规则，卸载/覆盖安装时不影响其他程序
 - 白名单实现从 sing-box `route.rules` 改为 iptables/ip6tables：在 TCP 层直接拦截非白名单 IP 的连接，同时支持 IPv4/IPv6
 - 版本号推进为 1.0.29

v1.0.26 (2026-08-26)
 - 新增 Socks5 IP白名单功能：通过 `socks5_wl_flag`（开关）和 `socks5_ips`（IP列表）控制，仅白名单中的源 IP 可访问 Socks5 入站
 - 安装时通过环境变量传入，安装后可通过交互菜单 `node → Socks5 IP白名单管理` 开关、修改 IP 列表
 - 大小写不敏感：`true`/`True`/`TRUE`/`1` 均可识别为开启

v1.0.24 (2026-08-25)
 - **修复 Reality 私钥 base64 编码不兼容导致 sing-box 启动失败**：旧版 reality.key 使用标准 base64（`+`/`/` + `=` 填充），sing-box 1.13+ 期望 URL-safe base64（`-`/`_` + 无填充），密钥中 `+` 字符在解码时被拒绝
 - 新增 `_to_urlsafe_base64()` 自动转换函数，读取密钥时自动将标准 base64 转为 URL-safe base64
 - 覆盖所有密钥读取路径：`init_reality_keypair()` / `ensure_and_print_reality_private_for_cip()` / `regenerate_links_and_sub()`
 - `sbbout()` 启动前预创建 singbox.log，启动后 3 秒检测日志文件是否生成


v1.0.23 (2026-08-25)
 - sbbout() 启动前预创建 singbox.log，确保 sing-box 启动时文件已存在
 - 启动后 3 秒检测日志文件是否生成，为空显示黄色警告提示

v1.0.22 (2026-08-25)
 - 修复 sbrestart/argorestart：systemd 下不再手动 pkill，避免进程脱离 cgroup 导致服务重启后显示"已停止"
 - 新增 capture_stop_reason()：服务异常停止时自动从 journalctl/dmesg/应用日志捕获原因，写入 `doraemon/logs/stop_reason.log`
 - 新增 `sb log_stop` 快捷命令 + 菜单项查看停止原因
 - cleandel 优化：systemctl stop 加 timeout 5 超时保护，清理流程每阶段添加进度提示（▸→✓）

v1.0.21 (2026-08-25)
 - 新增日志查看快捷命令：`sb logs`（菜单）、`sb log_sb`、`sb log_argo`、`sb log_ins`（可带行数，如 `sb log_sb 100`）
 - 提取 show_log_file() 公共函数供菜单与 CLI 共用
 - cleandel 删除冗余 /proc/[0-9]* 遍历循环（每个进程 2 次 fork 导致 ~6s 卡顿），已被 pkill 等效覆盖

v1.0.20 (2026-08-25)
 - 所有日志归拢到 `doraemon/logs/` 子目录（install.log / singbox.log / argo.log / deps_failed.log / nginx_install.log）
 - 新增 migrate_logs_dir()：老安装自动将根目录散落日志迁移到 logs/，systemd 句柄无缝衔接
 - cleandel 保留列表从 `sing-box|cloudflared|install.log` 改为 `sing-box|cloudflared|logs`（整个日志目录保留）
 - 菜单日志子菜单同步更新

v1.0.19 (2026-08-25)
 - 新增脚本安装日志系统（ins/rep/菜单安装全流程记录），零管道零终端干扰
 - 颜色函数钩子 + echo 钩子双写纯文本到 `doraemon/install.log`
 - 日志菜单重构：支持按时间/行数/关键字过滤查看，支持清空与复制路径
 - 新增 `DEBUG_FLAG=1` 环境变量开启调试模式，所有调试输出写入 `doraemon/debug.log`
 - cleandel 保留 install.log 不被清理
 - install_deps 改为实时逐行输出（去管道化），日志同步记录失败依赖

v1.0.15 (2026-08-08)
 - Argo 隧道协议由 vmess/trojan 二选一升级为 vmess/trojan/vless 三选一
 - 新增 vless argo 支持：`argo=vless` 启用（vless-ws 走 Argo）
 - 安装菜单 / 端口修改菜单 / Argo 协议切换菜单 / 分流管理均支持 vless
 - nginx 订阅新增 `/${uuid}-vl` 反代，vless argo 链接自动输出到订阅与 jh.txt

v1.0.14 (2026-08-07)
 - 支持交互式菜单操作
 - 支持 `sb` 快捷指令：安装后直接 `sb` 打开主菜单，或 `sb ins`/`sb rep`/`sb list`/`sb rt`/`sb node`/`sb sub`/`sb del` 等一步直达对应功能
 - 支持内置代理 / 分流管理
 - 方便对接代理 [jyucoeng/aimili-vpngate](https://github.com/jyucoeng/aimili-vpngate)，该项目的代理出口为家宽 IP，可让节点使用家宽出口

v1.0.13
 - sing-box 内核（1.13.14）下载源切换到本仓库 jyucoeng/singbox-tools（release: v1.13.14）
 - 新增 .github/workflows/sync-singbox.yml：手动触发，从上游镜像 4 个 linux 二进制包（amd64/arm64 及 musl 变体）到本仓库 release

v1.0.12
 - `del` 改为保留 sing-box/cloudflared 二进制（只删配置），新增 `delall` 命令完全删除
 - `rep` 复用已有二进制，不再每次重新下载；`upsingbox` 增加版本检测，版本一致则跳过下载
 - 新增 Alpine 自动适配：自动安装 bash、下载 musl 版 sing-box、使用 OpenRC 管理服务
 - 优化 geo IP 查询：v4/v6 并发探测，超时从 5s→3s，不再卡住后续流程

v1.0.11
 - hy2协议增加指纹锁定，防止被篡改

v1.0.10
 -  singbox 内核版本文件适配

v1.0.9
 - 改用官方 sing-box 1.13.14（默认含 WireGuard）
 - 移除 `sniff: true` 适配新版 sing-box 1.13+
 - 修改socks5的socks5_username 和socks5_password环境变量名称（之前没添加socks5前缀）
 - socks5 密码自动生成改为纯字母数字，不再含特殊符号

v1.0.8
 - 新增 socks5 协议支持，可与其他协议自由组合,把一些 sni的默认值由  www.microsoft.com 改为 www.apple.com 

v1.0.7
 - 新增 anytls 协议支持，可与其他协议自由组合

v1.0.6  
 - 去掉快捷指令agsb，以及将主目录名称由agsb 变更为doraemon，用新脚本卸载之前部署好的功能的时候，会把/root/doraemon 和/root/agsb文件夹都删除.

---

## 2.8 感谢以下开发者的贡献

- [77160860大佬](https://github.com/77160860/proxy)










