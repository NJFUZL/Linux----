"""健康报告生成：Markdown / HTML 格式。"""
import os
from datetime import datetime
import data_reader

_REPORT_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "reports")


def _build_markdown(snapshot: dict, analysis: str) -> str:
    """生成 Markdown 格式报告。"""
    s = data_reader.get_summary(snapshot)
    anomalies = data_reader.get_anomalies(snapshot)

    lines = [
        f"# AI 智能运维助手 — 系统健康报告",
        f"",
        f"**生成时间：** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        f"**主机名：** {s['hostname']}",
        f"**快照时间：** {s['timestamp']}",
        f"",
        f"---",
        f"",
        f"## 1. 系统概览",
        f"",
        f"| 指标 | 值 |",
        f"|------|----|",
        f"| CPU 使用率 | {s['cpu_usage']:.1f}% |",
        f"| CPU 负载 (1min) | {s['cpu_load_1min']:.2f} |",
        f"| CPU 核心数 | {s['cpu_cores']} |",
        f"| 内存使用率 | {s['memory_usage']:.1f}% |",
        f"| 内存 (已用/总量) | {s['memory_used_mb']}MB / {s['memory_total_mb']}MB |",
        f"| 磁盘使用率 (最高) | {s['disk_usage_max']:.1f}% |",
        f"| 活跃连接数 | {s['connections']} |",
        f"| 进程总数 | {s['process_count']} |",
        f"| CPU 占用最高进程 | {s['top_cpu_process']} |",
        f"| 内存占用最高进程 | {s['top_mem_process']} |",
        f"",
        f"---",
        f"",
        f"## 2. 日志异常统计",
        f"",
        f"| 严重级别 | 数量 |",
        f"|----------|------|",
        f"| Critical | {s['anomaly_critical']} |",
        f"| Error    | {s['anomaly_error']} |",
        f"| Warning  | {s['anomaly_warning']} |",
        f"| **总计** | **{s['anomaly_total']}** |",
        f"",
    ]

    if anomalies:
        lines.append("### 最近异常日志\n")
        lines.append("| 文件 | 行号 | 级别 | 内容 |")
        lines.append("|------|------|------|------|")
        for a in anomalies[:20]:
            content = a.get("content", "")[:60].replace("|", "\\|")
            lines.append(f"| {a.get('file', '')} | {a.get('line', '')} | {a.get('severity', '')} | {content} |")
        lines.append("")

    lines.extend([
        "---",
        "",
        "## 3. AI 诊断分析",
        "",
        analysis,
        "",
        "---",
        "",
        "*报告由 AI 智能运维助手自动生成*",
    ])

    return "\n".join(lines)


def _build_html(snapshot: dict, analysis: str) -> str:
    """生成 HTML 格式报告。"""
    s = data_reader.get_summary(snapshot)
    anomalies = data_reader.get_anomalies(snapshot)

    severity_color = {"critical": "#d32f2f", "error": "#f44336", "warning": "#ff9800", "info": "#2196f3"}

    anomaly_rows = ""
    for a in anomalies[:20]:
        color = severity_color.get(a.get("severity", ""), "#666")
        content = a.get("content", "")[:80].replace("<", "&lt;").replace(">", "&gt;")
        anomaly_rows += (
            f"<tr>"
            f"<td>{a.get('file', '')}</td>"
            f"<td>{a.get('line', '')}</td>"
            f"<td style='color:{color};font-weight:bold'>{a.get('severity', '')}</td>"
            f"<td>{content}</td>"
            f"</tr>\n"
        )

    status_class = "ok"
    if s["cpu_usage"] > 90 or s["memory_usage"] > 90:
        status_class = "critical"
    elif s["cpu_usage"] > 70 or s["memory_usage"] > 70:
        status_class = "warning"

    return f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<title>系统健康报告 — {s['hostname']}</title>
