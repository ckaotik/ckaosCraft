-- provides a more powerful search engine using LibItemSearch
local addonName, addon, _ = ...
local search = addon:NewModule('Search', 'AceEvent-3.0')

-- GLOBALS: _G, LibStub
-- GLOBALS: FauxScrollFrame_GetOffset, FauxScrollFrame_Update, TradeSkillFrame_Update, GetTradeSkillSelectionIndex, TradeSkillFrame_SetSelection, IsTradeSkillGuild, GetNumTradeSkills, GetTradeSkillInfo, GetTradeSkillItemLink, GetTradeSkillReagentItemLink, TradeSkilSubSkillRank_Set
-- GLOBALS: pairs, hooksecurefunc, wipe
local abs = math.abs

local ItemSearch = LibStub('LibItemSearch-1.2')
local searchResultCache, searchQuery = setmetatable({}, {
	__mode = 'kv',
})

local function SearchRow(query, index)
	if not query then return true end
	local cache = searchResultCache
	local key   = GetTradeSkillRecipeLink(index)
	local itemLink = GetTradeSkillItemLink(index)

	if cache and cache.query ~= query then
		wipe(cache)
		cache.query = query
	elseif cache[key] ~= nil then
		return cache[key]
	end

	if itemLink and ItemSearch:Matches(itemLink, query) then
		cache[key] = true
	else -- check reagents
		for reagentIndex = 1, MAX_TRADE_SKILL_REAGENTS do
			local reagentLink = GetTradeSkillReagentItemLink(index, reagentIndex)
			if reagentLink and ItemSearch:Matches(reagentLink, query) then
				cache[key] = true
				break
			end
		end
	end
	return cache[key]
end

local function UpdateTradeSkillRow(button, index, selected, isGuild)
	local skillName, skillType, numAvailable, isExpanded, serviceType, numSkillUps, indentLevel, showProgressBar, currentRank, maxRank, startingRank = GetTradeSkillInfo(index)

	local color       = _G.TradeSkillTypeColor[skillType]
	local prefix      = _G.ENABLE_COLORBLIND_MODE == '1' and _G.TradeSkillTypePrefix[skillType] or ' '
	local indentDelta = indentLevel > 0 and 20 or 0
	local textWidth   = _G.TRADE_SKILL_TEXT_WIDTH - indentDelta
	local usedWidth   = 0

	local skillUps, rankBar = button.skillup, button.SubSkillRankBar
	if skillType == 'header' or skillType == 'subheader' then
		-- headers / rank bar
		if showProgressBar then
			TradeSkilSubSkillRank_Set(rankBar, skillName, currentRank, startingRank, maxRank)
			textWidth = textWidth - _G.SUB_SKILL_BAR_WIDTH
			rankBar:Show()
		end
		button.text:SetWidth(textWidth)
		button.count:SetText('')
		button:SetNormalTexture('Interface\\Buttons\\' .. (isExpanded and 'UI-MinusButton-Up' or 'UI-PlusButton-Up'))
		button:GetHighlightTexture():SetTexture('Interface\\Buttons\\UI-PlusButton-Hilight')
		button:SetText(skillName)
	else
		-- guild color override
		if isGuild then color = _G.TradeSkillTypeColor['easy'] end

		button:SetNormalTexture('')
		button:GetHighlightTexture():SetTexture('')
		button:SetText(prefix .. skillName)

		if numAvailable > 0 then
			button.count:SetText('['..numAvailable..']')
			local nameWidth, countWidth = button.text:GetStringWidth(), button.count:GetStringWidth()
			if (nameWidth + 2 + countWidth) > (textWidth - usedWidth) then
				textWidth = textWidth - 2 - countWidth - usedWidth
			else
				textWidth = 0
			end
		else
			button.count:SetText('')
			textWidth = textWidth - usedWidth
		end
		button.text:SetWidth(textWidth)
	end

	-- update highlight state
	if index == selected then
		_G.TradeSkillHighlightFrame:SetPoint('TOPLEFT', button, 'TOPLEFT', 0, 0)
		_G.TradeSkillHighlightFrame:Show()
		button:LockHighlight()
		button.isHighlighted = true

		-- update craft details
		TradeSkillFrame_SetSelection(index)
		-- Set the max makeable items for the create all button
		_G.TradeSkillFrame.numAvailable = abs(numAvailable)
	else
		button:UnlockHighlight()
		button.isHighlighted = false
	end

	-- button colors
	button:SetNormalFontObject(color.font)
	button.font = color.font
	if button.isHighlighted then color = _G.HIGHLIGHT_FONT_COLOR end
	button.r, button.g, button.b = color.r, color.g, color.b
	button.text:SetVertexColor(color.r, color.g, color.b)
	button.count:SetVertexColor(color.r, color.g, color.b)

	-- multiskill
	if numSkillUps > 1 and skillType == 'optimal' then
		usedWidth = _G.TRADE_SKILL_SKILLUP_TEXT_WIDTH
		skillUps.countText:SetText(numSkillUps)
		skillUps:Show()
	else
		skillUps:Hide()
	end
	skillUps.countText:SetVertexColor(color.r, color.g, color.b)
	skillUps.icon:SetVertexColor(color.r, color.g, color.b)

	-- indent
	button:GetNormalTexture():SetPoint('LEFT', 3 + indentDelta, 0)
	button:GetDisabledTexture():SetPoint('LEFT', 3 + indentDelta, 0)
	button:GetHighlightTexture():SetPoint('LEFT', 3 + indentDelta, 0)

	button:SetID(index)
	button:Show()
	search:SendMessage('TRADE_SKILL_ROW_UPDATE', button, index, selected, isGuild)
