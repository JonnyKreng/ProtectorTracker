local WM = GetWindowManager()
local PING = LibMapPing

local debug = false

ProtectorTracker = {}
ProtectorTracker.name = "ProtectorTracker"
ProtectorTracker.inZone = false
ProtectorTracker.default = {
    offsetX = 500,
    offsetY = 500
}
ProtectorTracker.savedVariables = ProtectorTracker.default
ProtectorTracker.magic = {
    AS_ZONE = 1000,
    PROTECTOR = 64508
}
ProtectorTracker.Frame = {}
ProtectorTracker.ProtectorId = 0
ProtectorTracker.ProtectorData = 0
ProtectorTracker.SendTimeout = 0
ProtectorTracker.found = false

local sphereList = { -- Vorne = Rechts
    sphere1 = { -- Eingang Vorne
        y = 0.7063,
        x = 0.5344,
        name = "Eingang Vorne",
        bit = 1
    },
    sphere2 = { -- Eingang Hinten
        y = 0.7063,
        x = 0.4997,
        name = "Eingang Hinten",
        bit = 2
    },
    sphere3 = { -- Mitte Hinten
        y = 0.7444,
        x = 0.4944,
        name = "Mitte Hinten",
        bit = 4
    },
    sphere4 = { -- Mitte Vorne
        y = 0.7446,
        x = 0.5377,
        name = "Mitte Vorne",
        bit = 8
    },
    sphere5 = { -- Ausgang Vorne 
        y = 0.7857,
        x = 0.5341,
        name = " Ausgang Vorne",
        bit = 16
    },
    sphere6 = { -- Ausgang Hinten 
        y = 0.7867,
        x = 0.4963,
        name = "Ausgang Hinten ",
        bit = 32
    }
}

function ProtectorTracker.pointTo(data)
    for sphere in sphereList
        if sphere.bit == data then
            d(sphere.name)
        end
    end
end

function ProtectorTracker.AddProtector(data)
    if ProtectorTracker.ProtectorData == 0 then
        ProtectorTracker.ProtectorData = data
    end

    if data == 0 then
        d("ProtectorTracker: This should no have happend!")
    end
    
    --ProtectorTracker.ProtectorData = bit32.band(data, ProtectorTracker.ProtectorData)
    if ProtectorTracker.ProtectorData - data ~= 0 then
        ProtectorTracker.ProtectorData = math.abs(ProtectorTracker.ProtectorData - data)
    end

    d("Data in AddProtector:".. ProtectorTracker.ProtectorData)
    if ProtectorTracker.ProtectorData == 1 or
        ProtectorTracker.ProtectorData == 2 or
        ProtectorTracker.ProtectorData == 4 or
        ProtectorTracker.ProtectorData == 8 or
        ProtectorTracker.ProtectorData == 16 or
        ProtectorTracker.ProtectorData == 32 then
        ProtectorTracker.found = true
        ProtectorTracker.pointTo(ProtectorTracker.ProtectorData)
    end
end


local function sendData(data)
    if 4 > math.abs(ProtectorTracker.SendTimeout - os.clock()) then return end
    ProtectorTracker.SendTimeout = os.clock()
    if debug then d("Send: " .. data) end
    SetMapToPlayerLocation()
    x = 0
    y = data/10000
    PING:SetMapPing(MAP_PIN_TYPE_PING, MAP_TYPE_LOCATION_CENTERED, x ,y)
end

local function Ping(pingType, pingTag, offsetX, offsetY, isLocalPlayerOwner)
    if isLocalPlayerOwner or pingEventType ~= MAP_PIN_TYPE_PING then
        return
    end
    SetMapToPlayerLocation()
    x, y = LMP:GetMapPing(pingType, pingTag)
    d("Ping with: x:" .. x .." y:".. y)
    if x ~= 0 then 
        ProtectorTracker.AddProtector(math.floor(y*10000))
    end
end

local function clearPing()
    PING:RemoveMapPing(MAP_PIN_TYPE_PING)
end

local function round(num)
    return math.floor(num*10000)/10000
end

function ProtectorTracker.Search()
    name = GetUnitName('reticleover')
    if name ~= "Ordinated Protector" or ProtectorTracker.found then
        return
    end

    SetMapToPlayerLocation()
    local py,px,ph = GetMapPlayerPosition('player') 
    local ch = GetPlayerCameraHeading()
    px = round(px) 
    py = round(py)
    ch = (ch+math.pi)%(math.pi*2)
    sky = "-"
    if math.pi/4 > ch or ch >= (math.pi*7)/4 then
        sky = "S"
    elseif (math.pi*3)/4 > ch and ch >= math.pi/4 then
        sky = "W"
    elseif (math.pi*5)/4 > ch and ch >= (math.pi*3)/4 then
        sky = "N"
    elseif  (math.pi*7)/4 > ch and ch >= (math.pi*5)/4 then
        sky = "E"
    end

    if debug then
        d("+++++++++++++++++++++++++++++++++++++++++++++++++++++")
        d("Target:" .. name .." x:".. px .." y:" .. py .. " h:".. round(ch) .. "-" .. sky)
    end

    m = math.tan(ch)
    b = py - (px * m)

    local toSend = 0
    for name,sphere in pairs(sphereList) do 
        delta = (sphere.x * m + b) - sphere.y
        error = round(math.sqrt(math.pow(sphere.x-px,2) +math.pow(sphere.y-py,2)))*0.1 --Make error bigger with Distance
        error = error*((math.abs(m)+1)/1)   --Mitigate the tan() changes for tan(pi/2) -> inf
        if error < 0.005 then error = 0.005 end
        if  error >= math.abs(delta) then
            if not (
                (sphere.x > px and sky == "N") or 
                (sphere.x < px and sky == "S") or 
                (sphere.y < py and sky == "W") or
                (sphere.y > py and sky == "E")    
                ) then
                if debug then d(sphere.name) end
                toSend = toSend + sphere.bit
            end
        end    
    end
    if toSend ~= 0 then
        sendData(toSend)
        ProtectorTracker.AddProtector(toSend)
        ProtectorTracker.found = true
    end
