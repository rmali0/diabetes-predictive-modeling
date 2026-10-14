# Load the project helpers (no package build needed).
root <- normalizePath(file.path(testthat::test_path(), "..", ".."))
for (f in list.files(file.path(root, "R"), pattern = "[.]R$", full.names = TRUE)) source(f)
fixture <- function(name) file.path(testthat::test_path(), "fixtures", name)
