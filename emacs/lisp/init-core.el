;;; -*- lexical-binding: t; -*-

(setopt package-install-upgrade-built-in t
		  initial-scratch-message nil
		  use-dialog-box nil
		  ring-bell-function #'ignore
		  read-process-output-max (* 1024 1024)
		  completion-cycle-threshold 3
		  tab-always-indent 'complete
		  select-enable-clipboard t
		  make-backup-files nil
		  global-auto-revert-non-file-buffers t
		  which-key-idle-delay 0.1
		  text-mode-ispell-word-completion nil)

(when (fboundp 'editorconfig-mode)
  (editorconfig-mode 1))
(global-whitespace-mode 1)

;; 履歴
(savehist-mode 1)
(recentf-mode 1)
(global-auto-revert-mode 1)
(pixel-scroll-precision-mode 1)
(electric-pair-mode 1)
(repeat-mode 1)

(require 'package)
(setq package-archives
		'(("gnu" . "https://elpa.gnu.org/packages/")
		  ("nongnu" . "https://elpa.nongnu.org/nongnu/")
		  ("melpa" . "https://melpa.org/packages/")))

(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t)

(use-package  exec-path-from-shell
  :config
  (setq exec-path-from-shell-shell-name "/run/current-system/sw/bin/nu")
  (exec-path-from-shell-initialize))

(which-key-mode 1)

(setq scroll-margin 0
		scroll-conservatively 101
		scroll-up-aggressively nil
		scroll-down-aggressively nil
		scroll-preserve-screen-position t)

(setq compilation-scroll-output 'first-error
		compilation-auto-jump-to-first-error t)

(provide 'init-core)
