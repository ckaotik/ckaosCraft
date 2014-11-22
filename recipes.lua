-- scans and stores data on known recipes and how to craft them
local addonName, addon, _ = ...
local recipes = addon:NewModule('Recipes')

-- GLOBALS: _G, LibStub
-- GLOBALS: CreateFrame, SpellButton_OnClick, TradeSkillOnlyShowMakeable, TradeSkillOnlyShowSkillUps, TradeSkillUpdateFilterBar, SelectTradeSkill, RegisterStateDriver, UnregisterStateDriver, CloseTradeSkill
-- GLOBALS: GetTradeSkillSelectionIndex, GetTradeSkillItemNameFilter, GetTradeSkillItemLevelFilter, GetTradeSkillInvSlotFilter, GetTradeSkillInvSlots, GetTradeSkillCategoryFilter, GetTradeSkillSubClasses, SetTradeSkillItemNameFilter, SetTradeSkillItemLevelFilter, SetTradeSkillInvSlotFilter, SetTradeSkillCategoryFilter, TradeSkillSetFilter, ExpandTradeSkillSubClass
-- GLOBALS: ToggleSpellBook, IsUsableSpell, GetSpellLink, IsTradeSkillLinked, GetTradeSkillNumReagents, GetTradeSkillReagentInfo, GetTradeSkillReagentItemLink, GetNumTradeSkills, GetTradeSkillInfo, GetTradeSkillNumMade, GetTradeSkillItemLink, GetTradeSkillRecipeLink, GetTradeSkillListLink
-- GLOBALS: wipe, select, pairs, hooksecurefunc, tonumber, strsplit, strjoin
local tinsert = table.insert

local skillLineMappings = {
	-- primary crafting
	[171] =  2259, -- 'Alchemy',
	[164] =  2018, -- 'Blacksmithing',
	[333] =  7411, -- 'Enchanting',
	[202] =  4036, -- 'Engineering',
	[773] = 45357, -- 'Inscription',
	[755] = 25229, -- 'Jewelcrafting',
	[165] =  2108, -- 'Leatherworking',
	[197] =  3908, -- 'Tailoring',
	-- primary gathering
	[182] = 13614, -- 'Herbalism',
	[186] =  2575, -- 'Mining',
	[393] =  8613, -- 'Skinning',
	-- secondary
	[794] = 78670, -- 'Archaeology',
	[184] =  2550, -- 'Cooking',
	[129] =  3273, -- 'First Aid',
	[356] =  7620, -- 'Fishing',
}

local function GetItemRecipes(craftedItemID)
	-- FIXME: this needs love, lots of love
	return recipes.db.char.craftables and recipes.db.char.craftables[craftedItemID]
end

local function ReadData(craftedItemID, craftSpellID, professionID)
	local craftables = recipes.db.char.craftables
	if craftables and craftables[craftedItemID] then
		for craft, data in pairs(craftables[craftedItemID]) do
			local profID, spellID = strsplit('|', craft)
			if (not craftSpellID or spellID == craftSpellID) and (not professionID or profID == professionID) then
				local min, max, reagents = strsplit('|', data, 3)
				return craftedItemID, spellID, profID, min, max, reagents
			end
		end
	end
end

local function WriteData(craftedItemID, craftSpellID, professionID, min, max, ...)
	if not ... then return end
	if not recipes.db.char.craftables[craftedItemID] then
		recipes.db.char.craftables[craftedItemID] = {}
	end
	local craftID   = (professionID or '') .. '|' .. craftSpellID
	local craftData = min .. '|' .. max
	if type(...) == 'table' then
		local craftInfo = ...
		for i = 1, #craftInfo, 2 do
			local reagentID, amount = craftInfo[i], craftInfo[i+1]
			craftData = craftData .. '|' .. reagentID .. ':' .. (amount or 1)
		end
	else
		for i = 1, select('#', ...), 2 do
			local reagentID, amount = select(i, ...)
			craftData = craftData .. '|' .. reagentID .. ':' .. (amount or 1)
		end
	end
	recipes.db.char.craftables[craftedItemID][craftID] = craftData
end

local reagentsTable = {}
local function FillReagentsTable(reagentID, amount)
	reagentsTable[tonumber(reagentID)] = tonumber(amount)
end
local function ParseReagentsString(reagentsString)
	wipe(reagentsTable)
	string.gsub(reagentsString, '([^:|]+):([^:|]+)', FillReagentsTable)
	return reagentsTable
end

local function WipeProfessionData(professionID)
	for craftedItemID, crafts in pairs(recipes.db.char.craftables) do
		for craftID, craftData in pairs(crafts) do
			local profID, craftSpellID = strsplit('|', craftID)
			if profID == professionID then
				recipes.db.char.craftables[craftedItemID][craftID] = nil
			end
		end
	end
end

-- --------------------------------------------------------
--  Recipe Scanning
-- --------------------------------------------------------
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
local function RemoveFilters()
	ExpandTradeSkillSubClass(0) -- TODO: isn't currently saved/restored
	SetTradeSkillItemLevelFilter(0, 0)
    SetTradeSkillItemNameFilter(nil)
    TradeSkillSetFilter(-1, -1)
    -- TradeSkillFrame_Update()
