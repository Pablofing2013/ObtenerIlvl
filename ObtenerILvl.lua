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
    for _, slotName in ipairs(SLOTS) do
        local button = _G[prefix .. slotName]
        UpdateButtonILvl(button, unit)
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
