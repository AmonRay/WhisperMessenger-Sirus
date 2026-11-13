-- A chat emoji is drawn as `|Tpath:w:h|t`: the whole 64x64 texture is squeezed
-- into the message's icon box. The clown texture used to leave transparent art
-- around a 44px face, so at the same box size it read smaller than every other
-- emoji whose art fills the canvas. Read the shipped textures and compare.
local CLOWN = "Media/emoji_clown.tga"
local SMILE = "Media/emoji/smile.tga"

local function readTexture(path)
  local file = assert(io.open(path, "rb"), "missing texture " .. path)
  local header = file:read(18)
  assert(header ~= nil and #header == 18, "truncated header in " .. path)
  local idLength = string.byte(header, 1)
  local width = string.byte(header, 13) + string.byte(header, 14) * 256
  local height = string.byte(header, 15) + string.byte(header, 16) * 256
  local depth = string.byte(header, 17)
  assert(depth == 32, path .. " must be a 32-bit TGA, got " .. tostring(depth))
  local pixels = file:read(width * height * 4)
  file:close()
  assert(pixels ~= nil and #pixels == width * height * 4, "truncated pixels in " .. path)
  return { width = width, height = height, pixels = pixels }
end

-- How much of the 64x64 canvas the art itself covers: a texture whose drawing
-- leaves transparent margins reads smaller than one that fills the canvas.
local function opaqueArea(texture)
  local count = 0
  for i = 0, texture.width * texture.height - 1 do
    local alpha = string.byte(texture.pixels, i * 4 + 4)
    if alpha ~= nil and alpha > 128 then
      count = count + 1
    end
  end
  return count
end

return function()
  local clown = readTexture(CLOWN)
  local smile = readTexture(SMILE)
  assert(clown.width == 64 and clown.height == 64, "the clown texture stays 64x64")
  assert(smile.width == 64 and smile.height == 64, "the smile texture stays 64x64")

  local clownArea = opaqueArea(clown)
  local smileArea = opaqueArea(smile)
  assert(clownArea >= smileArea * 0.8, "the clown emoji must fill its canvas like the others: " .. clownArea .. "px vs " .. smileArea .. "px")
end
