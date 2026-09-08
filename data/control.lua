require("gui")

script.on_init(
    function()
        storage.regions = {}
        storage.next_region_id = 1
        storage.regions_visible = true
        for _, player in pairs(game.players) do build_visibility_button(player) end
    end
)

script.on_event(defines.events.on_player_created,
    function(event)
        build_visibility_button(game.get_player(event.player_index))
    end
)

script.on_nth_tick(30,
    function()
        for _, player in pairs(game.connected_players) do -- self-heals if on_init/on_player_created never ran for this player
            if not player.gui.screen.region_visibility_button then build_visibility_button(player) end
            player.gui.screen.region_visibility_button.visible = (player.render_mode == defines.render_mode.chart) or false
        end
    end
)

local function point_in_area(point, area)
    return point.x >= area.left_top.x and point.x <= area.right_bottom.x and point.y >= area.left_top.y and point.y <= area.right_bottom.y
end

local function point_in_region(point, region)
    for _, r in pairs(region.rects) do
        if point_in_area(point, r.area) then return true end
    end
    return false
end

local function line_in_region(line, region)
    return point_in_region({x = line.x1, y = line.y1}, region) and point_in_region({x = line.x2, y = line.y2}, region)
end

local function find_region_at(surface_index, point)
    for id, region in pairs(storage.regions) do
        if region.surface_index == surface_index and point_in_region(point, region) then return id, region end
    end
    return nil
end

local function create_rect(player, rect_color, surface_index, line_points, area)
    local lines = {}
    for _, p in pairs(line_points) do
        table.insert(lines, rendering.draw_line {
            color = {r = rect_color.r, g = rect_color.g, b = rect_color.b, a = 255},
            width = player.mod_settings["region-marker-line-width"].value,
            from = {p.x1, p.y1},
            to = {p.x2, p.y2},
            surface = game.surfaces[surface_index],
            render_mode = "chart"
        })
    end
    local rect_trans = rendering.draw_rectangle {
        color = construct_region_color(rect_color),
        filled = true,
        left_top = area.left_top,
        right_bottom = area.right_bottom,
        surface = game.surfaces[surface_index],
        render_mode = "chart"
    }
    return {lines = lines, rect_trans = rect_trans, line_points = line_points, area = area}
end

local function create_region(player, surface_index, line_points, area)
    local rect_color = player.mod_settings["region-marker-rectangle-color"].value
    rect_color = { -- rect_color is normalized to 0-1, even tho the mod settings gui is 0-255. convert to the latter.
        r = math.floor(255 * rect_color.r),
        g = math.floor(255 * rect_color.g),
        b = math.floor(255 * rect_color.b),
        a = math.floor(255 * rect_color.a)
    }
    local rect = create_rect(player, rect_color, surface_index, line_points, area)
    local id = storage.next_region_id
    storage.next_region_id = id + 1
    local name = "Region " .. id
    local text = rendering.draw_text {
        text = name,
        color = {r = 255, g = 255, b = 255},
        target = { x = (area.left_top.x + area.right_bottom.x) / 2, y = area.left_top.y - 0.5},
        surface = game.surfaces[surface_index],
        render_mode = "chart",
        alignment = "center",
        scale = player.mod_settings["region-marker-text-scale"].value,
        visible = storage.regions_visible
    }
    storage.regions[id] = {
        name = name,
        color = rect_color,
        text_render_id = text.id,
        surface_index = surface_index,
        rects = {rect}
    }
    open_region_dialog(player, id)
end

function destroy_region(region_id)
    local region = storage.regions[region_id]
    if not region then return end
    for _, r in pairs(region.rects) do
        for _, l in pairs(r.lines) do
            if l and l.valid then l.destroy() end
        end
        r.rect_trans.destroy()
    end
    local text = rendering.get_object_by_id(region.text_render_id)
    if text and text.valid then text.destroy() end
    storage.regions[region_id] = nil
end

local function lines_intersect_region(line_points)
    local region_count = 0
    local state = {intersecting_line_index = -1, last_valid_region_id = -1, result = -1}
    for id, region in pairs(storage.regions) do
        local count = 0
        --TODO escape searching regions with only one rect
        for i, l in pairs(line_points) do
            if line_in_region(l, region) then
                state.intersecting_line_index = i
                count = count + 1
            end
            if count == 1 then -- if we have enough intersections, store region id
                -- all points of the new rect fall within the region. no action should be taken
                -- early escape if new drag covers multiple regions
                if region_count > 0 and state.last_valid_region_id ~= id then
                    return state
                end
                region_count = region_count + 1
                state.last_valid_region_id = id
            elseif count == 4 then
                return state
            end
        end
    end
    -- check if we had a valid region
    if state.last_valid_region_id ~= -1 then
        state.result = 1
        return state
    else
        state.result = 0
        return state
    end
