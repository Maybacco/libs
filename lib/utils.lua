local debug = false

-- side detection
SERVER = IsDuplicityVersion()
CLIENT = not SERVER

-- print("============IS_SERVER:"..tostring(SERVER))
-- print("============IS_CLIENT:"..tostring(CLIENT))


Keys = {
  ["ESC"] = 322, ["F1"] = 288, ["F2"] = 289, ["F3"] = 170, ["F5"] = 166, ["F6"] = 167, ["F7"] = 168, ["F8"] = 169, ["F9"] = 56, ["F10"] = 57,
  ["~"] = 243, ["1"] = 157, ["2"] = 158, ["3"] = 160, ["4"] = 164, ["5"] = 165, ["6"] = 159, ["7"] = 161, ["8"] = 162, ["9"] = 163, ["-"] = 84, ["="] = 83, ["BACKSPACE"] = 177,
  ["TAB"] = 37, ["Q"] = 44, ["W"] = 32, ["E"] = 38, ["R"] = 45, ["T"] = 245, ["Y"] = 246, ["U"] = 303, ["P"] = 199, ["["] = 39, ["]"] = 40, ["ENTER"] = 18,
  ["CAPS"] = 137, ["A"] = 34, ["S"] = 8, ["D"] = 9, ["F"] = 23, ["G"] = 47, ["H"] = 74, ["K"] = 311, ["L"] = 182,
  ["LEFTSHIFT"] = 21, ["Z"] = 20, ["X"] = 73, ["C"] = 26, ["V"] = 0, ["B"] = 29, ["N"] = 249, ["M"] = 244, [","] = 82, ["."] = 81,
  ["LEFTCTRL"] = 36, ["LEFTALT"] = 19, ["SPACE"] = 22, ["RIGHTCTRL"] = 70,
  ["HOME"] = 213, ["PAGEUP"] = 10, ["PAGEDOWN"] = 11, ["DELETE"] = 178,
  ["LEFT"] = 174, ["RIGHT"] = 175, ["TOP"] = 27, ["DOWN"] = 173,
  ["NENTER"] = 201, ["N4"] = 108, ["N5"] = 60, ["N6"] = 107, ["N+"] = 96, ["N-"] = 97, ["N7"] = 117, ["N8"] = 61, ["N9"] = 118
}

function round(val, decimal)
  if (decimal) then
    return math.floor( (val * 10^decimal) + 0.5) / (10^decimal)
  else
    return math.floor(val+0.5)
  end
end

Utils = {}
Utils.Table = {}
Utils.Table.Duplicate = function (obj, seen)
  if type(obj) ~= 'table' then return obj end
  if seen and seen[obj] then return seen[obj] end
  local s = seen or {}
  local res = setmetatable({}, getmetatable(obj))
  s[obj] = res
  for k, v in pairs(obj) do res[Utils.Table.Duplicate(k, s)] = Utils.Table.Duplicate(v, s) end
  return res
end

Utils.Math = {}
Utils.Math.Trim = function(value)
	if value then
		return (string.gsub(value, "^%s*(.-)%s*$", "%1"))
	else
		return nil
	end
end
Utils.Math.Round = round

Utils.Text3D = {}
Utils.Text3D.Draw = function(x, y, z, text, scale)
  SetTextScale(0.325, 0.325)
  SetTextFont(4)
  SetTextProportional(1)
  SetTextColour(255, 255, 255, 215)
  SetTextEntry("STRING")
  SetTextCentre(true)
  AddTextComponentString(text)
  SetDrawOrigin(x,y,z, 0)
  DrawText(0.0, 0.0)
  local factor = (string.len(text)) / 370
  DrawRect(0.0, 0.0+0.0125, 0.017+ factor, 0.03, 0, 0, 0, 68)
  ClearDrawOrigin()
end

-- table.maxn replacement
function table_maxn(t)
  local max = 0
  for k,v in pairs(t) do
    local n = tonumber(k)
    if n and n > max then max = n end
  end

  return max
end

local modules = {}
function module(rsc, path) -- load a LUA resource file as module
  if path == nil then -- shortcut for vrp, can omit the resource parameter
    path = rsc
    rsc = "libs"
  end

  local key = rsc..path

  if modules[key] then -- cached module
    return table.unpack(modules[key])
  else
    -- print(rsc)
    -- print(path..".lua")
    local f,err = load(LoadResourceFile(rsc, path..".lua"))
    if f then
      local ar = {pcall(f)}
      if ar[1] then
        table.remove(ar,1)
        modules[key] = ar
        return table.unpack(ar)
      else
        modules[key] = nil
        print("[vRP] error loading module "..rsc.."/"..path..":"..ar[2])
      end
    else
      print("[vRP] error parsing module "..rsc.."/"..path..":"..err)
    end
  end
