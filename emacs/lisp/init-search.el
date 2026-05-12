;;; -*- lexical-binding: t; -*-

(use-package
	vertico
	:init (vertico-mode 1)
	:custom
	(vertico-scroll-margin 0)
	(vertico-count 20)
	(vertico-resize t)
	(vertico-cycle t)
	(vertico-multiform-commands '((consult-imenu buffer indexed)))
	(vertico-multiform-categories '((file grid) (consult-grep buffer)))
	:config
	(require 'vertico-multiform)
	(add-to-list 'vertico-multiform-categories
		'(embark-keybinding grid))
	(vertico-multiform-mode 1))

(use-package vertico-buffer-frame
	:after vertico
	:vc (:url "https://github.com/kn66/vertico-buffer-frame"
			 :rev :newest)
	:custom
	(vertico-buffer-frame-preview t)
	(vertico-buffer-frame-preview-layout 'side-by-side)
	(vertico-buffer-frame-alpha-background 80)
	:config
	(vertico-buffer-frame-mode 1))

(use-package marginalia :init (marginalia-mode 1))

(use-package
	consult
	:config
	(setq
		xref-show-xrefs-function #'consult-xref
		xref-show-definitions-function #'consult-xref
		consult-narrow-key "<"))

(defvar my/consult-buffer-source-project-files
	`(:name
		 "Project files"
		 :narrow ?p
		 :category file
		 :face consult-file
		 :history file-name-history
		 :state ,#'consult--file-state
		 :items
		 ,(lambda ()
			  (let* ((proj (project-current nil))
						  (root
							  (if proj
								  (file-truename (project-root proj))
								  (file-truename default-directory))))
				  (mapcar
					  (lambda (f) (expand-file-name f root))
					  (let ((default-directory root))
						  (process-lines "fd"
                       "--color=never"
                       "--hidden"
                       "--exclude"
                       ".git"
                       "--exclude"
                       ".jj"
                       ".")))))
		 :action ,#'find-file))

(add-to-list
	'consult-buffer-sources 'my/consult-buffer-source-project-files
	'append)

(use-package consult-dir
	:after consult
	:preface
	(require 'seq)

	(defun my/consult-dir-zoxide-dirs ()
		"Return zoxide directory candidates."
		(when (executable-find "zoxide")
			(delete-dups
				(seq-filter
					#'file-directory-p
					(mapcar #'file-name-as-directory
						(or (ignore-errors
								 (process-lines "zoxide" "query" "-l"))
							'()))))))

	(defvar my/consult-dir-source-zoxide
		`(:name "Zoxide"
			 :narrow ?z
			 :category file
			 :face consult-file
			 :history file-name-history
			 :enabled ,(lambda () (executable-find "zoxide"))
			 :items ,#'my/consult-dir-zoxide-dirs)
		"Zoxide source for `consult-dir'.")

	(defun my/consult-dir-source-value (source)
		"Return plist value of SOURCE."
		(cond
			((and (symbolp source) (boundp source))
				(symbol-value source))
			((listp source)
				source)
			(t nil)))

	(defun my/consult-dir-source-enabled-p (source)
		"Return non-nil if consult-dir SOURCE is enabled."
		(let ((enabled (plist-get source :enabled)))
			(cond
				((null enabled) t)
				((functionp enabled) (funcall enabled))
				(t enabled))))

	(defun my/consult-dir-source-items (source)
		"Return items from consult-dir SOURCE."
		(let ((items (plist-get source :items)))
			(cond
				((functionp items) (funcall items))
				((listp items) items)
				(t nil))))

	(defun my/consult-dir-item-directory (item)
		"Resolve consult-dir ITEM to a directory path."
		(let ((value (if (consp item) (cdr item) item)))
			(when (stringp value)
				(file-name-as-directory value))))

	(defun my/consult-dir-buffer-candidates ()
		"Return directory candidates from `consult-dir-sources' for `consult-buffer'."
		(let ((seen (make-hash-table :test #'equal))
				  result)
			(dolist (source consult-dir-sources)
				(let* ((src (my/consult-dir-source-value source))
							(name (or (plist-get src :name) "directory"))
							(category (plist-get src :category)))
					;; bookmark source は使わない
					(when (and src
								(not (eq category 'bookmark))
								(my/consult-dir-source-enabled-p src))
						(dolist (item (my/consult-dir-source-items src))
							(let ((dir (my/consult-dir-item-directory item)))
								(when (and dir
											(or (file-remote-p dir)
												(file-directory-p dir))
											(not (gethash dir seen)))
									(puthash dir t seen)
									(push
										(cons
											(format "%-12s %s"
												name
												(abbreviate-file-name dir))
											dir)
										result)))))))
			(nreverse result)))

	(defun my/consult-buffer-directory-action (dir)
		"Open `find-file' from DIR."
		(let ((default-directory (file-name-as-directory dir)))
			(call-interactively #'consult-buffer)))

	(defvar my/consult-source-consult-dir
		`(:name "directory"
			 :narrow ?d
			 :category file
			 :face consult-file
			 :history file-name-history
			 :items ,#'my/consult-dir-buffer-candidates
			 :action ,#'my/consult-buffer-directory-action)
		"Directory source backed by `consult-dir-sources'.")

	:config
	(add-to-list 'consult-dir-sources
      'my/consult-dir-source-zoxide
      t)

	(setq consult-buffer-sources
      '(consult-source-hidden-buffer
          consult-source-buffer
          consult-source-recent-file
          my/consult-buffer-source-project-files
          my/consult-source-consult-dir)))

(use-package
	orderless
	:custom
	(completion-styles '(orderless flex basic))
	(completion-category-defaults nil)
	(completion-category-overrides
		'((file (styles partial-completion basic))))
													 ;(completion-pcm-leading-wildcard t)
	)

(use-package
	embark
	:bind
	(("C-." . embark-act)
		("C-;" . embark-dwim)
		("C-h B" . embark-bindings))
	:init (setopt prefix-help-command #'embark-prefix-help-command)
	:config
	(setq embark-indicators
		'(embark-minimal-indicator
			 embark-highlight-indicator
			 embark-isearch-highlight-indicator))
	(setq embark-prompter #'embark-completing-read-prompter)
	;;minibufferを閉じない運用にしたい場合
	;; (setq embark-quit-after-action nil)
	)

(use-package embark-consult :after (embark consult))

(use-package consult-eglot :after (consult eglot))

(use-package
	consult-eglot-embark
	:after (embark consult-eglot)
	:config (consult-eglot-embark-mode 1))

(use-package
	corfu
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
	(corfu-popupinfo-mode)
	:config (keymap-unset corfu-map "RET"))

(use-package
	nerd-icons-corfu
	:config
	(add-to-list 'corfu-margin-formatters #'nerd-icons-corfu-formatter))

(use-package
	cape
	:init
	(add-hook 'completion-at-point-functions #'cape-file)
	(add-hook 'completion-at-point-functions #'cape-dabbrev)
	(add-hook 'completion-at-point-functions #'cape-emoji))

(context-menu-mode t)

(setopt
	completion-ignore-case t
	enable-recursive-minibuffers t
	read-extended-command-predicate #'command-completion-default-include-p
	minibuffer-prompt-properties '(read-only t cursor-intangible t face minibuffer-prompt))

(minibuffer-depth-indicate-mode 1)

(provide 'init-search)
