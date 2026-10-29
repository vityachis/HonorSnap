local addonName, ns = ...
local L = ns.L

local HonorSnap = CreateFrame("Frame")
ns.addon = HonorSnap

local INTERFACE = select(4, GetBuildInfo())
-- Retail (12.x) and WoW Forever (16xxx, retail engine) have no combat log for addons,
-- but they do fire a dedicated PARTY_KILL event instead.
local IS_MODERN = INTERFACE >= 120000 or (INTERFACE >= 16000 and INTERFACE < 20000)

local SOUND_FILE = "Interface\\AddOns\\HonorSnap\\Media\\shutter.ogg"
local KB_WINDOW = 2.5         -- max seconds between the killing blow and the honor credit
local DEDUPE_WINDOW = 1.0     -- several signals for the same kill collapse into one screenshot
local WARMUP = 5              -- ignore stat updates right after login / loading screens
local DUEL_GRACE = 5          -- ignore kill signals for a few seconds after a duel ends
local EMOTE_COOLDOWN = 3      -- at most one emote every few seconds, however many kills
local DEATH_CHECK_DELAY = 0.5 -- let the lethal hit (or the death recap) arrive before reading it
local DEATH_WINDOW = 2        -- max seconds between the last hit taken and the death check
local UI_RESTORE_TIMEOUT = 2  -- show the interface again even if no screenshot event arrives

-- Emotes that can be picked in the options. Only these tokens are ever performed,
-- so an edited or shared SavedVariables file can't make the addon do anything else.
ns.EMOTES = {
	"CHEER", "ROAR", "FLEX", "GLOAT",
	"LAUGH", "ROFL", "CACKLE", "GUFFAW", "MOCK", "TAUNT", "CHICKEN", "PITY",
	"SPIT", "RUDE",
	"SALUTE", "BOW", "APPLAUD", "WAVE",
	"DANCE", "TRAIN", "CRY",
}

local defaults = {
	enabled = true,
	killingBlowOnly = true,
	delay = 0.5,
	hideUI = false,
	emote = "",
	sound = false,
	msgOwnKills = false,
	msgGroupKills = false,
	msgDeaths = false,
	debug = false,
	locale = "auto",
	total = 0,
}

local db
local playerGUID
local readyAt = math.huge
local lastSessionHK
local honorAt, honorVictim
local lastHonorAt = -math.huge
local pendingKill          -- my latest killing blow on a player: { at, victim, isPlayer, pet, honored }
local lastShotAt = 0
local lastEmoteAt = -math.huge
local savedUIAlpha         -- set while the interface is hidden for a screenshot
local inDuel = false
local duelEndedAt = -math.huge
local usesCombatLog = false
local debugReminded = false
local lastHit = {}         -- last damage the player took, from the combat log

ns.canDetectKillingBlow = false

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffffd100Honor|r|cffff4040Snap|r: " .. msg)
end
ns.Print = Print

local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) or false
end

-- Debug output is English only and never localized.
local function DebugValue(value)
	if IsSecret(value) then return "<secret>" end
	return tostring(value)
end

local function Debug(msg, ...)
	if not (db and db.debug) then return end
	local count = select("#", ...)
	local args = {}
	for i = 1, count do
		args[i] = DebugValue((select(i, ...)))
	end
	DEFAULT_CHAT_FRAME:AddMessage("|cff999999[HonorSnap debug]|r " .. msg:format(unpack(args, 1, count)))
end

local function SafeName(unit)
	if not unit or IsSecret(unit) then return nil end
	local ok, name, realm = pcall(UnitName, unit)
	if ok and name and not IsSecret(name) and name ~= "" then
		if realm and not IsSecret(realm) and realm ~= "" then
			return name, name .. "-" .. realm
		end
		return name, name
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

-- Returns why this isn't a real open-world kill (instance, battleground, arena or duel), or nil.
local function GetBlockReason()
	local inInstance, instanceType = IsInInstance()
	if IsSecret(inInstance) or IsSecret(instanceType) then return "instance (secret)" end
	if inInstance or (instanceType ~= nil and instanceType ~= "none") then
		return "instance: " .. tostring(instanceType)
	end
	if inDuel or GetTime() - duelEndedAt < DUEL_GRACE then return "duel" end
	if IsInActiveBattlefield() then return "battleground / arena / battlefield" end
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
-- Names for chat messages
---------------------------------------------------------------------------

