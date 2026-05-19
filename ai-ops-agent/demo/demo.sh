#!/bin/bash
# demo.sh — 演示脚本：在 Linux 环境下运行完整功能流
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."

BOLD="\033[1m"
GREEN="\033[32m"
BLUE="\033[34m"
RESET="\033[0m"

header() {
    echo ""
    echo -e "${BOLD}${BLUE}========================================${RESET}"
    echo -e "${BOLD}${BLUE}  $*${RESET}"
    echo -e "${BOLD}${BLUE}========================================${RESET}"
    echo ""
}

check_linux() {
    if [[ "$(uname -s)" != "Linux" ]]; then
        echo "警告: 当前不是 Linux 环境，部分 Shell 功能可能不可用"
        echo "建议在 WSL2 / Linux 虚拟机中运行此演示"
        echo ""
    fi
}

check_deps() {
    local missing=""
    for cmd in python3 bash; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "缺少依赖: $cmd"
            missing="$missing $cmd"
        fi
    done
    if [[ -n "$missing" ]]; then
        echo "请先安装: $missing"
        exit 1
    fi
}

demo_sys_collector() {
    header "1. 系统资源采集 (sys_collector.sh)"
    echo "命令: bash shell/sys_collector.sh"
    echo ""
    if [[ "$(uname -s)" == "Linux" ]]; then
        bash "$PROJECT_DIR/shell/sys_collector.sh" 2>/dev/null | python3 -m json.tool 2>/dev/null | head -40 || echo "(采集失败，可能缺少 /proc)"
    else
        echo "(跳过 - 非 Linux 环境)"
    fi
}

demo_log_scanner() {
    header "2. 日志扫描 (log_scanner.sh)"

    # 创建测试日志
    local test_log="/tmp/demo_test_$$.log"
    cat > "$test_log" << 'EOF'
2024-05-01 10:00:01 server sshd[1234]: Failed password for root from 10.0.0.5 port 22 ssh2
2024-05-01 10:05:23 server kernel: [12345.678] Out of memory: Killed process 5678 (java)
2024-05-01 10:10:45 server nginx[2345]: connect() failed (111: Connection refused)
2024-05-01 10:15:02 server CRON[3456]: (root) CMD (cd / && run-parts --report /etc/cron.hourly)
2024-05-01 10:20:11 server mysqld[4567]: [Warning] Aborted connection 42 to db
2024-05-01 10:25:33 server kernel: [12456.789] BUG: soft lockup - CPU#1 stuck for 23s!
2024-05-01 10:30:00 server systemd[1]: nginx.service: Failed with result 'timeout'
2024-05-01 10:35:15 server sshd[5678]: error: maximum authentication attempts exceeded
2024-05-01 10:40:00 server postfix[6789]: fatal: connect to mysql: Connection refused
EOF

    echo "测试日志内容 ($test_log):"
    cat "$test_log"
    echo ""
    echo "扫描结果:"
    bash "$PROJECT_DIR/shell/log_scanner.sh" -f "$test_log" 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "(扫描失败)"
    rm -f "$test_log"
}

demo_process_guard() {
    header "3. 进程守护 (process_guard.sh)"

    echo "命令: bash shell/process_guard.sh -p bash -r 2"
    echo ""
    if [[ "$(uname -s)" == "Linux" ]]; then
        bash "$PROJECT_DIR/shell/process_guard.sh" -p bash -r 2 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "(守护失败)"
    else
        echo "(跳过 - 非 Linux 环境)"
    fi
}

demo_auto_reporter() {
    header "4. 自动快照 (auto_reporter.sh)"

    local tmpdir="/tmp/demo_snapshots_$$"
    mkdir -p "$tmpdir"

    echo "命令: bash shell/auto_reporter.sh -d $tmpdir -r 30"
    echo ""
    bash "$PROJECT_DIR/shell/auto_reporter.sh" -d "$tmpdir" -r 30 2>/dev/null || echo "(部分采集失败)"

    echo ""
    echo "生成的快照文件:"
    ls -la "$tmpdir"/snapshot_*.json 2>/dev/null || echo "(无)"


    # 显示快照摘要
    local latest=$(ls -t "$tmpdir"/snapshot_*.json 2>/dev/null | head -1)
    if [[ -n "$latest" ]]; then
        echo ""
        echo "快照内容预览:"
        python3 -c "
import json
with open('$latest') as f:
    d = json.load(f)
print(f'  主机: {d[\"system\"].get(\"hostname\", \"?\")}')
print(f'  时间: {d[\"created_at\"]}')
print(f'  状态: {d[\"status\"]}')
" 2>/dev/null || true
    fi

    rm -rf "$tmpdir"
}

