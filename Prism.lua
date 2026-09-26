--[[
    Prism
    A polished, dependency-free Roblox UI library.

    The library intentionally uses Roblox primitives instead of external
    assets for its default logo, so it works immediately after loadstring.
    A custom image can be supplied through Window.LogoImage.
]]

local Prism = {
    Flags = {},
    Windows = {},
    _connections = {},
    _themeName = "Dark",
}

local Services = {
    Players = game:GetService("Players"),
    TweenService = game:GetService("TweenService"),
    UserInputService = game:GetService("UserInputService"),
    RunService = game:GetService("RunService"),
    HttpService = game:GetService("HttpService"),
}

local LocalPlayer = Services.Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Themes = {
    Dark = {
        Background = Color3.fromRGB(13, 15, 20),
        Surface = Color3.fromRGB(19, 22, 29),
        SurfaceRaised = Color3.fromRGB(25, 29, 38),
        SurfaceHover = Color3.fromRGB(31, 35, 46),
        Border = Color3.fromRGB(57, 63, 78),
        Text = Color3.fromRGB(244, 246, 250),
        TextMuted = Color3.fromRGB(148, 155, 170),
        TextFaint = Color3.fromRGB(93, 101, 118),
        Accent = Color3.fromRGB(255, 145, 35),
        AccentBright = Color3.fromRGB(255, 184, 82),
        AccentDark = Color3.fromRGB(178, 77, 22),
        Success = Color3.fromRGB(73, 205, 132),
        Warning = Color3.fromRGB(255, 187, 74),
        Danger = Color3.fromRGB(244, 91, 101),
        Info = Color3.fromRGB(104, 166, 255),
        Overlay = Color3.fromRGB(4, 5, 8),
    },
    Light = {
        Background = Color3.fromRGB(248, 249, 252),
        Surface = Color3.fromRGB(255, 255, 255),
        SurfaceRaised = Color3.fromRGB(244, 246, 250),
        SurfaceHover = Color3.fromRGB(237, 240, 246),
        Border = Color3.fromRGB(218, 222, 231),
        Text = Color3.fromRGB(28, 31, 39),
        TextMuted = Color3.fromRGB(103, 110, 126),
        TextFaint = Color3.fromRGB(151, 158, 173),
        Accent = Color3.fromRGB(224, 105, 16),
        AccentBright = Color3.fromRGB(252, 142, 36),
        AccentDark = Color3.fromRGB(174, 65, 8),
        Success = Color3.fromRGB(31, 158, 91),
        Warning = Color3.fromRGB(212, 132, 14),
        Danger = Color3.fromRGB(214, 58, 70),
        Info = Color3.fromRGB(51, 111, 219),
        Overlay = Color3.fromRGB(20, 22, 28),
    },
}

local function theme()
    return Themes[Prism._themeName] or Themes.Dark
end

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(Prism._connections, connection)
    return connection
end

local function disconnect(connection)
    if connection then
        connection:Disconnect()
    end
end

local function tween(instance, properties, duration, style, direction)
    if not instance or not instance.Parent then
        return nil
    end
    local info = TweenInfo.new(
        duration or 0.2,
        style or Enum.EasingStyle.Quart,
        direction or Enum.EasingDirection.Out
    )
    local animation = Services.TweenService:Create(instance, info, properties)
    animation:Play()
    return animation
end

local function create(className, properties, children)
    local instance = Instance.new(className)
    for property, value in pairs(properties or {}) do
        instance[property] = value
    end
    for _, child in ipairs(children or {}) do
        child.Parent = instance
    end
    return instance
end

local function corner(parent, radius)
    return create("UICorner", {
        CornerRadius = UDim.new(0, radius or 8),
        Parent = parent,
    })
end

local function stroke(parent, color, transparency, thickness)
    return create("UIStroke", {
        Color = color or theme().Border,
        Transparency = transparency == nil and 0.25 or transparency,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function padding(parent, left, right, top, bottom)
    return create("UIPadding", {
        PaddingLeft = UDim.new(0, left or 0),
        PaddingRight = UDim.new(0, right == nil and left or right),
        PaddingTop = UDim.new(0, top == nil and left or top),
        PaddingBottom = UDim.new(0, bottom == nil and top or bottom),
        Parent = parent,
    })
end

local function list(parent, direction, gap, sortOrder)
    return create("UIListLayout", {
        FillDirection = direction or Enum.FillDirection.Vertical,
        Padding = UDim.new(0, gap or 8),
        SortOrder = sortOrder or Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        Parent = parent,
    })
end

local function safeCall(callback, ...)
    if type(callback) ~= "function" then
        return
    end
    local args = { ... }
    task.spawn(function()
        local ok, errorMessage = pcall(function()
            callback(table.unpack(args))
        end)
        if not ok then
            warn("[Prism] Callback error:", errorMessage)
        end
    end)
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function isInputObject(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end

local function setProperty(instance, property, value)
    if instance and instance.Parent then
        instance[property] = value
    end
end

local function getInputPosition(input)
    return Vector2.new(input.Position.X, input.Position.Y)
end

local function makeDraggable(handle, target, boundary)
    local dragging = false
    local dragStart
    local startPosition
    local moveConnection
    local endConnection

    connect(handle.InputBegan, function(input)
        if not isInputObject(input) then
            return
        end
        dragging = true
        dragStart = getInputPosition(input)
        startPosition = target.Position
        disconnect(moveConnection)
        disconnect(endConnection)

        moveConnection = connect(Services.UserInputService.InputChanged, function(changed)
            if not dragging or (changed.UserInputType ~= Enum.UserInputType.MouseMovement
                and changed.UserInputType ~= Enum.UserInputType.Touch) then
                return
            end
            local delta = getInputPosition(changed) - dragStart
            local nextX = startPosition.X.Offset + delta.X
            local nextY = startPosition.Y.Offset + delta.Y
            if boundary then
                local viewport = boundary.AbsoluteSize
                local size = target.AbsoluteSize
                nextX = clamp(nextX, 8, math.max(8, viewport.X - size.X - 8))
                nextY = clamp(nextY, 8, math.max(8, viewport.Y - size.Y - 8))
            end
            target.Position = UDim2.fromOffset(nextX, nextY)
        end)

        endConnection = connect(Services.UserInputService.InputEnded, function(ended)
            if isInputObject(ended) then
                dragging = false
            end
        end)
    end)
end

local function makeResizable(handle, target, minimumSize, boundary, onResize)
    local resizing = false
    local resizeStart
    local startSize
    local moveConnection
    local endConnection

    connect(handle.InputBegan, function(input)
        if not isInputObject(input) then
            return
        end
        resizing = true
        resizeStart = getInputPosition(input)
        startSize = target.AbsoluteSize
        disconnect(moveConnection)
        disconnect(endConnection)

        moveConnection = connect(Services.UserInputService.InputChanged, function(changed)
            if not resizing or (changed.UserInputType ~= Enum.UserInputType.MouseMovement
                and changed.UserInputType ~= Enum.UserInputType.Touch) then
                return
            end
            local delta = getInputPosition(changed) - resizeStart
            local width = math.max(minimumSize.X, startSize.X + delta.X)
            local height = math.max(minimumSize.Y, startSize.Y + delta.Y)
            if boundary then
                width = math.min(width, boundary.AbsoluteSize.X - target.Position.X.Offset - 8)
                height = math.min(height, boundary.AbsoluteSize.Y - target.Position.Y.Offset - 8)
            end
            target.Size = UDim2.fromOffset(width, height)
            safeCall(onResize, width, height)
        end)

        endConnection = connect(Services.UserInputService.InputEnded, function(ended)
            if isInputObject(ended) then
                resizing = false
            end
        end)
    end)
end

local function createLogo(parent, image)
    if image and image ~= "" then
        return create("ImageLabel", {
            Name = "Logo",
            BackgroundTransparency = 1,
            Image = image,
            ScaleType = Enum.ScaleType.Fit,
            Size = UDim2.fromOffset(27, 27),
            Parent = parent,
        })
    end

    local logo = create("Frame", {
        Name = "Logo",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(27, 27),
        Parent = parent,
    })
    local diamond = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = theme().Accent,
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0.5, 0.5),
        Rotation = 45,
        Size = UDim2.fromOffset(17, 17),
        Parent = logo,
    })
    corner(diamond, 4)
    local inner = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = theme().Background,
        BorderSizePixel = 0,
        Position = UDim2.fromScale(0.5, 0.5),
        Rotation = 45,
        Size = UDim2.fromOffset(8, 8),
        Parent = logo,
    })
    corner(inner, 2)
    create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, theme().AccentBright),
            ColorSequenceKeypoint.new(1, theme().AccentDark),
        }),
        Rotation = 45,
        Parent = diamond,
    })
    return logo
