local utils = require("image/utils")


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
  local sixel_str_orig = vim.fn.system(cmd)

  -- Additional patching of the string

  -- Placing the sixel string
  local defer_render = function()
    local stdout = vim.loop.new_tty(2, false)
    stdout:write({
      "\27[s",
      string.format("\27[%d;%dH", y,x+1),
      sixel_str_orig..'\n',
      "\27[u"
    })
    stdout:close() -- Must be closed immediately otherwise there will be ghost characters
  end

  vim.defer_fn(defer_render, 20) -- Suggested in sixelview, doesn't seem to help?
  image.is_rendered = true
  image.sixel_len = string.len(sixel_str_orig)
  backend.state.images[image.id] = image
end


backend.clear = function(image_id, shallow)
  -- Clearing the canvas, and redraw, is there a better way to do this without a full redraw??
  vim.defer_fn(function() vim.cmd("mode") end, 100)

  -- specific image id, re-draw remaining
  if image_id then
    for id, image in pairs(backend.state.images) do
      if id == image_id then
        image.is_rendered = false
        if not shallow then backend.state.images[id] = nil end
      else
        backend.render(image, image.geometry.x, image.geometry.y, image.geometry.width, image.geometry.height)
      end
    end
  else
    for id, image in pairs(backend.state.images) do
      image.is_rendered = false
      if not shallow then backend.state.images[id] = nil end
    end
  end
end

return backend

