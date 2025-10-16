#!/usr/bin/env bash
# ===========================================================================================
# cf-ddns.sh 是一款用于自动更新 Cloudflare DNS 记录的脚本，支持 IPv4/IPv6
# 支持 Debian9+ / Ubuntu18+ / Centos7+ / Rocky9+ / Fedora40+ / Arch 主流系统，其它系统未经过测试
# 支持简体中文、繁体中文、英文、俄语、西班牙语、波斯语
# 参数说明:
# --debug Debug模式: 1-开启, 0-关闭(默认)
# --lang 脚本语言: 支持 zh_CN|zh_TW|en|es|ru|fa 语言, 默认 en
# --tz 时区: 空值时会根据语言进行设置, 有值则根据值设置
# 部分逻辑参考了 https://github.com/yulewang 作者的逻辑
# ===========================================================================================

set -euo pipefail

DEBUG=0 # debug模式
CONFIG_DIR="/etc/GB_DDNS" # 配置目录
DDNS_CONFIG_FILE="${CONFIG_DIR}/config.json" # 配置文件
DDNS_LOG_FILE="${CONFIG_DIR}/logs/ddns.log" # 日志文件
DDNS_LANG_FILE="${CONFIG_DIR}/i18n.conf" # 语言文件
CF_API="https://api.cloudflare.com/client/v4"
DEFAULT_LANG="en" # 默认语言, zh_CN、zh_TW、en
DEFAULT_TIME="Europe/London" # 默认时区
CF_TZ_DEFAULT="$DEFAULT_TIME"
CF_DDNS_LANG="$DEFAULT_LANG"
I18N_FILE=""

Font="\033[0m"     # 结尾
Black="\033[30m"   # 黑色
Red="\033[31m"     # 红色
Green="\033[32m"   # 绿色
Yellow="\033[33m"  # 黄色
Blue="\033[34m"    # 蓝色
Magenta="\033[35m" # 紫/洋红
Cyan="\033[36m"    # 青
White="\033[37m"   # 白色

SUCCESS="${Green}[SUCCESS]${Font}"
ERROR="${Red}[ERROR]${Font}"
WARNING="${Yellow}[WARNING]${Font}"
INFO="${Cyan}[INFO]${Font}"

declare -A MSG=() # 国际化

success() {
  echo -e "${SUCCESS}${Green} $1 ${Font}"
}

warning() {
  echo -e "${WARNING}${Yellow} $1 ${Font}"
}

error() {
  echo -e "${ERROR}${Red} $1 ${Font}"
}

info() {
  echo -e "${INFO}${Cyan} $1 ${Font}"
}

judge() {
  if [[ 0 -eq $? ]]; then
    success "$1 $(t gb_success)"
    sleep 1
  else
    error "$1 $(t gb_error)"
    exit 1
  fi
}

load_i18n_file() {
  local local_path="./i18n.conf"
  local remote_url="https://raw.githubusercontent.com/GeorgianaBlake/DDNS/refs/heads/main/i18n.conf"
  local target_dir
  target_dir="$(dirname "$DDNS_LANG_FILE")"
  

  if [[ "$DEBUG" == "1" ]]; then
    I18N_FILE="$local_path"
    return 0
  fi

  mkdir -p "$target_dir"

  if [[ -f "$DDNS_LANG_FILE" && -s "$DDNS_LANG_FILE" ]]; then
    info "Detected ${DDNS_LANG_FILE}, skipping download"
    I18N_FILE="$DDNS_LANG_FILE"
    return 0
  fi

  info "Downloading i18n.conf"

  if command -v curl >/dev/null 2>&1; then
    if curl -fsSL "$remote_url" -o "$DDNS_LANG_FILE"; then
      success "i18n.conf has been successfully downloaded"
    else
      error "Download failed (curl)"
      exit 1
    fi
  elif command -v wget >/dev/null 2>&1; then
    if wget -qO "$DDNS_LANG_FILE" "$remote_url"; then
      success "i18n.conf has been successfully downloaded"
    else
      error "Download failed (wget)"
      exit 1
    fi
  else
    error "curl or wget not found, unable to download file"
    exit 1
  fi

  I18N_FILE="$DDNS_LANG_FILE"
}

