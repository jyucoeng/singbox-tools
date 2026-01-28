## mtproxy用法示例：

### 1、安装服务（交互式或非交互式）：

#### 未PORT设置（交互式安装，会显示菜单）：
```
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/mtp.sh)
```

#### 非交互式安装
```
PORT=31009 bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/mtp.sh)
```

### 高级用法

```
PORT=32000 DOMAIN='你的伪装域名,不填默认为www.microsoft.com' IP_MODE='v4/v6/dual' INSTALL_MODE='go/py' SECRET='' PORT_V6='?'   bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/mtp.sh) rep
```

## 环境变量说明

#### 1️⃣、  PORT= 端口号 （填写了就是非交互式安装，不填就是为菜单式安装，）

#### 2️⃣、 DOMAIN='www.microsoft.com' （伪装域名，不填就默认为 www.microsoft.com ）

#### 3️⃣、  IP_MODE='?' 

**值含义**
- v4 → 使用ipv4监听端口（不填默认使用v4）
- v6 → 使用ipv6监听端口
- dual → 使用ipv4和ipv6同时监听端口

#### 4️⃣、 INSTALL_MODE='?'  (安装方式,go版或者python版)

**值含义**
- go → 使用go版安装(不填默认使用go版安装,强烈推荐安装这个)
- py → 使用python版安装


#### 5️⃣、 SECRET='?'  (安装密钥,不会就留空，留空就随机产生密钥,因为go版的时候，密钥里面会包含域名信息，所以，不会请不要乱填)



#### 6️⃣、 PORT_V6='?'  (当IP_MODE='dual'时，PORT_V6才会启用「而且是python模式下才有用-只有pyhton版的dual才支持分端口，go版，这个参数直接默认等于v4端口」，IP_MODE='dual'，如果PORT_V6不填，则 PORT_V6会取PORT的值)


#### 7️⃣、 脚本后边的rep、list参数代表覆盖安装和查看节点信息，ins参数或者什么都不跟的时候代表默认安装。


### 2、卸载已安装的服务：
```
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/mtp.sh) del
```

### 3、列出已安装服务的详细信息：
```
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/mtp.sh) list
```

### 4、启动已安装的服务：
```
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/mtp.sh) start
```

### 5、停止已安装的服务：
```
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/mtp.sh) stop
```
### 6、重启已安装的服务：
```
 bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/mtp.sh) restart
```


## 感谢
感谢以下开发者的贡献：

- [0xdabiaoge大佬](https://github.com/0xdabiaoge/MTProxy)