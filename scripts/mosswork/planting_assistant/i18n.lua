local Mosswork = require("mosswork")
local Language = Mosswork.Language

local STRINGS = {
    en = {
        ["mod.name"] = "Planting Assistant",
        ["action.batch"] = "Batch Plant",
        ["controller.rows"] = "Rows: %d",
        ["controller.columns"] = "Columns: %d",

        ["settings.title"] = "Planting Assistant Settings",
        ["settings.local_rows"] = "Default Rows",
        ["settings.local_columns"] = "Default Columns",
        ["settings.grid_opacity"] = "GP Grid Opacity",
        ["settings.rows_tooltip"] =
            "Initial row count. A layout supports at most 9 rows and 9 columns\n(81 candidate positions).",
        ["settings.columns_tooltip"] =
            "Initial column count. A layout supports at most 9 rows and 9 columns\n(81 candidate positions).",
        ["settings.opacity_tooltip"] =
            "Compatibility option for Geometric Placement.\nOnly changes the opacity of the GP Grid shown around Planting Assistant previews.\nIt does not modify Geometric Placement's global settings,\nplant previews, or tile borders.",

        ["failure.busy"] = "Another planting batch is already running.",
        ["failure.server_busy"] =
            "The server is handling too many planting batches. Try again shortly.",
        ["failure.no_inventory"] =
            "No matching plantable items remain in your inventory.",
        ["failure.no_positions"] =
            "No valid planting positions were available.",
        ["failure.too_far"] =
            "Move closer to the planting area and stay nearby.",
        ["failure.selection_changed"] =
            "The selected item or target changed. Please try again.",
        ["failure.timeout"] =
            "The planting request timed out. Please try again.",
        ["failure.unavailable"] =
            "Your character cannot plant in their current state.",
        ["failure.interrupted"] = "The planting action was interrupted.",
        ["failure.layout_too_large"] =
            "The layout cannot exceed 9 rows by 9 columns.",
        ["failure.invalid"] = "The server rejected the planting request.",
        ["failure.internal"] =
            "Batch planting failed. Check the server log.",
        ["failure.plantable_unavailable"] =
            "This item's planting code failed. The current batch was stopped.",
        ["failure.generic"] = "Batch planting did not complete.",

        ["opacity.hidden"] = "Hidden",
        ["opacity.very_low"] = "Very Low",
        ["opacity.low_recommended"] = "Low (Recommended)",
        ["opacity.medium"] = "Medium",
        ["opacity.high"] = "High",
        ["opacity.full"] = "Original",
    },
    zh = {
        ["mod.name"] = "种植助手",
        ["action.batch"] = "批量种植",
        ["controller.rows"] = "行数：%d",
        ["controller.columns"] = "列数：%d",

        ["settings.title"] = "种植助手设置",
        ["settings.local_rows"] = "默认行数",
        ["settings.local_columns"] = "默认列数",
        ["settings.grid_opacity"] = "GP Grid 透明度",
        ["settings.rows_tooltip"] =
            "进入种植模式时使用的初始行数。\n阵列最多为 9 行 × 9 列（81 个候选位置）。",
        ["settings.columns_tooltip"] =
            "进入种植模式时使用的初始列数。\n阵列最多为 9 行 × 9 列（81 个候选位置）。",
        ["settings.opacity_tooltip"] =
            "此选项专门用于兼容 Geometric Placement。\n只调整种植助手预览周围 GP Grid 的透明度，\n不会修改 Geometric Placement 的全局设置，\n也不影响作物预览和地皮框。",

        ["failure.busy"] = "已有一批种植正在执行。",
        ["failure.server_busy"] = "服务端正在处理过多种植批次，请稍后重试。",
        ["failure.no_inventory"] = "背包中没有可用的同类种植物。",
        ["failure.no_positions"] = "当前阵列没有可用的种植位置。",
        ["failure.too_far"] = "请靠近种植区域，并在执行期间留在附近。",
        ["failure.selection_changed"] =
            "活动物品或目标已改变，请重新操作。",
        ["failure.timeout"] = "种植请求已超时，请重试。",
        ["failure.unavailable"] = "角色当前状态无法执行种植。",
        ["failure.interrupted"] = "种植动作被中断。",
        ["failure.layout_too_large"] = "阵列不能超过 9 行 × 9 列。",
        ["failure.invalid"] = "服务端拒绝了此次种植请求。",
        ["failure.internal"] = "批量种植发生内部错误，请检查服务端日志。",
        ["failure.plantable_unavailable"] =
            "该物品的种植逻辑报错，当前批次已停止。",
        ["failure.generic"] = "批量种植未能完成。",

        ["opacity.hidden"] = "隐藏",
        ["opacity.very_low"] = "很浅",
        ["opacity.low_recommended"] = "浅（推荐）",
        ["opacity.medium"] = "中等",
        ["opacity.high"] = "较深",
        ["opacity.full"] = "原始强度",
    },
    es = {
        ["mod.name"] = "Asistente de plantación",
        ["action.batch"] = "Plantar en lote",
        ["controller.rows"] = "Filas: %d",
        ["controller.columns"] = "Columnas: %d",

        ["settings.title"] = "Configuración del asistente de plantación",
        ["settings.local_rows"] = "Filas predeterminadas",
        ["settings.local_columns"] = "Columnas predeterminadas",
        ["settings.grid_opacity"] = "Opacidad de la cuadrícula de GP",
        ["settings.rows_tooltip"] =
            "Número inicial de filas. El diseño admite como máximo 9 filas\ny 9 columnas (81 posiciones candidatas).",
        ["settings.columns_tooltip"] =
            "Número inicial de columnas. El diseño admite como máximo 9 filas\ny 9 columnas (81 posiciones candidatas).",
        ["settings.opacity_tooltip"] =
            "Opción de compatibilidad con Geometric Placement.\nSolo cambia la opacidad de la cuadrícula de GP alrededor\nde las vistas previas del Asistente de plantación.\nNo modifica la configuración global de Geometric Placement,\nlas vistas previas de plantas ni los bordes de las parcelas.",

        ["failure.busy"] = "Ya hay un lote de plantación en curso.",
        ["failure.server_busy"] =
            "El servidor procesa demasiados lotes. Inténtalo de nuevo en breve.",
        ["failure.no_inventory"] =
            "No quedan objetos plantables iguales en tu inventario.",
        ["failure.no_positions"] =
            "No había posiciones válidas para plantar.",
        ["failure.too_far"] =
            "Acércate a la zona de plantación y permanece cerca.",
        ["failure.selection_changed"] =
            "El objeto o el objetivo cambió. Inténtalo de nuevo.",
        ["failure.timeout"] =
            "La solicitud de plantación agotó el tiempo. Inténtalo de nuevo.",
        ["failure.unavailable"] =
            "Tu personaje no puede plantar en su estado actual.",
        ["failure.interrupted"] = "La acción de plantación fue interrumpida.",
        ["failure.layout_too_large"] =
            "El diseño no puede superar 9 filas por 9 columnas.",
        ["failure.invalid"] =
            "El servidor rechazó la solicitud de plantación.",
        ["failure.internal"] =
            "La plantación en lote falló. Revisa el registro del servidor.",
        ["failure.plantable_unavailable"] =
            "El código de plantación del objeto falló. Se detuvo el lote actual.",
        ["failure.generic"] = "La plantación en lote no pudo completarse.",

        ["opacity.hidden"] = "Oculto",
        ["opacity.very_low"] = "Muy baja",
        ["opacity.low_recommended"] = "Baja (recomendado)",
        ["opacity.medium"] = "Media",
        ["opacity.high"] = "Alta",
        ["opacity.full"] = "Original",
    },
    ru = {
        ["mod.name"] = "Помощник по посадке",
        ["action.batch"] = "Массовая посадка",
        ["controller.rows"] = "Строки: %d",
        ["controller.columns"] = "Столбцы: %d",

        ["settings.title"] = "Настройки помощника по посадке",
        ["settings.local_rows"] = "Строки по умолчанию",
        ["settings.local_columns"] = "Столбцы по умолчанию",
        ["settings.grid_opacity"] = "Прозрачность сетки GP",
        ["settings.rows_tooltip"] =
            "Начальное число строк. Схема поддерживает не более 9 строк\nи 9 столбцов (81 возможная позиция).",
        ["settings.columns_tooltip"] =
            "Начальное число столбцов. Схема поддерживает не более 9 строк\nи 9 столбцов (81 возможная позиция).",
        ["settings.opacity_tooltip"] =
            "Параметр совместимости с Geometric Placement.\nИзменяет только прозрачность сетки GP вокруг предпросмотра\nПомощника по посадке. Он не меняет глобальные настройки\nGeometric Placement, предпросмотр растений или границы участков.",

        ["failure.busy"] = "Уже выполняется другая массовая посадка.",
        ["failure.server_busy"] =
            "Сервер обрабатывает слишком много посадок. Повторите попытку позже.",
        ["failure.no_inventory"] =
            "В инвентаре не осталось подходящих предметов для посадки.",
        ["failure.no_positions"] =
            "Нет доступных мест для посадки.",
        ["failure.too_far"] =
            "Подойдите ближе к месту посадки и оставайтесь рядом.",
        ["failure.selection_changed"] =
            "Предмет или цель изменились. Повторите попытку.",
        ["failure.timeout"] =
            "Время ожидания запроса истекло. Повторите попытку.",
        ["failure.unavailable"] =
            "Персонаж не может сажать в текущем состоянии.",
        ["failure.interrupted"] = "Действие посадки было прервано.",
        ["failure.layout_too_large"] =
            "Схема не может превышать 9 строк на 9 столбцов.",
        ["failure.invalid"] = "Сервер отклонил запрос на посадку.",
        ["failure.internal"] =
            "Ошибка массовой посадки. Проверьте журнал сервера.",
        ["failure.plantable_unavailable"] =
            "Код посадки предмета завершился ошибкой. Текущая партия остановлена.",
        ["failure.generic"] = "Массовая посадка не была завершена.",

        ["opacity.hidden"] = "Скрыто",
        ["opacity.very_low"] = "Очень низкая",
        ["opacity.low_recommended"] = "Низкая (рекомендуется)",
        ["opacity.medium"] = "Средняя",
        ["opacity.high"] = "Высокая",
        ["opacity.full"] = "Исходная",
    },
    fr = {
        ["mod.name"] = "Assistant de plantation",
        ["action.batch"] = "Plantation groupée",
        ["controller.rows"] = "Lignes : %d",
        ["controller.columns"] = "Colonnes : %d",

        ["settings.title"] = "Paramètres de l’assistant de plantation",
        ["settings.local_rows"] = "Lignes par défaut",
        ["settings.local_columns"] = "Colonnes par défaut",
        ["settings.grid_opacity"] = "Opacité de la grille GP",
        ["settings.rows_tooltip"] =
            "Nombre initial de lignes. La disposition accepte au maximum 9 lignes\net 9 colonnes (81 positions candidates).",
        ["settings.columns_tooltip"] =
            "Nombre initial de colonnes. La disposition accepte au maximum 9 lignes\net 9 colonnes (81 positions candidates).",
        ["settings.opacity_tooltip"] =
            "Option de compatibilité avec Geometric Placement.\nModifie uniquement l’opacité de la grille GP affichée autour\ndes aperçus de l’Assistant de plantation.\nNe modifie ni les paramètres globaux de Geometric Placement,\nni les aperçus des plantes, ni les bordures des parcelles.",

        ["failure.busy"] = "Une plantation groupée est déjà en cours.",
        ["failure.server_busy"] =
            "Le serveur traite trop de plantations. Réessayez dans un instant.",
        ["failure.no_inventory"] =
            "Il ne reste aucun objet plantable correspondant dans l’inventaire.",
        ["failure.no_positions"] =
            "Aucune position de plantation valide n’est disponible.",
        ["failure.too_far"] =
            "Approchez-vous de la zone de plantation et restez à proximité.",
        ["failure.selection_changed"] =
            "L’objet ou la cible a changé. Réessayez.",
        ["failure.timeout"] =
            "La demande de plantation a expiré. Réessayez.",
        ["failure.unavailable"] =
            "Votre personnage ne peut pas planter dans son état actuel.",
        ["failure.interrupted"] = "L’action de plantation a été interrompue.",
        ["failure.layout_too_large"] =
            "La disposition ne peut pas dépasser 9 lignes sur 9 colonnes.",
        ["failure.invalid"] =
            "Le serveur a rejeté la demande de plantation.",
        ["failure.internal"] =
            "La plantation groupée a échoué. Consultez le journal du serveur.",
        ["failure.plantable_unavailable"] =
            "Le code de plantation de cet objet a échoué. Le lot en cours a été arrêté.",
        ["failure.generic"] =
            "La plantation groupée n’a pas pu être terminée.",

        ["opacity.hidden"] = "Masquée",
        ["opacity.very_low"] = "Très faible",
        ["opacity.low_recommended"] = "Faible (recommandée)",
        ["opacity.medium"] = "Moyenne",
        ["opacity.high"] = "Élevée",
        ["opacity.full"] = "Intensité d’origine",
    },
    de = {
        ["mod.name"] = "Pflanzassistent",
        ["action.batch"] = "Gruppenpflanzung",
        ["controller.rows"] = "Zeilen: %d",
        ["controller.columns"] = "Spalten: %d",

        ["settings.title"] = "Einstellungen des Pflanzassistenten",
        ["settings.local_rows"] = "Standardzeilen",
        ["settings.local_columns"] = "Standardspalten",
        ["settings.grid_opacity"] = "Deckkraft des GP-Rasters",
        ["settings.rows_tooltip"] =
            "Anfängliche Zeilenzahl. Eine Anordnung unterstützt höchstens 9 Zeilen\nund 9 Spalten (81 mögliche Positionen).",
        ["settings.columns_tooltip"] =
            "Anfängliche Spaltenzahl. Eine Anordnung unterstützt höchstens 9 Zeilen\nund 9 Spalten (81 mögliche Positionen).",
        ["settings.opacity_tooltip"] =
            "Kompatibilitätsoption für Geometric Placement.\nÄndert nur die Deckkraft des GP-Rasters um die Vorschau\ndes Pflanzassistenten. Globale Einstellungen von Geometric Placement,\nPflanzenvorschauen und Feldränder bleiben unverändert.",

        ["failure.busy"] = "Eine Gruppenpflanzung läuft bereits.",
        ["failure.server_busy"] =
            "Der Server verarbeitet zu viele Pflanzvorgänge. Versuche es gleich erneut.",
        ["failure.no_inventory"] =
            "Keine passenden pflanzbaren Gegenstände mehr im Inventar.",
        ["failure.no_positions"] =
            "Es waren keine gültigen Pflanzpositionen verfügbar.",
        ["failure.too_far"] =
            "Gehe näher zum Pflanzbereich und bleibe in der Nähe.",
        ["failure.selection_changed"] =
            "Gegenstand oder Ziel haben sich geändert. Versuche es erneut.",
        ["failure.timeout"] =
            "Die Pflanzanfrage ist abgelaufen. Versuche es erneut.",
        ["failure.unavailable"] =
            "Dein Charakter kann im aktuellen Zustand nicht pflanzen.",
        ["failure.interrupted"] = "Die Pflanzaktion wurde unterbrochen.",
        ["failure.layout_too_large"] =
            "Die Anordnung darf höchstens 9 Zeilen mal 9 Spalten umfassen.",
        ["failure.invalid"] = "Der Server hat die Pflanzanfrage abgelehnt.",
        ["failure.internal"] =
            "Gruppenpflanzung fehlgeschlagen. Prüfe das Serverprotokoll.",
        ["failure.plantable_unavailable"] =
            "Der Pflanzcode dieses Gegenstands ist fehlgeschlagen. Der aktuelle Durchlauf wurde gestoppt.",
        ["failure.generic"] =
            "Die Gruppenpflanzung konnte nicht abgeschlossen werden.",

        ["opacity.hidden"] = "Ausgeblendet",
        ["opacity.very_low"] = "Sehr niedrig",
        ["opacity.low_recommended"] = "Niedrig (empfohlen)",
        ["opacity.medium"] = "Mittel",
        ["opacity.high"] = "Hoch",
        ["opacity.full"] = "Original",
    },
    ja = {
        ["mod.name"] = "植え付けアシスタント",
        ["action.batch"] = "一括植え付け",
        ["controller.rows"] = "行数: %d",
        ["controller.columns"] = "列数: %d",

        ["settings.title"] = "植え付けアシスタント設定",
        ["settings.local_rows"] = "デフォルトの行数",
        ["settings.local_columns"] = "デフォルトの列数",
        ["settings.grid_opacity"] = "GP グリッドの不透明度",
        ["settings.rows_tooltip"] =
            "植え付けモード開始時の行数です。\n配置は最大 9 行 × 9 列（候補位置 81 か所）です。",
        ["settings.columns_tooltip"] =
            "植え付けモード開始時の列数です。\n配置は最大 9 行 × 9 列（候補位置 81 か所）です。",
        ["settings.opacity_tooltip"] =
            "Geometric Placement との互換設定です。\n植え付けアシスタントのプレビュー周囲に表示される\nGP グリッドの不透明度だけを変更します。\nGeometric Placement の全体設定、植物プレビュー、\nタイル境界には影響しません。",

        ["failure.busy"] = "別の一括植え付けを実行中です。",
        ["failure.server_busy"] =
            "サーバーが多数の植え付けを処理中です。少し待って再試行してください。",
        ["failure.no_inventory"] = "同じ植え付け可能なアイテムが持ち物に残っていません。",
        ["failure.no_positions"] = "植え付け可能な場所がありませんでした。",
        ["failure.too_far"] =
            "植え付け場所へ近づき、実行中は付近に留まってください。",
        ["failure.selection_changed"] =
            "アイテムまたは目標が変わりました。もう一度お試しください。",
        ["failure.timeout"] =
            "植え付け要求がタイムアウトしました。もう一度お試しください。",
        ["failure.unavailable"] =
            "現在のキャラクター状態では植え付けできません。",
        ["failure.interrupted"] = "植え付け動作が中断されました。",
        ["failure.layout_too_large"] =
            "配置は 9 行 × 9 列以内にしてください。",
        ["failure.invalid"] = "サーバーが植え付け要求を拒否しました。",
        ["failure.internal"] =
            "一括植え付けに失敗しました。サーバーログを確認してください。",
        ["failure.plantable_unavailable"] =
            "このアイテムの植え付け処理でエラーが発生したため、現在の一括処理を停止しました。",
        ["failure.generic"] = "一括植え付けを完了できませんでした。",

        ["opacity.hidden"] = "非表示",
        ["opacity.very_low"] = "最低",
        ["opacity.low_recommended"] = "低（推奨）",
        ["opacity.medium"] = "中",
        ["opacity.high"] = "高",
        ["opacity.full"] = "元の濃さ",
    },
    ko = {
        ["mod.name"] = "심기 도우미",
        ["action.batch"] = "일괄 심기",
        ["controller.rows"] = "행 수: %d",
        ["controller.columns"] = "열 수: %d",

        ["settings.title"] = "심기 도우미 설정",
        ["settings.local_rows"] = "기본 행 수",
        ["settings.local_columns"] = "기본 열 수",
        ["settings.grid_opacity"] = "GP 그리드 불투명도",
        ["settings.rows_tooltip"] =
            "심기 모드를 시작할 때 사용할 행 수입니다.\n배치는 최대 9행 × 9열(후보 위치 81개)입니다.",
        ["settings.columns_tooltip"] =
            "심기 모드를 시작할 때 사용할 열 수입니다.\n배치는 최대 9행 × 9열(후보 위치 81개)입니다.",
        ["settings.opacity_tooltip"] =
            "Geometric Placement 호환 옵션입니다.\n심기 도우미 미리보기 주변에 표시되는 GP 그리드의\n불투명도만 변경합니다. Geometric Placement의 전역 설정,\n식물 미리보기 또는 타일 경계에는 영향을 주지 않습니다.",

        ["failure.busy"] = "다른 일괄 심기를 실행 중입니다.",
        ["failure.server_busy"] =
            "서버가 너무 많은 심기 작업을 처리 중입니다. 잠시 후 다시 시도하세요.",
        ["failure.no_inventory"] =
            "소지품에 같은 심기 가능한 아이템이 남아 있지 않습니다.",
        ["failure.no_positions"] =
            "심을 수 있는 위치가 없습니다.",
        ["failure.too_far"] =
            "심기 구역에 가까이 이동하고 실행 중에는 주변에 머무르세요.",
        ["failure.selection_changed"] =
            "아이템 또는 대상이 바뀌었습니다. 다시 시도해 주세요.",
        ["failure.timeout"] =
            "심기 요청 시간이 초과되었습니다. 다시 시도해 주세요.",
        ["failure.unavailable"] =
            "현재 캐릭터 상태에서는 심을 수 없습니다.",
        ["failure.interrupted"] = "심기 동작이 중단되었습니다.",
        ["failure.layout_too_large"] =
            "배치는 9행 × 9열을 초과할 수 없습니다.",
        ["failure.invalid"] = "서버가 심기 요청을 거부했습니다.",
        ["failure.internal"] =
            "일괄 심기에 실패했습니다. 서버 로그를 확인하세요.",
        ["failure.plantable_unavailable"] =
            "이 아이템의 심기 코드에서 오류가 발생해 현재 일괄 작업을 중단했습니다.",
        ["failure.generic"] = "일괄 심기를 완료하지 못했습니다.",

        ["opacity.hidden"] = "숨김",
        ["opacity.very_low"] = "매우 낮음",
        ["opacity.low_recommended"] = "낮음 (권장)",
        ["opacity.medium"] = "중간",
        ["opacity.high"] = "높음",
        ["opacity.full"] = "원래 강도",
    },
}

return Language.Create(STRINGS, "mosswork.planting_assistant")
