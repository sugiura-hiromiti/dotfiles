;;; -*- lexical-binding: t; -*-

(declare-function flymake-mode "flymake")
(declare-function hl-todo-flymake "hl-todo")
(defvar flymake-diagnostic-functions)

(defun my/hl-todo-flymake-setup ()
  "現在のbufferでhl-todoのFlymake diagnosticsを有効化する。"
  (add-hook 'flymake-diagnostic-functions #'hl-todo-flymake nil t)
  (flymake-mode 1))

(use-package eat
  :ensure t
  :commands (eat))

(use-package diff-hl
  :config
  (global-diff-hl-mode)
  (diff-hl-flydiff-mode)
  (diff-hl-margin-mode))

(use-package majutsu
  :vc (:url "https://github.com/0WD0/majutsu"))

(use-package envrc
  :hook (after-init . envrc-global-mode))

(use-package hl-todo
  :hook ((prog-mode . hl-todo-mode)
			(prog-mode . my/hl-todo-flymake-setup)))

(provide 'init-misc)
