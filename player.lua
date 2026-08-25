--player.lua
local player = {}
local world = require("world")
local particles = require("particles")
local undo = require("undo")

local TILE_SIZE = 8

function player.init()
    --get starting position
    local start_x, start_y = world.get_player_spawn()

    player.x = start_x
    player.y = start_y
    player._v = 0
    player._h = 0
    player.direction_x = 0
    player.direction_y = 0
    player.last_direction_x = 0
    player.last_direction_y = 0
    player.target_tile_position_x = 0
    player.target_tile_position_y = 0
    player.pixels_remaining = 0
    player.moving = false
    player.input_timer = 0
    player.input_delay_threshold = 15

    --animation
    player.flip_x = false
    player.animation_frame = 1
    player.animation_timer = 0
    player.animations = {
        idle_small = {
            frames = {{ x = 2, y = 4 }, { x = 3, y = 4 }},
            speed = 20,
            frame_size = 8
        },
        idle_medium = {
            frames = {{ x = 2, y = 3 }, { x = 3, y = 3 }},
            speed = 25,
            frame_size = 8
        },
        idle_large = {
            frames = {{ x = 2, y = 5 }, { x = 4, y = 5 }},
            speed = 30,
            frame_size = 16
        }
    }

    --slime variables
    player.slime_size = 1
    player.min_slime_size = 1
    player.max_slime_size = 3
end

function player.update()
    player.get_input()
    player.tile_movement()
    player.check_slime_eject()
    player.update_sprite_flip_effect()
    player.update_animation()
end

function player.input_down(action)
    if input.pressed(action) then
        return 1
    end
    return 0
end

function player.input_held(action)
    if input.held(action) then
        return 1
    end
    return 0
end

function player.get_input()
    --undo input
    --prevent undo if the player is moving
    if not player.moving and player.input_down(input.BTN2) == 1 then
        undo.perform_undo(player, world)
        --skip all other input
        player._v = 0
        player._h = 0
        player.input_timer = 0
        return
    end

    --check for input pressed
    -- player._v = player.input_down(input.DOWN) - player.input_down(input.UP)
    -- player._h = player.input_down(input.RIGHT) - player.input_down(input.LEFT)
    local v_press = player.input_down(input.DOWN) - player.input_down(input.UP)
    local h_press = player.input_down(input.RIGHT) - player.input_down(input.LEFT)
    
    --check for held keys
    local v_hold = player.input_held(input.DOWN) - player.input_held(input.UP)
    local h_hold = player.input_held(input.RIGHT) - player.input_held(input.LEFT)

    --check for immedate movement
    if v_press ~= 0 or h_press ~= 0 then
        --key pressed, trigger movement
        player._v = v_press
        player._h = h_press
        --reset input timer
        player.input_timer = 0
    elseif v_hold ~= 0 or h_hold ~= 0 then
        --input held
        player.input_timer += 1
        --move if timer is past threshold
        if player.input_timer > player.input_delay_threshold then
            player._v = v_hold
            player._h = h_hold
        else
            --no movement
            player._v = 0
            player._h = 0
        end
    else
        --no movement
        player._v = 0
        player._h = 0
        player.input_timer = 0
    end
end

