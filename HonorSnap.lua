local addonName, ns = ...
local L = ns.L

local HonorSnap = CreateFrame("Frame")
ns.addon = HonorSnap

local INTERFACE = select(4, GetBuildInfo())
-- Retail (12.x) and WoW Forever (16xxx, retail engine) have no combat log for addons,
-- but they do fire a dedicated PARTY_KILL event instead.
local IS_MODERN = INTERFACE >= 120000 or (INTERFACE >= 16000 and INTERFACE < 20000)

local SOUND_FILE = "Interface\\AddOns\\HonorSnap\\Media\\shutter.ogg"
local KB_WINDOW = 2.5      -- max seconds between the killing blow and the honor credit
local DEDUPE_WINDOW = 1.0  -- several signals for the same kill collapse into one screenshot
local WARMUP = 5           -- ignore stat updates right after login / loading screens
local DUEL_GRACE = 5       -- ignore kill signals for a few seconds after a duel ends

local defaults = {
	enabled = true,
	killingBlowOnly = true,
	delay = 0.5,
	sound = false,
	chat = false,
	locale = "auto",
	total = 0,
}

local db
local playerGUID
local readyAt = math.huge
local lastSessionHK
local honorAt, honorVictim
local killingBlowAt
local lastShotAt = 0
local pendingMessage
local inDuel = false
local duelEndedAt = -math.huge

ns.canDetectKillingBlow = false

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Honor|r|cffff4040Snap|r: " .. msg)
end
ns.Print = Print

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) or false
end

local function SafeName(unit)
	if not unit or IsSecret(unit) then return nil end
	local ok, name = pcall(UnitName, unit)
	if ok and name and not IsSecret(name) and name ~= "" then
		return name
	end
end

local function IsInActiveBattlefield()
	if UnitInBattleground and UnitInBattleground("player") then return true end
	if IsActiveBattlefieldArena and IsActiveBattlefieldArena() then return true end
	if C_PvP then
		if C_PvP.IsPVPMap and C_PvP.IsPVPMap() then return true end
		if C_PvP.IsInBrawl and C_PvP.IsInBrawl() then return true end
	end
	-- Also covers world battlefields such as Wintergrasp or Tol Barad while the battle is on.
	if GetMaxBattlefieldID and GetBattlefieldStatus then
		for i = 1, GetMaxBattlefieldID() do
			if GetBattlefieldStatus(i) == "active" then return true end
		end
	end
	return false
end

-- Real open-world kill: not in an instance, battleground, arena or duel.
local function IsOpenWorld()
	local inInstance, instanceType = IsInInstance()
	if IsSecret(inInstance) then return false end
	if inInstance or (instanceType ~= nil and instanceType ~= "none") then return false end
	if inDuel or GetTime() - duelEndedAt < DUEL_GRACE then return false end
	return not IsInActiveBattlefield()
end

local function GetSessionHK()
	if not GetPVPSessionStats then return nil end
	local ok, hk = pcall(GetPVPSessionStats)
	if ok and type(hk) == "number" and not IsSecret(hk) then
		return hk
	end
end

local function IsMyGUID(guid)
	if not guid or IsSecret(guid) then return false end
	if guid == playerGUID then return true end
	local petGUID = UnitGUID("pet")
	return petGUID ~= nil and not IsSecret(petGUID) and guid == petGUID
end

---------------------------------------------------------------------------
-- Screenshot
---------------------------------------------------------------------------

local function TakeShot(victim)
	C_Timer.After(db.delay, function()
		if db.sound then
			PlaySoundFile(SOUND_FILE, "Master")
		end
		db.total = db.total + 1
		if db.chat then
			pendingMessage = L.SHOT_SAVED:format(victim and L.SHOT_SAVED_VICTIM:format(victim) or "", db.total)
		end
		Screenshot()
	end)
end

local function TryFire()
	if not db.enabled or not honorAt then return end
	local now = GetTime()

	if db.killingBlowOnly and ns.canDetectKillingBlow then
		if not killingBlowAt or math.abs(honorAt - killingBlowAt) > KB_WINDOW then
			return
		end
	end

	local victim = honorVictim
	honorAt, honorVictim, killingBlowAt = nil, nil, nil

	if now - lastShotAt < DEDUPE_WINDOW then return end
	if not IsOpenWorld() then return end

	lastShotAt = now
	TakeShot(victim)
end

---------------------------------------------------------------------------
-- Kill signals
---------------------------------------------------------------------------

