-- Volt's highlight groups, derived from the colorscheme. They are set when
-- this module loads and again after every :colorscheme, so they follow it.

local api = vim.api
local lighten = require("volt.color").change_hex_lightness

local M = {}

local function hex(n)
  return "#" .. ("%06x"):format(n or 0)
end

--- The foreground of the first of these groups that has one.
local function fg(...)
  for _, name in ipairs { ... } do
    local color = api.nvim_get_hl(0, { name = name, link = false }).fg
    if color then
      return hex(color)
    end
  end
end

function M.groups()
  local dark = vim.o.background == "dark"

  if vim.g.base46_cache then
    local colors = dofile(vim.g.base46_cache .. "colors")
    return {
      ExDarkBg = { bg = colors.darker_black },
      ExDarkBorder = { bg = colors.darker_black, fg = colors.darker_black },
      ExBlack2Bg = { bg = colors.black2 },
      ExBlack2Border = { bg = colors.black2, fg = colors.black2 },
      ExRed = { fg = colors.red },
      ExYellow = { fg = colors.yellow },
      ExBlue = { fg = colors.blue },
      ExGreen = { fg = colors.green },
      ExBlack3Bg = { bg = colors.one_bg2 },
      ExBlack3Border = { bg = colors.one_bg2, fg = colors.one_bg2 },
      ExLightGrey = { fg = lighten(colors.grey, dark and 35 or -35) },
      CommentFg = { fg = colors.light_grey },
    }
  end

  local normal_bg = hex(api.nvim_get_hl(0, { name = "Normal", link = false }).bg)
  local comment = fg("Comment", "NonText") or (dark and "#808080" or "#606060")
  local darker_bg = lighten(normal_bg, dark and -3 or -4)
  local lighter_bg = lighten(normal_bg, dark and 5 or -6)
  local black3_bg = lighten(normal_bg, dark and 10 or -10)

  return {
    ExDarkBg = { bg = darker_bg },
    ExDarkBorder = { bg = darker_bg, fg = darker_bg },
    ExBlack2Bg = { bg = lighter_bg },
    ExBlack2Border = { bg = lighter_bg, fg = lighter_bg },
    ExRed = { fg = fg("Removed", "DiffDelete", "ErrorMsg") },
    ExYellow = { fg = fg("Changed", "DiffChange", "WarningMsg") },
    ExBlue = { fg = fg("Function", "Identifier") },
    ExGreen = { fg = fg("Added", "DiffAdd", "String") },
    ExBlack3Bg = { bg = black3_bg },
    ExBlack3Border = { bg = black3_bg, fg = black3_bg },
    ExLightGrey = { fg = lighten(comment, dark and 20 or -20) },
    CommentFg = { fg = comment },
  }
end

function M.apply()
  for name, val in pairs(M.groups()) do
    api.nvim_set_hl(0, name, val)
  end
end

M.apply()
api.nvim_create_autocmd("ColorScheme", {
  group = api.nvim_create_augroup("volt.highlights", { clear = true }),
  callback = M.apply,
})

return M
