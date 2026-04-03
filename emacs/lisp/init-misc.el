;;; -*- lexical-binding: t; -*-

(use-package eat
  :ensure t
	:commands (eat))

(use-package diff-hl
	:config
	(global-diff-hl-mode)
	(diff-hl-flydiff-mode)
	(diff-hl-margin-mode))

(use-package majutsu
	:vc (:url "https://github.com/0WD0/majutsu"))

(provide 'init-misc)
