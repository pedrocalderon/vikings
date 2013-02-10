
require 'thing'
require 'vec2'
require 'hitbox'
require 'message'
require 'sound'

avatar = thing:new {
  slashspr  = nil,
  life      = 200,
  dmg_delay = 0,

  attacking = false
}

function avatar:__init() 
  self.equipment = {}
  self.hitboxes.helpful.class = "avatar"
  self.hitboxes.attack = hitbox:new {
    owner       = self,
    targetclass = 'damageable',
    on_collision = function (self, collisions)
      for _,another in ipairs(collisions) do
        if another.owner then
          another.owner:take_damage(
            5,
            (self.owner.pos-another.owner.pos):normalized()
          )
        else
          another:unregister()
        end
      end
    end,
    update = function (self, avatar, dt)
      self.pos = avatar.pos+vec2:new{(avatar.direction=='right' and 0.75 or -1.75), -.5}
    end
  }

  self.airjumpsleft = 0
end

local JUMPSPDY   = -14
local min_equipment_slot = 1
local max_equipment_slot = 1

function avatar:update_animation (dt)
  self.frame.i =
    self.sprite:frame_from_direction(self.direction)
    +
    (self.attacking and 4 or 0)
  local moving = self.accelerated
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
    self.hitboxes.attack:register 'playeratk'
  end
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
  self.dmg_delay = math.max(self.dmg_delay - dt, 0)
  avatar:__super().update(self, dt, map)
end

function avatar:jump ()
  if self.airjumpsleft > 0 or self.air == 0 then
    if self.air > 0 then
      self.airjumpsleft = self.airjumpsleft - 1
    end
    self.spd.y = JUMPSPDY
    sound.effect 'jump'
  end
end

function avatar:accelerate (dv)
  if not self.attacking then
    avatar:__super().accelerate(self, dv)
  end
end

function avatar:attack ()
  if not self.attacking and self.equipment[1] then
    sound.effect 'slash'
    self.attacking = true
    self.frametime = 0
    self.frame.j = 1
    self.atkhitbox.pos = self:get_atkhitboxpos()
    self:shove(vec2:new{3, 0}*(self.direction=='right' and 1 or -1))
  end
end

function avatar:stopattack ()
  if self.attacking then
    self.attacking = false
    self.frame.j = 1
    self.hitboxes.attack:unregister()
  end
end

function avatar:equip(slot, item)
  if slot >= min_equipment_slot and slot <= max_equipment_slot then
    self.equipment[slot] = item
  end
end

function avatar:take_damage (amount, dir)
  if self.dmg_delay > 0 then return end
  self.life = math.max(self.life - amount, 0)
  self.dmg_delay = 0.5
  sound.effect 'hit'
  if dir then
    self:shove(amount*(vec2:new{0,-1}-dir):normalized())
  end
  if self.life <= 0 then
    message.send 'game' {'kill', self}
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
