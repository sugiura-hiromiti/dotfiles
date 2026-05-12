;;; -*- lexical-binding: t; -*-

(declare-function treesit-available-p "treesit")
(declare-function treesit-language-available-p "treesit")
(defvar major-mode-remap-alist)
(defvar treesit-font-lock-level)
(defvar warning-suppress-log-types nil)
(defvar warning-suppress-types nil)

(setq treesit-font-lock-level 4)

(use-package md-ts-mode
	:config
	(md-ts-mode-enable-global))

(use-package nix-ts-mode)

(use-package kdl-ts-mode
	:vc (:url "https://github.com/dataphract/kdl-ts-mode")
	:config
	(setq kdl-ts-mode-indent-offset 3))

(defun my/treesit-languages-available-p (&rest languages)
	"LANGUAGESのtree-sitter grammarがすべて使えるならnon-nilを返す。"
	(let ((warning-suppress-types (cons '(treesit) warning-suppress-types))
			  (warning-suppress-log-types
				  (cons '(treesit) warning-suppress-log-types)))
		(and (treesit-available-p)
         (catch 'missing
				(dolist (language languages t)
					(unless (car (treesit-language-available-p language t))
						(throw 'missing nil)))))))

(defun my/add-treesit-auto-mode (regexp mode &rest languages)
	"LANGUAGESが使えるときだけREGEXPをMODEに関連付ける。"
	(when (and (fboundp mode)
            (apply #'my/treesit-languages-available-p languages))
		(add-to-list 'auto-mode-alist (cons regexp mode))))

(defun my/add-treesit-mode-remap (base-mode ts-mode &rest languages)
	"LANGUAGESが使えるときだけBASE-MODEをTS-MODEへremapする。"
	(when (and (fboundp ts-mode)
            (apply #'my/treesit-languages-available-p languages))
		(add-to-list 'major-mode-remap-alist (cons base-mode ts-mode))))

;; ts-mode packageをここでuse-package宣言すると、grammar未導入時に
;; package側のnative compile warningが出る。autoload済みのmodeだけ登録する。
(defun my/setup-treesit-mode-associations ()
	"利用可能なtree-sitter grammarだけmode関連付けへ登録する。"
	(my/add-treesit-auto-mode "\\.hs\\'" 'haskell-ts-mode 'haskell)
	(my/add-treesit-auto-mode "\\.lhs\\'" 'haskell-ts-mode 'haskell)
	(my/add-treesit-auto-mode "\\.nu\\'" 'nushell-ts-mode 'nu)
	(my/add-treesit-auto-mode "\\.nix\\'" 'nix-ts-mode 'nix)
	(my/add-treesit-auto-mode "\\.md\\'" 'md-ts-mode 'markdown 'markdown-inline)
	(my/add-treesit-auto-mode "\\.lua\\'" 'lua-ts-mode 'lua)
	(my/add-treesit-auto-mode "\\.rs\\'" 'rust-ts-mode 'rust)
	(my/add-treesit-auto-mode "\\.kdl\\'" 'kdl-ts-mode 'kdl)

	(my/add-treesit-mode-remap 'rust-mode 'rust-ts-mode 'rust)
	(my/add-treesit-mode-remap 'haskell-mode 'haskell-ts-mode 'haskell)
	(my/add-treesit-mode-remap 'json-mode 'json-ts-mode 'json)
	(my/add-treesit-mode-remap 'js-json-mode 'json-ts-mode 'json)
	(my/add-treesit-mode-remap 'toml-mode 'toml-ts-mode 'toml)
	(my/add-treesit-mode-remap 'conf-toml-mode 'toml-ts-mode 'toml)
	(my/add-treesit-mode-remap 'nushell-mode 'nushell-ts-mode 'nu)
	(my/add-treesit-mode-remap 'lua-mode 'lua-ts-mode 'lua)
	(my/add-treesit-mode-remap 'nix-mode 'nix-ts-mode 'nix)
	(my/add-treesit-mode-remap 'yaml-mode 'yaml-ts-mode 'yaml))

(add-hook 'after-init-hook #'my/setup-treesit-mode-associations)

;; (use-package ts-movement
;; 	:vc (:url "https://github.com/haritkapadia/ts-movement")
;; 	:hook
;; 	((rust-ts-mode
;; 		 haskell-ts-mode
;; 		 json-ts-mode
;; 		 toml-ts-mode
;; 		 nushell-ts-mode
;; 		 lua-ts-mode
;; 		 nix-ts-mode
;; 		 yaml-ts-mode
;; 		 md-ts-mode
;; 		 kdl-ts-mode) . ts-movement-mode)
;; 	:config
;; 	(defun my/tsm-next-node-end ()
;; 		"move to next sibling node, then go to its end"
;; 		(interactive)
;; 		(tsm/node-next (point))
;; 		(tsm/node-end (point)))
;; 	(defun my/tsm-prev-node-start ()
;; 		"move to previous sibling node, then go to its start"
;; 		(interactive)
;; 		(tsm/node-prev (point))
;; 		(tsm/node-start (point)))
;; 	(define-key ts-movement-map (kbd "<down>") #'my/tsm-next-node-end)
;; 	(define-key ts-movement-map (kbd "<up>") #'my/tsm-prev-node-start)
;; 	(define-key ts-movement-map (kbd "<right>") #'tsm/node-child)
;; 	(define-key ts-movement-map (kbd "<left>") #'tsm/node-parent))

(use-package ts-movement
	:vc (:url "https://github.com/haritkapadia/ts-movement")
	:hook
	((rust-ts-mode
		 haskell-ts-mode
		 json-ts-mode
		 toml-ts-mode
		 nushell-ts-mode
		 lua-ts-mode
		 nix-ts-mode
		 yaml-ts-mode
		 md-ts-mode
		 kdl-ts-mode)
		. ts-movement-mode)
	:config
	;; nil   = boundary movement session has not started
	;; start = current overlay node's start side
	;; end   = current overlay node's end side
	(defvar-local my/tsm-boundary-edge nil)

	(defun my/tsm-boundary-command-p ()
		"Return non-nil if the previous command was my Tree-sitter boundary movement."
		(memq last-command
         '(my/tsm-next-node-boundary
             my/tsm-prev-node-boundary)))

	(defun my/tsm-reset-boundary-state-unless-continuing ()
		"Reset boundary state unless the last command was also boundary movement."
		(unless (my/tsm-boundary-command-p)
			(setq my/tsm-boundary-edge nil)))

	(defun my/tsm-next-node-boundary ()
		"Move through Tree-sitter sibling node boundaries forward.

Order:
  current node end
  -> next sibling node start
  -> same node end
  -> next sibling node start
  -> ..."
		(interactive)
		(my/tsm-reset-boundary-state-unless-continuing)
		(pcase my/tsm-boundary-edge
			;; If we are at the start of a node, go to its end.
			('start
				(tsm/node-end (point))
				(setq my/tsm-boundary-edge 'end))

			;; If we are at the end of a node, go to next sibling's start.
			('end
				(let ((old-point (point)))
					(tsm/node-next (point))
					(if (= old-point (point))
						(message "No next sibling node")
						(setq my/tsm-boundary-edge 'start))))

			;; First ↓ in a session:
			;; move to the current indicated node's end.
			(_
				(tsm/node-end (point))
				(setq my/tsm-boundary-edge 'end))))

	(defun my/tsm-prev-node-boundary ()
		"Move through Tree-sitter sibling node boundaries backward.

Order:
  current node start
  -> previous sibling node end
  -> same node start
  -> previous sibling node end
  -> ..."
		(interactive)
		(my/tsm-reset-boundary-state-unless-continuing)
		(pcase my/tsm-boundary-edge
			;; If we are at the end of a node, go to its start.
			('end
				(tsm/node-start (point))
				(setq my/tsm-boundary-edge 'start))

			;; If we are at the start of a node, go to previous sibling's end.
			('start
				(let ((old-point (point)))
					(tsm/node-prev (point))
					(if (= old-point (point))
						(message "No previous sibling node")
						(tsm/node-end (point))
						(setq my/tsm-boundary-edge 'end))))

			;; First ↑ in a session:
			;; move to the current indicated node's start.
			(_
				(tsm/node-start (point))
				(setq my/tsm-boundary-edge 'start))))

	(define-key ts-movement-map (kbd "<down>")  #'my/tsm-next-node-boundary)
	(define-key ts-movement-map (kbd "<up>")    #'my/tsm-prev-node-boundary)
	(define-key ts-movement-map (kbd "<right>") #'tsm/node-child)
	(define-key ts-movement-map (kbd "<left>")  #'tsm/node-parent))

(provide 'init-ts)
