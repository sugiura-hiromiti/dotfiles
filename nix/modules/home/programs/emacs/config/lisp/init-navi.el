;;; -*- lexical-binding: t; -*-

(declare-function eldoc-box-focus-frame "eldoc-box")
(declare-function eldoc-box-help-at-point "eldoc-box")
(declare-function eglot-code-actions "eglot")
(declare-function eglot-rename "eglot")
(declare-function flymake-show-project-diagnostics "flymake")
(declare-function my/meow-treesit-contract "init-edit")
(declare-function my/meow-treesit-expand "init-edit")
(declare-function my/meow-treesit-down "init-edit")
(declare-function my/meow-treesit-in "init-edit")
(declare-function my/meow-treesit-out "init-edit")
(declare-function my/meow-treesit-up "init-edit")

(winner-mode 1)

(defun my/other-window-backward ()
	"前のwindowに移動する。"
	(interactive)
	(other-window -1))

(defun my/shrink-window-vertically ()
	"現在のwindowの高さを1行小さくする。"
	(interactive)
	(enlarge-window -1))

(defun my/tab-move-left ()
	"現在のtabを左に移動する。"
	(interactive)
	(tab-move -1))

(defun my/switch-to-buffer-other-tab ()
	"bufferを選んで別tabで開く。"
	(interactive)
	(call-interactively #'switch-to-buffer-other-tab))

(use-package pretty-hydra
	:config
	(pretty-hydra-define meta-navigation
		(:color pink :quit-key "<escape>")
		("window/navi"
			(("h" windmove-left "left")
				("j" windmove-down "down")
				("k" windmove-up "up")
				("l" windmove-right "right")
				;; cycle
				("n" other-window "next")
				("p" my/other-window-backward "prev"))
			"window/create,delete"
			(("v" split-window-right "vertical")
				("x" split-window-below "horizontal")
				;; delete
				("d" delete-window "delete")
				("u" winner-undo "undo")
				)
			"window/swap"
			(("H" windmove-swap-states-left "swap left")
				("J" windmove-swap-states-down "swap down")
				("K" windmove-swap-states-up "swap up")
				("L" windmove-swap-states-right "swap right"))
			"window/resize"
			(("-" my/shrink-window-vertically "lower")
				("+" enlarge-window "higher")
				(";" shrink-window-horizontally "shrink")
				("'" enlarge-window-horizontally "enlarge"))
			"tab"
			(("q" tab-previous "prev")
				("w" tab-next "next")
				("t" tab-new "new")
				("c" tab-close "close")
				("U" tab-undo "undo")
				(">" tab-move "right")
				("<" my/tab-move-left "left")
				("m" my/switch-to-buffer-other-tab "buffer switch")
				)
			))

	(pretty-hydra-define command-palette
		(:color blue)
		("document"
			(("l" xref-find-references "list")
				("f" xref-find-definitions "def")
				("o" consult-eglot-symbols "outline")
				("d" flymake-show-project-diagnostics "diagnostic")
				("a" eglot-code-actions "actions")
				("r" eglot-rename "rename")
				("h" my/eldoc-box-help-at-point "hover")
				)
			"buf/file"
			(("b" consult-buffer "buffer")
				("i" consult-line "line")
				("g" my/consult-ripgrep-current-dir "rg")
				("p" consult-ripgrep "prj rg")
				("m" ghostel-compile "compilation-mode"))
			"misc"
			(("e" eval-buffer "eval")
				("x" ghostel-project "terminal")
				("j" majutsu "jj")
				("n" elfeed-update "rss notification"))
			"org"
			(("c" org-capture "capture")
				("k" org-agenda "agenda")
				("s" org-store-link "store link")))))

(defun my/eldoc-box-help-at-point ()
	"Show eldoc document and focus its child frame"
	(interactive)
	(eldoc-box-help-at-point)
	(eldoc-box-focus-frame))

(defun my/consult-ripgrep-current-dir ()
	"現在のバッファのディレクトリ配下をrgする"
	(interactive)
	(consult-ripgrep
		default-directory
		(thing-at-point 'symbol t)))

(use-package flymake
	:ensure nil
	:bind
	(:map flymake-mode-map
		("<f1>" . flymake-goto-prev-error)
		("<f2>" . flymake-goto-next-error)))

(use-package pulsar
	:custom (pulsar-pulse-on-window-change t)
	:config (pulsar-global-mode 1))

(use-package goggles
	:hook ((prog-mode text-mode) . goggles-mode)
	:custom
	(googles-pulse t))

(provide 'init-navi)
