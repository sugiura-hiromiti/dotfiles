;;; -*- lexical-binding: t; -*-

(setq native-comp-jit-compilation nil)

;; Some VC packages declare a dependency on the built-in `treesit' library.
;; `treesit' is not listed as a package in Emacs 30, so package activation
;; otherwise reports "Required package `treesit-0' is unavailable".
(with-eval-after-load 'package
	(require 'finder-inf nil t)
	(unless (assq 'treesit package--builtins)
		(push `(treesit . ,(package-make-builtin nil "Tree-sitter support"))
					package--builtins)))

;; Keep Emacs from resizing its outer frame while OmniWM controls it.
(setq frame-inhibit-implied-resize t
      frame-resize-pixelwise t)

(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
