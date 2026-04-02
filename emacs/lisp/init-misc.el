;;; -*- lexical-binding: t; -*-

(use-package eat
  :ensure t
  :commands (eat))

(defvar my/eat-scratchpad-buffer-name "*eat-scratchpad*")

(defvar my/eat-scratchpad-display-action
  '((display-buffer-in-child-frame)
    (window-height . 0.7)
    (window-width . 0.8)
    (child-frame-parameters
     . ((undecorated . t)
        (minibuffer . nil)
        (internal-border-width . 12)
        (left . 0.22)
        (top . 0.10)
        (keep-ratio . t)
        (no-other-frame . t)
        (auto-hide-function . make-frame-invisible)))))

(defun my/eat-scratchpad--buffer ()
  "Return the scratchpad Eat buffer, creating it if needed."
  (or (get-buffer my/eat-scratchpad-buffer-name)
      (save-window-excursion
        (let ((buf (progn
                     (eat)
                     (current-buffer))))
          (with-current-buffer buf
            (rename-buffer my/eat-scratchpad-buffer-name t)
            ;; 見た目用。不要なら消してよい。
            (setq-local mode-line-format nil)
            (setq-local header-line-format " Eat scratchpad "))
          (get-buffer my/eat-scratchpad-buffer-name)))))

(defun my/eat-scratchpad--frame ()
  "Return the child frame showing the scratchpad, or nil."
  (when-let* ((buf (get-buffer my/eat-scratchpad-buffer-name))
              (win (get-buffer-window buf t))
              (fr  (window-frame win)))
    (and (frame-live-p fr)
         (frame-parent fr)
         fr)))

(defun my/toggle-eat-scratchpad ()
  "Toggle Eat scratchpad child frame."
  (interactive)
  (if-let ((fr (my/eat-scratchpad--frame)))
      (if (frame-visible-p fr)
          (make-frame-invisible fr)
        (make-frame-visible fr)
        (select-frame-set-input-focus fr)
        (when-let ((win (get-buffer-window
                         my/eat-scratchpad-buffer-name t)))
          (select-window win)))
    (let* ((buf (my/eat-scratchpad--buffer))
           (display-buffer-overriding-action
            my/eat-scratchpad-display-action)
           (win (display-buffer buf))
           (fr  (window-frame win)))
      (select-frame-set-input-focus fr)
      (select-window win))))

(provide 'init-misc)
