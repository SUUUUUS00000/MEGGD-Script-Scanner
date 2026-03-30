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
local button_colors = {}

local function create_instance(class_name, properties)
    local instance = Instance.new(class_name)
    for property, value in pairs(properties) do
        instance[property] = value
    end
    return instance
end

local function clamp_pos(x, y, width, height)
    local vp = workspace.CurrentCamera.ViewportSize
    local max_x = math.max(0, vp.X - width)
    local max_y = math.max(0, vp.Y - height)
    return math.clamp(x, 0, max_x), math.clamp(y, 0, max_y)
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
    ClipsDescendants = true,
    ZIndex = 10
})

local warning_container = create_instance("Frame", {
    Name = "warning_container",
    Parent = screen_gui,
    BackgroundTransparency = 1,
    Size = UDim2.new(0, 260, 1, 0),
    Position = UDim2.new(0, 0, 0, 0),
    ZIndex = 1,
    ClipsDescendants = true
})

local resize_handle = create_instance("Frame", {
    Name = "resize_handle",
    Parent = screen_gui,
    BackgroundTransparency = 1,
    Size = UDim2.new(0, 20, 0, 20),
    Active = true,
    ZIndex = 11,
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

local function update_positions()
    resize_handle.Position = UDim2.new(
        0, main_gui.AbsolutePosition.X + main_gui.AbsoluteSize.X - 2,
        0, main_gui.AbsolutePosition.Y + main_gui.AbsoluteSize.Y - 2
    )
    warning_container.Position = UDim2.new(
        0, main_gui.AbsolutePosition.X + main_gui.AbsoluteSize.X + 8,
        0, main_gui.AbsolutePosition.Y
    )
end

main_gui:GetPropertyChangedSignal("AbsolutePosition"):Connect(update_positions)
main_gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(update_positions)
task.spawn(function()
    task.wait()
    update_positions()
    local ix, iy = clamp_pos(main_gui.AbsolutePosition.X, main_gui.AbsolutePosition.Y, main_gui.AbsoluteSize.X, main_gui.AbsoluteSize.Y)
    main_gui.Position = UDim2.new(0, ix, 0, iy)
end)

local missing_funcs = {}
if not decompile then table.insert(missing_funcs, "decompile") end
if not getscripthash then table.insert(missing_funcs, "getscripthash") end
if not getscripts then table.insert(missing_funcs, "getscripts") end
if not getnilinstances then table.insert(missing_funcs, "getnilinstances") end
if not getloadedmodules then table.insert(missing_funcs, "getloadedmodules") end
if not getrunningscripts then table.insert(missing_funcs, "getrunningscripts") end

if #missing_funcs > 0 then
    local snd = Instance.new("Sound")
    snd.SoundId = "rbxassetid://124177041037614"
    snd.Volume = 2
    snd.Parent = core_gui
    snd:Play()
    game.Debris:AddItem(snd, 3)

    local y_off = 10
    for i, func_name in ipairs(missing_funcs) do
        local w_frame = create_instance("Frame", {
            Parent = warning_container,
            BackgroundColor3 = current_theme.element_bg,
            BorderColor3 = Color3.fromRGB(255, 255, 255),
            BorderSizePixel = 2,
            Size = UDim2.new(0, 240, 0, 60),
            Position = UDim2.new(0, -260, 0, y_off),
            ZIndex = 1
        })

        local ic = create_instance("Frame", {
            Parent = w_frame,
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 24, 0, 16),
            Position = UDim2.new(0, 8, 0.5, -8),
            ZIndex = 2
        })

        local map = {
            "000002200000",
            "000022220000",
            "000221122000",
            "002221122200",
            "022221122220",
            "222220022222",
            "222221122222",
            "222222222222"
        }

        for my, row in ipairs(map) do
            for mx = 1, #row do
                local char = row:sub(mx, mx)
                if char ~= "0" then
                    local col = char == "2" and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(255, 255, 255)
                    create_instance("Frame", {
                        Parent = ic,
                        BorderSizePixel = 0,
                        Position = UDim2.new(0, (mx - 1) * 2, 0, (my - 1) * 2),
                        Size = UDim2.new(0, 2, 0, 2),
                        BackgroundColor3 = col,
                        ZIndex = 2
                    })
                end
            end
        end

        create_instance("TextLabel", {
            Parent = w_frame,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 40, 0, 0),
            Size = UDim2.new(1, -48, 1, 0),
            Font = Enum.Font.Arcade,
            TextSize = 14,
            RichText = true,
            TextWrapped = true,
            Text = '<font color="rgb(255,0,0)">Your executor does not\nsupport the </font><font color="rgb(255,255,0)">' .. func_name .. '</font><font color="rgb(255,0,0)"> feature.</font>',
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 2
        })

        tween_service:Create(w_frame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, 0, 0, y_off)
        }):Play()

        y_off = y_off + 70

        task.delay(2.5 + (i * 0.2), function()
            if w_frame and w_frame.Parent then
                local tw_out = tween_service:Create(w_frame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                    Position = UDim2.new(0, -260, 0, w_frame.Position.Y.Offset)
                })
                tw_out:Play()
                tw_out.Completed:Connect(function()
                    if w_frame and w_frame.Parent then
                        w_frame:Destroy()
                    end
                end)
            end
        end)
    end
