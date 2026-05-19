#!/usr/bin/env python3
"""Python 模块单元测试。"""
import json
import os
import sys
import tempfile
import unittest
from unittest.mock import patch, MagicMock

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "python"))

import data_reader
import ai_engine
import shell_agent
import report_gen

# ===== 测试用模拟快照数据 =====
MOCK_SNAPSHOT_DATA = {
    "snapshot_id": "20240501_120000",
    "hostname": "test-server",
    "created_at": "2024-05-01 12:00:00",
    "system": {
        "timestamp": "2024-05-01 12:00:00",
        "hostname": "test-server",
        "cpu": {"usage_percent": 45.2, "load_avg_1min": 0.85, "load_avg_5min": 0.72, "load_avg_15min": 0.65, "cores": 4},
        "memory": {"total_mb": 7986, "used_mb": 3456, "available_mb": 4530, "usage_percent": 43.3},
        "disk": [{"mount": "/", "total_gb": 100, "used_gb": 45, "available_gb": 55, "usage_percent": 45}],
        "network": {"connections_total": 128, "connections_established": 64, "connections_listening": 12},
        "processes": {
            "total": 245,
            "top_cpu": [{"pid": 1234, "name": "mysqld", "cpu_percent": 23.5}],
            "top_mem": [{"pid": 5678, "name": "java", "mem_percent": 12.3}],
        },
    },
    "logs": {
        "timestamp": "2024-05-01 12:00:00",
        "scanned_files": ["/var/log/syslog"],
        "anomalies": [
            {"file": "/var/log/syslog", "line": 123, "severity": "error", "content": "connection refused"},
            {"file": "/var/log/syslog", "line": 456, "severity": "warning", "content": "disk space low"},
            {"file": "/var/log/syslog", "line": 789, "severity": "error", "content": "timeout"},
        ],
        "summary": {"total_anomalies": 3, "by_severity": {"critical": 0, "error": 2, "warning": 1, "info": 0}},
    },
    "status": "ok",
}

MOCK_SNAPSHOT = {"id": "20240501_120000", "path": "/tmp/test.json", "data": MOCK_SNAPSHOT_DATA}


class TestDataReader(unittest.TestCase):
    """data_reader 模块测试。"""

    def test_get_metrics(self):
        m = data_reader.get_metrics(MOCK_SNAPSHOT)
        self.assertEqual(m.get("hostname"), "test-server")
        self.assertEqual(m.get("cpu", {}).get("usage_percent"), 45.2)

    def test_get_metrics_category(self):
        cpu = data_reader.get_metrics(MOCK_SNAPSHOT, "cpu")
        self.assertEqual(cpu.get("cores"), 4)

    def test_get_anomalies(self):
        anomalies = data_reader.get_anomalies(MOCK_SNAPSHOT)
        self.assertEqual(len(anomalies), 3)

    def test_get_summary(self):
        s = data_reader.get_summary(MOCK_SNAPSHOT)
        self.assertEqual(s["hostname"], "test-server")
        self.assertEqual(s["cpu_usage"], 45.2)
        self.assertEqual(s["memory_usage"], 43.3)
        self.assertEqual(s["disk_usage_max"], 45)
        self.assertEqual(s["connections"], 64)
        self.assertEqual(s["process_count"], 245)
        self.assertEqual(s["anomaly_total"], 3)
        self.assertEqual(s["anomaly_error"], 2)
        self.assertEqual(s["anomaly_warning"], 1)
        self.assertEqual(s["top_cpu_process"], "mysqld")
        self.assertEqual(s["top_mem_process"], "java")

    def test_get_summary_empty(self):
        s = data_reader.get_summary({})
        self.assertEqual(s["hostname"], "unknown")
        self.assertEqual(s["cpu_usage"], 0)

    def test_list_snapshots_empty_dir(self):
        with tempfile.TemporaryDirectory() as tmp:
            with patch("data_reader._snapshot_dir", return_value=tmp):
                snaps = data_reader.list_snapshots()
                self.assertEqual(snaps, [])

    def test_get_latest_empty(self):
        with tempfile.TemporaryDirectory() as tmp:
            with patch("data_reader._snapshot_dir", return_value=tmp):
                self.assertIsNone(data_reader.get_latest())

    def test_get_snapshot_not_found(self):
        with tempfile.TemporaryDirectory() as tmp:
            with patch("data_reader._snapshot_dir", return_value=tmp):
                self.assertIsNone(data_reader.get_snapshot("nonexistent"))


