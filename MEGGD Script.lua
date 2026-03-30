local user_input_service = game:GetService("UserInputService")
local tween_service = game:GetService("TweenService")
local run_service = game:GetService("RunService")
local text_service = game:GetService("TextService")
local core_gui = game:GetService("CoreGui")

local themes = {
    dark_blue = {
        bg = Color3.fromRGB(15, 20, 30),
        element_bg = Color3.fromRGB(25, 30, 45),
        border = Color3.fromRGB(40, 50, 70),
        text = Color3.fromRGB(200, 210, 230),
        accent = Color3.fromRGB(60, 120, 210)
    },
    dracula = {
        bg = Color3.fromRGB(40, 42, 54),
        element_bg = Color3.fromRGB(68, 71, 90),
        border = Color3.fromRGB(98, 114, 164),
        text = Color3.fromRGB(248, 248, 242),
        accent = Color3.fromRGB(189, 147, 249)
    },
    monokai = {
        bg = Color3.fromRGB(39, 40, 34),
        element_bg = Color3.fromRGB(62, 61, 50),
        border = Color3.fromRGB(117, 113, 94),
        text = Color3.fromRGB(248, 248, 242),
        accent = Color3.fromRGB(249, 38, 114)
    },
    vscode = {
        bg = Color3.fromRGB(30, 30, 30),
        element_bg = Color3.fromRGB(37, 37, 38),
        border = Color3.fromRGB(62, 62, 66),
        text = Color3.fromRGB(212, 212, 212),
        accent = Color3.fromRGB(10, 119, 215)
    }
}

local type_colors = {
    LocalScript = Color3.fromRGB(86, 156, 214),
    ModuleScript = Color3.fromRGB(78, 201, 176),
    Script = Color3.fromRGB(197, 134, 192)
}

local current_theme = themes.vscode
local flat_image = "rbxassetid://2790382281"
local decompile_cache = {}

local function create_instance(class_name, properties)
    local instance = Instance.new(class_name)
    for property, value in pairs(properties) do
        instance[property] = value
    end
    return instance
end

local gui_parent = gethui and gethui() or core_gui
local screen_gui = create_instance("ScreenGui", {
    Name = "pixel_decompiler_gui",
    Parent = gui_parent,
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling
})

local main_gui = create_instance("Frame", {
    Name = "main_container",
    Parent = screen_gui,
    BackgroundColor3 = current_theme.bg,
    BorderSizePixel = 2,
    BorderColor3 = current_theme.border,
    Position = UDim2.new(0.5, -200, 0.5, -150),
    Size = UDim2.new(0, 420, 0, 360),
    Active = true,
    ClipsDescendants = true
})

local resize_handle = create_instance("Frame", {
    Name = "resize_handle",
    Parent = screen_gui,
    BackgroundTransparency = 1,
    Size = UDim2.new(0, 20, 0, 20),
    Active = true,
    ZIndex = 10,
    AnchorPoint = Vector2.new(0, 0)
})

local handle_part_h = create_instance("Frame", {
    Parent = resize_handle,
    BackgroundColor3 = current_theme.accent,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 1, -4),
    Size = UDim2.new(1, 0, 0, 4)
})

local handle_part_v = create_instance("Frame", {
    Parent = resize_handle,
    BackgroundColor3 = current_theme.accent,
    BorderSizePixel = 0,
    Position = UDim2.new(1, -4, 0, 0),
    Size = UDim2.new(0, 4, 1, 0)
})

local function update_resize_handle_position()
    resize_handle.Position = UDim2.new(
        0, main_gui.AbsolutePosition.X + main_gui.AbsoluteSize.X - 2,
        0, main_gui.AbsolutePosition.Y + main_gui.AbsoluteSize.Y - 2
    )
end

main_gui:GetPropertyChangedSignal("AbsolutePosition"):Connect(update_resize_handle_position)
main_gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(update_resize_handle_position)
task.spawn(function()
    task.wait()
    update_resize_handle_position()
end)

local top_bar = create_instance("Frame", {
    Parent = main_gui,
    BackgroundColor3 = current_theme.element_bg,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 46),
    ClipsDescendants = true
})

