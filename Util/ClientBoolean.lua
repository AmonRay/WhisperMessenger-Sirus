local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- A client boolean as a Lua boolean. 3.3.5a answers its "is this held / is this
-- click modified" questions with 1 and nil, not true and false, so comparing
-- against true made a held Shift look released and every shift-click there did
-- nothing. 0 counts as off: in Lua it is truthy, but it is not the client
-- saying yes.
local ClientBoolean = {}

function ClientBoolean.IsTrue(value)
  return value == true or (type(value) == "number" and value ~= 0)
end

ns.ClientBoolean = ClientBoolean
return ClientBoolean
