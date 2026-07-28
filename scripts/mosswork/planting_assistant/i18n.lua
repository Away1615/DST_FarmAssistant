local Mosswork = require("mosswork")
local Language = Mosswork.Language

local STRINGS = {
    en = {
        ["mod.name"] = "Planting Assistant",
        ["action.plan"] = "Plan Batch Planting",
        ["action.batch"] = "Batch Plant",
        ["action.move"] = "Move to Planting Area",

        ["settings.title"] = "Planting Assistant Settings",
        ["settings.local_rows"] = "Default Rows",
        ["settings.local_columns"] = "Default Columns",
        ["settings.plant_spacing"] = "Plant Spacing",
        ["settings.grid_opacity"] = "GP Grid Opacity",
        ["settings.rows_tooltip"] =
            "Initial row count used when entering planting mode.",
        ["settings.columns_tooltip"] =
            "Initial column count used when entering planting mode.",
        ["settings.spacing_tooltip"] =
            "Automatic calculates one fixed spacing per crop\nfrom its native deploy spacing.\nThe maximum safe count is distributed evenly across each 4 x 4 tile\nand does not change with rows or columns.\nManual values use world units from 1 to 4.",
        ["settings.opacity_tooltip"] =
            "Compatibility option for Geometric Placement.\nOnly changes the opacity of the GP Grid shown around Planting Assistant previews.\nIt does not modify Geometric Placement's global settings,\nplant previews, or tile borders.",
        ["settings.spacing_auto"] = "Automatic",

        ["opacity.hidden"] = "Hidden",
        ["opacity.very_low"] = "Very Low",
        ["opacity.low_recommended"] = "Low (Recommended)",
        ["opacity.medium"] = "Medium",
        ["opacity.high"] = "High",
        ["opacity.full"] = "Original",
    },
    zh = {
        ["mod.name"] = "种植助手",
        ["action.plan"] = "规划批量种植",
        ["action.batch"] = "批量种植",
        ["action.move"] = "移动到种植区域",

        ["settings.title"] = "种植助手设置",
        ["settings.local_rows"] = "默认行数",
        ["settings.local_columns"] = "默认列数",
        ["settings.plant_spacing"] = "作物间距",
        ["settings.grid_opacity"] = "GP Grid 透明度",
        ["settings.rows_tooltip"] =
            "进入种植模式时使用的初始行数。",
        ["settings.columns_tooltip"] =
            "进入种植模式时使用的初始列数。",
        ["settings.spacing_tooltip"] =
            "自动模式会根据当前作物的原生部署间距计算一个固定值，\n让每块 4 × 4 地皮内可安全容纳的最大数量均匀铺满；\n不会随行列数变化。\n手动值为 1 至 4 个世界单位。",
        ["settings.opacity_tooltip"] =
            "此选项专门用于兼容 Geometric Placement。\n只调整种植助手预览周围 GP Grid 的透明度，\n不会修改 Geometric Placement 的全局设置，\n也不影响作物预览和地皮框。",
        ["settings.spacing_auto"] = "自动",

        ["opacity.hidden"] = "隐藏",
        ["opacity.very_low"] = "很浅",
        ["opacity.low_recommended"] = "浅（推荐）",
        ["opacity.medium"] = "中等",
        ["opacity.high"] = "较深",
        ["opacity.full"] = "原始强度",
    },
}

return Language.Create(STRINGS, "mosswork.planting_assistant")
