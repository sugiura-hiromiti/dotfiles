;;; -*- lexical-binding: t; -*-

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
			(prog-mode . my-hl-todo-flymake-setup)))


(defun my-hl-todo-flymake-setup ()
  (add-hook 'flymake-diagnostic-functions #'hl-todo-flymake nil t)
  (flymake-mode 1))

(provide 'init-misc)
