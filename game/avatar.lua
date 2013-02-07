
require 'lux.object'
require 'thing'
require 'vec2'
require 'hitbox'
require 'message'

avatar = thing:new {
  slashspr  = nil,

  attacking = false
}

function avatar:__init() 
  self.equipment = {}
  self.hitbox.class = "avatar"
  self.atkhitbox = hitbox:new {
    targetclass = 'damageable',
    on_collision = function (self, collisions)
      for _,another in ipairs(collisions) do
        if another.owner then
          message.send 'game' {'kill', another.owner}
        else
          another:unregister()
        end
      end
    end
  }

  self.jumpsleft = 0
end

local jumpspd   = -12
local min_equipment_slot = 1
local max_equipment_slot = 1
local dir_map   = {
  left = 2, right = 4
}

function avatar:die ()
  self.hitbox:unregister()
  self.atkhitbox:unregister()
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

function avatar:animate_attack (dt)
  self.frametime = self.frametime + dt
  while self.frametime >= 1/self.sprite.animfps do
    if self.frame.j > 6 then
      self:stopattack()
    else
      self.frame.j = self.frame.j + 1
      self.frametime = self.frametime - 1/self.sprite.animfps
    end
  end
  if self.frame.j > 6 then
    self:stopattack()
  end
  if self.attacking and self.frame.j >= 5 then
    self.atkhitbox:register 'playeratk'
  end
end

function avatar:get_atkhitboxpos ()
  return self.pos+vec2:new{(self.direction=='right' and 0.75 or -1.75), -.5}
end

function avatar:get_atkpos ()
  local tilesize = map.get_tilesize()
  return
    self.pos +
    vec2:new{
      (self.direction=='right' and 1 or -1)*0.75,
      -4/tilesize
    }
end

function avatar:update (dt, map)
  self:update_physics(dt, map)
  self:update_animation(dt)
  self:update_hitbox(dt)
  if self.atkhitbox then
    self.atkhitbox.pos = self:get_atkhitboxpos()
  end
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
  if not self.attacking then
    self.attacking = true
    self.frametime = 0
    self.frame.j = 1
    self.atkhitbox.pos = self:get_atkhitboxpos()
    --self.atkhitbox:register 'playeratk'
  end
end

function avatar:stopattack ()
  if self.attacking then
    self.attacking = false
    self.frame.j = 1
    self.atkhitbox:unregister()
  end
end

function avatar:equip(slot, item)
  if slot >= min_equipment_slot and slot <= max_equipment_slot then
    self.equipment[slot] = item
  end
end

function avatar:draw (graphics)
  if self.equipment[1] then graphics.setColor(255,   0,   0) end
  self.sprite:draw(graphics, self.frame, self.pos)
  if self.equipment[1] then graphics.setColor(255, 255, 255) end
  if self.slashspr and self.attacking and self.frame.j >= 4 then
    self.slashspr:draw(
      graphics,
      {i=self.frame.j-3, j=1},
      self:get_atkpos(),
      self.direction=='right' and 'h' or nil
    )
  end
  for _, task in pairs(self.drawtasks) do
    task(self, graphics)
  end
end
