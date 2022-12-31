local Addon = {}
Addon.Name = "ImprovedTitleizer"
Addon.DisplayName = "ImprovedTitleizer"
Addon.Author = "tomstock"
Addon.Version = "1.0"

local AVA_SORT_BY_RANK =
{
    ["name"] = {},
    ["rank"] = {tiebreaker = "name", isNumeric = true},
}

local function spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

--These are actually their respective achievementIds
local AchievmentIds =
{
	["AvA"] =
	{
		92, --Volunteer
		93, --Recruit
		94, --Tyro
		95, --Legionary
		96, --Veteran
		97, --Corporal
		98, --Sergeant
		706, --First Sergeant
		99, --Lieutenant
		100, --Captain
		101, --Major
		102, --Centurion
		103, --Colonel
		104, --Tribune
		105, --Brigadier
		106, --Prefect
		107, --Praetorian
		108, --Palatine
		109, --August Palatine
		110, --Legate
		111, --General
		112, --Warlord
		113, --Grand Warlord
		114, --Overlord
		705, --Grand Overlord
	},

	["BG"] =
	{
		1918, -- [Paragon] Paragon
		1915, -- [Battleground Butcher] Battleground Butcher
		1913, -- [Grand Champion] Grand Champion
		1916, -- [Tactician] Tactician
		1919, -- [Triple Threat] Relic Runner
		1910, -- [Conquering Hero] Conquering Hero
		1895, -- [Pit Hero] Bloodletter
		1901, -- [Grand Relic Guardian] Relic Guardian
		1898, -- [Grand Relic Hunter] Relic Hunter
		1904, -- [Grand Standard-Bearer] Standard-Bearer
		1907, -- [Grand Standard-Guardian] Standard-Guardian
		1921, -- [Quadruple Kill] The Merciless
	},

}
local AvATitles
local AvATitlesF
local TitleCats = {} -- short for categories!! (and because I like cats)

local AchievementToTitle = {}
local TitleToAchievement = {}

local GetNumAchievementCategories        = GetNumAchievementCategories
--Usage: local numAchieveCategory = GetNumAchievementCategories()
local GetAchievementCategoryInfo         = GetAchievementCategoryInfo
--Usage: local categoryName, numSubCategories, numAchievements, earnedPoints, totalPoints = GetAchievementCategoryInfo(categoryIndex)
local GetFirstAchievementInLine          = GetFirstAchievementInLine
--Usage: local firstAchievementId = GetFirstAchievementInLine(achievementID)
local GetAchievementRewardTitle          = GetAchievementRewardTitle
--Usage: local hasRewardTitle, titleName = GetAchievementRewardTitle(achievementId)
local GetNextAchievementInLine           = GetNextAchievementInLine
--Usage: nextAchievementId = GetNextAchievementInLine(achievementId)
local GetAchievementSubCategoryInfo      = GetAchievementSubCategoryInfo
--Usage: local subCategoryName, subNumAchievements = GetAchievementSubCategoryInfo(categoryIndex, subCategoryIndex)
local GetAchievementId                   = GetAchievementId

--Usage: achievementId = GetAchievementId(categoryIndex, subcategoryIndex, achievementIndex)
local GetTitle                           = GetTitle -- I want original titles
--Usage: local strTitle GetTitle(achievementId)

local function InitializeTitles()

	local function CheckAchievementsInLine(id)
		--Go through every achievement looking for if a title exists for it.
		local firstId = GetFirstAchievementInLine(id)
		id = firstId > 0 and firstId or id
		while id > 0 do
			local hasTitle, title = GetAchievementRewardTitle(id)
			if hasTitle then
				AchievementToTitle[id] = title
				TitleToAchievement[title] = id
			end
			id = GetNextAchievementInLine(id)
		end
	end

	for i=1,GetNumAchievementCategories() do
		local s,n,a = GetAchievementCategoryInfo(i)
		for j=1,a do
			CheckAchievementsInLine(GetAchievementId(i,nil,j))
		end

		for j=1,n do
			local s,a = GetAchievementSubCategoryInfo(i,j)
			for k=1,a do
				CheckAchievementsInLine(GetAchievementId(i,j,k))
			end
		end
	end


	AvATitles = {}
	--grab AvA titles from achievements
	for i, id in ipairs(AchievmentIds["AvA"]) do
		local _, titleName = GetAchievementRewardTitle(id)
		AvATitles[titleName] = i
	end

	AvATitlesF = {}
	for titleName, rank in pairs(AvATitles) do
		AvATitlesF[titleName] = "|t28:28:"..GetAvARankIcon(rank*2).."|t " .. titleName
	end

	local header
	for desc, section in pairs(AchievmentIds) do
		for _, id in ipairs(section) do
			if not header then
				header = GetAchievementSubCategoryInfo(GetCategoryInfoFromAchievementId(id))
			end
			local _, titleName = GetAchievementRewardTitle(id)
			TitleCats[titleName] = header
		end
		header = nil
	end
