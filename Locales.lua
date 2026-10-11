local _, ns = ...

local locales = {}

locales.enUS = {
	ON = "|cff40ff40ON|r",
	OFF = "|cffff4040OFF|r",
	STATUS = "Screenshots on honorable kills: %s",
	SHOT_SAVED = "Honorable kill%s — screenshot #%d saved.",
	SHOT_SAVED_VICTIM = ": |cffffd100%s|r",
	DELAY_SET = "Screenshot delay: %.2f sec.",
	KB_ONLY_STATUS = "Only my killing blows: %s",
	SOUND_STATUS = "Shutter sound: %s",
	CHAT_STATUS = "Chat message: %s",
	KB_UNAVAILABLE = "(not detectable on this client — every honorable kill counts)",
	TOTAL = "Screenshots taken so far: %d",
	LANGUAGE_SET = "Language: %s",

	HELP = {
		"Commands (/honorsnap or /hsnap):",
		"  |cffffd100/hsnap|r — open settings",
		"  |cffffd100/hsnap on|r | |cffffd100off|r | |cffffd100toggle|r — enable or disable",
		"  |cffffd100/hsnap kb|r — toggle \"only my killing blows\"",
		"  |cffffd100/hsnap delay <0-3>|r — delay before the screenshot, in seconds",
		"  |cffffd100/hsnap sound|r — toggle shutter sound",
		"  |cffffd100/hsnap chat|r — toggle chat message",
		"  |cffffd100/hsnap lang <auto|en|uk|ru>|r — interface language",
		"  |cffffd100/hsnap status|r — show current settings",
	},

	OPT_SUBTITLE = "Automatically takes a screenshot when you get an honorable kill (the enemy was not gray to you) in the open world. Battlegrounds, arenas, duels, dungeons and raids are ignored.",
	OPT_ENABLE = "Enable HonorSnap",
	OPT_ENABLE_TIP = "Take a screenshot on every honorable kill in the open world.",
	OPT_KB_ONLY = "Only my killing blows",
	OPT_KB_ONLY_TIP = "Take a screenshot only when you (or your pet) landed the killing blow. Turn this off to count any honorable kill, including kills made together with your group.",
	OPT_SOUND = "Play shutter sound",
	OPT_SOUND_TIP = "Play a camera shutter sound when the screenshot is taken.",
	OPT_CHAT = "Print a chat message",
	OPT_CHAT_TIP = "Print the victim's name and screenshot number in chat after saving.",
	OPT_DELAY = "Delay before screenshot",
	OPT_DELAY_VALUE = "%.2f sec",
	OPT_LANGUAGE = "Language",
	OPT_LANGUAGE_AUTO = "Auto (game client)",
	OPT_FOLDER = "Screenshots are saved to the |cffffd100Screenshots|r folder next to your game's Interface folder.",
	OPT_RESET_COUNTER = "Reset counter",
	OPT_RESET_COUNTER_CONFIRM = "Reset the screenshot counter to 0?\nScreenshots already saved are not deleted.",
	OPT_RESET_SETTINGS = "Reset settings",
	OPT_RESET_SETTINGS_CONFIRM = "Reset all HonorSnap settings to their defaults? The screenshot counter is reset too.\nScreenshots already saved are not deleted.",

	TT_LEFT = "|cffffd100Left-click:|r enable / disable",
	TT_RIGHT = "|cffffd100Right-click:|r settings",
}

