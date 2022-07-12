local GameHUD = require("cet-kit/GameHUD")

StylishCombat = {
    description = "Stylish combat meter",
    displayStyleMeter = false
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
                GameHUD.ShowWarning("You've done poorly", 5)
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

        -- Hide on any menu
    end)

    registerForEvent("onDraw", function()
        if not StylishCombat.displayStyleMeter then return end

        local screenWidth, screenHeight = GetDisplayResolution()
        local width  = 400 * (screenWidth / 3440)
        local height = 100 * (screenHeight / 1440)

        local styleAmount = 50 -- percentage of style meter to be filled

        ImGui.SetNextWindowPos(screenWidth - (width * 1.25), screenHeight * 0.85 * 0.5, ImGuiCond.Always)
        ImGui.SetNextWindowSize(width, height, ImGuiCond.Appearing)

        CPS:setThemeBegin()

        if ImGui.Begin("Style Ranking", true, ImGuiWindowFlags.NoResize + ImGuiWindowFlags.NoMove +  ImGuiWindowFlags.NoTitleBar + ImGuiWindowFlags.NoScrollbar + ImGuiWindowFlags.NoBackground) then
            -- bigger with each level?
            local fontScale = 2 -- 2.5
            ImGui.SetWindowFontScale(fontScale)

            local text = "Dull"

            local textSizeX, _textSizeY = ImGui.CalcTextSize(text)

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

            ImGui.ProgressBar(styleAmount * 0.01, width, height - (ImGui.GetFontSize() * 1.6), "")

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

return StylishCombat:new()
