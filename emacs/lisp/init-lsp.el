;;; -*- lexical-binding: t; -*-

(use-package eglot
	:hook (
				(rust-mode . eglot-ensure)
				(rust-ts-mode . eglot-ensure)
				(lua-mode . eglot-ensure)
				(lua-ts-mode . eglot-ensure)
	)
)

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
     (:enable :json-false)))))

(provide 'init-lsp)
