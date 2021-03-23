Microscope_G = Microscope_G or {}

-- DEBUG
dbg = require('luadev').print

Microscope_G.prompt_bufnr = vim.api.nvim_create_buf(true, true)
Microscope_G.candidates_bufnr = vim.api.nvim_create_buf(true, true)
vim.api.nvim_buf_set_option(Microscope_G.prompt_bufnr, 'buflisted', false)
vim.api.nvim_buf_set_option(Microscope_G.candidates_bufnr, 'buflisted', false)

vim.fn.sign_define('microscope_prompt', {
  text   = "» ",
  texthl = "Question",
  linehl = 'TabLine'
})

Microscope_G.PROMPT_SIGN_ID = 32
vim.fn.sign_place(Microscope_G.PROMPT_SIGN_ID, 'microscope', 'microscope_prompt', Microscope_G.prompt_bufnr, { lnum = 1 })

vim.fn.sign_define('microscope_candidate_selection', {
  text   = "> ",
  texthl = "CursorLine",
  linehl = 'CursorLine'
})

Microscope_G.CANDIDATE_SELECTION_SIGN_ID = 69
-- if = 0, don't show
Microscope_G.candidate_selection_lnum = 0

Microscope_G.is_valid_selection = function(lnum)
  return lnum > 0 and lnum <= vim.api.nvim_buf_line_count(Microscope_G.candidates_bufnr)
end

Microscope_G.hide_candidate_selection = function()
  vim.fn.sign_unplace(
    'microscope',
    {
      buffer = Microscope_G.candidates_bufnr,
      id = Microscope_G.CANDIDATE_SELECTION_SIGN_ID,
    }
  )
end

Microscope_G.update_candidate_selection = function(lnum)
  if not Microscope_G.is_valid_selection(lnum) then return nil end

  Microscope_G.candidate_selection_lnum = lnum
  Microscope_G.hide_candidate_selection()

  vim.fn.sign_place(
    Microscope_G.CANDIDATE_SELECTION_SIGN_ID,
    'microscope',
    'microscope_candidate_selection',
    Microscope_G.candidates_bufnr,
    { lnum = lnum }
  )

  -- center the selection in the candidates window
  vim.fn.win_gotoid(Microscope_G.candidates_winnr)
  vim.fn.execute('normal! '..lnum..'Gzz')
  vim.fn.execute('wincmd p')
end

Microscope_G.attempt_increment_selection = function(lnum)
  Microscope_G.update_candidate_selection(Microscope_G.candidate_selection_lnum + 1)
end

Microscope_G.attempt_decrement_selection = function(lnum)
  Microscope_G.update_candidate_selection(Microscope_G.candidate_selection_lnum - 1)
end

Microscope_G.promptline = vim.fn.floor(vim.api.nvim_get_option('lines') * 2 / 3)

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

