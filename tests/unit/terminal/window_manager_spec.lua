describe("claudecode.terminal.window_manager", function()
  local window_manager
  local mock_vim
  local original_vim
  local spy

  before_each(function()
    -- Store original vim global
    original_vim = vim

    -- Create spy module
    spy = require("luassert.spy")

    -- Create mock vim
    mock_vim = {
      api = {
        nvim_win_is_valid = spy.new(function()
          return true
        end),
        nvim_win_get_buf = spy.new(function()
          return 1
        end),
        nvim_win_get_width = spy.new(function()
          return 80
        end),
        nvim_win_get_height = spy.new(function()
          return 24
        end),
        nvim_get_current_win = spy.new(function()
          return 1000
        end),
        nvim_create_augroup = spy.new(function()
          return 1
        end),
        nvim_create_autocmd = spy.new(function() end),
      },
      bo = setmetatable({}, {
        __index = function(_, bufnr)
          return { channel = 123 }
        end,
      }),
      fn = {
        jobresize = spy.new(function() end),
      },
      defer_fn = spy.new(function(fn, delay)
        fn()
      end),
    }

    -- Set global vim to mock
    _G.vim = mock_vim

    -- Clear package cache and reload module
    package.loaded["claudecode.terminal.window_manager"] = nil
    package.loaded["claudecode.logger"] = nil

    -- Mock logger
    package.loaded["claudecode.logger"] = {
      debug = spy.new(function() end),
      info = spy.new(function() end),
      warn = spy.new(function() end),
      error = spy.new(function() end),
    }

    window_manager = require("claudecode.terminal.window_manager")
  end)

  after_each(function()
    -- Restore original vim
    _G.vim = original_vim
    -- Reset module state
    package.loaded["claudecode.terminal.window_manager"] = nil
  end)

  describe("setup", function()
    it("should create resize autocommands", function()
      window_manager.setup({})

      -- Should create augroup
      assert.spy(mock_vim.api.nvim_create_augroup).was_called_with("ClaudeCodeTerminalResize", { clear = true })

      -- Should create VimResized, WinEnter, TabEnter, and TermEnter autocommands
      assert.spy(mock_vim.api.nvim_create_autocmd).was_called(4)
    end)

    it("should create VimResized autocommand", function()
      window_manager.setup({})

      local calls = mock_vim.api.nvim_create_autocmd.calls
      local vim_resized_found = false

      for _, call in ipairs(calls) do
        if call.vals[1] == "VimResized" then
          vim_resized_found = true
          assert.is_not_nil(call.vals[2].group)
          assert.is_function(call.vals[2].callback)
        end
      end

      assert.is_true(vim_resized_found, "VimResized autocommand should be created")
    end)

    it("should create WinEnter autocommand", function()
      window_manager.setup({})

      local calls = mock_vim.api.nvim_create_autocmd.calls
      local win_enter_found = false

      for _, call in ipairs(calls) do
        if call.vals[1] == "WinEnter" then
          win_enter_found = true
          assert.is_not_nil(call.vals[2].group)
          assert.is_function(call.vals[2].callback)
        end
      end

      assert.is_true(win_enter_found, "WinEnter autocommand should be created")
    end)

    it("should create TabEnter autocommand", function()
      window_manager.setup({})

      local calls = mock_vim.api.nvim_create_autocmd.calls
      local tab_enter_found = false

      for _, call in ipairs(calls) do
        if call.vals[1] == "TabEnter" then
          tab_enter_found = true
          assert.is_not_nil(call.vals[2].group)
          assert.is_function(call.vals[2].callback)
        end
      end

      assert.is_true(tab_enter_found, "TabEnter autocommand should be created")
    end)

    it("should create TermEnter autocommand", function()
      window_manager.setup({})

      local calls = mock_vim.api.nvim_create_autocmd.calls
      local term_enter_found = false

      for _, call in ipairs(calls) do
        if call.vals[1] == "TermEnter" then
          term_enter_found = true
          assert.is_not_nil(call.vals[2].group)
          assert.is_function(call.vals[2].callback)
        end
      end

      assert.is_true(term_enter_found, "TermEnter autocommand should be created")
    end)
  end)

  describe("notify_resize", function()
    it("should be a no-op when no terminal window exists", function()
      window_manager.setup({})
      -- Don't set up any window
      window_manager.notify_resize()

      -- jobresize should not be called
      assert.spy(mock_vim.fn.jobresize).was_not_called()
    end)

    it("should be a no-op when window is not valid", function()
      mock_vim.api.nvim_win_is_valid = spy.new(function()
        return false
      end)

      window_manager.setup({})
      window_manager.notify_resize()

      assert.spy(mock_vim.fn.jobresize).was_not_called()
    end)

    it("should call jobresize with correct dimensions when terminal window exists", function()
      -- Mock additional APIs needed for window creation
      mock_vim.o = { columns = 200 }
      mock_vim.wo = setmetatable({}, {
        __index = function()
          return {}
        end,
        __newindex = function() end,
      })
      mock_vim.cmd = spy.new(function() end)
      mock_vim.api.nvim_win_set_width = spy.new(function() end)
      mock_vim.api.nvim_tabpage_list_wins = spy.new(function()
        return {}
      end)
      mock_vim.api.nvim_get_current_tabpage = spy.new(function()
        return 1
      end)

      window_manager.setup({})

      -- Create a window first
      local winid = window_manager.ensure_window()
      assert.is_not_nil(winid)

      -- Now call notify_resize
      window_manager.notify_resize()

      -- jobresize should be called with channel and dimensions
      assert.spy(mock_vim.fn.jobresize).was_called_with(123, 80, 24)
    end)

    it("should not call jobresize when channel is invalid", function()
      -- Mock buffer with no channel
      mock_vim.bo = setmetatable({}, {
        __index = function(_, bufnr)
          return { channel = 0 }
        end,
      })
      mock_vim.o = { columns = 200 }
      mock_vim.wo = setmetatable({}, {
        __index = function()
          return {}
        end,
        __newindex = function() end,
      })
      mock_vim.cmd = spy.new(function() end)
      mock_vim.api.nvim_win_set_width = spy.new(function() end)
      mock_vim.api.nvim_tabpage_list_wins = spy.new(function()
        return {}
      end)
      mock_vim.api.nvim_get_current_tabpage = spy.new(function()
        return 1
      end)

      window_manager.setup({})

      -- Create a window first
      window_manager.ensure_window()

      -- Now call notify_resize
      window_manager.notify_resize()

      -- jobresize should not be called with invalid channel
      assert.spy(mock_vim.fn.jobresize).was_not_called()
    end)
  end)

  describe("VimResized autocommand callback", function()
    it("should restore configured width on VimResized event", function()
      mock_vim.o = { columns = 200 }
      mock_vim.wo = setmetatable({}, {
        __index = function()
          return {}
        end,
        __newindex = function() end,
      })
      mock_vim.cmd = spy.new(function() end)
      mock_vim.api.nvim_win_set_width = spy.new(function() end)
      mock_vim.api.nvim_tabpage_list_wins = spy.new(function()
        return {}
      end)
      mock_vim.api.nvim_get_current_tabpage = spy.new(function()
        return 1
      end)

      window_manager.setup({ split_width_percentage = 0.3 })

      -- Create a window first
      window_manager.ensure_window()

      -- Find and call the VimResized callback
      local vim_resized_callback
      for _, call in ipairs(mock_vim.api.nvim_create_autocmd.calls) do
        if call.vals[1] == "VimResized" then
          vim_resized_callback = call.vals[2].callback
          break
        end
      end

      assert.is_function(vim_resized_callback)

      -- Simulate terminal resize: columns changed to 300
      mock_vim.o = { columns = 300 }
      mock_vim.api.nvim_win_set_width = spy.new(function() end)

      vim_resized_callback()

      -- Should restore width: 300 * 0.3 = 90
      assert.spy(mock_vim.api.nvim_win_set_width).was_called()
    end)

    it("should call notify_resize on VimResized event", function()
      -- Mock additional APIs needed for window creation
      mock_vim.o = { columns = 200 }
      mock_vim.wo = setmetatable({}, {
        __index = function()
          return {}
        end,
        __newindex = function() end,
      })
      mock_vim.cmd = spy.new(function() end)
      mock_vim.api.nvim_win_set_width = spy.new(function() end)
      mock_vim.api.nvim_tabpage_list_wins = spy.new(function()
        return {}
      end)
      mock_vim.api.nvim_get_current_tabpage = spy.new(function()
        return 1
      end)

      window_manager.setup({})

      -- Create a window first
      window_manager.ensure_window()

      -- Find and call the VimResized callback
      local vim_resized_callback
      for _, call in ipairs(mock_vim.api.nvim_create_autocmd.calls) do
        if call.vals[1] == "VimResized" then
          vim_resized_callback = call.vals[2].callback
          break
        end
      end

      assert.is_function(vim_resized_callback)

      -- Call the callback
      vim_resized_callback()

      -- jobresize should be called
      assert.spy(mock_vim.fn.jobresize).was_called()
    end)
  end)

  describe("WinEnter autocommand callback", function()
    it("should call notify_resize when terminal exists in tab", function()
      -- Mock additional APIs needed
      mock_vim.o = { columns = 200 }
      mock_vim.wo = setmetatable({}, {
        __index = function()
          return {}
        end,
        __newindex = function() end,
      })
      mock_vim.cmd = spy.new(function() end)
      mock_vim.api.nvim_win_set_width = spy.new(function() end)
      mock_vim.api.nvim_get_current_tabpage = spy.new(function()
        return 1
      end)

      -- Mock find_terminal_window to return a terminal window
      local terminal_win = 2000
      mock_vim.api.nvim_tabpage_list_wins = spy.new(function()
        return { terminal_win }
      end)
      mock_vim.bo = setmetatable({}, {
        __index = function()
          return { buftype = "terminal", channel = 123 }
        end,
      })
      mock_vim.api.nvim_win_is_valid = spy.new(function()
        return true
      end)
      mock_vim.api.nvim_win_get_buf = spy.new(function()
        return 1
      end)

      window_manager.setup({})

      -- Find the WinEnter callback
      local win_enter_callback
      for _, call in ipairs(mock_vim.api.nvim_create_autocmd.calls) do
        if call.vals[1] == "WinEnter" then
          win_enter_callback = call.vals[2].callback
          break
        end
      end

      assert.is_function(win_enter_callback)

      -- Reset spies
      mock_vim.fn.jobresize = spy.new(function() end)
      mock_vim.defer_fn = spy.new(function(fn, delay)
        fn()
      end)

      -- Call the callback (entering any window when terminal exists)
      win_enter_callback()

      -- defer_fn should be called
      assert.spy(mock_vim.defer_fn).was_called()

      -- Since our mock immediately executes the deferred function, jobresize should be called
      assert.spy(mock_vim.fn.jobresize).was_called()
    end)

    it("should NOT restore configured width on WinEnter (allows manual resizing)", function()
      mock_vim.o = { columns = 200 }
      mock_vim.wo = setmetatable({}, {
        __index = function()
          return {}
        end,
        __newindex = function() end,
      })
      mock_vim.cmd = spy.new(function() end)
      mock_vim.api.nvim_win_set_width = spy.new(function() end)
      mock_vim.api.nvim_get_current_tabpage = spy.new(function()
        return 1
      end)

      local terminal_win = 2000
      mock_vim.api.nvim_tabpage_list_wins = spy.new(function()
        return { terminal_win }
      end)
      mock_vim.bo = setmetatable({}, {
        __index = function()
          return { buftype = "terminal", channel = 123 }
        end,
      })
      mock_vim.api.nvim_win_is_valid = spy.new(function()
        return true
      end)
      mock_vim.api.nvim_win_get_buf = spy.new(function()
        return 1
      end)

      window_manager.setup({ split_width_percentage = 0.4 })

      local win_enter_callback
      for _, call in ipairs(mock_vim.api.nvim_create_autocmd.calls) do
        if call.vals[1] == "WinEnter" then
          win_enter_callback = call.vals[2].callback
          break
        end
      end

      assert.is_function(win_enter_callback)

      -- Reset spies after setup
      mock_vim.fn.jobresize = spy.new(function() end)
      mock_vim.api.nvim_win_set_width = spy.new(function() end)
      mock_vim.defer_fn = spy.new(function(fn, delay)
        fn()
      end)

      win_enter_callback()

      -- jobresize should be called (notify_resize works)
      assert.spy(mock_vim.fn.jobresize).was_called()

      -- BUT nvim_win_set_width should NOT be called (no width restoration on WinEnter)
      assert.spy(mock_vim.api.nvim_win_set_width).was_not_called()
    end)

    it("should not call notify_resize when no terminal in tab", function()
      -- Mock additional APIs
      mock_vim.o = { columns = 200 }
      mock_vim.wo = setmetatable({}, {
        __index = function()
          return {}
        end,
        __newindex = function() end,
      })
      mock_vim.cmd = spy.new(function() end)
      mock_vim.api.nvim_win_set_width = spy.new(function() end)
      mock_vim.api.nvim_get_current_tabpage = spy.new(function()
        return 1
      end)

      -- Mock find_terminal_window to return nil (no terminal in tab)
      mock_vim.api.nvim_tabpage_list_wins = spy.new(function()
        return { 1001 } -- A non-terminal window
      end)
      mock_vim.bo = setmetatable({}, {
        __index = function()
          return { buftype = "", channel = 0 } -- Not a terminal
        end,
      })
      mock_vim.api.nvim_win_is_valid = spy.new(function()
        return true
      end)
      mock_vim.api.nvim_win_get_buf = spy.new(function()
        return 1
      end)

      window_manager.setup({})

      -- Find the WinEnter callback
      local win_enter_callback
      for _, call in ipairs(mock_vim.api.nvim_create_autocmd.calls) do
        if call.vals[1] == "WinEnter" then
          win_enter_callback = call.vals[2].callback
          break
        end
      end

      assert.is_function(win_enter_callback)

      -- Reset spies
      mock_vim.fn.jobresize = spy.new(function() end)
      mock_vim.defer_fn = spy.new(function(fn, delay)
        fn()
      end)

      -- Call the callback
      win_enter_callback()

      -- defer_fn should not be called since no terminal in tab
      assert.spy(mock_vim.defer_fn).was_not_called()

      -- jobresize should not be called
      assert.spy(mock_vim.fn.jobresize).was_not_called()
    end)
  end)

  describe("TabEnter autocommand callback", function()
    it("should find terminal window and call notify_resize when switching tabs", function()
      -- Mock additional APIs needed for window creation
      mock_vim.o = { columns = 200 }
      mock_vim.wo = setmetatable({}, {
        __index = function()
          return {}
        end,
        __newindex = function() end,
      })
      mock_vim.cmd = spy.new(function() end)
      mock_vim.api.nvim_win_set_width = spy.new(function() end)
      mock_vim.api.nvim_get_current_tabpage = spy.new(function()
        return 1
      end)

      -- Mock find_terminal_window to return a terminal window in the new tab
      local terminal_win_in_tab = 2000
      mock_vim.api.nvim_tabpage_list_wins = spy.new(function()
        return { terminal_win_in_tab }
      end)
      mock_vim.bo = setmetatable({}, {
        __index = function(_, bufnr)
          return { buftype = "terminal", channel = 123 }
        end,
      })

      window_manager.setup({})

      -- Find the TabEnter callback
      local tab_enter_callback
      for _, call in ipairs(mock_vim.api.nvim_create_autocmd.calls) do
        if call.vals[1] == "TabEnter" then
          tab_enter_callback = call.vals[2].callback
          break
        end
      end

      assert.is_function(tab_enter_callback)

      -- Mock the terminal window validation and dimensions
      mock_vim.api.nvim_win_is_valid = spy.new(function(win)
        return win == terminal_win_in_tab
      end)
      mock_vim.api.nvim_win_get_buf = spy.new(function()
        return 1
      end)

      -- Reset spies
      mock_vim.fn.jobresize = spy.new(function() end)
      mock_vim.defer_fn = spy.new(function(fn, delay)
        fn()
      end)

      -- Call the callback (simulating tab switch)
      tab_enter_callback()

      -- defer_fn should be called
      assert.spy(mock_vim.defer_fn).was_called()

      -- Since our mock immediately executes the deferred function, jobresize should be called
      assert.spy(mock_vim.fn.jobresize).was_called()
    end)

    it("should restore configured width when switching tabs", function()
      -- Mock additional APIs needed for window creation
      mock_vim.o = { columns = 200 }
      mock_vim.wo = setmetatable({}, {
        __index = function()
          return {}
        end,
        __newindex = function() end,
      })
      mock_vim.cmd = spy.new(function() end)
      mock_vim.api.nvim_win_set_width = spy.new(function() end)
      mock_vim.api.nvim_get_current_tabpage = spy.new(function()
        return 1
      end)

      -- Mock find_terminal_window to return a terminal window in the new tab
      local terminal_win_in_tab = 2000
      mock_vim.api.nvim_tabpage_list_wins = spy.new(function()
        return { terminal_win_in_tab }
      end)
      mock_vim.bo = setmetatable({}, {
        __index = function(_, bufnr)
          return { buftype = "terminal", channel = 123 }
        end,
      })

      window_manager.setup({ split_width_percentage = 0.35 })

      -- Find the TabEnter callback
      local tab_enter_callback
      for _, call in ipairs(mock_vim.api.nvim_create_autocmd.calls) do
        if call.vals[1] == "TabEnter" then
          tab_enter_callback = call.vals[2].callback
          break
        end
      end

      assert.is_function(tab_enter_callback)

      -- Mock the terminal window validation and dimensions
      mock_vim.api.nvim_win_is_valid = spy.new(function(win)
        return win == terminal_win_in_tab
      end)
      mock_vim.api.nvim_win_get_buf = spy.new(function()
        return 1
      end)

      -- Reset spies
      mock_vim.fn.jobresize = spy.new(function() end)
      mock_vim.api.nvim_win_set_width = spy.new(function() end)
      mock_vim.defer_fn = spy.new(function(fn, delay)
        fn()
      end)

      -- Call the callback (simulating tab switch)
      tab_enter_callback()

      -- nvim_win_set_width should be called with configured percentage (200 * 0.35 = 70)
      assert.spy(mock_vim.api.nvim_win_set_width).was_called_with(terminal_win_in_tab, 70)
    end)

    it("should use default 40% width when split_width_percentage not configured", function()
      -- Mock additional APIs needed for window creation
      mock_vim.o = { columns = 200 }
      mock_vim.wo = setmetatable({}, {
        __index = function()
          return {}
        end,
        __newindex = function() end,
      })
      mock_vim.cmd = spy.new(function() end)
      mock_vim.api.nvim_win_set_width = spy.new(function() end)
      mock_vim.api.nvim_get_current_tabpage = spy.new(function()
        return 1
      end)

      local terminal_win_in_tab = 2000
      mock_vim.api.nvim_tabpage_list_wins = spy.new(function()
        return { terminal_win_in_tab }
      end)
      mock_vim.bo = setmetatable({}, {
        __index = function(_, bufnr)
          return { buftype = "terminal", channel = 123 }
        end,
      })

      -- Setup with no split_width_percentage (should default to 0.4)
      window_manager.setup({})

      local tab_enter_callback
      for _, call in ipairs(mock_vim.api.nvim_create_autocmd.calls) do
        if call.vals[1] == "TabEnter" then
          tab_enter_callback = call.vals[2].callback
          break
        end
      end

      mock_vim.api.nvim_win_is_valid = spy.new(function(win)
        return win == terminal_win_in_tab
      end)
      mock_vim.api.nvim_win_get_buf = spy.new(function()
        return 1
      end)
      mock_vim.fn.jobresize = spy.new(function() end)
      mock_vim.api.nvim_win_set_width = spy.new(function() end)
      mock_vim.defer_fn = spy.new(function(fn, delay)
        fn()
      end)

      tab_enter_callback()

      -- Should use default 40%: 200 * 0.4 = 80
      assert.spy(mock_vim.api.nvim_win_set_width).was_called_with(terminal_win_in_tab, 80)
    end)

    it("should not call notify_resize when no terminal window in new tab", function()
      -- Mock additional APIs
      mock_vim.o = { columns = 200 }
      mock_vim.wo = setmetatable({}, {
        __index = function()
          return {}
        end,
        __newindex = function() end,
      })
      mock_vim.cmd = spy.new(function() end)
      mock_vim.api.nvim_win_set_width = spy.new(function() end)
      mock_vim.api.nvim_get_current_tabpage = spy.new(function()
        return 1
      end)

      -- Mock find_terminal_window to return nil (no terminal in this tab)
      mock_vim.api.nvim_tabpage_list_wins = spy.new(function()
        return { 1001 } -- A non-terminal window
      end)
      mock_vim.bo = setmetatable({}, {
        __index = function(_, bufnr)
          return { buftype = "", channel = 0 } -- Not a terminal
        end,
      })
      mock_vim.api.nvim_win_is_valid = spy.new(function()
        return true
      end)
      mock_vim.api.nvim_win_get_buf = spy.new(function()
        return 1
      end)

      window_manager.setup({})

      -- Find the TabEnter callback
      local tab_enter_callback
      for _, call in ipairs(mock_vim.api.nvim_create_autocmd.calls) do
        if call.vals[1] == "TabEnter" then
          tab_enter_callback = call.vals[2].callback
          break
        end
      end

      assert.is_function(tab_enter_callback)

      -- Reset spies
      mock_vim.fn.jobresize = spy.new(function() end)
      mock_vim.defer_fn = spy.new(function(fn, delay)
        fn()
      end)

      -- Call the callback (simulating tab switch)
      tab_enter_callback()

      -- defer_fn should not be called since no terminal window found
      assert.spy(mock_vim.defer_fn).was_not_called()

      -- jobresize should not be called
      assert.spy(mock_vim.fn.jobresize).was_not_called()
    end)
  end)
end)
