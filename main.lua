local inspect = require("lib.inspect")

---@class Identifier
---@field type "Identifier"
---@field value string
---@class LeftParenthesis
---@field type "LeftParenthesis"
---@class RightParenthesis
---@field type "RightParenthesis"
---@class LeftBracket
---@field type "LeftBracket"
---@class RightBracket
---@field type "RigthBracket"
---@class LeftBrace
---@field type "LeftBrace"
---@class RightBrace
---@field type "RightBrace"
---@class Dot
---@field type "Dot"
---@class Semicolon
---@field type "Semicolon"
---@class Colon
---@field type "Colon"
---@class Type
---@field type "Type"
---@field value string
---@class Indent
---@field type "Indent"
---@class Outdent
---@field type "Outdent"
---@class Label
---@field type "Label"
---@field value string
---@class Integer
---@field type "Integer"
---@field value string
---@class Number
---@field type "Number"
---@field value string
---@class String
---@field type "String"
---@field value string

---@alias Token Identifier | LeftParenthesis | RightParenthesis | LeftBracket | RightBracket | LeftBrace | RightBrace | Dot | Semicolon | Colon | Type | Indent | Outdent | Label | Integer | Number | String

---@param token Token
---@return Token
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

local tokens = {} ---@type Token[]

local TERMINATER = {
    [":"] = { type = "Colon" },
    ["."] = { type = "Dot" },
    [";"] = { type = "Semicolon" },
} ---@type table<string, Token>

local SYMBOLS = {
    ["("] = { type = "LeftParenthesis" },
    [")"] = { type = "RightParenthesis" },
    ["["] = { type = "LeftBracket" },
    ["]"] = { type = "RightBracket" },
    ["{"] = { type = "LeftBrace" },
    ["}"] = { type = "RightBrace" },
} ---@type table<string, Token>

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
} ---@type table<string, Token>

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
                    current_token.type = "Identifier"
                end
                table.insert(current_token.value, codepoint)
            end
        end
    end

    flush()
    table.insert(tokens, copy(TERMINATER[sep]))
end

print(inspect(tokens))
