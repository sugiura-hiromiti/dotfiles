;;; -*- lexical-binding: t; -*-

(declare-function eglot-format-buffer "eglot")
(declare-function eglot-inlay-hints-mode "eglot")
(declare-function eglot-managed-p "eglot")
(defvar eglot-server-programs)
(defvar flymake-diagnostic-functions)

(defconst my/rust-analyzer-initialization-options
  '(:assist
    (:preferSelf t)
    :cargo
    (:targetDir t
                :buildScripts (:enable t))
    :check (:command "clippy")
    :checkOnSave t
    :completion
    (:fullFunctionSignatures (:enable t))
    :diagnostics
    (:styleLints (:enable t))
    :hover
    (:actions
     (:enable t :references (:enable t))
     :maxSubstitutionLength 40
     :memoryLayout (:niches t)
     :show (:traitAssocItems 5))
    :inlayHints
    (:bindingModeHints (:enable t)
                       :chainingHints (:enable t)
                       :closingBraceHints (:enable t :minLines 0)
                       :closureCaptureHints (:enable t)
                       :closureReturnTypeHints (:enable "always")
                       :discriminantHints (:enable "always")
                       ;; deref / borrow / coercionなどの調整ヒント
                       :expressionAdjustmentHints
                       (:enable "always"
                                :mode "prefix"
                                :hideOutsideUnsafe :json-false
                                :disableReborrows :json-false)
                       :genericParameterHints
                       (:const (:enable t)
                               :lifetime (:enable t)
                               :type (:enable t))
                       :implicitDrops (:enable t)
                       :implicitSizedBoundHints (:enable t)
                       :impliedDynTraitHints (:enable t)
                       :lifetimeElisionHints
                       (:enable "always" :useParameterNames t)
                       :maxLength nil
                       :parameterHints (:enable t :missingArguments (:enable t))
                       :rangeExclusiveHints (:enable t)
                       :renderColons t
                       :typeHints
                       (:enable t
                                :hideClosureInitialization :json-false
                                :hideClosureParameter :json-false
                                :hideInferredTypes :json-false
                                :hideNamedConstructor :json-false
                                :location "inline"))
    :interpret (:tests t)
    :lens
    (:enable
     t
     :references
     (:adt
      (:enable t)
      :enumVariant (:enable t)
      :method (:enable t)
      :trait (:enable t))
     :updateTest (:enable t))
    :procMacro (:enable t :attributes (:enable t))
    :rustfmt (:rangeFormatting (:enable t))
    :workspace
    (:symbol (:search (:kind "all_symbols"))))
  "rust-analyzerに渡す初期化オプション。")

(defconst my/eglot-workspace-configuration
  '(:Lua
    (:runtime (:version "LuaJIT"))
    :diagnostics (:globals ["vim" "hs"])
    :workspace
    ( ;; :library ["/absolute/path/one" "/absolute/path/two"]
     ;; :checkThirdParty "Apply"
     )
    :format (:enable :json-false))
  "Eglotに渡すworkspace/configuration。")

(defun my/eglot-configure-server-programs ()
  "Eglot用のlanguage server設定を登録する。"
  (add-to-list 'eglot-server-programs '(nix-ts-mode . ("nil")))
  (add-to-list
   'eglot-server-programs
   `((rust-mode rust-ts-mode)
     .
     ("rust-analyzer"
      :initializationOptions
      ,my/rust-analyzer-initialization-options)))
  (add-to-list 'eglot-server-programs
               '((toml-ts-mode :language-id "toml")
                 . ("taplo" "lsp" "stdio"))))

(defun my/eglot-enable-inlay-hints ()
  "Eglot管理下のbufferでinlay hintsを有効化する。"
  (when (fboundp 'eglot-inlay-hints-mode)
    (eglot-inlay-hints-mode 1)))

(defun my/rust-ts-disable-built-in-flymake ()
  "rust-ts-mode組み込みのFlymake checkerをbuffer-localに外す。"
  (setq-local flymake-diagnostic-functions
              (remq 'rust-ts-flymake flymake-diagnostic-functions)))

(use-package
  eglot
  :hook
  ((rust-mode . eglot-ensure)
	(rust-ts-mode . eglot-ensure)
	(lua-mode . eglot-ensure)
	(lua-ts-mode . eglot-ensure)
	(haskell-ts-mode . eglot-ensure)
	(nix-ts-mode . eglot-ensure))
  :config
  (my/eglot-configure-server-programs)
  (setq-default eglot-workspace-configuration my/eglot-workspace-configuration))

(add-hook 'eglot-managed-mode-hook #'my/eglot-enable-inlay-hints)
(add-hook 'rust-ts-mode-hook #'my/rust-ts-disable-built-in-flymake)

(defun my/eglot-format-on-save ()
  "eglot管理下では保存前に整形する"
  (when (eglot-managed-p)
    (condition-case nil
        (eglot-format-buffer)
      (error
       nil))))

(defun my/eglot-setup-format-on-save ()
  "eglot開始/終了にあわせてbuffer-local hookを出し入れする"
  (if (eglot-managed-p)
      (add-hook 'before-save-hook #'my/eglot-format-on-save nil t)
    (remove-hook 'before-save-hook #'my/eglot-format-on-save t)))

(add-hook 'eglot-managed-mode-hook #'my/eglot-setup-format-on-save)

(use-package apheleia :config (apheleia-global-mode +1))

(provide 'init-lsp)
