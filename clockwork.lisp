(defvar *fruit-pos*)
(defvar *all-pills*)
(defvar *closest-pill*)

(defun player-distance (pos)
  (manhattan (lambda-man-pos) pos))

(defun update-closest-pill (pos new-distance)
  (set *closest-pill* pos)
  new-distance)

(defun ghost-on-pos (pos)
  (not (null (member-if (lambda (x) (is-ghost-pos pos x)) (ghost-state)))))

(defun search-at (val pos)
  (cond ((is-pill val) (set *all-pills* (cons pos *all-pills*)))
	((is-fruit val) (set *fruit-pos* pos))
	(t nil)))

(defun search-row (row x y)
  (if (null row)
      nil
      (progn
	(search-at (car row) (cons x y))
	(search-row (cdr row) (+ x 1) y))))

(defun search-column (map y)
  (if (null map)
      nil
      (progn
	(search-row (car map) 0 y)
	(search-column (cdr map) (+ y 1)))))

(defvar *new-states*)
(defvar *old-states*)

(defun ghost-next-pos (ghost)
  (move (second ghost) (cdr (cdr ghost))))

(defun is-ghost-pos (pos ghost)
  (or (pos-eq pos (second ghost))
      (pos-eq pos (ghost-next-pos ghost))))

(defun bad-ghost-near (pos ghost)
  (and (= 0 (first ghost))
       (is-ghost-pos pos ghost)
       (>= 3 (manhattan (lambda-man-pos) (second ghost)))))

(defun is-ghost-near (pos)
  (not (null (matching-ghost pos bad-ghost-near))))

(defun can-move (pos dir)
  (let ((new-pos (move pos dir)))
    (null (or (= (pos-contents new-pos) +wall+)
	      (is-ghost-near new-pos)))))

(defun distance (pos)
  (manhattan pos *closest-pill*))

(defun initial-state ()
  (list (lambda-man-pos) (distance (lambda-man-pos)) -1 -1))

(defun state-pos (state)
  (first state))

(defun state-distance (state)
  (second state))

(defun state-from (state)
  (third state))

(defun state-origin (state)
  (fourth state))

(defun possible-dirs (pos)
  (remove-if (lambda (dir) (not (can-move pos dir))) *all-dirs*))

(defun state-dir (from dir)
  (if (> 0 from) dir from))

(defun create-state (state dir)
  (let ((pos (move (state-pos state) dir)))
    (list pos (distance pos) (state-dir (state-from state) dir) dir)))

(defun prune-dirs (state dirs)
  (let ((bad-dir (opposite (state-origin state))))
    (if (> (state-origin state) 0)
	(remove-if (lambda (x) (= bad-dir x)) dirs)
	dirs)))

(defun possible-neighbors (state)
  (map (lambda (dir) (create-state state dir))
       (prune-dirs state (possible-dirs (state-pos state)))))

(defun insert-row (item state hash depth)
  (cons item (insert-old state (cdr hash) (- depth 1))))

(defun insert-old (state hash depth)
  (cond ((null hash) nil)
	((= depth 0) (insert-row (cons state (car hash)) state hash depth))
	(t (insert-row (car hash) state hash depth))))

(defun pick-state ()
  (let ((state (first *new-states*)))
    (set *new-states* (cdr *new-states*))
    (set *old-states* (insert-old state *old-states* (cdr (state-pos state))))
    state))

(defun hit (state)
  (pos-eq *closest-pill* (state-pos state)))

(defun insert (state list)
  (cond ((null list) (list state))
	((> (state-distance (car list))
	    (state-distance state))
	 (cons state list))
	(t (cons (car list) (insert state (cdr list))))))

(defun push-state (state)
  (set *new-states* (insert state *new-states*)))

(defun is-not-element (a list)
  (null (member-if (lambda (b) (pos-eq (state-pos a) (state-pos b))) list)))

(defun is-not-in-old-states (state)
  (is-not-element state (nth *old-states* (cdr (state-pos state)))))

(defun is-new-state (state)
  (and (is-not-in-old-states state) (is-not-element state *new-states*)))

(defun dispatch-neighbor (state rest-states)
  (if (is-new-state state) (push-state state) nil)
  (sort-neighbors rest-states))

(defun sort-neighbors (states)
  (cond ((null states) nil)
	((hit (car states)) (car states))
	(t (dispatch-neighbor (car states) (cdr states)))))

(defun inspect-state ()
  (sort-neighbors (possible-neighbors (pick-state))))

(defun get-a-star-direction ()
  (let ((result (inspect-state)))
    (cond ((consp result) (state-from result))
	  ((null *new-states*)
	   (opposite (lambda-man-dir)))
	  (t (get-a-star-direction)))))

(defun lambda-man-on (pos)
  (pos-eq pos (lambda-man-pos)))

(defun clean-pill-list (pos)
  (set *all-pills* (remove-if (lambda (x) (pos-eq pos x)) *all-pills*)))

(defun find-closest-pill (pos pills best score)
  (if (null pills)
      best
      (let ((new-score (manhattan pos (car pills))))
	(if (> new-score score)
	    (find-closest-pill pos (cdr pills) best score)
	    (find-closest-pill pos (cdr pills) (car pills) new-score)))))

(defun closest-pill ()
  (find-closest-pill (lambda-man-pos) *all-pills* nil 512))

(defun search-for-new-pill ()
  (clean-pill-list (lambda-man-pos))
  (cond ((and (fruit-on-board) (not (ghost-on-pos *fruit-pos*)))
	 (set *closest-pill* *fruit-pos*))
	((or (null *closest-pill*)
	     (lambda-man-on *closest-pill*)
	     (ghost-on-pos *closest-pill*))
	 (set *closest-pill* (closest-pill)))
	(t nil)))

(defun a-star ()
  (search-for-new-pill)
  (set *old-states* (make-list (length *map*)))
  (set *new-states* (list (initial-state)))
  (get-a-star-direction))

(defun main ()
  (init-globals)
  (search-column (car arg1) 0)
  (cons 0 (lambda (old-pos world)
	    (init-world world)
	    (cons 0 (a-star)))))
