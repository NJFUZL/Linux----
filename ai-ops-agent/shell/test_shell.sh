#!/bin/bash
# test_shell.sh — Shell 脚本单元测试
set -euo pipefail

PASS=0
FAIL=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

green() { echo -e "\033[32m$*\033[0m"; }
red()   { echo -e "\033[31m$*\033[0m"; }

assert_pass() {
    local name="$1"
    echo -n "  [PASS] $name"
    green " ✓"
    PASS=$((PASS + 1))
}

assert_fail() {
    local name="$1"
    local reason="${2:-}"
    echo -n "  [FAIL] $name"
    red " ✗"
    if [[ -n "$reason" ]]; then
        echo "         原因: $reason"
    fi
    FAIL=$((FAIL + 1))
}

# ===== sys_collector 测试 =====
test_sys_collector() {
    echo "=== sys_collector.sh 测试 ==="

    if [[ ! -f "$SCRIPT_DIR/sys_collector.sh" ]]; then
        assert_fail "文件存在" "sys_collector.sh 不存在"
        return
    fi
    assert_pass "文件存在"

    # 语法检查
    if bash -n "$SCRIPT_DIR/sys_collector.sh" 2>&1; then
        assert_pass "语法检查"
    else
        assert_fail "语法检查" "语法错误"
    fi

    # 执行测试
    local output rc
    output=$(bash "$SCRIPT_DIR/sys_collector.sh" 2>/dev/null) && rc=$? || rc=$?
    if [[ $rc -le 2 ]]; then
        assert_pass "正常执行 (exit=$rc)"
    else
        assert_fail "正常执行" "exit code=$rc"
    fi

    # JSON 有效性（用 python 验证）
    if echo "$output" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
        assert_pass "输出为合法 JSON"
    else
        assert_fail "输出为合法 JSON" "JSON 解析失败"
    fi

    # 必要字段
    for field in timestamp hostname cpu memory disk network processes; do
        if echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert '$field' in d" 2>/dev/null; then
            assert_pass "包含字段: $field"
        else
            assert_fail "包含字段: $field" "缺少字段"
        fi
    done
}

# ===== log_scanner 测试 =====
test_log_scanner() {
    echo "=== log_scanner.sh 测试 ==="

    if [[ ! -f "$SCRIPT_DIR/log_scanner.sh" ]]; then
        assert_fail "文件存在" "log_scanner.sh 不存在"
        return
    fi
    assert_pass "文件存在"

    # 语法检查
    if bash -n "$SCRIPT_DIR/log_scanner.sh" 2>&1; then
        assert_pass "语法检查"
    else
        assert_fail "语法检查" "语法错误"
    fi

    # 用测试文件扫描
    local test_log="/tmp/test_ai_ops_$$.log"
    echo "2024-01-01 error: connection refused" > "$test_log"
    echo "2024-01-01 WARNING: disk space low" >> "$test_log"
    echo "2024-01-01 kernel panic: system halted" >> "$test_log"
    echo "2024-01-01 info: service started" >> "$test_log"

    local output rc
    output=$(bash "$SCRIPT_DIR/log_scanner.sh" -f "$test_log" 2>/dev/null) && rc=$? || rc=$?
    rm -f "$test_log"

    # JSON 有效性
    if echo "$output" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
        assert_pass "输出为合法 JSON"
    else
        assert_fail "输出为合法 JSON" "JSON 解析失败，输出: ${output:0:200}"
    fi

    # 必要字段
    for field in timestamp scanned_files anomalies summary; do
        if echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert '$field' in d" 2>/dev/null; then
            assert_pass "包含字段: $field"
        else
            assert_fail "包含字段: $field" "缺少字段"
        fi
    done

    # 应检测到至少 1 条异常
    local count
    count=$(echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['summary']['total_anomalies'])" 2>/dev/null || echo 0)
    if [[ $count -ge 3 ]]; then
        assert_pass "检测到异常 ($count 条)"
    else
        assert_fail "检测到异常" "预期 >=3 条，实际 $count 条"
    fi
}

