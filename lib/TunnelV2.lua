-- this file describe a two way proxy between the server and the clients (request system)
local Debug = false
local IDManager = module("lib/IDManager")

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


-- API used in function of the side
local TriggerRemoteEvent = nil
local RegisterLocalEvent = nil
if SERVER then
  TriggerRemoteEvent = TriggerClientEvent
  RegisterLocalEvent = RegisterServerEvent
else
  TriggerRemoteEvent = TriggerServerEvent
  RegisterLocalEvent = RegisterNetEvent
end

local Tunnel = {}

-- define per dest regulator
Tunnel.delays = {}

-- set the base delay between Triggers for this destination in milliseconds (0 for instant trigger)
function Tunnel.setDestDelay(dest, delay)
  Tunnel.delays[dest] = {delay, 0}
end

local function tunnel_resolve(itable,key)
  local mtable = getmetatable(itable)
  local iname = mtable.name
  local ids = mtable.tunnel_ids
  local callbacks = mtable.tunnel_callbacks
  local identifier = mtable.identifier

  local fname = key
  local no_wait = false
  if string.sub(key,1,1) == "_" then
    fname = string.sub(key,2)
    no_wait = true
  end

  -- vRP 2
  local fcall = function(...)
    local args = {...}
    if (Debug) then
        print("===========================================fcall")
        if (SERVER) then
            print(os.date("%Y/%m/%d %X - " .. os.clock())) 
        end
        print(DumpTable(args))
    end

    local r = nil
    local profile -- debug

 
    local dest = nil
    if SERVER then
      dest = args[1]
      args = table.unpack(args, 2, table_maxn(args))
      if dest >= 0 and not no_wait then -- return values not supported for multiple dests (-1)
        r = async()
      end
    elseif not no_wait then
      r = async()
    end
    -- get delay data
    local delay_data = nil
    if dest then delay_data = Tunnel.delays[dest] end
    if delay_data == nil then
      delay_data = {0,0}
    end

    -- increase delay
    local add_delay = delay_data[1]
    delay_data[2] = delay_data[2]+add_delay

    if delay_data[2] > 0 then -- delay trigger
      SetTimeout(delay_data[2], function() 
        -- remove added delay
        delay_data[2] = delay_data[2]-add_delay

        -- send request
        local rid = -1
        if r then
          rid = ids:gen()
          callbacks[rid] = r
        end
        if SERVER then
          TriggerRemoteEvent(iname..":tunnel_req",dest,fname,args,identifier,rid)
        else
          TriggerRemoteEvent(iname..":tunnel_req",fname,args,identifier,rid)
        end
      end)
    else -- no delay
      -- send request
      local rid = -1
      if r then
        rid = ids:gen()
        callbacks[rid] = r
      end

      if SERVER then
        TriggerRemoteEvent(iname..":tunnel_req",dest,fname,args,identifier,rid)
      else
        TriggerRemoteEvent(iname..":tunnel_req",fname,args,identifier,rid)
      end
    end

    if r then
      return r:wait()
    end
  end

  itable[key] = fcall -- add generated call to table (optimization)
  return fcall
end

-- vRP 2
-- bind an interface (listen to net requests)
-- name: interface name
-- interface: table containing functions
function Tunnel.bindInterface(name,interface)
  -- receive request
  RegisterLocalEvent(name..":tunnel_req")
  AddEventHandler(name..":tunnel_req",function(member,args,identifier,rid)
    if (Debug) then
        print(name..":tunnel_req")
        if (SERVER) then
            print(os.date("%Y/%m/%d %X - " .. os.clock())) 
        end
        print(identifier)
        print(rid)
        print(source)
        print(DumpTable(args))
    end

    local source = source
    local f = interface[member]

    local rets = {}
    if type(f) == "function" then -- call bound function
        rets = {f(table.unpack(args, 1, table_maxn(args)))}
        if (Debug) then
            print("RETS FUNCTION RESULT")
            print(rets)
            print(DumpTable(args))
        end
        -- CancelEvent() -- cancel event doesn't seem to cancel the event for the other handlers, but if it does, uncomment this
    end

    -- send response (even if the function doesn't exist)
    if rid >= 0 then
      if SERVER then
        TriggerRemoteEvent(name..":"..identifier..":tunnel_res",source,rid,rets)
      else
        TriggerRemoteEvent(name..":"..identifier..":tunnel_res",rid,rets)
      end
    end
  end)
end

-- vRP2
-- get a tunnel interface to send requests 
-- name: interface name
-- identifier: (optional) unique string to identify this tunnel interface access; if nil, will be the name of the resource
function Tunnel.getInterface(name,identifier)
  if not identifier then identifier = GetCurrentResourceName() end
  
  local ids = IDManager()
  local callbacks = {}

  -- build interface
  local r = setmetatable({},{ __index = tunnel_resolve, name = name, tunnel_ids = ids, tunnel_callbacks = callbacks, identifier = identifier })

  -- receive response
  RegisterLocalEvent(name..":"..identifier..":tunnel_res")
  AddEventHandler(name..":"..identifier..":tunnel_res",function(rid,args)
    if (Debug) then
        print("======================"..name..":"..identifier..":tunnel_res START")
        if (SERVER) then
            print(os.date("%Y/%m/%d %X - " .. os.clock())) 
        end
    end
    local callback = callbacks[rid]
    if callback then
        if (Debug) then
            print("TUNNEL RESULT CALLBACK")
            print(rid)
            print(DumpTable(args))
        end     
        -- free request id
        ids:free(rid)
        callbacks[rid] = nil
        -- call
        callback(table.unpack(args, 1, table_maxn(args)))    
    end
  end)

  return r
end

return Tunnel
-- vRP2