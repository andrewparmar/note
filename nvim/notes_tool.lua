local M = {}

local NOTES_DIR = vim.fn.expand("~/Documents/notes")

function M.insert_timestamp()
  local timestamp = os.date("[%Y-%m-%d %a %I:%M %p] - ")
  vim.api.nvim_put({ timestamp }, "c", true, true)
  vim.cmd("startinsert!")
end

function M.setup()
  vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    pattern = "*",
    callback = function()
      local real_path = vim.fn.resolve(vim.fn.expand("%:p"))
      if real_path == NOTES_DIR .. "/notes.txt" or real_path == NOTES_DIR .. "/personal_notes.txt" then
        vim.bo.filetype = "notes"
      end
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
