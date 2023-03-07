local Pkg = require "mason-core.package"
local pip3 = require "mason-core.managers.pip3"

return Pkg.new {
    name = "python-lsp-ruff",
    desc = [[Linter plugin for pylsp based using ruff. Formatting via ruff's]],
    homepage = "https://github.com/python-lsp/python-lsp-ruff",
    languages = { Pkg.Lang.Python },
    categories = { Pkg.Cat.LSP },
    install = pip3.packages { "python-lsp-ruff", bin = { "pylsp" } },
}
