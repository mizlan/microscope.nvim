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

M = {
  file_exists = file_exists,
  lines_from = lines_from,
  first_ = first_,
  get_keys = get_keys,
}

return M
