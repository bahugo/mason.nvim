local Pkg = require "mason-core.package"
local pip3 = require "mason-core.managers.pip3"

return Pkg.new {
    name = "python-lsp-ruff",
    desc = [[ Linter plugin for pylsp based using ruff. Formatting via ruff's. Allows to use ruff in pylsp. WARNING : python-lsp-server must be uninstalled before]],
    homepage = "https://github.com/python-lsp/python-lsp-ruff",
    languages = { Pkg.Lang.Python },
    categories = { Pkg.Cat.LSP },
    install = pip3.packages { "python-lsp-ruff", bin = { "pyslp" } },

}
