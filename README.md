# Planting Assistant | 种植助手

[English](#english) · [简体中文](#简体中文)

Server-authoritative batch planting for Don't Starve Together.

- Mod version: `0.1.0`
- Required base mod: `Mosswork`, API `1`
- Author: `Nooobad`
- License: [MIT](LICENSE)

## English

### Overview

Planting Assistant plans a rectangular transplant layout from the tile under
the mouse. The character moves into range, plays one action, and the server
plants the valid positions as a bounded batch.

Blocked positions are skipped. The server continues through later candidates
inside the same fixed rectangle until it reaches the available inventory quota
or exhausts the layout.

### Requirements

Mosswork and Planting Assistant both use `all_clients_require_mod = true`.
The server and every joining player must load compatible versions of both mods.

### Controls

1. Pick up a supported transplant so it becomes the active cursor item.
2. Point at the tile where the layout should begin.
3. Hold `Ctrl` and use the mouse wheel to change rows.
4. Hold `Alt` and use the mouse wheel to change columns.
5. Right-click to confirm.

The default layout is `1 × 1`. Rows and columns are each limited to `1–9`, so
one batch contains at most `81` candidate positions.

If the target is within planning distance, DST moves the character into action
range before planting. A distant right-click only moves toward the area;
right-click again after approaching it. The character never walks to every
individual plant position.

Planting Assistant does not replace left click, so original DST inventory drop
and movement behavior remains available.

### Preview

- Green: predicted to be plantable.
- Red: blocked or occupied; skipped by the server.
- Gray: valid candidate beyond the current inventory quota.
- Tile border: the `4 × 4` planning units covered by the layout.

The client simulates the same snake-like candidate order used by the server.
The server still rebuilds and validates the complete layout at execution time.

### Settings

Open the Mosswork settings hub and choose Planting Assistant:

- Default Rows
- Default Columns
- Plant Spacing
- GP Grid Opacity

Automatic spacing calculates one fixed value from the selected transplant's
native deploy spacing. It evenly divides a `4 × 4` tile and does not change
when rows or columns change. Manual spacing accepts integer values from `1` to
`4` world units.

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

### Supported transplants

- Berry Bush
- Berry Bush (`dug_berrybush2` variant)
- Juicy Berry Bush
- Grass
- Sapling
- Moon Sapling
- Spiky Bush

### Multiplayer safety

- Client input and preview are predictive only.
- The server validates request IDs, active items, distance, dimensions,
  spacing, inventory, and every deployment.
- Invalid requests are rate-limited before expensive layout work.
- All players share bounded preflight and planting budgets with round-robin
  scheduling.
- Progress heartbeats and a stall watchdog prevent permanent busy states.
- Players must remain near the original action point during execution.
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

种植助手以鼠标所在的地皮作为矩形阵列起点。角色会实际移动到动作范围，
只播放一次种植动作，随后由服务器把有效位置作为一个受限批次种下。

遇到已有作物或其他阻挡时会跳过该点，并继续尝试同一个固定矩形中的后续
候选位置，直到达到当前库存配额或耗尽阵列。

### 依赖

Mosswork 和种植助手都使用 `all_clients_require_mod = true`。服务器以及
所有加入的玩家都必须加载兼容版本的两个模组。

### 操作

1. 从物品栏拿起一个支持的移植作物，使其成为鼠标活动物品。
2. 把鼠标指向阵列需要开始的地皮。
3. 按住 `Ctrl` 滚动鼠标滚轮，调整行数。
4. 按住 `Alt` 滚动鼠标滚轮，调整列数。
5. 按鼠标右键确认。

默认阵列为 `1 × 1`。行数和列数分别限制为 `1–9`，所以单次最多包含
`81` 个候选位置。

目标在规划距离内时，DST 会让角色先移动到动作范围再种植。距离过远时，
本次右键只负责向目标区域移动；靠近后需要再次右键确认。角色不需要逐个
走到每株作物的位置。

种植助手不会覆写左键，原版物品栏丢弃和移动行为仍然可用。

### 预览

- 绿色：客户端预测可以种植。
- 红色：已有作物或存在阻挡，服务器会跳过。
- 灰色：位置有效，但超过当前库存配额。
- 地皮边框：阵列覆盖的 `4 × 4` 规划单位。

客户端按照与服务器相同的蛇形顺序模拟候选点；最终执行时，服务器仍会
重新生成并校验完整阵列。

### 设置

打开 Mosswork 设置中心并选择种植助手：

- 默认行数
- 默认列数
- 作物间距
- GP Grid 透明度

自动间距根据当前移植作物的原生部署间距计算一个固定值，使其能够整齐
等分 `4 × 4` 地皮，并且不会随当前行列变化。手动间距只能选择 `1–4`
的整数世界单位。

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

### 当前支持的移植作物

- 浆果丛
- 浆果丛 `dug_berrybush2` 变体
- 多汁浆果丛
- 草
- 树苗
- 月岛树苗
- 尖刺灌木

### 联机安全

- 客户端输入和预览只负责预测。
- 服务端校验请求 ID、活动物品、距离、行列、间距、库存和每次部署。
- 无效请求会在高成本布局计算前进入限流。
- 所有玩家通过轮转调度共享固定的预检与种植预算。
- 进度心跳和停滞看门狗避免永久 busy。
- 执行期间玩家必须留在原动作点附近。
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
