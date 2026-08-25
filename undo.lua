--undo.lua
local undo = {}

--past action table
undo.history = {}

local function deep_copy_map(map)
    --set up copy
    local copy = {}
    --iterate and copy
    for y, row in ipairs(map) do
        copy[y] = {}
        for x, val in ipairs(row) do
            copy[y][x] = val
        end
    end
    return copy
end

function undo.clear()
    --reset history
    undo.history = {}
end

--save world state
function undo.save_state(player, world)
    local state = {
        room = world.current_room,
        player_x = player.x,
        player_y = player.y,
        size = player.slime_size,
        last_direction_x = player.last_direction_x,
        last_direction_y = player.last_direction_y,
        map = deep_copy_map(world.map)
    }
    table.insert(undo.history, state)
end

--undo last action
function undo.perform_undo(player, world)
    --cannot rewind without history
    if #undo.history == 0 then
        return
    end

    --pop last state off history
    local state = table.remove(undo.history)

    --if rewinded state belongs to different room, force load
    if state.room ~= world.current_room then
        world.load(state.room)
    end

    --restore player state
    player.x = state.player_x
    player.y = state.player_y
    player.slime_size = state.size
    player.last_direction_x = state.last_direction_x
    player.last_direction_y = state.last_direction_y

    --snap player to grid if they were moving
    player.target_tile_position_x = state.player_x
    player.target_tile_position_y = state.player_y
    player.moving = false
    player.pixels_remaining = 0

    --restore map
    world.map = state.map
end

return undo
