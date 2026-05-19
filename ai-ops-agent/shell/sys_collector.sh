#!/bin/bash
# sys_collector.sh — 系统资源采集（CPU/内存/磁盘/网络/进程），输出 JSON
set -euo pipefail

# ===== 工具函数 =====
_ts() { date '+%Y-%m-%d %H:%M:%S'; }
_err() { echo "[$(date '+%H:%M:%S')] ERROR: $*" >&2; }
_warn() { echo "[$(date '+%H:%M:%S')] WARN: $*" >&2; }

# 简单的 JSON 字符串转义
json_escape() {
    sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\n/\\n/g' <<< "$*"
}

# 数值安全提取（非数字返回 0）
safe_num() {
    awk '{n=$1; if(n+0==n) print n; else print 0}' 2>/dev/null <<< "$1" || echo 0
}

# ===== CPU 采集 =====
collect_cpu() {
    local cpu_usage="" load1="" load5="" load15="" cores=""
    cores=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 1)

    # CPU 使用率（从 /proc/stat 计算）
    if [[ -f /proc/stat ]]; then
        local stat1 stat2 idle1 idle2 total1 total2
        stat1=$(head -1 /proc/stat)
        sleep 0.5
        stat2=$(head -1 /proc/stat)
        idle1=$(echo "$stat1" | awk '{print $5}')
        total1=$(echo "$stat1" | awk '{for(i=2;i<=8;i++) t+=$i; print t}')
        idle2=$(echo "$stat2" | awk '{print $5}')
        total2=$(echo "$stat2" | awk '{for(i=2;i<=8;i++) t+=$i; print t}')
        if [[ -n "$total1" && -n "$total2" ]]; then
            cpu_usage=$(awk "BEGIN {printf \"%.1f\", (1 - ($idle2 - $idle1) / ($total2 - $total1)) * 100}")
        fi
    fi
    cpu_usage=${cpu_usage:-0}

    # Load average
    if [[ -f /proc/loadavg ]]; then
        read load1 load5 load15 _ < /proc/loadavg
    fi
    load1=${load1:-0}; load5=${load5:-0}; load15=${load15:-0}

    echo "\"cpu\": {"
    echo "    \"usage_percent\": $(safe_num "$cpu_usage"),"
    echo "    \"load_avg_1min\": $(safe_num "$load1"),"
    echo "    \"load_avg_5min\": $(safe_num "$load5"),"
    echo "    \"load_avg_15min\": $(safe_num "$load15"),"
    echo "    \"cores\": $cores"
    echo "  }"
}

# ===== 内存采集 =====
collect_memory() {
    local total_kb=0 avail_kb=0 used_kb=0 usage_pct=0

    if [[ -f /proc/meminfo ]]; then
        total_kb=$(awk '/^MemTotal:/{print $2}' /proc/meminfo 2>/dev/null || echo 0)
        avail_kb=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo 2>/dev/null || echo 0)
        if [[ "$avail_kb" -eq 0 ]]; then
            local free_kb buffers cached
            free_kb=$(awk '/^MemFree:/{print $2}' /proc/meminfo 2>/dev/null || echo 0)
            buffers=$(awk '/^Buffers:/{print $2}' /proc/meminfo 2>/dev/null || echo 0)
            cached=$(awk '/^Cached:/{print $2}' /proc/meminfo 2>/dev/null || echo 0)
            avail_kb=$((free_kb + buffers + cached))
        fi
        used_kb=$((total_kb - avail_kb))
        if [[ "$total_kb" -gt 0 ]]; then
            usage_pct=$(awk "BEGIN {printf \"%.1f\", ($used_kb / $total_kb) * 100}")
        fi
    fi

    local total_mb=$((total_kb / 1024))
    local used_mb=$((used_kb / 1024))
    local avail_mb=$((avail_kb / 1024))

    echo "\"memory\": {"
    echo "    \"total_mb\": $total_mb,"
    echo "    \"used_mb\": $used_mb,"
    echo "    \"available_mb\": $avail_mb,"
    echo "    \"usage_percent\": $(safe_num "$usage_pct")"
    echo "  }"
}

# ===== 磁盘采集 =====
collect_disk() {
    echo "\"disk\": ["
    local first=true count=0
    while IFS= read -r line; do
        # 只处理物理磁盘和根分区相关的
        local fs=$(awk '{print $1}' <<< "$line")
        local total=$(awk '{print $2}' <<< "$line")
        local used=$(awk '{print $3}' <<< "$line")
        local avail=$(awk '{print $4}' <<< "$line")
        local pct=$(awk '{print $5}' <<< "$line" | tr -d '%')
        local mnt=$(awk '{print $6}' <<< "$line")

        # 跳过伪文件系统和临时挂载
        case "$fs" in
            tmpfs|devtmpfs|overlay|squashfs|none) continue ;;
        esac

        # 只取前 5 个
        [[ $count -ge 5 ]] && break

        local total_gb=$((total / 1024 / 1024))
        local used_gb=$((used / 1024 / 1024))
        local avail_gb=$((avail / 1024 / 1024))
        [[ $total_gb -lt 1 ]] && continue

        $first || echo ","
        first=false
        echo -n "    { \"mount\": \"$mnt\", \"total_gb\": $total_gb, \"used_gb\": $used_gb, \"available_gb\": $avail_gb, \"usage_percent\": $pct }"
        count=$((count + 1))
    done < <(df -k 2>/dev/null | tail -n +2)
    if $first; then
        # 没有磁盘数据时输出空对象占位
        echo "    { \"mount\": \"/\", \"total_gb\": 0, \"used_gb\": 0, \"available_gb\": 0, \"usage_percent\": 0 }"
    fi
    echo ""
    echo "  ]"
}

