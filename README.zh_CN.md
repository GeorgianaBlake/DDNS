# Cloudflare DDNS 自动更新脚本

> 一款纯 Bash 实现的 Cloudflare 动态域名解析（DDNS）脚本，支持 IPv4 / IPv6 自动检测与同步更新。内置多语言（简体中文、繁体中文、英文、西班牙语、俄语、波斯语）与自动时区匹配功能，支持主流 Linux 系统。

## 功能特点

+ 自动检测公网 IPv4 / IPv6 并更新 Cloudflare DNS 记录
+ 支持多语言界面(zh_CN, zh_TW, en, es, ru, fa), 自动根据语言匹配时区
+ 支持 Debian / Ubuntu / CentOS / Rocky / Fedora / Arch

## 安装方法

**安装依赖**

脚本依赖 curl、wget 包, 执行安装下载之前, 请预先下载, 下载方法如下:

```bash
apt install -y curl wget
# 或
yum install -y curl wget
```

一键安装(推荐)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/GeorgianaBlake/DDNS/main/cf-ddns.sh) --init
```

或手动下载

```bash
wget https://raw.githubusercontent.com/GeorgianaBlake/DDNS/main/cf-ddns.sh -O /usr/local/bin/cf-ddns.sh
chmod +x /usr/local/bin/cf-ddns.sh
```

## 参数说明

| 参数 | 说明 | 示例 |
| ------- | ------- | ------- |
|   `--lang=`   |   设置脚本语言，支持 zh_CN、zh_TW、en、es、ru、fa   |   `--lang=zh_CN`   |
|   `--tz=`   |   指定时区，不填则根据语言自动匹配   |   `--tz=Asia/Shanghai`   |
|   `--debug=`   |   是否启用 Debug 模式 (1=开启，0=关闭)   |   `--debug=1`   |
|   `--init`   |   首次初始化运行（生成配置）   |      |
|   `--run`   |   执行 DDNS 更新   |      |
|   `--rest`   |   重置配置   |      |

## 使用示例

### 初始化配置

```bash
sudo ./cf-ddns.sh --lang=zh_CN --init
```

按提示输入以下内容：

```bash
请输入 CF 区域 API Token:
请输入 CF 区域 ID:
请输入 CF 域名 (示例: test.example.com):
请输入记录类型 (A 或 AAAA):
```

脚本将自动生成配置文件：

```bash
/etc/GB_DDNS/config.json
```

### 手动运行更新

```bash
sudo ./cf-ddns.sh --run
```

示例输出：

```bash
[INFO] 当前IP: 1.2.3.4
[SUCCESS] example.com A 记录已更新至 1.2.3.4
```

### 定时任务设置（自动更新）

推荐使用 crontab 每分钟检测一次：

```bash
sudo crontab -e
```

添加以下行：

```bash
*/1 * * * * /usr/local/bin/cf-ddns.sh --run >> /etc/GB_DDNS/logs/ddns.log 2>&1
```

## 文件结构

```bash
/etc/GB_DDNS/
├── config.json        # Cloudflare API 配置
├── i18n.conf          # 多语言配置文件
└── logs/
    └── ddns.log       # 日志文件（保留最近 20 条）
```

## 支持语言与时区映射

| 语言代码    | 语言名称    | 自动匹配时区        |
| ------- | ------- | ------------- |
| `zh_CN` | 简体中文    | Asia/Shanghai |
| `zh_TW` | 繁體中文    | Asia/Taipei   |
| `en`    | English | Europe/London |
| `es`    | Español | Europe/Madrid |
| `ru`    | Русский | Europe/Moscow |
| `fa`    | فارسی   | Asia/Tehran   |

## 调试模式

如果需要查看详细执行日志，可启用 Debug 模式：

```bash
./cf-ddns.sh --debug=1 --run
```

日志路径：

```bash
/etc/GB_DDNS/logs/ddns.log
```

## 重置配置

如果需要重新配置：

```bash
./cf-ddns.sh --rest
```

系统会提示：

```bash
确认重置配置吗? (y/n):
```

选择 y 后重新初始化。

## 国际化配置说明

多语言配置文件会自动下载至 /etc/GB_DDNS/i18n.conf
你也可以在调试模式下加载本地的 ./i18n.conf。

```conf
[zh_CN]
gb_success="成功"
gb_error="失败"
gb_enter_cf_domain="请输入 CF 域名 (示例: test.example.com)"
gb_no_public_ip="无法获取公网(%s)IP地址"

[en]
gb_success="Success"
gb_error="Error"
gb_enter_cf_domain="Enter your CF domain (example: test.example.com)"
gb_no_public_ip="Unable to obtain public %s IP"
```

## 日志示例

```bash
2025-10-20 08:45:12 当前IP: 1.2.3.4
2025-10-20 08:45:13 更新记录: example.com A -> 1.2.3.4
2025-10-20 09:00:12 无需更新: example.com A 记录值为 1.2.3.4
```

## 其它

如有问题可提交 Issue
