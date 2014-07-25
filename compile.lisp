(defparameter *linker-symbols* nil)

(defun el-num (var frame)
  (- (length frame) (length (member var frame))))

(defun find-symbol-lm (var env &optional (depth 0))
  (cond ((null env) (error "unknown variable ~A" var))
	((member var (first env)) `(ld ,depth ,(el-num var (first env))))
	(t (find-symbol-lm var (rest env) (1+ depth)))))

(defparameter *builtin-ops*
  '((+ . add)
    (- . sub)
    (* . mul)
    (/ . div)
    (= . ceq)
    (> . cgt)
    (>= . cgte)
    (car . car)
    (cdr . cdr)
    (atom . atom)
    (print . dbug)
    (cons . cons)))

(defun is-builtin (exp)
  (and (consp exp) (assoc (first exp) *builtin-ops*)))

(defun get-builtin-opcode (op)
  (list (list (cdr (assoc op *builtin-ops*)))))

(defun compile-builtin (exp env)
  (append (compile-list (rest exp) env)
	  (get-builtin-opcode (first exp))))

(defun is-application (exp)
  (and (consp exp) (symbolp (first exp))))

(defun compile-list (exp-list env)
  (cond ((null exp-list) nil)
	(t (append (compile-lm (first exp-list) env)
		   (compile-list (rest exp-list) env)))))

(defun apply-defined (exp env)
  (append (compile-list (rest exp) env)
	  `(,(find-symbol-lm (first exp) env)
	    (ap ,(length (rest exp))))))

(defun is-special (exp sym)
  (and (consp exp) (eq (first exp) sym)))

(defun compile-block (sym body env linkage)
  (push (cons sym (append (compile-lm body env) linkage)) *linker-symbols*))

(defun compile-lambda (exp env &optional (lambda-sym (gensym)))
  (unless (= 3 (length exp)) (error "malformed lambda body ~A" exp))
  (unless (listp (second exp)) (error "invalid lambda list ~A" (second exp)))
  (compile-block lambda-sym (third exp) (cons (second exp) env) '((rtn)))
  `((ldf ,lambda-sym)))

(defun compile-if (exp env)
  (let ((true-sym (gensym))
	(false-sym (gensym)))
    (compile-block true-sym (third exp) env '((join)))
    (compile-block false-sym (fourth exp) env '((join)))
    (append (compile-lm (second exp) env)
	    `((sel ,true-sym ,false-sym)))))

(defun compile-funcall (exp env)
  (append (compile-list (cddr exp) env)
	  (compile-lm (second exp) env)
	  `((ap ,(length (cddr exp))))))

(defun compile-define (exp env)
  (compile-lambda (rest exp) env (second exp)))

(defun compile-lm (exp env)
  (cond ((numberp exp) `((ldc ,exp)))
	((symbolp exp) (list (find-symbol-lm exp env)))
	((is-builtin exp) (compile-builtin exp env))
	((is-special exp 'if) (compile-if exp env))
	((is-special exp 'defun) (compile-define exp env))
	((is-special exp 'lambda) (compile-lambda exp env))
	((is-special exp 'funcall) (compile-funcall exp env))
	((is-application exp) (apply-defined exp env))
	(t (error "bad expression ~A" exp))))

(defun get-top-level-names (program)
  (mapcar #'second program))

(defun read-program-defines (stream &optional accumulator)
  (let ((define (read stream nil)))
    (if (null define)
	accumulator
	(read-program-defines stream (cons define accumulator)))))

(defun read-program (filename)
  (with-open-file (stream filename :direction :input)
    (read-program-defines stream)))

(defun ldf-name (top-level-name)
  `(ldf ,top-level-name))

(defun mappend (fn list)
  (apply #'append (mapcar fn list)))

(defparameter *symbol-offsets* nil)

(defun calculate-offsets (offset &optional (seq *linker-symbols*))
  (when (consp seq)
    (cons (cons (car (first seq)) offset)
	  (calculate-offsets (+ offset (length (cdr (first seq))))
			     (rest seq)))))

(defun flatten-chunks (entry)
  (setf *symbol-offsets* (calculate-offsets (length entry)))
  (append entry (mappend #'cdr *linker-symbols*)))

(defun flatten-program (top-level)
  (flatten-chunks
   `((dum ,(length top-level))
     ,@(mapcar #'ldf-name top-level)
     (ldf main)
     (rap ,(length top-level))
     (stop))))

(defun resolve-symbol (sym)
  (if (not (symbolp sym))
      sym
      (let ((offset (assoc sym *symbol-offsets*)))
	(if offset
	    (cdr offset)
	    (error "unknown symbol ~A" sym)))))

(defun resolve-symbols (instruction-body)
  (when instruction-body
    (cons (resolve-symbol (first instruction-body))
	  (resolve-symbols (rest instruction-body)))))

(defun resolve-instruction (instruction)
  (cons (first instruction) (resolve-symbols (rest instruction))))

(defun resolve-links (program)
  (mapcar #'resolve-instruction program))

(defun print-program (program)
  (format t "~{~{~A ~}~%~}" program))

(defun compile-program (filename)
  (let* ((*linker-symbols* nil)
	 (*symbol-offsets* nil)
	 (program (read-program filename))
	 (top-level-functions (get-top-level-names program)))
    (compile-list program (list top-level-functions))
    (print-program (resolve-links (flatten-program top-level-functions)))))
