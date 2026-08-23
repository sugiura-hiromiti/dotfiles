;;; -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'pulse)
(require 'subr-x)
(require 'treesit)

(defgroup my/treesit-treewalk nil
	"Tree-sitterとインデントを使った構造移動。"
	:group 'editing)

(defcustom my/treesit-treewalk-pulse t
	"Non-nilなら移動先の構文ノードを短時間highlightする。"
	:type 'boolean
	:group 'my/treesit-treewalk)

;; Treewalker.nvimの既定分類をnative treesitのnode typeへ移植したもの。
(defconst my/treesit-treewalk--jump-excluded-patterns
	'("comment" "source" "text" "attribute_item" "decorat" "else"
		 "elif" "end_tag" "declaration_list" "compound_statement" "document"))

(defconst my/treesit-treewalk--highlight-excluded-patterns
	'("body" "\\`block\\'" "\\`block_[^_]+\\'" "document"))

(defconst my/treesit-treewalk--augment-patterns
	'("comment" "\\`source\\'" "text" "attribute_item" "decorat"))

(defconst my/treesit-treewalk--language-jump-excluded-patterns
	'((c-sharp . ("\\`block\\'"))
		 (haskell . ("\\`imports\\'" "\\`declarations\\'"))))

(defconst my/treesit-treewalk--language-highlight-excluded-patterns
	'((haskell . ("\\`imports\\'" "\\`declarations\\'"))))

(cl-defstruct
	(my/treesit-treewalk--anchor
		(:constructor my/treesit-treewalk--anchor-create))
	node row start-row column indent line)

(defvar my/treesit-treewalk--line-start-cache nil
	"構造移動中だけ使う、各行の開始位置を収めたvector。")

(defvar my/treesit-treewalk--single-parser-cache nil
	"構造移動中にbuffer唯一のparserを保持する。")

(defun my/treesit-treewalk-available-p ()
	"現在のbufferに利用可能なTree-sitter parserがあればnon-nilを返す。"
	(and (treesit-available-p)
	   (ignore-errors (treesit-parser-list))))

(defun my/treesit-treewalk--collect-line-starts ()
	"現在のbufferにある各行の開始位置をvectorで返す。"
	(save-excursion
		(goto-char (point-min))
		(let ((starts (list (point))))
			(while (zerop (forward-line 1))
				(push (point) starts))
			(vconcat (nreverse starts)))))

(defun my/treesit-treewalk--line-start-position (row)
	"現在のbufferの1始まりのROWの開始位置を返す。"
	(if my/treesit-treewalk--line-start-cache
		(and (<= 1 row (length my/treesit-treewalk--line-start-cache))
			(aref my/treesit-treewalk--line-start-cache (1- row)))
		(save-excursion
			(goto-char (point-min))
			(and (zerop (forward-line (1- row))) (point)))))

(defun my/treesit-treewalk--row-at-position (position)
	"POSITIONの1始まりの行番号を返す。"
	(if (not my/treesit-treewalk--line-start-cache)
		(line-number-at-pos position)
		(let ((low 0)
		        (high (1- (length my/treesit-treewalk--line-start-cache)))
		        (answer 0))
			(while (<= low high)
				(let ((middle (/ (+ low high) 2)))
					(if (<= (aref my/treesit-treewalk--line-start-cache middle)
					       position)
						(setq answer middle
						   low (1+ middle))
						(setq high (1- middle)))))
			(1+ answer))))

(defun my/treesit-treewalk--line-count ()
	"現在のbufferの行数を返す。"
	(if my/treesit-treewalk--line-start-cache
		(length my/treesit-treewalk--line-start-cache)
		(line-number-at-pos (point-max))))

(defun my/treesit-treewalk--line-text (row)
	"現在のbufferの1始まりのROWにある文字列を返す。"
	(when-let ((start
					  (and (integerp row)
					     (> row 0)
					     (my/treesit-treewalk--line-start-position row))))
		(save-excursion
			(goto-char start)
			(buffer-substring-no-properties start (line-end-position)))))

(defun my/treesit-treewalk--line-navigation-positions (row)
	"ROWの最初の非blank位置と、その次の位置を返す。"
	(when-let ((start (my/treesit-treewalk--line-start-position row)))
		(save-excursion
			(goto-char start)
			(let ((end (line-end-position)))
				(skip-chars-forward " \t" end)
				(cons (point)
				   (and (< (point) end) (1+ (point))))))))

(defun my/treesit-treewalk--line-indent (line)
	"LINE先頭にあるspace/tabのbyte数を1始まりで返す。"
	(1+ (string-bytes
			 (or (and (string-match "\\`[ \t]*" line)
			        (match-string 0 line))
			    ""))))

