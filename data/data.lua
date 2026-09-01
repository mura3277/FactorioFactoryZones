data:extend({
	{
		type = "selection-tool",
		name = "region-marker-tool",
		icon = "__base__/graphics/icons/deconstruction-planner.png", -- TODO: swap for your own icon
		icon_size = 64,
		flags = {"only-in-cursor", "not-stackable", "spawnable"},
		subgroup = "tool",
		order = "z[region-marker]",
		stack_size = 1,

		select = {
			border_color = {r = 0.2, g = 1, b = 0.2},
			chart_color = {r = 0.2, g = 1, b = 0.2},  -- box color while dragging on the map
			cursor_box_type = "copy",
			mode = {"nothing"},  -- just give me the area, don't match entities/tiles
		},

		alt_select = {
			border_color = {r = 1, g = 0.2, b = 0.2},
			chart_color = {r = 1, g = 0.2, b = 0.2},
			cursor_box_type = "not-allowed",
			mode = {"nothing"},
		},
	},
	{
		type = "shortcut",
		name = "give-region-marker-tool",
		order = "z[region-marker]",
		action = "spawn-item",
		item_to_spawn = "region-marker-tool",
		icon = "__base__/graphics/icons/deconstruction-planner.png", -- TODO: swap for your own icon
		icon_size = 64,
		small_icon = "__base__/graphics/icons/deconstruction-planner.png", -- TODO: swap for your own icon
		small_icon_size = 64,
	}
})