end

-- generate a task metatable (helper to return delayed values with timeout)
--- dparams: default params in case of timeout or empty cbr()
--- timeout: milliseconds, default 5000
function Task(callback, dparams, timeout) 
  if timeout == nil then timeout = 5000 end

  local r = {}
  r.done = false

  local finish = function(params) 
    if not r.done then
      if params == nil then params = dparams or {} end
      r.done = true
      callback(table.unpack(params))
    end
  end

  setmetatable(r, {__call = function(t,params) finish(params) end })
  SetTimeout(timeout, function() finish(dparams) end)

  return r
end

-- Luaoop class

local Luaoop = module("libs", "lib/Luaoop")
class = Luaoop.class

-- Luaseq like for FiveM

local function wait(self)
  local rets = Citizen.Await(self.p)
  if not rets then
    if self.r then
      rets = self.r
    else
      error("async wait(): Citizen.Await returned (nil) before the areturn call.")
    end
  end

  return table.unpack(rets, 1, table_maxn(rets))
end

local function areturn(self, ...)
  self.r = {...}
  self.p:resolve(self.r)
end

-- create an async returner or a thread (Citizen.CreateThreadNow)
-- func: if passed, will create a thread, otherwise will return an async returner
function async(func)
  if func then
    Citizen.CreateThreadNow(func)
  else
    return setmetatable({ wait = wait, p = promise.new() }, { __call = areturn })
  end
end

local function hex_conv(c)
  return string.format('%02X', string.byte(c))
end

-- convert Lua string to hexadecimal
function tohex(str)
  return string.gsub(str, '.', hex_conv)
end

-- basic deep clone function (doesn't handle circular references)
function clone(t)
  if type(t) == "table" then
    local new = {}
    for k,v in pairs(t) do
      new[k] = clone(v)
    end

    return new
  else
    return t
  end
end

function parseInt(v)
--  return cast(int,tonumber(v))
  local n = tonumber(v)
  if n == nil then 
    return 0
  else
    return math.floor(n)
  end
end

function parseDouble(v)
--  return cast(double,tonumber(v))
  local n = tonumber(v)
  if n == nil then n = 0 end
  return n
end

function parseFloat(v)
  return parseDouble(v)
end

-- will remove chars not allowed/disabled by strchars
-- if allow_policy is true, will allow all strchars, if false, will allow everything except the strchars
local sanitize_tmp = {}
function sanitizeString(str, strchars, allow_policy)
  local r = ""

  -- get/prepare index table
  local chars = sanitize_tmp[strchars]
  if chars == nil then
    chars = {}
    local size = string.len(strchars)
    for i=1,size do
      local char = string.sub(strchars,i,i)
      chars[char] = true
    end

    sanitize_tmp[strchars] = chars
  end

  -- sanitize
  size = string.len(str)
  for i=1,size do
    local char = string.sub(str,i,i)
    if (allow_policy and chars[char]) or (not allow_policy and not chars[char]) then
      r = r..char
    end
  end

  return r
end


-- function split(str, sep)
--   local array = {}
--   local reg = string.format("([^%s]+)", sep)
--   for mem in string.gmatch(str, reg) do
--       table.insert(array, mem)
--   end
--   return array
-- end

function splitString(str, sep)
  if sep == nil then sep = "%s" end

  local t={}
  local i=1

  for str in string.gmatch(str, "([^"..sep.."]+)") do
    t[i] = str
    i = i + 1
  end

  return t
end

function joinStrings(list, sep)
  if sep == nil then sep = "" end

  local str = ""
  local count = 0
  local size = #list
  for k,v in pairs(list) do
    count = count+1
    str = str..v
    if count < size then str = str..sep end
  end

  return str
end

function comma_value(amount)
  local formatted = amount
  while true do  
    formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
    if (k==0) then
      break
    end
  end
  return formatted
end


function format_num(amount, decimal, prefix, neg_prefix)
  local str_amount,  formatted, famount, remain

  decimal = decimal or 2  -- default 2 decimal places
  neg_prefix = neg_prefix or "-" -- default negative sign

  famount = math.abs(round(amount,decimal))
  famount = math.floor(famount)

  remain = round(math.abs(amount) - famount, decimal)

        -- comma to separate the thousands
  formatted = comma_value(famount)

        -- attach the decimal portion
  if (decimal > 0) then
    remain = string.sub(tostring(remain),3)
    formatted = formatted .. "." .. remain ..
    string.rep("0", decimal - string.len(remain))
  end

  formatted = (prefix or "") .. formatted 

  if (amount<0) then
    if (neg_prefix=="()") then
      formatted = "("..formatted ..")"
    else
      formatted = neg_prefix .. formatted 
    end
  end

  return formatted
end

function DumpTable(table, nb)
	if nb == nil then
		nb = 0
	end

	if type(table) == 'table' then
		local s = ''
		for i = 1, nb + 1, 1 do
			s = s .. "    "
		end

		s = '{\n'
		for k,v in pairs(table) do
			if type(k) ~= 'number' then k = '"'..k..'"' end
			for i = 1, nb, 1 do
				s = s .. "    "
			end
			s = s .. '['..k..'] = ' .. DumpTable(v, nb + 1) .. ',\n'
		end

		for i = 1, nb, 1 do
			s = s .. "    "
		end

		return s .. '}'
	else
		return tostring(table)
	end
end


function toPositive(n)
  if n < 0 then
    return n * -1
  end
  return n
end

function roundToClosestInt(n,mult)
    local a = math.floor(n / mult) * mult
    local b = a + mult
    if n - a > b - n then
      return b
    else
      return a
    end
end

function RotationToDirection(rotation)
	local adjustedRotation = 
	{ 
		x = (math.pi / 180) * rotation.x, 
		y = (math.pi / 180) * rotation.y, 
		z = (math.pi / 180) * rotation.z 
	}
	local direction = 
	vector3(
		-math.sin(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)), 
		math.cos(adjustedRotation.z) * math.abs(math.cos(adjustedRotation.x)), 
		math.sin(adjustedRotation.x)
  )
	return direction
