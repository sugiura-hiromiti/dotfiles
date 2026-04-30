;;; -*- lexical-binding: t; -*-

(set-language-environment "Utf-8")
(prefer-coding-system 'utf-8-unix)

(setopt inhibit-startup-screen t
		  inhibit-startup-message t
		  inhibit-scratch-message nil
		  display-line-numbers-type t
		  indent-tabs-mode t
		  tab-width 3
		  tab-bar-show 1
		  )
(setq whitespace-style '(face tabs tab-mark)
		whitespace-display-mappings
		'((tab-mark ?\t [?\│ ?\t] [?\t ?\t]))
		;; flymake-show-diagnostics-at-end-of-line t
		)
(when (fboundp 'editorconfig-mode)
  (editorconfig-mode 1))
(global-whitespace-mode 1)

(tab-bar-mode)
(global-display-line-numbers-mode 1)
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

(use-package doom-modeline
  :init
  (doom-modeline-mode 1)
  :custom
  (doom-modeline-enable-buffer-position t)
  (doom-modeline-position-column-line-format '("%l:%c"))
  (doom-modeline-check 'auto)
  :config
  (doom-modeline-def-segment my-breadcrumbs
	 "Project/Imenu breadcrumbs for doom-modeline."
	 (when (not doom-modeline--limited-width-p)
		(let* ((proj  (ignore-errors (breadcrumb-project-crumbs)))
				 (imenu (ignore-errors (breadcrumb-imenu-crumbs)))
				 (items (delq nil (list proj imenu))))
		  (when items
			 (concat
			  (doom-modeline-spc)
			  (mapconcat #'identity items " › ")
			  (doom-modeline-spc))))))
  (doom-modeline-def-modeline 'my-main
	 '(bar my-breadcrumbs)
	 '(major-mode vcs check))
  (doom-modeline-set-modeline 'my-main t))

(use-package breadcrumb
  :config
  (breadcrumb-mode -1))

(use-package ligature
  :ensure t
  :config
  ;; Maple Mono NF CN の calt をかなり広く拾う版
  (ligature-set-ligatures
   't
   '("::" ":::" "?:" ":?" ":?>" "<:" ":>" ":<" "<:<" ">:>"
     "__" "#{" "#[" "#(" "#?" "#!" "#:" "#=" "#_" "#__" "#_(" "]#"
     "#######" "<<" "<<<" ">>" ">>>" "{{" "}}" "{|" "|}" "{{--" "{{!--"
     "--}}" "[|" "|]" "!!" "||" "??" "???" "&&" "&&&" "//" "///"
     "/*" "/**" "*/" "++" "+++" ";;" ";;;" ".." "..." ".?" "?."
     "..<" ".=" "<~" "~>" "~~" "<~>" "<~~" "~~>" "-~" "~-"
     "~~~~~~~" "-------" "<>" "</" "/>" "</>" "<+" "+>" "<+>" "<*" "*>"
     "<*>" ">=" "<=" "<=<" ">=>" "<=>" "<==>" "<==" "==>" "=>" "==" "==="
     "!=" "!==" "=/=" "=!=" "|=" "<=|" "|=>" "=<=" "=>=" ">=<" ":=" "=:"
     ":=:" "=:=" "\\\\" "\\'" "\\." "--" "---" "<#--" "<!---->" "<!--"
     "<->" "<-->" "->" "<-" "-->" "<--" ">->" "<-<" "|->" "<-|"
     "<|||" "|||>" "<||" "||>" "<|" "|>" "<|>" "_|_"
     "[TRACE]" "[DEBUG]" "[INFO]" "[WARN]" "[ERROR]" "[FATAL]"
     "[TODO]" "[FIXME]" "[NOTE]" "[HACK]" "[MARK]" "[EROR]" "[WARNING]"
     "todo))" "fixme))" "Cl" "al" "cl" "el" "il" "tl" "ul"
     "ff" "tt" "all" "ell" "ill" "ull"
     "0xA12" "0x56" "1920x1080"))

  (global-ligature-mode t))

(use-package colorful-mode
  :config
  (global-colorful-mode 1))

;; TODO: あとで消す
;; (use-package popper
;;   :init
;;   (setq popper-reference-buffers
;; 		  '("^\\*Messages\\*"
;; 			 "\\*scratch\\*"
;; 			 "\\*eldoc\\*"
;; 			 help-mode
;; 			 eat-mode
;; 			 compilation-mode))
;;   :config
;;   (popper-mode 1)
;;   (popper-echo-mode 1)

;;   ;; (defun my/popper-popup-local-keys ()
;;   ;; 	 "Popupばっふぁの中でだけ使うきーを設定"
;;   ;; 	 (local-set-key (kbd "C-'") #'popper-cycle))
;;   ;; 	(add-hook 'popper-open-popup-hook #'my/popper-popup-local-keys)
;;   )

(require 'tab-bar)
(require 'seq)

(tab-bar-mode 1)

(setopt tab-bar-show 1
        switch-to-buffer-obey-display-actions t)

(defvar my/popup-tab-name "Popper")
(defvar my/popup-return-tab nil)

(defun my/current-tab-name ()
  (let ((tab (seq-find (lambda (tab)
                         (memq 'current-tab tab))
                       (tab-bar-tabs))))
    (alist-get 'name tab)))

(defun my/tab-exists-p (name)
  (seq-some (lambda (tab)
              (equal (alist-get 'name tab) name))
            (tab-bar-tabs)))

(defun my/ensure-popup-tab ()
  (unless (my/tab-exists-p my/popup-tab-name)
    (tab-new)
    (tab-rename my/popup-tab-name)
    (set-window-buffer (selected-window)
                       (get-buffer-create "*Messages*"))))

(defun my/popup-buffer-p (buffer-or-name &rest _args)
  (and (display-graphic-p)
       (let* ((buf (get-buffer buffer-or-name))
              (name (if (bufferp buffer-or-name)
                        (buffer-name buffer-or-name)
                      buffer-or-name)))
         (or
          (string-match-p
           (rx bos "*"
               (or "Help" "helpful"
                   "Backtrace"
                   "Occur"
                   "grep"
                   "xref"
                   "Async Shell Command"
                   "eshell"
                   "shell"
                   "eat")
               (* any)
               "*"
               eos)
           name)
          (and buf
               (with-current-buffer buf
                 (derived-mode-p 'help-mode
                                 'compilation-mode
                                 'grep-mode
                                 'occur-mode)))))))

(add-to-list
 'display-buffer-alist
 `(my/popup-buffer-p
   (display-buffer-in-tab)
   (tab-name . ,my/popup-tab-name)
   (inhibit-same-window . t)))

(defun my/toggle-popup-tab ()
  (interactive)
  (if (equal (my/current-tab-name) my/popup-tab-name)
      (if (and my/popup-return-tab
               (my/tab-exists-p my/popup-return-tab)
               (not (equal my/popup-return-tab my/popup-tab-name)))
          (tab-switch my/popup-return-tab)
        (tab-recent))
    (setq my/popup-return-tab (my/current-tab-name))
    (my/ensure-popup-tab)
    (tab-switch my/popup-tab-name)))

(global-set-key (kbd "C-,") #'my/toggle-popup-tab)

(use-package agent-shell)

(provide 'init-ui)
