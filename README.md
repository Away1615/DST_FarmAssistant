# 丰耕助手 | Farm Assistant

[English](#english) · [简体中文](#简体中文)

Server-authoritative batch planting for Don't Starve Together.

- Mod version: `0.5.0`
- Required base mod: `Mosswork`, API `1`
- Author: `Nooobad`
- License: [MIT](LICENSE)

## English

### Overview

Farm Assistant plans a rectangular planting layout from the turf under the
mouse pointer or controller deploy reticle. It derives one fixed safe spacing
from the selected item's native deploy spacing and fills each covered turf
evenly. The server plants the valid positions as a bounded batch.

Blocked positions are skipped. The server continues through later candidates
inside the same fixed rectangle until it reaches the available inventory quota
or exhausts the layout.

### Requirements

Mosswork and Farm Assistant both use `all_clients_require_mod = true`.
The server and every joining player must load compatible versions of both mods.

### Controls

Mouse and keyboard:

1. Pick up an inventory item whose native deploy mode is `PLANT`, so it becomes
   the active cursor item.
2. Point at the turf that should become the layout origin.
3. Hold `Ctrl` and use the mouse wheel to change rows.
4. Hold `Alt` and use the mouse wheel to change columns.
5. Right-click to confirm.

Controller:

1. Select the plantable item and enter DST's normal deploy mode.
2. Use D-pad Up/Down to increase/decrease rows.
3. Use D-pad Left/Right to decrease/increase columns.
4. Press the standard action button (A by default) to confirm, or the standard
   alternate-action button (B by default) to cancel.

The HUD uses the player's current controller mappings instead of hard-coded
button names.

The default layout is `1 × 1`. Rows and columns can each be adjusted from `1`
to `9`, so one batch contains at most `81` candidate positions. Spacing is
selected automatically for the active plant, and the layout footprint remains
limited to `9` terrain tiles (`36` world units) per axis.

Inventory and valid positions determine how many plants are actually consumed.

One right-click records the mouse planting plan. `Planting Method` controls how
it runs: Batch moves into range and completes the plan in one character action;
Sequential follows the same snake-like order, automatically moves between
positions, and performs one planting action per item. A controller confirmation
uses the nearby native deploy reticle and the same server distance validation.

Farm Assistant does not replace left click, so original DST inventory drop
and movement behavior remains available.

### Preview

- Green: predicted to be plantable.
- Red: blocked or occupied; skipped by the server.
- Amber: client-side validation was unavailable; the server remains
  authoritative.
- Tile border: the `4 × 4` planning units covered by the layout.

Plant ghosts follow the server's snake-like traversal order and are limited to
the smaller of current matching inventory, layout candidates, and `256`.
Candidates beyond current inventory are not rendered. The complete tile border
remains visible, and the server still streams through every candidate at
execution time so later valid positions can replace blocked ones.

### Settings

Open the Mosswork settings hub and choose Farm Assistant:

- Default Rows
- Default Columns
- Planting Method
- GP Grid Opacity

`Planting Method` defaults to `Batch (One Action)`. Select
`Sequential (Auto-move)` when each plant should use a visible character action.
Manual movement or another action interrupts the remaining sequential plan.

Spacing is always automatic. The layout is anchored to the turf under the
cursor, calculates one fixed crop-safe value from the selected item's native
deploy spacing, and evenly fills every `4 × 4` turf without changing with rows
or columns.

`GP Grid Opacity` only changes the Geometric Placement grid around this mod's
preview. It does not change Geometric Placement's global colors, plant ghosts,
or tile borders.

Settings are stored locally per player. The server has no configurable balance
options and independently enforces every safety limit.

### Supported languages

Runtime UI, actions, settings, tooltips, mod names, and in-game descriptions
support:

- English
- Simplified Chinese
- Spanish
- Russian
- French
- German
- Japanese
- Korean

Mosswork owns the shared automatic/manual language selection. Missing keys fall
back to English. Traditional Chinese DST locales currently use the Simplified
Chinese translation.

### Supported plantables

Farm Assistant accepts an active item only when it:

- can exist in an inventory; and
- uses DST's native `DEPLOYMODE.PLANT`.

This includes dug berry bushes, grass, saplings, birchnuts, pine cones, marble
beans, living tree roots, and compatible modded plantables. Buildings, walls,
traps, turf, and other deploy modes are excluded. Farm seeds that use farm-soil
planting rather than `DEPLOYMODE.PLANT` are also outside this batch-placement
path.

### Multiplayer safety

- Client input and preview are predictive only.
- Batch mode uses one normal planting action. Sequential mode reuses DST
  locomotion and compatible short-action states for every plant; neither mode
  adds a custom crouching state, undo history, or request cooldown.
- The server validates request IDs, the active plantable, dimensions, derived
  spacing, arrival distance, inventory, and every deployment.
- One-action batches share a bounded per-tick planting budget with round-robin
  scheduling. Sequential plans naturally run one plant action at a time. At
  most eight planting plans run concurrently across both methods.
- Plant metadata is resolved once for the current item instance and reused
  until that instance changes. Per-point validation does not repeatedly query
  deploy mode and spacing.
- Plant checks use DST's public `Deployable` methods directly. A callback error
  stops the current batch and is logged; normal callbacks are not quarantined
  or rejected for merely taking longer than a threshold.
- Deployment follows `ACTIONS.DEPLOY`: remove one real inventory item, call
  `Deploy`, and give that same still-valid item back after a clean rejection.
  If the callback raises, a still-valid detached source is consumed before the
  batch stops; if it already invalidated the item, the state is treated as
  unknown. The mod never synthesizes a replacement item.
- Batch mode requires the player to remain near the original action point.
  Sequential mode follows its planned points and stops when player input
  interrupts the current automatic action.
- Busy, timeout, extension, and internal failures appear as localized system
  messages. Distance, inventory shortage, and no-valid-position outcomes stay
  silent.
- Server logs record rejected requests and failed batch summaries, including
  planted and blocked counts.
- RPC, Action, prefab, and Lua module identifiers are namespaced.
- Original and custom character StateGraphs receive a compatible action
  handler.

### Architecture

Farm Assistant is the product shell. Planting is an independent
`planting` feature under `scripts/mosswork/farm_assistant/planting/`; later farm
features keep their own actions, validation, and batch semantics.

Shared keyboard/controller mappings, RPC transport, persistent profile storage,
and bounded runtime caches come from Mosswork's public API. Farm Assistant does
not require Mosswork's internal Lua file paths.

### Local development

Keep both folders visible and enabled under the DST `mods` directory:

- `Mosswork`
- `FarmAssistant`

Restart the world after Lua changes. Check
`Documents/Klei/DoNotStarveTogether/client_log.txt` and the cluster
`Master/server_log.txt` when loading or server actions fail.

## 简体中文

### 简介

丰耕助手以鼠标指针或手柄部署准星所在的地皮为起点规划矩形种植阵列。
系统根据当前物品的原生部署间距计算一个固定安全值，并均匀填充每块地皮，
随后由服务器把有效位置作为一个受限批次种下。

遇到已有作物或其他阻挡时会跳过该点，并继续尝试同一个固定矩形中的后续
候选位置，直到达到当前库存配额或耗尽阵列。

### 依赖

Mosswork 和丰耕助手都使用 `all_clients_require_mod = true`。服务器以及
所有加入的玩家都必须加载兼容版本的两个模组。

### 操作

鼠标与键盘：

1. 从物品栏拿起一个原生部署模式为 `PLANT` 的物品，使其成为鼠标活动
   物品。
2. 把鼠标指向要作为阵列起点的地皮。
3. 按住 `Ctrl` 滚动鼠标滚轮，调整行数。
4. 按住 `Alt` 滚动鼠标滚轮，调整列数。
5. 按鼠标右键确认。

手柄：

1. 选中种植物并进入 DST 原生部署模式。
2. 方向键上/下增加/减少行数。
3. 方向键左/右减少/增加列数。
4. 按标准交互键（默认 A）确认，按标准次要交互键（默认 B）取消。

HUD 会显示玩家当前实际映射的手柄按键，不写死 A/B 图标。

默认阵列为 `1 × 1`。行数和列数都可以在 `1` 到 `9` 之间调整，因此单批
最多包含 `81` 个候选种植位置。间距会根据当前种植物自动选择，阵列每个
方向的占地范围仍不能超过 `9` 块地皮（`36` 个世界单位）。

实际消耗数量由库存和有效位置决定。

一次右键会记录鼠标种植计划。具体执行方式由“种植方式”决定：整批种植会
让角色进入范围后用一次动作完成；逐株种植会按照相同的蛇形顺序自动移动，
每株执行一次种植动作。手柄确认使用原生部署准星的近距离目标，并经过相同
的服务端距离校验。

丰耕助手不会覆写左键，原版物品栏丢弃和移动行为仍然可用。

### 预览

- 绿色：客户端预测可以种植。
- 红色：已有作物或存在阻挡，服务器会跳过。
- 琥珀色：客户端无法完成位置校验，最终以服务端结果为准。
- 地皮边框：阵列覆盖的 `4 × 4` 规划单位。

作物幽灵按照与服务端一致的蛇形顺序展示，其数量取当前同类库存、布局
候选点和 `256` 三者中的最小值。超出当前库存的候选点不再渲染作物幽灵；
完整地皮边框仍然保留。执行时服务端仍会流式扫描完整阵列，因此前方位置
被阻挡后仍可继续尝试后方有效位置。

### 设置

打开 Mosswork 设置中心并选择丰耕助手：

- 默认行数
- 默认列数
- 种植方式
- GP Grid 透明度

“种植方式”默认是“整批种植（一次动作）”。选择“逐株种植（自动移动）”后，
每株都会播放可见的角色动作；玩家主动移动或执行其他动作会中断剩余计划。

间距始终自动计算。阵列以鼠标指针或手柄部署准星所在的地皮为基准，根据
当前物品的原生部署间距得到一个固定安全值，均匀填充每块 `4 × 4` 地皮，
并且不会随当前行列变化。

`GP Grid 透明度`只改变丰耕助手种植预览周围的 Geometric Placement Grid，
不会修改 Geometric Placement 的全局颜色、作物幽灵或地皮边框。

个人设置保存在玩家本机。服务端不提供可配置的平衡参数，并独立执行全部
安全上限校验。

### 支持语言

运行时界面、动作、设置、悬停说明、模组名称和游戏内说明支持：

- 英语
- 简体中文
- 西班牙语
- 俄语
- 法语
- 德语
- 日语
- 韩语

自动/手动语言选择由 Mosswork 统一管理，缺失翻译键回退到英语。DST
繁体中文 locale 当前使用简体中文翻译。

### 支持的种植物

活动物品必须同时满足：

- 可以进入玩家物品栏；
- 使用 DST 原生 `DEPLOYMODE.PLANT` 部署模式。

这包括铲出的浆果丛、草、树苗、桦树果、松果、大理石豆、活木树根，以及
遵循相同组件契约的第三方种植物。建筑、墙、陷阱、地皮和其他部署模式
不会被识别。仅通过农田播种逻辑使用、而不是 `DEPLOYMODE.PLANT` 的普通
种子也不属于这条批量放置路径。

### 联机安全

- 客户端输入和预览只负责预测。
- 整批模式只使用一个普通种植动作；逐株模式为每株复用 DST 原生移动和
  兼容的短动作状态。两种模式都没有自定义蹲下状态、撤销历史或请求冷却。
- 服务端校验请求 ID、活动种植物、行列、自动间距、到达距离、库存和
  每次部署。
- 一次动作模式通过轮转调度共享固定的单帧种植预算；逐株模式自然限制为
  同一时间只执行一株动作。两种方式合计最多同时运行 8 个种植计划。
- 种植物元数据只针对当前物品实例解析一次并复用，只有实例变化时才重新
  解析。逐点校验不会重复查询部署模式和间距。
- 种植检查直接调用 DST 公开的 `Deployable` 方法。回调报错会停止并记录
  当前批次；正常回调不会因为耗时超过阈值而被隔离或拒绝。
- Deploy 对齐 `ACTIONS.DEPLOY`：从真实库存移除一件物品后调用 `Deploy`；
  如果明确失败且原物品仍有效，就把同一个物品归还。若回调抛错，会先消耗
  仍有效的已取出物品再停止；若物品已经失效，状态按未知处理。模组绝不会
  合成替代物品。
- 整批模式执行期间玩家必须留在原动作点附近；逐株模式会沿规划点移动，
  玩家输入打断当前自动动作时会停止剩余计划。
- 繁忙、超时、扩展回调和内部故障会以当前语言的系统消息通知对应玩家；
  距离过远、库存不足和无有效位置保持静默。
- 服务端日志会记录被拒绝的请求和失败批次摘要，并包含成功种植与阻挡
  数量。
- RPC、Action、Prefab 和 Lua 模块标识均使用命名空间。
- 原版和自定义人物 StateGraph 都会安装兼容的动作处理器。

### 架构

丰耕助手根模块只负责产品注册与功能组合。当前种植功能位于
`scripts/mosswork/farm_assistant/planting/`，后续农业功能继续保留各自的动作、
校验和批处理语义。

统一键鼠/手柄映射、RPC 传输、持久档案和有界运行时缓存均通过 Mosswork
公开 API 使用；丰耕助手不再依赖 Mosswork 内部 Lua 文件路径。

### 本地开发

确保 DST `mods` 目录中能看到并启用：

- `Mosswork`
- `FarmAssistant`

Lua 修改后需要重新进入世界。加载或服务端动作失败时检查
`Documents/Klei/DoNotStarveTogether/client_log.txt` 和集群目录中的
`Master/server_log.txt`。

## License

丰耕助手的原创代码采用 [MIT License](LICENSE)。Don't Starve
Together、Klei、Geometric Placement 以及第三方名称和游戏资源不属于
本许可证授权范围。