local meggd_badge = create_instance("Frame", {
    Parent = top_bar,
    BackgroundColor3 = Color3.fromRGB(85, 175, 205),
    BorderSizePixel = 0,
    Position = UDim2.new(0, 10, 0, 7),
    Size = UDim2.new(0, 62, 0, 14)
})

local meggd_text = create_instance("TextLabel", {
    Parent = meggd_badge,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(1, 0, 1, 0),
    Font = Enum.Font.Arcade,
    Text = "MEGGD",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Center,
    TextYAlignment = Enum.TextYAlignment.Center
})

local title_text = create_instance("TextLabel", {
    Parent = top_bar,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 10, 0, 20),
    Size = UDim2.new(0, 150, 0, 18),
    Font = Enum.Font.Arcade,
    Text = "Script Scanner",
    TextColor3 = current_theme.text,
    TextSize = 18,
    TextXAlignment = Enum.TextXAlignment.Left
})

local theme_button = create_instance("TextButton", {
    Parent = top_bar,
    BackgroundColor3 = current_theme.bg,
    BorderColor3 = current_theme.border,
    BorderSizePixel = 1,
    Position = UDim2.new(1, -128, 0, 8),
    Size = UDim2.new(0, 80, 0, 30),
    Font = Enum.Font.Arcade,
    Text = "THEME",
    TextColor3 = current_theme.text,
    TextSize = 14,
    AutoButtonColor = false
})

local close_button = create_instance("TextButton", {
    Parent = top_bar,
    BackgroundColor3 = current_theme.bg,
    BorderColor3 = current_theme.border,
    BorderSizePixel = 1,
    Position = UDim2.new(1, -38, 0, 8),
    Size = UDim2.new(0, 30, 0, 30),
    Text = "",
    AutoButtonColor = false
})

local search_container = create_instance("Frame", {
    Parent = main_gui,
    BackgroundColor3 = current_theme.bg,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 10, 0, 56),
    Size = UDim2.new(1, -20, 0, 40),
    ClipsDescendants = true
})

local search_box = create_instance("TextBox", {
    Parent = search_container,
    BackgroundColor3 = current_theme.element_bg,
    BorderColor3 = current_theme.border,
    BorderSizePixel = 1,
    Size = UDim2.new(1, -50, 1, 0),
    Font = Enum.Font.Arcade,
    PlaceholderText = "SEARCH SCRIPT...",
    Text = "",
    TextColor3 = current_theme.text,
    PlaceholderColor3 = current_theme.border,
    TextSize = 16,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false
})

create_instance("UIPadding", {
    Parent = search_box,
    PaddingLeft = UDim.new(0, 10)
})

local search_button = create_instance("TextButton", {
    Parent = search_container,
    BackgroundColor3 = current_theme.accent,
    BorderSizePixel = 0,
    Position = UDim2.new(1, -40, 0, 0),
    Size = UDim2.new(0, 40, 1, 0),
    Text = "",
    AutoButtonColor = false
})

local function draw_pixel_icon(parent, map, color, p_size)
    local pixel_size = p_size or 2
    local width = #map[1] * pixel_size
    local height = #map * pixel_size
    
    local container = create_instance("Frame", {
        Parent = parent,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, width, 0, height),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5)
    })
    
    for y, row in ipairs(map) do
        local x = 1
        while x <= #row do
            if row:sub(x, x) == "1" then
                local start_x = x
                while x + 1 <= #row and row:sub(x + 1, x + 1) == "1" do
                    x = x + 1
                end
                local segment_width = (x - start_x + 1) * pixel_size
                create_instance("Frame", {
                    Parent = container,
                    BackgroundColor3 = color,
                    BorderSizePixel = 0,
                    Position = UDim2.new(0, (start_x - 1) * pixel_size, 0, (y - 1) * pixel_size),
                    Size = UDim2.new(0, segment_width, 0, pixel_size)
                })
            end
            x = x + 1
        end
    end
    return container
end

local icon_search = draw_pixel_icon(search_button, {
    "000011110000",
    "000100001000",
    "001000000100",
    "001000000100",
    "001000000100",
    "000100001000",
    "000011110000",
    "000000011000",
    "000000001100",
    "000000000110",
    "000000000011"
}, current_theme.text, 2)

