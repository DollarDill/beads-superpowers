---
description: 设计背后的证据——外部文献与本项目自身的测量结果。
machine_translated: true
---
!!! warning "机器翻译"
    本页面由 AI 自动翻译，可能存在术语或语义偏差。如有疑问，请以[英文原文](research.md)为准。

<!-- Role: the evidence behind the design - external literature and our own measurements. Does NOT belong here: the decisions themselves (philosophy.md) or the mechanism (methodology.md). -->

# 研究

本页汇集了 beads-superpowers 设计选择背后的证据：项目所依据的外部文献，以及项目对自身进行的测量。它面向那些希望在信任一个插件掌管自己开发工作流之前先核实来源的采用者，而不是仅凭"已经测试过"这句话就买账。关于每项选择背后的理由，参见[设计理念](philosophy.md)；关于最终机制在日常中如何运作，参见[方法论](methodology.md)。

## 文献怎么说

### Cialdini（2021）——《影响力》

罗伯特·西奥迪尼（Robert Cialdini）的《影响力：说服心理学》（*Influence: The Psychology of Persuasion*，新增扩展版，Harper Business，2021）记录了一小组能够改变人类顺从行为的原则：权威、一致性、稀缺性、互惠、喜好、社会认同和统一性。其中三项塑造了 beads-superpowers 技能的写作方式。权威性：铁律使用绝对性措辞（"在没有失败测试的情况下，绝不编写生产代码"），因为读起来具有权威性的指令比一句建议更难让智能体说服自己不去遵守。一致性：一旦智能体开始执行某个技能的检查表，保持与已经开始的流程一致的压力会推动它继续走完剩余步骤，而不是中途松懈。稀缺性：像"你无法为此找到合理借口"这样的措辞消除了存在替代路径的感觉。

### Meincke et al.（2025）——在 AI 顺从行为上验证说服原则

