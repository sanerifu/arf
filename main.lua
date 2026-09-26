local inspect = require("lib.inspect")

local function copy(token)
    return { type = token.type, value = token.value }
end

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
    [":"] = { type = "Colon" },
    ["."] = { type = "Dot" },
    [";"] = { type = "Semicolon" },
}

local SYMBOLS = {
    ["("] = { type = "LeftParenthesis" },
    [")"] = { type = "RightParenthesis" },
    ["["] = { type = "LeftBracket" },
    ["]"] = { type = "RightBracket" },
    ["{"] = { type = "LeftBrace" },
    ["}"] = { type = "RightBrace" },
}

local KEYWORDS = {
    ["sayı"] = { type = "Type", value = "sayı" },
    ["pozitif"] = { type = "Type", value = "pozitif" },
    ["gerçel"] = { type = "Type", value = "gerçel" },

    ["sayı8"] = { type = "Type", value = "sayı8" },
    ["sayı16"] = { type = "Type", value = "sayı16" },
    ["sayı32"] = { type = "Type", value = "sayı32" },
    ["sayı64"] = { type = "Type", value = "sayı64" },
    ["pozitif8"] = { type = "Type", value = "pozitif8" },
    ["pozitif16"] = { type = "Type", value = "pozitif16" },
    ["pozitif32"] = { type = "Type", value = "pozitif32" },
    ["pozitif64"] = { type = "Type", value = "pozitif64" },
    ["gerçel32"] = { type = "Type", value = "gerçel32" },
    ["gerçel64"] = { type = "Type", value = "gerçel64" },

    ["karakter"] = { type = "Type", value = "karakter" },

    ["ile"] = { type = "Between" },
    ["arasında"] = { type = "Within" },
    ["ise"] = { type = "Then" },
    ["olsun"] = { type = "Assign" },
    ["değil-ama"] = { type = "ElseIf" },
    ["değilse"] = { type = "Else" },
    ["bitsin"] = { type = "Break" },
    ["sürsün"] = { type = "Continue" },
    ["sürece"] = { type = "While" },
    ["eklensin"] = { type = "AddAssign" },
    ["çıkarılsın"] = { type = "SubtractAssign" },
    ["çarpılsın"] = { type = "MultiplyAssign" },
    ["bölünsün"] = { type = "DivideAssign" },
    ["değişken"] = { type = "Mutable" },
    ["dönsün"] = { type = "Return" },
}

local UPPERCASE = {
    ["İ"] = true,
    ["Ş"] = true,
    ["Ö"] = true,
    ["Ü"] = true,
    ["Ç"] = true,
    ["Ğ"] = true, -- Ah yes starting your type with Ğ
}

for line, sep in input:gmatch("([^:.;]+)([:.;])") do
    local trimmed = line:gsub("^%s*\n", ""):gsub("\n", " ")
    local indent_count = select(2, trimmed:find("%S")) - 1
    if indent_count > last_indent_count then
        table.insert(tokens, { type = "Indent" })
    elseif indent_count < last_indent_count then
        table.insert(tokens, { type = "Outdent" })
    end
    last_indent_count = indent_count

    local current_token = {
        type = "",
        value = {},
    }

    local function flush()
        if current_token.type ~= "" then
            local value = table.concat(current_token.value)
            local keyword = KEYWORDS[value]
            if keyword then
                table.insert(tokens, copy(keyword))
            elseif current_token.type == "Integer" and value:match("%,") then
                table.insert(tokens, { type = "Number", value = value })
            elseif current_token.type == "String" then
                table.insert(tokens, {
                    type = "String",
                    value = value
                        :sub(2, -2)
                        :gsub(
                            "%x%x",
                            function(hex) return string.char(tonumber(hex, 16)) end
                        )
                        :gsub("\x01(%x%x)\x01", function(hex) return "\\" .. string.char(tonumber(hex, 16)) end),
                })
            else
                table.insert(
                    tokens,
                    {
                        type = current_token.type,
                        value = (value ~= "") and value or nil
                    }
                )
            end
            current_token.type = ""
            current_token.value = {}
        end
    end

    for codepoint in line:gmatch("[\1-\127\194-\244][\128-\191]*") do
        if codepoint:match("%s") then
            flush()
        else
            if SYMBOLS[codepoint] then
                flush()
                table.insert(tokens, copy(SYMBOLS[codepoint]))
            elseif current_token.type == "" and codepoint == "@" then
                current_token.type = "Label"
            elseif
                (current_token.type == "" or current_token.type == "Identifier" and #current_token.value == 1 and current_token.value[1] == "-")
                and codepoint:match("%d")
            then
                current_token.type = "Integer"
                table.insert(current_token.value, codepoint)
            else
                if current_token.type == "" then
                    if codepoint:match("[A-Z]") or UPPERCASE[codepoint] then
                        current_token.type = "Type"
                    elseif codepoint == "\x02" then
                        current_token.type = "String"
                    else
                        current_token.type = "Identifier"
                    end
                end
                table.insert(current_token.value, codepoint)
            end
        end
    end

    flush()
    table.insert(tokens, copy(TERMINATER[sep]))
end

print(inspect(tokens))
