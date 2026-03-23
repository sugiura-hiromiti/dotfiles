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
	which-key-idle-delay 0.1)

;; 履歴
(savehist-mode 1)
(recentf-mode 1)
(global-auto-revert-mode 1)
(pixel-scroll-precision-mode 1)
(electric-pair-mode 1)
(repeat-mode 1)

(which-key-mode 1)

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

(use-package vertico
	:init
	(vertico-mode 1))
(use-package marginalia
	:init
	(marginalia-mode 1))
(use-package consult)
(use-package orderless
  :custom
  (completion-styles '(orderless basic))
		     (completion-category-defaults nil)
		     (completion-category-overrides '((file (styles partial-completion basic)))))
(use-package embark)
(use-package embark-consult
	:after (embark consult))
(use-package corfu
	:custom
	(corfu-auto t)
	(corfu-cycle t)
	:init
	(global-corfu-mode 1))
(use-package cape)

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
  :custom
  (setq catppuccin-flavor 'frappe)
  (catppuccin-reload))

;; 編集/移動
(use-package avy)
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
     '("," . meow-inner-of-thing)
     '("." . meow-bounds-of-thing)
     '("a" . meow-append)
     '("A" . meow-open-below)
     '("b" . meow-back-word)
     '("B" . meow-back-symbol)
     '("c" . meow-change)
     '("d" . meow-delete)
     '("e" . meow-next-word)
     '("E" . meow-next-symbol)
     '("f" . meow-find)
     '("g" . meow-cancel-selection)
     '("G" . meow-grab) ;; ?
     '("h" . meow-left)
     '("H" . meow-left-expand)
     '("i" . meow-insert)
     '("I" . meow-open-above)
     '("j" . meow-next)
     '("J" . meow-next-expand)
     '("k" . meow-prev)
     '("K" . meow-prev-expand)
     '("l" . meow-right)
     '("L" . meow-right-expand)
     '("m" . meow-join)
     '("n" . meow-search)
     '("o" . meow-block)
     '("O" . meow-to-block)
     '("p" . meow-yank)
     '("q" . meow-goto-line)
     '("r" . meow-replace)
     '("s" . meow-kill)
     '("t" . meow-till)
     '("v" . meow-visit)
     '("u" . meow-undo)
     '("w" . meow-mark-word)
     '("W" . meow-mark-symbol)
     '("x" . meow-line)
     '("y" . meow-save)
     '("z" . meow-pop-selection)
     '("<escape>" . ignore)))
  (my/meow-setup)
  (meow-global-mode 1)
  :custom
  (setopt meow-use-clipboard t))
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages
   '(avy cape catppuccin-theme corfu embark-consult magit marginalia meow
	 nerd-icons orderless org-modern rainbow-delimiters vertico)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
