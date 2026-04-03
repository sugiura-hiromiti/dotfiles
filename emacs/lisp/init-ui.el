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
;; (global-display-line-numbers-mode 1)
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

(use-package org-modern
  :hook (org-mode . org-modern-mode))

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

(use-package breadcrumb
  :ensure t
  :init
  (breadcrumb-mode 1))

(after! doom-modeline
  (doom-modeline-def-segment breadcrumbs
    "Project/Imenu breadcrumbs for doom-modeline."
    (when (and (bound-and-true-p breadcrumb-mode)
               (not doom-modeline--limited-width-p))
      (let* ((proj  (ignore-errors (breadcrumb-project-crumbs)))
             (imenu (ignore-errors (breadcrumb-imenu-crumbs)))
             (items (delq nil (list proj imenu))))
        (when items
          (concat
           (doom-modeline-spc)
           (mapconcat #'identity items " › ")
           (doom-modeline-spc))))))

  ;; buffer-info の直後に breadcrumbs を差し込む
  (doom-modeline-add-segment 'breadcrumbs 'buffer-info :after 'main))
(provide 'init-ui)
