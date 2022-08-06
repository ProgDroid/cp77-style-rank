local GameHUD = require("cet-kit/GameHUD")
local GameUI = require("cet-kit/GameUI")

local styleRankMax = 6

local basePercentageIncrease = 15
local basePercentageDecrease = 12
local baseTickReduction = 3

local styleHealFactor = 0.5
local styleSelfDamageFactor = 1.5

local styleInitMessage = "Time to prove your worth"
local styleInitMessageDuration = 3
local styleDissDuration = 2
local styleEndMessageDuration = 5

local styleTitles = {
    "Dull",
    "Competent",
    "Badass",
    "Amazing",
    "Super",
    "Shmoovin'",
    "SMOKIN' SEXY STYLE"
}

local styleMessages = {
    "You've done poorly",
    "You've done OK",
    "You've done well",
    "You've done great",
    "You've done incredible",
    "You've done absolutely grand",
    "You're a beast"
}

local styleDisses = {
    "You suck",
    "Damn, you're bad",
    "Welp...",
    "Yawn",
    "Yikes..."
}

StyleRank = {
    rank = 0,
    title = styleTitles[1],
    message = styleMessages[1]
}

StylishCombat = {
    description = "Stylish combat meter",
    active = false,
    displayStyleMeter = false,
    styleRankPercentage = 0,
    repetitionModifier = 1,
    actionModifier = 1,
    styleRank = StyleRank,
    paused = false
}