-- Honorable kill credit. Blizzard only awards it for enemies that were not gray,
-- which is exactly the "green or higher" condition.
local function OnHonorableKill(victim)
	honorAt = GetTime()
	honorVictim = victim or honorVictim
	TryFire()
	-- In killing-blow mode the PARTY_KILL can arrive a moment after the honor credit.
	if honorAt and db.killingBlowOnly then
		C_Timer.After(KB_WINDOW, function()
			if honorAt and GetTime() - honorAt >= KB_WINDOW then
				honorAt, honorVictim = nil, nil
			end
		end)
	end
end

local function OnKillingBlow()
	killingBlowAt = GetTime()
	if db.killingBlowOnly then
		TryFire()
	end
end

-- Returns true if the session honorable kill counter went up since the last check.
local function SessionHKIncreased()
	local hk = GetSessionHK()
	if not hk then return nil end
	local increased = lastSessionHK ~= nil and hk > lastSessionHK
	lastSessionHK = hk
	return increased
end

local events = {}

function events.ADDON_LOADED(name)
	if name ~= addonName then return end
	HonorSnapDB = HonorSnapDB or {}
	db = HonorSnapDB
	for key, value in pairs(defaults) do
		if db[key] == nil then db[key] = value end
	end
	ns.db = db
	ns.ApplyLocale(db.locale)
	HonorSnap:UnregisterEvent("ADDON_LOADED")
	ns.CreateOptions()
end

function events.PLAYER_ENTERING_WORLD()
	playerGUID = UnitGUID("player")
	readyAt = GetTime() + WARMUP
	lastSessionHK = GetSessionHK()
	honorAt, honorVictim, killingBlowAt = nil, nil, nil
	inDuel = false
end

function events.PLAYER_PVP_KILLS_CHANGED(unitTarget)
	if GetTime() < readyAt then
		lastSessionHK = GetSessionHK()
		return
	end
	local increased = SessionHKIncreased()
	-- unitTarget is only passed for an actual kill; otherwise trust the counter.
	if (unitTarget and not IsSecret(unitTarget)) or increased or increased == nil then
		OnHonorableKill(SafeName(unitTarget))
	end
end

-- Backup signal: some clients print the honor message before (or instead of)
-- updating the kill counter. Dishonorable kills share this event, so we only
-- trust it when the honorable kill counter actually went up.
function events.CHAT_MSG_COMBAT_HONOR_GAIN()
	if GetTime() < readyAt then return end
	C_Timer.After(0.3, function()
		if SessionHKIncreased() then
			OnHonorableKill()
		end
	end)
end

-- Retail / Forever: dedicated event, the combat log is not available to addons.
function events.PARTY_KILL(attackerGUID)
	if IsMyGUID(attackerGUID) then
		OnKillingBlow()
	end
end

-- Classic flavors: the combat log tells who landed the killing blow.
local PLAYER_FLAG = COMBATLOG_OBJECT_TYPE_PLAYER or 0x00000400
function events.COMBAT_LOG_EVENT_UNFILTERED()
	local _, subevent, _, sourceGUID, _, _, _, _, _, destFlags = CombatLogGetCurrentEventInfo()
	if subevent == "PARTY_KILL" and IsMyGUID(sourceGUID) and destFlags and bit.band(destFlags, PLAYER_FLAG) > 0 then
		OnKillingBlow()
	end
end

function events.SCREENSHOT_SUCCEEDED()
	if pendingMessage then
		Print(pendingMessage)
		pendingMessage = nil
	end
end

function events.SCREENSHOT_FAILED()
	pendingMessage = nil
end

-- Duels never give honor, but we also block screenshots during and right after one,
-- so a duel can never be mistaken for a real kill.
function events.DUEL_REQUESTED()
	inDuel = true
end
events.DUEL_INBOUNDS = events.DUEL_REQUESTED
events.DUEL_OUTOFBOUNDS = events.DUEL_REQUESTED

function events.DUEL_FINISHED()
	inDuel = false
	duelEndedAt = GetTime()
end

HonorSnap:SetScript("OnEvent", function(_, event, ...)
	events[event](...)
end)

local function TryRegister(event)
	return pcall(HonorSnap.RegisterEvent, HonorSnap, event)
end

for _, event in ipairs({
	"ADDON_LOADED",
	"PLAYER_ENTERING_WORLD",
	"PLAYER_PVP_KILLS_CHANGED",
	"CHAT_MSG_COMBAT_HONOR_GAIN",
	"SCREENSHOT_SUCCEEDED",
	"SCREENSHOT_FAILED",
	"DUEL_REQUESTED",
	"DUEL_INBOUNDS",
	"DUEL_OUTOFBOUNDS",
	"DUEL_FINISHED",
}) do
	TryRegister(event)
end

if IS_MODERN then
	ns.canDetectKillingBlow = TryRegister("PARTY_KILL")
elseif CombatLogGetCurrentEventInfo then
	ns.canDetectKillingBlow = TryRegister("COMBAT_LOG_EVENT_UNFILTERED")