end

local top_bar = create_instance("Frame", {
    Parent = main_gui,
    BackgroundColor3 = current_theme.element_bg,
    BorderSizePixel = 0,
    Size = UDim2.new(1, 0, 0, 46),
    ClipsDescendants = true
})

local meggd_badge = create_instance("Frame", {
    Parent = top_bar,
    BackgroundColor3 = Color3.fromRGB(0, 150, 255),
    BorderSizePixel = 0,
    Position = UDim2.new(0, 10, 0, 7),
    Size = UDim2.new(0, 50, 0, 14)
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

local version_text = create_instance("TextLabel", {
    Parent = top_bar,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 64, 0, 7),
    Size = UDim2.new(0, 52, 0, 14),
    Font = Enum.Font.Arcade,
    Text = "V1.1.0",
    TextColor3 = Color3.fromRGB(160, 205, 230),
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left,
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
    Position = UDim2.new(1, -156, 0, 8),
    Size = UDim2.new(0, 80, 0, 30),
    Font = Enum.Font.Arcade,
    Text = "THEME",
    TextColor3 = current_theme.text,
    TextSize = 14,
    AutoButtonColor = false
})
button_colors[theme_button] = current_theme.bg

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
button_colors[close_button] = current_theme.bg

local hide_button = create_instance("TextButton", {
    Parent = top_bar,
    BackgroundColor3 = current_theme.bg,
    BorderColor3 = current_theme.border,
    BorderSizePixel = 1,
    Position = UDim2.new(1, -72, 0, 8),
    Size = UDim2.new(0, 30, 0, 30),
    Text = "",
    AutoButtonColor = false
})
button_colors[hide_button] = current_theme.bg

local floating_hide = create_instance("TextButton", {
    Parent = screen_gui,
    BackgroundColor3 = current_theme.bg,
    BorderColor3 = current_theme.border,
    BorderSizePixel = 2,
    Size = UDim2.new(0, 0, 0, 0),
    Position = UDim2.new(0, 0, 0, 0),
    Text = "",
    AutoButtonColor = false,
    Visible = false,
    ZIndex = 50
})
button_colors[floating_hide] = current_theme.bg

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
button_colors[search_button] = current_theme.accent

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

local icon_eye_slash = draw_pixel_icon(hide_button, {
    "000011110001",
    "001100001110",
    "010011110110",
    "100110011001",
    "100100011001",
    "100110111001",
    "010011110010",
    "001110001100",
    "100011110000"
}, current_theme.text, 2)

local icon_eye_open = draw_pixel_icon(floating_hide, {
    "000011110000",
    "001100001100",
    "010011110010",
    "100110011001",
    "100100001001",
    "100110011001",
    "010011110010",
    "001100001100",
    "000011110000"
}, current_theme.text, 2)

local is_collapsed = false
local original_main_size = UDim2.new(0, 420, 0, 360)
local original_main_pos = UDim2.new(0.5, -200, 0.5, -150)

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
button_colors[back_button] = current_theme.border

local copy_button = create_instance("TextButton", {
    Parent = code_top_bar,
    BackgroundColor3 = current_theme.accent,
    BorderSizePixel = 0,
    Position = UDim2.new(1, -65, 0, 5),
    Size = UDim2.new(0, 60, 0, 20),
    Text = "",
    AutoButtonColor = false
})
button_colors[copy_button] = current_theme.accent

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
    local orig = button_colors[button] or button.BackgroundColor3
    tween_service:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = current_theme.text}):Play()
    task.delay(0.1, function()
        if button.Parent then
            tween_service:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = orig}):Play()
        end
    end)
