;;; -*- lexical-binding: t; -*-

(declare-function treesit-available-p "treesit")
(declare-function treesit-language-available-p "treesit")
(defvar major-mode-remap-alist)
(defvar treesit-font-lock-level)
(defvar warning-suppress-log-types nil)
(defvar warning-suppress-types nil)

(setq treesit-font-lock-level 4)

(defun my/treesit-languages-available-p (&rest languages)
  "LANGUAGESのtree-sitter grammarがすべて使えるならnon-nilを返す。"
  (let ((warning-suppress-types (cons '(treesit) warning-suppress-types))
        (warning-suppress-log-types
         (cons '(treesit) warning-suppress-log-types)))
    (and (treesit-available-p)
         (catch 'missing
           (dolist (language languages t)
             (unless (car (treesit-language-available-p language t))
               (throw 'missing nil)))))))

(defun my/add-treesit-auto-mode (regexp mode &rest languages)
  "LANGUAGESが使えるときだけREGEXPをMODEに関連付ける。"
  (when (and (fboundp mode)
             (apply #'my/treesit-languages-available-p languages))
    (add-to-list 'auto-mode-alist (cons regexp mode))))

(defun my/add-treesit-mode-remap (base-mode ts-mode &rest languages)
  "LANGUAGESが使えるときだけBASE-MODEをTS-MODEへremapする。"
  (when (and (fboundp ts-mode)
             (apply #'my/treesit-languages-available-p languages))
    (add-to-list 'major-mode-remap-alist (cons base-mode ts-mode))))

;; ts-mode packageをここでuse-package宣言すると、grammar未導入時に
;; package側のnative compile warningが出る。autoload済みのmodeだけ登録する。
(defun my/setup-treesit-mode-associations ()
  "利用可能なtree-sitter grammarだけmode関連付けへ登録する。"
  (my/add-treesit-auto-mode "\\.hs\\'" 'haskell-ts-mode 'haskell)
  (my/add-treesit-auto-mode "\\.lhs\\'" 'haskell-ts-mode 'haskell)
  (my/add-treesit-auto-mode "\\.nu\\'" 'nushell-ts-mode 'nu)
  (my/add-treesit-auto-mode "\\.nix\\'" 'nix-ts-mode 'nix)
  (my/add-treesit-auto-mode "\\.md\\'" 'md-ts-mode 'markdown 'markdown-inline)
  (my/add-treesit-auto-mode "\\.lua\\'" 'lua-ts-mode 'lua)
  (my/add-treesit-auto-mode "\\.rs\\'" 'rust-ts-mode 'rust)

  (my/add-treesit-mode-remap 'rust-mode 'rust-ts-mode 'rust)
  (my/add-treesit-mode-remap 'haskell-mode 'haskell-ts-mode 'haskell)
  (my/add-treesit-mode-remap 'json-mode 'json-ts-mode 'json)
  (my/add-treesit-mode-remap 'js-json-mode 'json-ts-mode 'json)
  (my/add-treesit-mode-remap 'toml-mode 'toml-ts-mode 'toml)
  (my/add-treesit-mode-remap 'conf-toml-mode 'toml-ts-mode 'toml)
  (my/add-treesit-mode-remap 'nushell-mode 'nushell-ts-mode 'nu)
  (my/add-treesit-mode-remap 'lua-mode 'lua-ts-mode 'lua)
  (my/add-treesit-mode-remap 'nix-mode 'nix-ts-mode 'nix)
  (my/add-treesit-mode-remap 'yaml-mode 'yaml-ts-mode 'yaml))

(add-hook 'after-init-hook #'my/setup-treesit-mode-associations)

(provide 'init-ts)