--player tile movement
function player.tile_movement()
    --normal movement code
    if not player.moving then
        if player._v == 0 and player._h == 0 then
            player.direction_x = 0
            player.direction_y = 0
            player.moving = false
        else
            --pull direction, compute target tile requested, validate movement then move
            player.direction_x = player._h
            player.direction_y = player._v
            --prioritize vertical over horizontal
            if player.direction_x ~= 0 and player.direction_y ~= 0 then
                player.direction_x = 0
            end
            --set last direction
            player.last_direction_x = player.direction_x
            player.last_direction_y = player.direction_y
            --calculate target tile position
            player.target_tile_position_x = player.x + (player.direction_x * TILE_SIZE)
            player.target_tile_position_y = player.y + (player.direction_y * TILE_SIZE)
            --move only if we have a valid unsolid tile to move into
            local target_x = player.target_tile_position_x / TILE_SIZE
            local target_y = player.target_tile_position_y / TILE_SIZE
            
            --detect room edges during movement
            local move_room = player.detect_room_edge_transitions(target_x, target_y)
            if move_room then
                return
            end
            
            --define movement variables
            local can_move = false
            local can_consume = false
            local pushable_rocks = {}
            --get slime size
            if player.slime_size < 3 then
                --small and medium slime only have to check 1x1 block
                local target_tile = world.map[target_y + 1][target_x + 1]
                if world.is_empty(target_tile) then
                    can_move = true
                elseif world.is_consumable(target_tile) then
                    --check if there is room to expand to a large slime
                    if player.slime_size == 2 then
                        local origin_x, origin_y = player.find_valid_growth_origin(target_x, target_y)
                        
                        if origin_x ~= nil then
                            can_consume = true
                            --override target snap position to valid origin
                            player.target_tile_position_x = origin_x * TILE_SIZE
                            player.target_tile_position_y = origin_y * TILE_SIZE
                            --if valid space forces backward expansion into current spot, then zero slide direction so sprite does not jitter and rubber band
                            if origin_x == player.x / TILE_SIZE and origin_y == player.y / TILE_SIZE then
                                player.direction_x = 0
                                player.direction_y = 0
                            end
                        end
                    else
                        can_consume = true
                    end
                end
            else
                --large slime checks 2x2 blocks
                --do not check out of bounds
                if target_y + 2 <= world.height and target_x + 2 <= world.width then
                    local space_clear = true
                    --check area around player
                    for dy = 0, 1 do
                        for dx = 0, 1 do
                            local check_x = target_x + dx
                            local check_y = target_y + dy

                            --check tiles that are not occupied by the player
                            local current_x = player.x / TILE_SIZE
                            local current_y = player.y / TILE_SIZE
                            local is_player_body = (check_x >= current_x and check_x <= current_x + 1 and check_y >= current_y and check_y <= current_y + 1)

                            if not is_player_body then
                                local tile_char = world.map[check_y + 1][check_x + 1]

                                if tile_char == "r" then
                                    --rock, check pushable
                                    local push_x = check_x + player.direction_x
                                    local push_y = check_y + player.direction_y

                                    if push_x >= 0 and push_x < world.width and push_y >= 0 and push_y < world.height then
                                        if world.is_empty(world.map[push_y + 1][push_x + 1]) then
                                            --can push rock, tile behind is empty
                                            table.insert(pushable_rocks, {
                                                origin_x = check_x,
                                                origin_y = check_y,
                                                next_x = push_x,
                                                next_y = push_y
                                            })
                                        else
                                            --rock is blocked behind by object
                                            space_clear = false
                                        end
                                    else
                                        --rock is blocked by edge of room
                                        space_clear = false
                                    end
                                elseif not world.is_empty(tile_char) then
                                    space_clear = false
                                end
                            end
                        end
                    end

                    if space_clear then
                        can_move = true
                    else
                        pushable_rocks = {}
                    end
                end
            end

            --move or consume
            if can_move then
                undo.save_state(player, world)

                --check for pushable rocks
                for i = 1, #pushable_rocks do
                    local r = pushable_rocks[i]
                    world.set_tile(r.origin_x + 1, r.origin_y + 1, ".")
                    world.set_tile(r.next_x + 1, r.next_y + 1, "r")
                end

                player.moving = true
                player.pixels_remaining = TILE_SIZE
                --spawn particles for movement
                particles.spawn(player.x, player.y, 4, 3, 10, false)
            elseif can_consume then
                undo.save_state(player, world)
                player.moving = true
                player.pixels_remaining = TILE_SIZE
                --spawn particles for movement
                particles.spawn(player.x, player.y, 4, 3, 10, false)
                --set world tile to empty to consume
                world.set_tile(target_x + 1, target_y + 1, ".")
                --increase slime size
                player.safe_slime_size_change(1)
            end
        end
    else
        local speed = 2
        local step_x = player.direction_x * speed
        local step_y = player.direction_y * speed
        player.x += step_x
        player.y += step_y
        player.pixels_remaining -= speed

        --remaining pixel distance to move is 0 then we stop
        if player.pixels_remaining <= 0 then
            player.moving = false
            --snap to tile
            player.x = player.target_tile_position_x
            player.y = player.target_tile_position_y
            --reset animation frmae
            player.animation_frame = 1
            player.animation_timer = 0
        end
    end
