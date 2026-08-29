;;; init-anvil-test.el --- Tests for init-anvil -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'use-package)

(defconst init-anvil-test--init-file
  (expand-file-name
   "../lisp/init-anvil.el"
   (file-name-directory (or load-file-name buffer-file-name))))

(ert-deftest init-anvil-installs-v1.3.0-from-official-repository ()
  (let ((use-package-always-ensure nil)
	(vc-call nil))
    (unwind-protect
	(cl-letf (((symbol-function 'package-installed-p)
		   (lambda (&rest _args) nil))
		  ((symbol-function 'package-vc-install)
		   (lambda (spec &optional revision _backend)
		     (setq vc-call (list spec revision))
		     (provide 'anvil)))
		  ((symbol-function 'anvil-enable) #'ignore)
		  ((symbol-function 'anvil-server-start) #'ignore))
	  (should (load init-anvil-test--init-file 'noerror 'nomessage))
	  (should
	   (equal vc-call
		  '((anvil :url "https://github.com/zawatton/anvil.el")
		    "v1.3.0"))))
      (setq features (delq 'init-anvil (delq 'anvil features))))))

(ert-deftest init-anvil-automatically-starts-enabled-server ()
  (let ((use-package-always-ensure nil)
	(anvil-enabled nil)
	(anvil-server-started nil))
    (unwind-protect
	(cl-letf (((symbol-function 'package-installed-p)
		   (lambda (&rest _args) nil))
		  ((symbol-function 'package-vc-install)
		   (lambda (&rest _args) (provide 'anvil)))
		  ((symbol-function 'anvil-enable)
		   (lambda () (setq anvil-enabled t)))
		  ((symbol-function 'anvil-server-start)
		   (lambda () (setq anvil-server-started t))))
	  (should (load init-anvil-test--init-file nil 'nomessage))
	  (should anvil-enabled)
	  (should anvil-server-started))
      (setq features (delq 'init-anvil (delq 'anvil features))))))

;;; init-anvil-test.el ends here