function StylishCombat:new()
    registerForEvent("onInit", function ()
        CPS = GetMod("CPStyling"):New()

        GameHUD.Initialize()

        GameUI.Observe(function(state)
            local hideAndPause = StylishCombat:isActive() and
                (state.isDefault or state.isScanner) and
                not state.isMenu and
                not state.isPopup and
                not state.isLoading

            StylishCombat:setDisplay(hideAndPause)
            StylishCombat:setPaused(not hideAndPause)
        end)

        Observe('PlayerPuppet', 'OnCombatStateChanged', function(self, newState)
            if newState == 1 then
                GameHUD.ShowWarning(styleInitMessage, styleInitMessageDuration)
                StylishCombat:start()
            end

            if StylishCombat:isActive() and newState == 2 then
                GameHUD.ShowWarning(StylishCombat.styleRank.message, styleEndMessageDuration)
                StylishCombat:reset()
            end

            if newState ~= 1 then
                StylishCombat:reset()
            end
        end)

        Observe('PlayerPuppet', 'OnDeath', function(self, event)
            if StylishCombat:isActive() then
                GameHUD.ShowWarning(styleDisses[math.random(1, #styleDisses)], styleDissDuration)
            end

            StylishCombat:resetStyleMeter()
            StylishCombat:resetRank()
        end)

        Observe('PlayerPuppet', 'OnHit', function(self, event)
            -- TODO check if NPC and check if already dead wasAliveBeforeHit
            -- TODO check weapon type and add rate of fire modifier
            if self == nil or
                event == nil or
                event.attackData == nil or
                event.attackData:GetAttackType() == gamedataAttackType.Effect or
                event.attackData:GetInstigator() == nil then
                    return
            end

            if entEntity.GetEntityID(self).hash == entEntity.GetEntityID(Game.GetPlayer()).hash then
                if entEntity.GetEntityID(Game.GetPlayer()).hash == entEntity.GetEntityID(event.attackData:GetInstigator()).hash then
                    StylishCombat:tookSelfDamage()
                else
                    StylishCombat:tookDamage()
                end
            elseif entEntity.GetEntityID(Game.GetPlayer()).hash == entEntity.GetEntityID(event.attackData:GetInstigator()).hash then
                StylishCombat:dealtDamage()
            end
        end)

        Observe('PlayerPuppet', 'OnHealthUpdateEvent', function(self, event)
            if self == nil or
                event == nil or
                event.healthDifference == nil or
                event.healthDifference <= 1 then -- Do not punish player for having passive healing
                    return
            end

            if entEntity.GetEntityID(self).hash == entEntity.GetEntityID(Game.GetPlayer()).hash then
                StylishCombat:healed()
            end
        end)

        -- TODO Add modifier logic
    end)

    registerForEvent("onDraw", function()
        if not StylishCombat:isDisplaying() then return end

        local screenWidth, screenHeight = GetDisplayResolution()
        local width  = 420 * (screenWidth / 3440)
        local height = 100 * (screenHeight / 1440)

        local positionX = screenWidth - (width * 1.20)
        local positionY = screenHeight * 0.85 * 0.5

        ImGui.SetNextWindowPos(positionX, positionY, ImGuiCond.Always)
        ImGui.SetNextWindowSize(width, height, ImGuiCond.Appearing)

        CPS:setThemeBegin()

        if ImGui.Begin("Style Ranking", true, ImGuiWindowFlags.NoResize + ImGuiWindowFlags.NoMove +  ImGuiWindowFlags.NoTitleBar + ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoBackground) then
            local fontScale = 2 + (StylishCombat.styleRank.rank * 0.2)
            ImGui.SetWindowFontScale(fontScale)

            local text = StylishCombat.styleRank.title

            local textSizeX, textSizeY = ImGui.CalcTextSize(text)

            height = height + textSizeY

            ImGui.SetCursorPos((width - textSizeX) * 0.5, 0)

            -- Label
            CPS.colorBegin("Text", 0xFF4CFFFF)

            ImGui.Text(text)

            CPS.colorEnd(1)

            CPS.styleBegin("FrameRounding", 13)

            -- TODO Needs a style level
            -- TODO Get colour from style level
            CPS.colorBegin("FrameBg", 0x9926214A)
            CPS.colorBegin("PlotHistogram", 0xE64547C7)

            ImGui.SetCursorPos(0, ImGui.GetFontSize() * 1.6)

            ImGui.ProgressBar(StylishCombat.styleRankPercentage * 0.01, width, height - (ImGui.GetFontSize() * 1.6), "")

            -- count must match the number of pushes above
            CPS.colorEnd(2)
            CPS.styleEnd(1)

            ImGui.SetWindowFontScale(1)
        end

        ImGui.End()

        CPS:setThemeEnd()
    end)

    registerForEvent('onUpdate', function(delta)
        if StylishCombat:isActive() and not StylishCombat:isPaused() then
            StylishCombat:tick(delta)
        end
    end)

    return StylishCombat
end

function StylishCombat:nextRank()
    local oldRank = self.styleRank.rank
    self.styleRank.rank = math.min(self.styleRank.rank + 1, styleRankMax)
    self.styleRank.title = styleTitles[self.styleRank.rank + 1]
    self.styleRank.message = styleMessages[self.styleRank.rank + 1]

    return self.styleRank.rank ~= oldRank
end

function StylishCombat:previousRank()
    local oldRank = self.styleRank.rank
    self.styleRank.rank = math.max(self.styleRank.rank - 1, 0)
    self.styleRank.title = styleTitles[self.styleRank.rank + 1]
    self.styleRank.message = styleMessages[self.styleRank.rank + 1]

    return self.styleRank.rank ~= oldRank
end

function StylishCombat:resetRank()
    self.styleRank.rank = 0
    self.styleRank.title = styleTitles[self.styleRank.rank + 1]
    self.styleRank.message = styleMessages[self.styleRank.rank + 1]
end

function StylishCombat:resetStyleMeter()
    self.styleRankPercentage = 0
    self:setDisplay(false)
end

function StylishCombat:reduceStyle(amount)
    self.styleRankPercentage = self.styleRankPercentage - amount

    if self.styleRankPercentage < 0 then
        if self:previousRank() then
            self.styleRankPercentage = self.styleRankPercentage + 100
        else
            self.styleRankPercentage = 0
        end
    end
end

function StylishCombat:increaseStyle(amount)
    self.styleRankPercentage = self.styleRankPercentage + amount

    if self.styleRankPercentage > 100 then
        if self:nextRank() then
            self.styleRankPercentage = self.styleRankPercentage - 100
        else
            self.styleRankPercentage = 100
        end
    end
end

function StylishCombat:healed()
    self:reduceStyle(self:baseDecrease() * styleHealFactor)
end

function StylishCombat:tookDamage()
    self:reduceStyle(self:baseDecrease())
end

function StylishCombat:tookSelfDamage()
    self:reduceStyle(self:baseDecrease() * styleSelfDamageFactor)
end

function StylishCombat:dealtDamage()
    self:increaseStyle(self:baseIncrease() * self.repetitionModifier * self.actionModifier)
end

function StylishCombat:baseIncrease()
    return basePercentageIncrease + styleRankMax - self.styleRank.rank
end

function StylishCombat:baseDecrease()
    return basePercentageDecrease + self.styleRank.rank
end

function StylishCombat:reset()
    self:setActive(false)
    self:setDisplay(false)
    self:resetStyleMeter()
    self:resetRank()
end

function StylishCombat:setDisplay(value)
    self.displayStyleMeter = value
end

function StylishCombat:isDisplaying()
    return self.displayStyleMeter == true
end

function StylishCombat:setActive(value)
    self.active = value
end

function StylishCombat:isActive()
    return self.active == true
end

function StylishCombat:start()
    self:setActive(true)
    self:setDisplay(true)
    self:setPaused(false)
end

function StylishCombat:baseTickReduction()
    return baseTickReduction + ((self.styleRank.rank / styleRankMax) * 10)
end

function StylishCombat:tick(delta)
    self:reduceStyle(delta * self:baseTickReduction())
end

function StylishCombat:setPaused(value)
    self.paused = value
end

function StylishCombat:isPaused()
    return self.paused == true
end

return StylishCombat:new()