西奥迪尼的原则是基于人类受试者建立的。Meincke、Shapiro、Duckworth、Mollick、Mollick 和 Cialdini 在论文[《叫我混蛋：说服 AI 服从令人反感的请求》](https://www.pnas.org/doi/10.1073/pnas.2535868123)（*Call Me A Jerk: Persuading AI to Comply with Objectionable Requests*，*PNAS*，2025）中测试了这些原则是否也适用于 AI 模型。他们通过 28,000 段对话，要求 GPT-4o-mini 做两件它通常会拒绝的事情之一（辱骂用户，或说明如何合成受管制药物），并通过改变提示词来调用上述七项原则之一。使用普通对照提示词时，平均顺从率约为三分之一；调用某项原则后，平均顺从率升至约七成（33.3% 到 72.0%）；其中权威性、承诺和稀缺性带来的提升最大。

该研究测试的是诸如引用可信来源（权威性）或不断缩短的时间窗口（稀缺性）之类的原则，而非直接测试指令措辞本身。至于"坚定、绝对的措辞（'MUST'、'NEVER'）出于同样的原因胜过模糊措辞（'consider'、'when feasible'）"这一具体主张，则来自上游 superpowers 自己的[writing-skills 研究笔记](https://github.com/obra/superpowers/blob/main/skills/writing-skills/persuasion-principles.md)，该笔记将这一设计选择与 Meincke et al. 测量的同一项权威性原则联系了起来。beads-superpowers 连同技能一起继承了这一设计选择。

### MAST：多智能体系统为何失败（NeurIPS 2025）

[《多智能体 LLM 系统为何失败？》](https://arxiv.org/abs/2503.13657)（*Why Do Multi-Agent LLM Systems Fail?*，Cemri et al.，NeurIPS 2025 Datasets and Benchmarks Track）基于七个多智能体框架中超过 1,600 条标注轨迹，构建了一套失败分类法 MAST。它将 14 种不同的失败模式归入三个类别：

- **系统设计问题**：系统被赋予了模糊的任务或角色规格说明，却仍然照此构建下去。
- **智能体间失调**：执行过程中智能体之间信息流动出现断裂——交接遗漏、更新被忽略、对话被重置。
- **任务验证**：在系统宣布任务完成之前，没有检查、检查不完整，或检查未能发现实际错误。

每一类都对应 beads-superpowers 中已有的一种机制。系统设计问题正是 `brainstorming` 和 `writing-plans` 存在的目的：设计规格说明和小粒度任务计划在任何智能体编写代码之前就已完成，因此实现者手上不会留下模糊的规格说明可供随意发挥。智能体间失调没有对应的应对手段，而是有一种从结构上避免它的设计：只有编排智能体持有跨任务状态并创建、认领或关闭 bead，因此子智能体从一开始就不会彼此直接协调。任务验证失败正是 `verification-before-completion` 直接针对的问题：bead 若没有证据证明检查确实执行过，就无法关闭。

### 单线程智能体的行业实践

[Cognition](https://cognition.ai/blog/dont-build-multi-agents)（*Don't Build Multi-Agents*，Devin 编程智能体背后的团队）基于生产实践经验而非基准测试，反对并行子智能体架构。他们举的例子是：把"构建 Flappy Bird"任务拆分给两个子智能体，一个负责背景，一个负责小鸟，而两者都各自对美术风格做出了未言明的决定，且彼此看不到对方的工作。一个智能体构建了超级马里奥风格的背景；另一个做出的小鸟看起来不像游戏素材，动作方式也和 Flappy Bird 里的那只完全不同。两者无法调和。Cognition 的建议是：默认保持一条拥有完整共享上下文的连续线程，总体上反对并行子智能体架构。beads-superpowers 的仅编排者规则遵循同样的思路：子智能体并行运行以实现相互独立的任务，但只有编排者接触 bead，每个子智能体的输出通过基于文件的交接返回，而不是与其同级智能体进行实时对话。

## 我们测量到的结果

以上发现都是二手的：来自文献，以及其他团队的生产实践经验。而下面这三项是我们自己的——在本项目自身的技能和钩子上测量得到。

**技能发现优化（Skill Discovery Optimization）。** 部分技能的早期版本在 YAML 的 `description` 字段中总结了工作流程，例如"任务之间的代码审查"。当技能这样写时，我们发现智能体会直接依据描述行动，跳过完整 `SKILL.md` 正文规定的步骤。将描述改写为只陈述触发条件（"当任务 X 发生时使用"）后，智能体才会在行动前阅读完整技能。现在，每个技能的 `description` 字段都只陈述触发条件，而不再是工作流摘要。

**按显著度精选的上下文注入。** 插件的 session-start 钩子组合出一份 beads 上下文（精选记忆加上一个 `bd prime` 指引），而不是注入完整的 `bd prime` 转储。在一个包含 218 条记忆的库上测量，精选版本将注入上下文削减了 91.6%。正是这项测量结果确立了钩子的 8 KB 上限。

**对技能规则的对抗性压力测试。** 在发布之前，我们让每个技能中的每条规则都经历了一轮 RED/GREEN 循环：RED 是让智能体在没有该技能的情况下面对压力场景，违反规则；GREEN 是同一场景下技能已经存在，智能体遵守规则。如果 GREEN 阶段仍然发现漏洞，我们就重写规则并重新测试，而不是仅停留在理论层面。这就是把 TDD 的 RED-GREEN-REFACTOR 循环应用到技能文档本身，而不仅仅是代码上。

## 从发现到机制

| 发现 | 设计响应 | 所在位置 |
|---|---|---|
| 权威性、一致性和稀缺性的措辞框架提升智能体的顺从率（Cialdini；Meincke et al. 2025） | 铁律使用绝对的 MUST/NEVER 措辞，绝不使用模糊的建议 | 每个执行纪律的技能，例如 `test-driven-development`、`systematic-debugging` |
| 一致性压力使智能体一旦开始就保持在流程之内 | 多步骤技能以有序检查表的形式运行，而非可选菜单 | `brainstorming`、`writing-plans` |
| 系统设计与规格说明失败是一类主要的多智能体失败（MAST） | 设计与规划在任何代码编写之前由专门的技能完成 | `brainstorming`、`writing-plans` |
| 智能体间失调是一类主要的多智能体失败（MAST）；单一连续线程从结构上避免了它（Cognition） | 只有编排者创建、认领或关闭 bead；子智能体通过文件而非实时对话进行交接 | 仅编排者设计、`subagent-driven-development` |
| 任务验证失败是一类主要的多智能体失败（MAST） | 没有证据证明检查已执行，bead 就无法关闭 | `verification-before-completion` |
| 总结工作流程的技能描述会被直接遵循，而非技能正文（本项目实测） | 描述只陈述触发条件 | 每个技能的 YAML 前置元数据 |
| 完整的 `bd prime` 转储所占用的注入上下文远多于精选版本（本项目实测：在 218 条记忆的库上减少 91.6%） | 会话钩子在 8 KB 上限内组合出按显著度精选的上下文 | `session-start` 钩子 |
| 未经测试的技能规则往往存在漏洞（本项目实测） | 规则发布前进行 RED/GREEN 对抗性压力测试 | 每个执行纪律的技能 |

## 来源

- Cialdini, R. B. (2021). *Influence: The Psychology of Persuasion*（新增扩展版）. Harper Business.
- Meincke, L., Shapiro, D., Duckworth, A., Mollick, E., Mollick, L., & Cialdini, R. (2025). [《叫我混蛋：说服 AI 服从令人反感的请求》](https://www.pnas.org/doi/10.1073/pnas.2535868123)（*Call Me A Jerk: Persuading AI to Comply with Objectionable Requests*）. *PNAS*。
- 上游 superpowers，[writing-skills persuasion-principles 笔记](https://github.com/obra/superpowers/blob/main/skills/writing-skills/persuasion-principles.md)。
- Cemri, M., Pan, M. Z., Yang, S., et al. (2025). [《多智能体 LLM 系统为何失败？》](https://arxiv.org/abs/2503.13657)（*Why Do Multi-Agent LLM Systems Fail?*）NeurIPS 2025 Datasets and Benchmarks Track。
- Cognition. (2025). [《不要构建多智能体》](https://cognition.ai/blog/dont-build-multi-agents)（*Don't Build Multi-Agents*）。
- [方法论](methodology.md) —— 这些发现所汇入的机制。
- [设计理念](philosophy.md) —— 每项设计选择背后的理由。
