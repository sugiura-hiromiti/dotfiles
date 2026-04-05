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
         (file "~/org/inbox.org")
         "* %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n")

        ("t" "Task" entry
         (file "~/org/inbox.org")
         "* TODO %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n")

        ("j" "Journal" entry
         (file+olp+datetree "~/org/journal.org")
         "* %U %?\n")

        ("r" "Reference" entry
         (file "~/org/reference.org")
         "* %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n")))

(provide 'init-org)
