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
		button:SetText(skillName)
		button:SetNormalTexture('Interface\\Buttons\\' .. (isExpanded and 'UI-MinusButton-Up' or 'UI-PlusButton-Up'))
		button:GetHighlightTexture():SetTexture('Interface\\Buttons\\UI-PlusButton-Hilight')
		button:UnlockHighlight()
		button.isHighlighted = false
	else
		-- multiskill
		if numSkillUps > 1 and skillType == 'optimal' then
			usedWidth = _G.TRADE_SKILL_SKILLUP_TEXT_WIDTH
			skillUps.countText:SetText(numSkillUps)
			skillUps:Show()
		else
			skillUps:Hide()
		end

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

		-- Place the highlight and lock the highlight state
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
	end

	-- color
	button:SetNormalFontObject(color.font)
	button.font = color.font
	if button.isHighlighted then color = _G.HIGHLIGHT_FONT_COLOR end
	button.text:SetVertexColor(color.r, color.g, color.b)
	button.count:SetVertexColor(color.r, color.g, color.b)
	skillUps.countText:SetVertexColor(color.r, color.g, color.b)
	skillUps.icon:SetVertexColor(color.r, color.g, color.b)
	button.r, button.g, button.b = color.r, color.g, color.b

	-- indent
	button:GetNormalTexture():SetPoint('LEFT', 3 + indentDelta, 0)
	button:GetDisabledTexture():SetPoint('LEFT', 3 + indentDelta, 0)
	button:GetHighlightTexture():SetPoint('LEFT', 3 + indentDelta, 0)

	button:SetID(index)
	button:Show()
	search:SendMessage('TRADE_SKILL_ROW_UPDATE', button, index, selected, isGuild)
end

local function UpdateTradeSkillList()
	if not addon.db.profile.customSearch then return end

	local searchText = _G.TradeSkillFrame.search
	if not searchText or searchText == _G.SEARCH or not _G.TradeSkillFrameSearchBox:IsEnabled() then return end
	if searchText ~= searchQuery then wipe(searchResultCache) end
	searchQuery = searchText

	local offset    = FauxScrollFrame_GetOffset(_G.TradeSkillListScrollFrame)
	local isGuild   = IsTradeSkillGuild()
	local selected  = GetTradeSkillSelectionIndex()
	local numHeaders, notExpanded = 0, 0
	_G.TradeSkillHighlightFrame:Hide()

	-- ignore the first matches we have scrolled past
	local buttonIndex = 1 - offset
	local lastType, sndLastType = nil, nil
	local numItems = 0
	for index = 1, GetNumTradeSkills() do
		local isHeader = false
		local skillName, skillType, numAvailable, isExpanded, serviceType, numSkillUps, indentLevel, showProgressBar, currentRank, maxRank, startingRank = GetTradeSkillInfo(index)

		local matchesSearch = false
		if skillType == 'header' or skillType == 'subheader' then
			if skillType == lastType or (lastType == 'subheader' and skillType == 'header') then
				-- FIXME: prevent collapsed headers from hiding, see Twinkle lists
				-- hide empty groups
				buttonIndex = buttonIndex - 1
				numItems    = numItems - 1
				lastType    = nil
				if sndLastType == 'header' then
					-- header - subheader - header, go back 2 steps
					buttonIndex = buttonIndex - 1
					numItems    = numItems - 1
					sndLastType = nil
				end
			end
			isHeader      = true
			matchesSearch = true
		elseif skillName then
			if searchResultCache[index] ~= nil then
				matchesSearch = searchResultCache[index]
			else
				matchesSearch = ItemSearch:Matches(GetTradeSkillItemLink(index), searchText)
				local reagentIndex = 0
				while not matchesSearch do
					reagentIndex = reagentIndex + 1
					local reagentLink = GetTradeSkillReagentItemLink(index, reagentIndex)
					if not reagentLink then break end
					matchesSearch = ItemSearch:Matches(reagentLink, searchText)
				end
				searchResultCache[index] = matchesSearch and true or false
			end
		end

		if buttonIndex == 1 and _G.TradeSkillFilterBar:IsShown() then
			-- first button is filter bar, move on to next one
			buttonIndex = buttonIndex + 1
		end
		local button = _G['TradeSkillSkill'..buttonIndex]
		if matchesSearch then
			if button then
				UpdateTradeSkillRow(button, index, selected, isGuild)
			end
			numHeaders  = numHeaders  + (isHeader and 1 or 0)
			notExpanded = notExpanded + ((isHeader and isExpanded) and 0 or 1)

			buttonIndex = buttonIndex + 1
			numItems    = numItems + 1
			sndLastType = lastType
			lastType    = skillType
		elseif button then
			button:Hide()
			button:UnlockHighlight()
			button.isHighlighted = false
		end
	end

	if lastType == 'header' or lastType == 'subheader' then
		-- last row is an empty group
		buttonIndex = buttonIndex - 1
		numItems    = numItems - 1
	end
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
	FauxScrollFrame_Update(_G.TradeSkillListScrollFrame, numItems, _G.TRADE_SKILLS_DISPLAYED, _G.TRADE_SKILL_HEIGHT, nil, nil, nil, nil, nil, nil, true)

	-- Set the expand/collapse all button texture
	local collapseAll = _G.TradeSkillCollapseAllButton
	if notExpanded ~= numHeaders then
		collapseAll.collapsed = nil
		collapseAll:SetNormalTexture('Interface\\Buttons\\UI-MinusButton-Up')
	else
		collapseAll.collapsed = 1
		collapseAll:SetNormalTexture('Interface\\Buttons\\UI-PlusButton-Up')
	end