locales.ukUA = {
	ON = "|cff40ff40УВІМК|r",
	OFF = "|cffff4040ВИМК|r",
	STATUS = "Скриншоти при почесних вбивствах: %s",
	SHOT_SAVED = "Почесне вбивство %s — скриншот #%d збережено.",
	SHOT_SAVED_VICTIM = ": |cffffd100%s|r",
	DELAY_SET = "Затримка скриншота: %.2f с.",
	KB_ONLY_STATUS = "Лише мої добивання: %s",
	SOUND_STATUS = "Звук затвора: %s",
	CHAT_STATUS = "Повідомлення в чат: %s",
	KB_UNAVAILABLE = "(на цьому клієнті не визначається — зараховується будь-яке почесне вбивство)",
	TOTAL = "Зроблено скриншотів: %d",
	LANGUAGE_SET = "Мова: %s",

	HELP = {
		"Команди (/honorsnap або /hsnap):",
		"  |cffffd100/hsnap|r — відкрити налаштування",
		"  |cffffd100/hsnap on|r | |cffffd100off|r | |cffffd100toggle|r — увімкнути або вимкнути",
		"  |cffffd100/hsnap kb|r — перемкнути «лише мої добивання»",
		"  |cffffd100/hsnap delay <0-3>|r — затримка перед скриншотом у секундах",
		"  |cffffd100/hsnap sound|r — перемкнути звук затвора",
		"  |cffffd100/hsnap chat|r — перемкнути повідомлення в чат",
		"  |cffffd100/hsnap lang <auto|en|uk|ru>|r — мова інтерфейсу",
		"  |cffffd100/hsnap status|r — показати поточні налаштування",
	},

	OPT_SUBTITLE = "Автоматично робить скриншот, коли ви отримуєте почесне вбивство (противник не був для вас сірим) у відкритому світі. Поля бою, арени, дуелі, підземелля та рейди ігноруються.",
	OPT_ENABLE = "Увімкнути HonorSnap",
	OPT_ENABLE_TIP = "Робити скриншот при кожному почесному вбивстві у відкритому світі.",
	OPT_KB_ONLY = "Лише мої добивання",
	OPT_KB_ONLY_TIP = "Робити скриншот лише тоді, коли останній удар завдали ви (або ваш вихованець). Вимкніть, щоб зараховувалося будь-яке почесне вбивство, зокрема зроблене разом із групою.",
	OPT_SOUND = "Звук затвора",
	OPT_SOUND_TIP = "Відтворювати звук затвора фотоапарата під час скриншота.",
	OPT_CHAT = "Повідомлення в чат",
	OPT_CHAT_TIP = "Після збереження писати в чат ім'я противника та номер скриншота.",
	OPT_DELAY = "Затримка перед скриншотом",
	OPT_DELAY_VALUE = "%.2f с",
	OPT_LANGUAGE = "Мова",
	OPT_LANGUAGE_AUTO = "Авто (мова клієнта)",
	OPT_FOLDER = "Скриншоти зберігаються в папку |cffffd100Screenshots|r поруч із папкою Interface вашої гри.",
	OPT_RESET_COUNTER = "Скинути лічильник",
	OPT_RESET_COUNTER_CONFIRM = "Скинути лічильник скриншотів до 0?\nВже збережені скриншоти не видаляються.",
	OPT_RESET_SETTINGS = "Скинути налаштування",
	OPT_RESET_SETTINGS_CONFIRM = "Скинути всі налаштування HonorSnap до стандартних? Лічильник скриншотів теж буде скинуто.\nВже збережені скриншоти не видаляються.",

	TT_LEFT = "|cffffd100ЛКМ:|r увімкнути / вимкнути",
	TT_RIGHT = "|cffffd100ПКМ:|r налаштування",
}

