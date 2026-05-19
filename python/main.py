#!/usr/bin/env python3
"""AI 智能运维助手 — 主入口（交互菜单 + 命令行参数）。"""
import argparse
import os
import sys

# 确保可导入同目录模块
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import data_reader
import ai_engine
import shell_agent
import report_gen


def _print_banner():
    print("=" * 50)
    print("  AI 智能运维助手 (AI Ops Agent)")
    print("=" * 50)


def cmd_quick():
    """快速诊断模式（非交互）。"""
    _print_banner()
    print("[*] 正在加载最新系统快照...\n")

    snapshot = data_reader.get_latest()
    if not snapshot:
        print("[!] 未找到系统快照，请先运行 auto_reporter.sh")
        return

    summary = data_reader.get_summary(snapshot)
    print(f"  主机: {summary['hostname']}")
    print(f"  快照: {summary['timestamp']}")
    print(f"  CPU:  {summary['cpu_usage']:.1f}%  |  内存: {summary['memory_usage']:.1f}%  |"
          f"  磁盘: {summary['disk_usage_max']:.1f}%")
    print(f"  连接: {summary['connections']}  |  进程: {summary['process_count']}  |"
          f"  异常: {summary['anomaly_total']}")
    print()

    print("[*] AI 分析中...\n")
    analysis = ai_engine.query("请对这个系统进行快速健康诊断。", summary)
    print(analysis)


def cmd_report(fmt: str = "html"):
    """生成健康报告。"""
    _print_banner()
    print("[*] 正在生成报告...\n")

    snapshot = data_reader.get_latest()
    if not snapshot:
        print("[!] 未找到系统快照。")
        return

    summary = data_reader.get_summary(snapshot)
    analysis = ai_engine.query("请分析系统快照数据，生成详细的诊断报告。", summary)
    path = report_gen.generate(snapshot, analysis, fmt=fmt)
    print(f"[OK] 报告已保存: {path}")


def cmd_chat():
    """对话模式。"""
    _print_banner()
    print("对话模式（输入 /quit 退出，/shell 切换命令模式）\n")

    history = []
    while True:
        try:
            msg = input("You > ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\n再见！")
            break

        if not msg:
            continue
        if msg == "/quit":
            break

        if msg.startswith("/shell "):
            nl = msg[7:].strip()
            result = shell_agent.execute(nl)
            print(f"\n[CMD] $ {result['command']}")
            print(result["output"])
            if result["interpretation"]:
                print(f"[*] {result['interpretation']}")
            print()
            continue

        print("[AI] 思考中...")
        reply = ai_engine.chat(msg, history)
        print(f"AI > {reply}\n")
        history.append({"role": "user", "content": msg})
        history.append({"role": "assistant", "content": reply})
        # 只保留最近 20 轮
        if len(history) > 40:
            history = history[-40:]

    print("再见！")


def cmd_shell():
    """Shell 命令模式（交互式）。"""
    _print_banner()
    print("Shell 命令模式 — 自然语言 → Shell 命令（输入 /quit 退出）\n")
    print("示例: 查看CPU / 查看内存 / 查看磁盘 / 查看进程 / 端口监听\n")

    while True:
        try:
            msg = input("shell > ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\n再见！")
            break

        if not msg:
            continue
        if msg in ("/quit", "exit", "quit"):
            break

        result = shell_agent.execute(msg)
        if result["command"]:
            print(f"[CMD] $ {result['command']}")
        if result["output"]:
            print(result["output"])
        if result["interpretation"]:
            print(f"[*] {result['interpretation']}")
        print()


def cmd_menu():
    """交互菜单。"""
    while True:
        _print_banner()
        print("  1. 快速诊断")
        print("  2. 生成报告")
        print("  3. AI 对话")
        print("  4. Shell 命令")
        print("  5. 查看快照历史")
        print("  0. 退出")
        print("-" * 50)

        try:
            choice = input("请选择 > ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\n再见！")
            break

        if choice == "1":
            cmd_quick()
        elif choice == "2":
            fmt = input("报告格式 (html/md, 默认 html): ").strip() or "html"
            cmd_report(fmt)
        elif choice == "3":
            cmd_chat()
        elif choice == "4":
            cmd_shell()
        elif choice == "5":
            snapshots = data_reader.list_snapshots()
            if not snapshots:
                print("[!] 无快照记录")
            else:
                print(f"\n{'ID':<20} {'时间':<22} {'主机':<15}")
                print("-" * 60)
                for snap in snapshots[:10]:
                    s = data_reader.get_summary(snap)
                    print(f"{snap['id']:<20} {s['timestamp']:<22} {s['hostname']:<15}")
                print()
        elif choice == "0":
            print("再见！")
            break
        else:
            print("无效选项")

        if choice not in ("3", "4"):  # 对话/命令模式内部自己循环
            input("\n按回车键继续...")


def main():
    parser = argparse.ArgumentParser(description="AI 智能运维助手")
    parser.add_argument("--quick", action="store_true", help="快速诊断（非交互）")
    parser.add_argument("--chat", action="store_true", help="AI 对话模式")
    parser.add_argument("--shell", action="store_true", help="Shell 命令模式（自然语言→命令）")
    parser.add_argument("--report", action="store_true", help="生成健康报告")
    parser.add_argument("--format", choices=("html", "md"), default="html", help="报告格式 (默认 html)")
    args = parser.parse_args()

    if args.quick:
        cmd_quick()
    elif args.chat:
        cmd_chat()
    elif args.shell:
        cmd_shell()
    elif args.report:
        cmd_report(args.format)
    else:
        cmd_menu()


if __name__ == "__main__":
    main()
