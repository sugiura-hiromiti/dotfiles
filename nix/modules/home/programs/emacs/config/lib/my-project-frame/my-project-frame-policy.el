;;; policy.el --- provide policy management entrypoint -*- lexical-binding: t; -*-

;;; Commentary:
;;

;;; Code:

;; TODO: project.elのproject判定とmy-project-frameのscope判定を同期させるべきか判断する
;; 同期させない場合：実装がより楽
;; 同期させる場合：project.elを利用する他のpackageとも歩調があう

;; TODO: デフォルトポリシーを作る
(defcustom my-project-frame-policies nil
	"List of policies."
	:type 'hook
	:group 'my-project-frame)

(provide 'my-project-frame-policy)

;;; my-project-frame-policy.el ends here
