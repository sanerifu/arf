local inspect = require("lib.inspect")

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

local tokens = {}

local TERMINATER = {
    [":"] = "COLON",
    ["."] = "DOT",
    [";"] = "SEMICOLON",
}

local SYMBOLS = {
    ["("] = { type = "LPAREN" },
    [")"] = { type = "RPAREN" },
    ["["] = { type = "LBRACKET" },
    ["]"] = { type = "RBRACKET" },
    ["{"] = { type = "LBRACE" },
    ["}"] = { type = "RBRACE" },
}

for line, sep in input:gmatch("([^:.;]+)([:.;])") do
    local trimmed = line:gsub("^%s*\n", ""):gsub("\n", " ")
    local indent_count = select(2, trimmed:find("%S")) - 1
    if indent_count > last_indent_count then
        table.insert(tokens, { type = "IDENT" })
    elseif indent_count < last_indent_count then
        table.insert(tokens, { type = "DEDENT" })
    end
    last_indent_count = indent_count

    local current_token_type = ""
    local current_token = {}

    local function flush()
        if current_token_type ~= "" then
            table.insert(tokens,
                { type = current_token_type, value = (#current_token > 0) and table.concat(current_token) or nil })
            current_token_type = ""
            current_token = {}
        end
    end

    for codepoint in line:gmatch("[\1-\127\194-\244][\128-\191]*") do
        if codepoint:match("%s") then
            flush()
        else
            if SYMBOLS[codepoint] then
                flush()
                table.insert(tokens, { type = SYMBOLS[codepoint].type })
            else
                current_token_type = "IDENTIFIER"
                table.insert(current_token, codepoint)
            end
        end
    end

    flush()
    table.insert(tokens, { type = TERMINATER[sep] })
end

print(inspect(tokens))
