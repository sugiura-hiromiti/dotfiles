;;; my-project-frame.el --- project-frame.el -*- lexical-binding: t; -*-

;;; Commentary:
;;

;;;

;;; Code:

(require 'project)
(require 'seq)

(defun project-frame-buffer-scope (&optional buffer)
	"BUFFERがどのプロジェクトに属するのかを判定する."
	(with-current-buffer (or buffer (current-buffer))
		(project-frame-directory-scope default-directory)))

(defun project-frame-normalize-project-root (root)
	"ROOTをproject-frameの統一表現にnormalizeする.
契約は以下.
1. absolute.
2. symlink解決済み.
3. 必ず末尾/."
	(when (file-remote-p root)
		(error "Remote project roots are not supported yet: %s" root))
	(file-name-as-directory
		(file-truename
			(expand-file-name root))))

(defun project-frame-directory-scope (directory)
	"DIRECTORYに対するプロジェクトスコープを判定して返す."
	(let ((default-directory directory))
		(if-let* ((project (project-current nil)))
			(project-frame-normalize-project-root (project-root project))
			'projectless)))

(defun project-frame-frame-scope (&optional frame)
	"FRAMEがどのプロジェクトに属するかを判定する."
	(or (frame-parameter (or frame (selected-frame))
			 'project-frame-scope)
		'projectless))

(defun project-frame-compatible-p (frame buffer)
	"FRAMEとBUFFERが同じprojectに属するかを判定する."
	(equal (project-frame-buffer-scope buffer) (project-frame-frame-scope frame)))

(defun project-frame-valid-p (&optional frame)
	"FRAME内の全てのwindowに対してframeのprojectとwindowが表示するbufferのprojectが一致する事を検証する."
	(let* ((frame (or frame (selected-frame)))
				(scope (project-frame-frame-scope frame)))
		(seq-every-p
			(lambda (window)
				(equal scope
					(project-frame-buffer-scope (window-buffer window))))
			(window-list frame 'nomini))))

(defun project-frame-valid-state-p ()
	"1. 全frameがproject-frame-valid-p.
2. 同じprojectのframeが2つ以上存在しない."
	(let ((frames (project-frame-managed-frames))
			  (seen-scopes nil))
		(and ;; 全てのフレームはframeのscope内のバッファのみを持つ
			(seq-every-p #'project-frame-valid-p frames)
			;; 全てのスコープは1つのフレームに属する
			(seq-every-p
				(lambda (frame)
					(let ((scope (project-frame-frame-scope frame)))
						(if (member scope seen-scopes)
							nil
							(push scope seen-scopes)
							t)))
				frames))))

(defun project-frame-for-scope (scope)
	"Return the unique frame asigned to SCOPE."
	(let ((frames
				(seq-filter
					(lambda (frame)
						(equal (project-frame-frame-scope frame)
							scope))
					(project-frame-managed-frames))))
		(pcase frames
			('() nil)
			(`(,frame) frame)
			(_
				(error "Multiple frames have project scope %S" scope)))))

(defun project-frame-set-frame-scope (frame scope)
	"FRAMEにSCOPEを設定する."
	(let* ((scope
				 (if (eq scope 'projectless)
					 'projectless
					 (project-frame-normalize-project-root scope)))
				(existing (project-frame-for-scope scope)))
		;; 1 project = 1 frame
		(when (and existing
					(not (eq existing frame)))
			(error "Scope %S already belongs to another frame" scope))
		;; frame内で現在表示中のbufferが全てscopeでなければscopeを変更した瞬間にinvariant違反となる
		(unless
			(seq-every-p
				(lambda (window)
					(equal scope
						(project-frame-buffer-scope (window-buffer window))))
				(window-list frame 'nomini))
			(error "Frame contains buffers incompatible with scope %S" scope))
		(set-frame-parameter
			frame
			'project-frame-scope
			(unless (eq  scope 'projectless)
				scope))
		frame))

(defun project-frame-managed-frame-p (frame)
	"FRAMEが通常のgraphical frameの場合はnon-nilを返す."
	(and (display-graphic-p frame)
		(null (frame-parameter frame 'parent-frame))
		(not (frame-parameter frame 'tooltip))))

(defun project-frame-managed-frames ()
	"My-project-frameの管理対象である可視フレームの全リストを返す."
	(seq-filter #'project-frame-managed-frame-p (frame-list)))

(defun project-frame-create-frame (buffer)
	"BUFFERのスコープに対応するフレームが存在しない場合新たにframeを作成する."
	(let* ((buffer (get-buffer buffer))
				(scope (project-frame-buffer-scope buffer)))
		(when (project-frame-for-scope scope)
			(error "Frame for scope %S already exists" scope))
		(with-current-buffer buffer
			(make-frame
				`((project-frame-scope
					  . ,(unless (eq scope 'projectless)
							  scope)))))))

(defun project-frame-for-buffer (buffer)
	"BUFFERの所属するべきフレームを返す.必要に応じて作成までする."
	(let* ((buffer (get-buffer buffer))
				(scope (project-frame-buffer-scope buffer)))
		(or (project-frame-for-scope scope)
			(project-frame-create-frame buffer))))

(defun project-frame-display-buffer (buffer _alist)
	"BUFFERを対応するframeで表示する."
	(let* ((buffer (get-buffer buffer))
				(frame (project-frame-for-buffer buffer))
				(window (or (get-buffer-window buffer frame)
							  (let ((selected (frame-selected-window frame)))
								  (if (window-minibuffer-p selected)
									  (car (window-list frame 'nomini))
									  selected)))))
		(set-window-buffer window buffer)
		window))

(defun project-frame-display-buffer-condition (buffer _action)
	"BUFFERが別のframeのスコープに属する場合non  nilを返す."
	(let ((buffer (get-buffer buffer))
			  (frame (selected-frame)))
		(and buffer
			(project-frame-managed-frame-p frame)
			(not (project-frame-compatible-p frame buffer)))))

(defvar project-frame--display-log nil)

(defun project-frame--probe-display (buffer &rest _action)
	"BUFFERの属性を記録する."
	(when-let* ((buffer (get-buffer buffer))
					  (frame (selected-frame)))
		(push
			(list
				:buffer (buffer-name buffer)
				:buffer-scope (project-frame-buffer-scope buffer)
				:frame-scope (project-frame-frame-scope frame))
			project-frame--display-log))
	nil)

(defvar project-frame--mismatches nil)

(defun project-frame--audit ()
	"Frameとscopeが合致しないbufferを記録する."
	(dolist (frame (project-frame-managed-frames))
		(dolist (window (window-list frame 'nomini))
			(let ((buffer (window-buffer window)))
				(unless (project-frame-compatible-p frame buffer)
					(push
						(list
							:buffer (buffer-name buffer)
							:buffer-scope (project-frame-buffer-scope buffer)
							:frame-scope (project-frame-frame-scope frame))
						project-frame--mismatches))))))

(add-hook 'window-state-change-hook
	#'project-frame--audit)

(defun project-frame-invalid-windows ()
	"スコープ違反している(FRAME . WINDOW)の組を返す."
	(let (invalid)
		(dolist (frame (project-frame-managed-frames))
			(dolist (window (window-list frame 'nomini))
				(unless (project-frame-compatible-p
							  frame (window-buffer window))
					(push (cons frame window) invalid))))
		(nreverse invalid)))

(defun project-frame-close-window (window)
	"WINDOW, tab, frameを閉じる."
	(pcase (window-deletable-p window)
		('t
			(delete-window window)
			t)
		('tab
			(with-selected-frame (window-frame window)
				(tab-bar-close-tab))
			(not (window-live-p window)))
		('frame
			(delete-frame (window-frame window))
			t)
		(_ nil)))

(defun project-frame-reconcile-window (&optional window)
	"WINDOWのバッファが現在のframeに合わない場合は別フレームに移動し元のwindowは削除する."
	(interactive)
	(let* ((window (or window (selected-window)))
				(frame (window-frame window))
				(buffer (window-buffer window)))
		(cond
			((not (project-frame-managed-frame-p frame))
				nil)
			((project-frame-compatible-p frame buffer)
				t)
			(t
				(project-frame-display-buffer buffer nil)
				(project-frame-close-window window)))))

(defvar project-frame--reconciling nil)

(defun project-frame-reconcile ()
	"Scopeの一致しない全てのwindowを適切なframeに移動する."
	(interactive)
	(unless project-frame--reconciling
		(let ((project-frame-reconciling t))
			(dolist (entry (project-frame-invalid-windows))
				(let ((window (cdr entry)))
					(when (window-live-p window)
						(project-frame-reconcile-window window))))))
	(project-frame-valid-state-p))

(provide 'my-project-frame)

;;; my-project-frame.el ends here
