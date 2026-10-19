;;; init-org.el --- Summary -*- lexical-binding: t; -*-

;;; Commentary:

;;; Code:

(require 'init-paths)

(defun my/org-enable-auto-update-dblocks ()
	"Update dynamic block on save."
	(add-hook 'before-save-hook
		#'org-update-all-dblocks
		nil
		t))

(use-package org
	:custom
	(org-startup-indented t)
	:hook
	(org-mode . my/org-enable-auto-update-dblocks))

(setq org-directory my/dotfiles-org-directory)

(setq org-agenda-files
	(mapcar (lambda (file) (expand-file-name file org-directory))
		'("inbox.org"
			 "journal.org"
			 "feed.org")))

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
			 "* %:description :link:\n%:link\n\n%i\n")
		 ("L" "via protocol" entry
			 (file ,(expand-file-name "inbox.org" org-directory))
			 "* %:description :link:\n%:link\n\n%i\n")))

(setq org-protocol-default-template-key "p")

(setq org-refile-targets
   `((,(expand-file-name "journal.org" org-directory)  :maxlevel . 3)))

(setq org-refile-allow-creating-parent-nodes 'confirm)
(setq org-outline-path-complete-in-steps nil)
(setq org-refile-use-outline-path 'file)

(use-package org-modern
	:hook ((org-mode . org-modern-mode)
				(org-agenda-finalize . org-modern-agenda))
	:custom
	(org-modern-hide-stars nil)
	(org-modern-table nil))

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

(use-package org-modern-indent
	:vc (:url "https://github.com/jdtsmith/org-modern-indent")
	:config
	(add-hook 'org-mode-hook #'org-modern-indent-mode 90))

(use-package org-ql
	:config
	(require 'org-ql-search)
	:custom
	(org-ql-ask-unsafe-queries nil)
	(org-ql-views
		(list
			(cons "link"
				(list
					:buffers-files #'org-agenda-files
					:query '(tags "link")
					:title "link"))
			(cons "todo"
				(list
					:buffers-files #'org-agenda-files
					:query '(todo)
					:title "todo"))
			(cons "bookmarks"
				(list
					:buffers-files #'org-agenda-files
					:query '(tags "bookmark")
					:title "bookmarks")))))

(use-package org-feed
	:ensure nil
	:after org
	:custom
	(org-feed-alist
		`(("Rust"
			  "https://blog.rust-lang.org/feed.xml"
			  ,(expand-file-name "feed.org" org-directory)
			  "Rust")
			 ("Apribase"
				 "https://apribase.net/program/feed"
				 ,(expand-file-name "feed.org" org-directory)
				 "Apribase"))))

(require 'org-protocol)

(provide 'init-org)
;;; init-org.el ends here
