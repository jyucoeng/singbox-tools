# socks5 安装脚本

============================================================

## 1、 socks5 安装以及卸载
 1.1、安装（可覆盖安装，端口号不指定则会随机端口，用户名和密码不指定也会随机生成）：
 ```bash
 PORT=端口号 USERNAME=用户名 PASSWORD=密码 bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/socks5.sh)
```

1.2、socks5 卸载：
 ```bash
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/socks5.sh) uninstall
 ```

1.3、socks5 节点查看：
 ```bash
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/socks5.sh) node
 ```



## 测试socks5是否通畅
运行以下命令，若正确返回服务器ip则节点通畅

#### 带用户名密码版的ipv4 socks5（如果ipv6，请对应把curl -4 改成curl -6）
```  
curl -4 -sS --connect-timeout 8 --max-time 15 \
  --socks5-hostname 你的socks服务器ip:你的socks端口 \
  -U '用户名:密码' \
  https://api.ipify.org ; echo

```
或者
 打开下方网址验证

https://iplau.com/category/ip-detection-tool.html