end

function genCoordId(coords)
  local x = "%0"
  local y = "%0"
  local z = "%0"
  if coords.x < 0 then
    x = "%1"
  end
  x = x .. tostring(roundToClosestInt(parseInt(toPositive(coords.x)),2)) -- round coord to multiplier 5 to prevent spam of bag on the same position
  if coords.y < 0 then
    y = "%1"
  end
  y = y .. tostring(roundToClosestInt(parseInt(toPositive(coords.y)),2))
  if coords.z < 0 then
    z = "%1"
  end
  z = z .. tostring(roundToClosestInt(parseInt(toPositive(coords.z)),2))

	return  x .. y .. z
end

function drawDebugLine(DebugPoint1,DebugPoint2)
  Citizen.CreateThread(function()
      print("draw line")
      print(DebugPoint1.x .." ".. DebugPoint1.y .." ".. DebugPoint1.z .." ".. DebugPoint2.x .." ".. DebugPoint2.y .." ".. DebugPoint2.z)
      for i=0,5000,1 do 
          Citizen.Wait(1)
          DrawLine(DebugPoint1, DebugPoint2,255,0,0,255);
      end
      --TerminateThisThread()
  end)
end

function GetEntityInFrontOfEntity (distance, entity, flag)
  if flag == nil then
      flag = -1
  end
  local p1 = GetEntityCoords(entity, 1)
  local p2 = GetOffsetFromEntityInWorldCoords(entity, 0.0, distance, 0.0)
  local DebugPoint1 = p1
  local DebugPoint2 = p2
  local RayHandle = CastRayPointToPoint(p1, p2, flag, entity, 0)
  local A,B,C,D,Ent = GetRaycastResult(RayHandle)
  if debug then
      drawDebugLine(DebugPoint1,DebugPoint2)
  end
  return Ent
end

function ensureCollisionUnderEntity(distance,entity)
  print("ensureCollisionUnderEntity")
  local p1 = GetEntityCoords(entity, 1)
  local p2 = GetOffsetFromEntityInWorldCoords(entity, 0.0, 0.0, -distance)
  local DebugPoint1 = p1
  local DebugPoint2 = p2
  local RayHandle = CastRayPointToPoint(p1, p2, -1, entity, 0)
  local A,B,C,D,Ent = GetRaycastResult(RayHandle)
  if debug then
    drawDebugLine(DebugPoint1,DebugPoint2)
  end
  return B --b hit something
end

