--[[
Style Rank probe

A throwaway diagnostic mod. It changes nothing in game; it only reports what the
combat hooks in Style Rank actually receive on the patch you are running, so the
open questions in docs/compatibility-2x.md can be answered with observed values
instead of guesses.

Install: copy this folder into
  <game>/bin/x64/plugins/cyber_engine_tweaks/mods/style-rank-probe

Then load a save, fight for a few minutes, and press the dump hotkey (bind
"Style Rank probe: dump summary" under Cyber Engine Tweaks -> Bindings).

Output goes to the CET console and to probe-log.txt next to this file.

Every game value is read through pcall. The point of the exercise is to find out
which of these the current game and CET expose at all, so a name that no longer
resolves has to degrade into a note rather than an error.
]]

local MAX_DETAILED_HITS = 25
local MAX_HEALTH_EVENTS = 15
local LOG_FILE = "probe-log.txt"

local detailedHits = 0
local healthEvents = 0

-- Distinct values observed, per field. These matter more than any single hit:
-- the set of collider tags is how a headshot gets identified, and it cannot be
-- read out of the game's reflection data.
local seen = {}

-- Cyber Engine Tweaks sandboxes io to the mod's own folder, and may withhold it
-- entirely. Losing the log file is acceptable; losing the console output is not.
local function writeLine(line)
    pcall(function()
        local file = io.open(LOG_FILE, "a")
        if file then
            file:write(line, "\n")
            file:close()
        end
    end)
end

local function log(line)
    print("[style-rank-probe] " .. line)
    writeLine(line)
end

-- Reads a game value without letting a missing field take the handler with it.
local function describe(reader)
    local ok, value = pcall(reader)

    if not ok then
        return "<error: " .. tostring(value) .. ">"
    end

    if value == nil then
        return "<nil>"
    end

    return tostring(value)
end

-- Calls obj:name() defensively, so a method the patch removed reports as absent
-- rather than breaking the rest of the report.
local function method(obj, name)
    return describe(function() return obj[name](obj) end)
end

local function note(field, value)
    if value == nil or value == "<nil>" or value == "" then
        return
    end

    if value:sub(1, 7) == "<error:" then
        return
    end

    seen[field] = seen[field] or {}

    if not seen[field][value] then
        seen[field][value] = true
        log(("  NEW %s -> %s"):format(field, value))
    end
end

local function reportHit(self, event)
    detailedHits = detailedHits + 1
    log(("--- hit %d ---"):format(detailedHits))

    local attack = event.attackData

    -- Confirms the mod's core assumption: that observing PlayerPuppet.OnHit also
    -- catches hits where the target is an NPC. If selfIsPlayer is always true,
    -- style can only ever decrease and the whole design needs rethinking.
    log(("  selfIsPlayer      %s"):format(method(self, "IsPlayer")))
    log(("  instigatorIsPlayer %s"):format(describe(function()
        return attack:GetInstigator():IsPlayer()
    end)))

    log(("  attackType        %s"):format(describe(function()
        return attack:GetAttackType()
    end)))

    -- The roadmap's "wall bounced shots". gamedamageAttackData carries this as a
    -- counter, so bounce depth can scale the bonus rather than just flagging it.
    log(("  ricochetBounces   %s"):format(describe(function()
        return attack.numRicochetBounces
    end)))

    -- Rate-of-fire modifier, the existing TODO in init.lua.
    log(("  triggerMode       %s"):format(describe(function() return attack.triggerMode end)))
    log(("  weaponCharge      %s"):format(describe(function() return attack.weaponCharge end)))
    log(("  attackSpread      %s"):format(describe(function() return attack.numAttackSpread end)))

    -- Headshot detection hangs on these two. Reflection data names the fields but
    -- not their values, so the tags have to be collected in game.
    log(("  hitColliderTag    %s"):format(describe(function() return event.hitColliderTag end)))
    log(("  hitComponent      %s"):format(describe(function()
        return event.hitComponent:GetName()
    end)))

    -- Predicates the scoring already branches on. Any that report an error are
    -- gone from this patch and need replacing.
    log(("  IsDead            %s"):format(method(self, "IsDead")))
    log(("  IsHostile         %s"):format(method(self, "IsHostile")))
    log(("  IsBoss            %s"):format(method(self, "IsBoss")))
    log(("  IsIncapacitated   %s"):format(method(self, "IsIncapacitated")))
    log(("  IsCrowd           %s"):format(method(self, "IsCrowd")))
    log(("  IsVendor          %s"):format(method(self, "IsVendor")))

    -- gamedataNPCRarity is a ladder (Boss/Elite/MaxTac/Rare/Normal/Trash/Weak),
    -- so it could replace the current binary boss check.
    log(("  npcRarity         %s"):format(describe(function()
        return self:GetNPCRarity()
    end)))
