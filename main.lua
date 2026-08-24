local world = require("world")
local player = require("player")
local particles = require("particles")

local tile = 8
local res_width = 240
local res_height = 176
local res_scale = 2

function _config()
  return {
    name = "SlimeGame", game_id = "com.usagiengine.slime", game_width = res_width, game_height = res_height }
end

function _init()
  -- Live reload preserves globals across saved edits but resets locals.
  -- Stash mutable game state in a capitalized global like `State` so it
  -- survives reloads; F5 calls _init again to reset.
  State = {
    resolution_scale = res_scale,
    cam_x = 0,
    cam_y = 0,
    is_transitioning = false,
    target_cam_x = 0,
    target_cam_y = 0
  }

  world.init()
  player.init()
  particles.init()
end

function _update(dt)
  world.update()
  player.update()
  particles.update()
end

function draw_scaled_tile(x, y, source_x, source_y, world_offset_x, world_offet_y, flip_x, sprite_size)
  local grid_spacing = tile * res_scale
  local screen_x = (x * grid_spacing) + (world_offset_x or 0) - State.cam_x
  local screen_y = (y * grid_spacing) + (world_offset_y or 0) - State.cam_y

  --set spritesheet dimensions
  local source_w = sprite_size or tile
  local source_h = sprite_size or tile

  --drawn dimensions
  local destination_w = source_w * res_scale
  local destination_h = source_h * res_scale

  --bounds check
  if screen_x + destination_w < 0 or screen_x > res_width then
    return
  end
  if screen_y + destination_h < 0 or screen_y > res_height then
    return
  end

  gfx.sspr_ex(source_x, source_y, source_w, source_h,
    screen_x, screen_y, destination_w, destination_h,
    flip_x or false, false, 0, gfx.COLOR_TRUE_WHITE, 1.0)
end

function _draw(dt)
  gfx.clear(gfx.COLOR_BLACK)
  world.draw()
  player.draw()
  particles.draw()
end
