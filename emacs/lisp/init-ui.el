;;; -*- lexical-binding: t; -*-

(setopt inhibit-startup-screen t
	inhibit-startup-message t
	inhibit-scratch-message nil
	display-line-numbers-type 'relative)

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

(provide 'init-ui)
