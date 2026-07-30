# Planting Assistant | 种植助手

[English](#english) · [简体中文](#简体中文)

Server-authoritative batch planting for Don't Starve Together.

- Mod version: `0.2.0`
- Required base mod: `Mosswork`, API `1`
- Author: `Nooobad`
- License: [MIT](LICENSE)

## English

### Overview

Planting Assistant plans a rectangular planting layout from the turf under the
mouse. It derives one fixed safe spacing from the selected item's native deploy
spacing and fills each covered turf evenly. The character moves into range,
plays one action, and the server plants the valid positions as a bounded batch.

Blocked positions are skipped. The server continues through later candidates
inside the same fixed rectangle until it reaches the available inventory quota
or exhausts the layout.

### Requirements

Mosswork and Planting Assistant both use `all_clients_require_mod = true`.
The server and every joining player must load compatible versions of both mods.

### Controls

1. Pick up an inventory item whose native deploy mode is `PLANT`, so it becomes
   the active cursor item.
2. Point at the turf that should become the layout origin.
3. Hold `Ctrl` and use the mouse wheel to change rows.
4. Hold `Alt` and use the mouse wheel to change columns.
5. Right-click to confirm.
6. Within five seconds after the batch finishes, press `Ctrl+Z` to undo it.

The default layout is `1 × 1`. The number of candidates allowed on each axis
depends on the selected plant's automatic spacing: up to `36` at `1`, `27` at
`4/3`, `18` at `2`, or `9` at `4` world units. Width and height are each limited
to `9` terrain tiles (`36` world units).

There is no separate `81`-plant limit. Inventory and valid positions determine
how many plants are actually consumed; the `9 × 9`-turf boundary is the layout
safety limit.

One right-click records the planting plan. DST moves the character into action
range when needed, then automatically starts the batch. The character never
walks to every individual plant position.

Planting Assistant does not replace left click, so original DST inventory drop
and movement behavior remains available.

Only the most recent completed batch is retained. Submitting another valid
Planting Assistant batch clears the previous history; walking, opening the
inventory, and other ordinary actions do not. Undo succeeds only while every
recorded planted entity still has the same server GUID and remains at its
original point. If any entity is gone, replaced, or moved, the whole batch is
left unchanged. Changes that keep the same entity, such as fertilizing it
within the five-second window, do not by themselves block undo.

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

Open the Mosswork settings hub and choose Planting Assistant:

- Default Rows
- Default Columns
- GP Grid Opacity

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

Planting Assistant accepts an active item only when it:

- can exist in an inventory; and
- uses DST's native `DEPLOYMODE.PLANT`.

This includes dug berry bushes, grass, saplings, birchnuts, pine cones, marble
beans, living tree roots, and compatible modded plantables. Buildings, walls,
traps, turf, and other deploy modes are excluded. Farm seeds that use farm-soil
planting rather than `DEPLOYMODE.PLANT` are also outside this batch-placement
path.

### Multiplayer safety

- Client input and preview are predictive only.
- The server validates request IDs, active plantable items, distance,
  dimensions, derived spacing, inventory, and every deployment.
- `Ctrl+Z` is accepted only from the gameplay screen without text-input focus.
  The server keeps one five-second undo history per player, pre-validates the
  complete batch, removes only the exact recorded GUIDs, and restores the
  consumed items from their server save records.
- Native and modded plantables are undoable when their deployment synchronously
  creates identifiable persistent entities at the planting point. Unsupported
  deployment results still plant normally and show a localized notice that
  undo is unavailable.
- Invalid requests are rate-limited before expensive layout work.
- All players share bounded per-tick preflight and planting budgets with
  round-robin scheduling; at most eight planting batches run concurrently.
- Progress heartbeats and a stall watchdog prevent permanent busy states.
- A missing terminal message is recovered by a client-side heartbeat timeout.
- Plant metadata is resolved once for the current item instance and reused
  until that instance changes. Per-point validation does not repeatedly query
  deploy mode and spacing.
- A plant callback error stops only the current request. Slow callbacks produce
  throttled performance warnings but their successful results are accepted;
  they are not quarantined.
- Deploy follows the native item boundary. If deployment fails while the
  detached item is still valid, that same item is returned to its original
  container, player inventory, or the player's feet. If a callback invalidates
  the item before failing, the state is unknown, so the batch stops and logs
  the incident. The mod never synthesizes a replacement item.
- Mosswork's execution-budgeted callback runner remains limited to low-frequency
  item/action metadata and extension UI work. Per-point `CanDeploy` and server
  `Deploy` calls use ordinary protected calls to avoid instruction-hook
  overhead.
- Players must remain near the original action point during execution.
- Busy, timeout, extension, and internal failures appear as localized system
  messages. Distance, inventory shortage, and no-valid-position outcomes stay
  silent.
- Server logs record rejected requests and failed batch summaries, including
  planted and blocked counts.
- RPC, Action, StateGraph, prefab, and Lua module identifiers are namespaced.
- Original and custom character StateGraphs receive a compatible action
  handler.

### Local development

Keep both folders visible and enabled under the DST `mods` directory:

- `Mosswork`
- `PlantingAssistant`

Restart the world after Lua changes. Check
`Documents/Klei/DoNotStarveTogether/client_log.txt` and the cluster
`Master/server_log.txt` when loading or server actions fail.

## 简体中文

### 简介

种植助手以鼠标所在的地皮为起点规划矩形种植阵列。系统根据当前物品的
原生部署间距计算一个固定安全值，并均匀填充每块地皮。角色会实际移动到
动作范围，只播放一次种植动作，随后由服务器把有效位置作为一个受限批次
种下。

遇到已有作物或其他阻挡时会跳过该点，并继续尝试同一个固定矩形中的后续
候选位置，直到达到当前库存配额或耗尽阵列。

### 依赖

Mosswork 和种植助手都使用 `all_clients_require_mod = true`。服务器以及
所有加入的玩家都必须加载兼容版本的两个模组。

### 操作

1. 从物品栏拿起一个原生部署模式为 `PLANT` 的物品，使其成为鼠标活动
   物品。
2. 把鼠标指向要作为阵列起点的地皮。
3. 按住 `Ctrl` 滚动鼠标滚轮，调整行数。
4. 按住 `Alt` 滚动鼠标滚轮，调整列数。
5. 按鼠标右键确认。
6. 批次完成后的 5 秒内按 `Ctrl+Z`，撤销上一批种植。

默认阵列为 `1 × 1`。每个方向允许的候选数量由自动间距决定：间距为
`1` 个世界单位时最多 `36` 株，间距为 `4/3` 时最多 `27` 株，间距为
`2` 时最多 `18` 株，间距为 `4` 时最多 `9` 株。阵列宽度和高度分别
不能超过 9 块地皮（36 个世界单位）。

不再另设 81 株上限。实际消耗数量由库存和有效位置决定，`9 × 9` 地皮
范围是单次布局的安全边界。

一次右键会记录种植计划。需要移动时，DST 会先让角色进入动作范围，再自动
开始整批种植。角色不需要逐个走到每株作物的位置。

种植助手不会覆写左键，原版物品栏丢弃和移动行为仍然可用。

每名玩家只保留最近一个已完成批次。提交新的有效种植助手批次后，旧历史
立即失效；走路、打开背包等普通操作不会清除历史。只有服务端记录的全部
作物实体仍保持同一 GUID、并留在原种植点时，整批撤销才会执行。任意实体
已经消失、被替换或移动时，整批保持不变。5 秒内施肥等不替换实体的变化
本身不会阻止撤销。

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

打开 Mosswork 设置中心并选择种植助手：

- 默认行数
- 默认列数
- GP Grid 透明度

间距始终自动计算。阵列以鼠标所在的地皮为基准，根据当前物品的原生部署
间距得到一个固定安全值，均匀填充每块 `4 × 4` 地皮，并且不会随当前
行列变化。

`GP Grid 透明度`只改变种植助手预览周围的 Geometric Placement Grid，
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
- 服务端校验请求 ID、活动种植物、距离、行列、自动计算的间距、库存和
  每次部署。
- `Ctrl+Z` 只在游戏画面且没有文本输入焦点时生效。服务端为每名玩家保留
  一份 5 秒单层历史，先校验整批，再只移除准确记录的 GUID，并通过服务端
  物品存档返还原先消耗的物品。
- 原版或第三方种植物只要能在部署回调内同步生成可识别的持久实体，就支持
  撤销。无法安全识别结果的部署仍会正常种植，并显示本地化的不支持提示。
- 无效请求会在高成本布局计算前进入限流。
- 所有玩家通过轮转调度共享固定的单帧预检与种植预算，同时执行的种植
  批次最多为 8 个。
- 进度心跳和停滞看门狗避免永久 busy。
- 即使终止消息丢失，客户端也会通过心跳超时自动解除 busy。
- 种植物元数据只针对当前物品实例解析一次并复用，只有实例变化时才重新
  解析。逐点校验不会重复查询部署模式和间距。
- 种植物回调抛错只终止当前请求。慢回调仅产生节流性能警告；只要成功
  返回，结果仍被接受，也不会因此被隔离。
- Deploy 遵循原生物品边界。部署失败且已取出的物品仍然有效时，会依次
  尝试归还原容器、玩家物品栏或玩家脚下；如果回调在失败前使物品失效，
  则状态未知，批次停止并记录日志。模组绝不会合成替代物品。
- Mosswork 的带执行预算回调执行器只用于低频物品/动作元数据和扩展 UI；
  逐点 `CanDeploy` 与服务端 `Deploy` 使用普通保护调用，避免指令 hook
  的热路径开销。
- 执行期间玩家必须留在原动作点附近。
- 繁忙、超时、扩展回调和内部故障会以当前语言的系统消息通知对应玩家；
  距离过远、库存不足和无有效位置保持静默。
- 服务端日志会记录被拒绝的请求和失败批次摘要，并包含成功种植与阻挡
  数量。
- RPC、Action、StateGraph、Prefab 和 Lua 模块标识均使用命名空间。
- 原版和自定义人物 StateGraph 都会安装兼容的动作处理器。

### 本地开发

确保 DST `mods` 目录中能看到并启用：

- `Mosswork`
- `PlantingAssistant`

Lua 修改后需要重新进入世界。加载或服务端动作失败时检查
`Documents/Klei/DoNotStarveTogether/client_log.txt` 和集群目录中的
`Master/server_log.txt`。

## License

Planting Assistant 的原创代码采用 [MIT License](LICENSE)。Don't Starve
Together、Klei、Geometric Placement 以及第三方名称和游戏资源不属于
本许可证授权范围。
