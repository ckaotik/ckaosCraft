-- scans and stores data on known recipes and how to craft them
local addonName, addon, _ = ...
local recipes = addon:NewModule('Recipes')

-- GLOBALS: _G, LibStub
-- GLOBALS: CreateFrame, SpellButton_OnClick, TradeSkillOnlyShowMakeable, TradeSkillOnlyShowSkillUps, TradeSkillUpdateFilterBar, SelectTradeSkill, RegisterStateDriver, UnregisterStateDriver, CloseTradeSkill
-- GLOBALS: GetTradeSkillSelectionIndex, GetTradeSkillItemNameFilter, GetTradeSkillItemLevelFilter, GetTradeSkillInvSlotFilter, GetTradeSkillInvSlots, GetTradeSkillCategoryFilter, GetTradeSkillSubClasses, SetTradeSkillItemNameFilter, SetTradeSkillItemLevelFilter, SetTradeSkillInvSlotFilter, SetTradeSkillCategoryFilter, TradeSkillSetFilter, ExpandTradeSkillSubClass
-- GLOBALS: ToggleSpellBook, IsUsableSpell, GetSpellLink, IsTradeSkillLinked, GetTradeSkillNumReagents, GetTradeSkillReagentInfo, GetTradeSkillReagentItemLink, GetNumTradeSkills, GetTradeSkillInfo, GetTradeSkillNumMade, GetTradeSkillItemLink, GetTradeSkillRecipeLink
-- GLOBALS: wipe, select, pairs, hooksecurefunc, tonumber
local tinsert = table.insert

local tradeSkillFilters = {}
local function SaveFilters()
	local displayedTradeskill = _G.CURRENT_TRADESKILL
	local filters = tradeSkillFilters[displayedTradeskill]
	if not tradeSkillFilters[displayedTradeskill] then
		tradeSkillFilters[displayedTradeskill] = {}
		filters = tradeSkillFilters[displayedTradeskill]
	else
		wipe(filters)
	end

	filters.selected 	 = GetTradeSkillSelectionIndex()
	filters.name 		 = GetTradeSkillItemNameFilter()
	filters.levelMin,
	filters.levelMax 	 = GetTradeSkillItemLevelFilter()
	filters.hasMaterials = _G.TradeSkillFrame.filterTbl.hasMaterials
	filters.hasSkillUp 	 = _G.TradeSkillFrame.filterTbl.hasSkillUp

	if not GetTradeSkillInvSlotFilter(0) then
		if not filters.slots then filters.slots = {} end
		for i = 1, select('#', GetTradeSkillInvSlots()) do
			filters.slots[i] = GetTradeSkillInvSlotFilter(i)
		end
	end

	if not GetTradeSkillCategoryFilter(0) then
		if not filters.subClasses then filters.subClasses = {} end
		for i = 1, select('#', GetTradeSkillSubClasses()) do
			filters.subClasses[i] = GetTradeSkillCategoryFilter(i)
		end
	end
end
local function RestoreFilters()
	local displayedTradeskill = _G.CURRENT_TRADESKILL
	local filters = tradeSkillFilters[displayedTradeskill]
	if not displayedTradeskill or not filters then return end

	SetTradeSkillItemNameFilter(filters.name)
	SetTradeSkillItemLevelFilter(filters.levelMin or 0, filters.levelMax or 0)
	TradeSkillOnlyShowMakeable(filters.hasMaterials)
	TradeSkillOnlyShowSkillUps(filters.hasSkillUp)

	if filters.slots and #filters.slots > 0 then
		SetTradeSkillInvSlotFilter(0, 1, 1)
		for index, enabled in pairs(filters.slots) do
			SetTradeSkillInvSlotFilter(index, enabled)
		end
	end
	if filters.subClasses and #filters.subClasses > 0 then
		SetTradeSkillCategoryFilter(0, 1, 1)
		for index, enabled in pairs(filters.subClasses) do
			SetTradeSkillCategoryFilter(index, enabled)
		end
	end

	TradeSkillUpdateFilterBar()
	SelectTradeSkill(filters.selected)
	-- TradeSkillFrame_Update()
end
local function RemoveActiveFilters()
	ExpandTradeSkillSubClass(0) -- TODO: isn't currently saved/restored
	SetTradeSkillItemLevelFilter(0, 0)
    SetTradeSkillItemNameFilter(nil)
    TradeSkillSetFilter(-1, -1)
    -- TradeSkillFrame_Update()
end

