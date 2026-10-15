local M = {}

--- @class CheckboxOptions
--- @field active boolean Indicates if the checkbox is active.
--- @field txt string The text to display next to the checkbox.
--- @field check string|nil Replace the default check icon with a custom one.
--- @field uncheck string|nil Replace the deafult unchecked icon with a custom one.
--- @field hlon? string|nil Highlight for the active state (optional).
--- @field hloff? string|nil Highlight for the inactive state (optional).
--- @field actions table|nil Actions associated with the checkbox (optional).

--- @param o CheckboxOptions The options for the checkbox.
--- @return string[] A table containing the checkbox representation.
M.checkbox = function(o)
  return {
    (o.active and (o.check or "") or (o.uncheck or "")) .. "  " .. o.txt,
    o.active and (o.hlon or "String") or (o.hloff or "ExInactive"),
    o.actions,
  }
end

--- @class ProgressOptions
--- @field w number The total width of the progress bar.
--- @field val number The current value of the progress (0 to 100).
--- @field icon? table active/inactive icon styles, ex: { on = "", off = ""}
--- @field hl? table  active/inactive highlights, ex: { on = "", off = ""}

--- @param o ProgressOptions The options for the progress bar.
--- @return table[] A table containing two elements: the active and inactive parts of the progress bar.
M.progressbar = function(o)
  local opts = {
    icon = { on = "-", off = "-" },
    hl = { on = "exred", off = "linenr" },
  }

  o = vim.tbl_deep_extend("force", opts, o)

  local activelen = math.floor(o.w * (o.val / 100))
  local inactivelen = o.w - activelen

  return {
    { string.rep(o.icon.on, activelen), o.hl.on },
    { string.rep(o.icon.off, inactivelen), o.hl.off },
  }
end

M.separator = function(char, w, hl)
  return { { string.rep(char or "─", w), hl or "linenr" } }
end

M.grid_row = function(tb)
  local result = {}
  for _, lines in ipairs(tb) do
    for _, line in ipairs(lines) do
      table.insert(result, line)
    end
  end

  return result
end

M.line_w = function(line)
  local w = 0

  for _, cell in ipairs(line) do
    if cell[1] ~= "_pad_" then
      w = w + vim.api.nvim_strwidth(cell[1])
    end
  end

  return w
end

M.border = function(lines, hl)
  hl = hl or "linenr"

  local maxw = 0
  local line_widths = {}

  for _, line in ipairs(lines) do
    local linew = M.line_w(line)

    if maxw < linew then
      maxw = linew
    end

    table.insert(line_widths, linew)
  end

  for i, _ in ipairs(lines) do
    table.insert(lines[i], 1, { "│ ", hl })
    local rpad = string.rep(" ", maxw - line_widths[i])
    table.insert(lines[i], { rpad .. " │", hl })
  end

  maxw = maxw + 2

  local horiz_chars = string.rep("─", maxw)

  table.insert(lines, 1, { { "┌" .. horiz_chars .. "┐", hl } })
  table.insert(lines, { { "└" .. horiz_chars .. "┘", hl } })
end

M.hpad = function(line, w)
  local pad_w = w - M.line_w(line)

  for i, v in ipairs(line) do
    if v[1] == "_pad_" then
      line[i][1] = string.rep(" ", pad_w)
    end
  end

  return line
end

--- @class TrackOptions
--- @field w integer Width in cells.
--- @field val number Where the thumb is, from 0 to 1.
--- @field on_pick fun(fraction: number) Called with where a click lands, from 0 to 1.
--- @field char? string The track's character (default "━").
--- @field thumb? string The thumb (default "●"); "" for none.
--- @field hlon? string Highlight before the thumb.
--- @field hloff? string Highlight after it.
--- @field hlthumb? string Highlight of the thumb.

--- A horizontal track you click to pick a point along it, unlike `slider`
--- with the mouse's column rather than the cursor's: a scrubber, a volume.
--- @param o TrackOptions
--- @return table[] One line.
M.track = function(o)
  local char = o.char or "━"
  local thumb = o.thumb or "●"
  local thumb_w = vim.api.nvim_strwidth(thumb)
  local val = math.max(0, math.min(1, o.val or 0))
  local before = math.min(math.floor(val * o.w + 0.5), o.w - thumb_w)
  local after = o.w - before - thumb_w

  local function pick(offset)
    return {
      click = function(ctx)
        local cell = offset + (ctx.col - ctx.col_start)
        o.on_pick(math.max(0, math.min(1, (cell + 0.5) / o.w)))
      end,
    }
  end

  local line = {}
  if before > 0 then
    table.insert(line, { string.rep(char, before), o.hlon or "ExBlue", pick(0) })
  end
  if thumb_w > 0 then
    table.insert(line, { thumb, o.hlthumb or o.hlon or "ExBlue", pick(before) })
  end
  if after > 0 then
    table.insert(line, { string.rep(char, after), o.hloff or "LineNr", pick(before + thumb_w) })
  end
  return line
end

return M
