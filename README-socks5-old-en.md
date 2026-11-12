[简体中文](README-socks5-old.md) | **English**

# socks5 install script


## 1、 socks5 install and uninstall
 1.1、Install (supports overwrite installation; if the port number is not specified, a random port will be used, and if the username and password are not specified, they will be randomly generated as well):
 ```bash
 PORT=PORT_NUMBER USERNAME=USERNAME PASSWORD=PASSWORD bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/socks5.sh)
```

1.2、socks5 uninstall:
 ```bash
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/socks5.sh) uninstall
 ```

1.3、socks5 node viewing:
 ```bash
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/socks5.sh) node
 ```



## Test whether socks5 works
Run the following command; if it correctly returns the server IP, the node works

#### ipv4 version of socks5 (for ipv6, change `curl -4` to `curl -6` accordingly)
```  
curl -4 -sS --connect-timeout 8 --max-time 15 \
  --socks5-hostname your-socks-server-ip:your-socks-port \
  -U 'username:password' \
  https://api.ipify.org ; echo

```
Or
 open the URL below to verify

https://iplau.com/category/ip-detection-tool.html
