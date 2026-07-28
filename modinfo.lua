local is_chinese = locale == "zh"
    or locale == "zhr"
    or locale == "zht"

local function T(english, chinese)
    return is_chinese and chinese or english
end

name = T("Planting Assistant", "种植助手")
description = T(
    [[
Server-authoritative batch planting assistant.

While holding a supported transplant:
Ctrl + Mouse Wheel: adjust rows
Alt + Mouse Wheel: adjust columns
Right Mouse Button: confirm batch planting

The client previews the layout. The character first moves into range, then the server recalculates and validates the entire layout over multiple frames. After one planting animation, valid positions are planted up to the available inventory count while blocked positions are skipped.
Players can use a fixed automatic spacing that evenly fills each tile or choose a personal manual spacing from 1 to 4 world units in the Mosswork settings center.
Requires Mosswork for the shared language, profile, and settings infrastructure.
]],
    [[
服务端权威的批量种植助手。

手持支持的移植作物时：
Ctrl + 鼠标滚轮：调整行数
Alt + 鼠标滚轮：调整列数
鼠标右键：确认批量种植

客户端负责预览；角色先移动到目标区域，服务器再重新计算、全局分帧预检，并在一次角色动作后按当前库存数量跳过阻挡点、批量部署其余位置。
玩家可以在 Mosswork 设置中心使用自动计算且整齐填满每块地皮的固定作物间距，或保存 1 至 4 个世界单位的个人手动间距。
依赖 Mosswork 提供统一语言、玩家档案和设置入口。
]]
)
author = "Nooobad"
version = "0.17.0"

icon_atlas = "modicon.xml"
icon = "modicon.tex"

api_version = 10
dst_compatible = true
all_clients_require_mod = true
client_only_mod = false
priority = 0

mod_dependencies = {
    {
        ["Mosswork"] = false,
    },
}

server_filter_tags = {
    "planting",
    "utility",
}