end

---------------------------------------------------------------------------
-- Public API used by the options panel, slash commands and addon compartment
---------------------------------------------------------------------------

function ns.SetEnabled(value)
	db.enabled = value and true or false
	ns.RefreshOptions()
end

function ns.SetDelay(value)
	value = math.floor((tonumber(value) or defaults.delay) * 4 + 0.5) / 4
	db.delay = math.max(0, math.min(3, value))
	ns.RefreshOptions()
	return db.delay
end

function ns.SetLocale(code)
	db.locale = code
	ns.ApplyLocale(code)
	ns.RefreshOptions()
end

function ns.ResetCounter()
	db.total = 0
	ns.RefreshOptions()
end

function ns.ResetSettings()
	for key, value in pairs(defaults) do
		db[key] = value
	end
	ns.ApplyLocale(db.locale)
	ns.RefreshOptions()
end

local function OnOff(value)
	return value and L.ON or L.OFF
end

local function KillingBlowStatus()
	local msg = L.KB_ONLY_STATUS:format(OnOff(db.killingBlowOnly))
	if not ns.canDetectKillingBlow then msg = msg .. " " .. L.KB_UNAVAILABLE end
	return msg
end

local function PrintHelp()
	for _, line in ipairs(L.HELP) do Print(line) end
end

local function PrintStatus()
	Print(L.STATUS:format(OnOff(db.enabled)))
	Print(KillingBlowStatus())
	Print(L.DELAY_SET:format(db.delay))
	Print(L.SOUND_STATUS:format(OnOff(db.sound)))
	Print(L.CHAT_STATUS:format(OnOff(db.chat)))
	Print(L.LANGUAGE_SET:format(ns.GetLanguageName(db.locale)))
	Print(L.TOTAL:format(db.total))
end

SLASH_HONORSNAP1 = "/honorsnap"
SLASH_HONORSNAP2 = "/hsnap"
SlashCmdList.HONORSNAP = function(input)
	local cmd, arg = strtrim(input or ""):lower():match("^(%S*)%s*(.-)$")
	if cmd == "" then
		ns.OpenOptions()
	elseif cmd == "on" or cmd == "enable" then
		ns.SetEnabled(true)
		Print(L.STATUS:format(OnOff(db.enabled)))
	elseif cmd == "off" or cmd == "disable" then
		ns.SetEnabled(false)
		Print(L.STATUS:format(OnOff(db.enabled)))
	elseif cmd == "toggle" then
		ns.SetEnabled(not db.enabled)
		Print(L.STATUS:format(OnOff(db.enabled)))
	elseif cmd == "kb" then
		db.killingBlowOnly = not db.killingBlowOnly
		Print(KillingBlowStatus())
		ns.RefreshOptions()
	elseif cmd == "delay" and tonumber(arg) then
		Print(L.DELAY_SET:format(ns.SetDelay(arg)))
	elseif cmd == "sound" then
		db.sound = not db.sound
		Print(L.SOUND_STATUS:format(OnOff(db.sound)))
		ns.RefreshOptions()
	elseif cmd == "chat" then
		db.chat = not db.chat
		Print(L.CHAT_STATUS:format(OnOff(db.chat)))
		ns.RefreshOptions()
	elseif cmd == "lang" then
		local code
		for _, lang in ipairs(ns.LANGUAGES) do
			if arg == lang.code:lower() or arg == lang.short then code = lang.code end
		end
		if code then
			ns.SetLocale(code)
			Print(L.LANGUAGE_SET:format(ns.GetLanguageName(code)))
		else
			PrintHelp()
		end
	elseif cmd == "status" then
		PrintStatus()
	else
		PrintHelp()
	end
end

function HonorSnap_OnAddonCompartmentClick(_, button)
	if button == "RightButton" then
		ns.OpenOptions()
	else
		ns.SetEnabled(not db.enabled)
		if db.chat then
			Print(L.STATUS:format(OnOff(db.enabled)))
		end
	end
end

function HonorSnap_OnAddonCompartmentEnter(_, menuButton)
	GameTooltip:SetOwner(menuButton, "ANCHOR_LEFT")
	GameTooltip:AddLine("|cffffd100Honor|r|cffff4040Snap|r")
	GameTooltip:AddLine(L.STATUS:format(OnOff(db.enabled)), 1, 1, 1)
	GameTooltip:AddLine(L.TOTAL:format(db.total), 1, 1, 1)
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(L.TT_LEFT)
	GameTooltip:AddLine(L.TT_RIGHT)
	GameTooltip:Show()
end

function HonorSnap_OnAddonCompartmentLeave()
	GameTooltip:Hide()
end