load_i18n() {
  local lang="$1" line key val
  local in_block=0
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue   # 跳过空行/注释
    if [[ "$line" =~ ^\[$lang\]$ ]]; then
      in_block=1; continue
    elif [[ "$line" =~ ^\[.*\]$ ]]; then
      (( in_block )) && break
    elif (( in_block )); then
      key="${line%%=*}"
      val="${line#*=}"
      val="${val%\"}"; val="${val#\"}"   # 去掉首尾引号
      MSG["$key"]="$val"
    fi
  done < "$I18N_FILE"
}

t() {
  local key="$1"; shift || true
  local tmpl="${MSG[$key]:-$key}"
  printf "$tmpl" "$@" | fold -s -w $(tput cols)
}

ensure_root() {
  if [[ $EUID -ne 0 ]]; then
    clear
    error "This script must be run as root!" 1>&2
    exit 1
  fi
}

quit() { exit 0; }

os_install() {
  info "$(t gb_downloading_script_deps)..."
  if [[ -f /etc/debian_version ]]; then
    info "$(t gb_debian_ubuntu_detected)"
    dpkg --configure -a
    apt-get -y -f install
    apt-get update -y
    apt-get install -y wget jq
    judge "$(t gb_installing_script_deps)"
  elif [[ -f /etc/redhat-release ]]; then
    info "$(t gb_centos_rhel_detected)"
    rm -f /var/run/yum.pid 2>/dev/null
    yum install -y epel-release
    yum install -y wget jq
    judge "$(t gb_installing_script_deps)"
  else
    error "$(t gb_unrecognized_pkg_manager)"
    exit 1
  fi
}

get_ipv4() {
  local urls=(
    "https://www.cloudflare.com/cdn-cgi/trace"
    "https://cloudflare.com/cdn-cgi/trace"
    "https://api.ipify.org"
    "https://ifconfig.co"
    "https://v4.ident.me"
    "https://ipv4.icanhazip.com"
  )

  for u in "${urls[@]}"; do
    ip=$(curl -4 -fsS --max-time 3 "$u" 2>/dev/null | awk -F= '/^ip=/{print $2}' | tr -d ' \r' | head -n1)
    [[ -z "$ip" ]] && ip=$(echo "$u" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n1)
    if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
      echo "$ip"
      return 0
    fi
  done

  echo "$(t gb_no_public_iPv4_detected)" >&2
  return 1
}

get_ipv6() {
  local urls=(
    "https://www.cloudflare.com/cdn-cgi/trace"
    "https://cloudflare.com/cdn-cgi/trace"
    "https://api64.ipify.org"
    "https://v6.ident.me"
    "https://ipv6.icanhazip.com"
    "https://ifconfig.co"
  )

  for u in "${urls[@]}"; do
    ip=$(curl -6 -fsS --max-time 3 "$u" 2>/dev/null | awk -F= '/^ip=/{print $2}' | tr -d ' \r' | head -n1)
    if [[ "$ip" =~ : ]]; then
      echo "$ip"
      return 0
    fi
  done

  echo "$(t gb_no_public_iPv6_detected)" >&2
  return 1
}


write_log() {
  local msg="$1"
  local max_lines=20
  local log_file="$DDNS_LOG_FILE"

  mkdir -p "$(dirname "$log_file")"

  echo "$(TZ=$CF_TZ_DEFAULT date '+%F %T') $msg" >> "$log_file"

  # 限制最大行数为20，只保留最后20行
  local lines
  lines=$(wc -l < "$log_file")
  if (( lines > max_lines )); then
    tail -n "$max_lines" "$log_file" > "${log_file}.tmp" && mv "${log_file}.tmp" "$log_file"
  fi
}

# CF API Token
read_cf_api_token() {
  local token
  while true; do
    read -rp "$(t gb_enter_cf_zone_api_token): " token
    echo "$token"
    break
  done
}

# Zone ID
read_cf_zone_id() {
  local zone_id
  while true; do
    read -rp "$(t gb_enter_cf_zone_id): " zone_id
    echo "$zone_id"
    break
  done
}

# Record Type. exp: A or AAAA
read_cf_record_type() {
  local record_type
  while true; do
    read -rp "$(t gb_enter_record_type): " record_type
    if [[ "$record_type" != "A" && "$record_type" != "AAAA" ]]; then
      error "$(t gb_type_must_be_A_try_again)" >&2
      continue
    fi
    echo "$record_type"
    break
  done
}

