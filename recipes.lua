-- scans and stores data on known recipes and how to craft them
local addonName, addon, _ = ...
local plugin = addon:NewModule('Recipes', 'AceEvent-3.0')

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
	return plugin.db.char.craftables and plugin.db.char.craftables[craftedItemID]
end

local function WipeProfessionData(professionID)
	for craftedItemID, crafts in pairs(plugin.db.char.craftables) do
		for recipeID, data in pairs(crafts) do
			if type(recipeID) ~= 'number' or C_TradeSkillUI.GetTradeSkillLineForRecipe(recipeID) == professionID then
				plugin.db.char.craftables[craftedItemID][recipeID] = nil
			end
		end
	end
end

local function ReadData(craftedItemID, craftSpellID, professionID)
	local craftables = plugin.db.char.craftables
	if not craftables or not craftables[craftedItemID] then
		return
	end

	for spellID, data in pairs(craftables[craftedItemID]) do
		local profID = C_TradeSkillUI.GetTradeSkillLineForRecipe(spellID)
		if (not craftSpellID or spellID == craftSpellID) and (not professionID or profID == professionID) then
			return craftedItemID, spellID, profID, plugin:ParseRecipeData(data)
		end
	end
end

local function WriteData(craftedItemID, recipeID, min, max, ...)
	if not ... then return end
	if not plugin.db.char.craftables[craftedItemID] then
		plugin.db.char.craftables[craftedItemID] = {}
	end
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
	plugin.db.char.craftables[craftedItemID][recipeID] = craftData
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

-- --------------------------------------------------------
--  Recipe Scanning
-- --------------------------------------------------------
local craftInfo = {}
local function ScanRecipe(recipeID, recipeInfo)
	-- local {reqName, uncolored}* = C_TradeSkillUI.GetRecipeTools(recipeID)
	-- local timeLeft, isDayCooldown, charges, maxCharges = C_TradeSkillUI.GetRecipeCooldown(recipeID)

	local craftedLink = C_TradeSkillUI.GetRecipeItemLink(recipeID)
	local craftedID, linkType = addon.GetLinkID(craftedLink)
	if linkType == 'enchant' then craftedID = -1 * craftedID end

	wipe(craftInfo)
	for i = 1, C_TradeSkillUI.GetRecipeNumReagents(recipeID) do
		local _, _, required = C_TradeSkillUI.GetRecipeReagentInfo(recipeID, i)
		-- FIXME: when item data is not available, our saved data gets corrupted!
		local reagent = C_TradeSkillUI.GetRecipeReagentItemLink(recipeID, i)
			  reagent = reagent and 1*reagent:match('item:(%d+)')
		if reagent and required > 0 then
			tinsert(craftInfo, reagent)
			tinsert(craftInfo, required)
		end
	end
	local minYield, maxYield = C_TradeSkillUI.GetRecipeNumItemsProduced(recipeID)
	WriteData(craftedID, recipeID, minYield, maxYield, unpack(craftInfo))
end

local function ScanTradeSkill()
	if not C_TradeSkillUI.IsTradeSkillReady()
		or C_TradeSkillUI.IsTradeSkillLinked() or C_TradeSkillUI.IsTradeSkillGuild()
		or C_TradeSkillUI.IsNPCCrafting()
		or C_TradeSkillUI.IsDataSourceChanging() then
		return
	end

	local professionID = C_TradeSkillUI.GetTradeSkillLine()
	WipeProfessionData(professionID)

	local recipes = C_TradeSkillUI.GetAllRecipeIDs()
	for _, recipeID in ipairs(recipes) do
		local recipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeID)
		if recipeInfo and recipeInfo.learned then
			ScanRecipe(recipeID, recipeInfo)
		end
		wipe(recipeInfo)
	end
end

local spellBookSkillButtons = { 'PrimaryProfession1SpellButtonBottom', 'PrimaryProfession2SpellButtonBottom', 'SecondaryProfession3SpellButtonRight', 'SecondaryProfession4SpellButtonRight' }
local function ScanTradeSkills()
	local professions = { GetProfessions() }
	local delay = 0.02
	for index, profession in pairs(professions) do
		if profession then
			local name, _, _, _, _, _, skillLine = GetProfessionInfo(profession)
			C_Timer.After(delay * (index - 1), function() C_TradeSkillUI.OpenTradeSkill(skillLine) end)
		end
	end
	C_Timer.After(delay * #professions, C_TradeSkillUI.CloseTradeSkill)
	wipe(professions)
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
	[110609] = { ['|159069'] = '1|1|110610:10' }, -- Raw Beasthide Scraps
}

-- http://www.wowpedia.org/TradeSkillLink string.byte, bit
function plugin.IsTradeSkillKnown(craftSpellID)
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
	for craftedItemID, sources in pairs(plugin.db.char.craftables) do
		for craft, data in pairs(sources) do
			local profID, craftSpell = strsplit('|', craft)
			if craftSpell == craftSpellID then
				return true
			end
		end
	end
end

function plugin:ParseRecipeData(data)
	local min, max, reagents = strsplit('|', data, 3)
	return min, max, reagents
end

-- --------------------------------------------------------
--  Module Setup
-- --------------------------------------------------------
function plugin:OnEnable()
	self.db = addon.db:RegisterNamespace('Recipes', {
		char = {
			craftables = {
				-- ['*'] = { -- crafted itemID
					-- [recipeID] = 'min|max|reagents'
				-- },
			},
		},
	})
	--[[ setmetatable(plugin.db.char.craftables, {
		-- TODO: check if recipe is known via commonCraftables
	}) --]]

	self:RegisterEvent('TRADE_SKILL_DATA_SOURCE_CHANGED', ScanTradeSkill)

	-- scanning part
	if addon.db.profile.scanRecipes and addon.db.profile.autoScanRecipes then
		ScanTradeSkills()
	end
	-- TRADE_SKILL_DATA_SOURCE_CHANGING
	-- TRADE_SKILL_DATA_SOURCE_CHANGED
	-- UPDATE_TRADESKILL_RECAST
end


function plugin:OnDisable()
	self:UnregisterEvent('TRADE_SKILL_DATA_SOURCE_CHANGED')
end