-- A person in a message: { name = shown name, target = name for the emote, class, sex }.
local function InfoFromGUID(guid, name)
	if IsSecret(name) then name = nil end
	local info = { name = name, target = name }
	if guid and not IsSecret(guid) and GetPlayerInfoByGUID then
		local ok, _, class, _, _, sex, playerName, realm = pcall(GetPlayerInfoByGUID, guid)
		if ok and class and not IsSecret(class) then
			info.class, info.sex = class, sex
			if not info.name and playerName and not IsSecret(playerName) and playerName ~= "" then
				info.name, info.target = playerName, playerName
				if realm and not IsSecret(realm) and realm ~= "" then
					info.target = playerName .. "-" .. realm
				end
			end
		end
	end
	-- Names from other realms come as "Name-Realm": show just the name.
	if info.name then info.name = info.name:gsub("%-.*$", "") end
	return info
end

local function InfoFromUnit(unit)
	local name, fullName = SafeName(unit)
	local _, class = UnitClass(unit)
	if IsSecret(class) then class = nil end
	local sex = UnitSex(unit)
	if IsSecret(sex) then sex = nil end
	return { name = name, target = fullName, class = class, sex = sex }
end

-- Retail GUIDs of anything that isn't player-controlled are secret, so a secret
-- GUID means "not sure", never "not a player".
local function VictimFromGUID(guid, name)
	local isPlayer
	if guid and not IsSecret(guid) then
		isPlayer = guid:find("^Player%-") ~= nil
	end
	return InfoFromGUID(guid, name), isPlayer
end

-- Finds a group member, or the owner of a group member's pet, by GUID.
local function FindGroupMember(guid)
	if not guid or IsSecret(guid) then return end
	local prefix, count = "party", GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
	if IsInRaid and IsInRaid() then
		prefix, count = "raid", GetNumGroupMembers()
	end
	for i = 1, count do
		local unit = prefix .. i
		if UnitGUID(unit) == guid then
			return InfoFromUnit(unit)
		end
		local pet = prefix .. "pet" .. i
		if UnitGUID(pet) == guid then
			return InfoFromUnit(unit), (SafeName(pet))
		end
	end
end

local function ColorName(info)
	local name = info.name or L.UNKNOWN
	local colors = info.class and (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)
	local color = colors and colors[info.class]
	if not color then return name end
	if color.colorStr then
		return "|c" .. color.colorStr .. name .. "|r"
	end
	local function hex(value) return math.floor(value * 255 + 0.5) end
	return ("|cff%02x%02x%02x%s|r"):format(hex(color.r), hex(color.g), hex(color.b), name)
end

-- Picks the male or female form of a message (Russian and Ukrainian need it).
local function GenderText(key, sex)
	if sex == 2 then return L[key .. "_M"] end
	if sex == 3 then return L[key .. "_F"] end
	return L[key]
end

---------------------------------------------------------------------------
-- Screenshot
---------------------------------------------------------------------------

function ns.IsValidEmote(token)
	for _, emote in ipairs(ns.EMOTES) do
		if emote == token then return true end
	end
	return false
end

local function PlayEmote(target)
	local token = db.emote
	if token == "" or not ns.IsValidEmote(token) then return end
	local now = GetTime()
	if now - lastEmoteAt < EMOTE_COOLDOWN then
		Debug("emote %s skipped: cooldown", token)
		return
	end
	lastEmoteAt = now
	-- Aimed at the victim by name, so the player's current target is left alone.
	local perform = C_ChatInfo and C_ChatInfo.PerformEmote or DoEmote
	local ok, err = pcall(perform, token, target)
	Debug("emote %s at %s: %s", token, target, ok and "sent" or err)
end

local function RestoreUI()
	if savedUIAlpha then
		UIParent:SetAlpha(savedUIAlpha)
		savedUIAlpha = nil
	end
end

-- Alpha instead of Hide(): UIParent holds secure frames, which an addon can't hide in combat.
-- Nameplates and names above heads live outside UIParent and stay visible.
local function HideUI()
	if not db.hideUI or not UIParent:IsShown() then return end
	if not savedUIAlpha then
		savedUIAlpha = UIParent:GetAlpha()
	end
	UIParent:SetAlpha(0)
	C_Timer.After(UI_RESTORE_TIMEOUT, RestoreUI)
end

local function TakeShot(victim, counted)
	-- The emote goes off right away, so the enemy sees it before releasing their spirit.
	PlayEmote(victim.target)
	C_Timer.After(db.delay, function()
		if db.sound and db.emote == "" then
			PlaySoundFile(SOUND_FILE, "Master")
		end
		if counted then
			if db.total == 0 and not db.since then
				db.since = time()
			end
			db.total = db.total + 1
		end
		HideUI()
		Screenshot()
	end)
