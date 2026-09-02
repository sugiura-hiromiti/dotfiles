;;; init-org.el --- Summary -*- lexical-binding: t; -*-

;;; Commentary:

;;; Code:

(require 'init-paths)

(use-package org)

(setq org-directory my/dotfiles-org-directory)

(setq org-agenda-files
	(mapcar (lambda (file) (expand-file-name file org-directory))
		'("inbox.org"
			 "journal.org")))

(setq org-default-notes-file (expand-file-name "inbox.org" org-directory))

(setq org-capture-templates
	`(("i" "Inbox" entry
		  (file ,(expand-file-name "inbox.org" org-directory))
		  "* %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n")
		 ("t" "Task" entry
			 (file ,(expand-file-name "inbox.org" org-directory))
			 "* TODO %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n")
		 ("p" "via protocol" entry
			 (file ,(expand-file-name "inbox.org" org-directory))
			 "* %:description\n%:link\n\n%i\n")))

(setq org-protocol-default-template-key "p")

(setq org-refile-targets
   `((,(expand-file-name "journal.org" org-directory)  :maxlevel . 3)))

(setq org-refile-allow-creating-parent-nodes 'confirm)
(setq org-outline-path-complete-in-steps nil)
(setq org-refile-use-outline-path 'file)

(use-package org-modern
	:hook ((org-mode . org-modern-mode)
				(org-agenda-finalize . org-modern-agenda)))

(defun my/org-raw-view ()
	"Show org source syntax for editing."
	(when (derived-mode-p 'org-mode)
		(org-modern-mode -1)
		(setq-local org-hide-emphasis-markers nil
			org-pretty-entities nil
			org-link-descriptive nil)
		(font-lock-flush)))

(defun my/org-rendered-view ()
	"Show presentation-oriented Org rendering."
	(when (derived-mode-p 'org-mode)
		(setq-local org-hide-emphasis-markers t
			org-pretty-entities t
			org-link-descriptive t)
		(org-modern-mode 1)
		(font-lock-flush)))

(defun my/org-meow-rendering-setup ()
	"Apply org-modern for beautiful rendering."
	(add-hook 'meow-insert-enter-hook #'my/org-raw-view nil t)
	(add-hook 'meow-insert-exit-hook #'my/org-rendered-view nil t)
	(if (bound-and-true-p meow-insert-mode)
		(my/org-raw-view)
		(my/org-rendered-view)))

(add-hook 'org-mode-hook #'my/org-meow-rendering-setup)

(require 'org-protocol)

(provide 'init-org)
;;; init-org.el ends here
