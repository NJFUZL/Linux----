"""自然语言 → Shell 命令 → 执行 → 结果解读。"""
import subprocess

# 危险命令黑名单
_BLOCKED = [
    "rm -rf /", "rm -rf /*", "rm -rf ~", "rm -rf .",
    ":(){ :|:& };:", "mkfs.", "dd if=", "> /dev/sd",
    "chmod 777 /", "chmod -R 777",
    "wget http", "curl http",  # 防止任意下载
]

# 自然语言关键词 → 安全命令
_TEMPLATES = [
    (("cpu", "使用率"), "top -bn1 | head -20"),
    (("cpu", "进程"), "ps -eo pid,pcpu,comm --sort=-pcpu | head -10"),
    (("内存",), "free -h"),
    (("磁盘", "使用"), "df -h"),
    (("磁盘", "io"), "iostat -x 1 2 2>/dev/null || echo 'iostat 未安装'"),
    (("网络", "连接"), "ss -tlnp"),
    (("网络", "流量"), "ss -s"),
    (("进程", "cpu"), "ps aux --sort=-%cpu | head -10"),
    (("进程", "内存"), "ps aux --sort=-%mem | head -10"),
    (("进程", "全部"), "ps aux"),
    (("负载",), "uptime"),
    (("内核", "版本"), "uname -a"),
    (("发行版",), "cat /etc/os-release 2>/dev/null || echo '未知'"),
    (("服务", "运行"), "systemctl list-units --type=service --state=running 2>/dev/null | head -20"),
    (("内核", "日志", "错误"), "dmesg | grep -iE 'error|fail|warn' | tail -20"),
    (("端口",), "ss -tlnp"),
    (("开机", "时间"), "uptime -s"),
    (("登录", "用户"), "who"),
    (("系统", "信息"), "uname -a && echo '---' && cat /etc/os-release 2>/dev/null"),
]


def _is_safe(command: str) -> bool:
    """检查命令是否包含危险操作。"""
    cmd = command.lower().strip()
    for pattern in _BLOCKED:
        if pattern.lower() in cmd:
            return False
    if "|" in cmd:
        return all(_is_safe(p) for p in cmd.split("|"))
    if ";" in cmd:
        return all(_is_safe(p) for p in cmd.split(";"))
    return True


def _nl_to_command(query: str) -> str:
    """将自然语言查询匹配到安全命令。"""
    q = query.lower()
    for keywords, cmd in _TEMPLATES:
        if all(kw in q for kw in keywords):
            return cmd
    return ""


def execute(nl_query: str, timeout: int = 15) -> dict:
    """执行自然语言查询，返回结构化结果。"""
    cmd = _nl_to_command(nl_query)

    if not cmd:
        return {
            "success": False,
            "command": "",
            "output": "",
            "interpretation": (
                "无法理解该查询。支持的查询类型：\n"
                "  - 查看CPU / 查看内存 / 查看磁盘\n"
                "  - 查看网络连接 / 查看进程\n"
                "  - 系统负载 / 内核版本 / 端口监听\n"
                "  - 登录用户 / 开机时间"
            ),
        }

    if not _is_safe(cmd):
        return {
            "success": False,
            "command": cmd,
            "output": "",
            "interpretation": f"命令被安全策略拦截。",
        }

    try:
        result = subprocess.run(
            ["bash", "-c", cmd],
            capture_output=True, text=True, timeout=timeout,
        )
        output = (result.stdout.strip() or result.stderr.strip())[:4000]
        return {
            "success": result.returncode == 0,
            "command": cmd,
            "output": output,
            "returncode": result.returncode,
            "interpretation": _interpret(output),
        }
    except subprocess.TimeoutExpired:
        return {
            "success": False, "command": cmd,
            "output": f"命令超时 ({timeout}s)",
            "interpretation": "命令执行时间过长，已终止。",
        }
    except FileNotFoundError:
        return {
            "success": False, "command": cmd,
            "output": "bash 不可用",
            "interpretation": "当前环境不支持执行 Shell 命令（非 Linux 系统或 bash 未安装）。",
        }


def _interpret(output: str) -> str:
    """对命令输出做简单解读。"""
    if not output.strip():
        return "命令无输出。"
    lines = output.strip().split("\n")
    return f"共 {len(lines)} 行输出。"
