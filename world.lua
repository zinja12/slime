--world.lua

local world = {}

--constants
local TILE_SIZE = 8
local TILES = {
  ["."] = { x = 1, y = 3, movable = false,  name = "floor" },
  ["g"] = { x = 3, y = 3, movable = false,  name = "grass" },
  ["d"] = { x = 2, y = 3, movable = false,  name = "dirt" },
  ["#"] = { x = 1, y = 1, movable = false,  name = "wall" },
  ["T"] = { x = 1, y = 2, movable = false,  name = "wall_top" },
  ["$"] = { x = 2, y = 1, movable = false,  name = "pillar" },
  ["X"] = { x = 2, y = 2, movable = true,  name = "cracked_wall" },
  ["r"] = { x = 4, y = 3, movable = true,  name = "rock" },
  ["P"] = { x = 3, y = 4, movable = true,  name = "player" },
  ["t"] = { x = 5, y = 3, movable = true,  name = "tree" },
  ["s"] = { x = 2, y = 6, movable = true,  consumable = true, name = "slime" },
}

--world data structures
world.map = {}
world.backdrop_map = {}
world.foreground_map = {}
world.neighbors = {}
world.width  = 0
world.height = 0
world.player_spawn_x = 0
world.player_spawn_y = 0
world.room_cache = {}

function world.init()
    --room cache for previously visited rooms
    world.room_cache = {}
    --load initial room
    world.load("room0.json")
end

function world.load(filename)
    local data = usagi.read_json(filename)
    --set world variables
    world.width  = data.tile_map_width
    world.height = data.tile_map_height

    --set neighbor connections
    world.neighbors = data.neighbors or {}

    --set up foreground layer
    for y = 1, world.height do
      world.foreground_map[y] = {}
      for x = 1, world.width do
        world.foreground_map[y][x] = "."
      end
    end

    --set up background layer
    for y = 1, world.height do
      world.backdrop_map[y] = {}
      for x = 1, world.width do
        world.backdrop_map[y][x] = "."
      end
    end

    --check room cache and load if available
    if world.room_cache[filename] then
        --load map from room cache (to keep player changes)
        world.map = world.room_cache[filename]
    else
        --instantiate new world map in memory so as to not overwrite old cached map
        world.map = {}
        --load tile data
        for y, row in ipairs(data.tile_map) do
            world.map[y] = {}
            for x, tile_char in ipairs(row) do
                if tile_char == "P" then
                    world.map[y][x] = "."
                    world.player_spawn_x = (x - 1) * TILE_SIZE
                    world.player_spawn_y = (y - 1) * TILE_SIZE
                else
                    world.map[y][x] = tile_char
                end
            end
        end
        --apply rules on initial load of a room
        world.apply_tile_rules()
        --save to room cache
        world.room_cache[filename] = world.map
    end
end

function world.is_empty(tile_char)
    return tile_char == "." or tile_char == "g" or tile_char == "d"
end

function world.is_consumable(tile_char)
    return tile_char == "s"
end

function world.set_tile(x, y, char)
    world.map[y][x] = char
end

function world.apply_tile_rules()
    for y = 1, world.height do
        for x = 1, world.width do
            if world.map[y][x] == "#" then
                --get tile above and below
                local tile_above = (y > 1) and world.map[y - 1][x] or ""
                local tile_below = (y < world.height) and world.map[y + 1][x] or ""
                local tile_right = (x < world.width) and world.map[y][x + 1] or ""
                local tile_left = (x > 1) and world.map[y][x - 1] or ""
                --apply rules
                
                --out of bounds below or empty -> regular wall
                if y + 1 >= world.height or world.is_empty(world.map[y + 1][x]) then
                    world.map[y][x] = "#"
                end

                --left side wall
                if x - 1 < 0 or world.is_empty(world.map[y][x - 1]) then
                    world.map[y][x] = "#"
                end

                --right side wall
                if x + 1 >= world.width or world.is_empty(world.map[y][x + 1]) then
                    world.map[y][x] = "#"
                end

                --top wall
                if y + 1 <= world.height and world.map[y + 1][x] == "#" then
                    world.map[y][x] = "T"
                end
                
                if world.is_empty(tile_above) and world.is_empty(tile_below) and world.is_empty(tile_right) and world.is_empty(tile_left) then
                    world.map[y][x] = "$"
                end
            end
        end
    end
end

function world.get_player_spawn()
    --return parsed player coords, default to 0, 0
    return world.player_spawn_x or 0, world.player_spawn_y or 0
end

function world.update()
end

function world.draw()
    for y, row in ipairs(world.map) do
        for x, tile_id in ipairs(row) do
            local tile_data = TILES[tile_id]
            --calculate source x and y on spritesheet
            local source_x = (tile_data.x - 1) * TILE_SIZE
            local source_y = (tile_data.y - 1) * TILE_SIZE
            local grid_x = x - 1
            local grid_y = y - 1
            local offset_x = 0
            local offset_y = 0

            --draw tile
            draw_scaled_tile(grid_x, grid_y, source_x, source_y, offset_x, offset_y)
        end
    end
end

return world