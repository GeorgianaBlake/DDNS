# Cloudflare DDNS Auto Update Script

> A pure Bash implementation of a Cloudflare Dynamic DNS (DDNS) script that supports automatic IPv4 / IPv6 detection and synchronization. It includes multilingual support (Simplified Chinese, Traditional Chinese, English, Spanish, Russian, Persian) and automatic timezone matching, compatible with mainstream Linux distributions.

## Features

+ Automatically detects public IPv4 / IPv6 and updates Cloudflare DNS records
+ Supports multiple languages (zh_CN, zh_TW, en, es, ru, fa) with automatic timezone matching
+ Supports Debian / Ubuntu / CentOS / Rocky / AlmaLinux

## Usage

**1. Install dependencies**

This script requires `curl` and `wget`. Please install them before downloading:

```bash
# Debian/Ubuntu systems
apt update -y
apt install -y curl wget
# CentOS/Rocky/AlmaLinux systems
yum install -y curl wget
```

**2. Download the script**

```bash
wget https://raw.githubusercontent.com/GeorgianaBlake/DDNS/main/cf-ddns.sh -O /usr/local/bin/cf-ddns.sh && chmod +x /usr/local/bin/cf-ddns.sh
```

**3. Initialize**

```bash
sudo /usr/local/bin/cf-ddns.sh --lang=en --init
```

Follow the prompts and enter:

```bash
Enter CF Zone API Token:
Enter CF Zone ID:
Enter CF Domain (e.g., test.example.com):
Enter record type (A or AAAA):
```

The script will automatically generate a configuration file. You can view it here:

```bash
/etc/GB_DDNS/config.json
```

**4. Run the update manually**

```bash
sudo /usr/local/bin/cf-ddns.sh --run
```

Example output:

```bash
[INFO] Current IP: 1.2.3.4
[SUCCESS] example.com A record updated to 1.2.3.4
```

**5. Set up cron job (auto update)**

It is recommended to check every minute via crontab:

```bash
sudo crontab -e
```

Add the following lines:

```bash
*/1 * * * * /usr/local/bin/cf-ddns.sh --run >> /etc/GB_DDNS/logs/cron.log 2>&1
*/30 * * * * tail -c 1M /etc/GB_DDNS/logs/cron.log > /etc/GB_DDNS/logs/cron.tmp && mv /etc/GB_DDNS/logs/cron.tmp /etc/GB_DDNS/logs/cron.log
```

## Debug Mode

To view detailed execution logs, enable Debug mode:

```bash
/usr/local/bin/cf-ddns.sh --debug=1 --run
```

Log file location:

```bash
/etc/GB_DDNS/logs/ddns.log
```

## Reset Configuration

To reconfigure:

```bash
/usr/local/bin/cf-ddns.sh --rest
```

You’ll be prompted:

```bash
Confirm reset configuration? (y/n):
```

Type `y` to reinitialize.

## Parameter Description

| Parameter  | Description                                                | Example              |
| ---------- | ---------------------------------------------------------- | -------------------- |
| `--lang=`  | Set script language, supports zh_CN, zh_TW, en, es, ru, fa | `--lang=en`          |
| `--tz=`    | Specify timezone, auto-detects if empty                    | `--tz=Asia/Shanghai` |
| `--debug=` | Enable Debug mode (1=on, 0=off)                            | `--debug=1`          |
| `--init`   | Run initialization to generate configuration               |                      |
| `--run`    | Execute DDNS update                                        |                      |
| `--rest`   | Reset configuration                                        |                      |

## File Structure

```bash
/etc/GB_DDNS/
├── config.json        # Cloudflare API configuration
├── i18n.conf          # Multilingual configuration file
└── logs/
    ├── ddns.log       # Log file (keeps last 20 lines)
    └── cron.log       # Cron job log file
```

## Supported Languages and Timezone Mapping

| Language Code | Language Name       | Auto Timezone |
| ------------- | ------------------- | ------------- |
| `zh_CN`       | Simplified Chinese  | Asia/Shanghai |
| `zh_TW`       | Traditional Chinese | Asia/Taipei   |
| `en`          | English             | Europe/London |
| `es`          | Spanish             | Europe/Madrid |
| `ru`          | Russian             | Europe/Moscow |
| `fa`          | Persian             | Asia/Tehran   |

## Internationalization Configuration Example

The multilingual config file will be automatically downloaded to `/etc/GB_DDNS/i18n.conf`.
You can also load a local version in debug mode via `./i18n.conf`.

```bash
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

## Log Example

```bash
2025-10-20 08:45:12 Current IP: 1.2.3.4
2025-10-20 08:45:13 Updated record: example.com A -> 1.2.3.4
2025-10-20 09:00:12 No update needed: example.com A record already 1.2.3.4
```

## Other

For issues or feature requests, please submit an Issue.
