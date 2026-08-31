script.on_init(
    function()
        rendering.draw_rectangle{
            color = {r = 1, g = 0, b = 0, a = 1},
            filled = true,
            left_top = {x = 0, y = 0},
            right_bottom = {x = 5, y = 5},
            surface = game.surfaces[1],
            render_mode = "chart",
        }
    end
)