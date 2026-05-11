const pptxgen = require('pptxgenjs');
const html2pptx = require('C:/Users/45267/.agents/skills/powerpoint/scripts/html2pptx');
const path = require('path');

async function build() {
    const pptx = new pptxgen();
    pptx.layout = 'LAYOUT_16x9';
    pptx.author = 'AI Ops Team';
    pptx.title = 'AI 智能运维助手 - 项目规划';

    const slides = [
        'slide1.html',  // 封面
        'slide2.html',  // 项目概述
        'slide3.html',  // 核心功能
        'slide4.html',  // 技术架构
        'slide5.html',  // 小组分工
        'slide6.html',  // 开发计划
        'slide7.html',  // 风险应对
    ];

    for (const file of slides) {
        const htmlPath = path.join(__dirname, file);
        console.log(`Processing: ${file}`);
        try {
            await html2pptx(htmlPath, pptx);
        } catch (err) {
            console.error(`Error processing ${file}:`, err.message);
            throw err;
        }
    }

    const outPath = path.join(__dirname, '..', 'docs', 'AI智能运维助手_项目规划.pptx');
    await pptx.writeFile({ fileName: outPath });
    console.log(`Done: ${outPath}`);
}

build().catch(err => { console.error(err); process.exit(1); });