end

function ProtectorTracker.onCombatEvent(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId) 
    if (result == ACTION_RESULT_EFFECT_GAINED and abilityId == ProtectorTracker.magic.PROTECTOR) then
        ProtectorTracker.ProtectorId = targetUnitId
        -- SEARCH PROTECTOR
        d("Start search")
        if not debug then 
            EVENT_MANAGER:RegisterForUpdate(ProtectorTracker.name .. "UPDATE", 0, ProtectorTracker.Search) 
            PING:RegisterCallback("BeforePingAdded", Ping)
        end

        --PING:SuppressPing(MAP_PIN_TYPE_PING)

    elseif (result == ACTION_RESULT_DIED and targetUnitId == ProtectorTracker.ProtectorId) then
        d("Stop search")
        -- STOP SEARCH
        EVENT_MANAGER:UnregisterForUpdate(ProtectorTracker.name .. "UPDATE")
        PING:UnregisterCallback("BeforePingAdded", Ping)
        ProtectorTracker.ProtectorId = 0
        ProtectorTracker.found = false

        if PING:IsPingSuppressed(MAP_PIN_TYPE_PING) then
            PING:UnsuppressPing(MAP_PIN_TYPE_PING)
        end
    end
end

function ProtectorTracker.zoneCheck()   

    if debug then 
        EVENT_MANAGER:RegisterForUpdate(ProtectorTracker.name .. "UPDATE", 1000, ProtectorTracker.Search) 
        PING:RegisterCallback("BeforePingAdded", Ping)
    end

    if (GetZoneId(GetUnitZoneIndex("player")) == ProtectorTracker.magic.AS_ZONE) then
        ProtectorTracker.inZone = true
        ProtectorTracker.Frame:SetHidden(false)
        EVENT_MANAGER:RegisterForEvent(ProtectorTracker.name .. "COMBAT_EVENT", EVENT_COMBAT_EVENT, ProtectorTracker.onCombatEvent);
        d("start")
    elseif (ProtectorTracker.inZone) then
        ProtectorTracker.inZone = false
        ProtectorTracker.Frame:SetHidden(true)
        EVENT_MANAGER:UnregisterForUpdate(ProtectorTracker.name .. "COMBAT_EVENT")
        d("stop")
    end
end

function ProtectorTracker.Initialize()
    ProtectorTracker.savedVariables = ZO_SavedVars:NewCharacterIdSettings("ProtectorTrackerVars", 1, "ProtectorTracker", ProtectorTracker.default, GetWorldName())
    ProtectorTracker.Frame = WM:CreateTopLevelWindow(ProtectorTracker.name .. "frame")
	ProtectorTracker.Frame:SetClampedToScreen(true)
	ProtectorTracker.Frame:SetDimensions(34, 34)
	ProtectorTracker.Frame:ClearAnchors()
	ProtectorTracker.Frame:SetMouseEnabled(false)
	ProtectorTracker.Frame:SetMovable(false)
    ProtectorTracker.Frame:SetHidden(true)
    ProtectorTracker.Frame:SetHandler("OnMoveStop", ProtectorTracker.savePos)
    ProtectorTracker.setPos()

    local t = WM:CreateControl(ProtectorTracker.name .. "texture", ProtectorTracker.Frame, CT_TEXTURE)
    t:SetTexture("esoui/art/lfg/gamepad/lfg_menuicon_normaldungeon.dds")
    t:SetAnchorFill()

    EVENT_MANAGER:RegisterForEvent(ProtectorTracker.name .. "ZONE_CHANGE", EVENT_PLAYER_ACTIVATED, ProtectorTracker.zoneCheck);
end

function ProtectorTracker.savePos()
    ProtectorTracker.savedVariables.offsetX = ProtectorTracker.Frame:GetLeft()
    ProtectorTracker.savedVariables.offsetY = ProtectorTracker.Frame:GetTop()
end
    
function ProtectorTracker.setPos()
    ProtectorTracker.Frame:ClearAnchors()
    ProtectorTracker.Frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, ProtectorTracker.savedVariables.offsetX, ProtectorTracker.savedVariables.offsetY)
end

function ProtectorTracker.OnAddOnLoaded(event, addonName)
    if addonName == ProtectorTracker.name then
        ProtectorTracker:Initialize()
    end
end

EVENT_MANAGER:RegisterForEvent(ProtectorTracker.name, EVENT_ADD_ON_LOADED, ProtectorTracker.OnAddOnLoaded)