# ===== 网络采集 =====
collect_network() {
    local conn_total=0 conn_estab=0 conn_listen=0

    if command -v ss &>/dev/null; then
        conn_total=$(ss -tan 2>/dev/null | tail -n +2 | wc -l)
        conn_estab=$(ss -tan state established 2>/dev/null | tail -n +2 | wc -l)
        conn_listen=$(ss -tan state listening 2>/dev/null | tail -n +2 | wc -l)
    elif command -v netstat &>/dev/null; then
        conn_total=$(netstat -tan 2>/dev/null | tail -n +3 | wc -l)
        conn_estab=$(netstat -tan 2>/dev/null | grep ESTABLISHED | wc -l)
        conn_listen=$(netstat -tan 2>/dev/null | grep LISTEN | wc -l)
    fi

    # 网络接口
    local ifaces_json="["
    local first=true
    for iface in $(ls /sys/class/net/ 2>/dev/null); do
        $first || ifaces_json+=", "
        first=false
        ifaces_json+="\"$iface\""
    done
    ifaces_json+="]"

    echo "\"network\": {"
    echo "    \"interfaces\": $ifaces_json,"
    echo "    \"connections_total\": $conn_total,"
    echo "    \"connections_established\": $conn_estab,"
    echo "    \"connections_listening\": $conn_listen"
    echo "  }"
}

# ===== 进程采集 =====
collect_processes() {
    local total=0
    total=$(ps -e 2>/dev/null | wc -l || echo 0)

    echo "\"processes\": {"
    echo "    \"total\": $total,"

    # Top 5 CPU
    echo "    \"top_cpu\": ["
    local first=true count=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local pid=$(awk '{print $1}' <<< "$line")
        local cpu=$(awk '{print $3}' <<< "$line")
        local cmd=$(awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}' <<< "$line" | sed 's/ $//')
        cmd=$(json_escape "${cmd:0:50}")
        $first || echo ","
        first=false
        echo -n "      { \"pid\": $pid, \"name\": \"$cmd\", \"cpu_percent\": $(safe_num "$cpu") }"
        count=$((count + 1))
        [[ $count -ge 5 ]] && break
    done < <(ps -eo pid,pcpu,rss,comm --no-headers --sort=-pcpu 2>/dev/null || true)
    if $first; then
        echo "      { \"pid\": 0, \"name\": \"N/A\", \"cpu_percent\": 0 }"
    fi
    echo ""
    echo "    ],"

    # Top 5 MEM
    echo "    \"top_mem\": ["
    first=true; count=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local pid=$(awk '{print $1}' <<< "$line")
        local mem=$(awk '{print $4}' <<< "$line")
        local cmd=$(awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}' <<< "$line" | sed 's/ $//')
        cmd=$(json_escape "${cmd:0:50}")
        $first || echo ","
        first=false
        echo -n "      { \"pid\": $pid, \"name\": \"$cmd\", \"mem_percent\": $(safe_num "$mem") }"
        count=$((count + 1))
        [[ $count -ge 5 ]] && break
    done < <(ps -eo pid,pcpu,rss,comm --no-headers --sort=-rss 2>/dev/null || true)
    if $first; then
        echo "      { \"pid\": 0, \"name\": \"N/A\", \"mem_percent\": 0 }"
    fi
    echo ""
    echo "    ]"
    echo "  }"
}

# ===== 主流程 =====
main() {
    local hostname
    hostname=$(hostname 2>/dev/null || echo "unknown")

    local collect_errors=0

    echo "{"
    echo "  \"timestamp\": \"$(_ts)\","
    echo "  \"hostname\": \"$(json_escape "$hostname")\","

    collect_cpu || { _warn "CPU 采集部分失败"; collect_errors=$((collect_errors + 1)); }
    echo ","
    collect_memory || { _warn "内存采集部分失败"; collect_errors=$((collect_errors + 1)); }
    echo ","
    collect_disk || { _warn "磁盘采集部分失败"; collect_errors=$((collect_errors + 1)); }
    echo ","
    collect_network || { _warn "网络采集部分失败"; collect_errors=$((collect_errors + 1)); }
    echo ","
    collect_processes || { _warn "进程采集部分失败"; collect_errors=$((collect_errors + 1)); }
    echo "}"

    if [[ $collect_errors -ge 3 ]]; then
        exit 2
    elif [[ $collect_errors -gt 0 ]]; then
        exit 1
    fi
}

main "$@"
