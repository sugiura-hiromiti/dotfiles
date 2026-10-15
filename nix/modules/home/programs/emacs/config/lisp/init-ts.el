;;; init-ts.el --- treesitter config -*- lexical-binding: t; -*-


;;; Commentary:
;;

(require 'treesit)

(setopt
	treesit-font-lock-level 4
	treesit-auto-install-grammar 'always
	treesit-enabled-modes
	'(rust-ts-mode
		 json-ts-mode
		 toml-ts-mode
		 lua-ts-mode
		 yaml-ts-mode))

(add-to-list
	'treesit-language-source-alist
	'(nix "https://github.com/nix-community/tree-sitter-nix"))

(add-to-list
	'treesit-language-source-alist
	'(nu "https://github.com/nushell/tree-sitter-nu"))

(add-to-list
	'treesit-language-source-alist
	'(kdl "https://github.com/tree-sitter-grammars/tree-sitter-kdl"))

(add-to-list
	'treesit-language-source-alist
	'(haskell "https://github.com/tree-sitter/tree-sitter-haskell"))

(dolist (language '(nix nu kdl haskell))
	(treesit-ensure-installed language))

;;; Code:

(declare-function treesit-available-p "treesit")
(declare-function treesit-language-available-p "treesit")
(defvar major-mode-remap-alist)
(defvar treesit-font-lock-level)
(defvar warning-suppress-log-types nil)
(defvar warning-suppress-types nil)

(use-package md-ts-mode
	:config
	(md-ts-mode-enable-global))

(use-package nix-ts-mode)

(use-package kdl-ts-mode
	:vc (:url "https://github.com/dataphract/kdl-ts-mode"
			 :rev :newest)
	:config
	(setq kdl-ts-mode-indent-offset 3))

(use-package treesit-auto
	:demand t
	:custom
	(treesit-auto-install t)
	:config
	(treesit-auto-add-to-auto-mode-alist 'all)
	(global-treesit-auto-mode 1))

(provide 'init-ts)

;;; init-ts.el ends here