function GetEntityByCamRotation (distance, entity, flag)
  print("GetEntityByCamRotation")
  if flag == nil then
      flag = -1
  end
  local entityCoord = GetEntityCoords(entity, 1)
  entityCoord = vector3(entityCoord.x,entityCoord.y,entityCoord.z + 0.7)
  local cameraCoord = GetGameplayCamCoord()
  local cameraRotation = GetGameplayCamRot()  
  local direction = RotationToDirection(cameraRotation) 
  distance = distance + GetDistanceBetweenCoords(entityCoord,cameraCoord,true)
  -- local p1 = vector3(entityCoord.x,entityCoord.y,entityCoord.z + 0.7 )
  local ax = cameraCoord.x - entityCoord.x
  local ay = cameraCoord.y - entityCoord.y
  local az = cameraCoord.z - (entityCoord.z)
  local p1 = entityCoord
  local p2 = vector3(p1.x + ax + direction.x * distance,p1.y  + ay + direction.y * distance,p1.z + az + direction.z * distance) 
  local DebugPoint1 = p1
  local DebugPoint2 = p2
  local RayHandle = CastRayPointToPoint(p1, p2, flag, entity, 0)
  local A,B,C,D,Ent = GetRaycastResult(RayHandle)
  if debug then
      drawDebugLine(DebugPoint1,DebugPoint2)
  end
  if DoesEntityExist(Ent) then
    local nativeStatus,result = pcall(function() return GetEntityModel(Ent) end)
    if not nativeStatus then
      return GetEntityByCamRotation(distance, entity, 30)
    end
  --   print(Ent)
  --   print(GetEntityModel(Ent))
  --   print(GetEntityType(Ent))
  end
  return Ent
end

--TEST 1
-- function isControlPressedFor(inputGroup ,control, time, func_hold, func_tap)
--   local pressed = false
--   local gtime = GetGameTimer() 
--   local t = 0
--   local done = false
--   while true do
--     Citizen.Wait(1)
--     if (IsControlPressed(inputGroup, control)) then
--       if not pressed then
--         gtime = GetGameTimer()
--         pressed = true     
--       end
--       Citizen.Wait(200)
--       t = t + 200
--       if (not done and GetGameTimer() - gtime > time) then
--         print("CONTROL PRESSED FOR "..time)
--         print("CONTROL PRESSED FOR "..t)
--         done = true
--         func_hold()
--       end
--     else
--       if (not done and pressed and func_tap) then
--           print("KEY TAP")
--           func_tap()
--       end
--       done = false
--       pressed = false 
--       t=0       
--     end
--   end
-- end
--TEST 2
function isControlPressedFor(inputGroup ,control, time, func_hold, func_tap)
  local pressed = false
  local t = 0
  local done = false
  while true do
    Citizen.Wait(1)
    if (IsControlPressed(inputGroup, control)) then
      if not pressed then
        pressed = true     
      end
      Citizen.Wait(200)
      t = t + 200
      if (not done and t >= time) then
        print("KEY HOLD FOR "..t)
        done = true
        func_hold()
      end
    else
      if (not done and pressed and func_tap) then
          print("KEY TAP")
          func_tap()
      end
      done = false
      pressed = false 
      t=0       
    end
  end
end

--TEST 3
-- function isControlPressedFor(inputGroup ,control, time, cb)
--   while true do
--     Citizen.Wait(1)
--     if (IsControlPressed(inputGroup, control)) then
--       Citizen.Wait(time)
--       if (IsControlPressed(inputGroup, control)) then 
--         cb()
--       end       
--     end
--   end
-- end

function GetHeadBlendData(ped)
  return Citizen.InvokeNative(0x2746BD9D88C5C5D0, ped, Citizen.PointerValueIntInitialized(0), Citizen.PointerValueIntInitialized(0), Citizen.PointerValueIntInitialized(0), Citizen.PointerValueIntInitialized(0), Citizen.PointerValueIntInitialized(0), Citizen.PointerValueIntInitialized(0), Citizen.PointerValueFloatInitialized(0), Citizen.PointerValueFloatInitialized(0), Citizen.PointerValueFloatInitialized(0))
end

function SetPlayerLocallyVisible(ped)
  SetEntityVisible(ped, false, false)
  SetLocalPlayerVisibleLocally(true)
  Citizen.Wait(0)
  SetEntityVisible(ped, true, false)
  SetLocalPlayerVisibleLocally(true)
end

function ShowNotification(text)
  SetNotificationTextEntry("STRING")
  AddTextComponentString(text)
  DrawNotification(false, false)
end

function CheckExistenceOfVehInCoords(coords,max_distance)
  local handle, scannedveh = FindFirstVehicle()
  local success
  if max_distance == nil then
    max_distance = 1
  end

  repeat
      local pos = GetEntityCoords(scannedveh)
      local distance = GetDistanceBetweenCoords(coords, pos, true)
      if distance < max_distance then
        return true
      end
      success, scannedveh = FindNextVehicle(handle)
  until not success
  EndFindVehicle(handle)
  return false
