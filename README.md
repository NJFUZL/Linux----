# AI 智能运维助手 (AI Ops Agent)

Linux 课程项目 — 融合 AI + Linux 运维，支持系统资源采集、日志智能分析和自然语言对话式操作。

## 快速开始

```bash
# 1. 安装 Python 依赖
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt

# 2. 配置 AI API（可选，不配置则使用离线规则引擎）
export AI_API_KEY="your-api-key"

# 3. 运行系统采集（需 Linux 环境）
bash shell/sys_collector.sh

# 4. 启动交互菜单
python3 python/main.py

# 5. 快速诊断
python3 python/main.py --quick

# 6. 生成报告
python3 python/main.py --report

# 7. AI 对话
python3 python/main.py --chat
```

## 项目结构

```
├── shell/                    # Shell 脚本（数据采集层）
│   ├── sys_collector.sh      # CPU/内存/磁盘/网络/进程采集
│   ├── log_scanner.sh        # 日志异常扫描
│   ├── process_guard.sh      # 关键进程监控守护
│   ├── auto_reporter.sh      # 快照编排（crontab 入口）
│   ├── cron_setup.sh         # 定时任务一键部署/移除
│   └── test_shell.sh         # Shell 单元测试
├── python/                   # Python 引擎
│   ├── main.py               # 主入口（交互菜单 + CLI）
│   ├── ai_engine.py          # LLM API + 离线规则引擎降级
│   ├── shell_agent.py        # 自然语言 → Shell 命令
│   ├── report_gen.py         # Markdown/HTML 报告生成
│   ├── data_reader.py        # 快照数据读取查询
│   └── config_loader.py      # YAML 配置 + 环境变量
├── tests/                    # 测试
│   ├── test_python.py        # Python 单元测试（27例）
│   ├── test_integration.py   # 集成测试（13例）
│   └── test_fixtures/        # 测试数据（正常/故障/健康）
├── demo/
│   └── demo.sh               # 功能演示脚本
├── config.yaml               # 配置文件
├── requirements.txt          # Python 依赖
└── README.md
```

## 核心功能

| 功能 | 说明 | 入口 |
|------|------|------|
| 系统采集 | 实时采集 CPU/内存/磁盘/网络/进程快照 | `bash shell/sys_collector.sh` |
| 日志扫描 | 基于模式匹配扫描系统日志异常 | `bash shell/log_scanner.sh -s` |
| 进程守护 | 关键进程宕机自动重启 | `bash shell/process_guard.sh` |
| 定时快照 | 周期性采集+扫描，生成快照文件 | `bash shell/cron_setup.sh install` |
| 快速诊断 | 非交互式一键健康检查 | `python3 python/main.py --quick` |
| AI 对话 | 自然语言运维咨询（离线降级） | `python3 python/main.py --chat` |
| Shell 指令 | 自然语言→安全Shell命令执行 | `python3 python/main.py --shell` |
| 报告生成 | Markdown/HTML 双格式健康报告 | `python3 python/main.py --report` |

## 数据流

```
Shell 脚本（stdout=纯JSON）→ Python subprocess → 解析 → AI分析/规则引擎 → 报告/对话
```

## 运行测试

```bash
# Python 单元测试
python3 tests/test_python.py

# 集成测试
python3 tests/test_integration.py

# Shell 语法检查 + 功能测试（需 Linux）
bash shell/test_shell.sh

# 演示脚本
bash demo/demo.sh
```

## 环境要求

- **Shell 脚本：** Linux 环境（WSL2 / 虚拟机），依赖 `/proc` 文件系统
- **Python：** 3.9+，依赖 `pyyaml`、`requests`
- **AI API：** 可选，未配置时自动使用离线规则引擎

## 配置

编辑 `config.yaml` 或设置环境变量（环境变量优先级更高）：

```bash
export AI_API_KEY="sk-xxxx"           # AI API 密钥
export AI_API_URL="https://..."       # API 地址
export AI_SNAPSHOT_DIR="data/snapshots"  # 快照目录
```

## 技术栈

Shell(bash)、grep/sed/awk、管道/重定向、进程管理(ps/pgrep/systemctl)、日志分析、crontab、Python subprocess、YAML、REST API、HTML/CSS

---

**开发周期：** 3 周 | **团队：** 3 人 | **代码量：** 2150+ 行
