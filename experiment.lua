prompt_bufnr = vim.api.nvim_create_buf(true, true)
-- :sign place 1 line=1 name=microscope_prompt buffer=1
candidates_bufnr = vim.api.nvim_create_buf(true, true)

-- signcolumn shenanigans
vim.fn.sign_define('microscope_prompt', {
  text   = "» ",
  texthl = "Question",
  linehl = 'StatusLine'
})

vim.fn.sign_place(1, '', 'microscope_prompt', prompt_bufnr, {
  lnum = 1
})

promptline = vim.fn.floor(vim.api.nvim_get_option('lines') * 2 / 3)
KILL_FLAG = 0

function file_exists(file)
  local f = io.open(file, "rb")
  if f then f:close() end
  return f ~= nil
end

function lines_from(file)
  if not file_exists(file) then return {} end
  lines = {}
  for line in io.lines(file) do 
    lines[#lines + 1] = line
  end
  return lines
end

function get_keys(tbl)
  local keys = {}
  for k, _ in pairs(tbl) do
    keys[#keys + 1] = k
  end
  return keys
end

cmds = get_keys(vim.api.nvim_get_commands({}))

results = lines_from('words')

--- fuzzy search (an alternative to prefix/substring search)
function fuzzy(query, s)
  local query_idx = 1
  for i = 1, #s do
    if string.sub(query, query_idx, query_idx) == string.sub(s, i, i) then
      if query_idx == #query then
        return true
      end
      query_idx = query_idx + 1
    end
  end
  return false
end

--- get_valid returns an array of valid matches, and caches based on the query string
get_valid_cache = {}
function get_valid(query, candidates)
  local matches = {}
  -- if the value is already cached, return it
  local cache_value = get_valid_cache[query]
  if cache_value ~= nil then
    return cache_value
  end
  for _, candidate in ipairs(candidates) do
    if fuzzy(query, candidate) then
    -- if vim.startswith(candidate, query) then
      matches[#matches+1] = candidate
    end
  end
  get_valid_cache[query] = matches
  return matches
end

function show_windows()
  candidates_winnr = vim.api.nvim_open_win(candidates_bufnr, true, {
    relative = 'editor',
    row      = promptline + 1,
    col      = 2,
    width    = vim.api.nvim_get_option('columns') - 4,
    height   = vim.api.nvim_get_option('lines') - promptline - 2,
    style    = 'minimal'
  })
  prompt_winnr = vim.api.nvim_open_win(prompt_bufnr, true, {
    relative = 'editor',
    row      = promptline,
    col      = 2,
    width    = vim.api.nvim_get_option('columns') - 4,
    height   = 1,
    style    = 'minimal'
  })
  vim.api.nvim_win_set_option(prompt_winnr, 'signcolumn', 'yes')
  vim.api.nvim_win_set_option(candidates_winnr, 'signcolumn', 'yes')
  vim.cmd('startinsert!')
  return candidates_winnr, prompt_winnr
end

function close_windows()
  vim.api.nvim_win_close(candidates_winnr, true)
  vim.api.nvim_win_close(prompt_winnr, true)
end

function attach_updater()
  return vim.api.nvim_buf_attach(prompt_bufnr, false, {
    on_lines = function()
      if KILL_FLAG > 0 then
        return false
      end
      vim.schedule(function()
        local text = vim.api.nvim_buf_get_lines(prompt_bufnr, 0, -1, true)[1]
        local allowed = get_valid(text, results)
        vim.api.nvim_buf_set_lines(candidates_bufnr, 0, -1, true, allowed)
      end)
    end
  })
end

vim.api.nvim_set_keymap('n', '<Leader>f', ':lua show_windows()<CR>', {silent = true})
vim.api.nvim_buf_set_keymap(prompt_bufnr, 'n', '<Esc>', ':lua close_windows()<CR>', {silent = true})

attach_updater()
