[简体中文](README-mtp-old.md) | **English**

## mtproxy usage examples (old script mtp-old.sh):

> **⚠️ This document corresponds to the old script `mtp-old.sh`**, which only retains the legacy installation method (including the Python version).
> The new version has more features (multi-user management, traffic quota, expiration date, rate limiting, etc.); it is recommended to use `mtp-new.sh` as described in [README-mtp-new-en.md](README-mtp-new-en.md).

### 1、Install the service (interactive or non-interactive):

#### No PORT set (interactive installation, a menu will be shown):
```
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/mtp-old.sh)
```

#### Non-interactive installation
```
PORT=31009 bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/mtp-old.sh)
```

### Advanced usage

```
PORT=32000 DOMAIN='your disguise domain (SNI); if omitted, the default is www.microsoft.com' IP_MODE='v4/v6/dual' INSTALL_MODE='go/py' SECRET='' PORT_V6='?'   bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/mtp-old.sh) rep
```

## Environment variable descriptions

#### 1️⃣、  PORT= port number (if filled in, it is a non-interactive installation; if not filled in, it is a menu-style installation)

#### 2️⃣、 DOMAIN='www.microsoft.com' (disguise domain (SNI); if not filled in, the default is www.microsoft.com)

#### 3️⃣、  IP_MODE='?' 

**Meaning of the values**
- v4 → listen on an ipv4 port (if omitted, v4 is used by default)
- v6 → listen on an ipv6 port
- dual → listen on both ipv4 and ipv6 ports

#### 4️⃣、 INSTALL_MODE='?'  (installation method, the Go version or the Python version)

**Meaning of the values**
- go → install the Go version (if omitted, the Go version is installed by default; installing this one is strongly recommended)
- py → install the Python version


#### 5️⃣、 SECRET='?'  (installation secret key; if unsure, leave it empty; if left empty, a secret key is generated randomly. Because with the Go version the secret key contains domain information, please do not fill it in carelessly if unsure)



#### 6️⃣、 PORT_V6='?'  (PORT_V6 only takes effect when IP_MODE='dual', and it is only useful in Python mode - only the Python version's dual supports separate ports; with the Go version, this parameter simply defaults to the v4 port. With IP_MODE='dual', if PORT_V6 is not filled in, PORT_V6 takes the value of PORT)


#### 7️⃣、 The rep and list parameters after the script mean overwrite installation and viewing node information; the ins parameter, or no parameter at all, means the default installation.


### 2、Uninstall the installed service:
```
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/mtp-old.sh) del
```

### 3、List detailed information of the installed service:
```
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/mtp-old.sh) list
```

### 4、Start the installed service:
```
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/mtp-old.sh) start
```

### 5、Stop the installed service:
```
bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/mtp-old.sh) stop
```
### 6、Restart the installed service:
```
 bash <(curl -Ls https://raw.githubusercontent.com/jyucoeng/singbox-tools/refs/heads/main/mtp-old.sh) restart
```


## Thanks
Thanks to the following developers for their contributions:

- [0xdabiaoge (renowned developer)](https://github.com/0xdabiaoge/MTProxy)