# Domain Name. exp: test.example.com
read_cf_domain_name() {
  local domain_name
  while true; do
    read -rp "$(t gb_enter_cf_domain): " domain_name

    if [[ -z "$domain_name" ]]; then
      error "$(t gb_domain_required_try_again)" >&2
      continue
    fi

    if [[ ! "$domain_name" =~ ^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$ ]]; then
      error "$(t gb_invalid_domain_try_again $domain_name)" >&2
      continue
    fi

    echo "$domain_name"
    break
  done
}

basic_setup() {
  local CF_API_TOKEN="$(read_cf_api_token)"
  local CF_ZONE_ID="$(read_cf_zone_id)"
  local CF_DOMAIN_NAME="$(read_cf_domain_name)"
  local CF_RECORD_TYPE="$(read_cf_record_type)"
  local CF_TTL=300
  local CF_PROXIED=false

  cat > "$DDNS_CONFIG_FILE" <<EOF
{
  "cf_token": "$CF_API_TOKEN",
  "cf_zone_id": "$CF_ZONE_ID",
  "cf_domain_name": "$CF_DOMAIN_NAME",
  "cf_record_type": "$CF_RECORD_TYPE",
  "cf_ttl": $CF_TTL,
  "cf_proxied": $CF_PROXIED
}
EOF
  success "$(t gb_config_done_run_script)"
}

run_script() {
  if [[ ! -f "$DDNS_CONFIG_FILE" ]]; then
    write_log "$(t gb_no_config_file)"
    exit 1
  fi

  local CF_API_TOKEN="$(jq -r '.cf_token' $DDNS_CONFIG_FILE)"
  local CF_ZONE_ID="$(jq -r '.cf_zone_id' $DDNS_CONFIG_FILE)"
  local CF_DOMAIN_NAME="$(jq -r '.cf_domain_name' $DDNS_CONFIG_FILE)"
  local CF_RECORD_TYPE="$(jq -r '.cf_record_type' $DDNS_CONFIG_FILE)"
  local CF_TTL="$(jq '.cf_ttl' $DDNS_CONFIG_FILE)"
  local CF_PROXIED="$(jq '.cf_proxied' $DDNS_CONFIG_FILE)"
  local NEW_IP=""

  if [[ "$CF_RECORD_TYPE" == "AAAA" ]]; then
    NEW_IP="$(get_ipv6 || true)"
  else
    NEW_IP="$(get_ipv4 || true)"
  fi

  info "$(t gb_current_ip): $NEW_IP"

  if [[ -z "${NEW_IP:-}" ]]; then
    error "$(t gb_no_public_ip ${CF_RECORD_TYPE})"
    write_log "$(t gb_no_public_ip ${CF_RECORD_TYPE})"
    exit 3
  fi

  auth_hdr=(-H "Authorization: Bearer ${CF_API_TOKEN}" -H "Content-Type: application/json")

  query_url="${CF_API}/zones/${CF_ZONE_ID}/dns_records?type=${CF_RECORD_TYPE}&name=$(printf %s "$CF_DOMAIN_NAME" | sed 's/\./%2E/g' | sed 's/-/%2D/g')"

  resp="$(curl -fsS "${auth_hdr[@]}" "$query_url")" || { write_log "查询失败; $resp" >&2; exit 4; }

  result_count="$(echo "$resp" | jq -r '.result | length')"

  record_id=""
  old_ip=""

  if [[ "$result_count" -ge 1 ]]; then
    record_id="$(echo "$resp" | jq -r '.result[0].id')"
    old_ip="$(echo "$resp" | jq -r '.result[0].content')"
  fi

  if [[ -n "$old_ip" && "$old_ip" == "$NEW_IP" ]]; then
    success "$(t gb_no_update_required ${CF_DOMAIN_NAME} ${CF_RECORD_TYPE} ${NEW_IP})"
    write_log "$(t gb_no_update_required ${CF_DOMAIN_NAME} ${CF_RECORD_TYPE} ${NEW_IP})"
    exit 0
  fi

  payload="$(jq -n \
    --arg type "$CF_RECORD_TYPE" \
    --arg name "$CF_DOMAIN_NAME" \
    --arg content "$NEW_IP" \
    --argjson ttl "$CF_TTL" \
    --argjson proxied "$( [[ "$CF_PROXIED" == "true" ]] && echo true || echo false )" \
    '{type:$type,name:$name,content:$content,ttl:$ttl,proxied:$proxied}')"

  # ---- 创建或更新 ----
  if [[ -z "$record_id" || "$record_id" == "null" ]]; then
    echo "$(t gb_no_record_creating)..."
    create_url="${CF_API}/zones/${CF_ZONE_ID}/dns_records"
    upd="$(curl -fsS "${auth_hdr[@]}" -X POST "$create_url" --data "$payload" || true)"
  else
    echo "$(t gb_found_updating ${record_id})..."
    update_url="${CF_API}/zones/${CF_ZONE_ID}/dns_records/${record_id}"
    upd="$(curl -fsS "${auth_hdr[@]}" -X PUT "$update_url" --data "$payload" || true)"
  fi

  ok="$(echo "${upd:-}" | jq -r '.success' 2>/dev/null || echo false)"
  if [[ "$ok" == "true" ]]; then
    succsss "$(t gb_written): ${CF_DOMAIN_NAME} ${CF_RECORD_TYPE} -> ${NEW_IP} (proxied=${CF_PROXIED}, ttl=${CF_TTL})"
    write_log "$(t gb_written): ${CF_DOMAIN_NAME} ${CF_RECORD_TYPE} -> ${NEW_IP} (proxied=${CF_PROXIED}, ttl=${CF_TTL})"
    exit 0
  else
    error "$(t gb_update_failed): ${upd:-"($(t gb_no_response))"}" | sed -e 's/\\n/\n/g'
    write_log "$(t gb_update_failed): ${upd:-"($(t gb_no_response))"}" | sed -e 's/\\n/\n/g'
    exit 5
  fi
}