local icon_loading = draw_pixel_icon(search_button, {
    "00111100",
    "01000010",
    "10000001",
    "10000000",
    "10000000",
    "10000001",
    "01000010",
    "00111100"
}, current_theme.text, 2)
icon_loading.Visible = false

draw_pixel_icon(close_button, {
    "10000001",
    "01000010",
    "00100100",
    "00011000",
    "00011000",
    "00100100",
    "01000010",
    "10000001"
}, Color3.fromRGB(220, 60, 60), 2)

local loading_conn

local function set_search_state(state)
    if state == "search" then
        if loading_conn then loading_conn:Disconnect() loading_conn = nil end
        icon_loading.Visible = false
        icon_search.Visible = true
        icon_loading.Rotation = 0
    elseif state == "loading" then
        icon_search.Visible = false
        icon_loading.Visible = true
        if not loading_conn then
            loading_conn = run_service.RenderStepped:Connect(function(dt)
                icon_loading.Rotation = icon_loading.Rotation + (dt * 360)
            end)
        end
    end
end

local content_area = create_instance("Frame", {
    Parent = main_gui,
    BackgroundColor3 = current_theme.bg,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 10, 0, 106),
    Size = UDim2.new(1, -20, 1, -116),
    ClipsDescendants = true
})

local results_scroll = create_instance("ScrollingFrame", {
    Parent = content_area,
    Active = true,
    BackgroundColor3 = current_theme.bg,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 1, 0),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ScrollBarThickness = 12,
    ScrollBarImageColor3 = current_theme.accent,
    BottomImage = flat_image,
    MidImage = flat_image,
    TopImage = flat_image,
    ClipsDescendants = true,
    ElasticBehavior = Enum.ElasticBehavior.Never
})

local results_layout = create_instance("UIListLayout", {
    Parent = results_scroll,
    SortOrder = Enum.SortOrder.LayoutOrder,
    Padding = UDim.new(0, 5)
})

results_layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    results_scroll.CanvasSize = UDim2.new(0, 0, 0, results_layout.AbsoluteContentSize.Y)
end)

local code_view_container = create_instance("Frame", {
    Parent = content_area,
    BackgroundColor3 = current_theme.element_bg,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 1, 0),
    Visible = false,
    ClipsDescendants = true
})

local code_top_bar = create_instance("Frame", {
    Parent = code_view_container,
    BackgroundColor3 = current_theme.bg,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 30),
    ClipsDescendants = true
})

local back_button = create_instance("TextButton", {
    Parent = code_top_bar,
    BackgroundColor3 = current_theme.border,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 5, 0, 5),
    Size = UDim2.new(0, 60, 0, 20),
    Font = Enum.Font.Arcade,
    Text = "BACK",
    TextColor3 = current_theme.text,
    TextSize = 14,
    AutoButtonColor = false
})

local copy_button = create_instance("TextButton", {
    Parent = code_top_bar,
    BackgroundColor3 = current_theme.accent,
    BorderSizePixel = 0,
    Position = UDim2.new(1, -65, 0, 5),
    Size = UDim2.new(0, 60, 0, 20),
    Text = "",
    AutoButtonColor = false
})

local icon_copy = draw_pixel_icon(copy_button, {
    "000111111100",
    "000100000100",
    "011111110100",
    "010000010100",
    "010000010100",
    "010000010100",
    "010000011100",
    "010000010000",
    "011111110000"
}, current_theme.text, 2)

local icon_success = draw_pixel_icon(copy_button, {
    "000000000011",
    "000000000110",
    "000000001100",
    "000000011000",
    "000000110000",
    "001101100000",
    "000111000000",
    "000010000000"
}, Color3.fromRGB(80, 220, 120), 2)
icon_success.Visible = false

local lines_info = create_instance("TextLabel", {
    Parent = code_top_bar,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 75, 0, 0),
    Size = UDim2.new(0, 150, 1, 0),
    Font = Enum.Font.Arcade,
    Text = "LINES: 0",
    TextColor3 = current_theme.text,
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left
})

local code_area = create_instance("Frame", {
    Parent = code_view_container,
    BackgroundColor3 = current_theme.bg,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 0, 0, 30),
    Size = UDim2.new(1, 0, 1, -30),
    ClipsDescendants = true
})

