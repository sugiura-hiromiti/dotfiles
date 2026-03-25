;;; -*- lexical-binding: t; -*-

(use-package eat
	:commands (eat))

(defvar my/eat-scratchpad-buf-name "*eat-scratchpad*")
(defvar my/eat-scratchpad-display-action
	'((display-buffer-in-child-frame)
		 (window-height . 0.8)
		 (window-width . 0.8)
		 (child-frame-parameters)
		 . ((undecorated . t)
				(minibuffer . nil)
				(internal-border-width . 12)
				(left . 0.22)
				(top . 0.10)
				(keep-ratio . t)
				(no-other-frame . t)
				(auto-hide-function . make-frame-invisible))))
(defun my/eat-scratchpad-buffer ()
	"Return the scratchpad eat buffer, creating it if needed"
	(or (get-buffer my/eat-scratchpad-buf-name)
		(save-window-excursion
			(let ((buf (progn
							  (eat)
							  (current-buffer))))
				(with-current-buffer buf
					(rename-buffer my/eat-scratchpad-buf-name t))
				(get-buffer my/eat-scratchpad-buf-name)))))
(defun my/eat-scratchpad-frame ()
	"return the child frame showing the scratchpad, or nil"
	(when-let* ))

(provide 'init-misc)
