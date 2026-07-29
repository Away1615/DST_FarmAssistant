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

local TRANSLATIONS = {
    en = {
        name = "Planting Assistant",
        description = [[
Server-authoritative batch planting assistant.

Ctrl + Mouse Wheel: adjust rows
Alt + Mouse Wheel: adjust columns
Right Mouse Button: confirm

Previews the layout, moves the character into range, plays one action, and plants valid positions while skipping blocked points.
Supports inventory items that use DST's native PLANT deploy mode. Each layout side is limited to nine turf tiles.
Requires Mosswork.
]],
    },
    zh = {
        name = "种植助手",
        description = [[
服务端权威的批量种植助手。

Ctrl + 鼠标滚轮：调整行数
Alt + 鼠标滚轮：调整列数
鼠标右键：确认

预览阵列，让角色实际移动到范围内，只播放一次动作，并跳过阻挡点种下其他有效位置。
支持物品栏中使用 DST 原生 PLANT 部署模式的种植物。阵列每边最多覆盖 9 块地皮。
依赖 Mosswork。
]],
    },
    es = {
        name = "Asistente de plantación",
        description = [[
Asistente de plantación en lote controlado por el servidor.

Ctrl + Rueda del ratón: ajustar filas
Alt + Rueda del ratón: ajustar columnas
Botón derecho: confirmar

Previsualiza la distribución, acerca al personaje, reproduce una acción y planta las posiciones válidas omitiendo los puntos bloqueados.
Admite objetos del inventario con el modo de despliegue PLANT nativo de DST. Cada lado está limitado a nueve parcelas.
Requiere Mosswork.
]],
    },
    ru = {
        name = "Помощник по посадке",
        description = [[
Серверный помощник для массовой посадки.

Ctrl + Колесо мыши: изменить число строк
Alt + Колесо мыши: изменить число столбцов
Правая кнопка мыши: подтвердить

Показывает раскладку, подводит персонажа, воспроизводит одно действие и засаживает допустимые точки, пропуская препятствия.
Поддерживает предметы инвентаря с режимом размещения PLANT из DST. Каждая сторона ограничена девятью участками.
Требуется Mosswork.
]],
    },
    fr = {
        name = "Assistant de plantation",
        description = [[
Assistant de plantation groupée contrôlé par le serveur.

Ctrl + Molette : régler les lignes
Alt + Molette : régler les colonnes
Bouton droit : confirmer

Affiche la disposition, déplace le personnage à portée, joue une seule action et plante les positions valides en ignorant les points bloqués.
Prend en charge les objets d’inventaire utilisant le mode de déploiement PLANT de DST. Chaque côté est limité à neuf parcelles.
Nécessite Mosswork.
]],
    },
    de = {
        name = "Pflanzassistent",
        description = [[
Servergesteuerter Assistent für Gruppenpflanzungen.

Strg + Mausrad: Zeilen anpassen
Alt + Mausrad: Spalten anpassen
Rechte Maustaste: bestätigen

Zeigt die Anordnung, bewegt die Figur in Reichweite, spielt eine Aktion ab und bepflanzt gültige Positionen unter Auslassung blockierter Punkte.
Unterstützt Inventargegenstände mit DSTs nativem PLANT-Platzierungsmodus. Jede Seite ist auf neun Felder begrenzt.
Benötigt Mosswork.
]],
    },
    ja = {
        name = "植え付けアシスタント",
        description = [[
サーバー管理の一括植え付けアシスタントです。

Ctrl + マウスホイール：行数を変更
Alt + マウスホイール：列数を変更
右クリック：確定

配置をプレビューし、キャラクターを範囲内へ移動させ、1 回の動作で障害物を避けながら有効な位置へ植え付けます。
DST 標準の PLANT 配置モードを使う所持品に対応します。配置範囲は各辺 9 タイルまでです。
Mosswork が必要です。
]],
    },
    ko = {
        name = "심기 도우미",
        description = [[
서버 권한 방식의 일괄 심기 도우미입니다.

Ctrl + 마우스 휠: 행 수 조절
Alt + 마우스 휠: 열 수 조절
마우스 오른쪽 버튼: 확인

배치를 미리 보여 주고 캐릭터를 범위 안으로 이동시킨 뒤, 한 번의 동작으로 막힌 지점을 건너뛰며 유효한 위치에 심습니다.
DST 기본 PLANT 배치 모드를 사용하는 소지품을 지원합니다. 배치는 각 방향으로 9 타일까지입니다.
Mosswork가 필요합니다.
]],
    },
}

local language = LANGUAGE_BY_LOCALE[locale] or "en"
local selected = TRANSLATIONS[language]

name = selected.name
description = selected.description
author = "Nooobad"
version = "0.1.0"

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
    "planting",
    "utility",
}
