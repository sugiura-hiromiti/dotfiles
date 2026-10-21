;;; init-ui.el --- UI configuration -*- lexical-binding: t; -*-

;;; Commentary:

;;; Code:

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
	:height (pcase system-type
				  ('darwin 160)
				  ('gnu/linux 100)
				  (_ 250))
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
	(defun my/auto-dark-on-first-gui-frame (frame)		(with-selected-frame frame
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

(use-package vc-jj
	:ensure t
	:demand t)

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

(use-package flyover
	:hook
	(flymake-mode . flyover-mode)
	:custom
	(flyover-checkers '(flymake))
	(flyover-levels '(error warning info))
	(flyover-show-virtual-line t)
	(flyover-use-theme-colors t)
	(flyover-wrap-messages t)
	(flyover-display-mode 'always)
	(flyover-show-at-eol t))

(use-package eldoc-box
	:hook
	(eldoc-mode . eldoc-box-hover-mode))

(provide 'init-ui)
;;; init-ui.el ends here
