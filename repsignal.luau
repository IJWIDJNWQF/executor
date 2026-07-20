-- replicatesignal replacement that actually works
-- resolves RemoteEvent from signal/instance/name then fires legitimately

local function resolve_event(input)
    if typeof(input) == "Instance" and (input:IsA("RemoteEvent") or input:IsA("RemoteFunction") or input:IsA("UnvalidatedRemoteEvent")) then
        return input
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
        local rs = game:GetService("ReplicatedStorage")
        local rf = game:GetService("ReplicatedFirst")
        for _, svc in ipairs({rs, rf}) do
            local found = svc:FindFirstChild(input)
            if found and (found:IsA("RemoteEvent") or found:IsA("RemoteFunction") or found:IsA("UnvalidatedRemoteEvent")) then
                return found
            end
            for _, desc in ipairs(svc:GetDescendants()) do
                if desc.Name == input and (desc:IsA("RemoteEvent") or desc:IsA("RemoteFunction") or desc:IsA("UnvalidatedRemoteEvent")) then
                    return desc
                end
            end
        end
    end

    return nil
end

local function replicatesignal(sig, ...)
    local event = resolve_event(sig)
    if not event then
        return false, "repsignal: could not resolve event"
    end

    local args = {...}
    local success, err = pcall(function()
        if event:IsA("RemoteEvent") or event:IsA("UnvalidatedRemoteEvent") then
            event:FireServer(unpack(args))
        elseif event:IsA("RemoteFunction") then
            event:InvokeServer(unpack(args))
        else
            error("repsignal: unsupported type " .. event.ClassName)
        end
    end)

    if not success then
        return false, err
    end
    return true
end

getgenv().replicatesignal = replicatesignal
getgenv().fire_replicate = replicatesignal

return replicatesignal
