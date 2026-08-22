;;; -*- lexical-binding: t; -*-

(declare-function meow-bounds-of-thing "meow-command")
(declare-function meow-cancel-selection "meow-command")
(declare-function meow-grab "meow-command")
(declare-function meow-pop-selection "meow-command")
(declare-function meow-thing-register "meow-thing")
(declare-function my/treesit-treewalk-available-p "init-ts")
(declare-function my/treesit-treewalk-node-bounds "init-ts")
(declare-function my/treesit-treewalk-down "init-ts")
(declare-function my/treesit-treewalk-in "init-ts")
(declare-function my/treesit-treewalk-out "init-ts")
(declare-function my/treesit-treewalk-up "init-ts")

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
			'("RET" . my/meow-ret-dispatch)
			'("TAB" . meta-navigation/body)
			'("x" . meow-line)
			'("y" . meow-save)
			'("<escape>" . ignore))

		(meow-leader-define-key
			'("?" . meow-cheatsheet)
			'("/" . meow-keypad-describe-key)
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
			'("RET" . my/meow-ret-dispatch)
			'("TAB" . meta-navigation/body)
			'("DEL" . tree-sitter-operations/body)
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
													 ;'("I" . meow-open-above)
			'("j" . meow-next)
			'("J" . meow-next-expand) ;; 要らないかも
			'("k" . meow-prev)
			'("K" . meow-prev-expand) ;; 要らないかも
			'("l" . meow-right)
			'("L" . meow-right-expand)
													 ;'("o" . meow-block)
													 ;'("O" . meow-to-block)
			'("o" . meow-open-below)
			'("O" . meow-open-above)
			'("p" . meow-yank)
			'("q" . meow-goto-line)
			'("r" . meow-reverse)
			'("s" . meow-kill)
			'("S" . puni-transpose)
			'("t" . comment-dwim)
			'("u" . meow-undo)
			'("w" . meow-mark-word)
			;;'("W" . meow-mark-symbol)
			;; '("w" . puni-mark-sexp-at-point) ;; 要らないかも(gでことたりる)
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

(defun my/meow-treesit-up (&optional count)
	"構造的に上へ移動し、選択があれば移動先を選択する。"
	(interactive "p")
	(my/meow-treesit--move #'my/treesit-treewalk-up count))

(defun my/meow-treesit-down (&optional count)
	"構造的に下へ移動し、選択があれば移動先を選択する。"
	(interactive "p")
	(my/meow-treesit--move #'my/treesit-treewalk-down count))

(defun my/meow-treesit-in (&optional count)
	"構造の内側へ移動し、選択があれば移動先を選択する。"
	(interactive "p")
	(my/meow-treesit--move #'my/treesit-treewalk-in count))

(defun my/meow-treesit-out (&optional count)
	"構造の外側へ移動し、選択があれば移動先を選択する。"
	(interactive "p")
	(my/meow-treesit--move #'my/treesit-treewalk-out count))

(defun my/meow-ret-dispatch ()
	(interactive)
	(cond
		((derived-mode-p 'compilation-mode)
			(compile-goto-error))
		((derived-mode-p 'grep-mode)
			(compile-goto-error))
		((derived-mode-p 'occur-mode)
			(occur-mode-goto-occurrence))
		(t
			(command-palette/body))))

(keymap-global-set "S-<down>" #'forward-paragraph)
(keymap-global-set "S-<up>" #'backward-paragraph)

(with-eval-after-load 'compile
	(keymap-set compilation-mode-map "S-<down>" #'next-error)
	(keymap-set compilation-mode-map "S-<up>" #'previous-error))

;; (define-key meow-normal-state-keymap (kbd "RET") #'my/meow-ret-dispatch)

;; NOTE: emacsの場合はりつけはctrl - y

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
