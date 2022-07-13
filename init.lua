local GameHUD = require("cet-kit/GameHUD")

local styleRankMax = 6
local basePercentageIncrease = 15
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

StyleRank = {
    rank = 0,
    title = styleTitles[1],
    message = styleMessages[1]
}

StylishCombat = {
    description = "Stylish combat meter",
    displayStyleMeter = false,
    styleRankPercentage = 0,
    repetitionModifier = 1,
    actionModifier = 1,
    styleRank = StyleRank
}

function StylishCombat:new()
    registerForEvent("onInit", function ()
        CPS = GetMod("CPStyling"):New()

        GameHUD.Initialize()

        Observe('PlayerPuppet', 'OnCombatStateChanged', function(self, newState)
            if newState == 1 then
                StylishCombat.displayStyleMeter = true
                GameHUD.ShowWarning("Time to prove your worth", 3)
            end

            if StylishCombat.displayStyleMeter and newState == 2 then
                StylishCombat:resetStyleMeter()
                StylishCombat:resetRank()

                GameHUD.ShowWarning(StylishCombat.styleRank.message, 5)
            end

            if newState ~= 1 then
                StylishCombat:resetStyleMeter()
                StylishCombat:resetRank()
            end
        end)

        Observe('PlayerPuppet', 'OnDeath', function(self, event)
            if StylishCombat.displayStyleMeter then
                GameHUD.ShowWarning("You've done poorly", 2) -- Should have several possible disses
            end

            StylishCombat:resetStyleMeter()
            StylishCombat:resetRank()
        end)

        Observe('PlayerPuppet', 'OnHit', function(self, event)
            if self == nil or
                event == nil or
                event.attackData == nil or
                event.attackData:GetAttackType() == gamedataAttackType.Effect or
                event.attackData:GetInstigator() == nil then
                    return
            end

            if entEntity.GetEntityID(self).hash == entEntity.GetEntityID(Game.GetPlayer()).hash then
                -- Player was hit
                StylishCombat.styleRankPercentage = StylishCombat.styleRankPercentage - (basePercentageIncrease + StylishCombat.styleRank.rank)

                if StylishCombat.styleRankPercentage < 0 and StylishCombat:previousRank() then
                    StylishCombat.styleRankPercentage = StylishCombat.styleRankPercentage + 100
                end
            end

            if entEntity.GetEntityID(Game.GetPlayer()).hash == entEntity.GetEntityID(event.attackData:GetInstigator()).hash then
                -- Player hit someone
                StylishCombat.styleRankPercentage = StylishCombat.styleRankPercentage + ((basePercentageIncrease + styleRankMax - StylishCombat.styleRank.rank) * StylishCombat.repetitionModifier * StylishCombat.actionModifier)

                if StylishCombat.styleRankPercentage > 100 and StylishCombat:nextRank() then
                    StylishCombat.styleRankPercentage = StylishCombat.styleRankPercentage - 100
                end
            end
        end)

        Observe('PlayerPupper', 'UpdateHealthStateSFX', function(self, event)
            print("Something to test")
            print(Dump(event, true))
        end)

        -- Hide on any menu
        -- Decrease style on (manual) heal
        -- Decrease style on tick
        -- Add modifier logic
    end)

    registerForEvent("onDraw", function()
        if not StylishCombat.displayStyleMeter then return end

        local screenWidth, screenHeight = GetDisplayResolution()
        local width  = 420 * (screenWidth / 3440)
        local height = 100 * (screenHeight / 1440)

        ImGui.SetNextWindowPos(screenWidth - (width * 1.20), screenHeight * 0.85 * 0.5, ImGuiCond.Always)
        ImGui.SetNextWindowSize(width, height, ImGuiCond.Appearing)

        CPS:setThemeBegin()

        if ImGui.Begin("Style Ranking", true, ImGuiWindowFlags.NoResize + ImGuiWindowFlags.NoMove +  ImGuiWindowFlags.NoTitleBar + ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoBackground) then
            -- bigger with each level?
            local fontScale = 2 + (StylishCombat.styleRank.rank * 0.2)
            ImGui.SetWindowFontScale(fontScale)

            local text = StylishCombat.styleRank.title

            local textSizeX, textSizeY = ImGui.CalcTextSize(text)

            height = height + textSizeY

            ImGui.SetCursorPos((width - textSizeX) * 0.5, 0)

            -- Label
            CPS.colorBegin("Text", 0xFF4CFFFF)

            -- needs to depend on style rank
            ImGui.Text(text)

            CPS.colorEnd(1)

            CPS.styleBegin("FrameRounding", 13)

            -- Needs a style level
            -- Get colour from style level
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
    self.displayStyleMeter = false
end

return StylishCombat:new()
