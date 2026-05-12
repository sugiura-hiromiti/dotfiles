;;; -*- lexical-binding: t; -*-

(set-language-environment "Utf-8")
(prefer-coding-system 'utf-8-unix)

(setopt inhibit-startup-screen t
	inhibit-startup-message t
	inhibit-scratch-message nil
	display-line-numbers-type t
	indent-tabs-mode t
	tab-width 3)
(setq whitespace-style '(face tabs tab-mark)
	whitespace-display-mappings
	'((tab-mark ?\t [?\│ ?\t] [?\t ?\t]))
	;; flymake-show-diagnostics-at-end-of-line t
	)
(global-whitespace-mode 1)

(global-display-line-numbers-mode 1)
(global-hl-line-mode 1)

(set-fringe-mode '(8 . 0))

(set-face-attribute 'default nil
	:family "Maple Mono NF CN"
	:height 110
	:weight 'extra-light)
(set-face-attribute 'bold nil
	:weight 'light)
(set-face-attribute 'italic nil
	:weight 'extra-light
	:slant 'italic)
(set-face-attribute 'bold-italic nil
	:weight 'light
	:slant 'italic)

(use-package nerd-icons
	:if (display-graphic-p))

(use-package rainbow-delimiters
	:hook (prog-mode . rainbow-delimiters-mode))

(use-package batppuccin
	:config
	;; custom.el が消えても daemon 起動時に theme safety prompt を出さない。
	(load-theme 'batppuccin-frappe t t)
	(load-theme 'batppuccin-latte t t)
	(enable-theme 'batppuccin-latte))

(use-package auto-dark
	:ensure t
	:after batppuccin
	:custom
	;; auto-dark-themes は基本的に (dark light)
	;; dark 側を frappe にしたいならこれでよい
	(auto-dark-themes '((batppuccin-frappe) (batppuccin-latte)))
	:config
	(defun my/auto-dark-on-first-gui-frame (frame)
		(with-selected-frame frame
			(when (display-graphic-p)
				(auto-dark-mode 1)
				(remove-hook 'after-make-frame-functions
               #'my/auto-dark-on-first-gui-frame))))

	(if (display-graphic-p)
      (auto-dark-mode 1)
		(add-hook 'after-make-frame-functions
         #'my/auto-dark-on-first-gui-frame)))

(use-package doom-modeline
	:init
	(doom-modeline-mode 1)
	:custom
	(doom-modeline-enable-buffer-position t)
	(doom-modeline-position-column-line-format '("%l:%c"))
	(doom-modeline-check 'auto)
	:config
	(doom-modeline-def-segment my-breadcrumbs
		"Project/Imenu breadcrumbs for doom-modeline."
		(when (not doom-modeline--limited-width-p)
			(let* ((proj  (ignore-errors (breadcrumb-project-crumbs)))
						(imenu (ignore-errors (breadcrumb-imenu-crumbs)))
						(items (delq nil (list proj imenu))))
				(when items
					(concat
						(doom-modeline-spc)
						(mapconcat #'identity items " › ")
						(doom-modeline-spc))))))
	(doom-modeline-def-modeline 'my-main
		'(bar my-breadcrumbs)
		'(major-mode vcs check))
	(doom-modeline-set-modeline 'my-main t))

(use-package breadcrumb
	:config
	(breadcrumb-mode -1))

(use-package ligature
	:ensure t
	:config
	;; Maple Mono NF CN の calt をかなり広く拾う版
	(ligature-set-ligatures
		't
		'("::" ":::" "?:" ":?" ":?>" "<:" ":>" ":<" "<:<" ">:>"
			 "__" "#{" "#[" "#(" "#?" "#!" "#:" "#=" "#_" "#__" "#_(" "]#"
			 "#######" "<<" "<<<" ">>" ">>>" "{{" "}}" "{|" "|}" "{{--" "{{!--"
			 "--}}" "[|" "|]" "!!" "||" "??" "???" "&&" "&&&" "//" "///"
			 "/*" "/**" "*/" "++" "+++" ";;" ";;;" ".." "..." ".?" "?."
			 "..<" ".=" "<~" "~>" "~~" "<~>" "<~~" "~~>" "-~" "~-"
			 "~~~~~~~" "-------" "<>" "</" "/>" "</>" "<+" "+>" "<+>" "<*" "*>"
			 "<*>" ">=" "<=" "<=<" ">=>" "<=>" "<==>" "<==" "==>" "=>" "==" "==="
			 "!=" "!==" "=/=" "=!=" "|=" "<=|" "|=>" "=<=" "=>=" ">=<" ":=" "=:"
			 ":=:" "=:=" "\\\\" "\\'" "\\." "--" "---" "<#--" "<!---->" "<!--"
			 "<->" "<-->" "->" "<-" "-->" "<--" ">->" "<-<" "|->" "<-|"
			 "<|||" "|||>" "<||" "||>" "<|" "|>" "<|>" "_|_"
			 "[TRACE]" "[DEBUG]" "[INFO]" "[WARN]" "[ERROR]" "[FATAL]"
			 "[TODO]" "[FIXME]" "[NOTE]" "[HACK]" "[MARK]" "[EROR]" "[WARNING]"
			 "todo))" "fixme))" "Cl" "al" "cl" "el" "il" "tl" "ul"
			 "ff" "tt" "all" "ell" "ill" "ull"
			 "0xA12" "0x56" "1920x1080"))

	(global-ligature-mode t))

(use-package colorful-mode
	:config
	(global-colorful-mode 1))

(use-package tab-bar
	:ensure nil
	:init
	(tab-bar-mode 1)
	:custom
	(tab-bar-show 1)
	(switch-to-buffer-obey-display-actions t))

(require 'seq)

(defvar my/popup-tab-name "Popper")
(defvar my/popup-return-tab nil)

(defconst my/popper-buffer-name-regexp
	(rx bos "*"
		(or "Help"
			"helpful"
			"Backtrace"
			"Occur"
			"grep"
			"xref"
			"Async Shell Command"
			"eshell"
			"shell"
			"eat")
		(* any)
		"*"
		eos))

(defconst my/popper-buffer-modes
	'(help-mode
		 helpful-mode
		 compilation-mode
		 grep-mode
		 occur-mode
		 eshell-mode
		 shell-mode
		 eat-mode))

(defun my/current-tab-name ()
	(let ((tab (seq-find (lambda (tab)
									(memq 'current-tab tab))
                 (tab-bar-tabs))))
		(alist-get 'name tab)))

(defun my/tab-exists-p (name)
	(seq-some (lambda (tab)
					 (equal (alist-get 'name tab) name))
      (tab-bar-tabs)))

(defun my/tab-number-by-name (name)
	"Return 1-based tab number for tab NAME, or nil."
	(let ((i 1)
			  found)
		(dolist (tab (tab-bar-tabs) found)
			(when (and (not found)
						(equal (alist-get 'name tab) name))
				(setq found i))
			(setq i (1+ i)))))

(defun my/switch-tab-by-name (name)
	"Switch to tab NAME."
	(let ((n (my/tab-number-by-name name)))
		(unless n
			(error "No tab named %S" name))
		(tab-bar-select-tab n)))

(defun my/first-non-popup-tab-name ()
	"Return the first tab name that is not the popup tab."
	(catch 'found
		(dolist (tab (tab-bar-tabs))
			(let ((name (alist-get 'name tab)))
				(unless (equal name my/popup-tab-name)
					(throw 'found name))))
		nil))

(defun my/ensure-popup-tab ()
	(unless (my/tab-exists-p my/popup-tab-name)
		(let ((origin-tab (my/current-tab-name)))
			(tab-new)
			(tab-rename my/popup-tab-name)
			(set-window-buffer
				(selected-window)
				(get-buffer-create "*Messages*"))
			;; Create Popper tab, then return to original tab.
			(when (and origin-tab
						(my/tab-exists-p origin-tab)
						(not (equal origin-tab my/popup-tab-name)))
				(my/switch-tab-by-name origin-tab)))))

(defun my/delete-popup-tab ()
	"Delete `my/popup-tab-name' tab if it exists."
	(let ((n (my/tab-number-by-name my/popup-tab-name)))
		(when n
			(tab-bar-close-tab n))))

(defun my/toggle-popup-tab ()
	"Toggle transient popup tab.

When called from a normal tab, create/switch to popup tab.
When called from popup tab, return to previous tab and delete popup tab."
	(interactive)
	(if (equal (my/current-tab-name) my/popup-tab-name)
      ;; Inside popup tab: return, then delete popup tab.
      (let ((return-tab my/popup-return-tab))
			(cond
				((and return-tab
                (my/tab-exists-p return-tab)
                (not (equal return-tab my/popup-tab-name)))
					(my/switch-tab-by-name return-tab))
				((my/first-non-popup-tab-name)
					(my/switch-tab-by-name (my/first-non-popup-tab-name))))
			(my/delete-popup-tab)
			(setq my/popup-return-tab nil))

		;; Outside popup tab: remember current tab, create/switch to popup tab.
		(setq my/popup-return-tab (my/current-tab-name))
		(my/ensure-popup-tab)
		(my/switch-tab-by-name my/popup-tab-name)))

(defun my/popper-display-in-tab (buffer alist)
	"Display Popper BUFFER in `my/popup-tab-name' tab."
	(my/ensure-popup-tab)
	(display-buffer-in-tab
		buffer
		(append
			`((tab-name . ,my/popup-tab-name)
				 (inhibit-same-window . t))
			alist)))

(use-package popper
	:ensure t
	:custom
	(popper-display-control t)
	(popper-display-function #'my/popper-display-in-tab)
	(popper-reference-buffers
		`(,my/popper-buffer-name-regexp
			 ,@my/popper-buffer-modes))
	:init
	(popper-mode 1)
	(popper-echo-mode 1)
	:config
	;; Global binding
	(keymap-global-set "C-," #'my/toggle-popup-tab))

(use-package agent-shell)

(provide 'init-ui)
