#  singbox 一键安装脚本
# 1、 singbox 安装以及卸载
## singbox 一键安装脚本（4协议，vmess argo/trojan argo +hy2+vless-Reality+tuic，这些协议可自由组合）

# 环境变量说明

## ① uuid=XXXX-xxx-XXXX（可传，也可不传）

**含义**
- 不传uuid → 脚本自动生成 UUID
- 传uuid → 使用你指定的 UUID

## ② argo（Cloudflare Argo 开关）

- 当argo=vmpt 表示启用vmess的argo转发
- 当argo=trpt 表示启用trojan的argo转发
- 或者这个argo参数留空，表示不启用argo

⚠️ Argo 只能用于 VMess / Trojan

❌ 对 hypt / vlrt /tupt无效

## ③ agn / agk（Argo 固定隧道）

- agn="argo固定隧道域名"
- agk="argo隧道token"

- 当agk为普通字符串的场景：agk的值用英文双引号包裹""
- 当agk的值为json格式的时候，agk值只能用英文单引号包裹''

**是否必须？**
- ❌ 不传 → 临时 Argo（trycloudflare）
- ✅ 只有你自己有 CF Tunnel才传

## ④ cf_host、hy_sni、vl_sni（cdn域名 和 各协议的伪装域名，可选） **注意：这几个值不会填的话就不要瞎传

### 用在以下地方(argo场景的端口我固定写死了443端口):
—— VMess Argo：
"add":"${cf_host}"

——  Trojan Argo：
trojan://${uuid}@${cf_host}:443?...




## ⑤ ippz（IP显示策略，可选）

| 值 | 含义 |
|----|-----|
| 4  | 强制使用 IPv4 |
| 6  | 强制使用 IPv6 |
| 空 | 自动判断 |

> 👉 只影响 节点输出，不影响服务运行

## ⑥ name（节点名称前缀）

- 不传 → 默认 hostname
- 传 → 节点名前加前缀

**例子：**
- name=HK
- ➡ HK-vmess / HK-vless

# 常见组合调用方式

## 组合1️⃣、 仅 1个直连协议（不走 Argo,hypt与vlrt、tupt这几个端口参数选一个来写）

### 只要hy2协议

```bash
hypt=2082 \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh)
```

### 只要vless Reality协议

```bash
vlrt=2083 \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh)
```

### 只要tuic协议

```bash
tupt=2082 \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh)
```

## 组合2️⃣、 仅 2个直连协议（不走 Argo,hypt与vlrt参数都写，代表hy2和vless-reality 协议都会出来）

```bash
hypt=2082 \
vlrt=2083 \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh)
```

## 组合3️⃣、 VMess  Argo/ Trojan  Argo（最常用，2个协议选一个）

```bash
ippz=4 \
trpt=41003 \
argo=trpt \
agn="test-trojan.xxxx.xyz" \
agk="ey开头的那一串" \
name="小叮当-韩国春川"  \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh)
```

### 当使用trojan Argo时

```bash
ippz=4 \
trpt=41003 \
argo=trpt \
agn="test-trojan.xxxx.xyz" \
agk="ey开头的那一串" \
name="小叮当-韩国春川"  \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) 
```

## 当使用trojan Argo时

```bash
ippz=4 \
trpt=41003 \
argo=trpt \
agn="test-vmess.xxxx.xyz" \
agk="ey开头的那一串" \
name="小叮当-韩国春川"  \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) 
```

## 4️⃣ 、VMess + Hysteria2+ vless

```bash
ippz=4 \
hypt=41001 \
vlrt=41002 \
vmpt=41003 \
argo=vmpt \
agn="test-vmess.xxxx.xyz" \
agk="ey开头的那一串" \
name="小叮当-韩国春川"  \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) 
```


## 5️⃣、我自己的测试用例（4协议，hy2+vless+tuic+trojan Argo）

### argo tunnel的token为普通字符串的场景：
```bash
uuid=0631a7f3-09f8-4144-acf2-a4f5bd9ed281 \
ippz=4 \
trpt=41003 \
hypt=41001 \
vlrt=41002 \
tupt=41005 \
argo=trpt \
agn="test-tr.xxxx.xyz" \
agk="ey开头的那一串" \
name="小叮当-韩国春川"  \
cdn_host="www.visa.com" \
hy_sni="time.js" \
vl_sni="www.yahoo.com" \
tu_sni="time.js" \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh)  rep
```



