local volt = require "volt"
local events = require "volt.events"
local state = require "volt.state"
local ui = require "volt.ui"

--- A volt buffer in a window, drawing `lines` (a function returning cells).
local function open(lines, w)
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, { relative = "editor", row = 1, col = 1, width = w or 40, height = 4 })
  local ns = vim.api.nvim_create_namespace "volt.spec"
  volt.gen_data { { buf = buf, layout = { { name = "main", lines = lines } }, xpad = 1, ns = ns } }
  volt.run(buf, { h = 4, w = w or 40 })
  events.add(buf)
  return buf, win
end

local function close(buf)
  require("volt.utils").close { bufs = { buf } }
end

it("clicks the cell under the column, with no overlap between neighbours", function()
  local clicked
  local buf = open(function()
    return {
      {
        {
          "ab",
          "Normal",
          function()
            clicked = "ab"
          end,
        },
        {
          "󰐊 cd",
          "Normal",
          function()
            clicked = "cd"
          end,
        },
      },
    }
  end)
  -- xpad 1: "ab" is columns 1-2, "󰐊 cd" columns 3-6.
  eq(false, events.click(buf, 1, 0))
  events.click(buf, 1, 2)
  eq("ab", clicked)
  events.click(buf, 1, 3)
  eq("cd", clicked, "the first column of a cell is its own")
  clicked = nil
  eq(false, events.click(buf, 1, 7))
  close(buf)
end)

it("passes where it was clicked to the action", function()
  local ctx
  local buf = open(function()
    return { { { "pad" }, { "button", "Normal", {
      click = function(c)
        ctx = c
      end,
    } } } }
  end)
  events.click(buf, 1, 6, "mouse")
  eq({ buf = buf, row = 1, col = 6, by = "mouse", col_start = 4, col_end = 10 }, ctx)
  close(buf)
end)

it("runs only sliders when the cursor moves onto them", function()
  local runs = 0
  local buf = open(function()
    return {
      { {
        "button",
        "Normal",
        function()
          runs = runs + 1
        end,
      } },
      { { "slider", "Normal", {
        ui_type = "slider",
        click = function()
          runs = runs + 10
        end,
      } } },
    }
  end)
  eq(false, events.click(buf, 1, 2, "keyb"))
  events.click(buf, 2, 2, "keyb")
  eq(10, runs)
  close(buf)
end)

it("picks a point along a track", function()
  local picked
  local buf = open(function()
    return { ui.track {
      w = 10,
      val = 0.5,
      on_pick = function(f)
        picked = f
      end,
    } }
  end, 20)
  -- xpad 1: the track spans columns 1-10; the thumb sits at cell 5.
  events.click(buf, 1, 1)
  eq(0.05, picked)
  events.click(buf, 1, 6)
  eq(0.55, picked, "on the thumb")
  events.click(buf, 1, 10)
  eq(0.95, picked)
  close(buf)
end)

it("hears the mouse only while a volt buffer is open", function()
  vim.o.mousemoveevent = false
  local a = open(function()
    return { { { "a" } } }
  end)
  local b = open(function()
    return { { { "b" } } }
  end)
  eq(true, vim.o.mousemoveevent)
  close(a)
  eq(true, vim.o.mousemoveevent, "another buffer still listens")
  vim.api.nvim_buf_delete(b, { force = true })
  eq(false, vim.o.mousemoveevent, "wiping the last buffer restores the option")
  eq({}, events.bufs)
end)

it("forgets a closed buffer, so late redraws do nothing", function()
  local buf = open(function()
    return { { { "x" } } }
  end)
  close(buf)
  eq(nil, state[buf])
  volt.redraw(buf, "all")
end)

it("follows the colorscheme", function()
  vim.o.background = "dark"
  vim.api.nvim_set_hl(0, "Normal", { bg = "#202020", fg = "#dddddd" })
  vim.api.nvim_exec_autocmds("ColorScheme", {})
  local first = vim.api.nvim_get_hl(0, { name = "ExBlack2Bg" }).bg
  vim.api.nvim_set_hl(0, "Normal", { bg = "#402020", fg = "#dddddd" })
  vim.api.nvim_exec_autocmds("ColorScheme", {})
  local second = vim.api.nvim_get_hl(0, { name = "ExBlack2Bg" }).bg
  eq(true, first ~= second)
end)
