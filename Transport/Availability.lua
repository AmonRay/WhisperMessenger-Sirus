local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Types = ns.TransportTypes or require("WhisperMessenger.Transport.Types")
local Availability = {}

function Availability.FromStatus(status)
  return {
    status = status,
    canWhisper = Types.WHISPERABLE[status] == true,
  }
end

-- A whisper that went through proves the player was online at that moment,
-- not that they still are. The game's own whisper check takes over after
-- this window; clients without it (3.3.5a) fall back to the roster and the
-- friends list instead of pinning the contact online forever.
Availability.PROOF_SECONDS = 5 * 60

function Availability.IsStaleProof(availability, now)
  if type(availability) ~= "table" or availability.confirmedByWhisper ~= true then
    return false
  end
  if type(availability.confirmedAt) ~= "number" or type(now) ~= "number" then
    return false
  end
  return now - availability.confirmedAt >= Availability.PROOF_SECONDS
end

ns.Availability = Availability

return Availability
