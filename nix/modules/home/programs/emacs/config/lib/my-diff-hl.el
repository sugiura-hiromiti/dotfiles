;;; my-diff-hl.el --- JJ compatibility for diff-hl -*- lexical-binding: t; -*-

(require 'diff-hl)

(defvar vc-jj-program)

(defun my/diff-hl-resolved-revision (original backend revision)
  "Resolve JJ REVISION without relying on vc-jj internals.
Delegate other BACKEND values to ORIGINAL."
  (if (not (eq backend 'JJ))
      (funcall original backend revision)
    (require 'vc-jj)
    (with-temp-buffer
      (let ((status (process-file vc-jj-program nil (list (current-buffer) nil)
                                  nil "log" "--no-graph" "-r" revision
                                  "-T" "commit_id" "-n" "1")))
        (unless (eq status 0)
          (error "JJ revision lookup failed (status %s)" status)))
      (goto-char (point-max))
      (unless (bobp)
        (when (bolp) (forward-char -1))
        (buffer-substring-no-properties (line-beginning-position)
                                        (line-end-position))))))

;; diff-hl passes an obsolete infile argument to vc-jj--process-lines.
;; Keep this scoped to revision lookup; vc-jj 0.5 removed that argument.
;; https://github.com/dgutov/diff-hl/blob/master/diff-hl.el
(advice-add 'diff-hl-resolved-revision :around #'my/diff-hl-resolved-revision)

(provide 'my-diff-hl)
;;; my-diff-hl.el ends here
