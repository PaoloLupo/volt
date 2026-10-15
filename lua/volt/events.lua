-- Mouse and keyboard events of volt buffers.
--
-- Mouse events are heard only while a volt buffer exists: the first buffer
-- added turns on 'mousemoveevent' and an on_key listener, and removing the
-- last one turns them off and restores the option. Clicks run on the cell
-- the mouse is over, after Neovim has handled the click.

local api = vim.api
local state = require "volt.state"

local MouseMove = vim.keycode "<MouseMove>"
local LeftMouse = vim.keycode "<LeftMouse>"
local map = vim.keymap.set

local M = {}

M.bufs = {}

local ns = api.nvim_create_namespace "volt.events"
local group = api.nvim_create_augroup("volt.events", { clear = true })
local saved_mousemoveevent = nil
local skip_cursor_moved = {}

--- The clickable under a column of a row, if any. Ranges are end-exclusive.
---@param items table[]?
---@param col integer
---@return table?
function M.item_at(items, col)
  for _, item in ipairs(items or {}) do
    if item.col_start <= col and col < item.col_end then
      return item
    end
  end
end

local function run(actions, ctx)
  local action = type(actions) == "table" and actions.click or actions
  if type(action) == "function" then
    action(ctx)
  elseif type(action) == "string" then
    vim.cmd(action)
  end
end

--- Runs the clickable at (row, col) of a buffer. `by` is "mouse", "keyb"
--- (the cursor moved onto a slider) or nil (<CR>). Row is 1-based, col
--- 0-based. The action gets `{ buf, row, col, by, col_start, col_end }`.
---@param buf integer
---@param row integer
---@param col integer
---@param by? "mouse"|"keyb"
---@return boolean ran
function M.click(buf, row, col, by)
  local v = state[buf]
  local item = v and M.item_at(v.clickables[row], col)
  if not item or (by == "keyb" and item.ui_type ~= "slider") then
    return false
  end
  run(item.actions, { buf = buf, row = row, col = col, by = by, col_start = item.col_start, col_end = item.col_end })
  return true
end

local function hover(buf, row, col)
  local v = state[buf]
  if v.hovered_extmarks then
    vim.g.nvmark_hovered = nil
    require("volt").redraw(buf, v.hovered_extmarks)
    v.hovered_extmarks = nil
  end
  local item = M.item_at(v.hoverables[row], col)
  if item and item.hover then
    local h = item.hover
    if h.callback then
      h.callback()
    end
    vim.g.nvmark_hovered = h.id
    require("volt").redraw(buf, h.redraw)
    v.hovered_extmarks = h.redraw
  end
end

local function on_key(key)
  if key ~= MouseMove and key ~= LeftMouse then
    return
  end
  local pos = vim.fn.getmousepos()
  if pos.winid == 0 or not api.nvim_win_is_valid(pos.winid) then
    return
  end
  local buf = api.nvim_win_get_buf(pos.winid)
  if not state[buf] then
    return
  end
  local row, col = pos.line, pos.column - 1
  if key == MouseMove then
    hover(buf, row, col)
  else
    -- Once Neovim has handled the click; the CursorMoved it causes is not a
    -- second click.
    skip_cursor_moved[buf] = true
    vim.schedule(function()
      skip_cursor_moved[buf] = nil
      M.click(buf, row, col, "mouse")
    end)
  end
end

local function listen()
  if saved_mousemoveevent == nil then
    saved_mousemoveevent = vim.o.mousemoveevent
  end
  vim.o.mousemoveevent = true
  vim.on_key(on_key, ns)
  vim.g.extmarks_events = true
end

local function stop_listening()
  vim.on_key(nil, ns)
  if saved_mousemoveevent ~= nil then
    vim.o.mousemoveevent = saved_mousemoveevent
    saved_mousemoveevent = nil
  end
  vim.g.extmarks_events = false
end

local function cursor()
  local pos = api.nvim_win_get_cursor(0)
  return pos[1], pos[2]
end

local function buf_mappings(buf)
  api.nvim_create_autocmd("CursorMoved", {
    group = group,
    buffer = buf,
    callback = function()
      if not skip_cursor_moved[buf] then
        local row, col = cursor()
        M.click(buf, row, col, "keyb")
      end
    end,
  })
  api.nvim_create_autocmd({ "BufWipeout", "BufDelete" }, {
    group = group,
    buffer = buf,
    callback = function()
      M.remove(buf)
    end,
  })

  map("n", "<CR>", function()
    local row, col = cursor()
    M.click(buf, row, col)
  end, { buffer = buf, desc = "volt: click" })
  map("n", "<Tab>", function()
    require("volt.utils").cycle_clickables(buf, 1)
  end, { buffer = buf, desc = "volt: next clickable" })
  map("n", "<S-Tab>", function()
    require("volt.utils").cycle_clickables(buf, -1)
  end, { buffer = buf, desc = "volt: previous clickable" })
end

--- Hears a buffer (or a list of them): its clicks, hovers and keys.
---@param val integer|integer[]
function M.add(val)
  for _, buf in ipairs(type(val) == "table" and val or { val }) do
    if not vim.tbl_contains(M.bufs, buf) then
      table.insert(M.bufs, buf)
      buf_mappings(buf)
    end
  end
  if #M.bufs > 0 then
    listen()
  end
end

--- Stops hearing a buffer; with none left, stops hearing the mouse.
---@param buf integer
function M.remove(buf)
  for i = #M.bufs, 1, -1 do
    if M.bufs[i] == buf then
      table.remove(M.bufs, i)
    end
  end
  skip_cursor_moved[buf] = nil
  pcall(api.nvim_clear_autocmds, { group = group, buffer = buf })
  if #M.bufs == 0 then
    stop_listening()
  end
end

--- Kept for plugins that call it: adding a buffer turns listening on.
function M.enable()
  if #M.bufs > 0 then
    listen()
  end
end

return M