end

local function bind_tap(button, callback)
    button.AutoButtonColor = false
    local start_pos = nil
    local start_time = 0
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            start_pos = input.Position
            start_time = os.clock()
        end
    end)
    button.InputEnded:Connect(function(input)
        if start_pos and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
            local delta = (input.Position - start_pos).Magnitude
            if delta < 5 and (os.clock() - start_time) < 0.5 then
                animate_button(button)
                callback()
            end
            start_pos = nil
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
    button_colors[theme_button] = current_theme.bg
    
    search_container.BackgroundColor3 = current_theme.bg
    search_box.BackgroundColor3 = current_theme.element_bg
    search_box.BorderColor3 = current_theme.border
    search_box.TextColor3 = current_theme.text
    search_box.PlaceholderColor3 = current_theme.border
    
    search_button.BackgroundColor3 = current_theme.accent
    button_colors[search_button] = current_theme.accent
    
    content_area.BackgroundColor3 = current_theme.bg
    results_scroll.BackgroundColor3 = current_theme.bg
    results_scroll.ScrollBarImageColor3 = current_theme.accent
    code_view_container.BackgroundColor3 = current_theme.element_bg
    code_top_bar.BackgroundColor3 = current_theme.bg
    
    back_button.BackgroundColor3 = current_theme.border
    back_button.TextColor3 = current_theme.text
    button_colors[back_button] = current_theme.border
    
    copy_button.BackgroundColor3 = current_theme.accent
    button_colors[copy_button] = current_theme.accent
    
    lines_info.TextColor3 = current_theme.text
    code_area.BackgroundColor3 = current_theme.bg
    line_numbers_scroll.BackgroundColor3 = current_theme.element_bg
    code_scroll.ScrollBarImageColor3 = current_theme.accent
    handle_part_h.BackgroundColor3 = current_theme.accent
    handle_part_v.BackgroundColor3 = current_theme.accent
    
    close_button.BackgroundColor3 = current_theme.bg
    close_button.BorderColor3 = current_theme.border
    button_colors[close_button] = current_theme.bg
    
    hide_button.BackgroundColor3 = current_theme.bg
    hide_button.BorderColor3 = current_theme.border
    button_colors[hide_button] = current_theme.bg
    
    floating_hide.BackgroundColor3 = current_theme.bg
    floating_hide.BorderColor3 = current_theme.border
    button_colors[floating_hide] = current_theme.bg
    
    for _, child in ipairs(results_scroll:GetChildren()) do
        if child:IsA("Frame") and child.Name == "Result" then
            child.BackgroundColor3 = current_theme.element_bg
            child.BorderColor3 = current_theme.border
            local click_btn = child:FindFirstChildOfClass("TextButton")
            if click_btn then button_colors[click_btn] = current_theme.element_bg end
        end
    end
    for _, child in ipairs(line_numbers_scroll:GetChildren()) do
        if child:IsA("TextLabel") then child.TextColor3 = Color3.fromRGB(150, 150, 150) end
    end
    for _, child in ipairs(code_scroll:GetChildren()) do
        if child:IsA("TextLabel") then child.TextColor3 = current_theme.text end
    end
    
    for _, fr in ipairs(icon_search:GetChildren()) do fr.BackgroundColor3 = current_theme.text end
    for _, fr in ipairs(icon_loading:GetChildren()) do fr.BackgroundColor3 = current_theme.text end
    for _, fr in ipairs(icon_copy:GetChildren()) do fr.BackgroundColor3 = current_theme.text end
    for _, fr in ipairs(icon_eye_slash:GetChildren()) do fr.BackgroundColor3 = current_theme.text end
    for _, fr in ipairs(icon_eye_open:GetChildren()) do fr.BackgroundColor3 = current_theme.text end
end

local theme_keys = {"vscode", "dark_blue", "dracula", "monokai"}
local theme_index = 1

bind_tap(theme_button, function()
    theme_index = theme_index + 1
    if theme_index > #theme_keys then theme_index = 1 end
    apply_theme(theme_keys[theme_index])
end)

bind_tap(hide_button, function()
    if not is_collapsed then
        is_collapsed = true
        original_main_size = main_gui.Size
        original_main_pos = main_gui.Position
        
        for _, w in ipairs(warning_container:GetChildren()) do
            if w:IsA("Frame") then
                tween_service:Create(w, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                    Position = UDim2.new(0, -260, 0, w.Position.Y.Offset)
                }):Play()
                task.delay(0.2, function() w:Destroy() end)
            end
        end

        local h_pos = hide_button.AbsolutePosition
        local h_size = hide_button.AbsoluteSize
        local center_pos = UDim2.new(0, h_pos.X + h_size.X / 2, 0, h_pos.Y + h_size.Y / 2)
        
        local fx, fy = clamp_pos(center_pos.X.Offset - 20, center_pos.Y.Offset - 20, 40, 40)
        floating_hide.Position = UDim2.new(0, fx, 0, fy)
        
        tween_service:Create(resize_handle, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 0, 0, 0)
        }):Play()

        local tw = tween_service:Create(main_gui, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 0, 0, 0),
            Position = center_pos
        })
        tw:Play()
        tw.Completed:Connect(function()
            main_gui.Visible = false
            floating_hide.Visible = true
            tween_service:Create(floating_hide, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, 40, 0, 40),
                Position = UDim2.new(0, fx, 0, fy)
            }):Play()
        end)
    end
