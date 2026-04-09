;;; -*- lexical-binding: t; -*-

(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file nil 'nomessage))


(require 'init-core)
(require 'init-ui)
(require 'init-search)
(require 'init-edit)
(require 'init-lsp)
(require 'init-navi)
(require 'init-misc)
(require 'init-ts)
(require 'init-org)
