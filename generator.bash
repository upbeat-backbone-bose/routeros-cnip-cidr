#! /bin/bash
set -euo pipefail

WORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1; pwd)"
TMP_DIR="$WORK_DIR/tmp"
DIST_DIR="$WORK_DIR/dist"

mkdir -p "$TMP_DIR" || { echo "ERROR: Failed to create tmp directory" >&2; exit 1; }
mkdir -p "$DIST_DIR" || { echo "ERROR: Failed to create dist directory" >&2; exit 1; }

TMP_CIDR_V4="$TMP_DIR/all_cn.txt"
TMP_CIDR_V6="$TMP_DIR/all_cn_ipv6.txt"
TMP_V4_STATUS="$TMP_DIR/v4_status.txt"
TMP_V6_STATUS="$TMP_DIR/v6_status.txt"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

download_list() {
  local url=$1
  local output=$2
  local status_file=$3
  local name=$4
  local http_code
  
  http_code=$(curl --max-time 60 --connect-timeout 10 -sL -w "%{http_code}" "$url" -o "$output" 2>/dev/null) || {
    echo "ERROR: Failed to download $name list (network error)" >&2
    echo "failed" > "$status_file"
    return 1
  }
  
  if [[ "$http_code" != "200" ]]; then
    echo "ERROR: Failed to download $name list (HTTP $http_code)" >&2
    rm -f "$output"
    echo "failed" > "$status_file"
    return 1
  fi
  
  if [[ ! -s "$output" ]]; then
    echo "ERROR: Downloaded $name list is empty" >&2
    rm -f "$output"
    echo "failed" > "$status_file"
    return 1
  fi
  
  local line_count
  line_count=$(wc -l < "$output")
  echo "Downloaded $name list: $line_count entries"
  echo "success" > "$status_file"
  return 0
}

download_list "https://raw.githubusercontent.com/soffchen/GeoIP2-CN/release/CN-ip-cidr.txt" "$TMP_CIDR_V4" "$TMP_V4_STATUS" "IPv4" &
download_list "https://raw.githubusercontent.com/gaoyifan/china-operator-ip/ip-lists/china6.txt" "$TMP_CIDR_V6" "$TMP_V6_STATUS" "IPv6" &

wait

if [[ ! -f "$TMP_V4_STATUS" ]] || [[ "$(cat "$TMP_V4_STATUS")" != "success" ]]; then
  echo "ERROR: IPv4 download failed" >&2
  exit 1
fi

if [[ ! -f "$TMP_V6_STATUS" ]] || [[ "$(cat "$TMP_V6_STATUS")" != "success" ]]; then
  echo "ERROR: IPv6 download failed" >&2
  exit 1
fi

validate_ip_cidr() {
    local file=$1
    local ip_version=$2
    local valid_count=0
    local invalid_count=0
    local total_count=0
    
    if [[ ! -f "$file" ]]; then
      echo "ERROR: File $file not found for validation" >&2
      return 1
    fi
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue
        ((total_count++)) || true
        
        local valid=false
        if [[ "$ip_version" == "IPv4" ]]; then
            if [[ "$line" =~ ^([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])/([0-9]|[1-2][0-9]|3[0-2])$ ]]; then
                valid=true
            fi
        elif [[ "$ip_version" == "IPv6" ]]; then
            if [[ "$line" =~ ^([0-9a-fA-F:]+)/([0-9]|[1-9][0-9]|1[0-1][0-9]|12[0-8])$ ]]; then
                valid=true
            fi
        fi
        
        if $valid; then
            ((valid_count++)) || true
        else
            ((invalid_count++)) || true
            echo "WARNING: Invalid $ip_version CIDR: $line" >&2
        fi
    done < "$file"
    
    echo "Validation result (Valid: $valid_count, Invalid: $invalid_count, Total: $total_count)"
    [[ $invalid_count -lt $valid_count ]]
}

echo "Validating IPv4 list..."
if ! validate_ip_cidr "$TMP_CIDR_V4" "IPv4"; then
  echo "ERROR: IPv4 list validation failed" >&2
  exit 1
fi

echo "Validating IPv6 list..."
if ! validate_ip_cidr "$TMP_CIDR_V6" "IPv6"; then
  echo "ERROR: IPv6 list validation failed" >&2
  exit 1
fi
cat > "$DIST_DIR/cn_ip_cidr.rsc" << 'EOF'
/log info "Import cn ipv4 cidr list..."
/ip firewall address-list remove [/ip firewall address-list find list=cn_ip_cidr]
/ipv6 firewall address-list remove [/ipv6 firewall address-list find list=cn_ip_cidr]
/ip firewall address-list
EOF

if [[ ! -s "$TMP_CIDR_V4" ]]; then
  echo "ERROR: IPv4 CIDR file is empty, skipping generation" >&2
  exit 1
fi

awk '{ printf(":do {add address=%s list=cn_ip_cidr} on-error={}\n",$0) }' "$TMP_CIDR_V4" >> "$DIST_DIR/cn_ip_cidr.rsc"

if [[ ! -s "$TMP_CIDR_V6" ]]; then
  echo "ERROR: IPv6 CIDR file is empty, skipping IPv6 generation" >&2
else
  cat >> "$DIST_DIR/cn_ip_cidr.rsc" << 'EOF'
:if ([:len [/system package find where name="routeros" and version~"^7"]] > 0) do={
    /log info "Import cn ipv6 cidr list..."
    /ipv6 firewall address-list
EOF
  awk '{ printf(":do {add address=%s list=cn_ip_cidr} on-error={}\n",$0) }' "$TMP_CIDR_V6" >> "$DIST_DIR/cn_ip_cidr.rsc"
  echo "}" >> "$DIST_DIR/cn_ip_cidr.rsc"
fi

echo "Generation completed successfully: $DIST_DIR/cn_ip_cidr.rsc"