end

local function accumulate(self, event)
    local attack = event.attackData

    note("hitColliderTag", describe(function() return event.hitColliderTag end))
    note("attackType", describe(function() return attack:GetAttackType() end))
    note("triggerMode", describe(function() return attack.triggerMode end))
    note("npcRarity", describe(function() return self:GetNPCRarity() end))
    note("ricochetBounces", describe(function() return attack.numRicochetBounces end))
end

local function dumpSummary()
    log("=== probe summary ===")
    log(("detailed hits logged: %d"):format(detailedHits))
    log(("health events logged: %d"):format(healthEvents))

    local fields = {}
    for field in pairs(seen) do
        fields[#fields + 1] = field
    end
    table.sort(fields)

    if #fields == 0 then
        log("no values observed yet - go and shoot something")
        return
    end

    for _, field in ipairs(fields) do
        local values = {}
        for value in pairs(seen[field]) do
            values[#values + 1] = value
        end
        table.sort(values)
        log(("%s (%d distinct):"):format(field, #values))
        for _, value in ipairs(values) do
            log("  " .. value)
        end
    end

    log("=== end summary ===")
    log("Paste probe-log.txt into docs/compatibility-2x.md findings.")
end

registerForEvent("onInit", function()
    writeLine("")
    writeLine(("=== style-rank-probe session %s ==="):format(
        describe(function() return os.date("%Y-%m-%d %H:%M:%S") end)
    ))

    log(("CET version   %s"):format(describe(function() return GetVersion() end)))
    log(("game version  %s"):format(describe(function()
        return EnumValueFromString("gameGameVersion", "Current")
    end)))

    Observe("PlayerPuppet", "OnCombatStateChanged", function(_, newState)
        -- init.lua compares this against literal 1 and 2. If those values moved,
        -- the meter never starts or never ends.
        log(("combatStateChanged -> %s"):format(describe(function() return newState end)))
        note("combatState", describe(function() return newState end))
    end)

    Observe("PlayerPuppet", "OnHit", function(self, event)
        if self == nil or event == nil or event.attackData == nil then
            return
        end

        accumulate(self, event)

        if detailedHits < MAX_DETAILED_HITS then
            reportHit(self, event)
        end
    end)

    Observe("PlayerPuppet", "OnHealthUpdateEvent", function(_, event)
        if event == nil or healthEvents >= MAX_HEALTH_EVENTS then
            return
        end

        healthEvents = healthEvents + 1

        -- init.lua ignores healthDifference <= 1 to skip passive regen. Health is
        -- percentage-based post-2.0, so that threshold may now discard real heals
        -- or punish regen ticks. These raw values settle it.
        log(("healthDifference  %s"):format(describe(function()
            return event.healthDifference
        end)))
    end)

    log("probe armed - fight for a few minutes, then press the dump hotkey")
end)

registerHotkey("styleRankProbeDump", "Style Rank probe: dump summary", function()
    dumpSummary()
end)
