"""AI 引擎：LLM API 调用 + 离线规则引擎降级。"""
import json
import os
import time
import requests
import config_loader

# ===== 离线规则引擎 =====
RULES = [
    ("cpu_critical", lambda s: s.get("cpu_usage", 0) > 90, "critical",
     "CPU 使用率超过 90%，建议立即检查 top 进程，考虑扩容或限流"),
    ("memory_critical", lambda s: s.get("memory_usage", 0) > 90, "critical",
     "内存使用率超过 90%，建议释放缓存或增加内存"),
    ("disk_critical", lambda s: s.get("disk_usage_max", 0) > 95, "critical",
     "磁盘使用率超过 95%，建议立即清理或扩容"),
    ("anomaly_critical", lambda s: s.get("anomaly_critical", 0) > 0, "critical",
     "检测到严重级别日志异常（kernel panic/OOM/segfault），需立即排查"),
    ("cpu_warning", lambda s: s.get("cpu_usage", 0) > 70, "warning",
     "CPU 使用率偏高（>70%），建议关注"),
    ("memory_warning", lambda s: s.get("memory_usage", 0) > 70, "warning",
     "内存使用率偏高（>70%），建议关注"),
    ("disk_warning", lambda s: s.get("disk_usage_max", 0) > 80, "warning",
     "磁盘使用率超过 80%，建议关注并计划清理"),
    ("error_warning", lambda s: s.get("anomaly_error", 0) > 10, "warning",
     "错误日志数量较多（>10），建议检查日志详情"),
    ("load_high", lambda s: s.get("cpu_load_1min", 0) > s.get("cpu_cores", 1) * 2, "warning",
     "系统负载过高（1min load > CPU 核心数 × 2），建议排查高负载进程"),
    ("connections_high", lambda s: s.get("connections", 0) > 1000, "warning",
     "网络连接数超过 1000，建议检查是否有异常连接"),
]


def _call_api(messages: list[dict]) -> str:
    """调用 LLM API 并返回响应文本。"""
    api_url = config_loader.get("ai.api_url", "https://api.openai.com/v1/chat/completions")
    api_key = config_loader.get("ai.api_key", "") or os.environ.get("AI_API_KEY", "")
    model = config_loader.get("ai.model", "gpt-3.5-turbo")
    timeout = int(config_loader.get("ai.timeout", 30))
    max_retries = int(config_loader.get("ai.max_retries", 3))

    if not api_key:
        raise RuntimeError("AI API Key 未配置，请设置环境变量 AI_API_KEY")

    headers = {"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}
    payload = {"model": model, "messages": messages, "temperature": 0.7, "max_tokens": 1024}

    last_error = None
    for attempt in range(max_retries):
        try:
            resp = requests.post(api_url, headers=headers, json=payload, timeout=timeout)
            if resp.status_code == 200:
                return resp.json()["choices"][0]["message"]["content"]
            last_error = f"API 返回 {resp.status_code}: {resp.text[:200]}"
        except requests.Timeout:
            last_error = f"API 请求超时 ({timeout}s)"
        except requests.RequestException as e:
            last_error = str(e)
        if attempt < max_retries - 1:
            time.sleep(2 ** attempt)

    raise RuntimeError(last_error or "API 调用失败")


def query(prompt: str, context: dict | None = None) -> str:
    """向 AI 发送查询，返回分析结果。API 失败时自动降级到规则引擎。"""
    system_prompt = (
        "你是一个 Linux 系统运维助手。根据提供的系统快照数据进行专业分析，"
        "给出简洁、可操作的建议。不要超过 300 字。"
    )
    messages = [{"role": "system", "content": system_prompt}]
    if context:
        messages.append({
            "role": "system",
            "content": f"系统快照数据:\n{json.dumps(context, ensure_ascii=False, indent=2)}",
        })
    messages.append({"role": "user", "content": prompt})

    try:
        return _call_api(messages)
    except Exception as e:
        if context:
            return rule_analyze(context, str(e))
        return f"AI 服务不可用: {e}"


def chat(message: str, history: list[dict] | None = None) -> str:
    """对话模式：多轮对话。"""
    system_prompt = "你是一个 Linux 系统运维助手。回答运维相关问题，给出简洁实用的建议。"
    messages = [{"role": "system", "content": system_prompt}]
    if history:
        messages.extend(history)
    messages.append({"role": "user", "content": message})

    try:
        return _call_api(messages)
    except Exception as e:
        return _chat_fallback(message, str(e))


def _chat_fallback(message: str, error: str) -> str:
    """对话模式的离线降级回复。"""
    msg = message.lower()
    tips = [
        ("cpu", "使用 top/htop 查看 CPU 占用，关注 load average 是否超过 CPU 核心数"),
        ("内存", "使用 free -h 查看内存，关注 available 列而非 free 列"),
        ("磁盘", "使用 df -h 查看使用率，du -sh 排查大文件/目录"),
        ("网络", "使用 ss -tlnp 查看监听端口，ping/traceroute 排查连通性"),
        ("进程", "使用 ps aux 查看进程状态，kill 终止异常进程"),
        ("日志", "使用 journalctl -xe 查看系统日志，dmesg 查看内核日志"),
    ]
    for keyword, tip in tips:
        if keyword in msg:
            return f"[离线模式] {tip}\n(API 不可用: {error})"
    return (f"[离线模式] AI 服务暂时不可用({error})。"
            f"请尝试更具体的问题，如「查看CPU」「检查内存」「磁盘使用」等。")


def rule_analyze(summary: dict, fallback_reason: str = "") -> str:
    """离线规则引擎：基于阈值分析系统状态，返回诊断结果。"""
    lines = []
    if fallback_reason:
        lines.append(f"> AI 服务暂时不可用（{fallback_reason}），以下为离线规则分析。\n")

    lines.append("## 系统健康分析\n")
    lines.append(f"| 指标 | 当前值 |")
    lines.append(f"|------|--------|")
    lines.append(f"| CPU 使用率 | {summary.get('cpu_usage', 0):.1f}% |")
    lines.append(f"| 内存使用率 | {summary.get('memory_usage', 0):.1f}% |")
    lines.append(f"| 磁盘使用率(最大) | {summary.get('disk_usage_max', 0):.1f}% |")
    lines.append(f"| 活跃连接数 | {summary.get('connections', 0)} |")
    lines.append(f"| 进程总数 | {summary.get('process_count', 0)} |")
    lines.append(f"| 异常日志数 | {summary.get('anomaly_total', 0)} |")
    lines.append("")

    triggered = []
    for name, check, severity, advice in RULES:
        try:
            if check(summary):
                triggered.append((severity, advice))
        except Exception:
            pass

    if triggered:
        lines.append("### 诊断建议\n")
        for severity, advice in triggered:
            prefix = "CRITICAL" if severity == "critical" else "WARNING"
            lines.append(f"- **[{prefix}]** {advice}")
    else:
        lines.append("### 诊断建议\n")
        lines.append("- 系统各项指标正常，未发现明显异常。")

    lines.append(f"\n共触发 {len(triggered)} 条规则。")
    return "\n".join(lines)