end)

local is_dragging_floating = false
local floating_drag_start_pos
local floating_start_pos
local floating_click_start

floating_hide.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        is_dragging_floating = true
        floating_drag_start_pos = input.Position
        floating_start_pos = UDim2.new(0, floating_hide.AbsolutePosition.X, 0, floating_hide.AbsolutePosition.Y)
        floating_click_start = input.Position
    end
end)

user_input_service.InputChanged:Connect(function(input)
    if is_dragging_floating and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
        local delta = input.Position - floating_drag_start_pos
        local nx, ny = clamp_pos(floating_start_pos.X.Offset + delta.X, floating_start_pos.Y.Offset + delta.Y, floating_hide.AbsoluteSize.X, floating_hide.AbsoluteSize.Y)
        floating_hide.Position = UDim2.new(0, nx, 0, ny)
    end
end)

user_input_service.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        if is_dragging_floating then
            is_dragging_floating = false
            if floating_click_start and (input.Position - floating_click_start).Magnitude < 10 then
                if is_collapsed then
                    is_collapsed = false
                    
                    local f_pos = floating_hide.AbsolutePosition
                    local f_size = floating_hide.AbsoluteSize
                    local center_x = f_pos.X + (f_size.X / 2)
                    local center_y = f_pos.Y + (f_size.Y / 2)
                    local center_pos = UDim2.new(0, center_x, 0, center_y)
                    
                    local target_x, target_y = clamp_pos(center_x - (original_main_size.X.Offset / 2), center_y - (original_main_size.Y.Offset / 2), original_main_size.X.Offset, original_main_size.Y.Offset)
                    original_main_pos = UDim2.new(0, target_x, 0, target_y)
                    
                    local tw = tween_service:Create(floating_hide, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                        Size = UDim2.new(0, 0, 0, 0),
                        Position = center_pos
                    })
                    tw:Play()
                    tw.Completed:Connect(function()
                        floating_hide.Visible = false
                        main_gui.Position = center_pos
                        main_gui.Visible = true
                        
                        tween_service:Create(resize_handle, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                            Size = UDim2.new(0, 20, 0, 20)
                        }):Play()

                        tween_service:Create(main_gui, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                            Size = original_main_size,
                            Position = original_main_pos
                        }):Play()
                    end)
                end
            end
        end
    end
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
    if raw_query == "" then return end

    local terms = {}
    for term in raw_query:gmatch("[^,]+") do
        local t = term:match("^%s*(.-)%s*$")
        if #t > 0 then
            table.insert(terms, string.lower(t))
            if #terms >= 25 then break end
        end
    end
    if #terms == 0 then return end

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

        local matched_results = {}
        local start_time = os.clock()

        for _, script_instance in ipairs(all_scripts) do
            if os.clock() - start_time > 0.01 then
                task.wait()
                start_time = os.clock()
            end

            local code = decompile_cache[script_instance]
            if not code then
                local s, res = pcall(decompile, script_instance)
                if s and type(res) == "string" and #res > 0 then
                    code = res
                    decompile_cache[script_instance] = code
                end
                task.wait()
                start_time = os.clock()
            end

            local all_match = true
            local total_count = 0
            local script_name_lower = string.lower(script_instance.Name)
            local code_lower = code and string.lower(code) or ""

            for _, term in ipairs(terms) do
                local safe_term = escape_pattern(term)
                local name_hit = string.find(script_name_lower, safe_term, 1, false)
                local code_count = 0
                if #code_lower > 0 then
                    local _, cnt = string.gsub(code_lower, safe_term, "")
                    code_count = cnt
                end
                if not name_hit and code_count == 0 then
                    all_match = false
                    break
                end
                if name_hit then total_count = total_count + 1 end
                total_count = total_count + code_count
            end

            if all_match then
                table.insert(matched_results, {script = script_instance, count = total_count})
            end
        end

        table.sort(matched_results, function(a, b) return a.count > b.count end)

        for order, entry in ipairs(matched_results) do
            local script_instance = entry.script
            local match_count = entry.count

            local hash_text = "HASH: N/A"
            if getscripthash then
                pcall(function()
                    local h = getscripthash(script_instance)
                    if h then hash_text = "HASH: " .. string.sub(h, 1, 12) .. "..." end
                end)
            end

            local path_text = script_instance:GetFullName()
            local s_color = type_colors[script_instance.ClassName] or current_theme.text

            local result_frame = create_instance("Frame", {
                Name = "Result",
                Parent = results_scroll,
                BackgroundColor3 = current_theme.element_bg,
                BorderColor3 = current_theme.border,
                BorderSizePixel = 1,
                Size = UDim2.new(1, -10, 0, 55),
                LayoutOrder = order
            })
            button_colors[result_frame] = current_theme.element_bg

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
        main_start_pos = UDim2.new(0, main_gui.AbsolutePosition.X, 0, main_gui.AbsolutePosition.Y)
    end
end)

user_input_service.InputChanged:Connect(function(input)
    if is_dragging_main and input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - main_drag_start_pos
        local nx, ny = clamp_pos(main_start_pos.X.Offset + delta.X, main_start_pos.Y.Offset + delta.Y, main_gui.AbsoluteSize.X, main_gui.AbsoluteSize.Y)
        main_gui.Position = UDim2.new(0, nx, 0, ny)
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
        local vp = workspace.CurrentCamera.ViewportSize
        local max_w = vp.X - main_gui.AbsolutePosition.X
        local max_h = vp.Y - main_gui.AbsolutePosition.Y
        local new_x = math.clamp(start_size.X.Offset + delta.X, 300, max_w)
        local new_y = math.clamp(start_size.Y.Offset + delta.Y, 200, max_h)
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
print("MEGGD Script Scanner - Loaded")
