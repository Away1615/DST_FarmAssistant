local LANGUAGE_BY_LOCALE = {
    zh = "zh",
    zhr = "zh",
    zht = "zh",
    es = "es",
    mex = "es",
    ru = "ru",
    fr = "fr",
    de = "de",
    ja = "ja",
    jp = "ja",
    ko = "ko",
    kr = "ko",
}

local DISPLAY_NAME = "丰耕助手 | Farm Assistant"

local TRANSLATIONS = {
    en = {
        name = DISPLAY_NAME,
        description = [[
Farm Assistant provides server-authoritative batch planting.

Ctrl + Mouse Wheel: adjust rows
Alt + Mouse Wheel: adjust columns
Right Mouse Button: confirm
Controller D-pad: adjust rows and columns
Controller Action / Alt Action: confirm / cancel

Previews the layout and skips blocked points. Choose one-action batch planting or sequential planting that automatically moves and performs one action per plant.
Supports inventory items that use DST's native PLANT deploy mode. Rows and columns are limited to nine plants each.
Requires Mosswork.
]],
    },
    zh = {
        name = DISPLAY_NAME,
        description = [[
Farm Assistant 提供服务端权威的批量种植功能。

Ctrl + 鼠标滚轮：调整行数
Alt + 鼠标滚轮：调整列数
鼠标右键：确认
手柄方向键：调整行数和列数
手柄交互键 / 次要交互键：确认 / 取消

预览阵列并跳过阻挡点。可选择一次动作完成整批种植，或让角色自动移动、每次动作种下一株。
支持物品栏中使用 DST 原生 PLANT 部署模式的种植物。阵列行数和列数各不超过 9 株。
依赖 Mosswork。
]],
    },
    es = {
        name = DISPLAY_NAME,
        description = [[
Farm Assistant ofrece plantación en lote controlada por el servidor.

Ctrl + Rueda del ratón: ajustar filas
Alt + Rueda del ratón: ajustar columnas
Botón derecho: confirmar
Cruceta del mando: ajustar filas y columnas
Acción / Acción secundaria: confirmar / cancelar

Previsualiza la distribución y omite los puntos bloqueados. Permite plantar todo con una acción o moverse automáticamente y plantar un objeto por acción.
Admite objetos del inventario con el modo de despliegue PLANT nativo de DST. Las filas y columnas están limitadas a nueve plantas cada una.
Requiere Mosswork.
]],
    },
    ru = {
        name = DISPLAY_NAME,
        description = [[
Farm Assistant обеспечивает серверную массовую посадку.

Ctrl + Колесо мыши: изменить число строк
Alt + Колесо мыши: изменить число столбцов
Правая кнопка мыши: подтвердить
Крестовина геймпада: изменить строки и столбцы
Действие / Альт. действие: подтвердить / отменить

Показывает схему и пропускает препятствия. Можно посадить всё одним действием или автоматически перемещаться и сажать по одному предмету за действие.
Поддерживает предметы инвентаря с режимом размещения PLANT из DST. Число растений в строках и столбцах ограничено девятью.
Требуется Mosswork.
]],
    },
    fr = {
        name = DISPLAY_NAME,
        description = [[
Farm Assistant propose une plantation groupée contrôlée par le serveur.

Ctrl + Molette : régler les lignes
Alt + Molette : régler les colonnes
Bouton droit : confirmer
Croix directionnelle : régler les lignes et les colonnes
Action / Action secondaire : confirmer / annuler

Affiche la disposition et ignore les points bloqués. Choisissez une action pour tout planter ou le déplacement automatique avec une action par plante.
Prend en charge les objets d’inventaire utilisant le mode de déploiement PLANT de DST. Les lignes et les colonnes sont limitées à neuf plantes chacune.
Nécessite Mosswork.
]],
    },
    de = {
        name = DISPLAY_NAME,
        description = [[
Farm Assistant bietet servergesteuerte Gruppenpflanzungen.

Strg + Mausrad: Zeilen anpassen
Alt + Mausrad: Spalten anpassen
Rechte Maustaste: bestätigen
Steuerkreuz: Zeilen und Spalten anpassen
Aktion / Alternative Aktion: bestätigen / abbrechen

Zeigt die Anordnung und überspringt blockierte Punkte. Wahlweise wird alles mit einer Aktion oder automatisch laufend Pflanze für Pflanze gesetzt.
Unterstützt Inventargegenstände mit DSTs nativem PLANT-Platzierungsmodus. Zeilen und Spalten sind jeweils auf neun Pflanzen begrenzt.
Benötigt Mosswork.
]],
    },
    ja = {
        name = DISPLAY_NAME,
        description = [[
Farm Assistant はサーバー管理の一括植え付け機能を提供します。

Ctrl + マウスホイール：行数を変更
Alt + マウスホイール：列数を変更
右クリック：確定
コントローラー方向キー：行数と列数を変更
アクション / サブアクション：確定 / キャンセル

配置をプレビューし、障害物を避けます。1 回の動作で一括植え付けするか、自動移動して1回の動作で1株ずつ植えるかを選べます。
DST 標準の PLANT 配置モードを使う所持品に対応します。行と列はそれぞれ最大 9 株です。
Mosswork が必要です。
]],
    },
    ko = {
        name = DISPLAY_NAME,
        description = [[
Farm Assistant는 서버 권한 방식의 일괄 심기 기능을 제공합니다.

Ctrl + 마우스 휠: 행 수 조절
Alt + 마우스 휠: 열 수 조절
마우스 오른쪽 버튼: 확인
컨트롤러 방향키: 행과 열 조절
동작 / 보조 동작: 확인 / 취소

배치를 미리 보여 주고 막힌 지점을 건너뜁니다. 한 번의 동작으로 일괄 심거나 자동 이동하며 동작마다 한 개씩 심을 수 있습니다.
DST 기본 PLANT 배치 모드를 사용하는 소지품을 지원합니다. 행과 열은 각각 최대 9개입니다.
Mosswork가 필요합니다.
]],
    },
}

local language = LANGUAGE_BY_LOCALE[locale] or "en"
local selected = TRANSLATIONS[language]

name = selected.name
description = selected.description
author = "Nooobad"
version = "0.5.0"

icon_atlas = "modicon.xml"
icon = "modicon.tex"

api_version = 10
dst_compatible = true
all_clients_require_mod = true
client_only_mod = false
priority = 0

mod_dependencies = {
    {
        workshop = "workshop-3773702573",
        ["Mosswork"] = false,
    },
}

server_filter_tags = {
    "farm",
    "planting",
    "utility",
}
