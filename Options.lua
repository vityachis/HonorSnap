local addonName, ns = ...
local L = ns.L

local panel, category
local controls = {}

local LEFT_X = 16          -- left column
local RIGHT_X = 330        -- right column
local NOTE_HEIGHT = 12     -- one line of small text under a checkbox

-- Anything with a Refresh method is updated when the panel opens, a setting
-- changes or the language is switched.
local function AddControl(control)
	controls[#controls + 1] = control
	return control
end

local function LocalizedText(fontString, key)
	AddControl({ Refresh = function() fontString:SetText(L[key]) end })
	return fontString
end

local function ShowTooltip(owner, title, text)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:SetText(title, 1, 1, 1)
	GameTooltip:AddLine(text, nil, nil, nil, true)
	GameTooltip:Show()
end

local function CreateCheckbox(parent, anchor, labelKey, tooltipKey, key, onClick)
	local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	check:SetSize(26, 26)
	check:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)

	local text = check:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	text:SetPoint("LEFT", check, "RIGHT", 4, 1)

	check:SetScript("OnClick", function(self)
		local value = self:GetChecked() and true or false
		if onClick then
			onClick(value)
		else
			ns.db[key] = value
		end
	end)
	check:SetScript("OnEnter", function(self)
		ShowTooltip(self, L[labelKey], check.GetTooltip and check:GetTooltip() or L[tooltipKey])
	end)
	check:SetScript("OnLeave", GameTooltip_Hide)

	check.Refresh = function(self)
		text:SetText(L[labelKey])
		self:SetHitRectInsets(0, -text:GetStringWidth() - 8, 0, 0)
		self:SetChecked(ns.db[key])
		-- IsLocked: the setting is overridden by another one, so it can't be changed.
		local locked = self.IsLocked and self:IsLocked()
		self:SetEnabled(not locked)
		text:SetFontObject(locked and "GameFontDisable" or "GameFontHighlight")
	end
	return AddControl(check)
end

-- Small gray text under a checkbox label. The next control must leave NOTE_HEIGHT for it.
local function AddNote(check, key)
	local note = LocalizedText(check:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall"), key)
	note:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 30, 4)
	return note
end

local function CreateHeader(parent, key)
	return LocalizedText(parent:CreateFontString(nil, "ARTWORK", "GameFontNormal"), key)
end

local function CreateSmallButton(parent, text, width)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width or 24, 22)
	button:SetText(text)
	return button
end

-- "[<] value [>]" control, used for the delay and the language.
local function CreateStepper(parent, anchor, labelKey, valueWidth, getText, onPrev, onNext)
	local label = LocalizedText(parent:CreateFontString(nil, "ARTWORK", "GameFontNormal"), labelKey)
	label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -18)

	local prev = CreateSmallButton(parent, "<")
	prev:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6)
	prev:SetScript("OnClick", onPrev)

	local value = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	value:SetPoint("LEFT", prev, "RIGHT", 6, 0)
	value:SetWidth(valueWidth)

	local nextButton = CreateSmallButton(parent, ">")
	nextButton:SetPoint("LEFT", value, "RIGHT", 6, 0)
	nextButton:SetScript("OnClick", onNext)

	AddControl({ Refresh = function() value:SetText(getText()) end })
	return prev
end