local function ScanTradeSkill()
	-- TODO: maybe even allow reagent crafting for linked skills, assuming we have the skill, too
	if IsTradeSkillLinked() then return end

	SaveFilters()
	RemoveActiveFilters()
	for index = 1, GetNumTradeSkills() do
		local skillName, skillType = GetTradeSkillInfo(index)
		if skillName and not skillType:find('header') then
			local minYield, maxYield = GetTradeSkillNumMade(index)
			local crafted = GetTradeSkillItemLink(index)
			local craftedID = crafted:match('enchant:(%d+)')
				  craftedID = craftedID and -1*craftedID or 1*crafted:match('item:(%d+)')
			local craftSpellID = GetTradeSkillRecipeLink(index)
				  craftSpellID = 1*craftSpellID:match('enchant:(%d+)')

			if not recipes.db.char.craftables[craftedID] then recipes.db.char.craftables[craftedID] = {} end
			local craftedTable = recipes.db.char.craftables[craftedID]
			if not craftedTable[craftSpellID] then
				craftedTable[craftSpellID] = {}
			else
				wipe(craftedTable[craftSpellID])
			end
			local dataTable = craftedTable[craftSpellID]

			dataTable[1], dataTable[2] = minYield, maxYield
			for i = 1, GetTradeSkillNumReagents(index) do
				local _, _, reagentCount = GetTradeSkillReagentInfo(index, i)
				local reagentID = GetTradeSkillReagentItemLink(index, i)
					  reagentID = reagentID and 1*reagentID:match('item:(%d+)')
				if reagentID and reagentCount > 0 then
					tinsert(dataTable, reagentID)
					tinsert(dataTable, reagentCount)
				end
			end
			-- print('new entry', skillName, unpack(MidgetDB.craftables[craftedID][craftSpellID]))
		end
	end
	RestoreFilters()
end

local spellBookSkillButtons = { 'PrimaryProfession1SpellButtonBottom', 'PrimaryProfession2SpellButtonBottom', 'SecondaryProfession3SpellButtonRight', 'SecondaryProfession4SpellButtonRight' }
local function ScanTradeSkills()
	if not addon.db.profile.scanRecipes then return end
	-- Archaeology / Fishing have no recipes
	for _, buttonName in pairs(spellBookSkillButtons) do
		local button = _G[buttonName]
		local profession = button:GetParent()
		-- herbalism / skinning have no recipes
		if profession.skillLine and profession.skillLine ~= 182 and profession.skillLine ~= 393 then
			SpellButton_OnClick(button, 'LeftButton')
			-- addon:Print('Scanning profession %s', profession.skillName)
			ScanTradeSkill()
			CloseTradeSkill()
		end
	end
end

local function ScanForReagents(index)
	if not addon.db.profile.scanRecipes then return end
	for i = 1, GetTradeSkillNumReagents(index) do
		local _, _, reagentCount, playerReagentCount = GetTradeSkillReagentInfo(index, i)
		local link = GetTradeSkillReagentItemLink(index, i)

		local linkType, id = link and link:match("\124H([^:]+):([^:]+)")
					    id = id and tonumber(id, 10)
		if id and recipes.db.char.craftables[id] and playerReagentCount < reagentCount then
			for spellID, data in pairs(recipes.db.char.craftables[id]) do
				local spellLink, tradeLink = GetSpellLink(spellID)
				if recipes.IsTradeSkillKnown(spellID) then
					-- print('could create', link, spellLink, tradeLink)
				else
					-- print(link, 'is craftable via', spellLink, tradeLink, "but you don't know/don't have materials")
				end
			end
		end
	end
end

