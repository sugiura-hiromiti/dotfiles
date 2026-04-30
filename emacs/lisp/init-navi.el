;;; -*- lexical-binding: t; -*-

(declare-function eglot-code-actions "eglot")
(declare-function eglot-rename "eglot")
(declare-function flymake-show-project-diagnostics "flymake")

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
		("h" eldoc "hover")
		)
	  "buf/file"
	  (("b" consult-buffer "buffer")
		("i" consult-line "line")
		("g" my/consult-ripgrep-current-dir "rg")
		("p" consult-ripgrep "prj rg")
		("m" compile "compilation-mode"))
	  "misc"
	  (("s" save-some-buffers "save")
		("e" eval-buffer "eval")
		("x" eat "terminal")
		("j" majutsu "jj"))
	  "org"
	  (("c" org-capture "capture")
		("k" org-agenda "agenda")))))

(defun my/reload-init-file ()
  "init.elを再読み込みする"
  (interactive)
  (load-file user-init-file)
  (message "RELOADED: %s" user-init-file))

(defun my/consult-ripgrep-current-dir ()
  "現在のバッファのディレクトリ配下をrgする"
  (interactive)
  (consult-ripgrep
	default-directory
	(thing-at-point 'symbol t)))

(provide 'init-navi)
