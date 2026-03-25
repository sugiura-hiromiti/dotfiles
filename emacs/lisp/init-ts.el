;;; -*- lexical-binding: t; -*-

(setq treesit-font-lock-level 4)

(use-package haskell-ts-mode
				 :mode (("\\.hs\\'" . haskell-ts-mode)
				 		 ("\\lhs.\\'" . haskell-ts-mode)))
(use-package nushell-ts-mode
				 :mode ("\\.nu\\'" . nushell-ts-mode))
(use-package nix-ts-mode
				 :mode ("\\.nix\\'" . nix-ts-mode))
(use-package md-ts-mode
  :mode ("\\.md\\'" . md-ts-mode))
(use-package lua-ts-mode
  :mode ("\\.lua\\'" . lua-ts-mode))

(when (treesit-available-p)
  (setq major-mode-remap-alist
		  '((rust-mode . rust-ts-mode)
			 (haskell-mode . haskell-ts-mode)
			 (json-mode . json-ts-mode)
			 (js-json-mode . json-ts-mode)
			 (toml-mode . toml-ts-mode)
			 (conf-toml-mode . toml-ts-mode)
			 (nushell-mode . nushell-ts-mode)
			 (lua-mode . lua-ts-mode)
			 (nix-mode . nix-ts-mode)
			 (yaml-mode . yaml-ts-mode))))

(provide 'init-ts)
