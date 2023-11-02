local _GetNumGroupMembers =
	GetNumGroupMembers                                                  --> wow api                                   --> wow api
local _IsInRaid = IsInRaid                                              --> wow api
local _UnitGroupRolesAssigned = DetailsFramework.UnitGroupRolesAssigned --> wow api
local GetUnitName = GetUnitName

local _ipairs = ipairs         --> lua api
local _table_sort = table.sort --> lua api
local _math_floor = math.floor
local _details = _G.Details
-- round combat time to nearest second
local _getCombatTime = function() return _math_floor(_details:GetCurrentCombat():GetCombatTime() + 0.5) + 1 end
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local DETAILS_ATTRIBUTE_DAMAGE = DETAILS_ATTRIBUTE_DAMAGE
local DF = DetailsFramework
_G.PrescienceDB = _G.PrescienceDB or {}
local PrescienceDB = _G.PrescienceDB
_G.PrescienceDebug = false
local debug = function(str)
	if (_G.PrescienceDebug) then
		print("|cFFFF0000Prescience:|r " .. str)
	end
end

-- actor 1 is name, 2 is dps, 3 is role, 4 is class, 5 is spec
local NAME = 1
local DPS_TABLE = 2
local ROLE = 3
local CLASS = 4
local SPEC = 5

--> Create the plugin Object
local Prescience = _details:NewPluginObject("Details_Prescience")

--> Main Frame
local PrescienceFrame = Prescience.Frame

Prescience:SetPluginDescription("Prescience Helper")

local _


-- Still TODO:
-- Maybe average multiple pulls?
-- Maybe also only run as augvoker?


