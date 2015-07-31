local addonName, addon, _ = ...
local plugin = addon:NewModule('Tracker', 'AceEvent-3.0')

local defaults = {
	profile = {
		trackProfession = {
			[1] = true, -- primary (first)
			[2] = true, -- primary (second)
			[3] = true, -- archaeology
			[4] = true, -- fishing
			[5] = true, -- cooking
			[6] = true, -- first aid
		},
		hideMaxed = false,
	},
}

local ARCHAEOLOGY = 794
local MINING = 186

local OBJECTIVE_TRACKER_UPDATE_MODULE_PROFESSION = 0x2000
local TRACKER = ObjectiveTracker_GetModuleInfoTable()
TRACKER.updateReasonModule = OBJECTIVE_TRACKER_UPDATE_MODULE_PROFESSION
TRACKER.usedBlocks = {}
plugin.tracker = TRACKER

function TRACKER:OnBlockHeaderClick(block, mouseButton)
	local name, _, _, _, _, spellOffset, skillLine = GetProfessionInfo(block.id)
	local spellLink, tradeSkillLink = GetSpellLink(spellOffset + 1, BOOKTYPE_PROFESSION)
	if tradeSkillLink or skillLine == ARCHAEOLOGY or skillLine == MINING then
		CastSpell(spellOffset + 1, BOOKTYPE_PROFESSION)
		if IsModifiedClick('CHATLINK') and ChatEdit_GetActiveWindow() and tradeSkillLink then
			ChatEdit_InsertLink(tradeSkillLink)
			CloseTradeSkill()
		else -- toggle off
			CastSpell(spellOffset + 1, BOOKTYPE_PROFESSION)
		end
	end
end

local professions, expansionMaxRank, expansionMaxName = {}, unpack(PROFESSION_RANKS[#PROFESSION_RANKS])
function TRACKER:Update()
	local prof1, prof2, archaeology, fishing, cooking, firstAid = GetProfessions()
	professions[1] = prof1 or 0 		professions[2] = prof2 or 0
	professions[3] = archaeology or 0	professions[4] = fishing or 0
	professions[5] = cooking or 0 		professions[6] = firstAid or 0

	TRACKER:BeginLayout()
	for index, profession in ipairs(professions) do
		local name, icon, rank, maxRank, numSpells, spelloffset, skillLine, rankModifier, specializationIndex, specializationOffset = GetProfessionInfo(profession)
		local isMaxSkill = rank >= expansionMaxRank and rank == maxRank
		if profession > 0 and plugin.db.profile.trackProfession[index]
			and (not isMaxSkill or not plugin.db.profile.hideMaxed) then
			local block = self:GetBlock(profession)
			self:SetBlockHeader(block, ('|T%s:0|t %s'):format(icon, name))

			local skill = isMaxSkill and expansionMaxName or ('%d/%d'):format(rank, maxRank)
			local line = self:AddObjective(block, profession, skill, nil, nil, true)

			if not isMaxSkill then
				-- abusing timer bar as progress bar
				-- cause line to move up into objective line
				local lineSpacing = block.module.lineSpacing
				block.module.lineSpacing = -16
				local timerBar = self:AddTimerBar(block, line, maxRank, nil)
				timerBar:SetScript('OnUpdate', nil)
				timerBar.Bar:SetMinMaxValues(0, maxRank)
				timerBar.Bar:SetValue(rank)
				block.module.lineSpacing = lineSpacing

				-- indicate higher learning required
				if maxRank < expansionMaxRank and rank/maxRank > 0.9 then
					timerBar.Bar:SetStatusBarColor(1, 0, 0)
				else
					timerBar.Bar:SetStatusBarColor(0.26, 0.42, 1)
				end
			else
				self:FreeProgressBar(block, line)
			end

			-- add to tracker
			block:SetHeight(block.height)
			if ObjectiveTracker_AddBlock(block) then
				block:Show()
				TRACKER:FreeUnusedLines(block)
			else -- we've run out of space
				block.used = false
				break
			end
		end
	end
	TRACKER:EndLayout()
end

local function InitTracker(self)
	table.insert(self.MODULES, TRACKER)
	self.BlocksFrame.ProfessionHeader = CreateFrame('Frame', nil, self.BlocksFrame, 'ObjectiveTrackerHeaderTemplate')
	TRACKER:SetHeader(self.BlocksFrame.ProfessionHeader, _G.TRADE_SKILLS, 0)

	self:RegisterEvent('SKILL_LINES_CHANGED', function()
		ObjectiveTracker_Update(OBJECTIVE_TRACKER_UPDATE_MODULE_PROFESSION)
	end)
	ObjectiveTracker_Update(OBJECTIVE_TRACKER_UPDATE_MODULE_PROFESSION)
end

function plugin:OnEnable()
	self.db = addon.db:RegisterNamespace('Tracker', defaults)

	--[[
	local professionButtons = SpellBookProfessionFrame:GetChildren()
	local professionToggle = CreateFrame('Button', addonName .. 'ProfessionToggle', nil, 'SecureActionButtonTemplate')
	professionToggle:RegisterForClicks('AnyUp')
	professionToggle:SetAttribute('type', 'OpenProfession')
	professionToggle.OpenProfession = function(self, unit, button, actionType)
		print(self, unit, button, actionType)
		for index, profession in pairs(professionButtons) do
			-- herbalism / skinning have no recipes
			if profession.skillLine and profession.skillLine ~= 182 and profession.skillLine ~= 393 then
				SpellButton_OnClick(profession.button1, 'LeftButton')
				-- CloseTradeSkill()
			end
		end
	end
	--]]

	if ObjectiveTrackerFrame.initialized then
		InitTracker(ObjectiveTrackerFrame)
	else
		hooksecurefunc('ObjectiveTracker_Initialize', function(frame)
			InitTracker(frame)
		end)
	end
end