local line_numbers_scroll = create_instance("ScrollingFrame", {
    Parent = code_area,
    Active = false,
    BackgroundColor3 = current_theme.element_bg,
    BorderSizePixel = 0,
    Size = UDim2.new(0, 45, 1, 0),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ScrollBarThickness = 0,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    ElasticBehavior = Enum.ElasticBehavior.Never
})

local line_numbers_layout = create_instance("UIListLayout", {
    Parent = line_numbers_scroll,
    SortOrder = Enum.SortOrder.LayoutOrder
})

local code_scroll = create_instance("ScrollingFrame", {
    Parent = code_area,
    Active = true,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Position = UDim2.new(0, 50, 0, 0),
    Size = UDim2.new(1, -50, 1, 0),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ScrollBarThickness = 12,
    ScrollBarImageColor3 = current_theme.accent,
    BottomImage = flat_image,
    MidImage = flat_image,
    TopImage = flat_image,
    ScrollingDirection = Enum.ScrollingDirection.XY,
    ElasticBehavior = Enum.ElasticBehavior.Never
})

local code_layout = create_instance("UIListLayout", {
    Parent = code_scroll,
    SortOrder = Enum.SortOrder.LayoutOrder
})

code_layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    local max_width = 0
    for _, child in ipairs(code_scroll:GetChildren()) do
        if child:IsA("TextLabel") and child.AbsoluteSize.X > max_width then
            max_width = child.AbsoluteSize.X
        end
    end
    code_scroll.CanvasSize = UDim2.new(0, max_width, 0, code_layout.AbsoluteContentSize.Y)
    line_numbers_scroll.CanvasSize = UDim2.new(0, 0, 0, line_numbers_layout.AbsoluteContentSize.Y)
end)

code_scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
    line_numbers_scroll.CanvasPosition = Vector2.new(0, code_scroll.CanvasPosition.Y)
end)

local function make_scrollbar_interactive(scroll_frame)
    local is_dragging = false
    local drag_start_y = 0
    local start_canvas_pos = 0

    scroll_frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            local rect = scroll_frame.AbsolutePosition
            local size = scroll_frame.AbsoluteSize
            local thickness = scroll_frame.ScrollBarThickness
            
            if input.Position.X >= rect.X + size.X - thickness - 5 then
                is_dragging = true
                drag_start_y = input.Position.Y
                start_canvas_pos = scroll_frame.CanvasPosition.Y
                
                local h, s, v = current_theme.accent:ToHSV()
                tween_service:Create(scroll_frame, TweenInfo.new(0.15), {
                    ScrollBarImageColor3 = Color3.fromHSV(h, s * 0.5, math.min(1, v * 1.5))
                }):Play()
            end
        end
    end)
    
    user_input_service.InputChanged:Connect(function(input)
        if is_dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            local size = scroll_frame.AbsoluteSize
            local content_size = scroll_frame.CanvasSize.Y.Offset
            local max_scroll = math.max(0, content_size - size.Y)
            
            if max_scroll > 0 then
                local delta_y = input.Position.Y - drag_start_y
                local track_space = size.Y
                local scroll_ratio = max_scroll / track_space
                
                local new_pos = start_canvas_pos + (delta_y * scroll_ratio * 1.5)
                new_pos = math.clamp(new_pos, 0, max_scroll)
                
                scroll_frame.CanvasPosition = Vector2.new(scroll_frame.CanvasPosition.X, new_pos)
            end
        end
    end)
    
    user_input_service.InputEnded:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) and is_dragging then
            is_dragging = false
            tween_service:Create(scroll_frame, TweenInfo.new(0.2), {
                ScrollBarImageColor3 = current_theme.accent
            }):Play()
        end
    end)
end

make_scrollbar_interactive(results_scroll)
make_scrollbar_interactive(code_scroll)

local function animate_button(button)
    if button:GetAttribute("anim") then return end
    button:SetAttribute("anim", true)
    local orig = button.BackgroundColor3
    local tw1 = tween_service:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = current_theme.text})
    tw1:Play()
    task.delay(0.1, function()
        if button.Parent then
            local tw2 = tween_service:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = orig})
            tw2:Play()
            tw2.Completed:Connect(function()
                if button.Parent then
                    button:SetAttribute("anim", false)
                end
            end)
        end
    end)
