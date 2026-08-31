-- ------------------------------------------------------------
-- show/hide-all button
-- ------------------------------------------------------------

function build_visibility_button(player)
  if player.gui.screen.region_visibility_button then return end

  local button = player.gui.screen.add{
    type = "button",
    name = "region_visibility_button",
    caption = storage.regions_visible and "Hide Regions" or "Show Regions",
  }
  button.location = {x = 10, y = 10}
  button.visible = false  -- the on_nth_tick poller in control.lua turns this on/off
end

function set_all_regions_visible(visible)
  storage.regions_visible = visible

  for _, region in pairs(storage.regions) do
    local rect_filled = rendering.get_object_by_id(region.filled_render_id)
    if rect_filled and rect_filled.valid then rect_filled.visible = visible end

	local rect_outline = rendering.get_object_by_id(region.outline_render_id)
    if rect_outline and rect_outline.valid then rect_outline.visible = visible end

    local text = rendering.get_object_by_id(region.text_render_id)
    if text and text.valid then text.visible = visible end
  end

  for _, player in pairs(game.connected_players) do
    local button = player.gui.screen.region_visibility_button
    if button then
      button.caption = visible and "Hide Regions" or "Show Regions"
    end
  end
end

-- ------------------------------------------------------------
-- color application + preview
-- ------------------------------------------------------------
function construct_region_color(color_rect)
  alpha = color_rect.a / 255
  game.print(string.format("a=%.2f", alpha))
  return {r = math.floor(color_rect.r * alpha), g = math.floor(color_rect.g * alpha), b = math.floor(color_rect.b * alpha), a = color_rect.a}
end

local function apply_region_color(region)
  local rect_filled = rendering.get_object_by_id(region.filled_render_id)
  if rect_filled and rect_filled.valid then
	  rect_filled.color = construct_region_color(region.color)
  end
  local rect_outline = rendering.get_object_by_id(region.outline_render_id)
  if rect_outline and rect_outline.valid then
	  rect_outline.color = {r = region.color.r, g = region.color.g, b = region.color.b, 255}
  end
end

local function refresh_color_preview(player, region)
  local dialog = player.gui.screen.region_edit_dialog
  if dialog and dialog.color_preview then
    dialog.color_preview.style.font_color = region.color
  end
end

-- ------------------------------------------------------------
-- create/edit dialog - RGBA sliders, like the vanilla mod-settings
-- color picker
-- ------------------------------------------------------------

local function add_channel_row(parent, region_id, channel, initial_value)
  local row = parent.add{type = "flow", direction = "horizontal"}
  row.style.vertical_align = "center"

  local label = row.add{type = "label", caption = channel:upper()}
  label.style.width = 12

  local slider = row.add{
    type = "slider",
    name = "slider",
    tags = {action = "set_color_channel", region_id = region_id, channel = channel},
  }
  slider.style.width = 140
  slider.set_slider_minimum_maximum(0, 255)
  slider.set_slider_value_step(1)
  slider.set_slider_discrete_values(true)
  slider.slider_value = initial_value

  local field = row.add{
    type = "textfield",
    name = "field",
    numeric = true,
    allow_decimal = false,
    allow_negative = false,
    text = tostring(math.floor(initial_value)),
    tags = {action = "set_color_channel", region_id = region_id, channel = channel},
  }
  field.style.width = 40
end

function open_region_dialog(player, region_id)
  local region = storage.regions[region_id]
  if not region then return end

  local existing = player.gui.screen.region_edit_dialog
  if existing then existing.destroy() end

  local frame = player.gui.screen.add{
    type = "frame",
    name = "region_edit_dialog",
    caption = "Edit region",
    direction = "vertical",
  }
  frame.auto_center = true
  player.opened = frame

  local name_row = frame.add{type = "flow", direction = "horizontal"}
  name_row.style.vertical_align = "center"

  local name_field = name_row.add{
    type = "textfield",
    text = region.name,
    tags = {action = "rename_region", region_id = region_id},
  }
  name_field.style.width = 200
  name_field.focus()
  name_field.select_all()

  name_row.add{
    type = "sprite-button",
    sprite = "utility/trash",
    style = "tool_button_red",  -- small red icon button, same style vanilla uses for delete actions
    tooltip = "Delete region",
    tags = {action = "delete_region", region_id = region_id},
  }

  local color_frame = frame.add{
    type = "frame",
    direction = "vertical",
    style = "inside_shallow_frame_with_padding",
  }
  color_frame.style.top_margin = 6

  add_channel_row(color_frame, region_id, "r", region.color.r)
  add_channel_row(color_frame, region_id, "g", region.color.g)
  add_channel_row(color_frame, region_id, "b", region.color.b)
  add_channel_row(color_frame, region_id, "a", region.color.a)

  local button_row = frame.add{type = "flow"}
  button_row.style.top_margin = 6
  button_row.add{
    type = "sprite-button",
    sprite = "utility/enter",
    style = "tool_button_green",  -- dark green icon button, same style vanilla confirm actions use
    tooltip = "Done",
    tags = {action = "close_region_dialog"},
  }
end

-- ------------------------------------------------------------
-- gui event handlers (one handler per event - Factorio only keeps
-- the last script.on_event registration for a given event, so all
-- gui handling has to live in these single functions)
-- ------------------------------------------------------------

script.on_event(defines.events.on_gui_click, function(event)
  local element = event.element
  if not (element and element.valid) then return end
  local player = game.get_player(event.player_index)

  if element.name == "region_visibility_button" then
    set_all_regions_visible(not storage.regions_visible)
    return
  end

  if not (element.tags and element.tags.action) then return end
  local action = element.tags.action

  if action == "delete_region" then
    destroy_region(element.tags.region_id)  -- defined in control.lua, made global for this
    local dialog = player.gui.screen.region_edit_dialog
    if dialog then dialog.destroy() end

  elseif action == "close_region_dialog" then
    local dialog = player.gui.screen.region_edit_dialog
    if dialog then dialog.destroy() end
  end
end)

script.on_event(defines.events.on_gui_value_changed, function(event)
  local element = event.element
  if not (element and element.valid and element.tags and element.tags.action == "set_color_channel") then
    return
  end
  local region = storage.regions[element.tags.region_id]
  if not region then return end
  local player = game.get_player(event.player_index)

  local value = element.slider_value
  region.color[element.tags.channel] = value

  local field = element.parent.field
  if field and field.valid then
    field.text = tostring(math.floor(value))
  end

  apply_region_color(region)
  refresh_color_preview(player, region)
end)

script.on_event(defines.events.on_gui_text_changed, function(event)
  local element = event.element
  if not (element and element.valid and element.tags and element.tags.action) then return end
  local action = element.tags.action

  if action == "rename_region" then
    local region = storage.regions[element.tags.region_id]
    if not region then return end

    region.name = element.text

    local text = rendering.get_object_by_id(region.text_render_id)
    if text and text.valid then
      text.text = region.name
    end

  elseif action == "set_color_channel" then
    local region = storage.regions[element.tags.region_id]
    if not region then return end
    local player = game.get_player(event.player_index)

    local value = tonumber(element.text) or 0
    value = math.max(0, math.min(255, value))
    region.color[element.tags.channel] = value

    local slider = element.parent.slider
    if slider and slider.valid then
      slider.slider_value = value
    end

    apply_region_color(region)
    refresh_color_preview(player, region)
  end
end)

script.on_event(defines.events.on_gui_closed, function(event)
  if event.element and event.element.valid and event.element.name == "region_edit_dialog" then
    event.element.destroy()
  end
end)