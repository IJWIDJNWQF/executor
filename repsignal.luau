-- repsignal.luau
-- replicatesignal replacement with retry + timeout handling

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local function wait_for_child(parent, name, timeout)
    timeout = timeout or 8
    local start = tick()
    local child = parent:FindFirstChild(name)
    while not child and (tick() - start) < timeout do
        child = parent:FindFirstChild(name)
        if child then break end
        RunService.Heartbeat:Wait()
    end
    return child
end

local function resolve_event(input)
    if typeof(input) == "Instance" then
        if input:IsA("RemoteEvent") or input:IsA("RemoteFunction") or input:IsA("UnvalidatedRemoteEvent") then
            return input
        end
        return nil
    end

    if typeof(input) == "userdata" then
        local mt = debug.getmetatable(input)
        if mt then
            local obj = mt.__object or mt._OBJECT or mt.instance
            if obj and typeof(obj) == "Instance" then
                return obj
            end
        end

        if getinstance then
            local obj = getinstance(input)
            if obj and typeof(obj) == "Instance" then
                return obj
            end
        end

        local obj = rawget(input, "__object") or rawget(input, "Instance") or rawget(input, "instance")
        if obj and typeof(obj) == "Instance" then
            return obj
        end
    end

    if type(input) == "string" then
        local found = wait_for_child(ReplicatedStorage, input, 8)
        if not found then
            found = wait_for_child(ReplicatedFirst, input, 8)
        end
        if found and (found:IsA("RemoteEvent") or found:IsA("RemoteFunction") or found:IsA("UnvalidatedRemoteEvent")) then
            return found
        end
    end

    return nil
end

local function safe_fire(event, args)
    if event:IsA("RemoteEvent") or event:IsA("UnvalidatedRemoteEvent") then
        event:FireServer(unpack(args))
    elseif event:IsA("RemoteFunction") then
        event:InvokeServer(unpack(args))
    else
        error("repsignal: unsupported type " .. event.ClassName)
    end
end

local function try_fire(event, args, retries)
    retries = retries or 5
    for i = 1, retries do
        local success, err = pcall(function()
            safe_fire(event, args)
        end)
        if success then
            return true
        end
        if i < retries then
            RunService.Heartbeat:Wait()
        end
    end
    return false
end

local function replicatesignal(sig, ...)
    local event = resolve_event(sig)
    if not event then
        return false, "repsignal: could not resolve event"
    end

    local args = {...}
    local success = try_fire(event, args, 5)

    if not success then
        return false, "repsignal: failed to fire after retries"
    end
    return true
end

getgenv().replicatesignal = replicatesignal
getgenv().fire_replicate = replicatesignal

return replicatesignal