<style>
  body {{ font-family: -apple-system, 'Microsoft YaHei', sans-serif; max-width: 900px; margin: 0 auto; padding: 20px; color: #333; }}
  h1 {{ color: #1a73e8; border-bottom: 2px solid #1a73e8; padding-bottom: 10px; }}
  h2 {{ color: #444; margin-top: 30px; }}
  table {{ border-collapse: collapse; width: 100%; margin: 10px 0; }}
  th, td {{ border: 1px solid #ddd; padding: 8px 12px; text-align: left; }}
  th {{ background: #f5f5f5; }}
  .status-ok {{ color: #4caf50; font-weight: bold; }}
  .status-warning {{ color: #ff9800; font-weight: bold; }}
  .status-critical {{ color: #d32f2f; font-weight: bold; }}
  .footer {{ color: #999; font-size: 12px; margin-top: 40px; border-top: 1px solid #eee; padding-top: 10px; }}
  .analysis {{ background: #f8f9fa; padding: 15px; border-left: 4px solid #1a73e8; white-space: pre-wrap; }}
</style>
</head>
<body>
<h1>AI 智能运维助手 — 系统健康报告</h1>
<p><strong>主机名：</strong>{s['hostname']} &nbsp;|&nbsp; <strong>快照时间：</strong>{s['timestamp']} &nbsp;|&nbsp; <strong>状态：</strong><span class="status-{status_class}">{status_class.upper()}</span></p>

<h2>1. 系统概览</h2>
<table>
<tr><th>指标</th><th>值</th></tr>
<tr><td>CPU 使用率</td><td>{s['cpu_usage']:.1f}%</td></tr>
<tr><td>CPU 负载 (1min)</td><td>{s['cpu_load_1min']:.2f}</td></tr>
<tr><td>CPU 核心数</td><td>{s['cpu_cores']}</td></tr>
<tr><td>内存使用率</td><td>{s['memory_usage']:.1f}%</td></tr>
<tr><td>内存 (已用/总量)</td><td>{s['memory_used_mb']}MB / {s['memory_total_mb']}MB</td></tr>
<tr><td>磁盘使用率 (最高)</td><td>{s['disk_usage_max']:.1f}%</td></tr>
<tr><td>活跃连接数</td><td>{s['connections']}</td></tr>
<tr><td>进程总数</td><td>{s['process_count']}</td></tr>
<tr><td>CPU 占用最高进程</td><td>{s['top_cpu_process']}</td></tr>
<tr><td>内存占用最高进程</td><td>{s['top_mem_process']}</td></tr>
</table>

<h2>2. 日志异常统计</h2>
<table>
<tr><th>严重级别</th><th>数量</th></tr>
<tr><td>Critical</td><td>{s['anomaly_critical']}</td></tr>
<tr><td>Error</td><td>{s['anomaly_error']}</td></tr>
<tr><td>Warning</td><td>{s['anomaly_warning']}</td></tr>
<tr><th>总计</th><th>{s['anomaly_total']}</th></tr>
</table>

{f'''<h3>最近异常日志</h3>
<table>
<tr><th>文件</th><th>行号</th><th>级别</th><th>内容</th></tr>
{anomaly_rows}
</table>''' if anomaly_rows else '<p>未检测到异常日志。</p>'}

<h2>3. AI 诊断分析</h2>
<div class="analysis">{analysis.replace(chr(10), '<br>')}</div>

<div class="footer">报告由 AI 智能运维助手于 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} 自动生成</div>
</body>
</html>"""


def generate(snapshot: dict, analysis: str = "", fmt: str = "html") -> str:
    """生成报告并保存到文件，返回文件路径。"""
    os.makedirs(_REPORT_DIR, exist_ok=True)
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    hostname = data_reader.get_summary(snapshot).get("hostname", "unknown")

    if fmt == "html":
        ext = "html"
        content = _build_html(snapshot, analysis)
    else:
        ext = "md"
        content = _build_markdown(snapshot, analysis)

    filename = f"report_{hostname}_{ts}.{ext}"
    path = os.path.join(_REPORT_DIR, filename)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)

    return path
