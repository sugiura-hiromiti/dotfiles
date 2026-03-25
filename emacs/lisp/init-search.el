;;; -*- lexical-binding: t; -*-

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
	;(corfu-quit-at-boundary nil)
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
(use-package cape
  :init
  (add-hook 'completion-at-point-functions #'cape-file)
  (add-hook 'completion-at-point-functions #'cape-dabbrev)
  (add-hook 'completion-at-point-functions #'cape-emoji)
)
(context-menu-mode t)
(setopt completion-ignore-case t
	enable-recursive-minibuffers t
	read-extended-command-predicate #'command-completion-default-include-p
	minibuffer-prompt-properties '(read-only t
						cursor-intangible t
						face minibuffer-prompt))
(minibuffer-depth-indicate-mode 1)

(provide 'init-search)
