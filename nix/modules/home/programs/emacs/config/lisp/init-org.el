;;; -*- lexical-binding: t; -*-

(require 'init-paths)

(setq org-directory my/dotfiles-org-directory)

(setq org-agenda-files
	(mapcar (lambda (file) (expand-file-name file org-directory))
		'("inbox.org"
			 "journal.org"
			 "reference.org"
			 "someday.org")))

(setq org-default-notes-file (expand-file-name "inbox.org" org-directory))

(setq org-capture-templates
   `(("i" "Inbox" entry
        (file ,(expand-file-name "inbox.org" org-directory))
        "* %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n")

       ("t" "Task" entry
          (file ,(expand-file-name "inbox.org" org-directory))
          "* TODO %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n")

       ("j" "Journal" entry
          (file+olp+datetree ,(expand-file-name "journal.org" org-directory))
          "* %U %?\n")

       ("r" "Reference" entry
          (file ,(expand-file-name "reference.org" org-directory))
          "* %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n")
		 ("p" "via protocol" entry
			 (file ,(expand-file-name "inbox.org" org-directory))
			 "* %:description\n%:link\n\n%i\n")))

(setq org-protocol-default-template-key "p")

(setq org-refile-targets
   `((,(expand-file-name "someday.org" org-directory)  :maxlevel . 3)
       (,(expand-file-name "reference.org" org-directory) :maxlevel . 3)
       (,(expand-file-name "journal.org" org-directory)  :maxlevel . 3)))

(setq org-refile-allow-creating-parent-nodes 'confirm)
(setq org-outline-path-complete-in-steps nil)
(setq org-refile-use-outline-path 'file)

(defun my/org-force-tab-width-8 ()
	"Force `tab-width' to 8 in Org buffers."
	(when (derived-mode-p 'org-mode)
		(setq-local tab-width 8)))
(add-hook 'org-mode-hook #'my/org-force-tab-width-8)
;; .dir-locals.el / file-local variables 適用後にも戻す
(add-hook 'hack-local-variables-hook #'my/org-force-tab-width-8)

(with-eval-after-load 'editorconfig
	(add-hook 'editorconfig-after-apply-functions
      (lambda (_props)
         (when (derived-mode-p 'org-mode)
            (setq-local tab-width 8)))))

(use-package org-modern
	:hook ((org-mode . org-modern-mode)
				(org-agenda-finalize . org-modern-agenda)))

(use-package org-appear
	:hook (org-mode . org-appear-mode)
	:custom
	(org-appear-autoemphasis t)
	(org-appear-autolinks t)
	(org-appear-autosubmarkers t)
	(org-appear-autoentities t)
	(org-appear-delay 0.0)
	(org-appear-trigger 'always))

(with-eval-after-load 'org
	(require 'org-tempo))

(require 'org-protocol)

(provide 'init-org)
