#!/bin/bash
# auto_reporter.sh — 编排采集+扫描，生成系统快照文件（crontab 入口）
set -euo pipefail

_ts() { date '+%Y-%m-%d %H:%M:%S'; }
_err() { echo "[$(date '+%H:%M:%S')] ERROR: $*" >&2; }
_warn() { echo "[$(date '+%H:%M:%S')] WARN: $*" >&2; }

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 默认配置
SNAPSHOT_DIR="${AI_SNAPSHOT_DIR:-${SCRIPT_DIR}/../data/snapshots}"
RETENTION_DAYS=${AI_RETENTION_DAYS:-7}
LOG_PATHS="${AI_LOG_PATHS:-/var/log/syslog}"

# ===== 清理过期快照 =====
cleanup_old_snapshots() {
    local dir="$1"
    local days="$2"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        return
    fi
    local count
    count=$(find "$dir" -name "snapshot_*.json" -mtime +"$days" 2>/dev/null | wc -l)
    if [[ $count -gt 0 ]]; then
        find "$dir" -name "snapshot_*.json" -mtime +"$days" -delete 2>/dev/null
        _warn "清理了 $count 个过期快照（>$days 天）"
    fi
}

# ===== 主流程 =====
main() {
    local mode="full"
    local output_path=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -o|--output) output_path="$2"; shift 2 ;;
            -d|--dir) SNAPSHOT_DIR="$2"; shift 2 ;;
            -r|--retention) RETENTION_DAYS="$2"; shift 2 ;;
            -h|--help)
                echo "用法: $0 [-o output.json] [-d snapshot_dir] [-r days]"
                exit 0 ;;
            *) shift ;;
        esac
    done

    mkdir -p "$SNAPSHOT_DIR"

    # 生成快照文件名
    local ts_file
    ts_file=$(date '+%Y%m%d_%H%M%S')
    local snapshot_file="$SNAPSHOT_DIR/snapshot_${ts_file}.json"
    if [[ -n "$output_path" ]]; then
        snapshot_file="$output_path"
        mkdir -p "$(dirname "$snapshot_file")"
    fi

    local hostname
    hostname=$(hostname 2>/dev/null || echo "unknown")
    local errors=0

    echo "[$(_ts)] 开始生成系统快照..." >&2

    # 1. 系统采集
    echo "[$(_ts)] 运行 sys_collector..." >&2
    local sys_json=""
    if [[ -x "$SCRIPT_DIR/sys_collector.sh" ]]; then
        sys_json=$(bash "$SCRIPT_DIR/sys_collector.sh" 2>/dev/null) || {
            _warn "sys_collector 返回非零退出码"
            errors=$((errors + 1))
        }
    else
        _err "未找到 sys_collector.sh"
        errors=$((errors + 1))
    fi

    # 2. 日志扫描
    echo "[$(_ts)] 运行 log_scanner..." >&2
    local log_json=""
    if [[ -x "$SCRIPT_DIR/log_scanner.sh" ]]; then
        log_json=$(bash "$SCRIPT_DIR/log_scanner.sh" -s 2>/dev/null) || {
            _warn "log_scanner 返回非零退出码"
            errors=$((errors + 1))
        }
    else
        _err "未找到 log_scanner.sh"
        errors=$((errors + 1))
    fi

    # 3. 组装快照
    {
        echo "{"
        echo "  \"snapshot_id\": \"$ts_file\","
        echo "  \"hostname\": \"$(sed 's/"/\\"/g' <<< "$hostname")\","
        echo "  \"created_at\": \"$(_ts)\","
        echo "  \"system\": $(echo "$sys_json" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin)))" 2>/dev/null || echo '{}'),"
        echo "  \"logs\": $(echo "$log_json" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin)))" 2>/dev/null || echo '{}'),"
        echo "  \"status\": \"$( [[ $errors -eq 0 ]] && echo 'ok' || echo 'partial' )\""
        echo "}"
    } > "$snapshot_file"

    echo "[$(_ts)] 快照已保存: $snapshot_file" >&2

    # 4. 清理过期快照
    cleanup_old_snapshots "$SNAPSHOT_DIR" "$RETENTION_DAYS"

    # 输出快照文件路径（供 Python 读取）
    echo "$snapshot_file"

    if [[ $errors -gt 0 ]]; then
        exit 1
    fi
}

main "$@"
