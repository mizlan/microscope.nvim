prompt_bufnr = vim.api.nvim_create_buf(true, true)
candidates_bufnr = vim.api.nvim_create_buf(true, true)

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
      table.insert(matches, candidate)
    end
  end
  get_valid_cache[query] = matches
  return matches
end

vim.api.nvim_open_win(candidates_bufnr, true, {
  relative = 'editor',
  row      = promptline+1,
  col      = 2,
  width    = vim.api.nvim_get_option('columns') - 4,
  height   = vim.api.nvim_get_option('lines') - promptline - 2
})
vim.api.nvim_open_win(prompt_bufnr, true, {
  relative = 'editor',
  row      = promptline,
  col      = 2,
  width    = vim.api.nvim_get_option('columns') - 4,
  height   = 1
})

vim.api.nvim_buf_attach(prompt_bufnr, false, {
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
