local M = {}

local NOTES_DIR = vim.fn.expand("~/Documents/notes")

function M.insert_timestamp()
  local timestamp = os.date("[%Y-%m-%d %a %I:%M %p] - ")
  vim.api.nvim_put({ timestamp }, "c", true, true)
  vim.cmd("startinsert!")
end

function M.setup()
  vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = {
      "*/Documents/notes/notes.txt",
      "*/Documents/notes/personal_notes.txt",
    },
    callback = function()
      vim.bo.filetype = "notes"
    end,
  })

  vim.api.nvim_create_autocmd("FileType", {
    pattern = "notes",
    callback = function(args)
      vim.keymap.set("n", "<leader>t", M.insert_timestamp, { buffer = args.buf, desc = "Insert note timestamp" })
    end,
  })
end

return M