end

local craftInfo = {}
local function ScanTradeSkill()
	-- TODO: IsTradeSkillReady() seems to be false on first init
	-- TODO: maybe even allow reagent crafting for linked skills, assuming we have the skill, too
	if IsTradeSkillLinked() or not IsTradeSkillReady() then return end

	local professionLink = GetTradeSkillListLink()
	if not professionLink then return end
	local unitGUID, _, professionSkill = professionLink:match('trade:([^:]+):([^:]+):([^:\124]+)')
	                   professionSkill = tonumber(professionSkill)
	WipeProfessionData(professionSkill)

	SaveFilters()
	RemoveFilters()
	for index = 1, GetNumTradeSkills() do
		local skillName, skillType = GetTradeSkillInfo(index)
		if skillName and not skillType:find('header') then
			local crafted   = GetTradeSkillItemLink(index)
			local craftedID = crafted:match('enchant:(%d+)')
				  craftedID = craftedID and -1*craftedID or 1*crafted:match('item:(%d+)')
			local craftSpellID = GetTradeSkillRecipeLink(index)
				  craftSpellID = 1*craftSpellID:match('enchant:(%d+)')

			wipe(craftInfo)
			for i = 1, GetTradeSkillNumReagents(index) do
				local _, _, amount = GetTradeSkillReagentInfo(index, i)
				-- FIXME: when item data is not available, our saved data gets corrupted!
				local reagent = GetTradeSkillReagentItemLink(index, i)
					  reagent = reagent and 1*reagent:match('item:(%d+)')
				if reagent and amount > 0 then
					tinsert(craftInfo, reagent)
					tinsert(craftInfo, amount)
				end
			end
			local minYield, maxYield = GetTradeSkillNumMade(index)
			WriteData(craftedID, craftSpellID, professionSkill, minYield, maxYield, unpack(craftInfo))
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

-- --------------------------------------------------------
--  Reagent Display
-- --------------------------------------------------------
local emptyTable = {}
local commonCraftables = {
	-- [craftedItemID] = { ['profID|craftSpellID'] = 'min|max|reagent1:num1|reagent2:num2|...' }

	-- Lesser to Greater Essence
	[10939] = { ['|13361'] = '1|1|10938|3' }, -- Magic
	[11082] = { ['|13497'] = '1|1|10998|3' }, -- Astral
	[11135] = { ['|13632'] = '1|1|11134|3' }, -- Mystic
	[11175] = { ['|13739'] = '1|1|11174|3' }, -- Nether
	[16203] = { ['|20039'] = '1|1|16202|3' }, -- Eternal
	[22446] = { ['|32977'] = '1|1|22447|3' }, -- Planar
	[34055] = { ['|44123'] = '1|1|34056|3' }, -- Cosmic
	[52719] = { ['|74186'] = '1|1|52718|3' }, -- Celestial

	-- Greater to Lesser Essence
	[10938] = { ['|13362'] = '3|3|10939|1' }, -- Magic
	[10998] = { ['|13498'] = '3|3|11082|1' }, -- Astral
	[11134] = { ['|13633'] = '3|3|11135|1' }, -- Mystic
	[11174] = { ['|13740'] = '3|3|11175|1' }, -- Nether
	[16202] = { ['|20040'] = '3|3|16203|1' }, -- Eternal
	[22447] = { ['|32978'] = '3|3|22446|1' }, -- Planar
	[34056] = { ['|44122'] = '3|3|34055|1' }, -- Cosmic
	[52718] = { ['|74187'] = '3|3|52719|1' }, -- Celestial

	[52721] = { ['|74188'] = '1|1|52720|3' }, -- Heavenly Shard
	[34052] = { ['|61755'] = '1|1|34053|3' }, -- Dream Shard

	[33568] = { ['|59926'] = '1|1|33567|5' }, -- Borean Leather
	[52976] = { ['|74493'] = '1|1|52977|5' }, -- Savage Leather

	-- Motes to Primal Elementals
	[22451] = { ['|28100'] = '1|1|22572|10' }, -- Air
	[22452] = { ['|28101'] = '1|1|22573|10' }, -- Earth
	[21884] = { ['|28102'] = '1|1|22574|10' }, -- Fire
	[21886] = { ['|28106'] = '1|1|22575|10' }, -- Life
	[22457] = { ['|28105'] = '1|1|22576|10' }, -- Mana
	[22456] = { ['|28104'] = '1|1|22577|10' }, -- Shadow
	[21885] = { ['|28103'] = '1|1|22578|10' }, -- Water

	-- Crystallized to Eternal Elementals
	[35623] = { ['|49234'] = '1|1|37700|10' }, -- Air
	[35624] = { ['|49248'] = '1|1|37701|10' }, -- Earth
	[36860] = { ['|49244'] = '1|1|37702|10' }, -- Fire
	[35625] = { ['|49247'] = '1|1|37704|10' }, -- Life
	[35627] = { ['|49246'] = '1|1|37703|10' }, -- Shadow
	[35622] = { ['|49245'] = '1|1|37705|10' }, -- Water

	-- Eternal to Crystallized Elementals
	[37700] = { ['|56045'] = '10|10|35623|1' }, -- Air
	[37701] = { ['|56041'] = '10|10|35624|1' }, -- Earth
	[37702] = { ['|56042'] = '10|10|36860|1' }, -- Fire
	[37704] = { ['|56043'] = '10|10|35625|1' }, -- Life
	[37703] = { ['|56044'] = '10|10|35627|1' }, -- Shadow
	[37705] = { ['|56040'] = '10|10|35622|1' }, -- Water

	[76061] = { ['|129352'] = '1|1|89112|10' }, -- Spirit of Harmony
	[76734] = { ['|131776'] = '1|1|90407|10' }, -- Serpent's Eye

	-- TODO: add WoD combines, add low-level gathering combines
}

