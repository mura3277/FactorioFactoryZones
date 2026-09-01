require("gui")

local TOOL_NAME = "region-marker-tool"

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

local function point_in_area(point, area)
  return point.x >= area.tl.x and point.x <= area.br.x
    and point.y >= area.tl.y and point.y <= area.br.y
end

local function point_in_region(point, region)
  for _, r in pairs(region.rects) do
    if point_in_area(point, {tl = r.points.tl, br = r.points.br}) then return true end
  end
  return false
end

local function find_region_at(surface_index, point)
  for id, region in pairs(storage.regions) do
    if region.surface_index == surface_index and point_in_region(point, region) then
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
local function create_rect(line_width, rect_color, surface_index, area)
  -- construct 4 points from the 2 point click drag area table
  line_points = {
    {x1 = area.left_top.x, y1 = area.left_top.y, x2 = area.right_bottom.x, y2 = area.left_top.y},
    {x1 = area.right_bottom.x, y1 = area.left_top.y, x2 = area.right_bottom.x, y2 = area.right_bottom.y},
    {x1 = area.right_bottom.x, y1 = area.right_bottom.y, x2 = area.left_top.x, y2 = area.right_bottom.y},
    {x1 = area.left_top.x, y1 = area.right_bottom.y, x2 = area.left_top.x, y2 = area.left_top.y},
  }

  lines = {}
  for _, p in pairs(line_points) do
    table.insert(lines, rendering.draw_line{
      color = {r = rect_color.r, g = rect_color.g, b = rect_color.b, a = 255},
      width = line_width,
      from = {p.x1, p.y1},
      to = {p.x2, p.y2},
      surface = game.surfaces[surface_index],
      render_mode = "chart",
    })
  end

  return {
    lines = lines,
    points = {
      tl = {x = area.left_top.x, y = area.left_top.y},
      tr = {x = area.right_bottom.x, y = area.left_top.y},
      br = {x = area.right_bottom.x, y = area.right_bottom.y},
      bl = {x = area.left_top.x, y = area.right_bottom.y},
    }
  }
end

local function create_region(player, surface_index, area)
  local line_width = player.mod_settings["region-marker-line-width"].value
  local rect_color = player.mod_settings["region-marker-rectangle-color"].value

  -- rect_color is normalized to 0-1, even tho the mod settings gui is 0-255. convert to the latter.
  rect_color = {r = math.floor(255 * rect_color.r), g = math.floor(255 * rect_color.g), b = math.floor(255 * rect_color.b), a = math.floor(255 * rect_color.a)}

  --TODO
  rect_color_transparent = construct_region_color(rect_color)

  rect = create_rect(line_width, rect_color, surface_index, area)

  local id = storage.next_region_id
  storage.next_region_id = id + 1
  local name = "Region " .. id

  local text_scale = player.mod_settings["region-marker-text-scale"].value
  local text = rendering.draw_text{
    text = name,
    color = {r = 255, g = 255, b = 255},
    --TODO label pos needs to use the first point in points table instead of area
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
    lines = lines,
    text_render_id = text.id,
    surface_index = surface_index,
    rects = {rect},
  }

  open_region_dialog(player, id)
end

function destroy_region(region_id)
  local region = storage.regions[region_id]
  if not region then return end

  for _, l in pairs(region.lines) do
    if l and l.valid then l.destroy() end
  end

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
  if player.gui.screen.region_edit_dialog then return end

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
    local id = find_region_at(event.surface.index, point)
    if id then
      open_region_dialog(player, id)  -- defined in gui.lua
    end
    return
  end

  -- A real drag: create a new region and immediately prompt for a name.
  create_region(player, event.surface.index, area)
end)