init_script() {
  os_install
  mkdir -p -- "$CONFIG_DIR"
  : > "$DDNS_CONFIG_FILE"
  rm -rf "$DDNS_LANG_FILE"
  basic_setup
}

rest_script() {
  while true; do
    read -rp "$(t gb_reset_config)? (y/n): " choice
    case "$choice" in
      [yY]|yes|YES)
        os_install
        if [[ ! -f "$DDNS_CONFIG_FILE" ]]; then
          mkdir -p -- "$CONFIG_DIR"
        fi
        : > "$DDNS_CONFIG_FILE"
        rm -rf "$DDNS_LANG_FILE"
        basic_setup
        return 0
        ;;
      [nN]|no|NO)
        info "$(t gb_reset_canceled)"
        return 1
        ;;
      *)
        error "$(t gb_invalid_input_enter_yn)"
        ;;
    esac
  done
}

map_lang_to_tz() {
  case "$1" in
    zh_CN) echo "Asia/Shanghai" ;;
    zh_TW) echo "Asia/Taipei" ;;
    en)    echo "Europe/London" ;;
    es)    echo "Europe/Madrid" ;;
    ru)    echo "Europe/Moscow" ;;
    fa)    echo "Asia/Tehran" ;;
    *)     echo "Europe/London" ;;
  esac
}

normalize_lang() {
  case "$1" in
    zh_CN|zh_TW|en|es|ru|fa) echo "$1" ;;
    "" ) echo "$DEFAULT_LANG" ;;
    *  ) echo "$DEFAULT_LANG" ;;
  esac
}


main() {
  [[ -d "$CONFIG_DIR" ]] || mkdir -p "$CONFIG_DIR"

  local lang="" tz="" debug="" action=""
  
  for arg in "$@"; do
    case "$arg" in
      --lang=*)  lang="${arg#*=}" ;;
      --tz=*)    tz="${arg#*=}" ;;
      --debug=*) debug="${arg#*=}" ;;
      --run)     action="run" ;;
      --init)    action="init" ;;
      --rest)    action="rest" ;;
      *)
    esac
  done

  lang="$(normalize_lang "$lang")"

  if [[ "$debug" == "1" ]]; then
    debug="1"
  else
    debug="0"
  fi

  if [[ -z "$tz" ]]; then
    tz="$(map_lang_to_tz "$lang")"
  fi

  [[ -z "$action" ]] && action="run"

  CF_DDNS_LANG="$lang"
  CF_TZ_DEFAULT="$tz"
  DEBUG="$debug"

  load_i18n_file
  load_i18n "$CF_DDNS_LANG"
  
  case "$action" in
    init) init_script; return ;;
    rest) rest_script; return ;;
    run)  run_script ;;
    *)    error "Unknown action: $action"; exit 1 ;;
  esac
}

ensure_root
main "$@"