-- TODO: refactor so we don't nest as deep,
-- opt1: [craftedItemID] = { 'craftSpellID|minYield|maxYield|reagent1:required1|...' , ... }
-- opt2: [craftedItemID] = { [craftSpellID] = 'minYield|maxYield|reagent1:required1|...', ... }
local commonCraftables = {
	-- [craftedItemID] = { [craftSpellID] = {minYield, maxYield, reagent1, required1[, reagent2, required2[, ...] ] } }

	-- Lesser to Greater Essence
	[10939] = { [13361] = {1, 1, 10938, 3} }, -- Magic
	[11082] = { [13497] = {1, 1, 10998, 3} }, -- Astral
	[11135] = { [13632] = {1, 1, 11134, 3} }, -- Mystic
	[11175] = { [13739] = {1, 1, 11174, 3} }, -- Nether
	[16203] = { [20039] = {1, 1, 16202, 3} }, -- Eternal
	[22446] = { [32977] = {1, 1, 22447, 3} }, -- Planar
	[34055] = { [44123] = {1, 1, 34056, 3} }, -- Cosmic
	[52719] = { [74186] = {1, 1, 52718, 3} }, -- Celestial

	-- Greater to Lesser Essence
	[10938] = { [13362] = {3, 3, 10939, 1} }, -- Magic
	[10998] = { [13498] = {3, 3, 11082, 1} }, -- Astral
	[11134] = { [13633] = {3, 3, 11135, 1} }, -- Mystic
	[11174] = { [13740] = {3, 3, 11175, 1} }, -- Nether
	[16202] = { [20040] = {3, 3, 16203, 1} }, -- Eternal
	[22447] = { [32978] = {3, 3, 22446, 1} }, -- Planar
	[34056] = { [44122] = {3, 3, 34055, 1} }, -- Cosmic
	[52718] = { [74187] = {3, 3, 52719, 1} }, -- Celestial

	[52721] = { [74188] = {1, 1, 52720, 3} }, -- Heavenly Shard
	[34052] = { [61755] = {1, 1, 34053, 3} }, -- Dream Shard

	[33568] = { [59926] = {1, 1, 33567, 5} }, -- Borean Leather
	[52976] = { [74493] = {1, 1, 52977, 5} }, -- Savage Leather

	-- Motes to Primal Elementals
	[22451] = { [28100] = {1, 1, 22572, 10} }, -- Air
	[22452] = { [28101] = {1, 1, 22573, 10} }, -- Earth
	[21884] = { [28102] = {1, 1, 22574, 10} }, -- Fire
	[21886] = { [28106] = {1, 1, 22575, 10} }, -- Life
	[22457] = { [28105] = {1, 1, 22576, 10} }, -- Mana
	[22456] = { [28104] = {1, 1, 22577, 10} }, -- Shadow
	[21885] = { [28103] = {1, 1, 22578, 10} }, -- Water

	-- Crystallized to Eternal Elementals
	[35623] = { [49234] = {1, 1, 37700, 10} }, -- Air
	[35624] = { [49248] = {1, 1, 37701, 10} }, -- Earth
	[36860] = { [49244] = {1, 1, 37702, 10} }, -- Fire
	[35625] = { [49247] = {1, 1, 37704, 10} }, -- Life
	[35627] = { [49246] = {1, 1, 37703, 10} }, -- Shadow
	[35622] = { [49245] = {1, 1, 37705, 10} }, -- Water

	-- Eternal to Crystallized Elementals
	[37700] = { [56045] = {10, 10, 35623, 1} }, -- Air
	[37701] = { [56041] = {10, 10, 35624, 1} }, -- Earth
	[37702] = { [56042] = {10, 10, 36860, 1} }, -- Fire
	[37704] = { [56043] = {10, 10, 35625, 1} }, -- Life
	[37703] = { [56044] = {10, 10, 35627, 1} }, -- Shadow
	[37705] = { [56040] = {10, 10, 35622, 1} }, -- Water

	[76061] = { [129352] = {1, 1, 89112, 10} }, -- Spirit of Harmony
	[76734] = { [131776] = {1, 1, 90407, 10} }, -- Serpent's Eye
}

-- http://www.wowpedia.org/TradeSkillLink string.byte, bit
function recipes.IsTradeSkillKnown(craftSpellID)
	-- local professionLink = GetTradeSkillListLink()
	-- if not professionLink then return end
	-- local unitGUID, tradeSpellID, currentRank, maxRank, recipeList = professionLink:match("\124Htrade:([^:]+):([^:]+):([^:]+):([^:]+):([^:\124]+)")

	return IsUsableSpell(craftSpellID)
end

-- IsUsableSpell(craftSpellID) as far as reagents are available
-- /cast <profession name>
-- /run for i=1,GetNumTradeSkills() do if GetTradeSkillInfo(i)==<crafted item> then DoTradeSkill(i, <num>); CloseTradeSkill(); break end end

function recipes:OnEnable()
	self.db = addon.db:RegisterNamespace('Recipes', {
		char = {
			craftables = {},
		},
	})

	hooksecurefunc('TradeSkillFrame_SetSelection', ScanForReagents)

	--[[ -- don't store commons in saved variables!
	for crafted, crafts in pairs(commonCraftables) do
		if not self.db.char.craftables[crafted] then
			self.db.char.craftables[crafted] = {}
		end
		for craftSpell, data in pairs(crafts) do
			self.db.char.craftables[crafted][craftSpell] = data
		end
	end --]]

	if addon.db.profile.autoScanRecipes then
		-- load spellbook or we'll fail
		ToggleSpellBook(_G.BOOKTYPE_PROFESSION)
		ToggleSpellBook(_G.BOOKTYPE_PROFESSION)

		local fullscreenTrigger = CreateFrame('Button', nil, nil, 'SecureActionButtonTemplate')
		fullscreenTrigger:RegisterForClicks('AnyUp')
		fullscreenTrigger:SetAllPoints()
		fullscreenTrigger:SetAttribute('type', 'scanTradeSkills')
		fullscreenTrigger:SetAttribute('_scanTradeSkills', function()
			ScanTradeSkills()
			UnregisterStateDriver(fullscreenTrigger, 'visibility')
			fullscreenTrigger:Hide()
		end)
		RegisterStateDriver(fullscreenTrigger, 'visibility', '[combat] hide; show')
	else
		hooksecurefunc('TradeSkillFrame_Show', ScanTradeSkill)
	end
end
