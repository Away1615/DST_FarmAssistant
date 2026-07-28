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
    es = {
        ["mod.name"] = "Asistente de plantación",
        ["action.plan"] = "Planificar plantación en lote",
        ["action.batch"] = "Plantar en lote",
        ["action.move"] = "Ir a la zona de plantación",

        ["settings.title"] = "Configuración del asistente de plantación",
        ["settings.local_rows"] = "Filas predeterminadas",
        ["settings.local_columns"] = "Columnas predeterminadas",
        ["settings.plant_spacing"] = "Espaciado de plantas",
        ["settings.grid_opacity"] = "Opacidad de la cuadrícula de GP",
        ["settings.rows_tooltip"] =
            "Número inicial de filas al entrar en el modo de plantación.",
        ["settings.columns_tooltip"] =
            "Número inicial de columnas al entrar en el modo de plantación.",
        ["settings.spacing_tooltip"] =
            "El modo automático calcula un espaciado fijo\nsegún el espaciado nativo de la planta.\nLa cantidad máxima segura se distribuye uniformemente\nen cada parcela de 4 × 4 y no cambia con las filas ni las columnas.\nLos valores manuales usan unidades del mundo de 1 a 4.",
        ["settings.opacity_tooltip"] =
            "Opción de compatibilidad con Geometric Placement.\nSolo cambia la opacidad de la cuadrícula de GP alrededor\nde las vistas previas del Asistente de plantación.\nNo modifica la configuración global de Geometric Placement,\nlas vistas previas de plantas ni los bordes de las parcelas.",
        ["settings.spacing_auto"] = "Automático",

        ["opacity.hidden"] = "Oculto",
        ["opacity.very_low"] = "Muy baja",
        ["opacity.low_recommended"] = "Baja (recomendado)",
        ["opacity.medium"] = "Media",
        ["opacity.high"] = "Alta",
        ["opacity.full"] = "Original",
    },
    ru = {
        ["mod.name"] = "Помощник по посадке",
        ["action.plan"] = "Спланировать массовую посадку",
        ["action.batch"] = "Массовая посадка",
        ["action.move"] = "Перейти к месту посадки",

        ["settings.title"] = "Настройки помощника по посадке",
        ["settings.local_rows"] = "Строки по умолчанию",
        ["settings.local_columns"] = "Столбцы по умолчанию",
        ["settings.plant_spacing"] = "Интервал между растениями",
        ["settings.grid_opacity"] = "Прозрачность сетки GP",
        ["settings.rows_tooltip"] =
            "Начальное число строк при входе в режим посадки.",
        ["settings.columns_tooltip"] =
            "Начальное число столбцов при входе в режим посадки.",
        ["settings.spacing_tooltip"] =
            "Автоматический режим вычисляет фиксированный интервал\nпо стандартному интервалу выбранного растения.\nМаксимальное безопасное количество равномерно распределяется\nна каждом участке 4 × 4 и не зависит от числа строк или столбцов.\nРучные значения задаются в единицах мира от 1 до 4.",
        ["settings.opacity_tooltip"] =
            "Параметр совместимости с Geometric Placement.\nИзменяет только прозрачность сетки GP вокруг предпросмотра\nПомощника по посадке. Он не меняет глобальные настройки\nGeometric Placement, предпросмотр растений или границы участков.",
        ["settings.spacing_auto"] = "Автоматически",

        ["opacity.hidden"] = "Скрыто",
        ["opacity.very_low"] = "Очень низкая",
        ["opacity.low_recommended"] = "Низкая (рекомендуется)",
        ["opacity.medium"] = "Средняя",
        ["opacity.high"] = "Высокая",
        ["opacity.full"] = "Исходная",
    },
    fr = {
        ["mod.name"] = "Assistant de plantation",
        ["action.plan"] = "Planifier une plantation groupée",
        ["action.batch"] = "Plantation groupée",
        ["action.move"] = "Aller à la zone de plantation",

        ["settings.title"] = "Paramètres de l’assistant de plantation",
        ["settings.local_rows"] = "Lignes par défaut",
        ["settings.local_columns"] = "Colonnes par défaut",
        ["settings.plant_spacing"] = "Espacement des plantes",
        ["settings.grid_opacity"] = "Opacité de la grille GP",
        ["settings.rows_tooltip"] =
            "Nombre initial de lignes à l’entrée du mode plantation.",
        ["settings.columns_tooltip"] =
            "Nombre initial de colonnes à l’entrée du mode plantation.",
        ["settings.spacing_tooltip"] =
            "Le mode automatique calcule un espacement fixe\nà partir de l’espacement natif de la plante.\nLe nombre maximal sûr est réparti uniformément sur chaque parcelle 4 × 4\net ne change pas avec le nombre de lignes ou de colonnes.\nLes valeurs manuelles utilisent de 1 à 4 unités du monde.",
        ["settings.opacity_tooltip"] =
            "Option de compatibilité avec Geometric Placement.\nModifie uniquement l’opacité de la grille GP affichée autour\ndes aperçus de l’Assistant de plantation.\nNe modifie ni les paramètres globaux de Geometric Placement,\nni les aperçus des plantes, ni les bordures des parcelles.",
        ["settings.spacing_auto"] = "Automatique",

        ["opacity.hidden"] = "Masquée",
        ["opacity.very_low"] = "Très faible",
        ["opacity.low_recommended"] = "Faible (recommandée)",
        ["opacity.medium"] = "Moyenne",
        ["opacity.high"] = "Élevée",
        ["opacity.full"] = "Intensité d’origine",
    },
    de = {
        ["mod.name"] = "Pflanzassistent",
        ["action.plan"] = "Gruppenpflanzung planen",
        ["action.batch"] = "Gruppenpflanzung",
        ["action.move"] = "Zum Pflanzbereich gehen",

        ["settings.title"] = "Einstellungen des Pflanzassistenten",
        ["settings.local_rows"] = "Standardzeilen",
        ["settings.local_columns"] = "Standardspalten",
        ["settings.plant_spacing"] = "Pflanzenabstand",
        ["settings.grid_opacity"] = "Deckkraft des GP-Rasters",
        ["settings.rows_tooltip"] =
            "Anfängliche Zeilenzahl beim Start des Pflanzmodus.",
        ["settings.columns_tooltip"] =
            "Anfängliche Spaltenzahl beim Start des Pflanzmodus.",
        ["settings.spacing_tooltip"] =
            "Automatisch berechnet einen festen Abstand\naus dem ursprünglichen Pflanzabstand der Pflanze.\nDie maximal sichere Anzahl wird gleichmäßig auf jedes 4 × 4-Feld verteilt\nund ändert sich nicht mit der Zeilen- oder Spaltenzahl.\nManuelle Werte verwenden 1 bis 4 Welteinheiten.",
        ["settings.opacity_tooltip"] =
            "Kompatibilitätsoption für Geometric Placement.\nÄndert nur die Deckkraft des GP-Rasters um die Vorschau\ndes Pflanzassistenten. Globale Einstellungen von Geometric Placement,\nPflanzenvorschauen und Feldränder bleiben unverändert.",
        ["settings.spacing_auto"] = "Automatisch",

        ["opacity.hidden"] = "Ausgeblendet",
        ["opacity.very_low"] = "Sehr niedrig",
        ["opacity.low_recommended"] = "Niedrig (empfohlen)",
        ["opacity.medium"] = "Mittel",
        ["opacity.high"] = "Hoch",
        ["opacity.full"] = "Original",
    },
    ja = {
        ["mod.name"] = "植え付けアシスタント",
        ["action.plan"] = "一括植え付けを計画",
        ["action.batch"] = "一括植え付け",
        ["action.move"] = "植え付け場所へ移動",

        ["settings.title"] = "植え付けアシスタント設定",
        ["settings.local_rows"] = "デフォルトの行数",
        ["settings.local_columns"] = "デフォルトの列数",
        ["settings.plant_spacing"] = "植物の間隔",
        ["settings.grid_opacity"] = "GP グリッドの不透明度",
        ["settings.rows_tooltip"] =
            "植え付けモード開始時に使用する行数です。",
        ["settings.columns_tooltip"] =
            "植え付けモード開始時に使用する列数です。",
        ["settings.spacing_tooltip"] =
            "自動モードでは植物本来の配置間隔から\n固定の間隔を計算します。\n各 4 × 4 タイルに安全な最大数を均等に配置し、\n行数や列数が変わっても間隔は変わりません。\n手動値はワールド単位の 1 から 4 です。",
        ["settings.opacity_tooltip"] =
            "Geometric Placement との互換設定です。\n植え付けアシスタントのプレビュー周囲に表示される\nGP グリッドの不透明度だけを変更します。\nGeometric Placement の全体設定、植物プレビュー、\nタイル境界には影響しません。",
        ["settings.spacing_auto"] = "自動",

        ["opacity.hidden"] = "非表示",
        ["opacity.very_low"] = "最低",
        ["opacity.low_recommended"] = "低（推奨）",
        ["opacity.medium"] = "中",
        ["opacity.high"] = "高",
        ["opacity.full"] = "元の濃さ",
    },
    ko = {
        ["mod.name"] = "심기 도우미",
        ["action.plan"] = "일괄 심기 계획",
        ["action.batch"] = "일괄 심기",
        ["action.move"] = "심기 구역으로 이동",

        ["settings.title"] = "심기 도우미 설정",
        ["settings.local_rows"] = "기본 행 수",
        ["settings.local_columns"] = "기본 열 수",
        ["settings.plant_spacing"] = "식물 간격",
        ["settings.grid_opacity"] = "GP 그리드 불투명도",
        ["settings.rows_tooltip"] =
            "심기 모드를 시작할 때 사용할 초기 행 수입니다.",
        ["settings.columns_tooltip"] =
            "심기 모드를 시작할 때 사용할 초기 열 수입니다.",
        ["settings.spacing_tooltip"] =
            "자동 모드는 식물의 기본 배치 간격을 기준으로\n고정 간격을 계산합니다.\n각 4 × 4 타일에 안전한 최대 수량을 고르게 배치하며\n행 또는 열 수가 바뀌어도 간격은 변하지 않습니다.\n수동 값은 월드 단위 1부터 4까지입니다.",
        ["settings.opacity_tooltip"] =
            "Geometric Placement 호환 옵션입니다.\n심기 도우미 미리보기 주변에 표시되는 GP 그리드의\n불투명도만 변경합니다. Geometric Placement의 전역 설정,\n식물 미리보기 또는 타일 경계에는 영향을 주지 않습니다.",
        ["settings.spacing_auto"] = "자동",

        ["opacity.hidden"] = "숨김",
        ["opacity.very_low"] = "매우 낮음",
        ["opacity.low_recommended"] = "낮음 (권장)",
        ["opacity.medium"] = "중간",
        ["opacity.high"] = "높음",
        ["opacity.full"] = "원래 강도",
    },
}

return Language.Create(STRINGS, "mosswork.planting_assistant")