end

function player.find_valid_growth_origin(target_x, target_y)
    --4 possible origins for a 2x2 space to include coordinate pair target_x, target_y
    local origins = {
        --default (down right expand)
        { x = target_x, y = target_y },
        --left expand
        { x = target_x - 1, y = target_y },
        --expand up
        { x = target_x, y = target_y - 1 },
        --expand up left
        { x = target_x - 1, y = target_y - 1 }
    }

    --loop over origins and check for valid expansion to expand into
    for i = 1, #origins do
        local origin_x = origins[i].x
        local origin_y = origins[i].y
        --check 2x2 area is within bounds
        if origin_x >= 0 and origin_y >= 0 and origin_x + 1 < world.width and origin_y + 1 < world.height then
            local top_left = world.map[origin_y + 1][origin_x + 1]
            local top_right = world.map[origin_y + 1][origin_x + 2]
            local bottom_left = world.map[origin_y + 2][origin_x + 1]
            local bottom_right = world.map[origin_y + 2][origin_x + 2]

            --valid tile is empty or if it is the slime being consumed
            local function valid_tile(cx, cy, tile_char)
                return world.is_empty(tile_char) or (cx == target_x and cy == target_y)
            end

            if valid_tile(origin_x, origin_y, top_left) and 
               valid_tile(origin_x + 1, origin_y, top_right) and 
               valid_tile(origin_x, origin_y + 1, bottom_left) and 
               valid_tile(origin_x + 1, origin_y + 1, bottom_right) then
                --return first successful pair
                return origin_x, origin_y
            end
        end
    end
    return nil, nil
end

function player.check_slime_eject()
    --only allow slime eject if not moving, button pressed, size > 1 and a direction is present
    if not player.moving and player.input_down(input.BTN1) == 1 and player.slime_size > 1 and (player.last_direction_x ~= 0 or player.last_direction_y ~= 0) then
        --calculate current player tile position
        local current_player_tile_x = player.x / TILE_SIZE
        local current_player_tile_y = player.y / TILE_SIZE
        --calculate target and reverse tile positions
        local target_x = current_player_tile_x + player.last_direction_x
        local target_y = current_player_tile_y + player.last_direction_y
        local slime_reverse_target_x = current_player_tile_x - player.last_direction_x
        local slime_reverse_target_y = current_player_tile_y - player.last_direction_y
        --bounds check for target tile for slime
        local target_tile = ""
        if target_y >= 0 and target_y < world.height and target_x >= 0 and target_x < world.width then
            target_tile = world.map[target_y + 1][target_x + 1]
        end
        --bounds check for reverse tile
        local slime_reverse_target_tile = ""
        if slime_reverse_target_y >= 0 and slime_reverse_target_y < world.height and slime_reverse_target_x >= 0 and slime_reverse_target_x < world.width then
            slime_reverse_target_tile = world.map[slime_reverse_target_y + 1][slime_reverse_target_x + 1]
        end
        
        --check valid slime positions
        --empty primary direction should take priority
        if world.is_empty(target_tile) then
            undo.save_state(player, world)
            world.set_tile(target_x + 1, target_y + 1, "s")
            player.safe_slime_size_change(-1)
        elseif not world.is_empty(target_tile) and (world.is_empty(slime_reverse_target_tile) or slime_reverse_target_tile == "c") then
            undo.save_state(player, world)

            --cracked wall tile interaction
            if slime_reverse_target_tile == "c" then
                --set tile
                world.set_tile(slime_reverse_target_x + 1, slime_reverse_target_y + 1, ".")
            end

            --move player backward and spawn slime (recoil)
            player.moving = true
            player.direction_x = player.last_direction_x * -1
            player.direction_y = player.last_direction_y * -1
            player.pixels_remaining = TILE_SIZE
            player.target_tile_position_x = slime_reverse_target_x * TILE_SIZE
            player.target_tile_position_y = slime_reverse_target_y * TILE_SIZE
            --set tile
            world.set_tile(current_player_tile_x + 1, current_player_tile_y + 1, "s")
            --decrease slime size
            player.safe_slime_size_change(-1)
        end
    end