local function ScanForReagents(index, ...)
	for i = 1, GetTradeSkillNumReagents(index) do
		local _, _, reagentCount, playerReagentCount = GetTradeSkillReagentInfo(index, i)
		local link = GetTradeSkillReagentItemLink(index, i)
		if link then
			local linkType, itemID = link:match('\124H([^:]+):([^:]+)')
						    itemID = itemID and tonumber(itemID)
			-- we know this reagent can be crafted and we need some more of it
			if playerReagentCount < reagentCount and itemID then
				-- TODO: scan all char's recipes
				local _, spellID, professionID, min, max, reagents = ReadData(itemID)
				if spellID then
					local spellLink = GetSpellLink(spellID)
					-- local spellLink = spellID < 0 and ('enchant:'..(-1*spellID)) or ('spell:'..spellID)
					--       spellLink = GetFixedLink(spellLink)
					if recipes.IsTradeSkillKnown(spellID) then
						-- print('could create', link, spellLink)
					else
						-- print(link, 'is craftable via', spellLink, 'but you don\'t know/don\'t have materials')
					end
				end
			end
		end
	end
end

local function GetMacroText(craftSpellID, numCrafts, profession)
	-- we need the profession's name
	profession = type(profession) == 'number' and (GetSpellInfo(skillLineMappings[profession])) or profession

	local macro = ''
	if profession and _G.CURRENT_TRADESKILL ~= profession then
		macro = macro .. '/cast '..profession..'\n'
	end
	-- the actual casting
	macro = macro .. '/run for i=1,GetNumTradeSkills() do if GetTradeSkillRecipeLink(i):match("enchant:'..craftSpellID..'\124") then DoTradeSkill(i,'..(numCrafts or 1)..') break end end'
	-- macro = macro .. '/run for i=1,GetNumTradeSkills() do if GetTradeSkillInfo(i)==<crafted item> then DoTradeSkill(i, <num>); CloseTradeSkill(); break end end'
	-- returning to where we were before
	-- macro = macro .. '/cast '.._G.CURRENT_TRADESKILL..'\n'
	-- macro = macro .. '/run TradeSkillFrame_SetSelection('..GetTradeSkillSelectionIndex()..')'
	return macro
end

-- http://www.wowpedia.org/TradeSkillLink string.byte, bit
function recipes.IsTradeSkillKnown(craftSpellID)
	-- local professionLink = GetTradeSkillListLink()
	-- if not professionLink then return end
	-- local unitGUID, tradeSpellID, currentRank, maxRank, recipeList = professionLink:match("\124Htrade:([^:]+):([^:]+):([^:]+):([^:]+):([^:\124]+)")

	-- take a shortcut when possible
	if IsUsableSpell(craftSpellID) then
		-- craft is known and reagents are available
		return true
	end

	-- is this a common spell such as combine motes or split essences
	for craftedItemID, sources in pairs(commonCraftables) do
		for craft, data in pairs(sources) do
			local profID, craftSpell = strsplit('|', craft)
			if craft == craftSpellID then
				return true
			end
		end
	end

	-- scan our saved profession info
	for craftedItemID, sources in pairs(recipes.db.char.craftables) do
		for craft, data in pairs(sources) do
			local profID, craftSpell = strsplit('|', craft)
			if craftSpell == craftSpellID then
				return true
			end
		end
	end
end

-- --------------------------------------------------------
--  Module Setup
-- --------------------------------------------------------
function recipes:OnEnable()
	self.db = addon.db:RegisterNamespace('Recipes', {
		char = {
			craftables = {},
		},
	})
	--[[ setmetatable(recipes.db.char.craftables, {
		-- TODO: check if recipe is known via commonCraftables
	}) --]]

	-- scanning part
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

			hooksecurefunc('TradeSkillFrame_Show', ScanTradeSkill)
		end)
		RegisterStateDriver(fullscreenTrigger, 'visibility', '[combat] hide; show')
	else
		hooksecurefunc('TradeSkillFrame_Show', ScanTradeSkill)
	end

	-- display part
	hooksecurefunc('TradeSkillFrame_SetSelection', ScanForReagents)
end
