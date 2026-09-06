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
      -- Setting filetype doesn't reliably load the syntax file during
      -- LazyVim's startup autocmd chain (a later Syntax/filetype pass can
      -- clobber it). Defer the load past the whole chain and source it
      -- explicitly, clearing the reload guard first.
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(args.buf) then
          vim.api.nvim_buf_call(args.buf, function()
            vim.b.current_syntax = nil
            vim.cmd("runtime! syntax/notes.vim")
          end)
        end
      end)
    end,
  })
end

return M