local function CreatePluginFrames(data)
	--> cache Details! main object
	---@diagnostic disable-next-line: undefined-field
	--> data
	Prescience.data = data or {}

	--> defaults
	Prescience.RowWidth = 294
	Prescience.RowHeight = 14
	--> amount of row wich can be displayed
	Prescience.CanShow = 0
	--> all rows already created
	Prescience.Rows = {}
	--> current shown rows
	Prescience.ShownRows = {}
	-->
	Prescience.Actived = false

	Prescience.GetOnlyName = Prescience.GetOnlyName

	--> window reference
	local instance

	--> OnEvent Table
	function Prescience:OnDetailsEvent(event, ...)
		if (event == "DETAILS_STARTED") then
			Prescience:RefreshRows()
		elseif (event == "HIDE") then --> plugin hidded, disabled
			Prescience.Actived = false
			Prescience:Cancel()
		elseif (event == "SHOW") then
			instance = Prescience:GetInstance(Prescience.instance_id)

			Prescience.RowWidth = instance.baseframe:GetWidth() - 6

			Prescience:UpdateContainers()
			Prescience:UpdateRows()

			Prescience:SizeChanged()
			Prescience.Actived = false

			if (UnitAffectingCombat("player")) then
				if (not Prescience.initialized) then
					return
				end
				Prescience.Actived = true
				Prescience:Start()
			end
		elseif (event == "DETAILS_INSTANCE_ENDRESIZE" or event == "DETAILS_INSTANCE_SIZECHANGED") then
			local what_window = select(1, ...)
			if (what_window == instance) then
				Prescience:SizeChanged()
				Prescience:RefreshRows()
			end
		elseif (event == "DETAILS_INSTANCE_STARTSTRETCH") then
			PrescienceFrame:SetFrameStrata("TOOLTIP")
			PrescienceFrame:SetFrameLevel(instance.baseframe:GetFrameLevel() + 1)
		elseif (event == "DETAILS_INSTANCE_ENDSTRETCH") then
			PrescienceFrame:SetFrameStrata("MEDIUM")
		elseif (event == "PLUGIN_DISABLED") then
			PrescienceFrame:UnregisterEvent("ENCOUNTER_START")
			PrescienceFrame:UnregisterEvent("ENCOUNTER_END")
		elseif (event == "PLUGIN_ENABLED") then
			PrescienceFrame:RegisterEvent("ENCOUNTER_START")
			PrescienceFrame:RegisterEvent("ENCOUNTER_END")
		end
	end

	PrescienceFrame:SetWidth(300)
	PrescienceFrame:SetHeight(100)

	function Prescience:UpdateContainers()
		for _, row in _ipairs(Prescience.Rows) do
			row:SetContainer(instance.baseframe)
		end
	end

	function Prescience:UpdateRows()
		for _, row in _ipairs(Prescience.Rows) do
			row.width = Prescience.RowWidth
		end
	end

	function Prescience:HideBars()
		for _, row in _ipairs(Prescience.Rows) do
			row:Hide()
		end
	end

	function Prescience:SizeChanged()
		local pinstance = Prescience:GetPluginInstance()

		local w, h = pinstance:GetSize()
		PrescienceFrame:SetWidth(w)
		PrescienceFrame:SetHeight(h)
		Prescience.RowHeight = pinstance.row_info.height
		Prescience.CanShow = math.floor(h / (pinstance.row_info.height + 1))

		for i = #Prescience.Rows + 1, Prescience.CanShow do
			Prescience:NewRow(i)
		end

		Prescience.ShownRows = {}

		for i = 1, Prescience.CanShow do
			Prescience.ShownRows[i] = Prescience.Rows[i]
			if (_details.in_combat) then
				Prescience.Rows[i]:Show()
			end
			Prescience.Rows[i].width = w - 5
		end

		for i = #Prescience.ShownRows + 1, #Prescience.Rows do
			Prescience.Rows[i]:Hide()
		end
	end

	local SharedMedia = LibStub:GetLibrary("LibSharedMedia-3.0")

	function Prescience:RefreshRow(row)
		local pinstance = Prescience:GetPluginInstance()

		if (pinstance) then
			local font = SharedMedia:Fetch("font", pinstance.row_info.font_face, true) or pinstance.row_info.font_face

			row.textsize = pinstance.row_info.font_size
			row.textfont = font
			row.texture = pinstance.row_info.texture
			row.shadow = pinstance.row_info.textL_outline

			row.width = pinstance.baseframe:GetWidth() - 5
			row.height = pinstance.row_info.height
			row:SetIcon(nil)
			local rowHeight = -((row.rowId - 1) * (pinstance.row_info.height + 1))
			row:ClearAllPoints()
			row:SetPoint("topleft", PrescienceFrame, "topleft", 1, rowHeight)
			row:SetPoint("topright", PrescienceFrame, "topright", -1, rowHeight)
		end
	end

	function Prescience:RefreshRows()
		for i = 1, #Prescience.Rows do
			Prescience:RefreshRow(Prescience.Rows[i])
		end
	end

	function Prescience:NewRow(i)
		local newrow = DF:CreateBar(PrescienceFrame, "DetailsPrescienceDpsRow" .. i, i)
		newrow:SetPoint("LEFT", 0, -((i - 1) * (newrow:GetHeight() + 1)))
		newrow:SetLeftText("", "DetailsFont_DefaultSmall", 9.9, { 1, 1, 1, 1 })
		newrow.rowId = i
		Prescience.Rows[#Prescience.Rows + 1] = newrow
		Prescience:RefreshRow(newrow)
		newrow:Hide()

		return newrow
	end

	local sort = function(table1, table2)
		-- sort by the next dps_window seconds of dps
		local combatTime = _getCombatTime() + Prescience.saveddata.forward_skip
		local dps_table1 = table1[2]
		local dps_table2 = table2[2]
		local dps1 = 0
		local dps2 = 0
		for i = combatTime, combatTime + Prescience.saveddata.dps_window do
			if dps_table1[i] then
				dps1 = dps1 + dps_table1[i]
			end
			if dps_table2[i] then
				dps2 = dps2 + dps_table2[i]
			end
		end
		return dps1 > dps2
	end

	-- actor 1 is name, 2 is dps, 3 is role, 4 is class, 5 is spec
	local UpdateTableFromDps = function(dps_table, unit, combatTime)
		local combat = _details:GetCurrentCombat()
		local unitName = GetUnitName(unit, true)
		-- local role = _UnitGroupRolesAssigned(unitName)
		-- if role ~= "DAMAGER" and not _G.PrescienceDebug then return end
		local actor = combat:GetActor(DETAILS_ATTRIBUTE_DAMAGE, unitName)
		if not actor then
			return
		end
		if not UnitAffectingCombat(unit) then
			debug(unitName .. " is not in combat")
			return
		end
		dps_table[SPEC] = actor.spec
		local totalDamage = actor.total
		local damageDoneUntilLastSecond = 0
		for i = 0, combatTime - 1 do
			if dps_table[DPS_TABLE][i] then
				damageDoneUntilLastSecond = damageDoneUntilLastSecond + dps_table[DPS_TABLE][i]
			end
		end

		local damageThisSecond = floor(totalDamage - damageDoneUntilLastSecond)
		if damageThisSecond > 0 then
			debug("updating " .. unitName .. " with " .. damageThisSecond .. " damage this second")
			dps_table[DPS_TABLE][combatTime] = damageThisSecond
		end
	end

	local Presciencer = function()
		if (Prescience.Actived) then
			local combatTime = _getCombatTime()
			if (_IsInRaid()) then
				for i = 1, _GetNumGroupMembers(), 1 do
					local thisplayer_name = GetUnitName("raid" .. i, true)
					local dps_table_index = Prescience.player_list_hash[thisplayer_name]
					local dps_table = Prescience.player_list_indexes[dps_table_index]

					if (not dps_table) then
						--> some one joined the group while the player are in combat
						Prescience:Start()
						return
					end

					UpdateTableFromDps(dps_table, "raid" .. i, combatTime)
				end
			elseif (_G.PrescienceDebug) then
				local thisplayer_name = GetUnitName("player", true)
				local dps_table_index = Prescience.player_list_hash[thisplayer_name]
				local dps_table = Prescience.player_list_indexes[dps_table_index]

				if (not dps_table) then
					--> some one joined the group while the player are in combat
					Prescience:Start()
					return
				end

				UpdateTableFromDps(dps_table, "player", combatTime)
			end

			-- first, we look back at PrescienceDB.combats from highest to lowest index
			-- and find a combat that is long enough for our combat time
			-- then we sort the player list by dps
			-- then we update the rows with the new dps
			local combat = nil
			if PrescienceDB.combats then
				for i = #PrescienceDB.combats, 1, -1 do
					local thisCombat = PrescienceDB.combats[i]
					debug("checking combat " .. i .. " with time " .. thisCombat.time .. " and encounterID " .. thisCombat.encounterID)
					debug("combatTime is " .. combatTime .. " and dps_window is " .. Prescience.saveddata.dps_window .. " and forward_skip is " .. Prescience.saveddata.forward_skip)
					if thisCombat
						and thisCombat.time
						and thisCombat.time >= (combatTime + Prescience.saveddata.dps_window + Prescience.saveddata.forward_skip)
						and thisCombat.encounterID == Prescience.encounterID or _G.PrescienceDebug then
							debug("found combat " .. i)
						combat = thisCombat.players
						break
					end
				end
			end

			if combat then
				debug("loading last combat")
				_table_sort(combat, sort)

				local index = 1
				local payloadIndex = 1
				local lastIndex = #Prescience.ShownRows
				local payload = {}

				combatTime = combatTime + Prescience.saveddata.forward_skip

				while index <= lastIndex do
					local thisRow = Prescience.ShownRows[index]
					local actor = combat[index]

					-- actor 1 is name, 2 is dps, 3 is role, 4 is class, 5 is spec
					if actor and (actor[ROLE] == "DAMAGER" or _G.PrescienceDebug) then
						debug("updating row " .. index .. " with " .. actor[NAME])

						-- if they're no longer in the raid we can ignore them
						if not _UnitGroupRolesAssigned(actor[NAME]) then
							debug(actor[NAME] .. " is no longer in the raid")
							thisRow:Hide()
						else
							local rankText = index .. ". "
							thisRow:SetLeftText(rankText .. Prescience:GetOnlyName(actor[NAME]))
							local dps = 0
							local dps_table = actor[DPS_TABLE]
							for i = combatTime, combatTime + Prescience.saveddata.dps_window do
								if dps_table[i] then
									dps = dps + dps_table[i]
								end
							end
							dps = dps / Prescience.saveddata.dps_window
							dps = _math_floor(dps + 0.5)
	
							-- now we calculate the percentage as if 1st was 100% of the damage
							local percent = 0
							if combat[1] then
								local topDps = 0
								local topDpsTable = combat[1][DPS_TABLE]
								for i = combatTime, combatTime + Prescience.saveddata.dps_window do
									if topDpsTable[i] then
										topDps = topDps + topDpsTable[i]
									end
								end
								topDps = topDps / Prescience.saveddata.dps_window
								topDps = _math_floor(topDps + 0.5)
								percent = dps / topDps
							end
	
							if percent > 1 then
								percent = 1
							elseif percent < 0 then
								percent = 0
							end
							thisRow:SetValue(percent * 100)
							thisRow:SetRightText(Prescience:ToK2(dps))
	
							payload[payloadIndex] = {
								name = actor[NAME],
								dps = dps,
								role = actor[ROLE],
								class = actor[CLASS],
								spec = actor[SPEC],
								percent = floor(percent * 100)
							}
							payloadIndex = payloadIndex + 1
	
							local color = RAID_CLASS_COLORS[actor[CLASS]]
							if (color) then
								thisRow:SetColor(color.r, color.g, color.b, 1)
							else
								thisRow:SetColor(1, 1, 1, 1)
							end
	
							if actor[5] then
								local specIcon = select(4, GetSpecializationInfoForSpecID(actor[SPEC]))
								if specIcon then
									thisRow.statusbar.icontexture:SetSize(thisRow:GetHeight(), thisRow:GetHeight())
									thisRow:SetIcon(specIcon)
								end
							end
	
							if (not thisRow.statusbar:IsShown()) then
								thisRow:Show()
							end
						end
					else
						thisRow:Hide()
					end
					index = index + 1
				end
				if WeakAuras and payload then
					WeakAuras.ScanEvents("PRES_UPDATE", payload)
				end
			else
				WeakAuras.ScanEvents("PRES_UPDATE", {})
				Prescience:HideBars()
			end
		end
	end

	function Prescience:Tick()
		Presciencer()
	end

	function Prescience:Start()
		Prescience:HideBars()
		debug("Starting Prescience")
		if (Prescience.Actived) then
			if (Prescience.job_thread) then
				Prescience:CancelTimer(Prescience.job_thread)
				Prescience.job_thread = nil
			end

			Prescience.player_list_indexes = {}
			Prescience.player_list_hash = {}
			Prescience.combatStartTime = GetTime()

			--> pre build player list
			if (_IsInRaid()) then
				for i = 1, _GetNumGroupMembers(), 1 do
					local thisplayer_name = GetUnitName("raid" .. i, true)
					local role = _UnitGroupRolesAssigned(thisplayer_name)
					local _, class = UnitClass(thisplayer_name)

					local t = { thisplayer_name, {}, role, class }
					Prescience.player_list_indexes[#Prescience.player_list_indexes + 1] = t
					Prescience.player_list_hash[thisplayer_name] = #Prescience.player_list_indexes
				end
			elseif (_G.PrescienceDebug) then
				local thisplayer_name = GetUnitName("player", true)
				local role = _UnitGroupRolesAssigned(thisplayer_name)
				local _, class = UnitClass(thisplayer_name)

				local t = { thisplayer_name, {}, role, class }
				Prescience.player_list_indexes[#Prescience.player_list_indexes + 1] = t
				Prescience.player_list_hash[thisplayer_name] = #Prescience.player_list_indexes
			end

			local job_thread = Prescience:ScheduleRepeatingTimer("Tick", 1)
			Prescience.job_thread = job_thread
		else
			if not _details.in_combat then
				Prescience:End()
			end
		end
	end

	function Prescience:End()
		PrescienceDB.combats = PrescienceDB.combats or {}

		if Prescience.combatStartTime then
			local endTime = GetTime()
			local combatDuration = floor(endTime - Prescience.combatStartTime)

			debug("Combat ended with a duration of " .. combatDuration .. " seconds")

			-- combat needs to be longer than our dps_window, otherwise it's useless
			if combatDuration > Prescience.saveddata.dps_window then
				PrescienceDB.combats[#PrescienceDB.combats + 1] = {
					time = combatDuration,
					players = Prescience.player_list_indexes,
					encounterID = Prescience.encounterID
				}

				-- Remove older combats
				if #PrescienceDB.combats > 20 then
					for i = 1, #PrescienceDB.combats - 20 do
						PrescienceDB.combats[i] = nil
					end
				end
			end
		end

		-- Keep track of combat start time for the next combat
		Prescience.combatStartTime = nil

		Prescience:HideBars()

		if (Prescience.job_thread) then
			Prescience:CancelTimer(Prescience.job_thread)
			Prescience.job_thread = nil
		end
	end

	function Prescience:Cancel()
		Prescience:HideBars()
		if (Prescience.job_thread) then
			Prescience:CancelTimer(Prescience.job_thread)
			Prescience.job_thread = nil
		end
		Prescience.Actived = false
	end
end

local build_options_panel = function()
	local options_frame = Prescience:CreatePluginOptionsFrame("PrescienceOptionsWindow", "Prescience Options", 1)

	local menu = {
		{
			type = "range",
			get = function() return Prescience.saveddata.dps_window end,
			set = function(self, fixedparam, value) Prescience.saveddata.dps_window = floor(value) end,
			min = 5,
			max = 120,
			step = 1,
			desc = "How far ahead to average dps over",
			name = "DPS Window",
			usedecimals = true,
		},
		{
			type = "range",
			get = function() return Prescience.saveddata.forward_skip end,
			set = function(self, fixedparam, value) Prescience.saveddata.forward_skip = floor(value) end,
			min = 0,
			max = 120,
			step = 1,
			desc = "How many seconds to skip forward in the future before we start calculating dps",
			name = "Forward Skip",
			usedecimals = true,
		},
		{
			type = "toggle",
			get = function() return Prescience.saveddata.only_aug end,
			set = function(self, fixedparam, value) Prescience.saveddata.only_aug = value end,
			desc = "Only show dps for augvokers",
			name = "Only Augvokers",
		},
	}

	Details.gump:BuildMenu(options_frame, menu, 15, -35, 160)
	options_frame:SetHeight(160)
end

Prescience.OpenOptionsPanel = function()
	if (not PrescienceOptionsWindow) then
		build_options_panel()
	end
	PrescienceOptionsWindow:Show()
end

function Prescience:OnEvent(_, event, ...)
	debug("event: " .. event)
	if (event == "ENCOUNTER_START") then
		local specId = GetSpecializationInfo(GetSpecialization())
		if Prescience.saveddata.only_aug and specId ~= 1473 then
			return
		end
		local groupSize = GetNumGroupMembers()
		if groupSize <= 5 and not _G.PrescienceDebug then
			return
		end
		Prescience.Actived = true
		Prescience.encounterID = select(1, ...)
		if not Prescience.encounterID then
			debug("No encounterID found")
			return
		end
		debug("Starting combat with encounterID " .. Prescience.encounterID)
		Prescience:Start()
	elseif (event == "ENCOUNTER_END") then
		Prescience:End()
		Prescience.Actived = false
	elseif (event == "ADDON_LOADED") then
		local AddonName = select(1, ...)

		if (AddonName == "Details_Prescience") then
			if (_details) then
				--> create widgets
				CreatePluginFrames()

				local MINIMAL_DETAILS_VERSION_REQUIRED = 1

				--> Install
				local install, saveddata = _details:InstallPlugin("RAID", "Prescience",
					"Interface\\Icons\\Ability_Evoker_Prescience", Prescience, "DETAILS_PLUGIN_PRESCIENCE",
					MINIMAL_DETAILS_VERSION_REQUIRED, "Marminator", "v0.1")
				if (type(install) == "table" and install.error) then
					print(install.error)
				end

				--> Register needed eventsB
				_details:RegisterEvent(Prescience, "COMBAT_PLAYER_ENTER")
				_details:RegisterEvent(Prescience, "COMBAT_PLAYER_LEAVE")
				_details:RegisterEvent(Prescience, "DETAILS_INSTANCE_ENDRESIZE")
				_details:RegisterEvent(Prescience, "DETAILS_INSTANCE_SIZECHANGED")
				_details:RegisterEvent(Prescience, "DETAILS_INSTANCE_STARTSTRETCH")
				_details:RegisterEvent(Prescience, "DETAILS_INSTANCE_ENDSTRETCH")
				_details:RegisterEvent(Prescience, "DETAILS_OPTIONS_MODIFIED")

				PrescienceFrame:RegisterEvent("ENCOUNTER_END")
				PrescienceFrame:RegisterEvent("ENCOUNTER_START")

				--> Saved data
				Prescience.saveddata = saveddata or {}
				Prescience.saveddata.dps_window = Prescience.saveddata.dps_window or 30
				Prescience.saveddata.forward_skip = Prescience.saveddata.forward_skip or 0
				Prescience.saveddata.only_aug = Prescience.saveddata.only_aug or true
				Prescience.options = Prescience.saveddata
			end
		end
	end
end
