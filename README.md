# sing-box 一键部署脚本

支持 VMess / Trojan / Hysteria2 / VLESS Reality 协议，支持 Cloudflare Argo Tunnel

## 核心特性

- 支持 4 种主流协议
- 支持 1–4 协议任意组合
- 支持 VMess / Trojan 双 Argo 同时运行
- 自动生成 UUID、证书、Reality Key
- 支持 Debian / Ubuntu / Alpine

## 协议端口变量

| 协议 | 端口变量 | 说明 |
|------|----------|------|
| VMess WS | vmpt | VMess WebSocket 监听端口 |
| Trojan WS | trpt | Trojan WebSocket 监听端口 |
| Hysteria2 | hypt | Hysteria2 UDP 端口 |
| VLESS Reality | vlrt | VLESS Reality 监听端口 |

> ⚠️ 传入端口号即启用对应协议

## 通用变量

| 变量 | 说明 |
|------|------|
| uuid | 四协议共用 UUID（不传自动生成） |
| cdn | CDN / SNI 域名（HY2、VLESS Reality 建议设置，如果不设置将会默认使用 www.bing.com ） |

## 使用示例

### 单协议部署

**VMess WS**
```bash
vmpt=2080 \
uuid="你的UUID" \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/agsb.sh)
```

**Hysteria2**
```bash
hypt=2082 \
uuid="你的UUID" \
cdn="www.cloudflare.com" \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/agsb.sh)
```

### 多协议部署

**VMess + Trojan**
```bash
vmpt=2080 \
trpt=2081 \
uuid="你的UUID" \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/agsb.sh)
```

**4协议全开**
```bash
vmpt=2080 \
trpt=2081 \
hypt=2082 \
vlrt=2083 \
uuid="你的UUID" \
cdn="www.cloudflare.com" \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/agsb.sh)
```

## Cloudflare Argo 隧道（可选）

Argo是入口方式，不是协议，最多支持2个（VMess/Trojan各1个）

| 变量 | 说明 |
|------|------|
| argo_vm_flag | 启用 VMess Argo |
| ag_vm_domain | VMess Argo 绑定域名 |
| ag_vm_token | VMess Argo Token |
| argo_tr_flag | 启用 Trojan Argo |
| ag_tr_domain | Trojan Argo 绑定域名 |
| ag_tr_token | Trojan Argo Token |

**双Argo示例**
```bash
vmpt=2080 \
trpt=2081 \
uuid="你的UUID" \
cdn="www.cloudflare.com" \
argo_vm_flag=1 \
ag_vm_domain="vm.example.com" \
ag_vm_token="VM_ARGO_TOKEN" \
argo_tr_flag=1 \
ag_tr_domain="tr.example.com" \
ag_tr_token="TR_ARGO_TOKEN" \
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/agsb.sh)
```


# 感谢开发者（改写自他的脚本，他的是argo 2选1）

http://github.com//77160860/proxy