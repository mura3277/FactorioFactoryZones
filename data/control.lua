require("gui")

local TOOL_NAME = "region-marker-tool"
-- Click tolerance, rectangle color, and line width are player-adjustable
-- via settings.lua (Settings > Mod settings > Per Player in-game).

local CHART_MODES = {
  [defines.render_mode.chart] = true,
  [defines.render_mode.chart_zoomed_in] = true,
}

script.on_init(function()
  storage.regions = {}
  storage.next_region_id = 1
  storage.regions_visible = true

  for _, player in pairs(game.players) do
    build_visibility_button(player)
  end
end)

script.on_event(defines.events.on_player_created, function(event)
  build_visibility_button(game.get_player(event.player_index))
end)

-- Poll twice a second: the engine has no "map opened/closed" event, so
-- this is the standard way to react to the player's current view.
script.on_nth_tick(30, function()
  for _, player in pairs(game.connected_players) do
    if not player.gui.screen.region_visibility_button then
      build_visibility_button(player)  -- self-heals if on_init/on_player_created never ran for this player
    end
    player.gui.screen.region_visibility_button.visible = CHART_MODES[player.render_mode] or false
  end
end)

local function get_surface_index(event)
  -- Defensive: different Factorio versions have used "surface_index"
  -- (a number) or "surface" (a LuaSurface) on these events.
  if event.surface_index then return event.surface_index end
  if event.surface then return event.surface.index end
  return 1
end

local function point_in_area(point, area)
  return point.x >= area.left_top.x and point.x <= area.right_bottom.x
    and point.y >= area.left_top.y and point.y <= area.right_bottom.y
end

local function find_region_at(surface_index, point)
  for id, region in pairs(storage.regions) do
    if region.surface_index == surface_index and point_in_area(point, region.area) then
      return id, region
    end
  end
  return nil
end

local function label_position(area)
  return {
    x = (area.left_top.x + area.right_bottom.x) / 2,
    y = area.left_top.y - 0.5,  -- just above the top edge of the rectangle
  }
end

-- ------------------------------------------------------------
-- region create/destroy
-- ------------------------------------------------------------
local function create_region(player, surface_index, area)
  local rect_color = player.mod_settings["region-marker-rectangle-color"].value
  local line_width = player.mod_settings["region-marker-line-width"].value

  -- rect_color is normalized to 0-1, even tho the mod settings gui is 0-255. convert to the latter.
  rect_color = {r = math.floor(255 * rect_color.r), g = math.floor(255 * rect_color.g), b = math.floor(255 * rect_color.b), a = math.floor(255 * rect_color.a)}

  game.print(string.format("r=%.2f g=%.2f b=%.2f a=%.2f", rect_color.r, rect_color.g, rect_color.b, rect_color.a))

  rect_color_trans = construct_region_color(rect_color)

  game.print(string.format("r=%.2f g=%.2f b=%.2f a=%.2f", rect_color_trans.r, rect_color_trans.g, rect_color_trans.b, rect_color_trans.a))

  local rect_filled = rendering.draw_rectangle{
    color = rect_color_trans,
    filled = true,
    width = line_width,
    left_top = area.left_top,
    right_bottom = area.right_bottom,
    surface = game.surfaces[surface_index],
    render_mode = "chart",  -- only visible on the map view
    visible = storage.regions_visible,
  }
  local rect_outline = rendering.draw_rectangle{
    color = {r = rect_color.r, g = rect_color.g, b = rect_color.b, a = 255},
    filled = false,
    width = line_width,
    left_top = area.left_top,
    right_bottom = area.right_bottom,
    surface = game.surfaces[surface_index],
    render_mode = "chart",  -- only visible on the map view
    visible = storage.regions_visible,
  }

  local id = storage.next_region_id
  storage.next_region_id = id + 1
  local name = "Region " .. id

  local text_scale = player.mod_settings["region-marker-text-scale"].value
  local text = rendering.draw_text{
    text = name,
    color = {r = 255, g = 255, b = 255},
    target = label_position(area),
    surface = game.surfaces[surface_index],
    render_mode = "chart",
    alignment = "center",
    scale = text_scale,
    visible = storage.regions_visible,
  }

  storage.regions[id] = {
    name = name,
    color = rect_color,
    filled_render_id = rect_filled.id,
    outline_render_id = rect_outline.id,
    text_render_id = text.id,
    surface_index = surface_index,
    area = {left_top = area.left_top, right_bottom = area.right_bottom},
  }

  open_region_dialog(player, id)
end

function destroy_region(region_id)
  local region = storage.regions[region_id]
  if not region then return end

  local rect_filled = rendering.get_object_by_id(region.filled_render_id)
  if rect_filled and rect_filled.valid then rect_filled.destroy() end

  local rect_outline = rendering.get_object_by_id(region.outline_render_id)
  if rect_outline and rect_outline.valid then rect_outline.destroy() end

  local text = rendering.get_object_by_id(region.text_render_id)
  if text and text.valid then text.destroy() end

  storage.regions[region_id] = nil
end

-- ------------------------------------------------------------
-- selection tool: click to edit, drag to create
-- ------------------------------------------------------------

script.on_event(defines.events.on_player_selected_area, function(event)
  if event.item ~= TOOL_NAME then return end

  local player = game.get_player(event.player_index)
  if player.gui.screen.region_edit_dialog then
    return  -- ignore drags/clicks while the create/edit dialog is open
  end

  local surface_index = get_surface_index(event)
  local area = event.area
  local width = area.right_bottom.x - area.left_top.x
  local height = area.right_bottom.y - area.left_top.y
  local click_tolerance = player.mod_settings["region-marker-click-tolerance"].value

  if width <= click_tolerance and height <= click_tolerance then
    -- Treat this as a click rather than a drag.
    local point = {
      x = (area.left_top.x + area.right_bottom.x) / 2,
      y = (area.left_top.y + area.right_bottom.y) / 2,
    }
    local id = find_region_at(surface_index, point)
    if id then
      open_region_dialog(player, id)  -- defined in gui.lua
    end
    return
  end

  -- A real drag: create a new region and immediately prompt for a name.
  create_region(player, surface_index, area)
end)