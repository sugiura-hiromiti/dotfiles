;;; my-diff-hl-test.el --- Tests for JJ diff highlighting -*- lexical-binding: t; -*-

(require 'ert)
(require 'diff-hl)
(require 'diff-hl-flydiff)
(require 'vc-jj)

(add-to-list 'load-path
             (expand-file-name "../lib" (file-name-directory load-file-name)))
(require 'my-diff-hl)

(defmacro my/diff-hl-test--with-jj-repository (&rest body)
  "Run BODY in a temporary JJ repository."
  (declare (indent 0) (debug t))
  `(let* ((directory (make-temp-file "my-diff-hl-test-" t))
          (default-directory (file-name-as-directory directory))
          (diff-hl-temporary-directory temporary-file-directory))
     (unwind-protect
         (progn
           (process-lines "jj" "git" "init" "--colocate" ".")
           ,@body)
       (delete-directory directory t))))

(ert-deftest my/diff-hl-test-resolves-jj-root-revision ()
  (my/diff-hl-test--with-jj-repository
    (should (equal (diff-hl-resolved-revision 'JJ "root()")
                   "0000000000000000000000000000000000000000"))))

(ert-deftest my/diff-hl-test-saves-with-jj-flydiff ()
  (my/diff-hl-test--with-jj-repository
    (let ((file (expand-file-name "sample.txt"))
          (diff-hl-update-async nil)
          (was-enabled diff-hl-flydiff-mode)
          buffer)
      (unwind-protect
          (progn
            (with-temp-file file (insert "before\n"))
            (process-lines "jj" "new" "-m" "diff-hl test")
            (with-temp-file file (insert "after\n"))
            (setq buffer (find-file-noselect file))
            (with-current-buffer buffer
              (diff-hl-flydiff-mode 1)
              (diff-hl-mode 1)
              (goto-char (point-max))
              (insert "saved\n")
              (save-some-buffers t (lambda () (eq (current-buffer) buffer)))
              (should-not (buffer-modified-p))
              (diff-hl-update)
              (should (seq-some
                       (lambda (overlay) (overlay-get overlay 'diff-hl))
                       (overlays-in (point-min) (point-max)))))
            (with-temp-buffer
              (insert-file-contents file)
              (should (equal (buffer-string) "after\nsaved\n"))))
        (unless was-enabled (diff-hl-flydiff-mode -1))
        (when (buffer-live-p buffer)
          (with-current-buffer buffer (set-buffer-modified-p nil))
          (kill-buffer buffer))))))

(ert-deftest my/diff-hl-test-preserves-other-backends ()
  (should (equal (diff-hl-resolved-revision 'SVN "123") "123")))

;;; my-diff-hl-test.el ends here
