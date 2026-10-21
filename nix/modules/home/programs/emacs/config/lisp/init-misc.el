;;; init-misc.el --- init-misc -*- lexical-binding: t; -*-


;;; Commentary:
;;

;;; Code:

(declare-function flymake-mode "flymake")
(declare-function eglot-managed-p "eglot")
(declare-function hl-todo-flymake "hl-todo")
(defvar flymake-diagnostic-functions)

(defun my/hl-todo-flymake-setup ()
	"現在のbufferでhl-todoのFlymake diagnosticsを有効化する。."
	(add-hook 'flymake-diagnostic-functions #'hl-todo-flymake nil t)
	(flymake-mode 1))

(defun my/eglot-hl-todo-flymake-setup ()
	"Eglotがbackendを置き換えた後にhl-todoのdiagnosticsを戻す."
	(when (and (eglot-managed-p) (bound-and-true-p hl-todo-mode))
		(my/hl-todo-flymake-setup)))

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

(use-package hl-todo
	:hook (prog-mode . hl-todo-mode)
	:init
	(add-hook 'prog-mode-hook #'my/hl-todo-flymake-setup 90)
	(add-hook 'eglot-managed-mode-hook #'my/eglot-hl-todo-flymake-setup))

(with-eval-after-load 'project
	(add-to-list 'project-vc-extra-root-markers
		".luarc.json"))

(provide 'init-misc)

;;; init-misc.el ends here