function first_(x)
  return function(tbl)
    local output = {}
    for i = 1, x do
      output[i] = tbl[i]
    end
    return output
  end
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
Microscope_G.fuzzy = function(query, s)
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
Microscope_G.get_valid_cache = {}
Microscope_G.get_valid = function(query, candidates, track)
  -- TODO: add option to track a particular value (more efficient)
  local track = track or '' -- or query, possibly?
  local track_idx = nil
  -- if the value is already cached, return it
  local cache_value = Microscope_G.get_valid_cache[query]
  if cache_value == nil then
    local matches = {}
    for i, candidate in ipairs(candidates) do
      -- if vim.fn.strlen(query) == 0 or Microscope_G.fuzzy(vim.fn.tolower(query), vim.fn.tolower(candidate)) then
      if vim.startswith(vim.fn.tolower(candidate), vim.fn.tolower(query)) then
        matches[#matches+1] = candidate
      end
    end
    Microscope_G.get_valid_cache[query] = matches
  end
  for i, match in ipairs(Microscope_G.get_valid_cache[query]) do
    if match == track then
      track_idx = i
    end
  end
  return Microscope_G.get_valid_cache[query], track_idx
end

Microscope_G.show_windows = function()
  Microscope_G.candidates_winnr = vim.api.nvim_open_win(Microscope_G.candidates_bufnr, true, {
    relative = 'editor',
    row      = Microscope_G.promptline + 1,
    col      = 2,
    width    = vim.api.nvim_get_option('columns') - 120,
    height   = vim.api.nvim_get_option('lines') - Microscope_G.promptline - 2,
    style    = 'minimal'
  })
  Microscope_G.prompt_winnr = vim.api.nvim_open_win(Microscope_G.prompt_bufnr, true, {
    relative = 'editor',
    row      = Microscope_G.promptline,
    col      = 2,
    width    = vim.api.nvim_get_option('columns') - 120,
    height   = 1,
    style    = 'minimal'
  })
  vim.api.nvim_win_set_option(Microscope_G.prompt_winnr, 'signcolumn', 'yes')
  vim.api.nvim_win_set_option(Microscope_G.candidates_winnr, 'signcolumn', 'yes')
  vim.api.nvim_buf_call(Microscope_G.prompt_bufnr, function()
    vim.cmd('startinsert!')
  end)
  return Microscope_G.candidates_winnr, Microscope_G.prompt_winnr
end

Microscope_G.close_windows = function()
  vim.api.nvim_win_close(candidates_winnr, true)
  vim.api.nvim_win_close(prompt_winnr, true)
end

Microscope_G.end_query = function()
  Microscope_G.get_valid_cache = {}
  Microscope_G.KILL_FLAG = 1
end

Microscope_G.KILL_FLAG = 0
Microscope_G.attach_updater = function()
  return vim.api.nvim_buf_attach(Microscope_G.prompt_bufnr, false, {
    on_lines = function()
      if Microscope_G.KILL_FLAG > 0 then
        return false
      end
      vim.schedule(function()
        local text = vim.api.nvim_buf_get_lines(Microscope_G.prompt_bufnr, 0, -1, true)[1]
        local track = Microscope_G.is_valid_selection(Microscope_G.candidate_selection_lnum) and
          -- should be equivalent to checking if Microscope_G.candidate_selection_lnum == 0
          vim.api.nvim_buf_get_lines(
            Microscope_G.candidates_bufnr,
            Microscope_G.candidate_selection_lnum - 1,
            Microscope_G.candidate_selection_lnum,
            false
          )[1] or nil
        local allowed, track_idx = Microscope_G.get_valid(text, results, track)
        vim.api.nvim_buf_set_lines(Microscope_G.candidates_bufnr, 0, -1, true, allowed)
        if track_idx ~= nil then
          Microscope_G.update_candidate_selection(track_idx)
        elseif not Microscope_G.is_valid_selection(Microscope_G.candidate_selection_lnum) then
          -- attempt to first set it to the top value (like ivy) or then hide it
          if Microscope_G.is_valid_selection(1) then
            Microscope_G.update_candidate_selection(1)
          else
            Microscope_G.update_candidate_selection(0)
            Microscope_G.hide_candidate_selection()
          end
        end
      end)
    end
  })
end

vim.api.nvim_set_keymap('n', '<Leader>.', ':lua Microscope_G.show_windows()<CR>', {silent = true})
vim.api.nvim_buf_set_keymap(Microscope_G.prompt_bufnr, 'i', '<Esc>', '<Esc>:lua Microscope_G.close_windows()<CR>', {silent = true})
vim.api.nvim_buf_set_keymap(Microscope_G.prompt_bufnr, 'i', '<C-n>', '<Esc>:lua Microscope_G.attempt_increment_selection()<CR>a', {noremap = true, silent = true})
vim.api.nvim_buf_set_keymap(Microscope_G.prompt_bufnr, 'i', '<C-p>', '<Esc>:lua Microscope_G.attempt_decrement_selection()<CR>a', {noremap = true, silent = true})

Microscope_G.attach_updater()
print(vim.inspect(Microscope_G.get_valid_cache["breadb"]))
print(Microscope_G.candidate_selection_lnum)
print(Microscope_G.is_valid_selection(Microscope_G.candidate_selection_lnum))
print(vim.api.nvim_buf_get_lines(
  Microscope_G.candidates_bufnr,
  Microscope_G.candidate_selection_lnum - 1,
  Microscope_G.candidate_selection_lnum,
  false
)[1])