end

-- Takes the screenshot unless it's a duplicate or not in the open world.
local function Shoot(victim, counted)
	local now = GetTime()
	if now - lastShotAt < DEDUPE_WINDOW then
		Debug("no screenshot: duplicate signal")
		return
	end
	local reason = GetBlockReason()
	if reason then
		Debug("no screenshot: %s", reason)
		return
	end
	lastShotAt = now
	Debug("screenshot of %s (%s)", victim.name, counted and "counted" or "debug, not counted")
	TakeShot(victim, counted)
end

local function TryFire()
	if not honorAt then return end
	if not db.enabled then
		Debug("no screenshot: addon disabled")
		honorAt, honorVictim = nil, nil
		return
	end

	local kill = pendingKill
	if kill and math.abs(honorAt - kill.at) > KB_WINDOW then kill = nil end
	if db.killingBlowOnly and ns.canDetectKillingBlow and not kill then
		Debug("honor credit without my killing blow (yet)")
		return
	end

	local victim = kill and kill.victim or { name = honorVictim, target = honorVictim }
	if not victim.name then
		victim.name, victim.target = honorVictim, honorVictim
	end
	honorAt, honorVictim = nil, nil
	if kill then pendingKill = nil end

	Shoot(victim, true)
end

---------------------------------------------------------------------------
-- Chat messages
---------------------------------------------------------------------------

local function AnnounceOwnKill(kill, noHonor)
	if kill.announced then return end
	kill.announced = true
	if not db.enabled or not db.msgOwnKills or kill.blocked then return end
	local suffix = ""
	if kill.pet then suffix = suffix .. L.MSG_PET:format(kill.pet) end
	if noHonor then suffix = suffix .. L.MSG_NO_HONOR end
	Print(L.MSG_YOU_KILLED:format(ColorName(kill.victim), suffix))
end

local function AnnounceGroupKill(killer, pet, victim, isPlayer)
	Debug("group kill: %s (pet %s) killed %s, player: %s", killer.name, pet, victim.name, isPlayer)
	if not db.enabled or not db.msgGroupKills then return end
	if not isPlayer and not db.debug then return end
	if GetBlockReason() then return end
	local suffix = pet and L.MSG_PET:format(pet) or ""
	Print(GenderText("MSG_GROUP_KILLED", killer.sex):format(ColorName(killer), ColorName(victim), suffix))
end

local function AnnounceDeath(killer, isPet, spell)
	if not db.enabled or not db.msgDeaths or GetBlockReason() then return end
	local suffix = spell and L.MSG_SPELL:format(spell) or ""
	if isPet then
		Print(L.MSG_KILLED_BY_PET:format(ColorName(killer), suffix))
	else
		Print(GenderText("MSG_KILLED_BY", killer.sex):format(ColorName(killer), suffix))
	end
end

---------------------------------------------------------------------------
-- Kill signals
---------------------------------------------------------------------------

-- Honorable kill credit. Blizzard only awards it for enemies that were not gray,
-- which is exactly the "green or higher" condition.
local function OnHonorableKill(victim)
	local now = GetTime()
	Debug("honorable kill credit: %s", victim)
	lastHonorAt = now
	honorAt = now
	honorVictim = victim or honorVictim

	local kill = pendingKill
	if kill and not kill.honored and now - kill.at <= KB_WINDOW then
		kill.honored = true
		if not kill.victim.name then
			kill.victim.name, kill.victim.target = victim, victim
		end
		AnnounceOwnKill(kill)
	end

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

-- isPlayer is nil when the client hides who the victim was.
local function OnKillingBlow(victim, isPlayer, pet)
	local kill = { at = GetTime(), victim = victim, isPlayer = isPlayer, pet = pet, blocked = GetBlockReason() }
	Debug("my killing blow: %s (pet %s), player: %s", victim.name, pet, isPlayer)

	-- Kills of NPCs only matter in debug mode, where any kill gets a screenshot.
	if isPlayer == false then
		if db.debug then
			AnnounceOwnKill(kill)
			if db.enabled then Shoot(victim, false) end
		end
		return
	end

	pendingKill = kill
	-- The honor credit may come first.
	if GetTime() - lastHonorAt <= KB_WINDOW then
		kill.honored = true
		AnnounceOwnKill(kill)
	end
	TryFire()

	-- Nothing tells us a kill gave no honor, so check back once the window is over.
	C_Timer.After(KB_WINDOW, function()
		if kill.honored then return end
		Debug("no honor credit for %s", victim.name)
		if isPlayer then
			AnnounceOwnKill(kill, true)
		elseif db.debug then
			AnnounceOwnKill(kill)
		end
		if db.debug and db.enabled then
			Shoot(victim, false)
		end
	end)
