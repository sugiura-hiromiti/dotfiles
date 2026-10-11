;;; init-misc.el --- init-misc -*- lexical-binding: t; -*-


;;; Commentary:
;;

;;; Code:

(declare-function flymake-mode "flymake")
(declare-function hl-todo-flymake "hl-todo")
(defvar flymake-diagnostic-functions)

(defun my/hl-todo-flymake-setup ()
	"現在のbufferでhl-todoのFlymake diagnosticsを有効化する。."
	(add-hook 'flymake-diagnostic-functions #'hl-todo-flymake nil t)
	(flymake-mode 1))

(use-package ghostel
	:commands (ghostel
					 ghostel-compile
					 ghostel-project
					 ghostel-project-list-buffers
					 ghostel-list-buffers)
	:custom
	(ghostel-module-auto-install 'download)
	(ghostel-max-scrollback (* 10 1024 1024)))

(use-package diff-hl
	:config
	(global-diff-hl-mode)
	(diff-hl-flydiff-mode 1))

(use-package majutsu
	:vc (:url "https://github.com/0WD0/majutsu"
			 :rev :newest))

(use-package envrc
	:hook (after-init . envrc-global-mode))

;; TODO: 現在壊れてる(特にhl-todo-flymake)ので修正する
(use-package hl-todo
	:hook (prog-mode . hl-todo-mode)
	:init
	(add-hook 'prog-mode-hook #'my/hl-todo-flymake-setup 90))

(provide 'init-misc)

;;; init-misc.el ends here
