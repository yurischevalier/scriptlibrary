local FuncsV3 = {}
local SaveConfig = {} -- FIX: was nil, which made Dropdown / "Save" defaults error when SetTable() wasn't called

local function Checker(Val, Val1, Val2)
  return typeof(Val) == Val1 and Val or Val2
end

function FuncsV3:SetTable(path)
  SaveConfig = Checker(path, "table", {})
end

function FuncsV3:Toggle(Tab, Name, Content, Default, Callback)
  Name = Checker(Name, "string", tostring(Name))
  Content = Checker(Content, "string", tostring(Content))
  Callback = Checker(Callback, "function", function() end)

  local _default = Default == "Save" 
  and Checker(SaveConfig[Name], "boolean", false)
  or Checker(Default, "boolean", false)

  return Tab:AddToggle({
    Title = Name,
    Content = Content,
    Default = _default,
    Callback = Callback
  })
end

function FuncsV3:Button(Tab, Name, Content, Callback)
  Name = Checker(Name, "string", tostring(Name))
  Content = Checker(Content, "string", tostring(Content))
  Callback = Checker(Callback, "function", function() end)

  return Tab:AddButton({
    Title = Name,
    Content = Content,
    Icon = "rbxassetid://16932740082",
    Callback = Callback
  })
end

function FuncsV3:Dropdown(Tab, Name, Content, multi, options, Default, Callback)
  Name = Checker(Name, "string", tostring(Name))
  Content = Checker(Content, "string", tostring(Content))
  multi = Checker(multi, "boolean", false)
  options = Checker(options, "table", { "" })
  Callback = Checker(Callback, "function", function() end)

  local _default

  if Default == "Save" then
    if type(SaveConfig[Name]) == "table" then
      _default = SaveConfig[Name] or {""}
    else
      _default = {SaveConfig[Name] or ""}
    end
  else
    if type(SaveConfig[Name] or Default) == "table" then
      _default = SaveConfig[Name] or Default
    else
      _default = {SaveConfig[Name] or Default}
    end
  end

  return Tab:AddDropdown({
    Title = Name,
    Content = Content,
    Multi = multi,
    Options = options,
    Default = _default,
    Callback = Callback
  })
end

function FuncsV3:Textbox(Tab, Name, Content, Default, Callback)
  Name = Checker(Name, "string", tostring(Name))
  Content = Checker(Content, "string", tostring(Content))
  Callback = Checker(Callback, "function", function() end)

  local _default = Default == "Save" 
  and Checker(SaveConfig[Name], "string", "")
  or Checker(Default, "string", "")

  return Tab:AddInput({
    Title = Name,
    Content = Content,
    Default = _default,
    Callback = Callback
  })
end

-- ///////////////////////////////////////////////////////////////
-- NEW helpers (additive - nothing above was changed)
-- ///////////////////////////////////////////////////////////////

-- FuncsV3:Slider(Section, "Walk Speed", "Set your speed", 1, 16, 200, 16, function(value) end)
-- Default can also be "Save" to restore the value from the table given to SetTable()
function FuncsV3:Slider(Tab, Name, Content, Increment, Min, Max, Default, Callback)
  Name = Checker(Name, "string", tostring(Name))
  Content = Checker(Content, "string", tostring(Content))
  Increment = Checker(Increment, "number", 1)
  Min = Checker(Min, "number", 0)
  Max = Checker(Max, "number", 100)
  Callback = Checker(Callback, "function", function() end)

  local _default = Default == "Save"
  and Checker(SaveConfig[Name], "number", Min)
  or Checker(Default, "number", Min)

  return Tab:AddSlider({
    Title = Name,
    Content = Content,
    Increment = Increment,
    Min = Min,
    Max = Max,
    Default = _default,
    Callback = Callback
  })
end

-- FuncsV3:Paragraph(Section, "Info", "Some longer text that wraps onto several lines")
function FuncsV3:Paragraph(Tab, Name, Content)
  Name = Checker(Name, "string", tostring(Name))
  Content = Checker(Content, "string", tostring(Content))

  return Tab:AddParagraph({
    Title = Name,
    Content = Content
  })
end

-- FuncsV3:Separator(Section, "Misc")
function FuncsV3:Separator(Tab, Name)
  Name = Checker(Name, "string", tostring(Name))

  return Tab:AddSeperator({
    Title = Name
  })
end

-- FuncsV3:Line(Section)
function FuncsV3:Line(Tab)
  return Tab:AddLine()
end

return FuncsV3
