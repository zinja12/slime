-- particles.lua

local particles = {}
local TILE_SIZE = 8

function particles.init()
  particles.list = {}
end

function particles.spawn(px, py, source_x, source_y, life, tile_coords)
  local x = px
  local y = py
  if tile_coords then
    x *= TILE_SIZE
    y *= TILE_SIZE
  end
  table.insert(particles.list, {
    x = x,
    y = y,
    source_x = source_x,
    source_y = source_y,
    life = life
  })
end

function particles.update()
  for i = #particles.list, 1, -1 do
    local p = particles.list[i]

    p.life -= 1

    --life calc
    if p.life <= 0 then
      table.remove(particles.list, i)
    end
  end
end

function particles.draw()
  for i = 1, #particles.list do
    local p = particles.list[i]
    --calculate source to draw
    local source_x = (p.source_x) * TILE_SIZE
    local source_y = (p.source_y) * TILE_SIZE
    --calculate screen position
    local screen_x = (p.x * State.resolution_scale) - State.cam_x
    local screen_y = (p.y * State.resolution_scale) - State.cam_y

    gfx.sspr_ex(
        source_x, source_y, TILE_SIZE, TILE_SIZE,
        screen_x, screen_y, TILE_SIZE * State.resolution_scale, TILE_SIZE * State.resolution_scale,
        false, false, 0, gfx.COLOR_TRUE_WHITE, 1.0)
  end
end

return particles