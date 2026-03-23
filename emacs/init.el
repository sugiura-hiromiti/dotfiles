(setq package-install-upgrade-built-in t
	initial-scratch-message nil
	use-dialog-box nil
	ring-bell-function #'ignore
	read-process-output-max (* 1024 1024)
	completion-cycle-threshold 3
	tab-always-indent 'complete)

(setq make-backup-files nil)

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
(package-initialize)

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
(setq inhibit-startup-screen t)
(setq inhibit-startup-message t)
(setq inhibit-scratch-message nil)

(menu-bar-mode -1)
(tool-bar-mode -1)
(scroll-bar-mode -1)

(use-package nerd-icons
	:if (display-graphic-p))
(use-package org-modern
	:hook (org-mode . org-modern-mode))
(use-package rainbow-delimiters
  :hook (prog-mode . rainbow-delimiters-mode))

;; 編集/移動
(use-package avy)
(use-package meow
  :ensure t
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
     ;;'("a" . meow-append)
     '("h" . meow-left)
     '("j" . meow-next)
     '("k" . meow-prev)
     '("l" . meow-right)
     '("i" . meow-insert)

     '("c" . meow-change)
     '("d" . meow-delete)
     '("s" . meow-kill)
     '("y" . meow-save)
     '("p" . meow-yank)
     '("u" . meow-undo)
     '("w" . meow-mark-word)
     '("e" . meow-next-word)
     '("b" . meow-back-word)
     '("," . meow-inner-of-thing)
     '("." . meow-bounds-of-thing)
     '("o" . meow-block)
     '("g" . meow-cancel-selection)
     '("x" . meow-line)
     '("<escape>" . ignore)))
  (my/meow-setup)
  (meow-global-mode 1))