end

-- Returns true if the session honorable kill counter went up since the last check.
local function SessionHKIncreased()
	local hk = GetSessionHK()
	if not hk then return nil end
	local increased = lastSessionHK ~= nil and hk > lastSessionHK
	lastSessionHK = hk
	return increased
end

---------------------------------------------------------------------------
-- Death
---------------------------------------------------------------------------

local FLAG_PLAYER = COMBATLOG_OBJECT_TYPE_PLAYER or 0x00000400
local FLAG_PET = (COMBATLOG_OBJECT_TYPE_PET or 0x00001000) + (COMBATLOG_OBJECT_TYPE_GUARDIAN or 0x00002000)
local FLAG_CONTROL_PLAYER = COMBATLOG_OBJECT_CONTROL_PLAYER or 0x00000100

local function HasFlag(flags, mask)
	return flags ~= nil and bit.band(flags, mask) ~= 0
end

-- Combat log damage events: the spell name argument, or false for melee and the environment.
local DAMAGE_EVENTS = {
	SWING_DAMAGE = false,
	ENVIRONMENTAL_DAMAGE = false,
	RANGE_DAMAGE = 13,
	SPELL_DAMAGE = 13,
	SPELL_PERIODIC_DAMAGE = 13,
	SPELL_BUILDING_DAMAGE = 13,
	DAMAGE_SHIELD = 13,
	DAMAGE_SPLIT = 13,
}

-- Classic flavors: the last hit taken before dying is the killing blow.
local function AnnounceDeathFromCombatLog()
	if not lastHit.at or GetTime() - lastHit.at > DEATH_WINDOW then
		Debug("death: no recent hit in the combat log")
		return
	end
	Debug("death: last hit by %s (%s)", lastHit.name, lastHit.spell)
	if not lastHit.guid or lastHit.guid == "" then return end -- falling, lava, drowning...
	local isPlayer = HasFlag(lastHit.flags, FLAG_PLAYER)
	local isPet = not isPlayer and HasFlag(lastHit.flags, FLAG_PET) and HasFlag(lastHit.flags, FLAG_CONTROL_PLAYER)
	if not isPlayer and not isPet and not db.debug then return end
	local killer = isPlayer and InfoFromGUID(lastHit.guid, lastHit.name) or { name = lastHit.name }
	AnnounceDeath(killer, isPet, lastHit.spell)
end

-- Retail / Forever: no combat log, so read Blizzard's own death recap.
-- Its fields may be secret on Retail, in which case nothing is printed.
local function AnnounceDeathFromRecap()
	if not (C_DeathRecap and C_DeathRecap.GetRecapEvents) then
		Debug("death: no death recap API")
		return
	end
	local ok, err = pcall(function()
		local hit = (C_DeathRecap.GetRecapEvents() or {})[1]
		if type(hit) ~= "table" then
			Debug("death: death recap is empty")
			return
		end
		local name, guid, event, spell = hit.sourceName, hit.sourceGUID, hit.event, hit.spellName
		Debug("death recap: %s, %s, %s, %s", name, guid, event, spell)
		if IsSecret(hit.hideCaster) or hit.hideCaster then return end
		if not name or IsSecret(name) then return end
		local isPlayer, isPet
		if guid and not IsSecret(guid) then
			isPlayer = guid:find("^Player%-") ~= nil
			isPet = guid:find("^Pet%-") ~= nil
		end
		if not isPlayer and not isPet and not db.debug then return end
		if IsSecret(event) or event == "SWING_DAMAGE" or IsSecret(spell) then spell = nil end
		local killer = isPlayer and InfoFromGUID(guid, name) or { name = name }
		AnnounceDeath(killer, isPet, spell)
	end)
	if not ok then Debug("death recap error: %s", err) end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local events = {}

