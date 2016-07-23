-- allows to easily craft reagents for current recipe
local addonName, addon, _ = ...
local plugin = addon:NewModule('ReagentMaker', 'AceEvent-3.0')

-- GLOBALS: C_TradeSkillUI
-- GLOBALS: pairs, print

local function OnReagentDoubleClick(self, ...)
	-- print('OnReagentDoubleClick', self, ...)
	local recipeID = self:GetParent():GetParent().selectedRecipeID
	local reagentIndex = self.reagentIndex

	local name, texture, count, playerCount = C_TradeSkillUI.GetRecipeReagentInfo(recipeID, reagentIndex)

	local itemLink = C_TradeSkillUI.GetRecipeReagentItemLink(recipeID, reagentIndex)
	local itemID, linkType = addon.GetLinkID(itemLink)

	local currentTradeSkillID, currentProfessionName, rank, maxRank, skillLineModifier = C_TradeSkillUI.GetTradeSkillLine()

	local recipes = plugin.recipes.db.char.craftables[itemID]
	-- local recipeSpells = {}
	for spellID, data in pairs(recipes) do
		local profID, profName = C_TradeSkillUI.GetTradeSkillLineForRecipe(spellID)
		local min, max, reagents = plugin.recipes:ParseRecipeData(data)

		-- local recipeInfo = C_TradeSkillUI.GetRecipeInfo(spellID)
		print(name, 'crafted by', spellID, C_TradeSkillUI.GetRecipeLink(spellID), profID, profName, min, max, reagents:gsub('|', '/'))
		-- table.insert(recipeSpells, spellID)
	end

	-- C_TradeSkillUI.IsAnyRecipeFromSource(sourceType)
	-- C_TradeSkillUI.OpenTradeSkill(tradeSkillID)
	-- local skillID = C_TradeSkillUI.GetTradeSkillLineForRecipe(spellID)
end

--[[ local function GetMacroText(craftSpellID, numCrafts, profession)
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

local function ScanForReagents(self, index, ...)
	if not index then return end
	for i = 1, C_TradeSkillUI.GetRecipeNumReagents(index) do
		local _, _, reagentCount, playerReagentCount = C_TradeSkillUI.GetRecipeReagentInfo(index, i)
		local link = C_TradeSkillUI.GetRecipeItemLink(index, i)
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
					if plugin.IsTradeSkillKnown(spellID) then
						-- print('could create', link, spellLink)
					else
						-- print(link, 'is craftable via', spellLink, 'but you don\'t know/don\'t have materials')
					end
				end
			end
		end
	end
end --]]

-- TradeSkillFrame.DetailsFrame:RefreshDisplay()
function plugin:OnEnable()
	self.recipes = addon:GetModule('Recipes')

	local reagents = TradeSkillFrame.DetailsFrame.Contents.Reagents
	for reagentIndex = 1, #reagents do
		local reagentButton = reagents[reagentIndex]
		reagentButton:HookScript('OnDoubleClick', OnReagentDoubleClick)
	end
end
