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
        ["settings.grid_opacity"] = "GP Grid Opacity",
        ["settings.rows_tooltip"] =
            "Initial row count. Automatic spacing may allow up to 36 plants,\nbut the layout never exceeds 9 turf tiles per side.",
        ["settings.columns_tooltip"] =
            "Initial column count. Automatic spacing may allow up to 36 plants,\nbut the layout never exceeds 9 turf tiles per side.",
        ["settings.opacity_tooltip"] =
            "Compatibility option for Geometric Placement.\nOnly changes the opacity of the GP Grid shown around Planting Assistant previews.\nIt does not modify Geometric Placement's global settings,\nplant previews, or tile borders.",

        ["failure.rate_limited"] =
            "Please wait a moment and try again.",
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
            "The layout cannot cover more than 9 x 9 tiles.",
        ["failure.invalid"] = "The server rejected the planting request.",
        ["failure.internal"] =
            "Batch planting failed. Check the server log.",
        ["failure.plantable_unavailable"] =
            "This item's planting code failed. The current batch was stopped.",
        ["failure.generic"] = "Batch planting did not complete.",
        ["undo.success"] = "The previous planting batch was undone.",
        ["undo.unavailable"] =
            "There is no recent planting batch to undo.",
        ["undo.expired"] = "The 5-second undo window has expired.",
        ["undo.changed"] =
            "A planted entity is gone or moved, so the batch was not undone.",
        ["undo.unsupported"] =
            "This planting result does not support safe undo.",
        ["undo.busy"] =
            "Wait for the current planting batch to finish.",
        ["undo.internal"] =
            "The planting batch could not be undone safely. Check the server log.",

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
        ["settings.grid_opacity"] = "GP Grid 透明度",
        ["settings.rows_tooltip"] =
            "进入种植模式时使用的初始行数。\n自动间距下最多可达到 36 株，但阵列每边始终不超过 9 块地皮。",
        ["settings.columns_tooltip"] =
            "进入种植模式时使用的初始列数。\n自动间距下最多可达到 36 株，但阵列每边始终不超过 9 块地皮。",
        ["settings.opacity_tooltip"] =
            "此选项专门用于兼容 Geometric Placement。\n只调整种植助手预览周围 GP Grid 的透明度，\n不会修改 Geometric Placement 的全局设置，\n也不影响作物预览和地皮框。",

        ["failure.rate_limited"] = "请稍后再试。",
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
        ["failure.layout_too_large"] = "阵列范围不能超过 9 × 9 块地皮。",
        ["failure.invalid"] = "服务端拒绝了此次种植请求。",
        ["failure.internal"] = "批量种植发生内部错误，请检查服务端日志。",
        ["failure.plantable_unavailable"] =
            "该物品的种植逻辑报错，当前批次已停止。",
        ["failure.generic"] = "批量种植未能完成。",
        ["undo.success"] = "上一批种植已撤销。",
        ["undo.unavailable"] = "当前没有可撤销的最近种植批次。",
        ["undo.expired"] = "5 秒撤销窗口已结束。",
        ["undo.changed"] =
            "部分作物已消失、被替换或离开原位置，整批未撤销。",
        ["undo.unsupported"] =
            "该作物的种植结果无法安全识别，因此不支持撤销。",
        ["undo.busy"] = "请等待当前种植批次完成后再撤销。",
        ["undo.internal"] =
            "无法安全撤销上一批种植，请检查服务端日志。",

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
        ["settings.grid_opacity"] = "Opacidad de la cuadrícula de GP",
        ["settings.rows_tooltip"] =
            "Número inicial de filas. El máximo se adapta a la planta,\npero el diseño nunca supera 9 parcelas por lado.",
        ["settings.columns_tooltip"] =
            "Número inicial de columnas. El máximo se adapta a la planta,\npero el diseño nunca supera 9 parcelas por lado.",
        ["settings.opacity_tooltip"] =
            "Opción de compatibilidad con Geometric Placement.\nSolo cambia la opacidad de la cuadrícula de GP alrededor\nde las vistas previas del Asistente de plantación.\nNo modifica la configuración global de Geometric Placement,\nlas vistas previas de plantas ni los bordes de las parcelas.",

        ["failure.rate_limited"] =
            "Espera un momento y vuelve a intentarlo.",
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
            "El diseño no puede cubrir más de 9 x 9 parcelas.",
        ["failure.invalid"] =
            "El servidor rechazó la solicitud de plantación.",
        ["failure.internal"] =
            "La plantación en lote falló. Revisa el registro del servidor.",
        ["failure.plantable_unavailable"] =
            "El código de plantación del objeto falló. Se detuvo el lote actual.",
        ["failure.generic"] = "La plantación en lote no pudo completarse.",
        ["undo.success"] = "Se deshizo el último lote de plantación.",
        ["undo.unavailable"] =
            "No hay ningún lote reciente que se pueda deshacer.",
        ["undo.expired"] =
            "La ventana de deshacer de 5 segundos ha terminado.",
        ["undo.changed"] =
            "Una planta desapareció o se movió; no se deshizo el lote.",
        ["undo.unsupported"] =
            "Este resultado de plantación no admite un deshacer seguro.",
        ["undo.busy"] =
            "Espera a que termine el lote de plantación actual.",
        ["undo.internal"] =
            "No se pudo deshacer el lote de forma segura. Revisa el registro del servidor.",

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
        ["settings.grid_opacity"] = "Прозрачность сетки GP",
        ["settings.rows_tooltip"] =
            "Начальное число строк. Максимум зависит от растения,\nно схема не превышает 9 участков по каждой стороне.",
        ["settings.columns_tooltip"] =
            "Начальное число столбцов. Максимум зависит от растения,\nно схема не превышает 9 участков по каждой стороне.",
        ["settings.opacity_tooltip"] =
            "Параметр совместимости с Geometric Placement.\nИзменяет только прозрачность сетки GP вокруг предпросмотра\nПомощника по посадке. Он не меняет глобальные настройки\nGeometric Placement, предпросмотр растений или границы участков.",

        ["failure.rate_limited"] =
            "Немного подождите и повторите попытку.",
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
            "Схема не может занимать больше 9 x 9 участков.",
        ["failure.invalid"] = "Сервер отклонил запрос на посадку.",
        ["failure.internal"] =
            "Ошибка массовой посадки. Проверьте журнал сервера.",
        ["failure.plantable_unavailable"] =
            "Код посадки предмета завершился ошибкой. Текущая партия остановлена.",
        ["failure.generic"] = "Массовая посадка не была завершена.",
        ["undo.success"] = "Последняя партия посадки отменена.",
        ["undo.unavailable"] =
            "Нет недавней партии посадки для отмены.",
        ["undo.expired"] =
            "Пятисекундное окно отмены уже истекло.",
        ["undo.changed"] =
            "Одно из растений исчезло или переместилось; партия не отменена.",
        ["undo.unsupported"] =
            "Результат этой посадки нельзя безопасно отменить.",
        ["undo.busy"] =
            "Дождитесь завершения текущей партии посадки.",
        ["undo.internal"] =
            "Не удалось безопасно отменить посадку. Проверьте журнал сервера.",

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
        ["settings.grid_opacity"] = "Opacité de la grille GP",
        ["settings.rows_tooltip"] =
            "Nombre initial de lignes. Le maximum dépend de la plante,\nmais la disposition ne dépasse jamais 9 parcelles par côté.",
        ["settings.columns_tooltip"] =
            "Nombre initial de colonnes. Le maximum dépend de la plante,\nmais la disposition ne dépasse jamais 9 parcelles par côté.",
        ["settings.opacity_tooltip"] =
            "Option de compatibilité avec Geometric Placement.\nModifie uniquement l’opacité de la grille GP affichée autour\ndes aperçus de l’Assistant de plantation.\nNe modifie ni les paramètres globaux de Geometric Placement,\nni les aperçus des plantes, ni les bordures des parcelles.",

        ["failure.rate_limited"] =
            "Attendez un instant, puis réessayez.",
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
            "La disposition ne peut pas dépasser 9 x 9 parcelles.",
        ["failure.invalid"] =
            "Le serveur a rejeté la demande de plantation.",
        ["failure.internal"] =
            "La plantation groupée a échoué. Consultez le journal du serveur.",
        ["failure.plantable_unavailable"] =
            "Le code de plantation de cet objet a échoué. Le lot en cours a été arrêté.",
        ["failure.generic"] =
            "La plantation groupée n’a pas pu être terminée.",
        ["undo.success"] =
            "La dernière plantation groupée a été annulée.",
        ["undo.unavailable"] =
            "Aucune plantation récente ne peut être annulée.",
        ["undo.expired"] =
            "La fenêtre d’annulation de 5 secondes est terminée.",
        ["undo.changed"] =
            "Une plante a disparu ou s’est déplacée ; le lot n’a pas été annulé.",
        ["undo.unsupported"] =
            "Ce résultat de plantation ne permet pas une annulation sûre.",
        ["undo.busy"] =
            "Attendez la fin de la plantation groupée en cours.",
        ["undo.internal"] =
            "Impossible d’annuler la plantation en toute sécurité. Consultez le journal du serveur.",

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
        ["settings.grid_opacity"] = "Deckkraft des GP-Rasters",
        ["settings.rows_tooltip"] =
            "Anfängliche Zeilenzahl. Das Maximum hängt von der Pflanze ab,\ndie Anordnung überschreitet aber nie 9 Felder pro Seite.",
        ["settings.columns_tooltip"] =
            "Anfängliche Spaltenzahl. Das Maximum hängt von der Pflanze ab,\ndie Anordnung überschreitet aber nie 9 Felder pro Seite.",
        ["settings.opacity_tooltip"] =
            "Kompatibilitätsoption für Geometric Placement.\nÄndert nur die Deckkraft des GP-Rasters um die Vorschau\ndes Pflanzassistenten. Globale Einstellungen von Geometric Placement,\nPflanzenvorschauen und Feldränder bleiben unverändert.",

        ["failure.rate_limited"] =
            "Warte einen Moment und versuche es erneut.",
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
            "Die Anordnung darf höchstens 9 x 9 Felder abdecken.",
        ["failure.invalid"] = "Der Server hat die Pflanzanfrage abgelehnt.",
        ["failure.internal"] =
            "Gruppenpflanzung fehlgeschlagen. Prüfe das Serverprotokoll.",
        ["failure.plantable_unavailable"] =
            "Der Pflanzcode dieses Gegenstands ist fehlgeschlagen. Der aktuelle Durchlauf wurde gestoppt.",
        ["failure.generic"] =
            "Die Gruppenpflanzung konnte nicht abgeschlossen werden.",
        ["undo.success"] =
            "Die letzte Gruppenpflanzung wurde rückgängig gemacht.",
        ["undo.unavailable"] =
            "Es gibt keine aktuelle Pflanzung zum Rückgängigmachen.",
        ["undo.expired"] =
            "Das 5-Sekunden-Zeitfenster zum Rückgängigmachen ist abgelaufen.",
        ["undo.changed"] =
            "Eine Pflanze fehlt oder wurde verschoben; der Vorgang wurde nicht rückgängig gemacht.",
        ["undo.unsupported"] =
            "Dieses Pflanzergebnis kann nicht sicher rückgängig gemacht werden.",
        ["undo.busy"] =
            "Warte, bis die aktuelle Gruppenpflanzung abgeschlossen ist.",
        ["undo.internal"] =
            "Die Pflanzung konnte nicht sicher rückgängig gemacht werden. Prüfe das Serverprotokoll.",

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
        ["settings.grid_opacity"] = "GP グリッドの不透明度",
        ["settings.rows_tooltip"] =
            "植え付けモード開始時の行数です。上限は植物に応じて変わりますが、\n配置範囲は各辺 9 タイルを超えません。",
        ["settings.columns_tooltip"] =
            "植え付けモード開始時の列数です。上限は植物に応じて変わりますが、\n配置範囲は各辺 9 タイルを超えません。",
        ["settings.opacity_tooltip"] =
            "Geometric Placement との互換設定です。\n植え付けアシスタントのプレビュー周囲に表示される\nGP グリッドの不透明度だけを変更します。\nGeometric Placement の全体設定、植物プレビュー、\nタイル境界には影響しません。",

        ["failure.rate_limited"] = "少し待ってから、もう一度お試しください。",
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
            "配置範囲は 9 x 9 タイル以内にしてください。",
        ["failure.invalid"] = "サーバーが植え付け要求を拒否しました。",
        ["failure.internal"] =
            "一括植え付けに失敗しました。サーバーログを確認してください。",
        ["failure.plantable_unavailable"] =
            "このアイテムの植え付け処理でエラーが発生したため、現在の一括処理を停止しました。",
        ["failure.generic"] = "一括植え付けを完了できませんでした。",
        ["undo.success"] = "直前の一括植え付けを元に戻しました。",
        ["undo.unavailable"] =
            "元に戻せる直前の植え付けはありません。",
        ["undo.expired"] =
            "5 秒間の取り消し受付時間が終了しました。",
        ["undo.changed"] =
            "植物が消失または移動したため、一括処理を元に戻しませんでした。",
        ["undo.unsupported"] =
            "この植え付け結果は安全に元に戻せません。",
        ["undo.busy"] =
            "現在の一括植え付けが完了するまでお待ちください。",
        ["undo.internal"] =
            "植え付けを安全に元に戻せませんでした。サーバーログを確認してください。",

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
        ["settings.grid_opacity"] = "GP 그리드 불투명도",
        ["settings.rows_tooltip"] =
            "심기 모드를 시작할 때 사용할 행 수입니다. 최대값은 식물에 따라 달라지지만,\n배치는 각 방향으로 9 타일을 넘지 않습니다.",
        ["settings.columns_tooltip"] =
            "심기 모드를 시작할 때 사용할 열 수입니다. 최대값은 식물에 따라 달라지지만,\n배치는 각 방향으로 9 타일을 넘지 않습니다.",
        ["settings.opacity_tooltip"] =
            "Geometric Placement 호환 옵션입니다.\n심기 도우미 미리보기 주변에 표시되는 GP 그리드의\n불투명도만 변경합니다. Geometric Placement의 전역 설정,\n식물 미리보기 또는 타일 경계에는 영향을 주지 않습니다.",

        ["failure.rate_limited"] =
            "잠시 기다린 뒤 다시 시도해 주세요.",
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
            "배치는 9 x 9 타일을 초과할 수 없습니다.",
        ["failure.invalid"] = "서버가 심기 요청을 거부했습니다.",
        ["failure.internal"] =
            "일괄 심기에 실패했습니다. 서버 로그를 확인하세요.",
        ["failure.plantable_unavailable"] =
            "이 아이템의 심기 코드에서 오류가 발생해 현재 일괄 작업을 중단했습니다.",
        ["failure.generic"] = "일괄 심기를 완료하지 못했습니다.",
        ["undo.success"] = "이전 일괄 심기를 되돌렸습니다.",
        ["undo.unavailable"] =
            "되돌릴 수 있는 최근 심기 작업이 없습니다.",
        ["undo.expired"] =
            "5초 되돌리기 시간이 끝났습니다.",
        ["undo.changed"] =
            "식물이 사라졌거나 이동하여 일괄 작업을 되돌리지 않았습니다.",
        ["undo.unsupported"] =
            "이 심기 결과는 안전한 되돌리기를 지원하지 않습니다.",
        ["undo.busy"] =
            "현재 일괄 심기가 끝날 때까지 기다려 주세요.",
        ["undo.internal"] =
            "심기 작업을 안전하게 되돌리지 못했습니다. 서버 로그를 확인하세요.",

        ["opacity.hidden"] = "숨김",
        ["opacity.very_low"] = "매우 낮음",
        ["opacity.low_recommended"] = "낮음 (권장)",
        ["opacity.medium"] = "중간",
        ["opacity.high"] = "높음",
        ["opacity.full"] = "원래 강도",
    },
}

return Language.Create(STRINGS, "mosswork.planting_assistant")
