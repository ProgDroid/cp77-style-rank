-- Cyber Engine Tweaks runs mods on LuaJIT and injects the game API as globals.
std = "luajit"

-- Vendored upstream code; verified by scripts/update-deps.sh --check, not linted.
exclude_files = { "cet-kit/" }

read_globals = {
    -- CET mod lifecycle and helpers
    "registerForEvent",
    "registerHotkey",
    "registerInput",
    "GetMod",
    "GetSingleton",
    "GetDisplayResolution",
    "GetVersion",

    -- CET hooking API
    "Observe",
    "ObserveAfter",
    "Override",
    "NewObject",
    "NewProxy",
    "EnumValueFromString",

    -- Game API
    "Game",
    "GameDump",
    "TweakDB",
    "TweakDBID",

    -- ImGui bindings
    "ImGui",
    "ImGuiCond",
    "ImGuiCol",
    "ImGuiStyleVar",
    "ImGuiWindowFlags",

    -- RED4 engine types used by this mod
    "entEntity",
    "gamedataAttackType",

    -- Logging
    "spdlog",
}
