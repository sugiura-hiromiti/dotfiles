;;; -*- lexical-binding: t; -*-

(set-language-environment "Utf-8")
(prefer-coding-system 'utf-8-unix)

(setopt inhibit-startup-screen t
		  inhibit-startup-message t
		  inhibit-scratch-message nil
		  display-line-numbers-type 'relative
		  indent-tabs-mode t
		  tab-width 3
		  tab-bar-show 1
		  )
(setq whitespace-style '(face tabs tab-mark)
		whitespace-display-mappings
		'((tab-mark ?\t [?\│ ?\t] [?\t ?\t])))
(when (fboundp 'editorconfig-mode)
  (editorconfig-mode 1))
(global-whitespace-mode 1)

(tab-bar-mode)
(global-display-line-numbers-mode 1)
(global-hl-line-mode 1)

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

(use-package catppuccin-theme
  :config (load-theme 'catppuccin :no-confirm)
  (catppuccin-reload)
  )
(use-package auto-dark
  :custom
  (auto-dark-themes '((catppuccin) (catppuccin)))
  :hook
  (auto-dark-dark-mode
	. (lambda ()
		 (setq catppuccin-flavor 'frappe)
		 (catppuccin-reload)))
  (auto-dark-light-mode
	. (lambda ()
		 (setq catppuccin-flavor 'latte)
		 (catppuccin-reload)))
  :init
  (auto-dark-mode 1))

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

(use-package popper
  :init
  (setq popper-reference-buffers
		  '("^\\*Messages\\*"
			 "\\*scratch\\*"
			 help-mode
			 compilation-mode))
  :config
  (popper-mode 1)
  (popper-echo-mode 1)

  (defun my/popper-popup-local-keys ()
	 "Popupばっふぁの中でだけ使うきーを設定"
	 (local-set-key (kbd "C-'") #'popper-cycle))
  (add-hook 'popper-open-popup-hook #'my/popper-popup-local-keys))

(global-set-key (kbd "C-,") #'popper-toggle)

(provide 'init-ui)
