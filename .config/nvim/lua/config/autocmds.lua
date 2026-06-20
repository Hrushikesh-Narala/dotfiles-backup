-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

local autocmd_group = vim.api.nvim_create_augroup("FloatWrap", { clear = true })
vim.api.nvim_create_autocmd("WinEnter", {
  group = autocmd_group,
  callback = function()
    local win_config = vim.api.nvim_win_get_config(0)
    if win_config.relative ~= "" then
      vim.wo.wrap = true
    end
  end,
  desc = "Enable word wrap in floating windows",
})
