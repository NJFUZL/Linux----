"""快照数据读取与查询。"""
import json
import os
from pathlib import Path

_DEFAULT_SNAPSHOT_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "snapshots")


def _snapshot_dir() -> str:
    return os.environ.get("AI_SNAPSHOT_DIR", _DEFAULT_SNAPSHOT_DIR)


def list_snapshots() -> list[dict]:
    """列出所有快照，按时间倒序。"""
    snap_dir = _snapshot_dir()
    if not os.path.isdir(snap_dir):
        return []
    snapshots = []
    for f in sorted(os.listdir(snap_dir), reverse=True):
        if not f.startswith("snapshot_") or not f.endswith(".json"):
            continue
        path = os.path.join(snap_dir, f)
        try:
            with open(path, "r", encoding="utf-8") as fh:
                snapshots.append({
                    "id": f.replace("snapshot_", "").replace(".json", ""),
                    "path": path,
                    "data": json.load(fh),
                })
        except (json.JSONDecodeError, OSError):
            continue
    return snapshots


def get_latest() -> dict | None:
    """获取最新快照。"""
    snapshots = list_snapshots()
    return snapshots[0] if snapshots else None


def get_snapshot(snapshot_id: str) -> dict | None:
    """根据 ID 获取指定快照。"""
    path = os.path.join(_snapshot_dir(), f"snapshot_{snapshot_id}.json")
    if not os.path.isfile(path):
        return None
    try:
        with open(path, "r", encoding="utf-8") as f:
            return {"id": snapshot_id, "path": path, "data": json.load(f)}
    except (json.JSONDecodeError, OSError):
        return None


def get_metrics(snapshot: dict, category: str = "") -> dict:
    """从快照中提取系统指标。category 为空返回全部。"""
    data = snapshot.get("data", snapshot) if isinstance(snapshot, dict) else {}
    system = data.get("system", {})
    return system.get(category, {}) if category else system


def get_anomalies(snapshot: dict) -> list[dict]:
    """从快照中提取日志异常列表。"""
    data = snapshot.get("data", snapshot) if isinstance(snapshot, dict) else {}
    return data.get("logs", {}).get("anomalies", [])


def get_summary(snapshot: dict) -> dict:
    """获取快照总览摘要，供分析和报告使用。"""
    data = snapshot.get("data", snapshot) if isinstance(snapshot, dict) else {}
    system = data.get("system", {})
    logs = data.get("logs", {})

    cpu = system.get("cpu", {})
    mem = system.get("memory", {})
    disk_list = system.get("disk", [])
    net = system.get("network", {})
    procs = system.get("processes", {})
    log_summary = logs.get("summary", {})

    return {
        "hostname": system.get("hostname", "unknown"),
        "timestamp": system.get("timestamp", ""),
        "cpu_usage": cpu.get("usage_percent", 0),
        "cpu_load_1min": cpu.get("load_avg_1min", 0),
        "cpu_cores": cpu.get("cores", 0),
        "memory_usage": mem.get("usage_percent", 0),
        "memory_total_mb": mem.get("total_mb", 0),
        "memory_used_mb": mem.get("used_mb", 0),
        "disk_count": len(disk_list),
        "disk_usage_max": max((d.get("usage_percent", 0) for d in disk_list), default=0),
        "connections": net.get("connections_established", 0),
        "connections_total": net.get("connections_total", 0),
        "process_count": procs.get("total", 0),
        "top_cpu_process": procs.get("top_cpu", [{}])[0].get("name", "") if procs.get("top_cpu") else "",
        "top_mem_process": procs.get("top_mem", [{}])[0].get("name", "") if procs.get("top_mem") else "",
        "anomaly_total": log_summary.get("total_anomalies", 0),
        "anomaly_critical": log_summary.get("by_severity", {}).get("critical", 0),
        "anomaly_error": log_summary.get("by_severity", {}).get("error", 0),
        "anomaly_warning": log_summary.get("by_severity", {}).get("warning", 0),
    }
