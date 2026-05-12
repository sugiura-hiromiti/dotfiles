;;; -*- lexical-binding: t; -*-

(setopt
 package-install-upgrade-built-in t
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

;; Emacs internals such as VC and diff expect POSIX shell syntax.
(when-let ((shell (or (executable-find "bash")
                      (executable-find "sh"))))
  (setq shell-file-name shell
        shell-command-switch "-c"))

(when-let ((nu (executable-find "nu")))
  (setq explicit-shell-file-name nu))

(when (fboundp 'editorconfig-mode)
  (editorconfig-mode 1))

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

;; Load archive Compat before any package is installed or compiled.
;; Emacs 30's built-in stub can expand `compat-call' incorrectly.
(defun my/ensure-external-package (pkg)
  "Ensure PKG is installed from package archives and activated."
  (unless (assq pkg package-alist)
    (unless package-archive-contents
      (package-refresh-contents))
    (let ((package-install-upgrade-built-in t))
      (package-install pkg)))
  (package-activate pkg))

(my/ensure-external-package 'compat)
(require 'compat)

(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(require 'use-package)
(setq use-package-always-ensure t)

(use-package
 exec-path-from-shell
 :config
 (when-let ((nu (executable-find "nu")))
   (setq exec-path-from-shell-shell-name nu))
 (exec-path-from-shell-initialize))

(which-key-mode 1)

(setq
 scroll-margin 0
 scroll-conservatively 101
 scroll-up-aggressively nil
 scroll-down-aggressively nil
 scroll-preserve-screen-position t)

(setq
 compilation-scroll-output 'first-error
 compilation-auto-jump-to-first-error t)

(setq clean-buffer-list-delay-general 1)
(midnight-mode 1)

(provide 'init-core)