end

local function UpdateTradeSkillSearch(self, isUserInput)
	local text = self:GetText()
	self:GetParent().search = text ~= '' and text ~= _G.SEARCH and text or nil
	TradeSkillFrame_Update()
end

function search:OnInitialize()
end

local function InitializeTradeSkillFrame(event, ...)
	local color = _G.NORMAL_FONT_COLOR_CODE
	local searchBox = _G.TradeSkillFrameSearchBox
	      searchBox._OnTextChanged = searchBox:GetScript('OnTextChanged')
	      searchBox:SetScript('OnTextChanged', UpdateTradeSkillSearch)
	      searchBox._tiptext = searchBox.tiptext
	      searchBox.tiptext  = 'Search hints:'

	local index = 2
	for key, label in pairs({
		['Name']     = 'n',
		['Type']     = 't, slot',
		['Quality']  = 'q',
		['Level']    = 'l, lvl',
		['Binding']  = 'bop, boe, boa, bou, quest, bound',
		['Equipment sets'] = 's (* to match any)',
		['Tooltip']  = 'tt, tip',
	}) do
		searchBox['tiptext'..index] = color..key..'|r'
		searchBox['tiptext'..index..'Right'] = label
		index = index + 1
	end
	searchBox['tiptext'..index] = color..'|nExamples:|r'
	searchBox['tiptext'..(index+1)], searchBox['tiptext'..(index+1)..'Right'] = 'l: > 200 & boe', 'BoE items with level > 200'
	searchBox['tiptext'..(index+2)], searchBox['tiptext'..(index+2)..'Right'] = 'q: epic & gladiator', 'Epics named gladiator'
	searchBox['tiptext'..(index+3)] = 'Combine using ' ..color..'!|r (don\'t match), '..color..'&|r (and), '..color..'|||r (or)'

	search:UnregisterEvent('TRADE_SKILL_SHOW')
end

function search:OnEnable()
	self:RegisterEvent('TRADE_SKILL_SHOW', InitializeTradeSkillFrame)

	hooksecurefunc('TradeSkillFrame_Update', UpdateTradeSkillList)
end

function search:OnDisable()
	self:UnregisterEvent('TRADE_SKILL_SHOW')

	local searchBox = _G.TradeSkillFrameSearchBox
	      searchBox:SetScript('OnTextChanged', searchBox._OnTextChanged)
	      searchBox._OnTextChanged = nil
	      searchBox.tiptext = searchBox._tiptext
	      searchBox._tiptext = searchBox.tiptext
end