end

local function bind_tap(button, callback)
    button.AutoButtonColor = false
    local start_pos = nil
    local is_valid = false
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            start_pos = input.Position
            is_valid = true
        end
    end)
    button.InputChanged:Connect(function(input)
        if start_pos and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
            if (input.Position - start_pos).Magnitude > 5 then
                is_valid = false
            end
        end
    end)
    button.InputEnded:Connect(function(input)
        if start_pos and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
            if is_valid and (input.Position - start_pos).Magnitude < 10 then
                animate_button(button)
                callback()
            end
            start_pos = nil
            is_valid = false
        end
    end)
end

local function apply_theme(theme_name)
    current_theme = themes[theme_name]
    main_gui.BackgroundColor3 = current_theme.bg
    main_gui.BorderColor3 = current_theme.border
    top_bar.BackgroundColor3 = current_theme.element_bg
    title_text.TextColor3 = current_theme.text
    theme_button.BackgroundColor3 = current_theme.bg
    theme_button.BorderColor3 = current_theme.border
    theme_button.TextColor3 = current_theme.text
    search_container.BackgroundColor3 = current_theme.bg
    search_box.BackgroundColor3 = current_theme.element_bg
    search_box.BorderColor3 = current_theme.border
    search_box.TextColor3 = current_theme.text
    search_box.PlaceholderColor3 = current_theme.border
    search_button.BackgroundColor3 = current_theme.accent
    content_area.BackgroundColor3 = current_theme.bg
    
    results_scroll.BackgroundColor3 = current_theme.bg
    results_scroll.ScrollBarImageColor3 = current_theme.accent
    
    code_view_container.BackgroundColor3 = current_theme.element_bg
    code_top_bar.BackgroundColor3 = current_theme.bg
    back_button.BackgroundColor3 = current_theme.border
    back_button.TextColor3 = current_theme.text
    copy_button.BackgroundColor3 = current_theme.accent
    lines_info.TextColor3 = current_theme.text
    code_area.BackgroundColor3 = current_theme.bg
    line_numbers_scroll.BackgroundColor3 = current_theme.element_bg
    code_scroll.ScrollBarImageColor3 = current_theme.accent
    handle_part_h.BackgroundColor3 = current_theme.accent
    handle_part_v.BackgroundColor3 = current_theme.accent
    
    for _, child in ipairs(results_scroll:GetChildren()) do
        if child:IsA("Frame") and child.Name == "Result" then
            child.BackgroundColor3 = current_theme.element_bg
            child.BorderColor3 = current_theme.border
        end
    end
    
    for _, child in ipairs(line_numbers_scroll:GetChildren()) do
        if child:IsA("TextLabel") then
            child.TextColor3 = Color3.fromRGB(150, 150, 150)
        end
    end
    
    for _, child in ipairs(code_scroll:GetChildren()) do
        if child:IsA("TextLabel") then
            child.TextColor3 = current_theme.text
        end
    end
    
    icon_search.BackgroundColor3 = current_theme.text
    for _, fr in ipairs(icon_search:GetChildren()) do fr.BackgroundColor3 = current_theme.text end
    icon_loading.BackgroundColor3 = current_theme.text
    for _, fr in ipairs(icon_loading:GetChildren()) do fr.BackgroundColor3 = current_theme.text end
    icon_copy.BackgroundColor3 = current_theme.text
    for _, fr in ipairs(icon_copy:GetChildren()) do fr.BackgroundColor3 = current_theme.text end
end

local theme_keys = {"vscode", "dark_blue", "dracula", "monokai"}
local theme_index = 1

bind_tap(theme_button, function()
    theme_index = theme_index + 1
    if theme_index > #theme_keys then theme_index = 1 end
    apply_theme(theme_keys[theme_index])
end)

local function escape_pattern(text)
    return text:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

