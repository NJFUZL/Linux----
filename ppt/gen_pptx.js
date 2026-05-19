const pptxgen = require('pptxgenjs');
const fs = require('fs');
const path = require('path');

async function build() {
    const pptx = new pptxgen();
    pptx.layout = 'LAYOUT_16x9';
    pptx.author = 'AI Ops Team';
    pptx.title = 'AI 智能运维助手 - 项目规划';

    // ── Slide 1: Title ──
    const s1 = pptx.addSlide();
    s1.background = { fill: '0D1B2A' };
    s1.addText('AI 智能运维助手', { x: 0.5, y: 1.2, w: 9, h: 1.2, fontSize: 36, bold: true, color: 'FFFFFF', align: 'center', fontFace: 'Arial' });
    s1.addText('AI Ops Agent — Linux 课程项目', { x: 0.5, y: 2.3, w: 9, h: 0.6, fontSize: 18, color: '7EB8DA', align: 'center', fontFace: 'Arial' });
    s1.addText('Shell 系统采集 + AI 智能诊断 + 对话式运维', { x: 2.5, y: 3.2, w: 5, h: 0.5, fontSize: 13, color: 'A8D8EA', align: 'center', fontFace: 'Arial', shape: pptx.shapes.ROUNDED_RECTANGLE, fill: { color: '1B3A5C' }, rectRadius: 0.1 });
    s1.addText('3 人团队 · 3 周开发 · Linux + AI 融合', { x: 0.5, y: 4.3, w: 9, h: 0.4, fontSize: 11, color: '5A7A9A', align: 'center', fontFace: 'Arial' });

    // ── Slide 2: 项目概述 ──
    const s2 = pptx.addSlide();
    s2.background = { fill: 'F5F7FA' };
    s2.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: 10, h: 0.06, fill: { color: '1A3A5C' } });
    s2.addText('项目概述', { x: 0.4, y: 0.25, w: 4, h: 0.5, fontSize: 26, bold: true, color: '1A3A5C', fontFace: 'Arial' });
    s2.addShape(pptx.shapes.RECTANGLE, { x: 0.4, y: 0.7, w: 0.6, h: 0.03, fill: { color: '2B579A' } });
    const cards2 = [
        { title: '项目目标', text: '开发一个融合 AI 的 Linux 系统运维助手，支持系统资源自动采集、日志智能分析、AI 诊断建议和自然语言对话式操作。' },
        { title: '核心理念', text: '让 AI 读懂系统状态 — 定时采集系统指标，送入 LLM 分析，自动诊断问题并给出可操作修复建议。' },
        { title: '交付产出', text: 'Shell 脚本集（4个）+ Python 引擎（5个模块）+ 快照数据 + 诊断报告 + 单元测试 + 完整文档' },
    ];
    cards2.forEach((c, i) => {
        const y = 1.0 + i * 1.05;
        s2.addShape(pptx.shapes.ROUNDED_RECTANGLE, { x: 0.4, y, w: 9.2, h: 0.9, fill: { color: 'FFFFFF' }, rectRadius: 0.1, line: { color: '2B579A', width: 0 } });
        s2.addShape(pptx.shapes.RECTANGLE, { x: 0.4, y, w: 0.06, h: 0.9, fill: { color: '2B579A' } });
        s2.addText(c.title, { x: 0.65, y: y + 0.08, w: 3, h: 0.3, fontSize: 14, bold: true, color: '2B579A', fontFace: 'Arial' });
        s2.addText(c.text, { x: 0.65, y: y + 0.35, w: 8.7, h: 0.5, fontSize: 11, color: '333333', fontFace: 'Arial' });
    });

    // ── Slide 3: 核心功能 ──
    const s3 = pptx.addSlide();
    s3.background = { fill: 'F5F7FA' };
    s3.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: 10, h: 0.06, fill: { color: '1A3A5C' } });
    s3.addText('核心功能（3 个模块）', { x: 0.4, y: 0.25, w: 6, h: 0.5, fontSize: 26, bold: true, color: '1A3A5C', fontFace: 'Arial' });
    s3.addShape(pptx.shapes.RECTANGLE, { x: 0.4, y: 0.7, w: 0.6, h: 0.03, fill: { color: '2B579A' } });
    const mods = [
        { num: '1', title: '系统采集与日志分析', desc: 'Shell 一键采集 CPU/内存/磁盘/网络/进程指标；grep/sed/awk 扫描系统日志异常模式，输出标准化 JSON。' },
        { num: '2', title: 'AI 智能诊断引擎', desc: 'Python 封装 Prompt 调用 LLM API 分析系统健康状态，输出严重程度分级和修复建议；API 不可用时自动降级为离线规则引擎。' },
        { num: '3', title: '对话式运维终端', desc: '自然语言输入需求，AI 翻译为 Shell 命令，用户确认后执行并解读结果；内置危险命令拦截和超时保护。' },
    ];
    mods.forEach((m, i) => {
        const x = 0.4 + i * 3.1;
        s3.addShape(pptx.shapes.ROUNDED_RECTANGLE, { x, y: 1.0, w: 2.9, h: 3.5, fill: { color: 'FFFFFF' }, rectRadius: 0.1 });
        s3.addShape(pptx.shapes.OVAL, { x: x + 1.0, y: 1.2, w: 0.6, h: 0.6, fill: { color: '2B579A' } });
        s3.addText(m.num, { x: x + 1.0, y: 1.25, w: 0.6, h: 0.5, fontSize: 18, bold: true, color: 'FFFFFF', align: 'center', fontFace: 'Arial' });
        s3.addText(m.title, { x: x + 0.2, y: 2.0, w: 2.5, h: 0.4, fontSize: 13, bold: true, color: '1A3A5C', align: 'center', fontFace: 'Arial' });
        s3.addText(m.desc, { x: x + 0.2, y: 2.5, w: 2.5, h: 1.8, fontSize: 10, color: '555555', fontFace: 'Arial' });
    });

    // ── Slide 4: 技术架构 ──
    const s4 = pptx.addSlide();
    s4.background = { fill: 'F5F7FA' };
    s4.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: 10, h: 0.06, fill: { color: '1A3A5C' } });
    s4.addText('技术架构与数据流', { x: 0.4, y: 0.25, w: 6, h: 0.5, fontSize: 26, bold: true, color: '1A3A5C', fontFace: 'Arial' });
    s4.addShape(pptx.shapes.RECTANGLE, { x: 0.4, y: 0.7, w: 0.6, h: 0.03, fill: { color: '2B579A' } });
    // Flow boxes
    const flowItems = ['crontab / 手动触发', 'Shell 采集层\nsys_collector · log_scanner · process_guard', 'Python 引擎层\ndata_reader → ai_engine → report_gen', '交互层\n终端菜单 · 对话模式 · 报告查看'];
    flowItems.forEach((t, i) => {
        const y = 0.9 + i * 0.85;
        s4.addShape(pptx.shapes.ROUNDED_RECTANGLE, { x: 0.4, y, w: 4.5, h: 0.6, fill: { color: 'FFFFFF' }, rectRadius: 0.08 });
        s4.addText(t, { x: 0.5, y, w: 4.3, h: 0.6, fontSize: 9, color: '333333', align: 'center', valign: 'middle', fontFace: 'Arial' });
        if (i < 3) s4.addText('↓', { x: 0.4, y: y + 0.6, w: 4.5, h: 0.25, fontSize: 12, color: '2B579A', align: 'center', fontFace: 'Arial' });
    });
    // Tech tags
    s4.addText('覆盖技术（11 项）', { x: 5.5, y: 0.9, w: 4, h: 0.35, fontSize: 14, bold: true, color: '2B579A', fontFace: 'Arial' });
    const techs = ['Shell (bash)', 'grep/sed/awk', '管道/重定向', '进程管理', '日志分析', 'crontab', '网络命令', '文件/权限', 'Python+Linux', 'Agent调用', 'Git 版本控制'];
    techs.forEach((t, i) => {
        const col = i % 2;
        const row = Math.floor(i / 2);
        s4.addShape(pptx.shapes.ROUNDED_RECTANGLE, { x: 5.5 + col * 2.1, y: 1.35 + row * 0.35, w: 1.9, h: 0.28, fill: { color: 'E8F0FE' }, rectRadius: 0.04 });
        s4.addText(t, { x: 5.5 + col * 2.1, y: 1.35 + row * 0.35, w: 1.9, h: 0.28, fontSize: 8, color: '1A3A5C', align: 'center', valign: 'middle', fontFace: 'Arial' });
    });
    s4.addText('接口约定', { x: 5.5, y: 3.6, w: 4, h: 0.35, fontSize: 14, bold: true, color: '2B579A', fontFace: 'Arial' });
    s4.addText('Shell stdout = 纯 JSON\nShell stderr = 日志/提示\nPython subprocess.run() 调用', { x: 5.5, y: 3.95, w: 4, h: 0.6, fontSize: 10, color: '555555', fontFace: 'Arial' });

    // ── Slide 5: 小组分工 ──
    const s5 = pptx.addSlide();
    s5.background = { fill: 'F5F7FA' };
    s5.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: 10, h: 0.06, fill: { color: '1A3A5C' } });
    s5.addText('小组分工（3 人）', { x: 0.4, y: 0.25, w: 6, h: 0.5, fontSize: 26, bold: true, color: '1A3A5C', fontFace: 'Arial' });
    s5.addShape(pptx.shapes.RECTANGLE, { x: 0.4, y: 0.7, w: 0.6, h: 0.03, fill: { color: '2B579A' } });
    const team = [
        { badge: '人员 A · Shell 方向', color: '2B579A', title: '模块 A：采集与分析层', items: ['common.sh — 公共函数库', 'sys_collector.sh — 系统资源采集', 'log_scanner.sh — 日志扫描分析', 'process_guard.sh — 进程守护', 'auto_reporter.sh — 定时快照编排', 'cron_setup.sh — crontab 部署', 'test_shell.sh — Shell 单元测试'] },
        { badge: '人员 B · AI 引擎方向', color: '1A7A5A', title: '模块 B：诊断核心', items: ['ai_engine.py — AI 诊断引擎', 'data_reader.py — 快照数据读取解析', 'config_loader.py — 配置加载与管理', 'config.yaml — 全局配置', 'AI Prompt 模板设计与调优', '离线规则引擎开发'] },
        { badge: '人员 C · 交互与集成', color: 'D4760A', title: '模块 C：界面与测试', items: ['main.py — 主入口交互菜单', 'shell_agent.py — 对话式运维代理', 'report_gen.py — 报告生成器', 'utils.py — 公共工具函数', 'test_python.py — Python 单元测试', '集成测试脚本编写'] },
    ];
    team.forEach((m, i) => {
        const x = 0.4 + i * 3.1;
        s5.addShape(pptx.shapes.ROUNDED_RECTANGLE, { x, y: 0.9, w: 2.9, h: 3.7, fill: { color: 'FFFFFF' }, rectRadius: 0.1 });
        s5.addShape(pptx.shapes.ROUNDED_RECTANGLE, { x: x + 0.15, y: 1.0, w: 2.6, h: 0.35, fill: { color: m.color }, rectRadius: 0.06 });
        s5.addText(m.badge, { x: x + 0.15, y: 1.02, w: 2.6, h: 0.32, fontSize: 10, bold: true, color: 'FFFFFF', align: 'center', fontFace: 'Arial' });
        s5.addText(m.title, { x: x + 0.15, y: 1.5, w: 2.6, h: 0.35, fontSize: 12, bold: true, color: '1A3A5C', fontFace: 'Arial' });
        s5.addText(m.items.join('\n'), { x: x + 0.15, y: 1.9, w: 2.6, h: 2.5, fontSize: 9, color: '444444', fontFace: 'Arial', valign: 'top' });
    });

    // ── Slide 6: 开发计划 ──
    const s6 = pptx.addSlide();
    s6.background = { fill: 'F5F7FA' };
    s6.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: 10, h: 0.06, fill: { color: '1A3A5C' } });
    s6.addText('3 周开发计划', { x: 0.4, y: 0.25, w: 6, h: 0.5, fontSize: 26, bold: true, color: '1A3A5C', fontFace: 'Arial' });
    s6.addShape(pptx.shapes.RECTANGLE, { x: 0.4, y: 0.7, w: 0.6, h: 0.03, fill: { color: '2B579A' } });
    const weeks = [
        { week: '第 1 周', title: '基础设施 + 核心采集', a: 'Git仓库，common.sh，sys_collector.sh，log_scanner.sh', b: 'config_loader，data_reader，ai_engine框架', c: 'main.py菜单框架，shell_agent原型，utils.py', check: '✓ Shell输出合法JSON，Python可解析' },
        { week: '第 2 周', title: '功能完善 + 集成', a: 'auto_reporter.sh，cron_setup.sh，process_guard', b: 'ai_engine完善(API+重试+解析)', c: 'shell_agent完善，report_gen.py', check: '✓ 全链路采集→AI→报告跑通' },
        { week: '第 3 周', title: '测试 + 文档 + 交付', a: 'test_shell.sh，兼容测试，运行截图', b: 'Prompt调优，项目报告技术章节', c: 'test_python.py，集成测试，演示视频', check: '✓ Tag v1.0，所有材料打包' },
    ];
    weeks.forEach((w, i) => {
        const x = 0.4 + i * 3.1;
        s6.addShape(pptx.shapes.ROUNDED_RECTANGLE, { x, y: 0.9, w: 2.9, h: 3.7, fill: { color: 'FFFFFF' }, rectRadius: 0.1 });
        s6.addShape(pptx.shapes.ROUNDED_RECTANGLE, { x: x + 0.15, y: 1.0, w: 1.2, h: 0.3, fill: { color: '2B579A' }, rectRadius: 0.05 });
        s6.addText(w.week, { x: x + 0.15, y: 1.0, w: 1.2, h: 0.3, fontSize: 10, bold: true, color: 'FFFFFF', align: 'center', fontFace: 'Arial' });
        s6.addText(w.title, { x: x + 0.15, y: 1.4, w: 2.6, h: 0.35, fontSize: 12, bold: true, color: '1A3A5C', fontFace: 'Arial' });
        s6.addText('A: ' + w.a + '\n\nB: ' + w.b + '\n\nC: ' + w.c, { x: x + 0.15, y: 1.8, w: 2.6, h: 2.0, fontSize: 8, color: '444444', fontFace: 'Arial', valign: 'top' });
        s6.addShape(pptx.shapes.ROUNDED_RECTANGLE, { x: x + 0.1, y: 4.0, w: 2.7, h: 0.35, fill: { color: 'FFF9E6' }, rectRadius: 0.05 });
        s6.addText(w.check, { x: x + 0.1, y: 4.0, w: 2.7, h: 0.35, fontSize: 8, color: '8B7300', align: 'center', fontFace: 'Arial' });
    });

    // ── Slide 7: 风险应对 ──
    const s7 = pptx.addSlide();
    s7.background = { fill: 'F5F7FA' };
    s7.addShape(pptx.shapes.RECTANGLE, { x: 0, y: 0, w: 10, h: 0.06, fill: { color: '1A3A5C' } });
    s7.addText('风险识别与应对', { x: 0.4, y: 0.25, w: 6, h: 0.5, fontSize: 26, bold: true, color: '1A3A5C', fontFace: 'Arial' });
    s7.addShape(pptx.shapes.RECTANGLE, { x: 0.4, y: 0.7, w: 0.6, h: 0.03, fill: { color: '2B579A' } });
    const risks = [
        { title: 'AI API 不可用', text: '内置离线规则引擎降级；支持多 Provider 切换（OpenAI / DeepSeek / Ollama 本地）。' },
        { title: '环境兼容性', text: '开发用 WSL2 / 虚拟机；脚本添加环境检测提示；演示优先使用 WSL。' },
        { title: '日志权限不足', text: '脚本检查可读性；给出 sudo 提示；提供模拟日志文件用于无权限环境演示。' },
        { title: '工作量协调', text: '3 人分工明确各司其职；每日沟通同步；优先核心路径，非核心功能后延。' },
    ];
    risks.forEach((r, i) => {
        const x = 0.4 + i * 2.35;
        s7.addShape(pptx.shapes.ROUNDED_RECTANGLE, { x, y: 0.9, w: 2.15, h: 3.5, fill: { color: 'FFFFFF' }, rectRadius: 0.1 });
        s7.addShape(pptx.shapes.RECTANGLE, { x, y: 0.9, w: 2.15, h: 0.04, fill: { color: 'E76F51' } });
        s7.addText(r.title, { x: x + 0.1, y: 1.15, w: 1.95, h: 0.35, fontSize: 11, bold: true, color: 'C0392B', fontFace: 'Arial' });
        s7.addText(r.text, { x: x + 0.1, y: 1.6, w: 1.95, h: 2.5, fontSize: 9, color: '555555', fontFace: 'Arial', valign: 'top' });
    });

    // ── Save ──
    const outPath = path.join(__dirname, '..', 'docs', 'AI智能运维助手_项目规划.pptx');
    await pptx.writeFile({ fileName: outPath });
    console.log('Done: ' + outPath);
}

build().catch(err => { console.error(err); process.exit(1); });
