# RaceDelta 项目说明

## 一句话定位

RaceDelta 是一个使用 MoonBit 构建的赛车策略分析与反事实进站模拟工具：它把逐圈 CSV 数据转换为可解释的比赛时间线和 Markdown 策略报告。

## 解决的问题

- 从逐圈 CSV 重建累计用时、排名、车手间 gap、stint 与比赛事件。
- 比较真实策略与一名目标车手的反事实进站策略，并保留其他车手的真实时间线。
- 说明策略在哪些圈发生 performance、strategic、opponent crossover，而不只给出最终快慢数字。

## 核心功能

- 严格解析和校验 CSV v1。
- 重建累计时间、排名、gap、stint、进站、赛道状态、天气和位置变化事件。
- 使用可配置的轮胎节奏、线性衰减、cliff 与 Green/Safety Car 进站损失模型。
- 回放显式的反事实进站策略。
- 检测 Performance / Strategic / Opponent 三类 crossover，并给出 turning points。
- 渲染稳定、可复现的 Markdown 报告。
- 提供 Native CLI，用于本地 CSV 读取与报告写入。

## 技术特点

- 主要使用 MoonBit 实现；异步文件与终端 I/O 限制在 CLI 边界，业务逻辑保持纯函数。
- 全部核心时间计算使用整数毫秒，结果确定且便于测试。
- 当前包含 209 项自动化测试。
- 依赖仅为官方 `moonbitlang/async@0.20.2`，用于 Native 文件与标准流 I/O。

## 最小复现

```sh
moon test --target native
moon run cmd/main -- examples/basic_race.csv --driver ALP --opponent BRV --stops 2:MEDIUM
```

示例输入见 [examples/basic_race.csv](examples/basic_race.csv)，上述策略生成的示例报告见 [examples/basic_strategy_report.md](examples/basic_strategy_report.md)。完整命令与 PLAN 格式见 [CLI.md](CLI.md)。

## 项目限制

- 轮胎与进站损失参数是教学演示值，不是任何真实 F1 车队、赛道或车手的官方数据。
- RaceDelta 不声称复现真实车队内部模型，也不承诺精确预测真实比赛。
- Safety Car 不会压缩输入 CSV 中的真实 gap；输入时间按原样累计。
- 不包含完整超车、DRS、交通、车手行为 AI 或自动策略搜索。

## AI 使用说明

AI 用于辅助设计、实现、测试与文档整理。项目目标、模型语义、验收规则与最终质量由参赛者掌握并负责。