end

local headerParents = {}
local function UpdateTradeSkillList()
	-- TODO: when selection does not fulfill search, select first child
	if not addon.db.profile.customSearch then return end

	local query = _G.TradeSkillFrame.search
	if not query or query == '' or query == _G.SEARCH or not _G.TradeSkillFrameSearchBox:IsEnabled() then return end

	local offset     = FauxScrollFrame_GetOffset(_G.TradeSkillListScrollFrame)
	local isGuild    = IsTradeSkillGuild()
	local selected   = GetTradeSkillSelectionIndex()
	local isFiltered = _G.TradeSkillFilterBar:IsShown()
	_G.TradeSkillHighlightFrame:Hide()

	local buttonIndex, numRows, numDataRows = isFiltered and 2 or 1, 0, 0
	local headerState, nextDataRow = nil, buttonIndex
	for index = 1, GetNumTradeSkills() do
		local skillName, skillType, numAvailable, isExpanded, serviceType, numSkillUps, indentLevel, showProgressBar, currentRank, maxRank, startingRank = GetTradeSkillInfo(index)
		local isHeader = (skillType == 'header' and 1) or (skillType == 'subheader' and 2) or nil

		-- hide nested collapsed rows
		local isHidden = false
		for level, isCollapsed in ipairs(headerParents) do
			if not isHeader or level < isHeader then
				-- state depends on parent's state
				isHidden = isHidden or isCollapsed
			elseif level > isHeader then
				-- remove deeper levels
				headerParents[level] = nil
			end
		end

		local matchesSearch = (isHeader and true) or SearchRow(query, index)
		if isHeader then
			-- Note: This is commented out because we cannot know what contents collapsed categories have
			--[[ if isHeader <= #headerParents then
				-- remove empty sibling/parent headers
				while nextDataRow < buttonIndex do
					buttonIndex = buttonIndex - 1
					numRows     = numRows - 1
				end
			end --]]
			headerParents[isHeader] = not isExpanded and true or false
			numRows = numRows + 1

			-- compare state for "toggle all" button
			local state = isExpanded and 'expanded' or 'collapsed'
			if headerState == nil then
				headerState = state
			elseif headerState and headerState ~= state then
				headerState = false
			end
		elseif matchesSearch then
			-- this row matches, even though it may not be displayed
			numRows = numRows + 1
			numDataRows = numDataRows + 1
			nextDataRow = buttonIndex + (isHidden and 0 or 1)
		end

		local button = _G['TradeSkillSkill'..buttonIndex]
		if button and index > offset and matchesSearch and not isHidden then
			UpdateTradeSkillRow(button, index, selected, isGuild)
			buttonIndex = buttonIndex + 1
		end
	end

	-- buttonIndex = nextDataRow or buttonIndex -- this causes the last collapsed group to vanish
	local button = _G['TradeSkillSkill'..buttonIndex]
	while button do
		-- hide unused buttons
		button:Hide()
		button:UnlockHighlight()
		button.isHighlighted = false
		buttonIndex = buttonIndex + 1
		button = _G['TradeSkillSkill'..buttonIndex]
	end

	-- update scroll bar
	FauxScrollFrame_Update(_G.TradeSkillListScrollFrame, numRows, _G.TRADE_SKILLS_DISPLAYED, _G.TRADE_SKILL_HEIGHT, nil, nil, nil, nil, nil, nil, true)

	-- Set the expand/collapse all button texture
	local collapseAll = _G.TradeSkillCollapseAllButton
	if headerState == 'expanded' then
		collapseAll.collapsed = nil
		collapseAll:SetNormalTexture('Interface\\Buttons\\UI-MinusButton-Up')
	else
		collapseAll.collapsed = 1
		collapseAll:SetNormalTexture('Interface\\Buttons\\UI-PlusButton-Up')
	end
