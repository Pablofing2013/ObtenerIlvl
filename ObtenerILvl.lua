local function printMsg(msg)
    print("|cFF00FFFF[ObtenerILvl]|r " .. msg)
end

-- List of wearable slots
local SLOTS = {
    "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", "TabardSlot",
    "WristSlot", "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot",
    "Trinket0Slot", "Trinket1Slot", "MainHandSlot", "SecondaryHandSlot"
}

-- Helper to create or update the iLvl text on a button
local function UpdateButtonILvl(button, unit)
    if not button then return end
    
    if not button.ilvlText then
        button.ilvlText = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        button.ilvlText:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
        button.ilvlText:SetTextColor(1, 1, 0) -- Yellow
    end

    -- Clear text initially or if no unit
    if not unit or not UnitExists(unit) then
        button.ilvlText:SetText("")
        return
    end

    local slotId = button:GetID()
    local itemLink = GetInventoryItemLink(unit, slotId)
    
    if itemLink then
        local iLevel = C_Item.GetDetailedItemLevelInfo(itemLink)
        if iLevel and iLevel > 0 then
            button.ilvlText:SetText(iLevel)
        else
            button.ilvlText:SetText("")
            -- Request data loading (triggers GET_ITEM_INFO_RECEIVED)
            C_Item.RequestLoadItemData(itemLink)
        end
    else
        button.ilvlText:SetText("")
    end
end

-- Update all slots for a specific frame (Character or Inspect)
local function UpdateAllSlots(prefix, unit)
    local totalIlvl = 0
    local itemCount = 0

    for _, slotName in ipairs(SLOTS) do
        local button = _G[prefix .. slotName]
        UpdateButtonILvl(button, unit)

        -- Calculate average (ignore Shirt and Tabard)
        if slotName ~= "ShirtSlot" and slotName ~= "TabardSlot" then
            local slotId = GetInventorySlotInfo(slotName)
            local itemLink = GetInventoryItemLink(unit, slotId)
            if itemLink then
                local iLevel = C_Item.GetDetailedItemLevelInfo(itemLink)
                if iLevel and iLevel > 0 then
                    totalIlvl = totalIlvl + iLevel
                    itemCount = itemCount + 1
                end
            end
        end
    end

    -- Update Average Display "Under the Feet" for a premium look
    local parentFrame = _G[prefix .. "Frame"]
    if parentFrame then
        if not parentFrame.avgIlvlDisplay then
            -- Create a stylish container for the iLvl
            local display = CreateFrame("Frame", nil, parentFrame)
            display:SetSize(140, 36)
            display:SetFrameLevel(parentFrame:GetFrameLevel() + 10)
            
            -- Glassmorphism background effect (semi-transparent dark)
            local bg = display:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0, 0, 0, 0.6)
            
            -- Elegant golden borders
            local topBorder = display:CreateTexture(nil, "OVERLAY")
            topBorder:SetPoint("TOPLEFT")
            topBorder:SetPoint("TOPRIGHT")
            topBorder:SetHeight(1.5)
            topBorder:SetColorTexture(1, 0.85, 0, 0.5)

            local botBorder = display:CreateTexture(nil, "OVERLAY")
            botBorder:SetPoint("BOTTOMLEFT")
            botBorder:SetPoint("BOTTOMRIGHT")
            botBorder:SetHeight(1.5)
            botBorder:SetColorTexture(1, 0.85, 0, 0.5)

            local text = display:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
            text:SetPoint("CENTER", display, "CENTER", 0, 0)
            text:SetTextColor(1, 0.85, 0) -- Gold
            text:SetShadowColor(0, 0, 0, 1)
            text:SetShadowOffset(1, -1)
            
            parentFrame.avgIlvlDisplay = display
            parentFrame.avgIlvlText = text

            -- Position "under the feet" of the model
            local modelFrame = (prefix == "Inspect") and _G["InspectModelFrame"] or _G["CharacterModelFrame"]
            if modelFrame then
                display:SetPoint("BOTTOM", modelFrame, "BOTTOM", 0, 45)
            else
                -- Fallback if model frame is not found (unlikely in retail)
                display:SetPoint("BOTTOM", parentFrame, "BOTTOM", 0, 100)
            end
        end

        if itemCount > 0 then
            local avg = totalIlvl / itemCount
            parentFrame.avgIlvlText:SetText("iLvl: |cffffffff" .. string.format("%.1f", avg) .. "|r")
            parentFrame.avgIlvlDisplay:Show()
        else
            parentFrame.avgIlvlDisplay:Hide()
        end
    end
end

-- Create the event frame
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("UNIT_INVENTORY_CHANGED")
frame:RegisterEvent("INSPECT_READY")
frame:RegisterEvent("GET_ITEM_INFO_RECEIVED")

local currentInspectGuid = nil

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        printMsg("Addon cargado. iLvl ahora visible en tu equipo.")
        UpdateAllSlots("Character", "player")
    elseif event == "UNIT_INVENTORY_CHANGED" then
        local unit = ...
        if unit == "player" then
            UpdateAllSlots("Character", "player")
        elseif unit == "target" and InspectFrame and InspectFrame:IsShown() then
            UpdateAllSlots("Inspect", "target")
        end
    elseif event == "INSPECT_READY" then
        local guid = ...
        if guid == currentInspectGuid or (InspectFrame and InspectFrame:IsShown()) then
            UpdateAllSlots("Inspect", "target")
            if guid == currentInspectGuid then
                currentInspectGuid = nil
            end
        end
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        -- Refresh visible frames when any item data finishes loading
        if CharacterFrame:IsShown() then
            UpdateAllSlots("Character", "player")
        end
        if InspectFrame and InspectFrame:IsShown() then
            UpdateAllSlots("Inspect", "target")
        end
    end
end)

-- Hook CharacterFrame to update when opened
CharacterFrame:HookScript("OnShow", function()
    UpdateAllSlots("Character", "player")
end)

-- Hook InspectFrame to update when opened (if it exists)
if InspectFrame then
    InspectFrame:HookScript("OnShow", function()
        UpdateAllSlots("Inspect", "target")
    end)
else
    -- If InspectFrame isn't loaded yet, wait for it
    local f = CreateFrame("Frame")
    f:RegisterEvent("ADDON_LOADED")
    f:SetScript("OnEvent", function(_, _, name)
        if name == "Blizzard_InspectUI" then
            InspectFrame:HookScript("OnShow", function()
                UpdateAllSlots("Inspect", "target")
            end)
            f:UnregisterEvent("ADDON_LOADED")
        end
    end)
end

-- Slash Command configuration
SLASH_OBTENERILVL1 = "/ilvl"
SlashCmdList["OBTENERILVL"] = function(msg)
    if msg == "target" or UnitExists("target") then
        if UnitIsUnit("player", "target") then
             local _, equipped = GetAverageItemLevel()
             printMsg("Tu iLvl equipado es: |cFFFFFF00" .. string.format("%.2f", equipped) .. "|r")
             UpdateAllSlots("Character", "player")
        else
            if CanInspect("target") then
                currentInspectGuid = UnitGUID("target")
                NotifyInspect("target")
                printMsg("Inspeccionando a " .. UnitName("target") .. "...")
            else
                printMsg("No puedes inspeccionar a este objetivo.")
            end
        end
    else
        local _, equipped = GetAverageItemLevel()
        printMsg("Tu iLvl equipado es: |cFFFFFF00" .. string.format("%.2f", equipped) .. "|r")
        UpdateAllSlots("Character", "player")
    end
end