end

function line_intersect_point(x1, y1, x2, y2, x3, y3, x4, y4) -- 2dengine.com/doc/intersections/?captcha=1#Segment_vs_segment
  local dx1, dy1 = x2 - x1, y2 - y1
  local dx2, dy2 = x4 - x3, y4 - y3
  local d = dx1*dy2 - dy1*dx2
  if d == 0 then return nil end
  local dx3, dy3 = x1 - x3, y1 - y3
  local t1 = (dx2*dy3 - dy2*dx3)/d
  if t1 < 0 or t1 > 1 then return nil end
  local t2 = (dx1*dy3 - dy1*dx3)/d
  if t2 < 0 or t2 > 1 then return nil end
  return {x = x1 + t1*dx1, y = y1 + t1*dy1} -- point of intersection
end

local function shift_intersected_points(intersection, line_points, area)
    for _, lp in pairs(line_points) do
        for _,r in pairs(storage.regions[intersection.last_valid_region_id].rects) do
            for _,l in pairs(r.line_points) do
                intersect_point = line_intersect_point(lp.x1, lp.y1, lp.x2, lp.y2, l.x1, l.y1, l.x2, l.y2)
                if intersect_point then -- we found which line in the region we crossed
                    if l.dir == 1 then -- shift vertex positions and shift area vector
                        lp.y2 = intersect_point.y
                        area.right_bottom.y = intersect_point.y
                    elseif l.dir == 2 then
                        lp.x1 = intersect_point.x
                        area.left_top.x = intersect_point.x
                    elseif l.dir == 3 then
                        lp.y1 = intersect_point.y
                        area.left_top.y = intersect_point.y
                    elseif l.dir == 4 then
                        lp.x2 = intersect_point.x
                        area.right_bottom.x = intersect_point.x
                    end
                    --TODO reconstruct intersected_line vertex positions
                end
            end
        end
    end
end

script.on_event(
    defines.events.on_player_selected_area,
    function(event)
        if event.item ~= "region-marker-tool" then return end

        local player = game.get_player(event.player_index)
        if player.gui.screen.region_edit_dialog then return end

        local width = event.area.right_bottom.x - event.area.left_top.x
        local height = event.area.right_bottom.y - event.area.left_top.y
        local click_tolerance = player.mod_settings["region-marker-click-tolerance"].value

        if width <= click_tolerance and height <= click_tolerance then
            -- Treat this as a click rather than a drag.
            local point = {
                x = (event.area.left_top.x + event.area.right_bottom.x) / 2,
                y = (event.area.left_top.y + event.area.right_bottom.y) / 2
            }
            local id = find_region_at(event.surface.index, point)
            if id then open_region_dialog(player, id) end
            return
        end

        local line_points = {
            {x1 = event.area.left_top.x, y1 = event.area.left_top.y, x2 = event.area.right_bottom.x, y2 = event.area.left_top.y, dir = 1},
            {x1 = event.area.right_bottom.x, y1 = event.area.left_top.y, x2 = event.area.right_bottom.x, y2 = event.area.right_bottom.y, dir = 2},
            {x1 = event.area.left_top.x, y1 = event.area.right_bottom.y, x2 = event.area.right_bottom.x, y2 = event.area.right_bottom.y, dir = 3},
            {x1 = event.area.left_top.x, y1 = event.area.left_top.y, x2 = event.area.left_top.x, y2 = event.area.right_bottom.y, dir = 4}
        }
        local intersection = lines_intersect_region(line_points) -- test if the drag intersects with an existing region
        if intersection.result == 1 then -- valid intersection
            local region = storage.regions[intersection.last_valid_region_id] -- merge new rect with existing region
            table.remove(line_points, intersection.intersecting_line_index) -- get line that was removed
            shift_intersected_points(intersection, line_points, event.area)
            local rect = create_rect(player, region.color, event.surface.index, line_points, event.area)
            table.insert(region.rects, rect)
        elseif intersection.result == 0 then
            -- create a new region and immediately prompt for a name.
            create_region(player, event.surface.index, line_points, event.area)
        else return end
    end
)