class TestAiEngine(unittest.TestCase):
    """ai_engine 模块测试。"""

    def test_rule_analyze_normal(self):
        summary = {
            "cpu_usage": 30, "memory_usage": 40, "disk_usage_max": 50,
            "connections": 100, "process_count": 200, "anomaly_total": 0,
            "anomaly_critical": 0, "anomaly_error": 2, "cpu_load_1min": 0.5, "cpu_cores": 4,
        }
        result = ai_engine.rule_analyze(summary)
        self.assertIn("正常", result)

    def test_rule_analyze_critical(self):
        summary = {
            "cpu_usage": 95, "memory_usage": 92, "disk_usage_max": 96,
            "connections": 2000, "process_count": 500, "anomaly_total": 5,
            "anomaly_critical": 3, "anomaly_error": 15, "cpu_load_1min": 10, "cpu_cores": 4,
        }
        result = ai_engine.rule_analyze(summary)
        self.assertIn("CRITICAL", result)
        self.assertIn("WARNING", result)

    def test_rule_analyze_trigger_count(self):
        summary = {
            "cpu_usage": 95, "memory_usage": 40, "disk_usage_max": 50,
            "connections": 100, "process_count": 200, "anomaly_total": 0,
            "anomaly_critical": 0, "anomaly_error": 0, "cpu_load_1min": 0.5, "cpu_cores": 4,
        }
        result = ai_engine.rule_analyze(summary)
        self.assertIn("触发 2 条规则", result)

    def test_chat_fallback(self):
        reply = ai_engine._chat_fallback("查看CPU使用率", "test error")
        self.assertIn("top", reply.lower())

    def test_chat_fallback_memory(self):
        reply = ai_engine._chat_fallback("检查内存情况", "test error")
        self.assertIn("free", reply.lower())

    def test_chat_fallback_generic(self):
        reply = ai_engine._chat_fallback("今天天气怎么样", "test error")
        self.assertIn("离线模式", reply)

    @patch("ai_engine._call_api")
    def test_query_with_context(self, mock_call):
        mock_call.return_value = "一切正常"
        summary = {"cpu_usage": 30}
        result = ai_engine.query("分析系统", summary)
        self.assertEqual(result, "一切正常")

    @patch("ai_engine._call_api")
    def test_query_fallback(self, mock_call):
        mock_call.side_effect = RuntimeError("timeout")
        summary = {"cpu_usage": 95, "memory_usage": 40, "disk_usage_max": 50,
                   "connections": 100, "process_count": 200, "anomaly_total": 0,
                   "anomaly_critical": 0, "anomaly_error": 0, "cpu_load_1min": 0.5, "cpu_cores": 4}
        result = ai_engine.query("分析系统", summary)
        self.assertIn("离线规则分析", result)


class TestShellAgent(unittest.TestCase):
    """shell_agent 模块测试。"""

    def test_is_safe_blocks_rm_rf(self):
        self.assertFalse(shell_agent._is_safe("rm -rf /"))
        self.assertFalse(shell_agent._is_safe("rm -rf /*"))

    def test_is_safe_allows_normal(self):
        self.assertTrue(shell_agent._is_safe("df -h"))
        self.assertTrue(shell_agent._is_safe("top -bn1"))

    def test_nl_to_command_cpu(self):
        cmd = shell_agent._nl_to_command("查看CPU使用率")
        self.assertIn("top", cmd)

    def test_nl_to_command_memory(self):
        cmd = shell_agent._nl_to_command("查看内存")
        self.assertIn("free", cmd)

    def test_nl_to_command_disk(self):
        cmd = shell_agent._nl_to_command("查看磁盘使用")
        self.assertIn("df", cmd)

    def test_nl_to_command_unknown(self):
        cmd = shell_agent._nl_to_command("今天吃什么")
        self.assertEqual(cmd, "")

    def test_execute_unknown_query(self):
        result = shell_agent.execute("abcdefg xyz")
        self.assertFalse(result["success"])
        self.assertIn("无法理解", result["interpretation"])

    def test_execute_dangerous(self):
        result = shell_agent.execute("rm -rf /")
        self.assertFalse(result["success"])


class TestReportGen(unittest.TestCase):
    """report_gen 模块测试。"""

    def test_generate_markdown(self):
        with tempfile.TemporaryDirectory() as tmp:
            with patch("report_gen._REPORT_DIR", tmp):
                path = report_gen.generate(MOCK_SNAPSHOT, "测试分析结果", fmt="md")
                self.assertTrue(os.path.isfile(path))
                content = open(path, "r", encoding="utf-8").read()
                self.assertIn("系统健康报告", content)
                self.assertIn("test-server", content)
                self.assertIn("测试分析结果", content)

    def test_generate_html(self):
        with tempfile.TemporaryDirectory() as tmp:
            with patch("report_gen._REPORT_DIR", tmp):
                path = report_gen.generate(MOCK_SNAPSHOT, "测试分析结果", fmt="html")
                self.assertTrue(os.path.isfile(path))
                content = open(path, "r", encoding="utf-8").read()
                self.assertIn("<!DOCTYPE html>", content)
                self.assertIn("test-server", content)
                self.assertIn("测试分析结果", content)

    def test_generate_markdown_no_anomalies(self):
        snap = json.loads(json.dumps(MOCK_SNAPSHOT))
        snap["data"]["logs"]["anomalies"] = []
        snap["data"]["logs"]["summary"]["total_anomalies"] = 0
        with tempfile.TemporaryDirectory() as tmp:
            with patch("report_gen._REPORT_DIR", tmp):
                path = report_gen.generate(snap, "OK", fmt="md")
                self.assertTrue(os.path.isfile(path))


if __name__ == "__main__":
    unittest.main(verbosity=2)
