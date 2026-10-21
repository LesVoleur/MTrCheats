-- Append our controls after the vanilla individual instructions.
local ffi = require("ffi")
local C = ffi.C
ffi.cdef[[
    typedef uint64_t UniverseID;
    UniverseID GetPlayerID(void);
    bool IsComponentClass(UniverseID componentid, const char* classname);
]]

local menu = Helper.getMenu("MapMenu")
if not menu then
    DebugError("MTrCheats: MapMenu was not loaded")
    return
end

local pending = {}
local options = {
    { id = "invulnerability", text = 1, variable = "$MTrCheatsInvincibleShips" },
    { id = "ammo", text = 3, variable = "$MTrCheatsAmmoShips" },
    { id = "civilian", text = 4, variable = "$MTrCheatsDeployableShips" },
    { id = "military", text = 5, variable = "$MTrCheatsMilitaryShips" },
}

local function isEnabled(ship, variable)
    local player = ConvertStringTo64Bit(tostring(C.GetPlayerID()))
    local ships = GetNPCBlackboard(player, variable) or {}
    for _, protectedShip in ipairs(ships) do
        if ConvertStringTo64Bit(tostring(protectedShip)) == ship then
            return true
        end
    end
    return false
end

RegisterEvent("MTrCheats.InvulnerabilityUpdated", function(_, ship)
    if ship then
        pending[tostring(ConvertStringTo64Bit(tostring(ship))) .. ":invulnerability"] = nil
    end
end)

RegisterEvent("MTrCheats.ConsumablesUpdated", function(_, ship)
    if ship then
        local key = tostring(ConvertStringTo64Bit(tostring(ship)))
        pending[key .. ":ammo"] = nil
        pending[key .. ":civilian"] = nil
        pending[key .. ":military"] = nil
    end
end)

-- Preserve the original on UI reload rather than wrapping our own wrapper.
menu.mtrCheatsOriginalResponses = menu.mtrCheatsOriginalResponses or menu.createResponsesForControllable
menu.createResponsesForControllable = function(ftable, controllable, textproperties, mode, yoffset, instance)
    menu.mtrCheatsOriginalResponses(ftable, controllable, textproperties, mode, yoffset, instance)
    if not C.IsComponentClass(controllable, "ship") or not GetComponentData(controllable, "isplayerowned") then
        return
    end

    local row = ftable:addRow(false, Helper.headerRowProperties)
    row[1]:setColSpan(8):createText(ReadText(25102029, 2), Helper.headerRowCenteredProperties)

    local group = ftable:addRowGroup({})
    for _, entry in ipairs(options) do
        local option = entry
        local key = tostring(controllable) .. ":" .. option.id
        row = group:addRow("mtr_cheats_" .. option.id, {})
        row[1]:createCheckBox(function()
            if pending[key] ~= nil then
                return pending[key]
            end
            return isEnabled(controllable, option.variable)
        end, { width = textproperties.height, height = textproperties.height })
        row[1].handlers.onClick = function(_, checked)
            pending[key] = checked
            -- Pass a component, not a raw 64-bit number, to Mission Director.
            AddUITriggeredEvent("MTrCheats", option.id .. (checked and "_on" or "_off"),
                ConvertStringToLuaID(tostring(controllable)))
        end
        row[2]:setColSpan(7):createText(ReadText(25102029, option.text), textproperties)
    end
end