demo_python_quick() {
    header "5. Python 快速诊断 (--quick)"

    # 先用 auto_reporter 创建测试快照
    local tmpdir="/tmp/demo_snapshots_py_$$"
    mkdir -p "$tmpdir"
    bash "$PROJECT_DIR/shell/auto_reporter.sh" -d "$tmpdir" -r 30 2>/dev/null || true

    echo "命令: AI_SNAPSHOT_DIR=$tmpdir python3 python/main.py --quick"
    echo ""
    AI_SNAPSHOT_DIR="$tmpdir" python3 "$PROJECT_DIR/python/main.py" --quick 2>/dev/null || echo "(AI API 未配置时使用离线规则引擎)"

    rm -rf "$tmpdir"
}

demo_python_report() {
    header "6. 报告生成 (--report)"

    local tmpdir="/tmp/demo_reports_$$"
    mkdir -p "$tmpdir"

    # 复制测试数据
    cp "$PROJECT_DIR/tests/test_fixtures/snapshot_normal.json" "$tmpdir/snapshot_20240501_120000.json"
    cp "$PROJECT_DIR/tests/test_fixtures/snapshot_critical.json" "$tmpdir/snapshot_20240502_083000.json"

    echo "命令: AI_SNAPSHOT_DIR=$tmpdir python3 python/main.py --report"
    echo ""
    AI_SNAPSHOT_DIR="$tmpdir" python3 "$PROJECT_DIR/python/main.py" --report 2>/dev/null || echo "(AI API 未配置，使用离线引擎)"

    echo ""
    echo "生成的报告文件:"
    find "$PROJECT_DIR/data/reports" -name "report_*.html" -newer "$tmpdir" 2>/dev/null | head -3 || echo "(无)"

    rm -rf "$tmpdir"
}

demo_cron_setup() {
    header "7. 定时任务管理 (cron_setup.sh)"

    echo "命令: bash shell/cron_setup.sh status"
    echo ""
    bash "$PROJECT_DIR/shell/cron_setup.sh" status 2>/dev/null || echo "(crontab 状态检查完成)"
}

demo_shell_agent() {
    header "8. 自然语言 Shell 操作 (shell_agent)"

    echo "命令: python3 -c \"import shell_agent; ...\""
    echo ""

    cd "$PROJECT_DIR/python"
    python3 -c "
import shell_agent
queries = ['查看CPU使用率', '查看内存', '查看磁盘使用', '系统负载']
for q in queries:
    r = shell_agent.execute(q)
    if r['success']:
        print(f'[NL] {q}')
        print(f'[CMD] \$ {r[\"command\"]}')
        print(r['output'][:300])
    else:
        print(f'[NL] {q} → {r[\"interpretation\"][:100]}')
    print()
" 2>/dev/null || echo "(在 Linux 环境运行可获得完整效果)"
}

demo_test() {
    header "9. 运行测试"

    echo "Python 单元测试:"
    python3 "$PROJECT_DIR/tests/test_python.py" 2>/dev/null | tail -5 || echo "(测试运行失败)"

    echo ""
    echo "集成测试:"
    python3 "$PROJECT_DIR/tests/test_integration.py" 2>/dev/null | tail -5 || echo "(集成测试运行失败)"
}

# ===== 主流程 =====
main() {
    echo -e "${BOLD}${GREEN}"
    echo "╔══════════════════════════════════════════╗"
    echo "║   AI 智能运维助手 — 功能演示脚本        ║"
    echo "║   AI Ops Agent Demo                     ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${RESET}"

    check_linux
    check_deps

    local all=${1:-all}

    case "$all" in
        shell|1)
            demo_sys_collector
            demo_log_scanner
            demo_process_guard
            ;;
        reporter|2)
            demo_auto_reporter
            demo_cron_setup
            ;;
        python|3)
            demo_python_quick
            demo_python_report
            demo_shell_agent
            ;;
        test|4)
            demo_test
            ;;
        *)
            demo_sys_collector
            demo_auto_reporter
            demo_python_quick
            demo_python_report
            demo_shell_agent
            demo_cron_setup
            demo_test
            ;;
    esac

    echo ""
    echo -e "${BOLD}${GREEN}演示完成！${RESET}"
    echo ""
    echo "下一步:"
    echo "  1. 配置 AI API Key: export AI_API_KEY='your-key'"
    echo "  2. 安装定时任务:  bash shell/cron_setup.sh install"
    echo "  3. 交互模式:      python3 python/main.py"
    echo "  4. 查看使用说明:  cat README.md"
}

main "${1:-all}"