### argo tunnel的json token的场景：（请一定要记得json格式的时候，要用英文单引号包裹起来）

```bash
uuid=0631a7f3-09f8-4144-acf2-a4f5bd9ed281 \
ippz=4 \
trpt=41002 \
vlrt=41003 \
hypt=41004 \
tupt=41005 \
argo="trpt" \
agn="northCarolina.xxxx.xyz" \
agk='{"AccountTag":"xxxxxxxxxxxxxx","TunnelSecret":"xxxxxxxxxxxxxx","TunnelID":"xxxxxxxxxxxxxx","Endpoint":""}' \
name="小叮当-美国北卡"  \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh) rep
```




## 解释一下上面那一大堆参数：

 0、 如果bash后面跟了一个参数 rep（如果没写这个参数默认视为安装），代表覆盖式安装，你可以用这个改成其他功能，比如del 代表 卸载, list 代表 查看节点，具体有哪些值你可以跑一次安装脚本你就知道怎么用了。

 1、uuid 不传的时候会自动生成

 2、 ippz ip显示策略，不影响服务

 3、 各种端口
   ```bash
   trpt=41003 \
   hypt=41001 \
   vlrt=41002 \
   tupt=41005 \
   vmpt=41004 \
   ```
     这4个分别为trojan、hy2、vless、tuic、vmess的端口

4、argo 代表使用的是哪一个协议作为argo，只能是一下三种值

    - 当argo=vmpt 表示启用vmess的argo转发
    - 当argo=trpt 表示启用trojan的argo转发
    - 或者这个argo参数留空，表示不启用argo

5、agn 和 agk 分别为隧道域名和隧道 token.

    -当token为普通字符串的场景：token的值用英文双引号包裹"".
    
    -当token的值为json格式的时候，token值用英文单引号包裹''.

6、 name 节点名称前缀（后缀会用各协议简写区分）

7、cdn_host 指的是用argo时的cf域名，缺省值为cdn.7zz.cn，你可以自己传你要的值，比如 www.visa.com 。 不传就会使用缺省值做兜底。

8、hy_sni 指的是用hy2协议的sni（伪装域名），缺省值为www.bing.com，你可以自己传你要的值，比如 time.js 。 不传就会使用缺省值做兜底。

9、vl_sni 指的是用vless协议的sni(伪装域名)，缺省值为www.ua.edu，你可以自己传你要的值，比如 www.yahoo.com 。 不传就会使用缺省值做兜底。

10、vl_sni 指的是用vless协议的sni(伪装域名)，缺省值为www.ua.edu，你可以自己传你要的值，比如 www.yahoo.com 。 不传就会使用缺省值做兜底。

11、argo的默认端口443（这个暂时不让修改，所以你换 cdn_host参数的值的时候注意一下是443端口才能支持）

12、所有的协议都出输出到聚合节点文件中: cat /root/agsb/jh.txt

## 如何卸载呢？
```
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/sb.sh)  del
```
## 以此类推，最后给一下协议组合吧

| 你设置了什么                   | 实际生成的节点                                          |
| ---------------------------- | ----------------------------------------------------- |
| hypt                         | 1（hy2）                                              |
| vlrt                         | 1（vless）                                            |
| tupt                         | 1（tuic）                                             |
| vmpt                         | 0（无直连）                                           |
| trpt                         | 0（无直连）                                           |
| vmpt + argo=vmpt             | 1（Argo-vmess）                                       |
| trpt + argo=trpt             | 1（Argo-trojan）                                      |
| hypt + vlrt                  | 2（hy2和vless直连）                                   |
| hypt + vlrt + tupt           | 3（hy2、vless、tuic直连）                             |
| hypt + vlrt + argo           | **3（hy2、vless直连+Argo-vmess或者Argo-trojan）**         |
| hypt + vlrt + tupt + argo    | **4（hy2、vless、tuic直连+Argo-vmess或者Argo-trojan）**   |

## 感谢
感谢以下开发者的贡献：

- [77160860大佬](https://github.com/77160860/proxy)