local function syntax_highlight(text)
    local highlighted = text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
    local patterns = {
        {"(%b\"\")", "#ce9178"},
        {"(%b\'\')", "#ce9178"},
        {"(%-%-[^\n]*)", "#6a9955"}
    }
    for _, pattern_data in ipairs(patterns) do
        highlighted = highlighted:gsub(pattern_data[1], "<font color=\"" .. pattern_data[2] .. "\">%1</font>")
    end
    local keywords_blue = {"local", "function", "return", "end", "nil", "true", "false", "and", "or", "not"}
    for _, kw in ipairs(keywords_blue) do
        highlighted = highlighted:gsub("%f[%w]" .. kw .. "%f[%W]", "<font color=\"#569cd6\">" .. kw .. "</font>")
    end
    local keywords_purple = {"if", "then", "else", "elseif", "for", "while", "do", "in"}
    for _, kw in ipairs(keywords_purple) do
        highlighted = highlighted:gsub("%f[%w]" .. kw .. "%f[%W]", "<font color=\"#c586c0\">" .. kw .. "</font>")
    end
    highlighted = highlighted:gsub("%f[%w](%d+)%f[%W]", "<font color=\"#b5cea8\">%1</font>")
    return highlighted
end

local active_decompile_text = ""

local function view_code(script_instance)
    results_scroll.Visible = false
    code_view_container.Visible = true
    lines_info.Text = "DECOMPILING..."
    
    for _, child in ipairs(code_scroll:GetChildren()) do
        if child:IsA("TextLabel") then child:Destroy() end
    end
    for _, child in ipairs(line_numbers_scroll:GetChildren()) do
        if child:IsA("TextLabel") then child:Destroy() end
    end
    
    code_scroll.CanvasPosition = Vector2.new(0, 0)
    line_numbers_scroll.CanvasPosition = Vector2.new(0, 0)
    active_decompile_text = ""
    
    task.spawn(function()
        local code = decompile_cache[script_instance]
        if not code then
            local success, source = pcall(function()
                if decompile then return decompile(script_instance) else return "-- DECOMPILE NOT SUPPORTED" end
            end)
            if not success or type(source) ~= "string" or source == "" then
                source = "-- FAILED TO DECOMPILE OR EMPTY"
            end
            code = source
            if success then decompile_cache[script_instance] = code end
        end
        
        code = string.gsub(code, "\r", "")
        code = string.gsub(code, "\t", "    ")
        active_decompile_text = code
        
        local lines = string.split(code, "\n")
        local lines_count = #lines
        lines_info.Text = "LINES: " .. tostring(lines_count)
        
        local chunk_size = 50
        
        for i = 1, lines_count, chunk_size do
            local chunk_lines = {}
            local chunk_nums = {}
            
            for j = i, math.min(i + chunk_size - 1, lines_count) do
                table.insert(chunk_lines, lines[j])
                table.insert(chunk_nums, tostring(j))
            end
            
            local text_chunk = table.concat(chunk_lines, "\n")
            local nums_chunk = table.concat(chunk_nums, "\n")
            
            create_instance("TextLabel", {
                Parent = line_numbers_scroll,
                BackgroundTransparency = 1,
                AutomaticSize = Enum.AutomaticSize.Y,
                Size = UDim2.new(1, 0, 0, 0),
                Font = Enum.Font.Arcade,
                Text = nums_chunk,
                TextColor3 = Color3.fromRGB(150, 150, 150),
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Right,
                TextYAlignment = Enum.TextYAlignment.Top
            })
            
            create_instance("TextLabel", {
                Parent = code_scroll,
                BackgroundTransparency = 1,
                AutomaticSize = Enum.AutomaticSize.XY,
                Size = UDim2.new(0, 0, 0, 0),
                Font = Enum.Font.Arcade,
                Text = syntax_highlight(text_chunk),
                TextColor3 = current_theme.text,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextYAlignment = Enum.TextYAlignment.Top,
                RichText = true,
                TextWrapped = false
            })
        end
    end)
end

bind_tap(back_button, function()
    code_view_container.Visible = false
    results_scroll.Visible = true
end)

bind_tap(copy_button, function()
    if setclipboard then
        setclipboard(active_decompile_text)
        icon_copy.Visible = false
        icon_success.Visible = true
        task.delay(1.5, function()
            icon_copy.Visible = true
            icon_success.Visible = false
        end)
    end
end)

local search_thread

