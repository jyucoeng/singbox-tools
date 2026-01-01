# Sing-box 一键安装脚本

提供多种协议的一键安装脚本，包括 Hysteria2、TUIC v5 和 VLESS Reality。

## 脚本列表

- `hy2.sh` - Sing-box Hysteria2 一键安装脚本
- `tuic5.sh` - Sing-box TUIC v5 一键安装脚本  
- `vless-reality.sh` - Sing-box VLESS Reality 一键安装脚本

## 安装方式

### 1. Hysteria2 (hy2.sh)

#### 交互式菜单安装：
```bash
curl -fsSL https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/hy2.sh -o hy2.sh && chmod +x hy2.sh && ./hy2.sh
```

#### 非交互式全自动安装:
```bash
PORT=31020 NGINX_PORT=31039 RANGE_PORTS=40000-41000 NODE_NAME="小叮当的节点" bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/hy2.sh)
```

### 2. TUIC v5 (tuic5.sh)

#### 交互式菜单安装：
```bash
curl -fsSL https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/tuic5.sh -o tuic5.sh && chmod +x tuic5.sh && ./tuic5.sh
```

#### 非交互式全自动安装:
```bash
PORT=31020 NGINX_PORT=31021 RANGE_PORTS=40000-41000 NODE_NAME="小叮当的节点" bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/tuic5.sh)
```

### 3. VLESS Reality (vless-reality.sh)

#### 交互式菜单安装：
```bash
curl -fsSL https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/vless-reality.sh -o vless-reality.sh && chmod +x vless-reality.sh && ./vless-reality.sh
```

#### 非交互式全自动安装:
```bash
PORT=31090 SNI=www.visa.com NODE_NAME="小叮当的节点" bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/vless-reality.sh)
```

> 注意：未提供 PORT / NGINX_PORT 时，脚本将暂停并提示输入（不会直接失败）

## 支持的环境变量

### hy2.sh 支持的环境变量：
- `PORT` - 必填，HY2 主端口（UDP）
- `NGINX_PORT` - 必填，订阅端口（TCP）
- `UUID` - 可选，用户UUID
- `RANGE_PORTS` - 可选，跳跃端口范围
- `NODE_NAME` - 可选，节点名称

### tuic5.sh 支持的环境变量：
- `PORT` - 必填，TUIC 主端口（UDP）
- `NGINX_PORT` - 必填，订阅端口（TCP）
- `UUID` - 可选，用户UUID
- `RANGE_PORTS` - 可选，跳跃端口范围
- `NODE_NAME` - 可选，节点名称

### vless-reality.sh 支持的环境变量：
- `PORT` - 必填，VLESS 监听端口（TCP）
- `NGINX_PORT` - 必填，订阅端口（TCP）
- `UUID` - 可选，用户UUID
- `NODE_NAME` - 可选，节点名称
- `SNI` - 可选，SNI 值
- `REALITY_PBK` - 可选，Reality 公钥
- `REALITY_SID` - 可选，Reality 短ID

## 特性

- 支持自动 / 交互模式
- 支持跳跃端口（hy2 和 tuic5）
- 支持自定义节点名称
- 自动配置防火墙
- 支持订阅服务
