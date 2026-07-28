# Planting Assistant | 种植助手

[English](#english) · [简体中文](#简体中文)

Planting Assistant is a server-authoritative batch planting mod for Don't
Starve Together.

- Mod version: `0.17.0`
- Required base mod: `Mosswork`, API `3`
- Author: `Nooobad`
- License: [MIT](LICENSE)

## English

### Features

- Plan a rectangular planting layout from the tile under the mouse.
- Adjust rows and columns without replacing normal left-click behavior.
- Preview plant positions, blocked points, inventory limits, and `4 × 4` tile
  boundaries.
- Play one character action, then plant the valid positions as one
  server-authoritative batch.
- Skip blocked points and continue scanning later points in the same fixed
  layout.
- Save personal defaults through the Mosswork settings hub.
- Switch all UI and action text between English and Simplified Chinese at
  runtime.

### Requirements

Planting Assistant depends on `Mosswork`. Both mods use
`all_clients_require_mod = true`, so the server and every joining player must
load compatible versions of both mods.

### Controls

1. Pick up a supported transplant from the inventory so it becomes the active
   cursor item.
2. Point at the tile that should contain the first part of the layout.
3. Hold `Ctrl` and use the mouse wheel to change rows.
4. Hold `Alt` and use the mouse wheel to change columns.
5. Right-click to confirm.

The default layout is `1 × 1`. Rows and columns are each limited to `1–9`, and
one request can plant at most `81` items.

If the target is within the planning range, the standard DST action system
moves the character into execution range before planting. A distant
right-click only moves toward the area; right-click again after approaching it.
The character does not walk to every individual plant position.

Planting Assistant does not replace left click. Dropping or moving the active
inventory item continues to use the original DST behavior.

### Preview

- Green: predicted to be plantable.
- Red: blocked or already occupied; the server will skip it.
- Gray: valid candidate beyond the current inventory quota.
- Tile border: the `4 × 4` planning units covered by the layout.

The client simulates candidates in the same snake-like order used by the
server. It treats each accepted preview point as occupied before checking the
next one, reducing differences when a manual spacing is too dense. The server
still performs the final validation at execution time.

### Plant spacing

Personal spacing is configured in the Mosswork settings hub.

- `Automatic` calculates one fixed spacing for the selected transplant from its
  native deploy spacing. The value evenly divides a `4 × 4` tile and does not
  change when rows or columns change.
- Manual spacing accepts integer values from `1` to `4` world units.
- Every final position must still pass the transplant's original DST
  `CanDeploy` and `Deploy` checks.

For example, a native spacing of `2` produces an automatic spacing of `2`.
A `2 × 2` layout fills one tile; a `3 × 3` layout keeps spacing `2` and expands
across more planning tiles instead of shrinking.

### Batch behavior

The server:

1. validates the player, request ID, active item, distance, dimensions, spacing,
   and layout;
2. scans the fixed layout over multiple frames;
3. starts one planting action only if at least one position is valid;
4. uses the available inventory count at action time as the success quota;
5. skips positions that become blocked and keeps trying later candidates;
6. stops after reaching the quota or exhausting the fixed layout.

If a `3 × 3` layout has nine valid positions, ten items plant nine and eight
items attempt to plant eight. Blocked candidates do not consume the quota.
The mod never extends the requested rectangle to search for replacement
positions.

### Personal settings

Open the green Mosswork button and choose Planting Assistant:

- Default Rows
- Default Columns
- Plant Spacing
- GP Grid Opacity

`GP Grid Opacity` only adjusts the Geometric Placement grid shown around this
mod's preview. It does not change Geometric Placement's global color scheme,
plant ghosts, or tile borders.

Settings are saved locally per player. `Ctrl`/`Alt` wheel changes only the
current layout and does not overwrite saved defaults. The server has no
configurable balance options; its limits remain authoritative.

### i18n

- Supported runtime languages: English and Simplified Chinese.
- `Automatic` follows the current DST locale.
- `zh`, `zhr`, and `zht` resolve to the Chinese translation.
- Unsupported locales and missing keys fall back to English.
- The shared language selection is stored by Mosswork and applies to every
  registered Mosswork mod.
- Action labels, settings, tooltips, and the mod entry refresh immediately when
  the Mosswork language changes.
- `modinfo.lua` independently localizes the pre-world mod name and description
  from the current DST locale.

### Supported transplants

- Berry Bush
- Berry Bush (`dug_berrybush2` variant)
- Juicy Berry Bush
- Grass
- Sapling
- Moon Sapling
- Spiky Bush

### Multiplayer safety

- The client handles input and predictive previews only.
- The server rebuilds the layout and validates coordinates, inventory,
  distance, spacing, and every deployment.
- Requests are rate-limited before expensive layout work.
- All players share bounded per-frame preflight and planting budgets with
  round-robin scheduling.
- Active batches send progress heartbeats and use a stall watchdog so a failed
  callback cannot leave the player permanently busy.
- Players must remain near the original action point while the batch executes.
- The mod uses namespaced RPC, Action, StateGraph state, prefab, and module
  identifiers.
- Original and custom character StateGraphs receive an action handler; a
  fallback handler preserves execution even when a custom graph has no matching
  animation state.

### Local development

For a junction-based local test, keep both folders visible under the DST
`mods` directory and enable both:

- `Mosswork`
- `PlantingAssistant`

Start a new local world or restart the current world after changing Lua files.
Use `Documents/Klei/DoNotStarveTogether/client_log.txt` and the cluster's
`Master/server_log.txt` when a load or server action fails.

## 简体中文

### 功能

- 以鼠标所在的地皮作为阵列规划起点。
- 使用组合键调整行列，不接管原版左键行为。
- 预览可种点、阻挡点、库存不足位置和 `4 × 4` 地皮边框。
- 角色只播放一次动作，随后由服务器一次性部署整批有效位置。
- 遇到已有作物或其他阻挡时跳过该点，并继续尝试固定阵列中的后续点。
- 通过 Mosswork 设置中心保存每名玩家自己的默认值。
- 英语和简体中文界面可以在运行时即时切换。

### 依赖

种植助手依赖 `Mosswork` API `2`。两个模组都使用
`all_clients_require_mod = true`，因此服务器和所有加入的玩家都必须加载
兼容版本的两个模组。

### 操作方式

1. 从物品栏拿起一个支持的移植作物，使其成为鼠标上的活动物品。
2. 把鼠标指向希望作为规划起点的地皮。
3. 按住 `Ctrl` 滚动鼠标滚轮，调整行数。
4. 按住 `Alt` 滚动鼠标滚轮，调整列数。
5. 按鼠标右键确认。

默认阵列为 `1 × 1`。行数和列数分别限制为 `1–9`，单次最多种植
`81` 株。

目标在规划距离内时，模组使用 DST 标准动作系统让角色先实际移动到
执行范围，再开始种植。距离过远时，本次右键只负责向目标区域移动；
靠近后需要再次右键确认。角色不需要逐个移动到每株作物的位置。

种植助手不会覆写左键。从鼠标丢弃或移动活动物品仍使用 DST 原版行为。

### 预览颜色

- 绿色：客户端预测可以种植。
- 红色：已有作物或存在阻挡，服务器执行时会跳过。
- 灰色：位置有效，但超过当前库存可以覆盖的数量。
- 地皮边框：当前阵列覆盖的 `4 × 4` 规划单位。

客户端按照与服务器一致的蛇形顺序模拟候选点。每接受一个绿色点后，
预览会先把它视为已经种下，再检查后续位置，从而减少手动间距过密时
“预览全绿、实际只能种一部分”的差异。最终结果仍以服务器执行时的
实时校验为准。

### 作物间距

玩家可以在 Mosswork 设置中心配置个人间距：

- `自动`：根据当前移植作物的原生部署间距计算一个固定值，使间距能够
  整齐等分 `4 × 4` 地皮；不会随当前行数或列数变化。
- 手动间距：只能选择 `1–4` 的整数世界单位。
- 每个最终位置仍必须通过该作物原版的 `CanDeploy` 和 `Deploy`。

例如作物原生间距为 `2` 时，自动间距固定为 `2`。`2 × 2` 正好填满
一块地皮；改成 `3 × 3` 后仍保持间距 `2`，阵列会扩展到更多规划地皮，
而不是为了塞进一块地皮而缩小间距。

### 批量执行规则

服务器会：

1. 校验玩家、请求 ID、活动物品、距离、行列、间距和布局；
2. 把固定阵列的预检分摊到多个游戏帧；
3. 只有至少一个有效位置时才开始一次种植动作；
4. 以动作触发时的可用库存作为成功数量配额；
5. 跳过执行期间新增的阻挡，并继续尝试后续候选点；
6. 达到配额或耗尽固定阵列后结束。

如果 `3 × 3` 阵列有九个有效位置，手上十株会种九株，手上八株会尽量
种八株。阻挡点不占用库存配额。模组不会越过玩家选定的矩形范围寻找
额外补位。

### 个人设置

点击 Mosswork 的绿色入口并选择种植助手：

- 默认行数
- 默认列数
- 作物间距
- GP Grid 透明度

`GP Grid 透明度`只调整种植助手预览周围的 Geometric Placement Grid，
不会修改 Geometric Placement 的全局配色、作物幽灵或地皮边框。

设置按玩家保存在本机档案中。`Ctrl`/`Alt` 加滚轮只改变当前阵列，
不会覆写已保存的默认值。服务端不提供可配置的平衡参数，所有安全上限
都保持固定并由服务器权威校验。

### i18n 语言支持

- 运行时支持英语和简体中文。
- `自动`跟随当前 DST 语言。
- `zh`、`zhr`、`zht` 都会解析为中文。
- 尚未支持的语言和缺失翻译键会回退到英语。
- 语言选择由 Mosswork 统一保存，并同时作用于所有接入模组。
- 动作文字、设置项、悬停说明和模组列表会在切换语言后立即刷新。
- 进入世界前的模组名称与说明由 `modinfo.lua` 根据 DST 当前语言独立
  本地化。

### 当前支持的移植作物

- 浆果丛
- 长草浆果丛
- 多汁浆果丛
- 草
- 树苗
- 月岛树苗
- 尖刺灌木

### 联机与安全

- 客户端只处理输入和预测预览。
- 服务端重新生成布局，并校验坐标、库存、距离、间距和每次部署。
- 请求在执行高成本布局计算前进入限流。
- 所有玩家通过轮转调度共享固定的每帧预检和种植预算。
- 活动批次包含进度心跳和停滞看门狗，异常不会让玩家永久处于 busy。
- 批量执行期间，玩家必须留在原动作点附近。
- RPC、Action、StateGraph 状态、Prefab 和 Lua 模块都使用完整命名空间。
- 原版与自定义人物 StateGraph 都会安装动作处理器；没有合适动画状态时
  仍会使用保底处理器完成种植。

### 本地开发测试

使用 Junction 测试时，确保 DST 的 `mods` 目录中能同时看到并启用：

- `Mosswork`
- `PlantingAssistant`

修改 Lua 后需要重新进入世界或重启当前世界。模组加载失败时检查
`Documents/Klei/DoNotStarveTogether/client_log.txt`；服务端动作失败时
同时检查集群目录中的 `Master/server_log.txt`。

## License

Planting Assistant 的原创代码采用 [MIT License](LICENSE)。Don't Starve
Together、Klei、Geometric Placement 以及第三方名称和游戏资源不属于
本许可证授权范围。
