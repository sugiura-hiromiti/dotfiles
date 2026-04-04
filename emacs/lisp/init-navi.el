;;; -*- lexical-binding: t; -*-

(winner-mode 1)

(use-package pretty-hydra
  :config
  (pretty-hydra-define meta-navigation
	 (:color amaranth :quit-key "<escape>")
	 ("window/navi"
	  (("h" windmove-left "left")
		("j" windmove-down "down")
		("k" windmove-up "up")
		("l" windmove-right "right")
		;; cycle
		("n" other-window "next")
		("p" (other-window -1) "prev"))
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
	  (("-" (enlarge-window -1) "lower")
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
		("<" (tab-move -1) "left")
		("m" (switch-to-buffer-other-tab) "buffer switch")
		)
	  ))

  (pretty-hydra-define command-palette
	 (:color blue)
	 ("document"
	  (("l" xref-find-references "list")
		("f" xref-find-definitions "def")
		("o" consult-eglot-symbols "outline")
		("d" consult-flymake "diagnostic")
		("a" eglot-code-actions "actions")
		("r" eglot-rename "rename")
		("h" eldoc "hover")
		)
	  "buf/file"
	  (("b" consult-buffer "buffer")
		("z" consult-fd "fd")
		("i" consult-line "line")
		("g" my/consult-ripgrep-current-dir "rg")
		("p" consult-ripgrep "prj rg"))
	  "misc"
	  (("s" save-some-buffers "save")
		("e" eval-buffer "eval")
		("x" eat "terminal")
		("R" my/reload-init-file "reload")
		("j" majutsu "jj")
		("t" popper-toggle "toggle")))))

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
