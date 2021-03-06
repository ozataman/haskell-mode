VERSION = $(shell git describe --tags --match 'v[0-9]*' --abbrev=0 | sed 's/^v//;s/\.0*/./g')
GIT_VERSION = $(shell git describe --tags --match 'v[0-9]*' --long --dirty | sed 's/^v//')

INSTALL_INFO = install-info
EMACS = emacs
EFLAGS = --eval "(add-to-list 'load-path (expand-file-name \"tests/compat\") 'append)" \
         --eval "(when (< emacs-major-version 24) \
                    (setq byte-compile-warnings '(not cl-functions)))" \
         --eval '(setq byte-compile-error-on-warn t)'

BATCH = $(EMACS) $(EFLAGS) --batch -Q -L .
SUBST_ATAT = sed -e 's/@@GIT_VERSION@@/$(GIT_VERSION)/g;s/@GIT_VERSION@/$(GIT_VERSION)/g;s/@@VERSION@@/$(VERSION)/g;s/@VERSION@/$(VERSION)/g'

ELFILES = \
	ghc-core.el \
	ghci-script-mode.el \
	highlight-uses-mode.el \
	haskell-align-imports.el \
	haskell-bot.el \
	haskell-cabal.el \
	haskell-c.el \
	haskell-checkers.el \
	haskell-collapse.el \
	haskell-modules.el \
	haskell-sandbox.el \
	haskell-commands.el \
	haskell-compat.el \
	haskell-compile.el \
	haskell-complete-module.el \
	haskell-customize.el \
	haskell-debug.el \
	haskell-decl-scan.el \
	haskell-doc.el \
	haskell.el \
	haskell-font-lock.el \
	haskell-indentation.el \
	haskell-indent.el \
	haskell-interactive-mode.el \
	haskell-load.el \
	haskell-menu.el \
	haskell-mode.el \
	haskell-move-nested.el \
	haskell-navigate-imports.el \
	haskell-package.el \
	haskell-presentation-mode.el \
	haskell-process.el \
	haskell-repl.el \
	haskell-session.el \
	haskell-show.el \
	haskell-simple-indent.el \
	haskell-sort-imports.el \
	haskell-str.el \
	haskell-string.el \
	haskell-unicode-input-method.el \
	haskell-utils.el \
	haskell-yas.el \
	inf-haskell.el

ELCFILES = $(ELFILES:.el=.elc)
AUTOLOADS = haskell-mode-autoloads.el

PKG_DIST_FILES = $(ELFILES) logo.svg NEWS haskell-mode.info dir
PKG_TAR = haskell-mode-$(VERSION).tar
ELCHECKS=$(addprefix check-, $(ELFILES:.el=))

%.elc: %.el
	@$(BATCH) \
		 -f batch-byte-compile $*.el

.PHONY: all compile info clean check $(ELCHECKS) elpa package

all: compile $(AUTOLOADS) info

compile: $(ELCFILES)

$(ELCHECKS): check-%: %.el %.elc
	@$(BATCH) --eval '(when (check-declare-file "$*.el") (error "check-declare failed"))'
	@if [ -f "$(<:%.el=tests/%-tests.el)" ]; then \
		$(BATCH) -l "$(<:%.el=tests/%-tests.el)" -f ert-run-tests-batch-and-exit; \
	fi
	@echo "--"

check: $(ELCHECKS)
	@echo "checks passed!"

clean:
	$(RM) $(ELCFILES) $(AUTOLOADS) $(AUTOLOADS:.el=.elc) $(PKG_TAR) haskell-mode.tmp.texi haskell-mode.info dir

info: haskell-mode.info dir

dir: haskell-mode.info
	$(INSTALL_INFO) --dir=$@ $<

haskell-mode.tmp.texi: haskell-mode.texi
	@sed -n -e '/@chapter/ s/@code{\(.*\)}/\1/' \
                -e 's/@chapter \(.*\)$$/* \1::/p' \
                -e 's/@unnumbered \(.*\)$$/* \1::/p' \
               haskell-mode.texi > haskell-mode-menu-order.txt
	@sed -e '1,/@menu/ d' \
            -e '/end menu/,$$ d' \
            haskell-mode.texi > haskell-mode-content-order.txt
	diff -C 1 haskell-mode-menu-order.txt haskell-mode-content-order.txt
	@rm haskell-mode-menu-order.txt haskell-mode-content-order.txt

	$(SUBST_ATAT) < haskell-mode.texi > haskell-mode.tmp.texi

haskell-mode.info: haskell-mode.tmp.texi
	$(MAKEINFO) $(MAKEINFO_FLAGS) -o $@ $<

haskell-mode.html: haskell-mode.tmp.texi
	$(MAKEINFO) $(MAKEINFO_FLAGS) --html --no-split -o $@ $<

# Generate ELPA-compatible package
package: $(PKG_TAR)
elpa: $(PKG_TAR)

$(PKG_TAR): $(PKG_DIST_FILES) haskell-mode-pkg.el.in
	rm -rf haskell-mode-$(VERSION)
	mkdir haskell-mode-$(VERSION)
	cp $(PKG_DIST_FILES) haskell-mode-$(VERSION)/
	$(SUBST_ATAT) < haskell-mode-pkg.el.in > haskell-mode-$(VERSION)/haskell-mode-pkg.el
	$(SUBST_ATAT) < haskell-mode.el > haskell-mode-$(VERSION)/haskell-mode.el
	(sed -n -e '/^;;; Commentary/,/^;;;/p' | egrep '^;;( |$$)' | cut -c4-) < haskell-mode.el > haskell-mode-$(VERSION)/README
	tar cvf $@ haskell-mode-$(VERSION)
	rm -rf haskell-mode-$(VERSION)
	@echo
	@echo "Created ELPA compatible distribution package '$@' from $(GIT_VERSION)"

$(AUTOLOADS): $(ELFILES) haskell-mode.elc
	$(BATCH) \
		--eval '(setq make-backup-files nil)' \
		--eval '(setq generated-autoload-file "$(CURDIR)/$@")' \
		-f batch-update-autoloads "."

# HACK: embed version number into .elc file
haskell-mode.elc: haskell-mode.el
	$(SUBST_ATAT) < haskell-mode.el > haskell-mode.tmp.el
	@$(BATCH) -f batch-byte-compile haskell-mode.tmp.el
	mv haskell-mode.tmp.elc haskell-mode.elc
	$(RM) haskell-mode.tmp.el
