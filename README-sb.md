# sing-box 一键安装脚本

支持两种安装方式：

- **交互式**：直接运行 `bash sb.sh`（不带参数），按菜单提示完成安装、卸载、查看等操作。
- **非交互式**：用环境变量 + 参数一行完成（见下方示例），也可搭配 [命令生成版界面](https://singbox.dingdang.de5.net/) 使用。

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
uuid=0631a7f3-09f8-4144-acf2-a4f5bd9ed200 \
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
trojan://0631a7f3-09f8-4144-acf2-a4f5bd9ed281@cdns.doon.eu.org:8443?...
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
uuid=0631a7f3-09f8-4144-acf2-a4f5bd9ed281 \
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
uuid=0631a7f3-09f8-4144-acf2-a4f5bd9ed200 \
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
sb del             卸载（保留二进制）
sb delall          卸载全部并清理
sb ups             更新 sing-box 内核
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

## 2.7 版本变更信息

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










