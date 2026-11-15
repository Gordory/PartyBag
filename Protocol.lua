-- Pure encode/decode of the wire format, kept free of WoW API calls so it can be unit-tested outside the client.
--
-- Messages:
--   R;<ver>                                   ask every group member to (re)send its snapshot
--   S;<ver>;<seq>;<idx>;<total>;<id:n,id:n>   one chunk of a full bag snapshot
local _, ns = ...

local Protocol = {}
ns.Protocol = Protocol

Protocol.VERSION = 1

-- SendAddonMessage hard-caps at 255 bytes; the rest is headroom for the header.
local MAX_PAYLOAD = 200

function Protocol.Serialize(counts)
    local ids = {}
    for id in pairs(counts) do
        ids[#ids + 1] = id
    end
    -- Stable order lets the sender compare snapshots as strings and skip unchanged broadcasts.
    table.sort(ids)
    local tokens = {}
    for i, id in ipairs(ids) do
        tokens[i] = id .. ":" .. counts[id]
    end
    return tokens
end

function Protocol.BuildSnapshot(tokens, seq)
    local chunks, current, length = {}, {}, 0
    for _, token in ipairs(tokens) do
        if #current > 0 and length + #token + 1 > MAX_PAYLOAD then
            chunks[#chunks + 1] = table.concat(current, ",")
            current, length = {}, 0
        end
        current[#current + 1] = token
        length = length + #token + 1
    end
    -- Always emit at least one chunk: empty bags must still clear stale data on receivers.
    chunks[#chunks + 1] = table.concat(current, ",")

    local messages = {}
    for i, chunk in ipairs(chunks) do
        messages[i] = string.format("S;%d;%d;%d;%d;%s", Protocol.VERSION, seq, i, #chunks, chunk)
    end
    return messages
end

function Protocol.BuildRequest()
    return "R;" .. Protocol.VERSION
end

function Protocol.Parse(message)
    local kind, version, rest = message:match("^(%a);(%d+);?(.*)$")
    -- Incompatible versions are dropped silently rather than misread.
    if not kind or tonumber(version) ~= Protocol.VERSION then
        return nil
    end
    if kind == "R" then
        return { kind = "R" }
    end
    if kind == "S" then
        local seq, idx, total, payload = rest:match("^(%d+);(%d+);(%d+);(.*)$")
        if not seq then
            return nil
        end
        return { kind = "S", seq = tonumber(seq), idx = tonumber(idx), total = tonumber(total), payload = payload }
    end
    return nil
end

function Protocol.DecodePayload(payload, into)
    for id, count in payload:gmatch("(%d+):(%d+)") do
        id = tonumber(id)
        into[id] = (into[id] or 0) + tonumber(count)
    end
    return into
end
