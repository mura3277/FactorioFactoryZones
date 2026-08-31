data:extend({
	{
		type = "double-setting",
		name = "region-marker-click-tolerance",
		setting_type = "runtime-per-user",
		default_value = 0.5,
		minimum_value = 0,
		maximum_value = 5,
		order = "a",
	},
	{
		type = "color-setting",
		name = "region-marker-rectangle-color",
		setting_type = "runtime-per-user",
		default_value = {r = 255, g = 0, b = 255, a = 255},
		order = "b",
	},
	{
		type = "int-setting",
		name = "region-marker-line-width",
		setting_type = "runtime-per-user",
		default_value = 3,
		minimum_value = 1,
		maximum_value = 100,
		order = "c",
	},
	{
		type = "int-setting",
		name = "region-marker-text-scale",
		setting_type = "runtime-per-user",
		default_value = 10,
		minimum_value = 1,
		maximum_value = 100,
		order = "d",
	}
})