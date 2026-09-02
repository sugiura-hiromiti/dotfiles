;;; init-edit.el --- Summary -*- lexical-binding: t; -*-

;;; Commentary:

;;; Code:

(declare-function meow-bounds-of-thing "meow-command")
(declare-function meow-cancel-selection "meow-command")
(declare-function meow-grab "meow-command")
(declare-function meow-pop-selection "meow-command")
(declare-function meow-thing-register "meow-thing")

(require 'my-treewalk)

(use-package puni :init (puni-global-mode))

(use-package embrace)

(use-package
	meow
	:after (pretty-hydra)
	:config
	(defun my/meow-setup ()
		(setq meow-cheatsheet-layout meow-cheatsheet-layout-qwerty)

		(meow-motion-define-key
			'("j" . meow-next)
			'("k" . meow-prev)
			'("/" . command-palette/body)
			'("." . meta-navigation/body)
			'("x" . meow-line)
			'("y" . meow-save)
			'(":" . execute-extended-command)
			'(";" . eval-expression)
			'("<escape>" . ignore))

		(meow-leader-define-key
			'("1" . meow-digit-argument)
			'("2" . meow-digit-argument)
			'("3" . meow-digit-argument)
			'("4" . meow-digit-argument)
			'("5" . meow-digit-argument)
			'("6" . meow-digit-argument)
			'("7" . meow-digit-argument)
			'("8" . meow-digit-argument)
			'("9" . meow-digit-argument)
			'("0" . meow-digit-argument))
		(meow-normal-define-key
			'("1" . meow-expand-1)
			'("2" . meow-expand-2)
			'("3" . meow-expand-3)
			'("4" . meow-expand-4)
			'("5" . meow-expand-5)
			'("6" . meow-expand-6)
			'("7" . meow-expand-7)
			'("8" . meow-expand-8)
			'("9" . meow-expand-9)
			'("0" . meow-expand-0)
			'("-" . negative-argument)
			'(":" . execute-extended-command)
			'(";" . eval-expression)
			'("/" . command-palette/body)
			'("." . meta-navigation/body)
			'("<up>" . my/meow-treesit-up)
			'("<down>" . my/meow-treesit-down)
			'("<right>" . my/meow-treesit-in)
			'("<left>" . my/meow-treesit-out)
			'("<escape>" . ignore)
			'("a" . meow-append)
			'("A" . embrace-add)
			'("b" . meow-back-word)
			'("B" . meow-back-symbol)
			'("c" . meow-change)
			'("C" . embrace-change)
			'("d" . meow-delete)
			'("D" . embrace-delete)
			'("e" . meow-next-word)
			'("E" . meow-next-symbol)
			'("f" . meow-find)
			'("g" . my/meow-treesit-expand)
			'("G" . my/meow-treesit-contract)
			'("h" . meow-left)
			'("H" . meow-left-expand)
			'("i" . meow-insert)
			'("j" . meow-next)
			'("J" . meow-next-expand) ;; 要らないかも
			'("k" . meow-prev)
			'("K" . meow-prev-expand) ;; 要らないかも
			'("l" . meow-right)
			'("L" . meow-right-expand)
			'("o" . meow-open-below)
			'("O" . meow-open-above)
			'("p" . meow-yank)
			'("q" . meow-goto-line)
			'("r" . meow-reverse)
			'("s" . meow-kill)
			'("t" . comment-dwim)
			'("u" . meow-undo)
			'("x" . meow-line)
			'("y" . meow-save)
													 ; '("z" . meow-pop-selection)
			))
	(meow-thing-register
		'my/treesit-node
		(lambda () (my/treesit-treewalk-node-bounds))
		(lambda () (my/treesit-treewalk-node-bounds)))
	(setf (alist-get ?n meow-char-thing-table) 'my/treesit-node)
	(my/meow-setup) (meow-global-mode 1)

	(defun my/save-some-buffers-when-meow-insert-exit (&rest _)
		"Save modified file-visiting buffers without confirmation.
Runs when leaving Meow insert mode."
		(condition-case err
			(save-some-buffers t)
			(error
				(message "save-some-buffers failed: %s" (error-message-string err)))))
	(advice-add #'meow-insert-exit
		:before
		#'my/save-some-buffers-when-meow-insert-exit)
	:custom (meow-use-clipboard t))

(defun my/meow-treesit-expand ()
	"Tree-sitter nodeを選択し、parserがなければPuniへfallbackする。"
	(interactive)
	(if (my/treesit-treewalk-available-p)
		(meow-bounds-of-thing ?n)
		(call-interactively #'puni-expand-region)))

(defun my/meow-treesit-contract ()
	"Tree-sitter選択を1段戻し、選択がなければMeow Grabを使う。"
	(interactive)
	(if (and (my/treesit-treewalk-available-p) (use-region-p))
		(call-interactively #'meow-pop-selection)
		(call-interactively #'meow-grab)))

(defun my/meow-treesit--move (command count)
	"構造移動COMMAND後、既存のMeow選択を移動先へ同期する。"
	(let ((had-selection (use-region-p))
			  (has-parser (my/treesit-treewalk-available-p)))
		(when had-selection
			(meow-cancel-selection))
		(funcall command (or count 1))
		(when (and had-selection has-parser)
			(my/meow-treesit-expand))))

;; TODO: treesitter supportやmodeによって実行関数を変える
(defun my/meow-treesit-up (&optional count)
	"構造的に上へ移動し、選択があれば移動先を選択する。"
	(interactive "p")
	(my/meow-treesit--move #'my/treesit-treewalk-up count))

;; TODO: treesitter supportやmodeによって実行関数を変える
(defun my/meow-treesit-down (&optional count)
	"構造的に下へ移動し、選択があれば移動先を選択する。"
	(interactive "p")
	(my/meow-treesit--move #'my/treesit-treewalk-down count))

;; TODO: treesitter supportやmodeによって実行関数を変える
(defun my/meow-treesit-in (&optional count)
	"構造の内側へ移動し、選択があれば移動先を選択する。"
	(interactive "p")
	(my/meow-treesit--move #'my/treesit-treewalk-in count))

;; TODO: treesitter supportやmodeによって実行関数を変える
(defun my/meow-treesit-out (&optional count)
	"構造の外側へ移動し、選択があれば移動先を選択する。"
	(interactive "p")
	(my/meow-treesit--move #'my/treesit-treewalk-out count))

;; NOTE: deprecated
(keymap-global-set "S-<down>" #'forward-paragraph)
(keymap-global-set "S-<up>" #'backward-paragraph)

;; NOTE: deprecated
(with-eval-after-load 'compile
	(keymap-set compilation-mode-map "S-<down>" #'next-error)
	(keymap-set compilation-mode-map "S-<up>" #'previous-error))

(with-eval-after-load 'meow
	(add-to-list 'meow-mode-state-list '(help-mode . normal))
	(add-to-list 'meow-mode-state-list '(messages-buffer-mode . normal))
	(add-to-list 'meow-mode-state-list '(compilation-mode . normal)))

(use-package tempel
	:init
	(defun my/tempel-setup-capf ()
		(add-hook 'completion-at-point-functions #'tempel-complete nil t))
	:hook
	((prog-mode text-mode conf-mode) . my/tempel-setup-capf))

(use-package eglot-tempel
	:preface (eglot-tempel-mode)
	:init
	(eglot-tempel-mode t))

(provide 'init-edit)