end

local function setTextColor(label, color)
    if label and label:IsA("TextLabel") or label and label:IsA("TextButton") then
        label.TextColor3 = color
    end
end

function Prism.SetTheme(name)
    if Themes[name] then
        Prism._themeName = name
        for _, window in ipairs(Prism.Windows) do
            if window and window.ApplyTheme then
                window:ApplyTheme()
            end
        end
    end
end

function Prism.GetTheme()
    return Prism._themeName
end

function Prism.Notify(options)
    options = type(options) == "table" and options or { Content = tostring(options) }
    for _, window in ipairs(Prism.Windows) do
        if window and window.Notify then
            return window:Notify(options)
        end
    end
end

function Prism.CreateWindow(options)
    options = options or {}
    local window = {
        Name = options.Name or options.Title or "Prism",
        SubTitle = options.SubTitle or options.Subtitle or "Premium interface",
        Flags = Prism.Flags,
        Connections = {},
        Tabs = {},
        Elements = {},
        Notifications = {},
        _destroyed = false,
        _minimized = false,
        _activeTab = nil,
    }
    table.insert(Prism.Windows, window)

    local gui = create("ScreenGui", {
        Name = "Prism_" .. tostring(math.random(100000, 999999)),
        DisplayOrder = options.DisplayOrder or 100,
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = PlayerGui,
    })
    window.Gui = gui

    local overlay = create("Frame", {
        Name = "Overlay",
        BackgroundColor3 = theme().Overlay,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        Visible = false,
        ZIndex = 1,
        Parent = gui,
    })
    local main = create("Frame", {
        Name = "Window",
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = theme().Background,
        BorderSizePixel = 0,
        ClipsDescendants = false,
        Position = UDim2.fromScale(0.5, 0.52),
        Size = UDim2.fromOffset(options.Width or 730, options.Height or 510),
        ZIndex = 2,
        Parent = gui,
    })
    corner(main, 14)
    stroke(main, theme().Border, 0.05, 1)
    window.Main = main

    local shadow = create("ImageLabel", {
        Name = "Shadow",
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Image = "rbxassetid://6014261993",
        ImageColor3 = Color3.new(0, 0, 0),
        ImageTransparency = 0.45,
        Position = UDim2.fromScale(0.5, 0.5),
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450),
        Size = UDim2.new(1, 52, 1, 52),
        ZIndex = 1,
        Parent = main,
    })
    shadow.LayoutOrder = -1

    local topbar = create("Frame", {
        Name = "Topbar",
        BackgroundColor3 = theme().Surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 63),
        ZIndex = 3,
        Parent = main,
    })
    corner(topbar, 14)
    local topbarMask = create("Frame", {
        BackgroundColor3 = theme().Surface,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 1, -14),
        Size = UDim2.new(1, 0, 0, 14),
        ZIndex = 3,
        Parent = topbar,
    })
    local logoHolder = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(18, 18),
        Size = UDim2.fromOffset(27, 27),
        ZIndex = 4,
        Parent = topbar,
    })
    createLogo(logoHolder, options.LogoImage)
    local title = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Position = UDim2.fromOffset(56, 13),
        Size = UDim2.new(0, 250, 0, 22),
        Text = window.Name,
        TextColor3 = theme().Text,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
        Parent = topbar,
    })
    local subtitle = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        Position = UDim2.fromOffset(57, 35),
        Size = UDim2.new(0, 280, 0, 16),
        Text = window.SubTitle,
        TextColor3 = theme().TextMuted,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
        Parent = topbar,
    })
    local dragHandle = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, -150, 1, 0),
        ZIndex = 5,
        Parent = topbar,
    })

    local function windowButton(text, x, color)
        local button = create("TextButton", {
            AutoButtonColor = false,
            BackgroundColor3 = theme().SurfaceRaised,
            BorderSizePixel = 0,
            Font = Enum.Font.GothamBold,
            Position = UDim2.new(1, x, 0, 19),
            Size = UDim2.fromOffset(27, 27),
            Text = text,
            TextColor3 = color or theme().TextMuted,
            TextSize = 13,
            ZIndex = 5,
            Parent = topbar,
        })
        corner(button, 8)
        stroke(button, theme().Border, 0.5, 1)
        connect(button.MouseEnter, function()
            tween(button, { BackgroundColor3 = theme().SurfaceHover }, 0.16, Enum.EasingStyle.Quad)
        end)
        connect(button.MouseLeave, function()
            tween(button, { BackgroundColor3 = theme().SurfaceRaised }, 0.16, Enum.EasingStyle.Quad)
        end)
        return button
    end

    local minimizeButton = windowButton("—", -104)
    local themeButton = windowButton("◐", -70)
    local closeButton = windowButton("×", -36, theme().Danger)

    local body = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 63),
        Size = UDim2.new(1, 0, 1, -63),
        ZIndex = 3,
        Parent = main,
    })
    local sidebar = create("Frame", {
        BackgroundColor3 = theme().Surface,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(178, 0),
        ZIndex = 3,
        Parent = body,
    })
    local sidebarMask = create("Frame", {
        BackgroundColor3 = theme().Surface,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -14, 0, 0),
        Size = UDim2.fromOffset(14, 600),
        ZIndex = 3,
        Parent = sidebar,
    })
    local tabList = create("ScrollingFrame", {
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(),
        Position = UDim2.fromOffset(12, 20),
        ScrollBarImageColor3 = theme().Border,
        ScrollBarThickness = 2,
        Size = UDim2.new(1, -24, 1, -76),
        ZIndex = 4,
        Parent = sidebar,
    })
    list(tabList, Enum.FillDirection.Vertical, 5)
    local searchBox = create("TextBox", {
        BackgroundColor3 = theme().SurfaceRaised,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Font = Enum.Font.Gotham,
        PlaceholderColor3 = theme().TextFaint,
        PlaceholderText = "Search elements  /",
        Position = UDim2.fromOffset(12, -1),
        Size = UDim2.new(1, -24, 0, 36),
        Text = "",
        TextColor3 = theme().Text,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 5,
        Parent = sidebar,
    })
    corner(searchBox, 9)
    stroke(searchBox, theme().Border, 0.55, 1)
    padding(searchBox, 11, 8, 0, 0)

    local content = create("Frame", {
        BackgroundColor3 = theme().Background,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(178, 0),
        Size = UDim2.new(1, -178, 1, 0),
        ZIndex = 3,
        Parent = body,
    })
    local contentTitle = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.GothamBold,
        Position = UDim2.fromOffset(24, 20),
        Size = UDim2.new(1, -48, 0, 25),
        Text = "Welcome",
        TextColor3 = theme().Text,
        TextSize = 20,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
        Parent = content,
    })
    local contentSubtitle = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = Enum.Font.Gotham,
        Position = UDim2.fromOffset(24, 47),
        Size = UDim2.new(1, -48, 0, 18),
        Text = "Choose a tab to get started.",
        TextColor3 = theme().TextMuted,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
        Parent = content,
    })
    local tabPages = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(18, 78),
        Size = UDim2.new(1, -36, 1, -88),
        ZIndex = 4,
        Parent = content,
    })
    local resizeHandle = create("TextButton", {
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -20, 1, -20),
        Size = UDim2.fromOffset(20, 20),
        Text = "⌟",
        TextColor3 = theme().TextFaint,
        TextSize = 16,
        ZIndex = 8,
        Parent = main,
    })

    window.Main = main
    window.Content = content
    window.TabPages = tabPages
    window.Search = searchBox

    local function updateSearch(query)
        query = string.lower(query or "")
        for _, element in ipairs(window.Elements) do
            if element.Root and element.Root.Parent then
                local matches = query == "" or string.find(string.lower(element.SearchText or ""), query, 1, true)
                element.Root.Visible = matches
            end
        end
    end
    connect(searchBox:GetPropertyChangedSignal("Text"), function()
        updateSearch(searchBox.Text)
    end)

    local function showWindow()
        main.Visible = true
        overlay.Visible = true
        main.Size = UDim2.fromOffset(main.AbsoluteSize.X, 0)
        overlay.BackgroundTransparency = 1
        tween(overlay, { BackgroundTransparency = 0.52 }, 0.25, Enum.EasingStyle.Sine)
        tween(main, { Size = UDim2.fromOffset(options.Width or 730, options.Height or 510) }, 0.42, Enum.EasingStyle.Quart)
    end

    function window:Toggle()
        if self._minimized then
            self:Open()
        else
            self:Minimize()
        end
    end

    function window:Open()
        self._minimized = false
        showWindow()
    end

    function window:Minimize()
        self._minimized = true
        tween(overlay, { BackgroundTransparency = 1 }, 0.2, Enum.EasingStyle.Sine)
        tween(main, { Size = UDim2.fromOffset(main.AbsoluteSize.X, 0) }, 0.3, Enum.EasingStyle.Quart)
        task.delay(0.3, function()
            if self._minimized and main.Parent then
                main.Visible = false
                overlay.Visible = false
            end
        end)
    end

    function window:Close()
        self._minimized = true
        tween(overlay, { BackgroundTransparency = 1 }, 0.2, Enum.EasingStyle.Sine)
        local closing = tween(main, { Size = UDim2.fromOffset(main.AbsoluteSize.X, 0) }, 0.28, Enum.EasingStyle.Quart)
        if closing then
            closing.Completed:Connect(function()
                if main.Parent then
                    main.Visible = false
                    overlay.Visible = false
                end
            end)
        end
    end

    function window:Destroy()
        if self._destroyed then
            return
        end
        self._destroyed = true
        for _, connection in ipairs(self.Connections) do
            disconnect(connection)
        end
        if self.Gui then
            self.Gui:Destroy()
        end
        for index, item in ipairs(Prism.Windows) do
            if item == self then
                table.remove(Prism.Windows, index)
                break
            end
        end
    end

    function window:ApplyTheme()
        if not self.Gui or not self.Gui.Parent then
            return
        end
        local current = theme()
        main.BackgroundColor3 = current.Background
        sidebar.BackgroundColor3 = current.Surface
        sidebarMask.BackgroundColor3 = current.Surface
        topbar.BackgroundColor3 = current.Surface
        topbarMask.BackgroundColor3 = current.Surface
        content.BackgroundColor3 = current.Background
        title.TextColor3 = current.Text
        subtitle.TextColor3 = current.TextMuted
        contentTitle.TextColor3 = current.Text
        contentSubtitle.TextColor3 = current.TextMuted
        searchBox.BackgroundColor3 = current.SurfaceRaised
        searchBox.TextColor3 = current.Text
        searchBox.PlaceholderColor3 = current.TextFaint
        resizeHandle.TextColor3 = current.TextFaint
        for _, element in ipairs(self.Elements) do
            if element.ApplyTheme then
                element:ApplyTheme()
            end
        end
    end

    function window:_registerElement(element, text)
        element.SearchText = text or ""
        table.insert(self.Elements, element)
        return element
    end

    function window:Notify(notice)
        notice = notice or {}
        local kind = string.lower(notice.Type or "info")
        local color = theme().Info
        if kind == "success" then color = theme().Success end
        if kind == "warn" or kind == "warning" then color = theme().Warning end
        if kind == "error" then color = theme().Danger end
        local holder = create("Frame", {
            BackgroundColor3 = theme().SurfaceRaised,
            BorderSizePixel = 0,
            Position = UDim2.new(1, 18, 0, 80),
            Size = UDim2.fromOffset(280, 72),
            ZIndex = 30,
            Parent = gui,
        })
        corner(holder, 10)
        stroke(holder, theme().Border, 0.2, 1)
        local accent = create("Frame", {
            BackgroundColor3 = color,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(3, 72),
            ZIndex = 31,
            Parent = holder,
        })
        corner(accent, 2)
        local notificationTitle = create("TextLabel", {
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            Position = UDim2.fromOffset(16, 13),
            Size = UDim2.new(1, -28, 0, 18),
            Text = notice.Title or "Prism",
            TextColor3 = theme().Text,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 31,
            Parent = holder,
        })
        local notificationBody = create("TextLabel", {
            BackgroundTransparency = 1,
            Font = Enum.Font.Gotham,
            Position = UDim2.fromOffset(16, 34),
            Size = UDim2.new(1, -28, 0, 28),
            Text = notice.Content or notice.Text or "",
            TextColor3 = theme().TextMuted,
            TextSize = 11,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            ZIndex = 31,
            Parent = holder,
        })
        table.insert(self.Notifications, holder)
        local offset = #self.Notifications
        holder.Position = UDim2.new(1, 18, 0, 80 + ((offset - 1) * 82))
        tween(holder, { Position = UDim2.new(1, -20, 0, 80 + ((offset - 1) * 82)) }, 0.35, Enum.EasingStyle.Quart)
        task.delay(notice.Duration or 4, function()
            if not holder.Parent then return end
            tween(holder, { Position = UDim2.new(1, 18, 0, holder.Position.Y.Offset) }, 0.3, Enum.EasingStyle.Quart)
            task.delay(0.3, function()
                for index, item in ipairs(self.Notifications) do
                    if item == holder then
                        table.remove(self.Notifications, index)
                        break
                    end
                end
                holder:Destroy()
            end)
        end)
        return holder
    end

    function window:AddTab(tabOptions)
        tabOptions = tabOptions or {}
        local tab = {
            Name = tabOptions.Name or "Tab",
            Icon = tabOptions.Icon or "",
            Elements = {},
            Window = self,
        }
        local tabButton = create("TextButton", {
            AutoButtonColor = false,
            BackgroundColor3 = theme().Surface,
            BorderSizePixel = 0,
            Font = Enum.Font.GothamMedium,
            Size = UDim2.new(1, 0, 0, 38),
            Text = "",
            ZIndex = 5,
            Parent = tabList,
        })
        corner(tabButton, 8)
        local tabLabel = create("TextLabel", {
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamMedium,
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(1, -20, 1, 0),
            Text = tab.Icon ~= "" and (tab.Icon .. "  " .. tab.Name) or tab.Name,
            TextColor3 = theme().TextMuted,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 6,
            Parent = tabButton,
        })
        local indicator = create("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            BackgroundColor3 = theme().Accent,
            BorderSizePixel = 0,
            Position = UDim2.new(1, -9, 0.5, 0),
            Size = UDim2.fromOffset(0, 2),
            ZIndex = 6,
            Parent = tabButton,
        })
        corner(indicator, 2)
        local page = create("ScrollingFrame", {
            AutomaticCanvasSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            CanvasSize = UDim2.new(),
            ScrollBarImageColor3 = theme().Border,
            ScrollBarThickness = 3,
            Size = UDim2.fromScale(1, 1),
            Visible = false,
            ZIndex = 5,
            Parent = tabPages,
        })
        padding(page, 4, 8, 4, 16)
        list(page, Enum.FillDirection.Vertical, 12)
        tab.Button = tabButton
        tab.Label = tabLabel
        tab.Indicator = indicator
        tab.Page = page
        table.insert(self.Tabs, tab)

        local function selectTab()
            for _, other in ipairs(self.Tabs) do
                other.Page.Visible = other == tab
                tween(other.Button, { BackgroundColor3 = other == tab and theme().SurfaceRaised or theme().Surface }, 0.2, Enum.EasingStyle.Quad)
                tween(other.Label, { TextColor3 = other == tab and theme().Text or theme().TextMuted }, 0.2, Enum.EasingStyle.Quad)
                tween(other.Indicator, { Size = UDim2.fromOffset(other == tab and 16 or 0, 2) }, 0.25, Enum.EasingStyle.Quart)
            end
            self._activeTab = tab
            contentTitle.Text = tab.Name
            contentSubtitle.Text = tabOptions.Description or "Configure your experience."
            for _, element in ipairs(self.Elements) do
                if element.Root and element.Root.Parent then
                    element.Root.Visible = string.find(string.lower(element.SearchText or ""), string.lower(searchBox.Text), 1, true) ~= nil
                end
            end
        end
        connect(tabButton.MouseEnter, function()
            if self._activeTab ~= tab then
                tween(tabButton, { BackgroundColor3 = theme().SurfaceHover }, 0.15, Enum.EasingStyle.Quad)
            end
        end)
        connect(tabButton.MouseLeave, function()
            if self._activeTab ~= tab then
                tween(tabButton, { BackgroundColor3 = theme().Surface }, 0.15, Enum.EasingStyle.Quad)
            end
        end)
        connect(tabButton.Activated, selectTab)

        function tab:_add(root, searchText)
            local element = { Root = root, Tab = self, SearchText = searchText or "" }
            table.insert(self.Elements, element)
            window:_registerElement(element, searchText)
            return element
        end

        function tab:AddSection(sectionOptions)
            sectionOptions = sectionOptions or {}
            local section = create("Frame", {
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundColor3 = theme().Surface,
                BorderSizePixel = 0,
                LayoutOrder = #tab.Elements + 1,
                Size = UDim2.new(1, -8, 0, 0),
                Parent = page,
            })
            corner(section, 10)
            stroke(section, theme().Border, 0.45, 1)
            padding(section, 14, 14, 13, 14)
            list(section, Enum.FillDirection.Vertical, 10)
            local sectionTitle = create("TextLabel", {
                AutomaticSize = Enum.AutomaticSize.Y,
                BackgroundTransparency = 1,
                Font = Enum.Font.GothamBold,
                LayoutOrder = 1,
                Size = UDim2.new(1, 0, 0, 18),
                Text = sectionOptions.Name or sectionOptions.Title or "Section",
                TextColor3 = theme().Text,
                TextSize = 13,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = section,
            })
            section._title = sectionTitle
            local sectionApi = { Root = section, Tab = self, Window = self.Window }
            function sectionApi:ApplyTheme()
                section.BackgroundColor3 = theme().Surface
                sectionTitle.TextColor3 = theme().Text
            end
            function sectionApi:AddLabel(textOptions)
                textOptions = type(textOptions) == "table" and textOptions or { Text = textOptions }
                local label = create("TextLabel", {
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1,
                    Font = Enum.Font.Gotham,
                    LayoutOrder = #tab.Elements + 1,
                    Size = UDim2.new(1, 0, 0, 18),
                    Text = textOptions.Text or textOptions.Content or "",
                    TextColor3 = theme().TextMuted,
                    TextSize = textOptions.TextSize or 12,
                    TextWrapped = true,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = section,
                })
                local element = tab:_add(label, textOptions.Text or "")
                function element:Set(value)
                    label.Text = tostring(value)
                end
                function element:ApplyTheme()
                    label.TextColor3 = theme().TextMuted
                end
                return element
            end
            function sectionApi:AddParagraph(textOptions)
                textOptions = textOptions or {}
                local paragraph = create("Frame", {
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundColor3 = theme().SurfaceRaised,
                    BorderSizePixel = 0,
                    LayoutOrder = #tab.Elements + 1,
                    Size = UDim2.new(1, 0, 0, 0),
                    Parent = section,
                })
                corner(paragraph, 8)
                padding(paragraph, 11, 11, 9, 9)
                local paragraphTitle = create("TextLabel", {
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1,
                    Font = Enum.Font.GothamBold,
                    Size = UDim2.new(1, 0, 0, 17),
                    Text = textOptions.Title or "Note",
                    TextColor3 = theme().Text,
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = paragraph,
                })
                local paragraphBody = create("TextLabel", {
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1,
                    Font = Enum.Font.Gotham,
                    Size = UDim2.new(1, 0, 0, 17),
                    Text = textOptions.Content or textOptions.Text or "",
                    TextColor3 = theme().TextMuted,
                    TextSize = 11,
                    TextWrapped = true,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = paragraph,
                })
                list(paragraph, Enum.FillDirection.Vertical, 4)
                local element = tab:_add(paragraph, (textOptions.Title or "") .. " " .. (textOptions.Content or ""))
                function element:ApplyTheme()
                    paragraph.BackgroundColor3 = theme().SurfaceRaised
                    paragraphTitle.TextColor3 = theme().Text
                    paragraphBody.TextColor3 = theme().TextMuted
                end
                return element
            end
            function sectionApi:AddDivider()
                local divider = create("Frame", {
                    BackgroundColor3 = theme().Border,
                    BackgroundTransparency = 0.45,
                    BorderSizePixel = 0,
                    LayoutOrder = #tab.Elements + 1,
                    Size = UDim2.new(1, 0, 0, 1),
                    Parent = section,
                })
                return tab:_add(divider, "divider")
            end
            function sectionApi:AddButton(buttonOptions)
                buttonOptions = type(buttonOptions) == "table" and buttonOptions or { Name = buttonOptions }
                local button = create("TextButton", {
                    AutoButtonColor = false,
                    BackgroundColor3 = theme().SurfaceRaised,
                    BorderSizePixel = 0,
                    Font = Enum.Font.GothamMedium,
                    LayoutOrder = #tab.Elements + 1,
                    Size = UDim2.new(1, 0, 0, 39),
                    Text = buttonOptions.Name or buttonOptions.Text or "Button",
                    TextColor3 = theme().Text,
                    TextSize = 12,
                    Parent = section,
                })
                corner(button, 8)
                stroke(button, theme().Border, 0.4, 1)
                local buttonColor = buttonOptions.Style == "Danger" and theme().Danger
                    or buttonOptions.Style == "Primary" and theme().Accent
                    or theme().SurfaceRaised
                button.BackgroundColor3 = buttonColor
                connect(button.MouseEnter, function()
                    tween(button, { BackgroundColor3 = buttonOptions.Style == "Primary" and theme().AccentBright or theme().SurfaceHover }, 0.16, Enum.EasingStyle.Quad)
                end)
                connect(button.MouseLeave, function()
                    tween(button, { BackgroundColor3 = buttonColor }, 0.16, Enum.EasingStyle.Quad)
                end)
                connect(button.Activated, function()
                    safeCall(buttonOptions.Callback)
                end)
                local element = tab:_add(button, buttonOptions.Name or buttonOptions.Text or "")
                function element:ApplyTheme()
                    buttonColor = buttonOptions.Style == "Danger" and theme().Danger
                        or buttonOptions.Style == "Primary" and theme().Accent
                        or theme().SurfaceRaised
                    button.BackgroundColor3 = buttonColor
                    button.TextColor3 = theme().Text
                end
                function element:Press()
                    safeCall(buttonOptions.Callback)
                end
                return element
            end
            function sectionApi:AddToggle(toggleOptions)
                toggleOptions = toggleOptions or {}
                local flag = toggleOptions.Flag
                local value = toggleOptions.CurrentValue == true or toggleOptions.Default == true
                if flag then self.Window.Flags[flag] = value end
                local row = create("Frame", {
                    BackgroundTransparency = 1,
                    LayoutOrder = #tab.Elements + 1,
                    Size = UDim2.new(1, 0, 0, 39),
                    Parent = section,
                })
                local label = create("TextLabel", {
                    BackgroundTransparency = 1,
                    Font = Enum.Font.GothamMedium,
                    Size = UDim2.new(1, -64, 1, 0),
                    Text = toggleOptions.Name or "Toggle",
                    TextColor3 = theme().Text,
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = row,
                })
                local switch = create("TextButton", {
                    AutoButtonColor = false,
                    BackgroundColor3 = theme().SurfaceRaised,
                    BorderSizePixel = 0,
                    Position = UDim2.new(1, -45, 0.5, -11),
                    Size = UDim2.fromOffset(45, 22),
                    Text = "",
                    Parent = row,
                })
                corner(switch, 12)
                stroke(switch, theme().Border, 0.3, 1)
                local knob = create("Frame", {
                    BackgroundColor3 = theme().TextMuted,
                    BorderSizePixel = 0,
                    Position = UDim2.fromOffset(4, 4),
                    Size = UDim2.fromOffset(14, 14),
                    Parent = switch,
                })
                corner(knob, 8)
                local function render(nextValue, fire)
                    value = nextValue == true
                    if flag then self.Window.Flags[flag] = value end
                    tween(switch, { BackgroundColor3 = value and theme().Accent or theme().SurfaceRaised }, 0.2, Enum.EasingStyle.Quart)
                    tween(knob, {
                        BackgroundColor3 = value and Color3.new(1, 1, 1) or theme().TextMuted,
                        Position = value and UDim2.fromOffset(27, 4) or UDim2.fromOffset(4, 4),
                    }, 0.3, Enum.EasingStyle.Back)
                    if fire then safeCall(toggleOptions.Callback, value) end
                end
                render(value, false)
                connect(switch.Activated, function() render(not value, true) end)
                local element = tab:_add(row, toggleOptions.Name or "")
                function element:Set(newValue) render(newValue, true) end
                function element:Get() return value end
                function element:ApplyTheme()
                    label.TextColor3 = theme().Text
                    render(value, false)
                end
                return element
            end
            function sectionApi:AddSlider(sliderOptions)
                sliderOptions = sliderOptions or {}
                local minimum = sliderOptions.Min or sliderOptions.Minimum or 0
                local maximum = sliderOptions.Max or sliderOptions.Maximum or 100
                local value = clamp(sliderOptions.Default or sliderOptions.CurrentValue or minimum, minimum, maximum)
                local flag = sliderOptions.Flag
                if flag then self.Window.Flags[flag] = value end
                local row = create("Frame", {
                    BackgroundTransparency = 1,
                    LayoutOrder = #tab.Elements + 1,
                    Size = UDim2.new(1, 0, 0, 52),
                    Parent = section,
                })
                local label = create("TextLabel", {
                    BackgroundTransparency = 1,
                    Font = Enum.Font.GothamMedium,
                    Size = UDim2.new(1, -78, 0, 20),
                    Text = sliderOptions.Name or "Slider",
                    TextColor3 = theme().Text,
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = row,
                })
                local valueLabel = create("TextLabel", {
                    BackgroundTransparency = 1,
                    Font = Enum.Font.GothamBold,
                    Position = UDim2.new(1, -65, 0, 0),
                    Size = UDim2.fromOffset(65, 20),
                    Text = tostring(value),
                    TextColor3 = theme().AccentBright,
                    TextSize = 11,
                    TextXAlignment = Enum.TextXAlignment.Right,
                    Parent = row,
                })
                local track = create("Frame", {
                    AnchorPoint = Vector2.new(0, 1),
                    BackgroundColor3 = theme().SurfaceRaised,
                    BorderSizePixel = 0,
                    Position = UDim2.new(0, 0, 1, -5),
                    Size = UDim2.new(1, 0, 0, 6),
                    Parent = row,
                })
                corner(track, 4)
                local fill = create("Frame", {
                    BackgroundColor3 = theme().Accent,
                    BorderSizePixel = 0,
                    Size = UDim2.fromScale((value - minimum) / (maximum - minimum == 0 and 1 or maximum - minimum), 1),
                    Parent = track,
                })
                corner(fill, 4)
                local knob = create("Frame", {
                    AnchorPoint = Vector2.new(0.5, 0.5),
                    BackgroundColor3 = Color3.new(1, 1, 1),
                    BorderSizePixel = 0,
                    Position = UDim2.fromScale((value - minimum) / (maximum - minimum == 0 and 1 or maximum - minimum), 0.5),
                    Size = UDim2.fromOffset(13, 13),
                    Parent = track,
                })
                corner(knob, 8)
                stroke(knob, theme().Accent, 0, 1)
                local draggingSlider = false
                local function render(nextValue, fire)
                    value = clamp(nextValue, minimum, maximum)
                    local ratio = (value - minimum) / (maximum - minimum == 0 and 1 or maximum - minimum)
                    if sliderOptions.Rounding then
                        local multiplier = 10 ^ sliderOptions.Rounding
                        value = math.floor(value * multiplier + 0.5) / multiplier
                    end
                    if flag then self.Window.Flags[flag] = value end
                    valueLabel.Text = tostring(value)
                    tween(fill, { Size = UDim2.fromScale(ratio, 1) }, 0.18, Enum.EasingStyle.Quart)
                    tween(knob, { Position = UDim2.fromScale(ratio, 0.5) }, 0.18, Enum.EasingStyle.Quart)
                    if fire then safeCall(sliderOptions.Callback, value) end
                end
                local function fromPosition(position)
                    local ratio = clamp((position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
                    render(minimum + (maximum - minimum) * ratio, true)
                end
                connect(track.InputBegan, function(input)
                    if isInputObject(input) then
                        draggingSlider = true
                        fromPosition(getInputPosition(input))
                    end
                end)
                connect(Services.UserInputService.InputChanged, function(input)
                    if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                        fromPosition(getInputPosition(input))
                    end
                end)
                connect(Services.UserInputService.InputEnded, function(input)
                    if isInputObject(input) then draggingSlider = false end
                end)
                local element = tab:_add(row, sliderOptions.Name or "")
                function element:Set(newValue) render(newValue, true) end
                function element:Get() return value end
                function element:ApplyTheme()
                    label.TextColor3 = theme().Text
                    valueLabel.TextColor3 = theme().AccentBright
                    track.BackgroundColor3 = theme().SurfaceRaised
                    fill.BackgroundColor3 = theme().Accent
                    render(value, false)
                end
                return element
            end
            function sectionApi:AddInput(inputOptions)
                inputOptions = inputOptions or {}
                local flag = inputOptions.Flag
                local value = inputOptions.Default or inputOptions.CurrentValue or ""
                if flag then self.Window.Flags[flag] = value end
                local row = create("Frame", {
                    BackgroundTransparency = 1,
                    LayoutOrder = #tab.Elements + 1,
                    Size = UDim2.new(1, 0, 0, 64),
                    Parent = section,
                })
                local label = create("TextLabel", {
                    BackgroundTransparency = 1,
                    Font = Enum.Font.GothamMedium,
                    Size = UDim2.new(1, 0, 0, 19),
                    Text = inputOptions.Name or "Input",
                    TextColor3 = theme().Text,
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = row,
                })
                local input = create("TextBox", {
                    BackgroundColor3 = theme().SurfaceRaised,
                    BorderSizePixel = 0,
                    ClearTextOnFocus = false,
                    Font = Enum.Font.Gotham,
                    Position = UDim2.fromOffset(0, 25),
                    PlaceholderColor3 = theme().TextFaint,
                    PlaceholderText = inputOptions.PlaceholderText or "Type here...",
                    Size = UDim2.new(1, 0, 0, 35),
                    Text = value,
                    TextColor3 = theme().Text,
                    TextSize = 11,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = row,
                })
                corner(input, 8)
                stroke(input, theme().Border, 0.35, 1)
                padding(input, 10, 10, 0, 0)
                connect(input.Focused, function() tween(input, { BackgroundColor3 = theme().SurfaceHover }, 0.15, Enum.EasingStyle.Quad) end)
                connect(input.FocusLost, function(enterPressed)
                    value = input.Text
                    if flag then self.Window.Flags[flag] = value end
                    safeCall(inputOptions.Callback, value)
                end)
                local element = tab:_add(row, inputOptions.Name or "")
                function element:Set(newValue)
                    value = tostring(newValue)
                    input.Text = value
                    if flag then self.Window.Flags[flag] = value end
                end
                function element:Get() return value end
                function element:ApplyTheme()
                    label.TextColor3 = theme().Text
                    input.BackgroundColor3 = theme().SurfaceRaised
                    input.TextColor3 = theme().Text
                    input.PlaceholderColor3 = theme().TextFaint
                end
                return element
            end
            function sectionApi:AddDropdown(dropdownOptions)
                dropdownOptions = dropdownOptions or {}
                local values = dropdownOptions.Options or dropdownOptions.Values or {}
                local selected = dropdownOptions.CurrentOption or dropdownOptions.Default or values[1]
                local flag = dropdownOptions.Flag
                if flag then self.Window.Flags[flag] = selected end
                local open = false
                local row = create("Frame", {
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1,
                    LayoutOrder = #tab.Elements + 1,
                    Size = UDim2.new(1, 0, 0, 62),
                    Parent = section,
                })
                local label = create("TextLabel", {
                    BackgroundTransparency = 1,
                    Font = Enum.Font.GothamMedium,
                    Size = UDim2.new(1, 0, 0, 19),
                    Text = dropdownOptions.Name or "Dropdown",
                    TextColor3 = theme().Text,
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = row,
                })
                local dropdown = create("TextButton", {
                    AutoButtonColor = false,
                    BackgroundColor3 = theme().SurfaceRaised,
                    BorderSizePixel = 0,
                    Position = UDim2.fromOffset(0, 25),
                    Size = UDim2.new(1, 0, 0, 35),
                    Text = tostring(selected or "Select...") .. "  ▾",
                    TextColor3 = theme().TextMuted,
                    TextSize = 11,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = row,
                })
                corner(dropdown, 8)
                stroke(dropdown, theme().Border, 0.35, 1)
                padding(dropdown, 10, 10, 0, 0)
                local optionList = create("Frame", {
                    BackgroundColor3 = theme().SurfaceRaised,
                    BorderSizePixel = 0,
                    Position = UDim2.fromOffset(0, 64),
                    Size = UDim2.new(1, 0, 0, 0),
                    Visible = false,
                    ZIndex = 20,
                    Parent = row,
                })
                corner(optionList, 8)
                stroke(optionList, theme().Border, 0.1, 1)
                padding(optionList, 5, 5, 5, 5)
                list(optionList, Enum.FillDirection.Vertical, 3)
                local optionButtons = {}
                local function choose(option)
                    selected = option
                    if flag then self.Window.Flags[flag] = selected end
                    dropdown.Text = tostring(selected) .. "  ▾"
                    safeCall(dropdownOptions.Callback, selected)
                    open = false
                    optionList.Visible = false
                    tween(optionList, { Size = UDim2.new(1, 0, 0, 0) }, 0.2, Enum.EasingStyle.Quart)
                end
                for _, option in ipairs(values) do
                    local optionButton = create("TextButton", {
                        AutoButtonColor = false,
                        BackgroundColor3 = theme().SurfaceRaised,
                        BorderSizePixel = 0,
                        Font = Enum.Font.Gotham,
                        Size = UDim2.new(1, 0, 0, 28),
                        Text = tostring(option),
                        TextColor3 = theme().TextMuted,
                        TextSize = 11,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        ZIndex = 21,
                        Parent = optionList,
                    })
                    corner(optionButton, 6)
                    padding(optionButton, 8, 6, 0, 0)
                    connect(optionButton.MouseEnter, function() optionButton.BackgroundColor3 = theme().SurfaceHover end)
                    connect(optionButton.MouseLeave, function() optionButton.BackgroundColor3 = theme().SurfaceRaised end)
                    connect(optionButton.Activated, function() choose(option) end)
                    table.insert(optionButtons, optionButton)
                end
                local function toggleOpen()
                    open = not open
                    optionList.Visible = open
                    if open then
                        local height = math.min(150, (#values * 31) + 10)
                        tween(optionList, { Size = UDim2.new(1, 0, 0, height) }, 0.25, Enum.EasingStyle.Quart)
                    else
                        tween(optionList, { Size = UDim2.new(1, 0, 0, 0) }, 0.2, Enum.EasingStyle.Quart)
                        task.delay(0.2, function() if not open then optionList.Visible = false end end)
                    end
                end
                connect(dropdown.Activated, toggleOpen)
                local element = tab:_add(row, dropdownOptions.Name or "")
                function element:Set(newValue) choose(newValue) end
                function element:Get() return selected end
                function element:ApplyTheme()
                    label.TextColor3 = theme().Text
                    dropdown.BackgroundColor3 = theme().SurfaceRaised
                    dropdown.TextColor3 = theme().TextMuted
                    optionList.BackgroundColor3 = theme().SurfaceRaised
                    for _, button in ipairs(optionButtons) do button.BackgroundColor3 = theme().SurfaceRaised end
                end
                return element
            end
            function sectionApi:AddKeybind(keybindOptions)
                keybindOptions = keybindOptions or {}
                local current = keybindOptions.CurrentKeybind or keybindOptions.Default or Enum.KeyCode.RightControl
                local listening = false
                local row = create("Frame", {
                    BackgroundTransparency = 1,
                    LayoutOrder = #tab.Elements + 1,
                    Size = UDim2.new(1, 0, 0, 39),
                    Parent = section,
                })
                local label = create("TextLabel", {
                    BackgroundTransparency = 1,
                    Font = Enum.Font.GothamMedium,
                    Size = UDim2.new(1, -110, 1, 0),
                    Text = keybindOptions.Name or "Keybind",
                    TextColor3 = theme().Text,
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = row,
                })
                local keyButton = create("TextButton", {
                    AutoButtonColor = false,
                    BackgroundColor3 = theme().SurfaceRaised,
                    BorderSizePixel = 0,
                    Position = UDim2.new(1, -105, 0.5, -15),
                    Size = UDim2.fromOffset(105, 30),
                    Text = current.Name,
                    TextColor3 = theme().TextMuted,
                    TextSize = 10,
                    Parent = row,
                })
                corner(keyButton, 7)
                stroke(keyButton, theme().Border, 0.4, 1)
                connect(keyButton.Activated, function()
                    listening = not listening
                    keyButton.Text = listening and "Press a key..." or current.Name
                    tween(keyButton, { BackgroundColor3 = listening and theme().Accent or theme().SurfaceRaised }, 0.18, Enum.EasingStyle.Quad)
                end)
                connect(Services.UserInputService.InputBegan, function(input, processed)
                    if processed or not listening then return end
                    if input.UserInputType == Enum.UserInputType.Keyboard then
                        current = input.KeyCode
                        listening = false
                        keyButton.Text = current.Name
                        tween(keyButton, { BackgroundColor3 = theme().SurfaceRaised }, 0.18, Enum.EasingStyle.Quad)
                        safeCall(keybindOptions.ChangedCallback, current)
                    end
                end)
                local element = tab:_add(row, keybindOptions.Name or "")
                function element:Get() return current end
                function element:Set(newKey) current = newKey; keyButton.Text = newKey.Name end
                function element:ApplyTheme()
                    label.TextColor3 = theme().Text
                    keyButton.BackgroundColor3 = theme().SurfaceRaised
                    keyButton.TextColor3 = theme().TextMuted
                end
                return element
            end
            function sectionApi:AddColorPicker(colorOptions)
                colorOptions = colorOptions or {}
                local selected = colorOptions.Color or colorOptions.Default or theme().Accent
                local row = create("Frame", {
                    BackgroundTransparency = 1,
                    LayoutOrder = #tab.Elements + 1,
                    Size = UDim2.new(1, 0, 0, 39),
                    ZIndex = 12,
                    Parent = section,
                })
                local label = create("TextLabel", {
                    BackgroundTransparency = 1,
                    Font = Enum.Font.GothamMedium,
                    Size = UDim2.new(1, -55, 1, 0),
                    Text = colorOptions.Name or "Color",
                    TextColor3 = theme().Text,
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Parent = row,
                })
                local swatch = create("TextButton", {
                    AutoButtonColor = false,
                    BackgroundColor3 = selected,
                    BorderSizePixel = 0,
                    Position = UDim2.new(1, -42, 0.5, -13),
                    Size = UDim2.fromOffset(42, 26),
                    Text = "",
                    ZIndex = 13,
                    Parent = row,
                })
                corner(swatch, 7)
                stroke(swatch, theme().Border, 0.25, 1)
                local popup = create("Frame", {
                    BackgroundColor3 = theme().SurfaceRaised,
                    BorderSizePixel = 0,
                    Position = UDim2.new(1, -220, 1, 5),
                    Size = UDim2.fromOffset(210, 133),
                    Visible = false,
                    ZIndex = 25,
                    Parent = row,
                })
                corner(popup, 9)
                stroke(popup, theme().Border, 0.15, 1)
                padding(popup, 10, 10, 10, 10)
                local popupTitle = create("TextLabel", {
                    BackgroundTransparency = 1,
                    Font = Enum.Font.GothamBold,
                    Size = UDim2.new(1, 0, 0, 16),
                    Text = "Color",
                    TextColor3 = theme().Text,
                    TextSize = 11,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 26,
                    Parent = popup,
                })
                local inputList = create("Frame", {
                    BackgroundTransparency = 1,
                    Position = UDim2.fromOffset(0, 25),
                    Size = UDim2.new(1, 0, 0, 30),
                    ZIndex = 26,
                    Parent = popup,
                })
                list(inputList, Enum.FillDirection.Horizontal, 6)
                local colorInputs = {}
                for _, channel in ipairs({ "R", "G", "B" }) do
                    local channelBox = create("TextBox", {
                        BackgroundColor3 = theme().Surface,
                        BorderSizePixel = 0,
                        ClearTextOnFocus = false,
                        Font = Enum.Font.Gotham,
                        PlaceholderText = channel,
                        Size = UDim2.fromOffset(56, 30),
                        Text = "",
                        TextColor3 = theme().Text,
                        TextSize = 10,
                        ZIndex = 27,
                        Parent = inputList,
                    })
                    corner(channelBox, 6)
                    padding(channelBox, 7, 5, 0, 0)
                    colorInputs[channel] = channelBox
                end
                local preview = create("Frame", {
                    BackgroundColor3 = selected,
                    BorderSizePixel = 0,
                    Position = UDim2.fromOffset(0, 70),
                    Size = UDim2.new(1, 0, 0, 24),
                    ZIndex = 26,
                    Parent = popup,
                })
                corner(preview, 6)
                local applyButton = create("TextButton", {
                    AutoButtonColor = false,
                    BackgroundColor3 = theme().Accent,
                    BorderSizePixel = 0,
                    Font = Enum.Font.GothamBold,
                    Position = UDim2.new(1, -58, 1, -32),
                    Size = UDim2.fromOffset(58, 25),
                    Text = "Apply",
                    TextColor3 = Color3.new(1, 1, 1),
                    TextSize = 10,
                    ZIndex = 27,
                    Parent = popup,
                })
                corner(applyButton, 6)
                local open = false
                local function syncInputs()
                    colorInputs.R.Text = tostring(math.floor(selected.R * 255 + 0.5))
                    colorInputs.G.Text = tostring(math.floor(selected.G * 255 + 0.5))
                    colorInputs.B.Text = tostring(math.floor(selected.B * 255 + 0.5))
                    preview.BackgroundColor3 = selected
                end
                local function applyColor()
                    local red = clamp(tonumber(colorInputs.R.Text) or selected.R * 255, 0, 255)
                    local green = clamp(tonumber(colorInputs.G.Text) or selected.G * 255, 0, 255)
                    local blue = clamp(tonumber(colorInputs.B.Text) or selected.B * 255, 0, 255)
                    selected = Color3.fromRGB(math.floor(red + 0.5), math.floor(green + 0.5), math.floor(blue + 0.5))
                    swatch.BackgroundColor3 = selected
                    syncInputs()
                    safeCall(colorOptions.Callback, selected)
                end
                connect(swatch.Activated, function()
                    open = not open
                    popup.Visible = open
                    if open then syncInputs() end
                end)
                connect(applyButton.Activated, function()
                    applyColor()
                    open = false
                    popup.Visible = false
                end)
                for _, box in pairs(colorInputs) do
                    connect(box.FocusLost, function() applyColor() end)
                end
                local element = tab:_add(row, colorOptions.Name or "")
                function element:Set(newColor)
                    selected = newColor
                    swatch.BackgroundColor3 = selected
                    syncInputs()
                    safeCall(colorOptions.Callback, selected)
                end
                function element:Get() return selected end
                function element:ApplyTheme()
                    label.TextColor3 = theme().Text
                    popup.BackgroundColor3 = theme().SurfaceRaised
                    popupTitle.TextColor3 = theme().Text
                    preview.BackgroundColor3 = selected
                    for _, box in pairs(colorInputs) do
                        box.BackgroundColor3 = theme().Surface
                        box.TextColor3 = theme().Text
                    end
                    applyButton.BackgroundColor3 = theme().Accent
                end
                return element
            end
            return sectionApi
        end

        if #self.Tabs == 1 then
            selectTab()
        end
        return tab
    end

    makeDraggable(dragHandle, main, gui)
    makeResizable(resizeHandle, main, Vector2.new(480, 330), gui)
    connect(minimizeButton.Activated, function() window:Minimize() end)
    connect(closeButton.Activated, function() window:Close() end)
    connect(themeButton.Activated, function()
        Prism.SetTheme(Prism.GetTheme() == "Dark" and "Light" or "Dark")
    end)
    connect(Services.UserInputService.InputBegan, function(input, processed)
        if processed then return end
        local key = options.ToggleKey or Enum.KeyCode.RightControl
        if input.KeyCode == key then
            if main.Visible then window:Minimize() else window:Open() end
        end
    end)

    window:Open()
    return window
end

function Prism.SaveConfiguration(name)
    if type(writefile) ~= "function" then
        return false, "writefile is unavailable in this executor"
    end
    local fileName = tostring(name or "PrismConfig") .. ".json"
    local encoded = Services.HttpService:JSONEncode(Prism.Flags)
    local ok, errorMessage = pcall(writefile, fileName, encoded)
    return ok, errorMessage
end

function Prism.LoadConfiguration(name)
    if type(readfile) ~= "function" or type(isfile) ~= "function" then
        return false, "readfile/isfile is unavailable in this executor"
    end
    local fileName = tostring(name or "PrismConfig") .. ".json"
    if not isfile(fileName) then
        return false, "configuration does not exist"
    end
    local ok, data = pcall(readfile, fileName)
    if not ok then return false, data end
    local decodedOk, decoded = pcall(Services.HttpService.JSONDecode, Services.HttpService, data)
    if not decodedOk or type(decoded) ~= "table" then
        return false, "invalid configuration"
    end
    for flag, value in pairs(decoded) do
        Prism.Flags[flag] = value
    end
    return true, decoded
end

function Prism.Destroy()
    for _, window in ipairs(Prism.Windows) do
        if window and window.Destroy then window:Destroy() end
    end
    for _, connection in ipairs(Prism._connections) do
        disconnect(connection)
    end
    Prism._connections = {}
    Prism.Windows = {}
end

return Prism