local function EmoteChoices()
	local choices = { "" }
	for _, token in ipairs(ns.EMOTES) do choices[#choices + 1] = token end
	return choices
end

-- Every current client has the new menu system; the old dropdown is only a fallback.
local function CreateEmoteDropdown(parent)
	local ok, dropdown = pcall(CreateFrame, "DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
	if ok and dropdown and dropdown.SetupMenu then
		dropdown:SetWidth(200)
		local function IsSelected(token) return ns.db.emote == token end
		local function Select(token) ns.SetEmote(token) end
		dropdown:SetupMenu(function(_, root)
			for _, token in ipairs(EmoteChoices()) do
				root:CreateRadio(ns.GetEmoteName(token), IsSelected, Select, token)
			end
		end)
		dropdown.Refresh = function(self) self:GenerateMenu() end
		return AddControl(dropdown), 0
	end

	dropdown = CreateFrame("Frame", "HonorSnapEmoteDropdown", parent, "UIDropDownMenuTemplate")
	UIDropDownMenu_SetWidth(dropdown, 180)
	UIDropDownMenu_Initialize(dropdown, function()
		for _, token in ipairs(EmoteChoices()) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = ns.GetEmoteName(token)
			info.arg1 = token
			info.checked = ns.db.emote == token
			info.func = function(_, value) ns.SetEmote(value) end
			UIDropDownMenu_AddButton(info)
		end
	end)
	dropdown.Refresh = function(self) UIDropDownMenu_SetText(self, ns.GetEmoteName(ns.db.emote)) end
	-- The old template has empty space on its left.
	return AddControl(dropdown), -16
end

-- The dialog text is set right before showing, so it follows the current language.
local function Confirm(name, textKey, onAccept)
	StaticPopupDialogs[name] = StaticPopupDialogs[name] or {
		button1 = YES,
		button2 = NO,
		OnAccept = onAccept,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
	StaticPopupDialogs[name].text = L[textKey]
	StaticPopup_Show(name)
end

local function StepLanguage(step)
	local index = 1
	for i, lang in ipairs(ns.LANGUAGES) do
		if lang.code == ns.db.locale then index = i end
	end
	index = (index - 1 + step) % #ns.LANGUAGES + 1
	ns.SetLocale(ns.LANGUAGES[index].code)
end

local function BuildPanel()
	panel = CreateFrame("Frame")
	panel.name = "HonorSnap"

	local icon = panel:CreateTexture(nil, "ARTWORK")
	icon:SetSize(40, 40)
	icon:SetPoint("TOPLEFT", LEFT_X, -16)
	icon:SetTexture("Interface\\AddOns\\HonorSnap\\Media\\icon")

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -2)
	title:SetText("|cffffd100Honor|r|cffff4040Snap|r")

	local version = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	version:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", 6, 1)
	local getMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
	local versionText = getMetadata and getMetadata(addonName, "Version") or ""
	-- The packager replaces @project-version@ with the git tag; a plain git checkout keeps the token.
	if versionText:find("^@") then versionText = "dev" end
	version:SetText(versionText:find("^v") and versionText or "v" .. versionText)

	local subtitle = LocalizedText(panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall"), "OPT_SUBTITLE")
	subtitle:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -10)
	subtitle:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
	subtitle:SetJustifyH("LEFT")

	-- Left column: what happens on a kill.
	local enable = CreateCheckbox(panel, subtitle, "OPT_ENABLE", "OPT_ENABLE_TIP", "enabled", function(value)
		ns.SetEnabled(value)
	end)
	enable:ClearAllPoints()
	enable:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", -2, -14)

	local kbOnly = CreateCheckbox(panel, enable, "OPT_KB_ONLY", "OPT_KB_ONLY_TIP", "killingBlowOnly")
	function kbOnly:GetTooltip()
		if ns.canDetectKillingBlow then return L.OPT_KB_ONLY_TIP end
		return L.OPT_KB_ONLY_TIP .. "\n\n|cffff8080" .. L.KB_UNAVAILABLE .. "|r"
	end

	local hideUI = CreateCheckbox(panel, kbOnly, "OPT_HIDE_UI", "OPT_HIDE_UI_TIP", "hideUI")
	AddNote(hideUI, "OPT_HIDE_UI_NOTE")

	local sound = CreateCheckbox(panel, hideUI, "OPT_SOUND", "OPT_SOUND_TIP", "sound")
	sound:SetPoint("TOPLEFT", hideUI, "BOTTOMLEFT", 0, -8 - NOTE_HEIGHT)
	function sound:IsLocked() return ns.db.emote ~= "" end
	function sound:GetTooltip()
		if not self:IsLocked() then return L.OPT_SOUND_TIP end
		return L.OPT_SOUND_TIP .. "\n\n|cffff8080" .. L.OPT_SOUND_LOCKED .. "|r"
	end

	local emoteLabel = CreateHeader(panel, "OPT_EMOTE")
	emoteLabel:SetPoint("TOPLEFT", sound, "BOTTOMLEFT", 4, -14)
	local emote, emoteX = CreateEmoteDropdown(panel)
	emote:SetPoint("TOPLEFT", emoteLabel, "BOTTOMLEFT", emoteX, -6)

	-- Right column: chat messages, delay and language.
	local messages = CreateHeader(panel, "OPT_MESSAGES")
	messages:SetPoint("TOPLEFT", enable, "TOPLEFT", RIGHT_X - LEFT_X + 2, -6)

	local msgOwn = CreateCheckbox(panel, messages, "OPT_MSG_OWN", "OPT_MSG_OWN_TIP", "msgOwnKills")
	msgOwn:SetPoint("TOPLEFT", messages, "BOTTOMLEFT", -4, -6)
	local msgGroup = CreateCheckbox(panel, msgOwn, "OPT_MSG_GROUP", "OPT_MSG_GROUP_TIP", "msgGroupKills")
	local msgDeath = CreateCheckbox(panel, msgGroup, "OPT_MSG_DEATH", "OPT_MSG_DEATH_TIP", "msgDeaths")

	local delayAnchor = CreateFrame("Frame", nil, panel)
	delayAnchor:SetSize(1, 1)
	delayAnchor:SetPoint("TOPLEFT", msgDeath, "BOTTOMLEFT", 4, 0)
	local delay = CreateStepper(panel, delayAnchor, "OPT_DELAY", 70,
		function() return L.OPT_DELAY_VALUE:format(ns.db.delay) end,
		function() ns.SetDelay(ns.db.delay - 0.25) end,
		function() ns.SetDelay(ns.db.delay + 0.25) end)

	local language = CreateStepper(panel, delay, "OPT_LANGUAGE", 150,
		function() return ns.GetLanguageName(ns.db.locale) end,
		function() StepLanguage(-1) end,
		function() StepLanguage(1) end)

	-- Bottom, full width: counter, folder and debugging. The right column is the
	-- taller one, so this part goes under it, moved back to the left edge.
	local resetCounter = CreateSmallButton(panel, "", 160)
	resetCounter:SetPoint("TOPLEFT", language, "BOTTOMLEFT", LEFT_X - RIGHT_X, -24)
	resetCounter:SetScript("OnClick", function()
		Confirm("HONORSNAP_RESET_COUNTER", "OPT_RESET_COUNTER_CONFIRM", ns.ResetCounter)
	end)
	AddControl({ Refresh = function() resetCounter:SetText(L.OPT_RESET_COUNTER) end })

	local resetSettings = CreateSmallButton(panel, "", 160)
	resetSettings:SetPoint("LEFT", resetCounter, "RIGHT", 8, 0)
	resetSettings:SetScript("OnClick", function()
		Confirm("HONORSNAP_RESET_SETTINGS", "OPT_RESET_SETTINGS_CONFIRM", ns.ResetSettings)
	end)
	AddControl({ Refresh = function() resetSettings:SetText(L.OPT_RESET_SETTINGS) end })

	local total = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	total:SetPoint("TOPLEFT", resetCounter, "BOTTOMLEFT", 2, -10)
	AddControl({ Refresh = function() total:SetText(ns.GetTotalText()) end })

	local folder = LocalizedText(panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall"), "OPT_FOLDER")
	folder:SetPoint("TOPLEFT", total, "BOTTOMLEFT", 0, -8)
	folder:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
	folder:SetJustifyH("LEFT")

	local debugHeader = CreateHeader(panel, "OPT_DEBUG_HEADER")
	debugHeader:SetPoint("TOPLEFT", folder, "BOTTOMLEFT", 0, -20)
	local debug = CreateCheckbox(panel, debugHeader, "OPT_DEBUG", "OPT_DEBUG_TIP", "debug")
	debug:SetPoint("TOPLEFT", debugHeader, "BOTTOMLEFT", -4, -6)
	AddNote(debug, "OPT_DEBUG_NOTE")

	panel:SetScript("OnShow", ns.RefreshOptions)
end

function ns.RefreshOptions()
	if not panel then return end
	for _, control in ipairs(controls) do
		control:Refresh()
	end
end

function ns.CreateOptions()
	BuildPanel()
	if Settings and Settings.RegisterCanvasLayoutCategory then
		category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
		Settings.RegisterAddOnCategory(category)
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
	end
end

function ns.OpenOptions()
	if category and Settings.OpenToCategory then
		Settings.OpenToCategory(category:GetID())
	elseif InterfaceOptionsFrame_OpenToCategory then
		-- Called twice: the first call may only open the frame on older clients.
		InterfaceOptionsFrame_OpenToCategory(panel)
		InterfaceOptionsFrame_OpenToCategory(panel)
	end
end
