#!/bin/bash
# log_scanner.sh — 日志异常扫描，基于模式匹配输出 JSON
set -euo pipefail

_ts() { date '+%Y-%m-%d %H:%M:%S'; }
_err() { echo "[$(date '+%H:%M:%S')] ERROR: $*" >&2; }
_warn() { echo "[$(date '+%H:%M:%S')] WARN: $*" >&2; }

json_escape() {
    sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\n/\\n/g' <<< "$*"
}

# 默认扫描路径
DEFAULT_LOGS=("/var/log/syslog" "/var/log/auth.log" "/var/log/kern.log" "/var/log/messages")

# 严重级别 → 模式映射
# 格式: severity:pattern (正则)
PATTERNS=(
    "critical:kernel panic|BUG:|segfault|general protection fault|Kernel Oops"
    "error:error|fail|failed|failure|FATAL|ALERT|denied|refused|killed"
    "warning:warning|WARN|timeout|retry|depleted|exceeded|limit|OOM|out of memory"
    "info:restart|started|stopped|reload"
)

# ===== 单文件扫描 =====
scan_file() {
    local file="$1"
    local anomalies_json=""
    local first=true
    local counts_error=0 counts_warn=0 counts_crit=0 counts_info=0

    if [[ ! -r "$file" ]]; then
        _warn "无法读取文件: $file，跳过"
        return
    fi

    local lines
    lines=$(wc -l < "$file" 2>/dev/null || echo 0)
    if [[ $lines -eq 0 ]]; then
        return
    fi

    # 只扫描最近 5000 行（控制性能）
    local tail_lines=5000

    for entry in "${PATTERNS[@]}"; do
        local severity="${entry%%:*}"
        local pattern="${entry#*:}"

        while IFS= read -r match_line; do
            [[ -z "$match_line" ]] && continue
            local lineno=$(echo "$match_line" | cut -d: -f1)
            local content=$(echo "$match_line" | cut -d: -f2-)
            content="${content:0:200}"  # 截断过长行
            content=$(json_escape "$content")

            case "$severity" in
                critical) counts_crit=$((counts_crit + 1)) ;;
                error)    counts_error=$((counts_error + 1)) ;;
                warning)  counts_warn=$((counts_warn + 1)) ;;
                info)     counts_info=$((counts_info + 1)) ;;
            esac

            $first || anomalies_json+=","
            first=false
            anomalies_json+=$'\n'"      { \"file\": \"$file\", \"line\": $lineno, \"severity\": \"$severity\", \"content\": \"$content\", \"matched_pattern\": \"$(json_escape "$pattern")\" }"
        done < <(tail -n "$tail_lines" "$file" 2>/dev/null | grep -inE "$pattern" 2>/dev/null || true)
    done

    if ! $first; then
        echo "$anomalies_json"
    fi

    # 输出计数到临时文件供汇总用
    echo "$counts_crit $counts_error $counts_warn $counts_info" > "/tmp/log_scan_counts.$$"
}

# ===== 主流程 =====
main() {
    local scan_paths=()
    local scan_lines=5000
    local scan_syslog=false

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--file)  scan_paths+=("$2"); shift 2 ;;
            -l|--lines) scan_lines="$2"; shift 2 ;;
            -s|--syslog) scan_syslog=true; shift ;;
            -h|--help)
                echo "用法: $0 [-f logfile] [-l lines] [-s]"
                echo "  -f  指定日志文件（可多次使用）"
                echo "  -l  扫描行数（默认 5000）"
                echo "  -s  扫描系统日志（/var/log/syslog, auth.log, kern.log）"
                exit 0 ;;
            *) shift ;;
        esac
    done

    # 默认扫描路径
    if [[ ${#scan_paths[@]} -eq 0 ]]; then
        if $scan_syslog; then
            for p in "${DEFAULT_LOGS[@]}"; do
                [[ -r "$p" ]] && scan_paths+=("$p")
            done
        fi
        # 如果仍为空，尝试常见日志目录
        if [[ ${#scan_paths[@]} -eq 0 ]]; then
            _err "未指定日志文件，使用 -f 指定或 -s 扫描系统日志"
            exit 2
        fi
    fi

    local hostname
    hostname=$(hostname 2>/dev/null || echo "unknown")

    echo "{"
    echo "  \"timestamp\": \"$(_ts)\","
    echo "  \"hostname\": \"$(json_escape "$hostname")\","
    echo "  \"scanned_files\": ["
    local fi=true
    for f in "${scan_paths[@]}"; do
        $fi || echo ","
        fi=false
        echo -n "    \"$f\""
    done
    echo ""
    echo "  ],"
    echo "  \"anomalies\": ["

    local anomaly_json=""
    local total_crit=0 total_err=0 total_warn=0 total_info=0
    local first_anomaly=true

    for f in "${scan_paths[@]}"; do
        > "/tmp/log_scan_counts.$$"
        local result
        result=$(scan_file "$f")
        if [[ -n "$result" ]]; then
            $first_anomaly || anomaly_json+=","
            first_anomaly=false
            anomaly_json+="$result"
        fi
        if [[ -f "/tmp/log_scan_counts.$$" ]]; then
            read c e w i < "/tmp/log_scan_counts.$$"
            total_crit=$((total_crit + c))
            total_err=$((total_err + e))
            total_warn=$((total_warn + w))
            total_info=$((total_info + i))
        fi
        rm -f "/tmp/log_scan_counts.$$"
    done

    echo "$anomaly_json"
    echo "  ],"
    echo "  \"summary\": {"
    echo "    \"total_anomalies\": $((total_crit + total_err + total_warn + total_info)),"
    echo "    \"by_severity\": {"
    echo "      \"critical\": $total_crit,"
    echo "      \"error\": $total_err,"
    echo "      \"warning\": $total_warn,"
    echo "      \"info\": $total_info"
    echo "    }"
    echo "  }"
    echo "}"

    local total=$((total_crit + total_err + total_warn))
    if [[ $total -gt 50 ]]; then
        exit 1
    fi
}

main "$@"