end

function GetVehiclesInCoords(coords,max_distance)
  local handle, scannedveh = FindFirstVehicle()
  local success
  local vehicles = {}
  if max_distance == nil then
    max_distance = 1
  end

  repeat
      local pos = GetEntityCoords(scannedveh)
      local distance = Vdist(coords[1],coords[2],coords[3], pos[1], pos[2], pos[3])
      if distance < max_distance then
        vehicles[#vehicles+1] = scannedveh
      end
      success, scannedveh = FindNextVehicle(handle)
  until not success
  EndFindVehicle(handle)
  return vehicles
end

function CheckExistenceOfVehWithPlate(vehicle_plate,max_distance)
  local playerped = GetPlayerPed(-1)
  local playerCoords = GetEntityCoords(playerped)
  local handle, scannedveh = FindFirstVehicle()
  local success
  repeat
      if max_distance ~= nil and max_distance > 0 then
        local pos = GetEntityCoords(scannedveh)
        local distance = GetDistanceBetweenCoords(playerCoords, pos, true)
        if distance < max_distance then
          local checkplate = GetVehicleNumberPlateText(scannedveh)
          if checkplate == vehicle_plate then
            return true
          end
        end
      else
        local checkplate = GetVehicleNumberPlateText(scannedveh)
        if checkplate == vehicle_plate then
          return true
        end       
      end
      success, scannedveh = FindNextVehicle(handle)
  until not success
  EndFindVehicle(handle)
  return false
end

function GetEntityVehWithPlate(vehicle_plate,max_distance)
  local playerped = GetPlayerPed(-1)
  local playerCoords = GetEntityCoords(playerped)
  local handle, scannedveh = FindFirstVehicle()
  local success
  repeat
      if max_distance ~= nil and max_distance > 0 then
        local pos = GetEntityCoords(scannedveh)
        local distance = GetDistanceBetweenCoords(playerCoords, pos, true)
        if distance < max_distance then
          local checkplate = GetVehicleNumberPlateText(scannedveh)
          if checkplate == vehicle_plate then
            return scannedveh
          end
        end
      else
        local checkplate = GetVehicleNumberPlateText(scannedveh)
        if checkplate == vehicle_plate then
          return scannedveh
        end       
      end
      success, scannedveh = FindNextVehicle(handle)
  until not success
  EndFindVehicle(handle)
  return nil
end
function getVehicleModelName(v_entity)
  local model = GetEntityModel(v_entity)
  local displaytext = GetDisplayNameFromVehicleModel(model)
  return string.lower(GetLabelText(displaytext))
end

function drawTxt(text,font,centre,x,y,scale,r,g,b,a)
	SetTextFont(font)
	SetTextProportional(0)
	SetTextScale(scale, scale)
	SetTextColour(r, g, b, a)
	SetTextDropShadow(0, 0, 0, 0,255)
	SetTextEdge(1, 0, 0, 0, 255)
	SetTextDropShadow()
	SetTextOutline()
	SetTextCentre(centre)
	SetTextEntry("STRING")
	AddTextComponentString(text)
	DrawText(x , y)
end

function calculateDistanceBetweenCoords(pos1,pos2)
  return #(vector3(pos1.x,pos1.y, pos1.z) - vector3(pos2.x, pos2.y, pos2.z))
end


function arrayHasValue(array,value)
  for i,v in ipairs(array) do
      if array[i] == value then
          return true
      end
  end
  return false
end

Streaming = {}
function Streaming.RequestModel(modelHash, cb)
	modelHash = (type(modelHash) == 'number' and modelHash or GetHashKey(modelHash))

	if not HasModelLoaded(modelHash) and IsModelInCdimage(modelHash) then
		RequestModel(modelHash)

		while not HasModelLoaded(modelHash) do
			Citizen.Wait(1)
		end
	end

	if cb ~= nil then
		cb()
	end
end

function SpawnLocalObject(model, coords, cb)
  local model = (type(model) == 'number' and model or GetHashKey(model))

  Citizen.CreateThread(function()
    Streaming.RequestModel(model)
    local obj = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
    if cb then
      cb(obj)
    end
  end)
end

function DeleteLocalObject(object)
  DeleteObject(object)
end


function IsMpPed(ped)
	local CurrentModel = GetEntityModel(ped)
	if CurrentModel == `mp_m_freemode_01` then return "Male" elseif CurrentModel == `mp_f_freemode_01` then return "Female" else return false end
end
