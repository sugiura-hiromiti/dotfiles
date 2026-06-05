;;; -*- lexical-binding: t; -*-

(declare-function flymake-mode "flymake")
(declare-function hl-todo-flymake "hl-todo")
(defvar flymake-diagnostic-functions)

(defun my/hl-todo-flymake-setup ()
	"現在のbufferでhl-todoのFlymake diagnosticsを有効化する。"
	(add-hook 'flymake-diagnostic-functions #'hl-todo-flymake nil t)
	(flymake-mode 1))

(use-package ghostel
	:commands (ghostel ghostel-compile)
	:custom
	(ghostel-module-auto-install 'download))

(use-package diff-hl
	:config
	(global-diff-hl-mode)
	(diff-hl-flydiff-mode 1))

(use-package majutsu
	:vc (:url "https://github.com/0WD0/majutsu"
			 :rev :newest))

(use-package envrc
	:hook (after-init . envrc-global-mode))

(use-package hl-todo
	:hook (prog-mode . hl-todo-mode)
	:init
	(add-hook 'prog-mode-hook #'my/hl-todo-flymake-setup 90))

(use-package elfeed
	:commands (elfeed)
	:custom
	;; 未読かつ直近1週間だけ表示
	(elfeed-search-filter "@1-week-ago +unread ")
	(elfeed-use-curl t)
	:config
	(setq elfeed-feeds
		'(("https://apribase.net/program/feed")
			 ("https://opaupafz2.hatenablog.com/rss")
			 ("https://this-week-in-rust.org/rss.xml")
			 ("https://www.matem.unam.mx/~omar/apropos-emacs.xml"))))

(defun my/elfeed-play-enclosure-with-mpv (&optional enclosure-index)
	"play current elfeed enclosure with mpv"
	(interactive)
	(unless (derived-mode-p 'elfeed-show-mode)
		(user-error "not in elfeed-show-mode"))
	(let* ((entry elfeed-show-entry)
				(enclosures (elfeed-entry-enclosures entry)))
		(unless enclosures
			(user-error "no enclosure in this entry"))
		(let * ((idx (or enclosure-index
							 (if (= 1 (length enclosures))
								 1
								 (read-number
									 (format "Enclosure 1-%d: " (length enclosures))
									 1))))
					 (url (car (elt enclosures (1- idx)))))
			(start-process "elfeed-mpv" "*elfeed-mpv*" "mpv" "--no-video" url)
			(message "Playing: %s" url))))

(with-eval-after-load 'elfeed-show
	(keymap-set elfeed-show-mode-map "P" #'my/elfeed-play-enclosure-with-mpv))

(use-package eww
	:ensure nil
	:custom
	;; サイト側の色、フォントを無視する
	(shr-use-colors nil)
	(shr-use-fonts nil))

(use-package browse-url
	:ensure nil
	:custom
	(browse-url-browser-function #'eww-browse-url)
	(browse-url-secondary-browser-function #'browse-url-default-browser))

(provide 'init-misc)
