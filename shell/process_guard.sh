#!/bin/bash
# process_guard.sh — 关键进程监控，异常告警/自动重启
set -euo pipefail

_ts() { date '+%Y-%m-%d %H:%M:%S'; }
_err() { echo "[$(date '+%H:%M:%S')] ERROR: $*" >&2; }
_warn() { echo "[$(date '+%H:%M:%S')] WARN: $*" >&2; }

# 状态文件路径（记录重启次数，防止无限重启）
STATE_DIR="${TMPDIR:-/tmp}/process_guard"
PID_FILE="$STATE_DIR/guard.pid"

# ===== 进程检查 =====
check_process() {
    local name="$1"
    local pid=""
    local running=false

    # pgrep 检查
    if command -v pgrep &>/dev/null; then
        pid=$(pgrep -x "$name" 2>/dev/null | head -1 || true)
    else
        pid=$(ps -e -o pid,comm 2>/dev/null | awk -v n="$name" '$2==n{print $1; exit}')
    fi

    if [[ -n "$pid" ]]; then
        # 额外确认进程存在
        if kill -0 "$pid" 2>/dev/null; then
            running=true
        else
            pid=""
        fi
    fi
    echo "$running $pid"
}

# ===== 重启进程 =====
restart_process() {
    local name="$1"
    local retries="$2"

    # 读取历史重启次数
    local count=0
    local state_file="$STATE_DIR/$name.count"
    [[ -f "$state_file" ]] && count=$(cat "$state_file")

    if [[ $count -ge $retries ]]; then
        _warn "$name 已达最大重启次数 ($retries)，不再自动重启"
        return 1
    fi

    case "$name" in
        sshd|nginx|apache2|mysql|mariadb)
            if command -v systemctl &>/dev/null; then
                systemctl restart "$name" 2>/dev/null && _warn "已通过 systemctl 重启 $name"
            elif command -v service &>/dev/null; then
                service "$name" restart 2>/dev/null && _warn "已通过 service 重启 $name"
            fi
            ;;
        *)
            _warn "未知进程 $name，无系统服务控制"
            return 1
            ;;
    esac

    count=$((count + 1))
    echo "$count" > "$state_file"
    return 0
}

# ===== 主流程 =====
main() {
    local processes=()
    local max_retries=3

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--process) processes+=("$2"); shift 2 ;;
            -r|--retries) max_retries="$2"; shift 2 ;;
            --reset) rm -rf "$STATE_DIR"; echo "状态已重置"; exit 0 ;;
            -h|--help)
                echo "用法: $0 [-p process] [-r retries] [--reset]"
                echo "  -p  监控的进程名（可多次使用，默认 nginx, sshd, mysql）"
                echo "  -r  最大重启次数（默认 3）"
                echo "  --reset  清除重启计数"
                exit 0 ;;
            *) shift ;;
        esac
    done

    # 默认进程
    [[ ${#processes[@]} -eq 0 ]] && processes=("sshd" "nginx" "mysql")

    # 防止并发运行
    mkdir -p "$STATE_DIR"
    if [[ -f "$PID_FILE" ]]; then
        local old_pid
        old_pid=$(cat "$PID_FILE")
        if kill -0 "$old_pid" 2>/dev/null; then
            _warn "process_guard 已在运行 (PID: $old_pid)"
            exit 0
        fi
    fi
    echo $$ > "$PID_FILE"
    trap 'rm -f "$PID_FILE"' EXIT

    local hostname
    hostname=$(hostname 2>/dev/null || echo "unknown")

    echo "{"
    echo "  \"timestamp\": \"$(_ts)\","
    echo "  \"hostname\": \"$(sed 's/"/\\"/g' <<< "$hostname")\","
    echo "  \"guarded_processes\": ["
    local fi=true
    for p in "${processes[@]}"; do
        $fi || echo ","
        fi=false
        echo -n "    \"$p\""
    done
    echo ""
    echo "  ],"
    echo "  \"status\": ["

    local actions_json=""
    local first_action=true
    local first_status=true
    local errors=0

    for p in "${processes[@]}"; do
        local result running pid
        result=$(check_process "$p")
        read running pid <<< "$result"

        local restarted=false
        local action_msg=""

        if ! $running; then
            _warn "进程 $p 未运行，尝试重启..."
            if restart_process "$p" "$max_retries"; then
                sleep 1
                # 检查重启后状态
                result=$(check_process "$p")
                read running pid <<< "$result"
                if $running; then
                    restarted=true
                    action_msg="$p 重启成功 (新PID: $pid)"
                    _warn "$action_msg"
                else
                    action_msg="$p 重启失败"
                    _err "$action_msg"
                    errors=$((errors + 1))
                fi
            else
                action_msg="$p 已达最大重试次数，放弃重启"
                _err "$action_msg"
                errors=$((errors + 1))
            fi

            $first_action || actions_json+=","
            first_action=false
            actions_json+=$'\n'"    { \"process\": \"$p\", \"action\": \"restart\", \"result\": \"$action_msg\", \"timestamp\": \"$(_ts)\" }"
        fi

        $first_status || echo ","
        first_status=false
        echo -n "    { \"name\": \"$p\", \"running\": $running, \"pid\": ${pid:-0}, \"restarted\": $restarted }"
    done

    echo ""
    echo "  ],"
    echo "  \"actions\": [$actions_json"
    if ! $first_action; then echo ""; fi
    echo "  ]"
    echo "}"

    if [[ $errors -gt 0 ]]; then
        exit 1
    fi
}

main "$@"