end

local function OnLoad(eventCode, name)
	if name ~= Addon.Name then return end

	InitializeTitles()

	local LSM = LibStub("LibScrollableMenu")

	local orgAddDropdownRow = STATS.AddDropdownRow
	STATS.AddDropdownRow = function(self, rowName)
		local control = orgAddDropdownRow(self, rowName)
		control.combobox = control:GetNamedChild("Dropdown")
		control.scrollHelper = LSM.ScrollableDropdownHelper:New(self.control, control, 16)
		STATS_SCENE:RegisterCallback("StateChange", OnStateChange)
		control.scrollHelper.OnShow = function() end --don't change parenting

		titlesRow = control
		return control
	end

	local function ComboBoxSortHelper(item1, item2, comboBoxObject, sortKey, sortType, sortOrder)
		return ZO_TableOrderingFunction(item1, item2, sortKey or "name", sortType or comboBoxObject.m_sortType, sortOrder or comboBoxObject.m_sortOrder)
	end

	local function UpdateTitleDropdownTitles(self, dropdown)
		-- new code
		dropdown:ClearItems()
		dropdown:AddItem(ZO_ComboBox:CreateItemEntry(GetString(SI_STATS_NO_TITLE), function() SelectTitle(nil) end), ZO_COMBOBOX_SUPRESS_UPDATE)

		local function stripMarkup(str)
			return str:gsub("|[Cc]%x%x%x%x%x%x", ""):gsub("|[Rr]", "")
		end

		local ownedTitles = {}
		local doonce = false
		local hasSubmenus = false

		local mainItems = {}
		local subItems = {}
		for i=1, GetNumTitles() do
			local title = zo_strformat(GetTitle(i), GetRawUnitName("player"))
			title = stripMarkup(title)
			ownedTitles[title] = true
			local header = TitleCats[title]
			if header ~= nil then
				hasSubmenus = true
				subItems[header] = subItems[header] or {}
				table.insert(subItems[header], {name=AvATitlesF[title] or title, rank=AvATitles[title] or 0, callback=function() SelectTitle(i) end})
			else
				table.insert(mainItems, {name=title, callback=function() SelectTitle(i) end})
			end
		end
		table.sort(mainItems, function(item1, item2) return ComboBoxSortHelper(item1, item2, dropdown) end)

		--[[ insert unowned AvA titles
		for title, rank in pairs(AvATitles) do
			local header = TitleCats[title]
			if header ~= nil and not ownedTitles[title] then
				subItems[header] = subItems[header] or {}
				table.insert(subItems[header], {name=AvATitlesF[title] or title, rank=AvATitles[title] or 0, callback=function() end, disabled=true, tooltip = "Disabled Title"})
			end
		end
		--]]

		local i = 1
		for header, titles in spairs(subItems) do
			table.sort(titles, function(item1, item2) return ComboBoxSortHelper(item1, item2, dropdown, "rank", AVA_SORT_BY_RANK) end)
			table.insert(mainItems, i, {name=header, entries=titles})
			i = i + 1
		end
		-- add divider below "No Title" if there is more
		if #mainItems > 0 then
			table.insert(mainItems, 1, {name=LSM.DIVIDER})
			i = i + 1
		end
		-- add divider below last submenu if there is more
		if i <= #mainItems and hasSubmenus then
			table.insert(mainItems, i, {name=LSM.DIVIDER})
		end
		dropdown:AddItems(mainItems)

		self:UpdateTitleDropdownSelection(dropdown)
	end

	if STATS and STATS.UpdateTitleDropdownTitles then
		STATS.UpdateTitleDropdownTitles = UpdateTitleDropdownTitles
	end

	EVENT_MANAGER:UnregisterForEvent(Addon.Name, EVENT_ADD_ON_LOADED)
end
EVENT_MANAGER:RegisterForEvent(Addon.Name, EVENT_ADD_ON_LOADED, OnLoad)

IMPROVEDTITLEIZER = Addon