local GameHUD = require("cet-kit/GameHUD")

local styleRankMax = 6
local basePercentageIncrease = 5

StylishCombat = {
    description = "Stylish combat meter",
    displayStyleMeter = false,
    styleRank = 0,
    styleRankPercentage = 0,
    repetitionModifier = 1,
    actionModifier = 1
}

function StylishCombat:new()
    registerForEvent("onInit", function ()
        CPS = GetMod("CPStyling"):New()

        GameHUD.Initialize()

        -- local message = SimpleScreenMessage.new()
        -- message.message = "Message test"
        -- message.isShown = true

        -- local blackboardDefs = Game.GetAllBlackboardDefs()
        -- local blackboardUI = Game.GetBlackboardSystem():Get(blackboardDefs.UI_HUDProgressBar)
        -- blackboardUI:SetVariant(
        --     blackboardDefs.UI_HUDProgressBar.Active,
        --     ToVariant(message),
        --     true
        -- )

        Observe('PlayerPuppet', 'OnCombatStateChanged', function(self, newState)
            if newState == 1 then
                StylishCombat.displayStyleMeter = true
                GameHUD.ShowWarning("Time to prove your worth", 3)
            end

            if StylishCombat.displayStyleMeter and newState == 2 then
                StylishCombat.displayStyleMeter = false
                local message = "You've done poorly"

                if StylishCombat.styleRank == 1 then
                    message = "You've done OK"
                end
    
                if StylishCombat.styleRank == 2 then
                    message = "You've done well"
                end
    
                if StylishCombat.styleRank == 3 then
                    message = "You've done great"
                end
    
                if StylishCombat.styleRank == 4 then
                    message = "You've done amazing"
                end
    
                if StylishCombat.styleRank == 5 then
                    message = "You've done absolutely grand"
                end
    
                if StylishCombat.styleRank == 6 then
                    message = "You're a beast"
                end

                GameHUD.ShowWarning(message, 5)
            end

            if newState ~= 1 then
                StylishCombat.displayStyleMeter = false
            end
        end)

        Observe('PlayerPuppet', 'OnDeath', function(self, event)
            if StylishCombat.displayStyleMeter then
                GameHUD.ShowWarning("You've done poorly", 2) -- Should have several possible disses
            end

            StylishCombat.displayStyleMeter = false
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
                StylishCombat.styleRankPercentage = StylishCombat.styleRankPercentage - basePercentageIncrease

                local changedRank = false
                if StylishCombat.styleRankPercentage <= 0 then
                    changedRank = StylishCombat:previousRank()
                end

                if changedRank then
                    StylishCombat.styleRankPercentage = 100 + StylishCombat.styleRankPercentage
                else
                    StylishCombat.styleRankPercentage = 0
                end
            end

            if entEntity.GetEntityID(Game.GetPlayer()).hash == entEntity.GetEntityID(event.attackData:GetInstigator()).hash then
                -- Player hit someone
                StylishCombat.styleRankPercentage = StylishCombat.styleRankPercentage + (basePercentageIncrease * StylishCombat.repetitionModifier * StylishCombat.actionModifier)

                local changedRank = false
                if StylishCombat.styleRankPercentage > 100 then
                    changedRank = StylishCombat:nextRank()
                end

                if changedRank then
                    StylishCombat.styleRankPercentage = 0
                else
                    StylishCombat.styleRankPercentage = 100
                end
            end
        end)

        -- Hide on any menu
        -- OnHit reduce style meter
    end)

    registerForEvent("onDraw", function()
        if not StylishCombat.displayStyleMeter then return end

        local screenWidth, screenHeight = GetDisplayResolution()
        local width  = 400 * (screenWidth / 3440)
        local height = 100 * (screenHeight / 1440)

        ImGui.SetNextWindowPos(screenWidth - (width * 1.25), screenHeight * 0.85 * 0.5, ImGuiCond.Always)
        ImGui.SetNextWindowSize(width, height, ImGuiCond.Appearing)

        CPS:setThemeBegin()

        if ImGui.Begin("Style Ranking", true, ImGuiWindowFlags.NoResize + ImGuiWindowFlags.NoMove +  ImGuiWindowFlags.NoTitleBar + ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoBackground) then
            -- bigger with each level?
            local fontScale = 2 + (StylishCombat.styleRank * 0.2)
            ImGui.SetWindowFontScale(fontScale)

            local text = "Dull"

            if StylishCombat.styleRank == 1 then
                text = "Competent"
            end

            if StylishCombat.styleRank == 2 then
                text = "Bonkers"
            end

            if StylishCombat.styleRank == 3 then
                text = "Acceptable"
            end

            if StylishCombat.styleRank == 4 then
                text = "Super"
            end

            if StylishCombat.styleRank == 5 then
                text = "So Stylish"
            end

            if StylishCombat.styleRank == 6 then
                text = "SMOKIN' SEXY STYLE"
            end

            local textSizeX, textSizeY = ImGui.CalcTextSize(text)

            height = height + textSizeY

            ImGui.SetCursorPos((width - textSizeX) * 0.5, 0)

            -- Label
            CPS.colorBegin("Text", 0xFF4CFFFF)

            -- needs to depend on style rank
            ImGui.Text(text)

            CPS.colorEnd(1)

            CPS.styleBegin("FrameRounding", 11)

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
    local oldRank = self.styleRank
    self.styleRank = math.min(self.styleRank + 1, styleRankMax)

    return self.styleRank ~= oldRank
end

function StylishCombat:previousRank()
    local oldRank = self.styleRank
    self.styleRank = math.max(self.styleRank - 1, 0)

    return self.styleRank ~= oldRank
end

return StylishCombat:new()