function events.ADDON_LOADED(name)
	if name ~= addonName then return end
	HonorSnapDB = HonorSnapDB or {}
	db = HonorSnapDB
	for key, value in pairs(defaults) do
		if db[key] == nil then db[key] = value end
	end
	db.chat = nil -- 1.0.0 setting, replaced by the kill messages
	if not ns.IsValidEmote(db.emote) then db.emote = "" end
	ns.db = db
	ns.ApplyLocale(db.locale)
	HonorSnap:UnregisterEvent("ADDON_LOADED")
	ns.CreateOptions()
end

function events.PLAYER_ENTERING_WORLD()
	playerGUID = UnitGUID("player")
	readyAt = GetTime() + WARMUP
	lastSessionHK = GetSessionHK()
	honorAt, honorVictim, pendingKill = nil, nil, nil
	inDuel = false
	RestoreUI()
	if db.debug and not debugReminded then
		debugReminded = true
		Debug("debug mode is on: screenshots of any kill, nothing is counted. Turn it off with /hsnap debug.")
	end
end

function events.PLAYER_PVP_KILLS_CHANGED(unitTarget)
	if GetTime() < readyAt then
		lastSessionHK = GetSessionHK()
		return
	end
	local increased = SessionHKIncreased()
	Debug("PLAYER_PVP_KILLS_CHANGED: unit %s, counter went up: %s", unitTarget, increased)
	-- unitTarget is only passed for an actual kill; otherwise trust the counter.
	if (unitTarget and not IsSecret(unitTarget)) or increased or increased == nil then
		OnHonorableKill((SafeName(unitTarget)))
	end
end

-- Backup signal: some clients print the honor message before (or instead of)
-- updating the kill counter. Dishonorable kills share this event, so we only
-- trust it when the honorable kill counter actually went up.
function events.CHAT_MSG_COMBAT_HONOR_GAIN()
	if GetTime() < readyAt then return end
	Debug("CHAT_MSG_COMBAT_HONOR_GAIN")
	C_Timer.After(0.3, function()
		if SessionHKIncreased() then
			OnHonorableKill()
		end
	end)
end

-- Retail / Forever: dedicated event, the combat log is not available to addons.
function events.PARTY_KILL(attackerGUID, targetGUID)
	local victim, isPlayer = VictimFromGUID(targetGUID)
	if IsMyGUID(attackerGUID) then
		local pet = attackerGUID ~= playerGUID and (SafeName("pet")) or nil
		OnKillingBlow(victim, isPlayer, pet)
	else
		local killer, pet = FindGroupMember(attackerGUID)
		if killer then
			AnnounceGroupKill(killer, pet, victim, isPlayer)
		else
			Debug("PARTY_KILL by someone outside the group: %s", attackerGUID)
		end
	end
end

-- Classic flavors: the combat log tells who landed the killing blow and who hit us.
function events.COMBAT_LOG_EVENT_UNFILTERED()
	local _, subevent, _, sourceGUID, sourceName, sourceFlags, _, destGUID, destName, destFlags = CombatLogGetCurrentEventInfo()
	if subevent == "PARTY_KILL" then
		local victim = InfoFromGUID(destGUID, destName)
		local isPlayer = HasFlag(destFlags, FLAG_PLAYER)
		if IsMyGUID(sourceGUID) then
			OnKillingBlow(victim, isPlayer, sourceGUID ~= playerGUID and sourceName or nil)
		else
			local killer, pet = FindGroupMember(sourceGUID)
			if killer then
				AnnounceGroupKill(killer, pet, victim, isPlayer)
			end
		end
	elseif destGUID == playerGUID and DAMAGE_EVENTS[subevent] ~= nil then
		local spellArg = DAMAGE_EVENTS[subevent]
		lastHit.at = GetTime()
		lastHit.guid = subevent ~= "ENVIRONMENTAL_DAMAGE" and sourceGUID or nil
		lastHit.name = sourceName
		lastHit.flags = sourceFlags
		lastHit.spell = spellArg and select(spellArg, CombatLogGetCurrentEventInfo()) or nil
	end
end

function events.PLAYER_DEAD()
	Debug("PLAYER_DEAD")
	C_Timer.After(DEATH_CHECK_DELAY, usesCombatLog and AnnounceDeathFromCombatLog or AnnounceDeathFromRecap)
end

events.SCREENSHOT_SUCCEEDED = RestoreUI
events.SCREENSHOT_FAILED = RestoreUI

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
	"PLAYER_DEAD",
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
	usesCombatLog = TryRegister("COMBAT_LOG_EVENT_UNFILTERED")
	ns.canDetectKillingBlow = usesCombatLog
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

