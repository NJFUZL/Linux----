# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

AI 智能运维助手（AI Ops Agent）— Linux 课程项目，3 人团队，3 周开发。融合 AI + Linux 运维，支持系统资源采集、日志智能分析和自然语言对话式操作。

## 架构

```
Shell 脚本（模块A）
  sys_collector.sh  → 采集 CPU/内存/磁盘/网络/进程，输出 JSON
  log_scanner.sh    → grep/sed/awk 扫描日志异常，输出 JSON
  process_guard.sh  → 监控关键进程，异常告警/重启
  auto_reporter.sh  → 编排采集+扫描，写快照文件（crontab 入口）
  cron_setup.sh     → 一键部署/移除 crontab 定时任务

Python 引擎（模块B）
  main.py           → 交互菜单 + 命令行参数入口
  ai_engine.py      → LLM API 调用 + 离线规则引擎降级
  shell_agent.py    → 自然语言 → Shell 命令 → 执行 → 解读
  report_gen.py     → Markdown/HTML 健康报告
  data_reader.py    → 读取快照 JSON，提供查询接口
  config_loader.py  → 读取 config.yaml + 环境变量注入

数据流：Shell stdout(纯JSON) → Python subprocess → 解析 → AI分析 → 报告/对话
```

## 目录结构

- `shell/` — Shell 脚本（人员A）
- `python/` — Python 模块（人员B）
- `data/snapshots/` — 系统快照 JSON
- `data/reports/` — 生成的诊断报告
- `tests/` — 集成测试和测试用例
- `docs/` — 项目规划书、项目报告、使用说明
- `demo/` — 演示脚本和视频

## 开发环境

**重要：** Shell 脚本依赖 `/proc` 文件系统和 Linux 命令（ps/df/ss/pgrep 等），必须在 Linux 环境下开发和测试。推荐 WSL2 Ubuntu 或 Linux 虚拟机。

```bash
# 首次使用
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt

# 配置 AI API（编辑 config.yaml 或设环境变量）
export AI_API_KEY="your-key"
```

## 运行命令

```bash
# Shell 独立测试
bash shell/sys_collector.sh                    # 查看系统快照
bash shell/log_scanner.sh -s                    # 扫描系统日志

# Python 主程序
python3 python/main.py                          # 交互菜单
python3 python/main.py --quick                  # 快速诊断（非交互）
python3 python/main.py --chat                   # 对话模式
python3 python/main.py --report                 # 直接生成报告

# Crontab 管理
bash shell/cron_setup.sh install                # 安装定时任务
bash shell/cron_setup.sh status                 # 查看状态
bash shell/cron_setup.sh uninstall              # 移除

# 测试
bash shell/test_shell.sh                        # Shell 单元测试
python3 python/test_python.py                   # Python 单元测试
```

## Shell ↔ Python 接口约定

- Shell 脚本 stdout = 纯 JSON（供 Python 解析），stderr = 日志/提示
- exit code: 0=成功, 1=部分失败, 2=致命错误
- Python 通过 `subprocess.run(["bash", "shell/xxx.sh"], ...)` 调用 Shell
- 快照文件命名：`snapshot_YYYYMMDD_HHMMSS.json`，存入 `data/snapshots/`

## Git 分支策略

```
main → develop → feature/shell-scripts（人员A）
               → feature/python-engine（人员B）
```

提交格式：`[Shell] 简要说明` / `[Python] 简要说明`