local function perform_search()
    if search_thread then
        task.cancel(search_thread)
    end
    for _, child in ipairs(results_scroll:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextButton") then
            child:Destroy()
        end
    end
    results_scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    local raw_query = search_box.Text
    local query = string.lower(raw_query)
    if query == "" then return end
    
    local safe_query = escape_pattern(query)
    set_search_state("loading")
    
    search_thread = task.spawn(function()
        local all_scripts_set = {}
        local all_scripts = {}
        
        local function add_script(scr)
            if typeof(scr) == "Instance" and (scr:IsA("LocalScript") or scr:IsA("ModuleScript") or scr:IsA("Script")) and not all_scripts_set[scr] then
                all_scripts_set[scr] = true
                table.insert(all_scripts, scr)
            end
        end
        
        local function get_priority(scr)
            local path = scr:GetFullName()
            if path:find("Players%.LocalPlayer") then return 1 end
            if path:find("ReplicatedStorage") then return 2 end
            if path:find("Workspace") then return 3 end
            if path:find("Starter") then return 4 end
            if path:find("CoreGui") then return 10 end
            return 5
        end
        
        local insts
        pcall(function() insts = getinstances() end)
        if not insts then insts = game:GetDescendants() end
        
        local y_counter = 0
        for i = 1, #insts do
            add_script(insts[i])
            y_counter = y_counter + 1
            if y_counter > 5000 then
                task.wait()
                y_counter = 0
            end
        end
        
        if getscripts then for _, scr in ipairs(getscripts()) do add_script(scr) end end
        if getnilinstances then for _, scr in ipairs(getnilinstances()) do add_script(scr) end end
        if getloadedmodules then for _, scr in ipairs(getloadedmodules()) do add_script(scr) end end
        if getrunningscripts then for _, scr in ipairs(getrunningscripts()) do add_script(scr) end end
        
        table.sort(all_scripts, function(a, b)
            return get_priority(a) < get_priority(b)
        end)
        
        local start_time = os.clock()
        
        for _, script_instance in ipairs(all_scripts) do
            if os.clock() - start_time > 0.01 then
                task.wait()
                start_time = os.clock()
            end
            
            local script_name = string.lower(script_instance.Name)
            local is_match = string.find(script_name, safe_query, 1, false)
            local match_count = 0
            
            local code = decompile_cache[script_instance]
            
            if not is_match and not code and #raw_query >= 2 then
                local s, res = pcall(decompile, script_instance)
                if s and type(res) == "string" then
                    code = res
                    decompile_cache[script_instance] = code
                end
                task.wait()
                start_time = os.clock()
            end
            
            if not is_match and code then
                local _, count = string.gsub(string.lower(code), safe_query, "")
                if count > 0 then
                    is_match = true
                    match_count = count
                end
            elseif is_match and code then
                local _, count = string.gsub(string.lower(code), safe_query, "")
                match_count = count
            end
            
            if is_match then
                local hash_text = "HASH: N/A"
                if getscripthash then
                    pcall(function()
                        local h = getscripthash(script_instance)
                        if h then hash_text = "HASH: " .. string.sub(h, 1, 12) .. "..." end
                    end)
                end
                
                local path_text = script_instance:GetFullName()
                
                local result_frame = create_instance("Frame", {
                    Name = "Result",
                    Parent = results_scroll,
                    BackgroundColor3 = current_theme.element_bg,
                    BorderColor3 = current_theme.border,
                    BorderSizePixel = 1,
                    Size = UDim2.new(1, -10, 0, 55)
                })
                
                local s_color = type_colors[script_instance.ClassName] or current_theme.text
                
                create_instance("TextLabel", {
                    Name = "NameLabel",
                    Parent = result_frame,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 10, 0, 5),
                    Size = UDim2.new(0.7, 0, 0, 14),
                    Font = Enum.Font.Arcade,
                    Text = script_instance.Name .. " (" .. script_instance.ClassName .. ")",
                    TextColor3 = s_color,
                    TextSize = 14,
                    TextXAlignment = Enum.TextXAlignment.Left
                })
                
                create_instance("TextLabel", {
                    Name = "HashLabel",
                    Parent = result_frame,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 10, 0, 20),
                    Size = UDim2.new(0.7, 0, 0, 14),
                    Font = Enum.Font.Arcade,
                    Text = hash_text,
                    TextColor3 = Color3.fromRGB(150, 150, 150),
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left
                })
                
                create_instance("TextLabel", {
                    Name = "PathLabel",
                    Parent = result_frame,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 10, 0, 35),
                    Size = UDim2.new(1, -60, 0, 14),
                    Font = Enum.Font.Arcade,
                    Text = "PATH: " .. path_text,
                    TextColor3 = Color3.fromRGB(100, 100, 100),
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd
                })
                
                if match_count > 0 then
                    create_instance("TextLabel", {
                        Parent = result_frame,
                        BackgroundTransparency = 1,
                        Position = UDim2.new(1, -110, 0, 0),
                        Size = UDim2.new(0, 100, 1, 0),
                        Font = Enum.Font.Arcade,
                        Text = tostring(match_count) .. " MATCH",
                        TextColor3 = current_theme.accent,
                        TextSize = 12,
                        TextXAlignment = Enum.TextXAlignment.Right
                    })
                end
                
                local click_btn = create_instance("TextButton", {
                    Parent = result_frame,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    Text = ""
                })
                
                bind_tap(click_btn, function()
                    view_code(script_instance)
                end)
            end
        end
        
        set_search_state("search")
    end)
