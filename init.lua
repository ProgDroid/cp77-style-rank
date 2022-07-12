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
    end)

    registerForEvent("onDraw", function()
        if StylishCombat.displayStyleMeter then
            local screenWidth, screenHeight = GetDisplayResolution()
            local width  = 400
            local height = 250

            ImGui.SetNextWindowPos(screenWidth - (width * 1.2), screenHeight * 0.9 / 2, ImGuiCond.Always)
            ImGui.SetNextWindowSize(width, height, ImGuiCond.Appearing)

            CPS:setThemeBegin()

            if ImGui.Begin("Style Ranking") then
                ImGui.Text("Stylish af!")
            end

            ImGui.End()

            CPS:setThemeEnd()
        end
    end)

    return StylishCombat
end

return StylishCombat:new()
