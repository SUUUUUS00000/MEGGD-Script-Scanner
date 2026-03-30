local uis = game:GetService("UserInputService")

local is_mobile = uis.TouchEnabled and not uis.KeyboardEnabled

if is_mobile then
    loadstring(game:HttpGet("https://raw.githubusercontent.com/AMOGUS392/MEGGD-Script-Scanner-Beta-Test-1.1.0/refs/heads/main/Device/MEGGD%20Script%20Scanner(Mobile).lua", true))()
else
    loadstring(game:HttpGet("https://raw.githubusercontent.com/AMOGUS392/MEGGD-Script-Scanner-Beta-Test-1.1.0/refs/heads/main/Device/MEGGD%20Script%20Scanner(PC).lua", true))()
end
