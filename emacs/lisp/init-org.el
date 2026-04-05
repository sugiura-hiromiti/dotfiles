;;; -*- lexical-binding: t; -*-

(setq org-directory "~/Downloads/awa/org")

(setq org-agenda-files
		'("~/Downloads/awa/org/inbox.org"
		  "~/Downloads/awa/org/journal.org"
		  "~/Downloads/awa/org/reference.org"
		  "~/Downloads/awa/org/someday.org"))

(setq org-default-notes-file "~/Downloads/awa/org")

(setq org-capture-templates
      '(("i" "Inbox" entry
         (file "~/Downloads/awa/org/inbox.org")
         "* %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n")

        ("t" "Task" entry
         (file "~/Downloads/awa/org/inbox.org")
         "* TODO %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n")

        ("j" "Journal" entry
         (file+olp+datetree "~/Downloads/awa/org/journal.org")
         "* %U %?\n")

        ("r" "Reference" entry
         (file "~/Downloads/awa/org/reference.org")
         "* %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n")))

(setq org-refile-targets
      '(("~/org/someday.org"  :maxlevel . 3)
        ("~/org/reference.org" :maxlevel . 3)
        ("~/org/journal.org"  :maxlevel . 3)))

(setq org-refile-allow-creating-parent-nodes)
(setq org-outline-path-complete-in-steps nil)
(setq org-refile-use-outline-path 'file)

(use-package org-modern
  :hook ((org-mode . org-modern-mode)
			(org-agenda-finalize . org-modern-agenda)))

;; TODO: 設定つめる
(use-package org-appear
  :hook (org-mode . org-appear-mode))

(with-eval-after-load 'org
  (require 'org-tempo))

(provide 'init-org)