locales.ruRU = {
	ON = "|cff40ff40ВКЛ|r",
	OFF = "|cffff4040ВЫКЛ|r",
	STATUS = "Скриншоты при почетных убийствах: %s",
	SHOT_SAVED = "Почетное убийство%s — скриншот #%d сохранен.",
	SHOT_SAVED_VICTIM = ": |cffffd100%s|r",
	DELAY_SET = "Задержка скриншота: %.2f сек.",
	KB_ONLY_STATUS = "Только мои добивания: %s",
	SOUND_STATUS = "Звук затвора: %s",
	CHAT_STATUS = "Сообщение в чат: %s",
	KB_UNAVAILABLE = "(на этом клиенте не определяется — засчитывается любое почетное убийство)",
	TOTAL = "Сделано скриншотов: %d",
	LANGUAGE_SET = "Язык: %s",

	HELP = {
		"Команды (/honorsnap или /hsnap):",
		"  |cffffd100/hsnap|r — открыть настройки",
		"  |cffffd100/hsnap on|r | |cffffd100off|r | |cffffd100toggle|r — включить или выключить",
		"  |cffffd100/hsnap kb|r — переключить «только мои добивания»",
		"  |cffffd100/hsnap delay <0-3>|r — задержка перед скриншотом в секундах",
		"  |cffffd100/hsnap sound|r — переключить звук затвора",
		"  |cffffd100/hsnap chat|r — переключить сообщение в чат",
		"  |cffffd100/hsnap lang <auto|en|uk|ru>|r — язык интерфейса",
		"  |cffffd100/hsnap status|r — показать текущие настройки",
	},

	OPT_SUBTITLE = "Автоматически делает скриншот, когда вы получаете почетное убийство (противник не был для вас серым) в открытом мире. Поля боя, арены, дуэли, подземелья и рейды игнорируются.",
	OPT_ENABLE = "Включить HonorSnap",
	OPT_ENABLE_TIP = "Делать скриншот при каждом почетном убийстве в открытом мире.",
	OPT_KB_ONLY = "Только мои добивания",
	OPT_KB_ONLY_TIP = "Делать скриншот только когда последний удар нанесли вы (или ваш питомец). Выключите, чтобы засчитывалось любое почетное убийство, в том числе сделанное вместе с группой.",
	OPT_SOUND = "Звук затвора",
	OPT_SOUND_TIP = "Проигрывать звук затвора фотоаппарата при скриншоте.",
	OPT_CHAT = "Сообщение в чат",
	OPT_CHAT_TIP = "После сохранения писать в чат имя противника и номер скриншота.",
	OPT_DELAY = "Задержка перед скриншотом",
	OPT_DELAY_VALUE = "%.2f сек",
	OPT_LANGUAGE = "Язык",
	OPT_LANGUAGE_AUTO = "Авто (язык клиента)",
	OPT_FOLDER = "Скриншоты сохраняются в папку |cffffd100Screenshots|r рядом с папкой Interface вашей игры.",
	OPT_RESET_COUNTER = "Сбросить счетчик",
	OPT_RESET_COUNTER_CONFIRM = "Сбросить счетчик скриншотов до 0?\nУже сохраненные скриншоты не удаляются.",
	OPT_RESET_SETTINGS = "Сбросить настройки",
	OPT_RESET_SETTINGS_CONFIRM = "Сбросить все настройки HonorSnap на стандартные? Счетчик скриншотов тоже будет сброшен.\nУже сохраненные скриншоты не удаляются.",

	TT_LEFT = "|cffffd100ЛКМ:|r включить / выключить",
	TT_RIGHT = "|cffffd100ПКМ:|r настройки",
}

-- Selectable languages, in the order shown in the options. Names are written in
-- their own language so they read the same whatever language is active.
ns.LANGUAGES = {
	{ code = "auto" },
	{ code = "enUS", short = "en", name = "English" },
	{ code = "ukUA", short = "uk", name = "Українська" },
	{ code = "ruRU", short = "ru", name = "Русский" },
}

local current = locales.enUS

local function IsMissing(value)
	return value == nil or value == "" or (type(value) == "table" and #value == 0)
end

ns.L = setmetatable({}, {
	__index = function(_, key)
		local value = current[key]
		if IsMissing(value) then value = locales.enUS[key] end
		if value == nil then return key end
		return value
	end,
})

-- There is no Ukrainian WoW client, so "auto" means Russian on ruRU clients and English otherwise.
function ns.ResolveLocale(code)
	if code == "auto" or not locales[code] then
		return GetLocale() == "ruRU" and "ruRU" or "enUS"
	end
	return code
end

function ns.ApplyLocale(code)
	current = locales[ns.ResolveLocale(code)]
end

function ns.GetLanguageName(code)
	for _, lang in ipairs(ns.LANGUAGES) do
		if lang.code == code then
			return lang.name or ns.L.OPT_LANGUAGE_AUTO
		end
	end
	return code
end
