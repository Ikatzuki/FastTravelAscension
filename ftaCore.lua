local FTA_ICON_COORDS_ICON = "Interface\\Addons\\FastTravelAscension\\Images\\FTAIcon"
local FTA_ICON_COORDS_ICON_HIGHLIGHT = "Interface\\Addons\\FastTravelAscension\\Images\\FTAIconGlow"

local function ShouldShowIcon(FTAType)
	local playerFaction = UnitFactionGroup('player')
	if FTAType == 1 and playerFaction == "Alliance" then
		return true
	end
	if FTAType == 2 and playerFaction == "Horde" then
		return true
	end
	if FTAType == 3 then
		return true
	end
	return false
end

local FTAPinFrames = {}
local FTAMapTooltip = nil

function FTAUI_OnLoad(self)
	self:RegisterForDrag("LeftButton")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	self:RegisterEvent("ADDON_LOADED")
	self:RegisterEvent("WORLD_MAP_UPDATE")
	self:RegisterEvent("WORLD_MAP_NAME_UPDATE")
	self:RegisterEvent("SPELL_COOLDOWN_UPDATE")

	self:SetScript("OnEvent", FTAEventHandler)

	if(not EncounterJournal) then
		LoadAddOn("Blizzard_EncounterJournal")
	end

	FTAMapTooltipSetup()
end

function FTAHideAllPins()
	for i = 1, #FTAPinFrames do
		FTAPinFrames[i]:Hide()
	end

	wipe(FTAPinFrames)
end

function FTARefreshPins()
	FTAHideAllPins()
	if not (WorldMapFrame:IsVisible()) then return nil end

	local cityOverride = false

	if ((GetCurrentMapAreaID() == 301) or (GetCurrentMapAreaID() == 321) or (GetCurrentMapAreaID() == 504)) then
		cityOverride = true
	end
	
	if ((GetCurrentMapDungeonLevel() == 0) or cityOverride) then
		if FTAPinDB[GetCurrentMapAreaID()] then
			for i = 1, #FTAPinDB[GetCurrentMapAreaID()] do
				FTAShowPin(i)
			end
		end
	end
end

function FTAMapTooltipSetup()
	FTAMapTooltip = CreateFrame("GameTooltip", "FTAMapTooltip", WorldFrame, "GameTooltipTemplate")
	FTAMapTooltip:SetFrameStrata("TOOLTIP")
	WorldMapFrame:HookScript("OnSizeChanged",
		function(self)
			FTAMapTooltip:SetScale(1/self:GetScale())
		end
	)
end

function FTAShowPin(locationIndex)
	FastTravelAscension = FTAPinDB[GetCurrentMapAreaID()][locationIndex]

	local x = FastTravelAscension[1]
	local y = FastTravelAscension[2]
	local subInstanceMapIDs = FastTravelAscension[3]

	local type = FTAInstanceMapDB[subInstanceMapIDs[1]][2]
	local hearthstone = FTAInstanceMapDB[subInstanceMapIDs[1]][3]

	if not ShouldShowIcon(type) then
		return nil
	end

	local hasSpell = IsUsableSpell(hearthstone);

	local pin = CreateFrame("Button", "IPPin", WorldMapDetailFrame, "SecureActionButtonTemplate")

	-- @robinsch: only add left click casting if we know the spell
	if hasSpell then
		pin:SetAttribute("type1", "macro") -- left click causes macro
		pin:SetAttribute("macrotext1", "/cast "..hearthstone) -- text for macro on left click
	end

	pin.Texture = pin:CreateTexture()
	pin.Texture:SetTexture(FTA_ICON_COORDS_ICON)
	pin.Texture:SetAllPoints()

	-- @robinsch: make icon greyed out
	if not hasSpell then
		pin.Texture:SetDesaturated(1);
		pin.Texture:SetAlpha(0.65);
	end

	pin:EnableMouse(true)
	pin:SetFrameStrata("HIGH")

	pin:SetPoint("CENTER", WorldMapDetailFrame, "TOPLEFT", (x / 100) * WorldMapDetailFrame:GetWidth(), (-y / 100) * WorldMapDetailFrame:GetHeight())

	pin:SetWidth(31)
	pin:SetHeight(31)

	pin:HookScript("OnEnter", function(pin, motion)
		FTAMapTooltip:SetOwner(pin, "ANCHOR_RIGHT")
		FTAMapTooltip:ClearLines()
		FTAMapTooltip:SetScale(GetCVar("uiScale"))
		FTAMapTooltip:AddLine(string.format("|cffffffff%s|r", hearthstone))
		
		-- Shouldn't show the glow texture if you don't have the stone learned.
		if not hasSpell then
			pin.Texture:SetDesaturated(1);
			pin.Texture:SetAlpha(0.65);
		else
			pin.Texture:SetTexture(FTA_ICON_COORDS_ICON_HIGHLIGHT)
		end

		local usable = true;
		if not hasSpell then
			FTAMapTooltip:AddLine(string.format("|cffff0000%s|r", "You don't own this vanity item"));
			usable = false;
		end

		local start, duration = GetSpellCooldown(hearthstone);
		if start ~= nil then
			local cooldown = start + duration - GetTime();
			if cooldown and cooldown > 0 then
				if cooldown > 60 then
					FTAMapTooltip:AddLine(string.format("|cffff0000%s %s:%s|r", "Remaining Cooldown:", math.floor(cooldown / 60), math.floor(cooldown % 60)));
				else
					FTAMapTooltip:AddLine(string.format("|cffff0000%s %s|r", "Remaining Cooldown:", math.floor(cooldown)));
				end
				usable = false;
			end
		end

		if usable then
			FTAMapTooltip:AddLine(string.format("|cff00ff00%s|r", "<Click to Teleport>"));
		end

		FTAMapTooltip:Show()
	end)

	pin:HookScript("OnLeave",
			function(pin)
				pin.Texture:SetTexture(FTA_ICON_COORDS_ICON)
				FTAMapTooltip:Hide()
			end
		)

	pin:HookScript("OnClick",
			function(self, button)
				if (button == "LeftButton") then
					WorldMapFrameCloseButton:Click()
				end
			end
		)
	table.insert(FTAPinFrames, pin)
	pin:Show()
end

function FTAEventHandler(self, event, ...)
	FTARefreshPins()
end