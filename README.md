# volt

Volt is a Neovim plugin to create interactive UIs within Neovim!

This is a fork of [nvzone/volt](https://github.com/nvzone/volt), made for
[gaanim.nvim](https://github.com/PaoloLupo/gaanim.nvim)'s panels. It keeps
volt's API and changes how it behaves:

- **Nothing global while no volt window is open.** The first volt buffer turns
  on `'mousemoveevent'` and a key listener; closing or wiping the last one
  turns them off and restores the option. Upstream sets both once and keeps
  them for the rest of the session.
- **Clicks land on the cell under the mouse.** Click ranges are end-exclusive,
  so the first column of a cell is its own and not its left neighbour's.
  Mouse clicks run after Neovim has handled the click, at the mouse's column
  rather than the cursor's, and the cursor stays where you clicked.
- **Actions know where they were clicked.** A click function receives
  `{ buf, row, col, by, col_start, col_end }`.
- **`ui.track`**: a bar you click to pick a point along it (a scrubber).
- **Colors follow the colorscheme**: volt's highlight groups are derived again
  after every `:colorscheme`, also for light backgrounds.
- **Late redraws are safe**: `redraw` on a closed buffer does nothing, so
  async updates need no guard.
- `<C-t>` (cycle windows) is mapped only when there is more than one buffer.
- Specs: `nvim --headless --clean -l tests/run.lua`.

## Install

```lua
{ "PaoloLupo/volt", lazy = true }
```

## Usage

A volt UI is a scratch buffer in a window you open. Its content is a layout of
named sections; each section returns lines, and each line is a list of cells
`{ text, highlight?, actions? }`, drawn as virtual text over blank lines.

```lua
local volt = require "volt"
local ui = require "volt.ui"

local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace "my-ui"
local value = 0.3

local layout = {
  {
    name = "header",
    lines = function()
      return { { { "Volume ", "Title" }, { ("%d%%"):format(value * 100), "Comment" } } }
    end,
  },
  {
    name = "bar",
    lines = function()
      return {
        ui.track {
          w = 30,
          val = value,
          on_pick = function(fraction)
            value = fraction
            volt.redraw(buf, "all")
          end,
        },
      }
    end,
  },
}

volt.gen_data { { buf = buf, layout = layout, xpad = 2, ns = ns } }
local win = vim.api.nvim_open_win(buf, true, { relative = "editor", row = 5, col = 10, width = 36, height = 2 })
volt.run(buf, { h = 2, w = 36 })
require("volt.events").add(buf)
volt.mappings { bufs = { buf } } -- q and <Esc> close it
```

### Core (`require "volt"`)

| Function | What it does |
|---|---|
| `gen_data(list)` | Registers buffers: each `{ buf, layout, xpad?, ns }`. Computes each section's row. Call again when the number of lines changes. |
| `run(buf, { h, w, custom_empty_lines? })` | Fills the buffer with `h` blank lines of width `w`, draws every section and makes it read-only. |
| `redraw(buf, names)` | Draws sections again: `"all"`, a name or a list of names. Nothing when the buffer was closed. |
| `mappings({ bufs, after_close?, close_func? })` | `q` and `<Esc>` close every buffer in `bufs`; `<C-t>` cycles them when there are several. |
| `close(buf?)` | Closes the UI from code. |

A section may set `col_start` to draw from another column than `xpad`.

### Cells and actions

`actions` is either a function (or an Ex command string) run on click, or a
table:

```lua
{
  click = function(ctx) end, -- ctx = { buf, row, col, by, col_start, col_end }
  ui_type = "slider",        -- also run when the cursor moves onto it
  hover = { id = "x", redraw = { "section" }, callback = function() end },
}
```

`ctx.by` is `"mouse"`, `"keyb"` (the cursor moved onto a slider) or `nil`
(`<CR>`). Columns are 0-based display columns; `col_end` is exclusive.

### Events (`require "volt.events"`)

| Function | What it does |
|---|---|
| `add(buf or bufs)` | Hears clicks, hovers and keys in these buffers: `<CR>` clicks, `<Tab>` / `<S-Tab>` move between clickable lines. |
| `remove(buf)` | Stops hearing a buffer; called for you when it is wiped or closed. |
| `click(buf, row, col, by?)` | Runs the clickable at a row (1-based) and column (0-based). Returns whether one ran. |

### Components (`require "volt.ui"`)

| Component | Returns |
|---|---|
| `track { w, val, on_pick, char?, thumb?, hlon?, hloff?, hlthumb? }` | A line: a bar with a thumb at `val` (0–1); a click calls `on_pick(fraction)`. |
| `slider.config { w, val, txt?, thumb?, ratio_txt?, hlon?, hloff?, actions }` | A line: a 0–100 slider; `slider.val(w, txt, xpad)` reads the cursor's value. |
| `progressbar { w, val, icon?, hl? }` | Cells: a 0–100 bar. |
| `checkbox { active, txt, check?, uncheck?, hlon?, hloff?, actions? }` | A cell. |
| `tabs(names, w, { active, hlon?, hloff? })` | Three lines of boxed tabs; `"_pad_"` fills the space. |
| `table(rows, w, header_hl?, title?)` | Lines of a bordered table; cells may be strings or lists of cells. |
| `separator(char?, w, hl?)` | A line. |
| `border(lines, hl?)` | Boxes `lines` in place. |
| `grid_col(cols)`, `grid_row(lines_list)` | Lay sections side by side, or stack them. |
| `graphs.bar(data)`, `graphs.dot(data)` | Small charts. |
| `hpad(line, w)`, `line_w(line)` | Expand a `"_pad_"` cell to fill `w`; a line's width. |

### Highlight groups

`ExDarkBg`, `ExBlack2Bg`, `ExBlack3Bg` (and `…Border`), `ExRed`, `ExYellow`,
`ExBlue`, `ExGreen`, `ExLightGrey` and `CommentFg`, derived from `Normal`,
`Comment` and the diff and syntax groups (or from base46 under NvChad).

## Showcase

Plugins made using volt: [Minty](https://github.com/NvChad/minty),
[Menu](https://github.com/NvChad/menu), [Typr](https://github.com/NvChad/typr),
[NvChad's theme picker](https://github.com/NvChad/base46).
