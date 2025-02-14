local path = require "mason-core.path"
local Result = require "mason-core.result"
local platform = require "mason-core.platform"
local _ = require "mason-core.functional"
local log = require "mason-core.log"
local fs = require "mason-core.fs"
local a = require "mason-core.async"

local M = {}

---@alias LinkContext { type: '"bin"' | '"opt"' | '"share"', prefix: fun(path: string): string }

---@type table<'"BIN"' | '"OPT"' | '"SHARE"', LinkContext>
local LinkContext = {
    BIN = { type = "bin", prefix = path.bin_prefix },
    OPT = { type = "opt", prefix = path.opt_prefix },
    SHARE = { type = "share", prefix = path.share_prefix },
}

---@param receipt InstallReceipt
---@param link_context LinkContext
local function unlink(receipt, link_context)
    return Result.pcall(function()
        local links = receipt.links[link_context.type]
        if not links then
            return
        end
        for linked_file in pairs(links) do
            if receipt.schema_version == "1.0" and link_context == LinkContext.BIN and platform.is.win then
                linked_file = linked_file .. ".cmd"
            end
            local share_path = link_context.prefix(linked_file)
            fs.sync.unlink(share_path)
        end
    end)
end

---@param pkg Package
---@param receipt InstallReceipt
---@nodiscard
function M.unlink(pkg, receipt)
    log.fmt_debug("Unlinking %s", pkg, receipt.links)
    return Result.try(function(try)
        try(unlink(receipt, LinkContext.BIN))
        try(unlink(receipt, LinkContext.SHARE))
        try(unlink(receipt, LinkContext.OPT))
    end)
end

---@async
---@param context InstallContext
---@param link_context LinkContext
---@param link_fn async fun(dest: string, target: string): Result
local function link(context, link_context, link_fn)
    log.trace("Linking", context.package, link_context.type, context.links[link_context.type])
    return Result.try(function(try)
        for name, rel_path in pairs(context.links[link_context.type]) do
            if platform.is.win and link_context == LinkContext.BIN then
                name = ("%s.cmd"):format(name)
            end
            local dest_abs_path = link_context.prefix(name)
            local target_abs_path = path.concat { context.package:get_install_path(), rel_path }

            do
                -- 1. Ensure destination directory exists
                if vim.in_fast_event() then
                    a.scheduler()
                end

                local dir = vim.fn.fnamemodify(dest_abs_path, ":h")
                if not fs.async.dir_exists(dir) then
                    try(Result.pcall(fs.async.mkdirp, dir))
                end
            end

            do
                -- 2. Ensure source file exists and target doesn't yet exist OR if --force unlink target if it already
                -- exists.
                if context.opts.force then
                    if fs.async.file_exists(dest_abs_path) then
                        try(Result.pcall(fs.async.unlink, dest_abs_path))
                    end
                elseif fs.async.file_exists(dest_abs_path) then
                    return Result.failure(("%q is already linked."):format(dest_abs_path, name))
                end
                if not fs.async.file_exists(target_abs_path) then
                    return Result.failure(("Link target %q does not exist."):format(target_abs_path))
                end
            end

            -- 3. Execute link.
            try(link_fn(dest_abs_path, target_abs_path))
            context.receipt:with_link(link_context.type, name, rel_path)
        end
    end)
end

---@param context InstallContext
---@param link_context LinkContext
local function symlink(context, link_context)
    return link(context, link_context, function(target, dest)
        return Result.pcall(fs.async.symlink, dest, target)
    end)
end

---@param context InstallContext
local function win_bin_wrapper(context)
    return link(context, LinkContext.BIN, function(dest, target)
        return Result.pcall(
            fs.async.write_file,
            dest,
            _.dedent(([[
                @ECHO off
                GOTO start
                :find_dp0
                SET dp0=%%~dp0
                EXIT /b
                :start
                SETLOCAL
                CALL :find_dp0

                endLocal & goto #_undefined_# 2>NUL || title %%COMSPEC%% & "%s" %%*
            ]]):format(target))
        )
    end)
end

---@async
---@param context InstallContext
---@nodiscard
function M.link(context)
    log.fmt_debug("Linking %s", context.package)
    return Result.try(function(try)
        if platform.is.win then
            try(win_bin_wrapper(context))
        else
            try(symlink(context, LinkContext.BIN))
        end
        try(symlink(context, LinkContext.SHARE))
        try(symlink(context, LinkContext.OPT))
    end)
end

return M
