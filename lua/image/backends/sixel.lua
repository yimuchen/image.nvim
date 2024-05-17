local magick = require("image/magick")

local uv = vim.uv
if uv == nil then uv = vim.loop end

---@type Backend
---@diagnostic disable-next-line: missing-fields
local backend = {
  state = nil,
  stdout = nil,
  features = {
    crop = false,
  },
}

backend.setup = function(state)
  backend.state = state
  if backend.stdout == nil then backend.stdout = uv.new_tty(1, false) end
end

local _render_sixel_str = function(s, x, y)
  vim.defer_fn(function()
    backend.stdout:write(string.format("\27[s\27[%d;%dH%s\27[u", y + 1, x + 1, s))
  end, 50)
end

backend.render = function(image, x, y, width, height)
  local sixel_str = vim.fn.system("img2sixel " .. image.cropped_path)
  _render_sixel_str(sixel_str, x, y)
  image.is_rendered = true
  backend.state.images[image.id] = image
end

local _derender_with_sixel = function(image)
  -- Currently not working...
  -- Getting where the image was set to be created
  local x = image.geometry.x
  local y = image.geometry.y
  -- Getting the cropped pixel geometry
  local cropped = magick.load_image(image.cropped_path)
  local pw = cropped:get_width()
  local ph = cropped:get_height()
  -- Constructing the sixel string
  local sixel_header = "P;2;;q#0;2;0;0;0" -- Set color at index 0 to color RGB (0,0,0)
  local blank_line = string.format("#0!%d@~", pw) -- Making a blank line
  local blank_code = string.rep(blank_line, math.ceil(ph / 6))
  local sixel_str = sixel_header .. blank_code .. "\\"

  local f = assert(io.open("./clear_test.sixel", "wb"))
  f:write(sixel_str)
  f:close()

  local render_str = "33;46m" .. sixel_str

  _render_sixel_str(string.rep(" ", image.sixel_len), x, y)
  _render_sixel_str(render_str, x, y)
  image.is_rendered = false
end

backend.clear = function(image_id, shallow)
  vim.defer_fn(function()
    vim.cmd("mode")
  end, 50) -- clear everything

  if image_id then
    for id, image in pairs(backend.state.images) do
      if id ~= image_id then -- Rerender
        local x = image.geometry.x
        local y = image.geometry.y
        local w = image.geometry.width
        local h = image.geometry.height
        backend.render(image, x, y, w, h)
      else
        image.is_rendered = false
      end
    end
    if not shallow then backend.state.images[image_id] = nil end
  else
    for _, image in pairs(backend.state.images) do
      image.is_rendered = false
    end
    if not shallow then
      for id, _ in pairs(backend.state.images) do
        backend.state.images[id] = nil
      end
    end
  end
end

return backend
