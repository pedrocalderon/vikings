
require 'lux.object'
require 'vec2'
require 'map'

avatar = lux.object.new {
  pos       = nil,
  spd       = nil,
  sprite    = nil,
  frame     = nil,

  direction = 'right',
  attacking = false
}

avatar.__init = {
  pos       = vec2:new{ 0, 0 },
  spd       = vec2:new{ 0, 0 },
  frame     = { i=1, j=1 },
  equipment = {},
  tasks     = {},
  drawtasks = {},

  jumpsleft = 0,
  frametime = 0
}

local gravity   = vec2:new{  0,  30 }
local maxspd    = vec2:new{ 30,  30 }
local jumpspd   = -12
local min_equipment_slot = 1
local max_equipment_slot = 1
local dir_map   = {
  left = 2, right = 4
}

local function pos_to_tile (point)
  return map.get_tile(math.floor(point.y), math.floor(point.x))
end

function avatar:colliding (position)
  for _,p in ipairs(self.sprite.collpts) do
    local tile = pos_to_tile(position-(self.sprite.hotspot-p)/32)
    if not tile or tile.floor then
      return true
    end
  end
  return false
end

function avatar:update_physics (dt)
  -- no, negative speed doesn't increase forever
  self.spd.x = math.min(math.max(-maxspd.x, self.spd.x), maxspd.x)
  self.spd.y = math.min(math.max(-maxspd.y, self.spd.y), maxspd.y)
  if self:colliding(self.pos) then
    error "Ooops, youre inside a wall"
  end
  self.pos:add(self.spd*dt)
  if self:colliding(self.pos) then
    local horizontal  = -vec2:new{self.spd.x*dt,0}
    local vertical    = -vec2:new{0,self.spd.y*dt}
    local hor_check   = self:colliding(self.pos+horizontal)
    local ver_check   = self:colliding(self.pos+vertical)
    if not (hor_check and not ver_check) then
      self.pos.x = self.pos.x - self.spd.x*dt
    end
    if (hor_check and not ver_check) or
       (hor_check and ver_check) then
      self.pos.y = self.pos.y - self.spd.y*dt
      if self.spd.y > 0 then
        self.jumpsleft = 2
      end
      self.spd.y = 0
    end
  end
  self.spd:add(gravity * dt)
end

function avatar:update_animation (dt)
  self.frame.i = dir_map[self.direction] + (self.attacking and 4 or 0)
  local moving = self.spd.x ~= 0
  if not moving and not self.attacking then
    self.frame.j = 1
    return
  end
  if self.attacking then
    self:animate_attack(dt)
  else
    self:animate_movement(dt)
  end
end

function avatar:animate_movement (dt)
  self.frametime = self.frametime + dt
  while self.frametime >= 1/self.sprite.animfps do
    self.frame.j = self.frame.j % (#self.sprite.quads[self.frame.i]) + 1
    if self.frame.j == 1 then self.frame.j = 2 end
    self.frametime = self.frametime - 1/self.sprite.animfps
  end
end

function avatar:animate_attack (dt)
  self.frametime = self.frametime + dt
  while self.frametime >= 1/self.sprite.animfps do
    if self.frame.j > 6 then
      self.attacking = false
      self.frame.j = 1
    end
    self.frame.j = self.frame.j + 1
    self.frametime = self.frametime - 1/self.sprite.animfps
  end
end

function avatar:update (dt)
  self:update_physics(dt)
  self:update_animation(dt)
  for _, task in pairs(self.tasks) do
    task(self, dt)
  end
end

function avatar:jump ()
  if self.jumpsleft > 0 then
    self.jumpsleft = self.jumpsleft - 1
    self.spd.y = jumpspd
  end
end

function avatar:attack ()
  self.attacking = true
end

function avatar:equip(slot, item)
  if slot >= min_equipment_slot and slot <= max_equipment_slot then
    self.equipment[slot] = item
  end
end

function avatar:accelerate (dv)
  self.spd:add(dv)
  if self.spd.x > 0 then
    self.direction = 'right'
  elseif self.spd.x < 0 then
    self.direction = 'left'
  end
end

function avatar:draw (graphics)
  if self.equipment[1] then graphics.setColor(255,   0,   0) end
  self.sprite:draw(graphics, self.frame, self.pos)
  if self.equipment[1] then graphics.setColor(255, 255, 255) end
  for _, task in pairs(self.drawtasks) do
    task(self, graphics)
  end
end
