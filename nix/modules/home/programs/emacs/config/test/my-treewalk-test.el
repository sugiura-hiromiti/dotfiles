;;; my-treewalk-test.el --- Tests for structural Tree-sitter navigation -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'ert)
(require 'treesit)

(eval-and-compile
	(defmacro use-package (&rest _arguments) nil))

(add-to-list
	'load-path
	(expand-file-name
		"../lisp"
		(file-name-directory (or load-file-name buffer-file-name))))

(add-to-list 'load-path
   (expand-file-name
      "../lib"
      (file-name-directory
         (or load-file-name buffer-file-name))))

(require 'my-treewalk)
(require 'init-edit)

(defconst my/treesit-treewalk-test--rust-source
	(concat
		"fn outer() {\n"
		"    let alpha = 1;\n"
		"    if alpha > 0 {\n"
		"        println!(\"yes\");\n"
		"    }\n"
		"    let omega = 2;\n"
		"}\n"
		"\n"
		"fn sibling() {}\n"))

(defmacro my/treesit-treewalk-test--with-rust-source (source &rest body)
	"SOURCEとRust parserを持つ一時bufferでBODYを実行する。"
	(declare (indent 0) (debug t))
	`(progn
		 (skip-unless
			 (and (treesit-available-p)
			    (treesit-language-available-p 'rust)))
		 (with-temp-buffer
			 (insert ,source)
			 (treesit-parser-create 'rust)
			 (goto-char (point-min))
			 (let ((my/treesit-treewalk-pulse nil))
				 ,@body))))

(defmacro my/treesit-treewalk-test--with-rust-buffer (&rest body)
	"標準fixtureとRust parserを持つ一時bufferでBODYを実行する。"
	(declare (indent 0) (debug t))
	`(my/treesit-treewalk-test--with-rust-source
		 my/treesit-treewalk-test--rust-source
		 ,@body))

(defun my/treesit-treewalk-test--goto-line (line)
	"一時bufferのLINEの最初の非blank文字へ移動する。"
	(goto-char (point-min))
	(forward-line (1- line))
	(back-to-indentation))

(defun my/treesit-treewalk-test--current-node-type ()
	"現在行の正規化済みnode typeを返す。"
	(treesit-node-type
		(my/treesit-treewalk--anchor-node
			(my/treesit-treewalk--current-anchor))))

(ert-deftest my/treesit-treewalk-test-four-directions ()
	(my/treesit-treewalk-test--with-rust-buffer
		(my/treesit-treewalk-in)
		(should (= (line-number-at-pos) 2))
		(should (equal (my/treesit-treewalk-test--current-node-type)
		           "let_declaration"))

		(my/treesit-treewalk-down)
		(should (= (line-number-at-pos) 3))

		(my/treesit-treewalk-in)
		(should (= (line-number-at-pos) 4))

		(my/treesit-treewalk-out)
		(should (= (line-number-at-pos) 3))

		(my/treesit-treewalk-down)
		(should (= (line-number-at-pos) 6))

		(my/treesit-treewalk-up)
		(should (= (line-number-at-pos) 3))))

(ert-deftest my/treesit-treewalk-test-out-and-unconfined-neighbor ()
	(my/treesit-treewalk-test--with-rust-buffer
		(my/treesit-treewalk-test--goto-line 2)
		(my/treesit-treewalk-out)
		(should (= (line-number-at-pos) 1))
		(should (equal (my/treesit-treewalk-test--current-node-type)
		           "function_item"))

		(my/treesit-treewalk-down)
		(should (= (line-number-at-pos) 9))
		(should (equal (my/treesit-treewalk-test--current-node-type)
		           "function_item"))))

(ert-deftest my/treesit-treewalk-test-prefix-count ()
	(my/treesit-treewalk-test--with-rust-buffer
		(my/treesit-treewalk-test--goto-line 2)
		(my/treesit-treewalk-down 2)
		(should (= (line-number-at-pos) 6))

		(my/treesit-treewalk-down -1)
		(should (= (line-number-at-pos) 3))))

(ert-deftest my/treesit-treewalk-test-final-empty-line-is-a-no-op ()
	(my/treesit-treewalk-test--with-rust-buffer
		(goto-char (point-max))
		(let ((origin (point)))
			(my/treesit-treewalk-down)
			(should (= (point) origin))
			(my/treesit-treewalk-in)
			(should (= (point) origin)))))

(ert-deftest my/treesit-treewalk-test-comments-and-empty-lines-are-skipped ()
	(my/treesit-treewalk-test--with-rust-source
		"fn main() {\n    // note\n\n    let value = 1;\n}\n"
		(my/treesit-treewalk-in)
		(should (= (line-number-at-pos) 4))

		(my/treesit-treewalk-test--goto-line 2)
		(my/treesit-treewalk-down)
		(should (= (line-number-at-pos) 4))))

(ert-deftest my/treesit-treewalk-test-blank-lines-are-skipped ()
	(my/treesit-treewalk-test--with-rust-source
		"fn main() {\n        \n    let value = 1;\n}\n"
		(my/treesit-treewalk-in)
		(should (= (line-number-at-pos) 3))))

(ert-deftest my/treesit-treewalk-test-same-line-node-is-not-a-neighbor ()
	(my/treesit-treewalk-test--with-rust-source
		(concat
			"fn main() {\n"
			"    let values = [\n"
			"        one,\n"
			"        two, three,\n"
			"        four,\n"
			"    ];\n"
			"}\n")
		(my/treesit-treewalk-test--goto-line 4)
		(search-forward "three")
		(should (equal (treesit-node-text
								(my/treesit-treewalk--anchor-node
									(my/treesit-treewalk--current-anchor)))
		           "two"))

		(my/treesit-treewalk-down)
		(should (= (line-number-at-pos) 5))
		(should (equal (treesit-node-text
								(my/treesit-treewalk--anchor-node
									(my/treesit-treewalk--current-anchor)))
		           "four"))))

(ert-deftest my/treesit-treewalk-test-falls-back-without-parser ()
	(with-temp-buffer
		(insert "first\nsecond\n")
		(goto-char (point-min))
		(forward-line 1)
		(my/treesit-treewalk-up)
		(should (= (line-number-at-pos) 1))
		(my/treesit-treewalk-down)
		(should (= (line-number-at-pos) 2))))

(ert-deftest my/treesit-treewalk-test-fallback-preserves-goal-column ()
	(with-temp-buffer
		(insert "abcdefghij\nx\nabcdefghij\n")
		(goto-char (point-min))
		(forward-char 7)
		(my/treesit-treewalk-down)
		(setq last-command #'next-line)
		(my/treesit-treewalk-down)
		(should (= (line-number-at-pos) 3))
		(should (= (current-column) 7))))

(ert-deftest my/treesit-treewalk-test-multiple-languages ()
	(let ((fixtures
				'((lua
					  "function outer()\n  local alpha = 1\n  local omega = 2\nend\n"
					  2 3)
					 (nix "let\n  alpha = 1;\n  omega = 2;\nin alpha\n" 2 3)
					 (haskell "module Main where\n\nalpha = 1\nomega = 2\n" 3 4)))
	        (tested 0))
		(dolist (fixture fixtures)
			(pcase-let ((`(,language ,source ,from ,expected) fixture))
				(when (treesit-language-available-p language)
					(setq tested (1+ tested))
					(with-temp-buffer
						(insert source)
						(treesit-parser-create language)
						(my/treesit-treewalk-test--goto-line from)
						(let ((my/treesit-treewalk-pulse nil))
							(my/treesit-treewalk-down))
						(should (= (line-number-at-pos) expected))))))
		(skip-unless (> tested 0))))

(ert-deftest my/treesit-treewalk-test-node-bounds-stop-before-root ()
	(my/treesit-treewalk-test--with-rust-buffer
		(search-forward "alpha")
		(backward-char)
		(let ((bounds (my/treesit-treewalk-node-bounds)))
			(should (equal (buffer-substring-no-properties
									(car bounds) (cdr bounds))
			           "alpha"))
			(goto-char (cdr bounds))
			(set-mark (car bounds))
			(activate-mark))

		(let ((previous (cons (region-beginning) (region-end)))
		        bounds)
			(while (setq bounds (my/treesit-treewalk-node-bounds))
				(should (or (< (car bounds) (car previous))
				           (> (cdr bounds) (cdr previous))))
				(setq previous bounds)
				(goto-char (cdr bounds))
				(set-mark (car bounds))
				(activate-mark))
			(should (equal (buffer-substring-no-properties
									(car previous) (cdr previous))
			           "fn outer() {\n    let alpha = 1;\n    if alpha > 0 {\n        println!(\"yes\");\n    }\n    let omega = 2;\n}")))))

(ert-deftest my/treesit-treewalk-test-meow-selection-dispatch ()
	(let (calls)
		(cl-letf (((symbol-function 'my/treesit-treewalk-available-p)
						 (lambda () t))
						((symbol-function 'use-region-p) (lambda () t))
						((symbol-function 'meow-bounds-of-thing)
							(lambda (thing) (push (list 'expand thing) calls)))
						((symbol-function 'meow-pop-selection)
							(lambda () (interactive) (push 'contract calls))))
			(call-interactively #'my/meow-treesit-expand)
			(call-interactively #'my/meow-treesit-contract))
		(should (equal calls '(contract (expand 110)))))

	(let (calls)
		(cl-letf (((symbol-function 'my/treesit-treewalk-available-p)
						 (lambda () nil))
						((symbol-function 'puni-expand-region)
							(lambda () (interactive) (push 'puni calls)))
						((symbol-function 'meow-grab)
							(lambda () (interactive) (push 'grab calls))))
			(call-interactively #'my/meow-treesit-expand)
			(call-interactively #'my/meow-treesit-contract))
		(should (equal calls '(grab puni))))

	(let (calls)
		(cl-letf (((symbol-function 'my/treesit-treewalk-available-p)
						 (lambda () t))
						((symbol-function 'use-region-p) (lambda () nil))
						((symbol-function 'meow-grab)
							(lambda () (interactive) (push 'grab calls))))
			(call-interactively #'my/meow-treesit-contract))
		(should (equal calls '(grab)))))

(ert-deftest my/treesit-treewalk-test-meow-movement-syncs-selection ()
	(let (calls)
		(cl-letf (((symbol-function 'use-region-p) (lambda () t))
						((symbol-function 'my/treesit-treewalk-available-p)
							(lambda () t))
						((symbol-function 'meow-cancel-selection)
							(lambda () (push 'cancel calls)))
						((symbol-function 'my/treesit-treewalk-up)
							(lambda (count) (push (list 'move count) calls)))
						((symbol-function 'my/meow-treesit-expand)
							(lambda () (push 'expand calls))))
			(my/meow-treesit-up 2))
		(should (equal calls '(expand (move 2) cancel)))))

(provide 'my-treewalk-test)

;;; my-treewalk-test.el ends here
