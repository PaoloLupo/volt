-- Runs volt's specs with no dependencies:
--   nvim --headless --clean -l tests/run.lua
local root = vim.fs.dirname(vim.fs.dirname(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p")))
vim.opt.rtp:prepend(root)

local passed, failed = 0, 0

function _G.it(name, fn)
  local ok, err = xpcall(fn, debug.traceback)
  if ok then
    passed = passed + 1
  else
    failed = failed + 1
    io.stdout:write("FAIL " .. name .. "\n" .. tostring(err) .. "\n\n")
  end
end

function _G.eq(expected, actual, message)
  if not vim.deep_equal(expected, actual) then
    error(
      ("%sexpected %s, got %s"):format(message and (message .. ": ") or "", vim.inspect(expected), vim.inspect(actual)),
      2
    )
  end
end

dofile(vim.fs.joinpath(root, "tests", "volt_spec.lua"))
io.stdout:write(("%d passed, %d failed\n"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
