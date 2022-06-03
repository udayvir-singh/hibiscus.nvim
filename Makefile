INSTALL_DIR = ~/.local/share/nvim/site/pack/tangerine/start/hibiscus.nvim

ifndef VERBOSE
.SILENT:
endif

.ONESHELL:

default: help

# ------------------- #
#      BUILDING       #
# ------------------- #
vimdoc:
	[ -d doc ] || mkdir doc
	./scripts/docs README.md ./doc/hibiscus.txt
	echo :: GENERATING HELPTAGS
	nvim -n --noplugin --headless -c "helptags doc" -c "q" doc/hibiscus.txt

install:
	[ -d $(INSTALL_DIR) ] || mkdir -p $(INSTALL_DIR)
	ln -srf fnl lua doc $(INSTALL_DIR)
	echo :: FINISHED INSTALLING

uninstall:
	rm -rf $(INSTALL_DIR)
	echo :: FINISHED UNINSTALLING


# ------------------- #
#        INFO         #
# ------------------- #
define HELP
| Usage: make [target] ...
|
| Targets:
|   :vimdoc              runs panvimdoc to generate vimdocs
|   :install             install macros inside plugin dir
|   :uninstall           removes macros from plugin dir
endef

help:
	if command -v bat &>/dev/null; then
		echo "$(HELP)" | sed "s:^| \{0,1\}::" | bat -p -l clj --theme=ansi
	else
		echo "$(HELP)" | sed "s:^| \{0,1\}::" | less -F
	fi