(defun my/treesit-treewalk--node-start-row (node)
	"NODEの開始行を1始まりで返す。"
	(my/treesit-treewalk--row-at-position (treesit-node-start node)))

(defun my/treesit-treewalk--node-start-column (node)
	"NODEの開始byte列を1始まりで返す。"
	(save-excursion
		(goto-char (treesit-node-start node))
		(1+ (string-bytes
				 (buffer-substring-no-properties
					 (line-beginning-position)
					 (point))))))

(defun my/treesit-treewalk--parser-at (position)
	"POSITIONを担当するparserを返す。"
	(or my/treesit-treewalk--single-parser-cache
	   (and (fboundp 'treesit-local-parsers-at)
	      (car (ignore-errors (treesit-local-parsers-at position))))
	   (when-let ((language (ignore-errors (treesit-language-at position))))
			(car (treesit-parser-list nil language)))
	   (car (treesit-parser-list))))

(defun my/treesit-treewalk--named-node-at (position)
	"POSITIONを覆う最小のnamed nodeを返す。"
	(when-let* ((parser (my/treesit-treewalk--parser-at position))
	              (seed (treesit-node-at position parser t))
	              (root (treesit-parser-root-node (treesit-node-parser seed))))
		(or (treesit-node-descendant-for-range root position position t)
		   root)))

(defun my/treesit-treewalk--named-node-on (beginning end)
	"BEGINNINGからENDまでを覆う最小のnamed nodeを返す。"
	(when-let ((parser (my/treesit-treewalk--parser-at beginning)))
		(treesit-node-on beginning end parser t)))

(defun my/treesit-treewalk--named-parent (node)
	"NODEに最も近いnamed parentを返す。"
	(treesit-parent-until
		node
		(lambda (parent) (treesit-node-check parent 'named))))

(defun my/treesit-treewalk-node-bounds ()
	"現在の選択より真に大きいnamed構文nodeの境界を返す。
Meow Thingのbounds関数として使い、rootではnilを返して展開を止める。"
	(when (my/treesit-treewalk-available-p)
		(condition-case nil
			(let* ((selected (use-region-p))
						(beginning (if selected (region-beginning) (point)))
						(end (if selected (region-end) (point)))
						(node
							(if selected
								(my/treesit-treewalk--named-node-on beginning end)
								(my/treesit-treewalk--named-node-at (point)))))
				;; 同じ境界を持つwrapper nodeは選択履歴へ積まない。
				(when selected
					(while (and node
					          (= beginning (treesit-node-start node))
					          (= end (treesit-node-end node)))
						(setq node (my/treesit-treewalk--named-parent node))))
				;; buffer全体はMeowのbuffer thingへ任せる。
				(when (and node (treesit-node-parent node))
					(cons (treesit-node-start node) (treesit-node-end node))))
			(treesit-error nil))))

(defun my/treesit-treewalk--node-matches-p
	(node patterns &optional language-patterns)
	"NODEのtypeがPATTERNSまたはLANGUAGE-PATTERNSに一致するか返す。"
	(let ((case-fold-search nil)
	        (type (treesit-node-type node)))
		(or (cl-some (lambda (pattern) (string-match-p pattern type)) patterns)
		   (cl-some
				(lambda (pattern) (string-match-p pattern type))
				(alist-get (treesit-node-language node) language-patterns)))))

(defun my/treesit-treewalk--root-node-p (node)
	"NODEが構文木のrootならnon-nilを返す。"
	(null (treesit-node-parent node)))

(defun my/treesit-treewalk--jump-target-p (node)
	"NODEが移動先として扱えるならnon-nilを返す。"
	(and node
	   (not (my/treesit-treewalk--root-node-p node))
	   (not
			(my/treesit-treewalk--node-matches-p
				node
				my/treesit-treewalk--jump-excluded-patterns
				my/treesit-treewalk--language-jump-excluded-patterns))))

(defun my/treesit-treewalk--highlight-target-p (node)
	"NODEが正規化・highlight対象ならnon-nilを返す。"
	(and node
	   (not (my/treesit-treewalk--root-node-p node))
	   (not
			(my/treesit-treewalk--node-matches-p
				node
				my/treesit-treewalk--highlight-excluded-patterns
				my/treesit-treewalk--language-highlight-excluded-patterns))))

(defun my/treesit-treewalk--augment-target-p (node)
	"NODEがcommentやdecoratorなどの付加要素ならnon-nilを返す。"
	(and node
	   (not (my/treesit-treewalk--root-node-p node))
	   (my/treesit-treewalk--node-matches-p
			node my/treesit-treewalk--augment-patterns)))

(defun my/treesit-treewalk--comment-node-p (node)
	"NODEがcomment相当ならnon-nilを返す。"
	(my/treesit-treewalk--node-matches-p node '("comment" "source" "text")))

(defun my/treesit-treewalk--normalize-node (node)
	"同じ行から始まる最も外側の表示可能なNODEを返す。"
	(let ((anchor node)
	        (row (my/treesit-treewalk--node-start-row node))
	        (iterator node))
		(while (and iterator
		          (= row (my/treesit-treewalk--node-start-row iterator)))
			(when (my/treesit-treewalk--highlight-target-p iterator)
				(setq anchor iterator))
			(setq iterator (treesit-node-parent iterator)))
		anchor))

(defun my/treesit-treewalk--node-at-row (row)
	"ROWを代表する正規化済み構文nodeを返す。"
	(when-let* ((line (my/treesit-treewalk--line-text row))
	              (positions (my/treesit-treewalk--line-navigation-positions row)))
		(let ((node (when-let ((candidate
										  (my/treesit-treewalk--named-node-at (car positions))))
							(my/treesit-treewalk--normalize-node candidate))))
			(if (and (my/treesit-treewalk--highlight-target-p node)
			       (= (my/treesit-treewalk--node-start-row node) row))
				node
				(let ((next-node
							(when-let* ((position (cdr positions))
											  (candidate
												  (my/treesit-treewalk--named-node-at position)))
								(my/treesit-treewalk--normalize-node candidate))))
					(cond
						((and (my/treesit-treewalk--highlight-target-p next-node)
					       (= (my/treesit-treewalk--node-start-row next-node) row))
							next-node)
						((my/treesit-treewalk--highlight-target-p node) node)
						((my/treesit-treewalk--highlight-target-p next-node) next-node)
						(t (or next-node node))))))))

(defun my/treesit-treewalk--anchor-from-node (node &optional row)
	"NODEから移動用anchorを作る。ROWは移動先の表示行。"
	(let* ((node (my/treesit-treewalk--normalize-node node))
				(start-row (my/treesit-treewalk--node-start-row node))
				(anchor-row (or row start-row))
				(line (my/treesit-treewalk--line-text anchor-row)))
		(when line
			(let* ((indent-row
						 (if (or (string-blank-p line)
						        (not (my/treesit-treewalk--jump-target-p node)))
							 start-row
							 anchor-row))
						(indent-line (my/treesit-treewalk--line-text indent-row)))
				(when indent-line
					(my/treesit-treewalk--anchor-create
						:node node
						:row anchor-row
						:start-row start-row
						:column (my/treesit-treewalk--node-start-column node)
						:indent (my/treesit-treewalk--line-indent indent-line)
						:line line))))))

(defun my/treesit-treewalk--anchor-at-row (row)
	"ROWを代表する移動用anchorを返す。"
	(when-let ((node (my/treesit-treewalk--node-at-row row)))
		(my/treesit-treewalk--anchor-from-node
			node
			(if (my/treesit-treewalk--augment-target-p node)
				(my/treesit-treewalk--node-start-row node)
				row))))

(defun my/treesit-treewalk--current-anchor ()
	"pointがある行の移動用anchorを返す。"
	(my/treesit-treewalk--anchor-at-row
		(my/treesit-treewalk--row-at-position (point))))

(defun my/treesit-treewalk--node-equal-p (first second)
	"FIRSTとSECONDが同じ構文nodeならnon-nilを返す。"
	(and first second (treesit-node-eq first second)))

(defun my/treesit-treewalk--strict-ancestor-p (ancestor node)
	"ANCESTORがNODEのstrict ancestorならnon-nilを返す。"
	(let ((iterator (treesit-node-parent node))
	        found)
		(while (and iterator (not found))
			(if (my/treesit-treewalk--node-equal-p ancestor iterator)
				(setq found t)
				(setq iterator (treesit-node-parent iterator))))
		found))

(defun my/treesit-treewalk--has-augment-child-p (node)
	"NODEが付加要素の直接childを持つならnon-nilを返す。"
	(cl-loop for index below (treesit-node-child-count node)
	   thereis
	   (my/treesit-treewalk--augment-target-p
			(treesit-node-child node index))))

(defun my/treesit-treewalk--has-same-indent-jump-ancestor-p
	(current candidate)
	"CANDIDATEが別scopeの同indent nodeに包まれていればnon-nilを返す。"
	(let ((current-node (my/treesit-treewalk--anchor-node current))
	        (candidate-indent (my/treesit-treewalk--anchor-indent candidate))
	        (candidate-row (my/treesit-treewalk--anchor-row candidate))
	        (iterator
				  (treesit-node-parent (my/treesit-treewalk--anchor-node candidate))))
		(catch 'answer
			(while iterator
				(let* ((iterator-row
							 (my/treesit-treewalk--node-start-row iterator))
							(iterator-line
								(my/treesit-treewalk--line-text iterator-row)))
					(when (and (< iterator-row candidate-row)
					         iterator-line
					         (my/treesit-treewalk--highlight-target-p iterator)
					         (not
									(my/treesit-treewalk--has-augment-child-p iterator))
					         (= (my/treesit-treewalk--line-indent iterator-line)
					            candidate-indent))
						(cond
							((my/treesit-treewalk--node-equal-p iterator current-node)
								(let ((first-child (treesit-node-child current-node 0 t)))
									(throw
										'answer
										(not
											(and first-child
												(= (my/treesit-treewalk--node-start-row current-node)
													(my/treesit-treewalk--node-start-row first-child))
												(= (my/treesit-treewalk--node-start-column current-node)
													(my/treesit-treewalk--node-start-column
														first-child)))))))
							((my/treesit-treewalk--strict-ancestor-p iterator current-node)
								(throw 'answer nil))
							(t (throw 'answer t)))))
				(setq iterator (treesit-node-parent iterator)))
			nil)))

(defun my/treesit-treewalk--find-neighbor (direction current)
	"CURRENTからDIRECTION方向にある同indentの移動先を返す。"
	(let* ((step (if (eq direction 'up) -1 1))
				(row (+ (my/treesit-treewalk--anchor-row current) step))
				(max-row (my/treesit-treewalk--line-count)))
		(catch 'target
			(while (<= 1 row max-row)
				(when-let ((candidate (my/treesit-treewalk--anchor-at-row row)))
					(when (and (= (my/treesit-treewalk--anchor-start-row candidate) row)
					         (not
									(string-blank-p
										(my/treesit-treewalk--anchor-line candidate)))
					         (= (my/treesit-treewalk--anchor-indent candidate)
					            (my/treesit-treewalk--anchor-indent current))
					         (my/treesit-treewalk--jump-target-p
									(my/treesit-treewalk--anchor-node candidate))
					         (not
									(my/treesit-treewalk--has-same-indent-jump-ancestor-p
										current candidate)))
						(throw 'target candidate)))
				(setq row (+ row step)))
			nil)))

(defun my/treesit-treewalk--find-in (current)
	"CURRENTの内側にある最初の移動先を返す。"
	(let ((row (1+ (my/treesit-treewalk--anchor-row current)))
	        (max-row (my/treesit-treewalk--line-count)))
		(catch 'target
			(while (<= row max-row)
				(when-let ((line (my/treesit-treewalk--line-text row)))
					(unless (string-blank-p line)
						(let ((indent (my/treesit-treewalk--line-indent line))
						        (candidate (my/treesit-treewalk--anchor-at-row row)))
							(when (and candidate
							         (my/treesit-treewalk--jump-target-p
											(my/treesit-treewalk--anchor-node candidate)))
								(cond
									((> indent (my/treesit-treewalk--anchor-indent current))
										(throw 'target candidate))
									((and
										 (= indent (my/treesit-treewalk--anchor-indent current))
										 (my/treesit-treewalk--strict-ancestor-p
											 (my/treesit-treewalk--anchor-node current)
											 (my/treesit-treewalk--anchor-node candidate)))
										(throw 'target candidate))))
							(when (< indent (my/treesit-treewalk--anchor-indent current))
								(throw 'target nil)))))
				(setq row (1+ row)))
			nil)))

(defun my/treesit-treewalk--find-out (current)
	"CURRENTの外側にある最初の移動先を返す。"
	(if (> (my/treesit-treewalk--anchor-row current)
	       (my/treesit-treewalk--anchor-start-row current))
		(my/treesit-treewalk--anchor-from-node
			(my/treesit-treewalk--anchor-node current)
			(my/treesit-treewalk--anchor-start-row current))
		(when (my/treesit-treewalk--comment-node-p
					(my/treesit-treewalk--anchor-node current))
			(setq current
				(or (my/treesit-treewalk--find-neighbor 'down current) current)))
		(let* ((current-node (my/treesit-treewalk--anchor-node current))
					(current-column
						(my/treesit-treewalk--anchor-column current))
					(iterator (treesit-node-parent current-node))
					fallback)
			(catch 'target
				(while iterator
					(when (my/treesit-treewalk--jump-target-p iterator)
						(if (/= (my/treesit-treewalk--node-start-column iterator)
						       current-column)
							(throw
								'target
								(my/treesit-treewalk--anchor-from-node iterator))
							(setq fallback iterator)))
					(setq iterator (treesit-node-parent iterator)))
				(and fallback
				   (my/treesit-treewalk--anchor-from-node fallback))))))

(defun my/treesit-treewalk--find-target (direction current)
	"CURRENTからDIRECTIONへ移動するtargetを返す。"
	(pcase direction
		('up (my/treesit-treewalk--find-neighbor 'up current))
		('down (my/treesit-treewalk--find-neighbor 'down current))
		('in (my/treesit-treewalk--find-in current))
		('out (my/treesit-treewalk--find-out current))))

(defun my/treesit-treewalk--opposite-direction (direction)
	"DIRECTIONの反対方向を返す。"
	(pcase direction
		('up 'down)
		('down 'up)
		('in 'out)
		('out 'in)))

(defun my/treesit-treewalk--jump (anchor)
	"ANCHORの行の最初の非blank文字へ移動する。"
	(when-let ((positions
					  (my/treesit-treewalk--line-navigation-positions
						  (my/treesit-treewalk--anchor-row anchor))))
		(goto-char (car positions))
		anchor))

(defun my/treesit-treewalk--pulse (anchor)
	"ANCHORの構文nodeを短時間highlightする。"
	(when (and my/treesit-treewalk-pulse anchor)
		(let ((pulse-flag t)
		        (pulse-delay 0.025)
		        (pulse-iterations 10)
		        (node (my/treesit-treewalk--anchor-node anchor)))
			(pulse-momentary-highlight-region
				(treesit-node-start node)
				(treesit-node-end node)))))

(defun my/treesit-treewalk--move (direction count fallback)
	"DIRECTIONへCOUNT回構造移動し、parserがなければFALLBACKを呼ぶ。"
	(if (not (my/treesit-treewalk-available-p))
		(progn
			;; next-line/previous-line use `this-command' to preserve goal column.
			(setq this-command fallback)
			(funcall fallback count))
		(let* ((parsers (treesit-parser-list nil nil t))
					(my/treesit-treewalk--single-parser-cache
						(and (null (cdr parsers)) (car parsers)))
					(my/treesit-treewalk--line-start-cache
						(my/treesit-treewalk--collect-line-starts))
					(direction
						(if (< count 0)
							(my/treesit-treewalk--opposite-direction direction)
							direction))
					(remaining (abs count))
					last-target)
			(while (> remaining 0)
				(if-let* ((current (my/treesit-treewalk--current-anchor))
								(target
									(my/treesit-treewalk--find-target direction current)))
					(progn
						(my/treesit-treewalk--jump target)
						(setq last-target target
						   remaining (1- remaining)))
					;; Leftだけは外側がなくても現在anchorの行頭へ正規化する。
					(when (and current (eq direction 'out))
						(my/treesit-treewalk--jump current)
						(setq last-target current))
					(setq remaining 0)))
			(my/treesit-treewalk--pulse last-target))))

(defun my/treesit-treewalk-up (&optional count)
	"同じindentにある前の構造へ移動する。"
	(interactive "p")
	(my/treesit-treewalk--move 'up (or count 1) #'previous-line))

(defun my/treesit-treewalk-down (&optional count)
	"同じindentにある次の構造へ移動する。"
	(interactive "p")
	(my/treesit-treewalk--move 'down (or count 1) #'next-line))

(defun my/treesit-treewalk-in (&optional count)
	"現在の構造の内側へ移動する。"
	(interactive "p")
	(my/treesit-treewalk--move 'in (or count 1) #'forward-char))

(defun my/treesit-treewalk-out (&optional count)
	"現在の構造の外側へ移動する。"
	(interactive "p")
	(my/treesit-treewalk--move 'out (or count 1) #'backward-char))

(provide 'my-treewalk)