function ns.SetEmote(token)
	db.emote = ns.IsValidEmote(token) and token or ""
	ns.RefreshOptions()
end

function ns.GetEmoteName(token)
	if not token or token == "" then return L.EMOTE_NONE end
	return L["EMOTE_" .. token]
end

function ns.SetLocale(code)
	db.locale = code
	ns.ApplyLocale(code)
	ns.RefreshOptions()
end

function ns.ResetCounter()
	db.total = 0
	db.since = nil
	ns.RefreshOptions()
end

function ns.ResetSettings()
	for key, value in pairs(defaults) do
		db[key] = value
	end
	db.since = nil
	ns.ApplyLocale(db.locale)
	ns.RefreshOptions()
end

function ns.GetTotalText()
	if db.total > 0 and db.since then
		return L.TOTAL_SINCE:format(db.total, date(L.DATE_FORMAT, db.since))
	elseif db.total > 0 then
		return L.TOTAL_UNKNOWN:format(db.total)
	end
	return L.TOTAL:format(db.total)
end

-- /hsnap test: the whole screenshot path with a made-up victim, anywhere, never counted.
function ns.RunTest()
	local victim = { name = L.TEST_VICTIM }
	Debug("test screenshot")
	if db.msgOwnKills then
		Print(L.MSG_YOU_KILLED:format(victim.name, ""))
	end
	TakeShot(victim, false)
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

local function PrintEmotes()
	local tokens = {}
	for i, token in ipairs(ns.EMOTES) do tokens[i] = token:lower() end
	Print(L.EMOTE_LIST:format(table.concat(tokens, ", ")))
end

local function PrintStatus()
	Print(L.STATUS:format(OnOff(db.enabled)))
	Print(KillingBlowStatus())
	Print(L.HIDE_UI_STATUS:format(OnOff(db.hideUI)))
	Print(L.EMOTE_STATUS:format(ns.GetEmoteName(db.emote)))
	Print(L.SOUND_STATUS:format(OnOff(db.sound)))
	Print(L.MSG_OWN_STATUS:format(OnOff(db.msgOwnKills)))
	Print(L.MSG_GROUP_STATUS:format(OnOff(db.msgGroupKills)))
	Print(L.MSG_DEATH_STATUS:format(OnOff(db.msgDeaths)))
	Print(L.DELAY_SET:format(db.delay))
	Print(L.LANGUAGE_SET:format(ns.GetLanguageName(db.locale)))
	Print(L.DEBUG_STATUS:format(OnOff(db.debug)))
	Print(ns.GetTotalText())
end

-- Simple on/off settings: command -> saved variable and the status line it prints.
local TOGGLES = {
	hideui = { key = "hideUI", status = "HIDE_UI_STATUS" },
	sound = { key = "sound", status = "SOUND_STATUS" },
	kills = { key = "msgOwnKills", status = "MSG_OWN_STATUS" },
	group = { key = "msgGroupKills", status = "MSG_GROUP_STATUS" },
	deaths = { key = "msgDeaths", status = "MSG_DEATH_STATUS" },
	debug = { key = "debug", status = "DEBUG_STATUS" },
}

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
	elseif TOGGLES[cmd] then
		local toggle = TOGGLES[cmd]
		db[toggle.key] = not db[toggle.key]
		Print(L[toggle.status]:format(OnOff(db[toggle.key])))
		ns.RefreshOptions()
	elseif cmd == "emote" then
		if arg == "off" or arg == "none" then
			ns.SetEmote("")
		elseif ns.IsValidEmote(arg:upper()) then
			ns.SetEmote(arg:upper())
		else
			PrintEmotes()
			return
		end
		Print(L.EMOTE_STATUS:format(ns.GetEmoteName(db.emote)))
	elseif cmd == "test" then
		Print(L.TEST_RUN)
		ns.RunTest()
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
	end
end

function HonorSnap_OnAddonCompartmentEnter(_, menuButton)
	GameTooltip:SetOwner(menuButton, "ANCHOR_LEFT")
	GameTooltip:AddLine("|cffffd100Honor|r|cffff4040Snap|r")
	GameTooltip:AddLine(L.STATUS:format(OnOff(db.enabled)), 1, 1, 1)
	GameTooltip:AddLine(ns.GetTotalText(), 1, 1, 1)
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(L.TT_LEFT)
	GameTooltip:AddLine(L.TT_RIGHT)
	GameTooltip:Show()
end

function HonorSnap_OnAddonCompartmentLeave()
	GameTooltip:Hide()
end
