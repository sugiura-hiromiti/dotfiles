(setopt package-install-upgrade-built-in t
	initial-scratch-message nil
	use-dialog-box nil
	ring-bell-function #'ignore
	read-process-output-max (* 1024 1024)
	completion-cycle-threshold 3
	tab-always-indent 'complete
	select-enable-clipboard t
	make-backup-files nil
	global-auto-revert-non-file-buffers t
	which-key-idle-delay 0.1
	text-mode-ispell-word-completion nil)

;; 履歴
(savehist-mode 1)
(recentf-mode 1)
(global-auto-revert-mode 1)
(pixel-scroll-precision-mode 1)
(electric-pair-mode 1)
(repeat-mode 1)

(require 'package)
(setq package-archives
	'(("gnu" . "https://elpa.gnu.org/packages/")
		("nongnu" . "https://elpa.nongnu.org/nongnu/")
		("melpa" . "https://melpa.org/packages/")))

(unless (package-installed-p 'use-package)
	(package-refresh-contents)
	(package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t)

(which-key-mode 1)

(use-package  exec-path-from-shell
  :custom
  (exec-path-from-shell-shell-name "/run/current-system/sw/bin/nu"))

(use-package vertico
	:init
	(vertico-mode 1)
	:custom
	(vertico-scroll-margin 0)
	(vertico-count 20)
	(vertico-resize t)
	(vertico-cycle t)
	(vertico-multiform-commands
		'((consult-imenu buffer indexed)))
	(vertico-multiform-categories
	 '((file grid)
	  (consult-grep buffer)))
	:config
	(require 'vertico-multiform)
	(vertico-multiform-mode)
)
(use-package marginalia
	:init
	(marginalia-mode 1))
(use-package consult)
(use-package orderless
  :custom
  (completion-styles '(orderless flex basic))
		     (completion-category-defaults nil)
		     (completion-category-overrides '((file (styles partial-completion basic))))
		     ;(completion-pcm-leading-wildcard t)
		     )
(use-package embark
  :bind
  (("C-." . embark-act)
   ("C-;" . embark-dwim)
   ("C-h B" . embark-bindings))
  :init
  (setopt prefix-help-command #'embark-prefix-help-command))
(use-package embark-consult
	:after (embark consult))
(use-package corfu
	:custom
	(corfu-auto t)
	(corfu-auto-prefix 1)
	(corfu-auto-delay 0.01)
	(corfu-cycle t)
	(corfu-quit-at-boundary nil)
	;(corfu-quit-no-match nil)
	(corfu-popupinfo-delay 0.01)
	(corfu-popupinfo-max-height 80)
	(corfu-count 40)
	(corfu-max-width 100)
	(corfu-left-margin-width 0.0)
	(corfu-right-margin-width 0.0)
	:init
	(global-corfu-mode 1)
	(corfu-history-mode)
	(corfu-popupinfo-mode))
(use-package nerd-icons-corfu
  :config
  (add-to-list 'corfu-margin-formatters #'nerd-icons-corfu-formatter))
(use-package cape)
(context-menu-mode t)
(setopt completion-ignore-case t
	enable-recursive-minibuffers t
	read-extended-command-predicate #'command-completion-default-include-p
	minibuffer-prompt-properties '(read-only t
						cursor-intangible t
						face minibuffer-prompt)
	)
(minibuffer-depth-indicate-mode 1)

(add-hook 'rust-ts-mode-hook #'eglot-ensure)
(use-package magit)

;; 見た目
(setopt inhibit-startup-screen t
	inhibit-startup-message t
	inhibit-scratch-message nil
	display-line-numbers-type 'relative)

(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)
(global-display-line-numbers-mode 1)
(global-hl-line-mode 1)

(set-face-attribute 'default nil
		    :family "Maple Mono NF CN"
		    :height 130
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
(use-package org-modern
	:hook (org-mode . org-modern-mode))
(use-package rainbow-delimiters
  :hook (prog-mode . rainbow-delimiters-mode))
(use-package catppuccin-theme
  :config (load-theme 'catppuccin :no-confirm)
  (catppuccin-reload)
  :custom
  (catppuccin-flavor 'frappe))

;; 編集/移動
(use-package avy)
(use-package puni
  :init
  (puni-global-mode))
(use-package meow
  :config
  (defun my/meow-setup ()
    (setq meow-cheatsheet-layout meow-cheatsheet-layout-qwerty)

    (meow-motion-define-key
     '("j" . meow-next)
     '("k" . meow-prev)
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
     '("'" . repeat)
     ;;'("," . meow-inner-of-thing)
     ;;'("." . meow-bounds-of-thing)
     '("," . puni-mark-list-around-point)
     '("." . puni-mark-sexp-around-point)
     '("a" . meow-append)
     ;'("A" . meow-open-below)
     '("b" . meow-back-word)
     '("B" . meow-back-symbol)
     '("c" . meow-change)
     '("d" . meow-delete)
     '("e" . meow-next-word)
     '("E" . meow-next-symbol)
     '("f" . meow-find)
     '("g" . puni-expand-region)
     '("G" . meow-grab) ;; ?
     '("h" . meow-left)
     '("H" . meow-left-expand)
     '("i" . meow-insert)
     ;'("I" . meow-open-above)
     '("j" . meow-next)
     '("J" . meow-next-expand)
     '("k" . meow-prev)
     '("K" . meow-prev-expand)
     '("l" . meow-right)
     '("L" . meow-right-expand)
     '("m" . meow-join)
     '("n" . meow-search)
     ;'("o" . meow-block)
     ;'("O" . meow-to-block)
     '("o" . meow-open-below)
     '("O" . meow-open-above)
     '("p" . meow-yank)
     '("q" . meow-goto-line)
     '("r" . meow-reverse)
     '("s" . meow-kill)
     '("t" . meow-till)
     '("u" . meow-undo)
     '("v" . meow-visit)
     ;;'("w" . meow-mark-word)
     ;;'("W" . meow-mark-symbol)
     '("w" . puni-mark-sexp-at-point)
     '("x" . meow-line)
     '("y" . meow-save)
     '("z" . meow-pop-selection)
     '("<escape>" . ignore)))
  (my/meow-setup)
  (meow-global-mode 1)
  :custom
  (meow-use-clipboard t))
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages
   '(avy cape catppuccin-theme corfu embark-consult exec-path-from-shell
	 magit marginalia meow nerd-icons nerd-icons-corfu orderless
	 org-modern puni rainbow-delimiters vertico)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
