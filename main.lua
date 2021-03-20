local get_node_text = require('vim.treesitter.query').get_node_text

local metadata = {
  project_name = "nvim-lspconfig",
}

local tokens = {
  heading = "atx_heading",
  loose_list = "loose_list",
  tight_list = "tight_list",
  fenced_code_block = "fenced_code_block",
  paragraph = "paragraph"
}

local style_elements = {
  header_break = string.rep("=", 78),
}

local function recursive_parser(parent_node, content, concatenated_content)
  for node in parent_node:iter_children() do
    if node:child_count() > 0 then
      concatenated_content = recursive_parser(node, content, concatenated_content)
    else
      local text = get_node_text(node, content)
      concatenated_content = concatenated_content .. text
    end
  end
  return concatenated_content
end

local function convert_header(number, node, contents, out)
  table.insert(out, style_elements.header_break)
  local text = get_node_text(node, contents)
  text = string.gsub(text, "#*[ ]", "")
  local left = string.format("%d. %s", number, text)
  local right = string.format("*%s-%s*", metadata.project_name, string.lower(text))
  local padding = string.rep(" ", 78 - #left - #right)
  text = string.format("%s%s%s", left, padding, right)
  table.insert(out, text)
  table.insert(out, " ")
end

local function convert_fenced_code_block(node, contents, out)
  local code_block = get_node_text(node, contents)
  -- change the backticks to the respective carets
  local formatted_start = string.gsub(code_block, '```.-\n', '>\n', 1)
  local formatted_end = string.gsub(formatted_start, '```', '<', 1)
  -- calculate the number of lines to avoid indenting the last line,
  -- which is the delimter which should not be indented
  local _, num_lines = string.gsub(vim.trim(formatted_end), '\n', '\n')
  local formatted_indent = string.gsub(formatted_end, '\n', '\n  ', num_lines - 1)
  table.insert(out, formatted_indent)
end

local function parse_markdown(parser, contents)
  local tstree = parser:parse()[1]
  local formatted_file = {}
  local parent_node = tstree:root()

  local header_count = 1
  for node in parent_node:iter_children() do
    local node_type = node:type()
    if node_type == tokens.heading then
      convert_header(header_count, node, contents, formatted_file)
      header_count = header_count + 1
    elseif node_type == tokens.fenced_code_block then
      convert_fenced_code_block(node, contents, formatted_file)
    else
      local text = get_node_text(node, contents)
      -- local text = recursive_parser(node, contents, "")
      table.insert(formatted_file, text)
    end
  end

  table.insert(formatted_file, "vim:tw=78:ts=8:ft=help:norl:")
  local final_text = table.concat(formatted_file, "\n")

  return final_text
end

local function generate_readme()
  local fp = assert(io.open("tests/README.md"))
  local contents = fp:read("*all")
  fp:close()
  local parser = vim.treesitter.get_string_parser(contents, "markdown")

  local readme_data = parse_markdown(parser, contents)

  local writer = io.open("help.txt", "w")
  writer:write(readme_data)
  writer:close()
end

generate_readme()
