return function()
  local BRAND = "MAFORGE"
  local TAGLINE = "Forged MAtricks • MA Macro Foundry"

  local function box(title, text)
    MessageBox({
      title = title,
      message = text,
      commands = { { value = 1, name = "OK" } }
    })
  end

  local function err(text)
    box(BRAND, text .. "\n\n" .. TAGLINE)
  end

  local function done(lines, recalledSlot)
    local footer = "\n\n" .. BRAND .. " — " .. TAGLINE
    if recalledSlot then
      footer = footer .. string.format("\nRecalled: MAtricks %d", recalledSlot)
    end
    box(BRAND, table.concat(lines, "\n") .. footer)
  end

  if not SelectionCount then
    return err("SelectionCount() not available in this environment.")
  end

  local n = SelectionCount()
  if not n or n < 1 then
    return err("Nothing selected. Select fixtures (or a group), then run again.")
  end

  local isOdd = (n % 2 == 1)

  if isOdd then
    box(
      BRAND,
      string.format(
        "Heads up:\nYour selection count is ODD (%d).\n\n" ..
        "For Better Results Create A New Group with the Center Fixture Removed.\n" ..
        "This is expected in the Fast Ship version.\n" ..
        "A Foundry edition will refine odd-count handling.\n\n%s",
        n,
        TAGLINE
      )
    )
  end

  local function toint(v)
    v = tonumber(v)
    if not v then return nil end
    return math.floor(v + 0.0)
  end

  local recipes = {
    {
      key = "LR",
      label = "LR Split (Blocks from count)",
      make = function(cnt)
        local blocks = math.max(1, math.floor(cnt / 2))
        return {
          { prop = "XBlock", val = blocks },
        }
      end
    },
    {
      key = "C/O",
      label = "Center-Out",
      make = function(_cnt)
        return {
          { prop = "XWings",     val = 2 },
          { prop = "PhaseFromX", val = 0 },
          { prop = "PhaseToX",   val = 360 },
        }
      end
    },
    {
      key = "QTR",
      label = "Quarter Splits (XBlock=4)",
      make = function(cnt)
        return {
          { prop = "XBlock", val = math.max(1, math.min(4, cnt)) },
        }
      end
    },
    {
      key = "O/E",
      label = "Odd/Even (XGroup=2)",
      make = function(_cnt)
        return {
          { prop = "XGroup", val = 2 },
        }
      end
    },
    {
      key = "1:1",
      label = "One-to-One (XBlock=Count)",
      make = function(cnt)
        return {
          { prop = "XBlock", val = math.max(1, cnt) },
        }
      end
    },
  }


  local states = {
    { name = "Forge ALL", state = true },
    { name = "Overwrite Slot", state = true },
    { name = "Recall First Forged", state = true },
  }

  for _, r in ipairs(recipes) do
    states[#states + 1] = { name = "Forge: " .. r.label, state = (r.key == "LR") }
  end

  local ui = MessageBox({
    title = "MAtricks Foundry — Batch Forge",
    message = string.format(
      "Selection count: %d\nChoose which MAtricks to forge into consecutive slots.",
      n
    ),
    inputs = {
      { name = "Base Name", value = "FOUNDRY" },
      { name = "Start Slot", value = "101" },
    },
    states = states,
    commands = {
      { name = "Forge", value = 1 },
      { name = "Cancel", value = 0 },
    }
  })

  if not ui or ui.success ~= true or ui.result ~= 1 then return end

  local baseName  = tostring(ui.inputs["Base Name"] or "FOUNDRY")
  local startSlot = toint(ui.inputs["Start Slot"])
  if not startSlot or startSlot < 1 then
    return err("Start Slot must be a positive number.")
  end

  local forgeAll    = (ui.states and ui.states["Forge ALL"] == true)
  local overwrite   = (ui.states and ui.states["Overwrite Slot"] == true)
  local recallFirst = (ui.states and ui.states["Recall First Forged"] == true)

  local storeFlag = overwrite and "/Overwrite" or "/Merge"

  local selected = {}
  if forgeAll then
    for _, r in ipairs(recipes) do
      selected[#selected + 1] = r
    end
  else
    for _, r in ipairs(recipes) do
      local k = "Forge: " .. r.label
      if ui.states and ui.states[k] == true then
        selected[#selected + 1] = r
      end
    end
  end

  if #selected == 0 then
    return err("No recipes selected.")
  end

  local out = {}
  local firstStoredSlot = nil

  for i, r in ipairs(selected) do
    local slot = startSlot + (i - 1)
    if not firstStoredSlot then firstStoredSlot = slot end

    local name = string.format('%s %s (%d)', baseName, r.key, n)

    Cmd(string.format('Store MAtricks %d "%s" %s /NoConfirmation', slot, name, storeFlag))

    local sets = r.make(n)
    for _, s in ipairs(sets) do
      Cmd(string.format('Set MAtricks %d "%s" %s', slot, s.prop, tostring(s.val)))
    end

    out[#out + 1] = string.format("• %d  %s", slot, name)
  end

  if recallFirst and firstStoredSlot then
    Cmd(string.format("MAtricks %d", firstStoredSlot))
  end

  done(out, (recallFirst and firstStoredSlot or nil))
end
