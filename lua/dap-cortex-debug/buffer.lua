local utils = require('dap-cortex-debug.utils')

---@alias BufferSetWin fun(buf: number): number, function?

---@class CDBufferOpts
---Assigns terminal buffer to a window, return window and optional callback to call when terminal is ready.
---@field set_win BufferSetWin
---@field uri string
---@field on_delete? fun(b: CDBuffer)

---@class CDBuffer
---@field buf number
---@field on_delete? fun(b: CDBuffer)
local Buffer = utils.class()

local augroup = vim.api.nvim_create_augroup('CortexDebugBuffer', { clear = true })

---@type { [string]: CDBuffer }
local buffers = {}

---Create new buffer object with its buffer.
---NOTE: For terminals this needs to open a window, at least temporarily.
---Will delete previous buffer with the same URI. `get_or_new` can be used instead.
---@param opts CDBufferOpts
---@return CDBuffer
function Buffer:new(opts, instance)
    if buffers[opts.uri] then
        buffers[opts.uri]:delete()
    end

    local b = instance or self:_new()
    b.buf = nil
    b.on_delte = nil
    b.uri = opts.uri

    b:_create_buf(opts.set_win)
    b:_create_autocmds()

    buffers[b.uri] = b

    return b
end

function Buffer.get(uri)
    return buffers[uri]
end

function Buffer.get_or_new(opts)
    return Buffer.get(opts.uri) or Buffer:new(opts)
end

function Buffer:delete()
    pcall(vim.api.nvim_buf_delete, self.buf, { force = true })
end

---Set buffer URI
---@param uri string
function Buffer:set_uri(uri)
    if buffers[uri] then
        utils.error('Terminal with given URI already exists: "%s"', uri)
        return
    end
    -- TODO: set user friendly b:term_title?
    vim.api.nvim_buf_set_name(self.buf, uri)
    buffers[self.uri] = nil
    self.uri = uri
    buffers[self.uri] = self
end

-- Create terminal buffer
function Buffer:_create_buf(set_win)
    self.buf = vim.api.nvim_create_buf(true, true)
    self:set_uri(self.uri)

    local win, on_ready = set_win(self.buf)
    vim.api.nvim_set_option_value('number', false, { win = win, scope = 'local' })
    vim.api.nvim_set_option_value('relativenumber', false, { win = win, scope = 'local' })
    vim.api.nvim_set_option_value('spell', false, { win = win, scope = 'local' })

    self:_create_buf_final()

    if on_ready then
        on_ready(self)
    end
end

function Buffer:_create_buf_final() end

function Buffer:_create_autocmds()
    vim.api.nvim_create_autocmd('BufDelete', {
        group = augroup,
        buffer = self.buf,
        callback = function()
            buffers[self.uri] = nil
            if self.on_delete then
                self:on_delete()
            end
        end,
    })
end

function Buffer:is_visible()
    return vim.api.nvim_win_is_valid(vim.fn.bufwinid(self.buf))
end

function Buffer.temporary_win(buf)
    local curr_win = vim.api.nvim_get_current_win()
    local new_win = vim.api.nvim_open_win(buf, false, {
        relative = 'win',
        win = curr_win,
        width = vim.api.nvim_win_get_width(curr_win),
        height = vim.api.nvim_win_get_height(curr_win),
        row = 0,
        col = 0,
        style = 'minimal',
    })
    return new_win, function()
        vim.api.nvim_win_close(new_win, false)
    end
end

return Buffer