end

function player.safe_slime_size_change(amount)
    player.slime_size += amount
    if player.slime_size >= player.max_slime_size then
        player.slime_size = player.max_slime_size
    elseif player.slime_size <= player.min_slime_size then
        player.slime_size = player.min_slime_size
    end
end

function player.update_sprite_flip_effect()
    --set flip x based on player input direction
    if player.direction_x ~= 0 then
        if player.direction_x > 0 then
            player.flip_x = false
        elseif player.direction_x < 0 then
            player.flip_x = true
        end
    end
end

function player.get_idle_animation_state()
    local idle_animation_state = "idle_medium"
    if player.slime_size == 1 then
        idle_animation_state = "idle_small"
    elseif player.slime_size == 2 then
        idle_animation_state = "idle_medium"
    elseif player.slime_size == 3 then
        idle_animation_state = "idle_large"
    end
    return idle_animation_state
end

function player.update_animation()
    --update animations

    --get idle animation state
    local idle_animation_state = player.get_idle_animation_state()

    --idle animation if player is not moving
    if not player.moving then
        --increase timer tick every frame
        player.animation_timer += 1
        local current_animation_frame = player.animations[idle_animation_state]
        
        --check against speed
        if player.animation_timer >= current_animation_frame.speed then
            --reset
            player.animation_timer = 0
            player.animation_frame += 1
            
            --loop back to frame 1 if reached end of animation
            if player.animation_frame > #current_animation_frame.frames then
                player.animation_frame = 1
            end
        end
    end
end

function player.detect_room_edge_transitions(target_x, target_y)
    --detect edges of rooms
    local move_room = false

    --set threshold based on size
    local detection_threshold = 0
    if player.slime_size == 3 then
        detection_threshold = 1
    end
    
    --right edge
    if target_x + detection_threshold >= world.width and type(world.neighbors.right) == "string" then
        undo.save_state(player, world)
        --load room
        world.load(world.neighbors.right)
        --set target tile
        player.target_tile_position_x = 0
        move_room = true
    --left edge
    elseif target_x < 0 and type(world.neighbors.left) == "string" then
        undo.save_state(player, world)
        world.load(world.neighbors.left)
        --subtract off detection threshole to properly position large slime
        player.target_tile_position_x = (world.width - 1 - detection_threshold) * TILE_SIZE
        move_room = true
    --up edge
    elseif target_y < 0 and type(world.neighbors.up) == "string" then
        undo.save_state(player, world)
        world.load(world.neighbors.up)
        --subtract off detection threshold to properly position large slime
        player.target_tile_position_y = (world.height - 1 - detection_threshold) * TILE_SIZE
        move_room = true
    --down edge
    elseif target_y + detection_threshold >= world.height and type(world.neighbors.down) == "string" then
        undo.save_state(player, world)
        world.load(world.neighbors.down)
        player.target_tile_position_y = 0
        move_room = true
    end

    if move_room then
        player.moving = true
        player.x = player.target_tile_position_x
        player.y = player.target_tile_position_y
        player.pixels_remaining = 0
    end

    return move_room
end

function player.draw()
    local offset_x = 0
    local offset_y = 0

    --get animation frame data for idle animations
    local idle_animation_state = player.get_idle_animation_state()
    local frame_data = player.animations[idle_animation_state].frames[player.animation_frame]
    local sprite_size = player.animations[idle_animation_state].frame_size
    local source_x = (frame_data.x * TILE_SIZE)
    local source_y = (frame_data.y * TILE_SIZE)
    local last_frame = player.animations[idle_animation_state].frames[#(player.animations[idle_animation_state].frames)]
    local move_frame_x = last_frame.x * TILE_SIZE
    local move_frame_y = last_frame.y * TILE_SIZE

    if player.moving then
        draw_scaled_tile(player.x / TILE_SIZE, player.y / TILE_SIZE, move_frame_x, move_frame_y, offset_x, offset_y, player.flip_x, sprite_size)
    else
        draw_scaled_tile(player.x / TILE_SIZE, player.y / TILE_SIZE, source_x, source_y, offset_x, offset_y, player.flip_x, sprite_size)
    end
end

return player