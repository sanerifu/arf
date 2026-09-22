local input_file = arg[1]
local output_file = arg[2] or input_file:gsub(".arf", ".c")

local input ---@type string

do
    local file = assert(io.open(input_file, "r"))
    input = file:read("*a") ---@type string
    file:close()
end

input = input:gsub("\\(.)", function(c) return ("\x01%02x\x01"):format(string.byte(c)) end)
input = input:gsub('"([^"]*)"', function(str)
    local bytes = { string.byte(str, 1, #str) }
    local ret = {}
    for i = 1, #bytes do
        ret[i] = ("%02x"):format(bytes[i])
    end
    return ("\x02%s\x02"):format(table.concat(ret, ""))
end)

local last_indent_count = 0

for line, sep in input:gmatch("([^:.;]+)([:.;])") do
    local trimmed = line:gsub("^%s*\n", ""):gsub("\n", " ")
    local indent_count = select(2, trimmed:find("%S")) - 1
    if indent_count > last_indent_count then
        print("IDENT")
    elseif indent_count < last_indent_count then
        print("DEDENT")
    end
    print(("%2d %s [[%q]]"):format(indent_count, sep, trimmed))
    last_indent_count = indent_count
end
