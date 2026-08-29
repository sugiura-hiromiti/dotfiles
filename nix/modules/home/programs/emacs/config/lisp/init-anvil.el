;;; -*- lexical-binding: t; -*-

(use-package anvil
  :vc (:url "https://github.com/zawatton/anvil.el"
	    :rev "v1.3.0")
  :demand t
  :config
  (anvil-enable)
  (anvil-server-start))

(provide 'init-anvil)
