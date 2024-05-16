local utils = require("image/utils")

local stdout = vim.loop.new_tty(1, false)

---@type Backend
---@diagnostic disable-next-line: missing-fields
local backend = {
  state = nil,
  features = {}
}

backend.setup = function(state)
  backend.state = state
end

backend.render = function(image, x, y, width, height)
  local cmd = 'img2sixel ' .. image.cropped_path
  local pipe = assert(io.popen(cmd, 'r'))
  local sixel_str_orig = assert(pipe:read '*a')


  -- Additional patching of the string

  -- Placing the sixel string
  stdout:write(string.format("\27[%d;%dH", y,x+1))
  stdout:write(sixel_str_orig)
  image.is_rendered = true
  image.sixel_len = string.len(sixel_str_orig)
  backend.state.images[image.id] = image
end

local clear_single = function(image)
  local x = image.geometry.x
  local y = image.geometry.y
  local width = image.geometry.width
  local height = image.geometry.height
  stdout:write(string.format("\27[%d;%dH", y, x+1))
  stdout:write(string.rep(" ", image.sixel_len))
end

backend.clear = function(image_id, shallow)
  -- one
  if image_id then
    local image = backend.state.images[image_id]
    if not image then return end
    clear_single(image)
    image.is_rendered = false
    if not shallow then backend.state.images[image_id] = nil end
    return
  end

  -- all
  for id, image in pairs(backend.state.images) do
    clear_single(image)
    image.is_rendered = false
    if not shallow then backend.state.images[id] = nil end
  end
end

return backend

