# Prism

Prism is a dependency-free Roblox UI library designed to feel closer to a
modern SaaS dashboard than a traditional Roblox menu. It uses Roblox GUI
primitives, tweened interactions, layered surfaces, and an orange prism accent
to stay polished without requiring an external UI framework.

## Features

- Draggable, resizable, minimizable, and closeable windows
- Dark and light themes with animated switching
- Responsive mouse and touch interactions
- Tabs, sections, labels, paragraphs, dividers, buttons, toggles, sliders,
  text inputs, dropdowns, keybind capture, and color swatches
- Search across all registered elements
- Animated notifications with info, success, warning, and error states
- Shared `Prism.Flags` table for script-readable values
- Optional `writefile` / `readfile` configuration persistence
- Native prism mark rendered from UI primitives; no image dependency required
- Cleanup through `Window:Destroy()` or `Prism.Destroy()`

## Quick start

```lua
local Prism = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/muhammadbaraqbah01-svg/Prism/main/Prism.lua"
))()

local Window = Prism.CreateWindow({
    Name = "Prism",
    SubTitle = "Control center",
    ToggleKey = Enum.KeyCode.RightControl,
    Width = 730,
    Height = 510,
})

local Home = Window:AddTab({
    Name = "Overview",
    Icon = "◆",
    Description = "A quick look at your active settings.",
})

local Controls = Home:AddSection({ Name = "Controls" })

Controls:AddParagraph({
    Title = "Welcome",
    Content = "Prism is ready. Every value below is also available in Prism.Flags.",
})

Controls:AddToggle({
    Name = "Enabled",
    Flag = "Enabled",
    Default = true,
    Callback = function(value)
        print("Enabled:", value)
    end,
})

Controls:AddSlider({
    Name = "Intensity",
    Flag = "Intensity",
    Min = 0,
    Max = 100,
    Default = 65,
    Rounding = 0,
})

Controls:AddDropdown({
    Name = "Mode",
    Flag = "Mode",
    Options = { "Balanced", "Performance", "Quiet" },
    Default = "Balanced",
})

Controls:AddButton({
    Name = "Show notification",
    Style = "Primary",
    Callback = function()
        Window:Notify({
            Title = "Saved",
            Content = "Your settings are up to date.",
            Type = "Success",
        })
    end,
})
```

## API notes

`Window:AddTab(options)` returns a tab. A tab returns a section through
`Tab:AddSection(options)`. Component methods return an element object with
`Set(value)`, `Get()`, and `ApplyTheme()` where the component supports them.

```lua
Window:Notify({
    Title = "Heads up",
    Content = "This is an informational message.",
    Type = "Info", -- Info, Success, Warning, Error
    Duration = 4,
})

Prism.SetTheme("Light")
Prism.SetTheme("Dark")
Prism.SaveConfiguration("my-settings")
Prism.LoadConfiguration("my-settings")
Window:Minimize()
Window:Open()
Window:Destroy()
```

Configuration persistence is intentionally capability-based. On executors
without `writefile`, `readfile`, or `isfile`, the methods return `false` and a
clear message rather than breaking the UI.

## Branding

The library's default logo is drawn from a pair of rounded diamond primitives,
so the published file remains self-contained. The supplied reference artwork
is included at `assets/prism-logo.png` for repository branding and future
Roblox asset upload. To use a Roblox-hosted image in a window, pass an image
asset URL or asset id as `LogoImage`:

```lua
local Window = Prism.CreateWindow({
    Name = "Prism",
    LogoImage = "rbxassetid://0000000000",
})
```

## License

Use and modify Prism freely in your own Roblox experiences and scripts.