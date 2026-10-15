local api = vim.api
local state = require "volt.state"

--- Draws a section of a volt buffer as extmarks, and records where its
--- clickables and hoverables are. A cell is `{ text, hl?, actions? }`;
--- columns are display columns, and each range is end-exclusive.
return function(buf, section)
  local v = state[buf]
  if not (v and section and api.nvim_buf_is_valid(buf)) then
    return
  end
  local section_lines = section.lines(buf)
  local xpad = section.col_start or v.xpad or 0

  for line_i, line in ipairs(section_lines) do
    local row = line_i + section.row
    local col = xpad
    local marks = {}

    v.clickables[row] = {}
    v.hoverables[row] = {}

    for _, mark in ipairs(line) do
      local width = api.nvim_strwidth(mark[1])
      local actions = mark[3]

      if actions then
        local item = { col_start = col, col_end = col + width, actions = actions }
        table.insert(v.clickables[row], item)

        if type(actions) == "table" then
          item.ui_type = actions.ui_type
          item.hover = actions.hover
          table.insert(v.hoverables[row], item)
        end
      end

      col = col + width
      table.insert(marks, { mark[1], mark[2] })
    end

    api.nvim_buf_set_extmark(buf, v.ns, row - 1, 0, { virt_text_win_col = xpad, virt_text = marks, id = row })
  end
end
