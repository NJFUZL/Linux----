#!/bin/bash
# cron_setup.sh — 一键部署/查看/移除 crontab 定时任务
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTO_REPORTER="$SCRIPT_DIR/auto_reporter.sh"
CRON_MARKER="# AI-Ops-Agent auto_reporter"

# ===== 安装 =====
cmd_install() {
    local interval="${1:-10}"  # 默认每 10 分钟

    if [[ ! -x "$AUTO_REPORTER" ]]; then
        echo "错误: 未找到 auto_reporter.sh" >&2
        exit 2
    fi

    # 检查是否已安装
    if crontab -l 2>/dev/null | grep -qF "$CRON_MARKER"; then
        echo "定时任务已存在，跳过安装"
        cmd_status
        return
    fi

    local cron_line="*/$interval * * * * bash $AUTO_REPORTER >> /tmp/ai_ops_reporter.log 2>&1 $CRON_MARKER"

    # 添加新任务（保留已有 crontab）
    {
        crontab -l 2>/dev/null || true
        echo "$cron_line"
    } | crontab -

    echo "定时任务已安装（每 ${interval} 分钟）"
    cmd_status
}

# ===== 移除 =====
cmd_uninstall() {
    if ! crontab -l 2>/dev/null | grep -qF "$CRON_MARKER"; then
        echo "未找到定时任务，无需移除"
        return
    fi

    crontab -l 2>/dev/null | grep -vF "$CRON_MARKER" | crontab -
    echo "定时任务已移除"
}

# ===== 状态 =====
cmd_status() {
    echo "=== AI Ops Agent 定时任务状态 ==="
    echo "脚本路径: $AUTO_REPORTER"

    if [[ -x "$AUTO_REPORTER" ]]; then
        echo "auto_reporter.sh: 存在且可执行"
    else
        echo "auto_reporter.sh: 不存在或无执行权限"
    fi
    echo ""

    if crontab -l 2>/dev/null | grep -qF "$CRON_MARKER"; then
        echo "当前 crontab 中的 AI Ops 任务:"
        crontab -l 2>/dev/null | grep -F "$CRON_MARKER"
    else
        echo "当前 crontab 中无 AI Ops 任务"
    fi
    echo ""

    # 显示最近的日志
    local log_file="/tmp/ai_ops_reporter.log"
    if [[ -f "$log_file" ]]; then
        echo "最近执行日志 (${log_file}):"
        tail -n 5 "$log_file" 2>/dev/null || true
    fi
}

# ===== 主流程 =====
case "${1:-}" in
    install)
        cmd_install "${2:-10}"
        ;;
    uninstall|remove)
        cmd_uninstall
        ;;
    status|check)
        cmd_status
        ;;
    -h|--help|help)
        echo "用法: $0 {install [interval]|uninstall|status}"
        echo "  install   安装定时任务（默认每 10 分钟）"
        echo "  uninstall 移除定时任务"
        echo "  status    查看定时任务状态"
        ;;
    *)
        echo "用法: $0 {install [interval]|uninstall|status}"
        echo "使用 $0 help 查看帮助"
        exit 1
        ;;
esac