end

-- TODO: add slight delay. see Twinkle/Search
local function UpdateTradeSkillSearch(self, isUserInput)
	InputBoxInstructions_OnTextChanged(self)
	local text = self:GetText()
	self:GetParent().search = text ~= '' and text or nil
	TradeSkillFrame_Update()
end

local function ShowSearchTooltip(button, tooltip)
	local color = _G.NORMAL_FONT_COLOR_CODE
	local r, g, b = _G.NORMAL_FONT_COLOR.r, _G.NORMAL_FONT_COLOR.g, _G.NORMAL_FONT_COLOR.b

	tooltip:AddLine('Search hints:')
	for key, label in pairs({
		['Name']     = 'n',
		['Type']     = 't, slot',
		['Quality']  = 'q',
		['Level']    = 'l, lvl',
		['Binding']  = 'bop, boe, boa, bou, quest, bound',
		['Equipment sets'] = 's (* to match any)',
		['Tooltip']  = 'tt, tip',
	}) do
		tooltip:AddDoubleLine(key, label, r, g, b, 1, 1, 1)
	end
	tooltip:AddLine(' ')
	tooltip:AddLine('Examples:', r, g, b)
	tooltip:AddDoubleLine('l: > 200 & boe', 'BoE items with level > 200')
	tooltip:AddDoubleLine('q: epic & gladiator', 'Epics named gladiator')
	tooltip:AddLine('Combine using ' ..color..'!|r (don\'t match), '..color..'&|r (and), '..color..'|||r (or)')
end

local function InitializeTradeSkillFrame(event, ...)
	if not addon.db.profile.customSearch then return end
	search:UnregisterEvent('TRADE_SKILL_SHOW')

	local orig_searchBox = _G.TradeSkillFrameSearchBox
	      orig_searchBox:Hide()
	local searchBox = CreateFrame('EditBox', '$parentAdvancesSearchBox', _G.TradeSkillFrame, 'SearchBoxTemplate')
	      searchBox:SetAllPoints(orig_searchBox)
	      searchBox.tiptext = ShowSearchTooltip
	_G.TradeSkillFrame.searchBox = searchBox

	searchBox:SetScript('OnEnter', addon.ShowTooltip)
	searchBox:SetScript('OnLeave', addon.HideTooltip)
	searchBox:SetScript('OnTextChanged', UpdateTradeSkillSearch)
	searchBox:SetScript('OnEnterPressed', EditBox_ClearFocus)
	searchBox:SetScript('OnEscapePressed', function(self) self.clearButton:Click() end)
	searchBox.clearFunc = function(self) TradeSkillFrame_Update() end
end

function search:OnEnable()
	self:RegisterEvent('TRADE_SKILL_SHOW', InitializeTradeSkillFrame)
	hooksecurefunc('TradeSkillFrame_Update', UpdateTradeSkillList)
end

function search:OnDisable()
	self:UnregisterEvent('TRADE_SKILL_SHOW')
	-- show original search box again
	_G.TradeSkillFrame.searchBox:Hide()
	_G.TradeSkillFrameSearchBox:Show()
end
