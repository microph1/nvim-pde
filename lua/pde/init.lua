local cmp = require('cmp');
local a = require("plenary.async");
local u = require('pde.utils');
local http = require('socket.http');

local ts = vim.treesitter;

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



local function extractClassesFromFile(css, callback)

  -- treesitter query for extracting css clasess
  local qs = [[
  (class_selector
    (class_name)@class_name)
  ]]

  a.run(function()

    local classes = {} -- clean up prev classes
    -- local fd = io.open(path, 'r');
    -- local compile = 'yarn sass '.. path .. ' -I '..projectDir..'/node_modules';

    -- print('executing', compile);
    -- local data = io.popen(compile):read("a");
    -- print('-----------------compiled scss end--------------------')

    if css then

      -- print(data);

      local unique_class = {}
      --
      local parser = ts.get_string_parser(css, "css")
      local tree = parser:parse()[1]
      local root = tree:root()
      local query = ts.query.parse("css", qs)

      for _, matches, _ in query:iter_matches(root, css, 0, 0, {}) do
        for _, node in pairs(matches) do
          local class_name = ts.get_node_text(node, css)
          -- print('adding class', class_name);
          table.insert(unique_class, class_name)
        end
      end

      local unique_list = u.unique_list(unique_class)
      -- print('collected', #unique_list, 'classes');
      for _, class in ipairs(unique_list) do
        table.insert(classes, {
          label = class,
          kind = cmp.lsp.CompletionItemKind.Class,
        });
      end

    end

    callback(classes);

  end) -- end a.run
end


-- Function to read a JSON file and parse its contents
local function readJSONFile(filename)
  local content = vim.fn.readfile(filename)
  local json_str = table.concat(content, "\n")
  return vim.fn.json_decode(json_str)
end


Source = {}

function Source:setup(_)
  self.cacheValid = false;
  self.enabled = true;

	-- Get the current working directory
	-- local cwd = vim.fn.getcwd();

  -- vim.print({ cwd });

  -- Get the current buffer handle
  local current_buf = vim.api.nvim_get_current_buf()

  -- Get the full path of the current buffer
  local buff_path = vim.api.nvim_buf_get_name(current_buf)

  -- Print the full path
  -- print("Full path of current buffer:", buff_path)

  local package_folder = find_parent_directory_containing_file('package.json', buff_path);

  if package_folder == nil then
    self.enabled = false;
    print('pde: cannot find a package.json file. Unable to determine working directory');
    return;
  end

  -- print('package working directory', package_folder);

  local name = 'html-css';

  -- registering nvim-cmp source
	cmp.register_source(name, Source);

  local packageJSON = readJSONFile(package_folder..'/'..'package.json');
  if packageJSON.nvim then
    -- print("Contents of the JSON file:")

    if packageJSON.nvim and packageJSON.nvim.pde then
      self.options = packageJSON.nvim.pde;
    end
  else
    print('Unable to find any configuration. Ensure that package.json has field `nvim`');
  end

  -- vim.print('options', self.options);

end

function Source:updateCompletion(data)
  self.completion = data;
end

function Source:is_available()

  if self.enabled == false then
    return false;
  end

  -- print('check for filetype');
  -- print(vim.bo.filetype);
  if vim.bo.filetype ~= 'html' then
    -- this is triggered also when the extension is scss
    -- as per config `ft = {"html", "scss", etc....}`
    -- when a file other than html is opened chances
    -- are that completion data needs to be updated
    self.cacheValid = false;
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

    -- when we are inside the quotes we need to navigate back
    -- in order to catch the attribute name
    inside_quotes = parent;
  end

	local prev_sibling = inside_quotes:prev_named_sibling();
  -- print('prev_sibling', prev_sibling);

	if prev_sibling == nil then
		return false;
	end

	local prev_sibling_name = ts.get_node_text(prev_sibling, 0);

  -- print('prev_sibling_name', prev_sibling_name)

	if (prev_sibling_name == "class") then
    -- print('completion is available...');
		return true;
	end

  return false;
end

function Source:get_trigger_characters()
  -- print('get_trigger_characters');
  return {'*'};
end

function Source:complete(_, callback)
  -- print('options');
  -- vim.print(self.options);
  -- print('enabled', self.enabled);

  if self.options.styles then
    for _, value in pairs(self.options.styles) do

      if self.cacheValid == false then

        local response, error_message = http.request(value);

        if error_message and error_message ~= 200 then
          print('Error:', error_message);
        end

        -- print('got response', response);

        extractClassesFromFile(response, function (data)
          Source:updateCompletion(data);
          -- cache is invalid by default
          -- when we save completion data for the first time we set `cacheValid = false`
          -- cache is invalidated only by opening a "styles" file
          self.cacheValid = true;
        end);
      end
    end
  end

  callback({ items = self.completion, isComplete = true })
end


return Source;