# ===== process_guard 测试 =====
test_process_guard() {
    echo "=== process_guard.sh 测试 ==="

    if [[ ! -f "$SCRIPT_DIR/process_guard.sh" ]]; then
        assert_fail "文件存在" "process_guard.sh 不存在"
        return
    fi
    assert_pass "文件存在"

    # 语法检查
    if bash -n "$SCRIPT_DIR/process_guard.sh" 2>&1; then
        assert_pass "语法检查"
    else
        assert_fail "语法检查" "语法错误"
    fi

    # 用不存在的进程名测试（确保不会卡住）
    local output rc
    output=$(bash "$SCRIPT_DIR/process_guard.sh" -p "nonexist_process_test" 2>/dev/null) && rc=$? || rc=$?

    if echo "$output" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
        assert_pass "输出为合法 JSON"
    else
        assert_fail "输出为合法 JSON" "JSON 解析失败"
    fi

    # 必要字段
    for field in timestamp guarded_processes status actions; do
        if echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); assert '$field' in d" 2>/dev/null; then
            assert_pass "包含字段: $field"
        else
            assert_fail "包含字段: $field" "缺少字段"
        fi
    done
}

# ===== auto_reporter 测试 =====
test_auto_reporter() {
    echo "=== auto_reporter.sh 测试 ==="

    if [[ ! -f "$SCRIPT_DIR/auto_reporter.sh" ]]; then
        assert_fail "文件存在" "auto_reporter.sh 不存在"
        return
    fi
    assert_pass "文件存在"

    # 语法检查
    if bash -n "$SCRIPT_DIR/auto_reporter.sh" 2>&1; then
        assert_pass "语法检查"
    else
        assert_fail "语法检查" "语法错误"
    fi

    # 测试执行（输出到临时目录）
    local tmpdir="/tmp/ai_ops_test_$$"
    mkdir -p "$tmpdir"
    local output rc
    output=$(bash "$SCRIPT_DIR/auto_reporter.sh" -d "$tmpdir" -r 30 2>/dev/null) && rc=$? || rc=$?

    local snapshot_file=$(tail -1 <<< "$output")
    if [[ -f "$snapshot_file" ]]; then
        assert_pass "生成快照文件: $(basename "$snapshot_file")"

        # 验证快照内容
        if python3 -c "import sys,json; json.load(open('$snapshot_file'))" 2>/dev/null; then
            assert_pass "快照文件为合法 JSON"
        else
            assert_fail "快照文件为合法 JSON" "JSON 解析失败"
        fi
    else
        assert_fail "生成快照文件" "快照文件未创建"
    fi

    rm -rf "$tmpdir"
}

# ===== cron_setup 测试 =====
test_cron_setup() {
    echo "=== cron_setup.sh 测试 ==="

    if [[ ! -f "$SCRIPT_DIR/cron_setup.sh" ]]; then
        assert_fail "文件存在" "cron_setup.sh 不存在"
        return
    fi
    assert_pass "文件存在"

    # 语法检查
    if bash -n "$SCRIPT_DIR/cron_setup.sh" 2>&1; then
        assert_pass "语法检查"
    else
        assert_fail "语法检查" "语法错误"
    fi

    # 测试 status 子命令（不会修改系统）
    if bash "$SCRIPT_DIR/cron_setup.sh" status &>/dev/null; then
        assert_pass "status 子命令正常"
    else
        assert_fail "status 子命令" "执行失败"
    fi

    # 测试 help 子命令
    if bash "$SCRIPT_DIR/cron_setup.sh" help &>/dev/null; then
        assert_pass "help 子命令正常"
    else
        assert_fail "help 子命令" "执行失败"
    fi
}

# ===== 主流程 =====
echo "=============================="
echo "  Shell 脚本单元测试"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "=============================="
echo ""

test_sys_collector
echo ""
test_log_scanner
echo ""
test_process_guard
echo ""
test_auto_reporter
echo ""
test_cron_setup
echo ""

echo "=============================="
echo "  结果: $((PASS + FAIL)) 项测试, $PASS 通过, $FAIL 失败"
echo "=============================="

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
