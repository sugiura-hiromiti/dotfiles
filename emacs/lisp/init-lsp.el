;;; -*- lexical-binding: t; -*-

(use-package eglot
  :hook (
			(rust-mode . eglot-ensure)
			(rust-ts-mode . eglot-ensure)
			(lua-mode . eglot-ensure)
			(lua-ts-mode . eglot-ensure)
			(haskell-ts-mode . eglot-ensure)
			(nix-ts-mode . eglot-ensure))
  :config
  (add-to-list 'eglot-server-programs
					'(nix-ts-mode . ("nil"))))

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
					'((rust-mode rust-ts-mode) .
					  ("rust-analyzer"
						:initializationOptions
						(:assist
						 (:preferSelf t)
						 :cargo
						 (:targetDir ,(expand-file-name "~/.cache/rust-analyzer/target/")
										 :buildScripts
										 (:enable t))
						 :check
						 (:command "clippy")
						 :checkOnSave t
						 :completion
						 (:fullFunctionSignatures
						  (:enable t)
						  :styleLints
						  (:enable t))
						 :hover
						 (:actions
						  (:enable t
									  :references
									  (:enable t))
						  :maxSubstitutionLength 40
						  :memoryLayout
						  (:niches t)
						  :show
						  (:traitAssocItems 5))
						 :inlayHint
						 (:enable t
									 :bindingModeHints
									 (:enable t)
									 :closureCaptureHints
									 (:enable t)
									 :closureReturnTypeHints
									 (:enable "always")
									 :discriminantHints
									 (:enable "always")
									 :expressionAdjustmentHints
									 (:enable "always")
									 :implicitDrops
									 (:enable t)
									 :lifetimeElisionHints
									 (:enable "always"
												 :useParameterNames t))
						 :interpret
						 (:tests t)
						 :lens
						 (:enable t
									 :references
									 (:adt
									  (:enable t)
									  :enumVariant
									  (:enable t)
									  :method
									  (:enable t)
									  :trait
									  (:enable t))
									 :updateTest
									 (:enable t))
						 :procMacro
						 (:enable t
									 :attributes
									 (:enable t))
						 :rustfmt
						 (:rangeFormatting
						  (:enable t))
						 :workspace
						 (:symbol
						  (:search
							(:kind "all_symbols"))))))))

(with-eval-after-load 'eglot
  (setq-default
   eglot-workspace-configuration
   '(:Lua
     (:runtime
      (:version "LuaJIT"))
     :diagnostics
     (:globals ["vim" "hs"])
     :workspace
     (;; :library ["/absolute/path/one" "/absolute/path/two"]
      ;; :checkThirdParty "Apply"
      )
     :format
     (:enable :json-false))))


(defun my/eglot-format-on-save ()
  "eglot管理下では保存前に整形する"
  (when (eglot-managed-p)
	 (condition-case nil
		  (eglot-format-buffer)
		(error nil))))

(defun my/eglot-setup-format-on-save ()
  "eglot開始/終了にあわせてbuffer-local hookを出し入れする"
  (if (eglot-managed-p)
		(add-hook 'before-save-hook #'my/eglot-format-on-save nil t)
	 (remove-hook 'before-save-hook #'my/eglot-format-on-save t)))

(add-hook 'eglot-managed-mode-hook #'my/eglot-setup-format-on-save)

(use-package apheleia
  :config
  (apheleia-global-mode +1))

(use-package elisp-autofmt
  :hook (emacs-lisp-mode . elisp-autofmt-mode)
  :config
  (setq elisp-autofmt-on-save-p 'always))


(provide 'init-lsp)