end

bind_tap(search_button, function()
    perform_search()
end)

bind_tap(close_button, function()
    local children = main_gui:GetDescendants()
    for _, child in ipairs(children) do
        if child:IsA("GuiObject") then
            local props = {BackgroundTransparency = 1}
            if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
                props.TextTransparency = 1
                props.TextStrokeTransparency = 1
            end
            if child:IsA("ImageLabel") or child:IsA("ImageButton") then
                props.ImageTransparency = 1
            end
            tween_service:Create(child, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), props):Play()
        end
    end
    task.delay(0.3, function()
        tween_service:Create(main_gui, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, main_gui.AbsoluteSize.X, 0, 0),
            BackgroundTransparency = 1
        }):Play()
        task.delay(0.28, function()
            screen_gui:Destroy()
        end)
    end)
end)

local is_dragging_main = false
local main_drag_start_pos
local main_start_pos

top_bar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        is_dragging_main = true
        main_drag_start_pos = input.Position
        main_start_pos = main_gui.Position
    end
end)

user_input_service.InputChanged:Connect(function(input)
    if is_dragging_main and input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - main_drag_start_pos
        main_gui.Position = UDim2.new(
            main_start_pos.X.Scale,
            main_start_pos.X.Offset + delta.X,
            main_start_pos.Y.Scale,
            main_start_pos.Y.Offset + delta.Y
        )
    end
end)

user_input_service.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        is_dragging_main = false
    end
end)

local is_resizing = false
local resize_start_pos
local start_size

resize_handle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        is_resizing = true
        resize_start_pos = input.Position
        start_size = main_gui.Size
        tween_service:Create(handle_part_h, TweenInfo.new(0.2), {BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 0, 0, 6)}):Play()
        tween_service:Create(handle_part_v, TweenInfo.new(0.2), {BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(0, 6, 1, 0)}):Play()
        tween_service:Create(resize_handle, TweenInfo.new(0.2), {Size = UDim2.new(0, 30, 0, 30)}):Play()
    end
end)

user_input_service.InputChanged:Connect(function(input)
    if is_resizing and input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - resize_start_pos
        local new_x = math.max(300, start_size.X.Offset + delta.X)
        local new_y = math.max(200, start_size.Y.Offset + delta.Y)
        main_gui.Size = UDim2.new(0, new_x, 0, new_y)
    end
end)

user_input_service.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch then
        if is_resizing then
            is_resizing = false
            tween_service:Create(handle_part_h, TweenInfo.new(0.2), {BackgroundColor3 = current_theme.accent, Size = UDim2.new(1, 0, 0, 4)}):Play()
            tween_service:Create(handle_part_v, TweenInfo.new(0.2), {BackgroundColor3 = current_theme.accent, Size = UDim2.new(0, 4, 1, 0)}):Play()
            tween_service:Create(resize_handle, TweenInfo.new(0.2), {Size = UDim2.new(0, 20, 0, 20)}):Play()
        end
    end
end)