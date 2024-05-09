local cmp = require('cmp');
local config = require('cmp.config');
local a = require("plenary.async");
local l = require("emerald-echo.local");
local job = require('plenary.job');
local u = require('emerald-echo.utils');

local ts = vim.treesitter;
local fwatch = require('fwatch')

-- vim.print(cmp.lsp.CompletionItemKind);
-- Class = 7,
-- Color = 16,
-- Constant = 21,
-- Constructor = 4,
-- Enum = 13,
-- EnumMember = 20,
-- Event = 23,
-- Field = 5,
-- File = 17,
-- Folder = 19,
-- Function = 3,
-- Interface = 8,
-- Keyword = 14,
-- Method = 2,
-- Module = 9,
-- Operator = 24,
-- Property = 10,
-- Reference = 18,
-- Snippet = 15,
-- Struct = 22,
-- Text = 1,
-- TypeParameter = 25,
-- Unit = 11,
-- Value = 12,
-- Variable = 6
--


-- Function to find the closest parent directory containing a file
local function find_parent_directory_containing_file(filename, topDir)
    local current_dir = vim.fn.expand('%:p:h') -- Get the full path of the current buffer's directory
    local parent_dir = current_dir

    while parent_dir ~= topDir do -- Continue until we reach the root directory
        local file_path = parent_dir .. '/' .. filename -- Construct the file path

        if vim.fn.filereadable(file_path) == 1 then -- Check if the file exists
            return parent_dir -- Return the parent directory containing the file
        else
            parent_dir = vim.fn.fnamemodify(parent_dir, ':h') -- Move up one directory
        end
    end

    return nil -- Return nil if the file is not found in any parent directory
end



local function extractClassesFromFile(projectDir, path, callback)

  -- treesitter query for extracting css clasess
  local qs = [[
  (class_selector
    (class_name)@class_name)
  ]]

  local classes = {} -- clean up prev classes
  -- local fd = io.open(path, 'r');
  local compile = 'yarn sass '.. path .. ' -I '..projectDir..'/node_modules';

  -- print('executing', compile);
  local data = io.popen(compile):read("a");
  -- print('-----------------compiled scss end--------------------')

  if data then

    -- print(data);

    local unique_class = {}
    --
    local parser = ts.get_string_parser(data, "css")
    local tree = parser:parse()[1]
    local root = tree:root()
    local query = ts.query.parse("css", qs)

    for _, matches, _ in query:iter_matches(root, data, 0, 0, {}) do
      for _, node in pairs(matches) do
        local class_name = ts.get_node_text(node, data)
        -- print('adding class', class_name);
        table.insert(unique_class, class_name)
      end
    end

    local unique_list = u.unique_list(unique_class)
    print('collected', #unique_list, 'classes from', path);
    for _, class in ipairs(unique_list) do
      table.insert(classes, {
        label = class,
        kind = cmp.lsp.CompletionItemKind.Class,
      });
    end

  end

  callback(classes);
end

--
-- Function to read the content of files matching a pattern in a directory
local function readFilesMatchingPattern(projectDir, pattern, callback)
  -- print('executing', 'ls '..pattern..'');
  local files = io.popen('ls '..pattern..''):lines()
  for file in files do
    -- vim.print('file', file);


    extractClassesFromFile(projectDir, file, function (classes)

      -- print('will set classes for completion');

      callback(classes);
    end)


    fwatch.watch(file, {
      on_event = function (filename, events, unwatch)
        -- print('file changed', filename);

        extractClassesFromFile(projectDir, file, function (classes)
          -- print('classes completion updated');
          callback(classes);
        end)


      end
    })
  end
  return nil;
end

-- Function to read a JSON file and parse its contents
local function readJSONFile(filename)
  local content = vim.fn.readfile(filename)
  local json_str = table.concat(content, "\n")
  return vim.fn.json_decode(json_str)
end


Source = {}

function Source:setup(opts)
  -- print('Registering html-css cmp source');
  local name = 'html-css';
	cmp.register_source(name, Source);

  -- vim.print({opts});

	-- Get the current working directory
	local current_directory = vim.fn.getcwd()

  vim.print({ current_directory });

  -- Get the current buffer handle
  local current_buf = vim.api.nvim_get_current_buf()

  -- Get the full path of the current buffer
  local buf_name = vim.api.nvim_buf_get_name(current_buf)

  -- Print the full path
  -- print("Full path of current buffer:", buf_name)

  self.options = {};

  local projectDir = find_parent_directory_containing_file('package.json', buf_name);
  -- vim.print(projectDir..'/'..'package.json');
  local packageJSON = readJSONFile(projectDir..'/'..'package.json');
  if packageJSON.nvim then
    -- print("Contents of the JSON file:")
    for key, value in pairs(packageJSON.nvim) do
      -- vim.print(key, value)

      if key == 'pde' then
        self.options = value;
      end

    end
  else
    print('Unable to find any configuration. Ensure that package.json has field `nvim`');
  end

  -- vim.print('options', self.options);

  if self.options.styles then
    for _, value in pairs(self.options.styles) do
      -- print(key, value);

      readFilesMatchingPattern(current_directory, projectDir..'/'..value, function (data)
        Source:updateCompletion(data);
      end);

    end
  end


end

function Source:config(...)
  print('Running config()', ...);
end

function Source:deactivate()
end

function Source:updateCompletion(data)
  self.completion = data;
end

function Source:is_available()
  -- print('check for filetype');
  -- print(vim.bo.filetype);
  if vim.bo.filetype ~= 'html' then
    return false;
  end

	local inside_quotes = ts.get_node({ bfnr = 0 })

  -- print('inside quote', inside_quotes);

	if inside_quotes == nil then
		return false
	end

	local type = inside_quotes:type()

  -- print('type', type);

  -- if type is attribute_value
  -- when there are already some values
  -- in the class attribute
  -- we reach the 'attribute_value' node
  if type == 'attribute_value' then

    local parent = inside_quotes:parent();
    -- print(parent);
    -- print('parent type', parent:type());

    -- when we are insied the quotes we need to navigate back
    -- in order to catch the attribute name
    inside_quotes = parent;
  end

	local prev_sibling = inside_quotes:prev_named_sibling()
  -- print('prev_sibling', prev_sibling);

	if prev_sibling == nil then
		return false
	end

	local prev_sibling_name = ts.get_node_text(prev_sibling, 0)

  -- print('prev_sibling_name', prev_sibling_name)

	if (prev_sibling_name == "class") then
    -- print('completion is available...');
		return true
	end

  return false;
end

function Source:get_trigger_characters()
  -- print('get_trigger_characters');
  return {'*'};
end

function Source:complete(_, callback)
  -- print('get classnames for completion');

  callback({ items = self.completion, isComplete = true })
end


return Source;
