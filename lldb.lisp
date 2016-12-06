(in-package :sys.int)

(defparameter *step-special-functions*
  '(cons cons-in-area mezzano.runtime::%allocate-object mezzano.supervisor:thread-yield))

(defun fetch-thread-function-arguments (thread)
  (let ((count (mezzano.supervisor:thread-state-rcx-value thread))
        (reg-vals (list (mezzano.supervisor:thread-state-r8-value thread)
                        (mezzano.supervisor:thread-state-r9-value thread)
                        (mezzano.supervisor:thread-state-r10-value thread)
                        (mezzano.supervisor:thread-state-r11-value thread)
                        (mezzano.supervisor:thread-state-r12-value thread)))
        (sp (mezzano.supervisor:thread-state-rsp thread))
        (stack-vals '()))
    (dotimes (i (max 0 (- count 5)))
      (push (memref-t sp (1+ i)) stack-vals))
    (subseq (append reg-vals (reverse stack-vals))
            0 count)))

(defun fetch-thread-return-values (thread)
  (let ((count (mezzano.supervisor:thread-state-rcx-value thread))
        (vals (list (mezzano.supervisor:thread-state-r12-value thread)
                    (mezzano.supervisor:thread-state-r11-value thread)
                    (mezzano.supervisor:thread-state-r10-value thread)
                    (mezzano.supervisor:thread-state-r9-value thread)
                    (mezzano.supervisor:thread-state-r8-value thread))))
    (dotimes (i (max 0 (- count 5)))
      (push (%object-ref-t thread (+ mezzano.supervisor::+thread-mv-slots-start+ i)) vals))
    (subseq (reverse vals) 0 count)))

(defun safe-single-step-thread (thread)
  (check-type thread mezzano.supervisor:thread)
  (assert (eql (mezzano.supervisor:thread-state thread) :stopped))
  ;; If the thread is not in the full-save state, then convert it.
  (mezzano.supervisor::convert-thread-to-full-save thread)
  (let* ((rip (mezzano.supervisor:thread-state-rip thread))
         (fn (return-address-to-function rip)))
    (cond ((eql fn #'mezzano.supervisor::%call-on-wired-stack-without-interrupts)
           (error "Cannot step into %CALL-ON-WIRED-STACK-WITHOUT-INTERRUPTS."))
          ((eql fn #'mezzano.supervisor::thread-final-cleanup)
           ;; Thread is in the process of dying.
           ;; Let it run to completion instead of stepping.
           (mezzano.supervisor::resume-thread thread))
          ((member fn *step-special-functions* :key #'fdefinition)
           (when (not (eql rip (%object-ref-unsigned-byte-64 fn +function-entry-point+)))
             (cerror "Step anyway"
                     "Cannot single-step function in the middle of special function ~S."
                     fn)
             (mezzano.supervisor::single-step-thread thread)
             (return-from safe-single-step-thread))
           (format t "Stepping over special function ~S.~%" fn)
           ;; Execute the function in this thread's context.
           (let* ((arguments (fetch-thread-function-arguments thread))
                  (results (multiple-value-list (apply fn arguments)))
                  (n-results (length results)))
             ;; Messing with the MV area requires us to be PA, as value counts
             ;; may not match up with number of actual live values.
             (mezzano.supervisor:with-pseudo-atomic
               ;; Set value count.
               (setf (mezzano.supervisor:thread-state-rcx-value thread) n-results)
               ;; Set return registers. This does the right thing (setting r8 to nil) when returning 0 values.
               (setf (mezzano.supervisor:thread-state-r8-value thread) (first results)
                     (mezzano.supervisor:thread-state-r9-value thread) (second results)
                     (mezzano.supervisor:thread-state-r10-value thread) (third results)
                     (mezzano.supervisor:thread-state-r11-value thread) (fourth results)
                     (mezzano.supervisor:thread-state-r12-value thread) (fifth results))
               ;; Set MV area values.
               (dotimes (i (- n-results 5))
                 (setf (%object-ref-t thread (+ mezzano.supervisor::+thread-mv-slots-start+ i))
                       (nth (+ i 5) results)))
               ;; Pop return address.
               (setf (mezzano.supervisor:thread-state-rip thread) (memref-unsigned-byte-64 (mezzano.supervisor:thread-state-rsp thread) 0))
               (incf (mezzano.supervisor:thread-state-rsp thread) 8))))
          (t
           (mezzano.supervisor::single-step-thread thread)))))

(defun step-until-next-call-or-return (thread &optional (limit 1000))
  (let ((prev-fn (return-address-to-function
                  (mezzano.supervisor:thread-state-rip thread)))
        (iters 0))
    (loop
       (dump-thread-state thread)
       (safe-single-step-thread thread)
       (let* ((rip (mezzano.supervisor:thread-state-rip thread))
              (fn (return-address-to-function rip)))
         (when (eql rip (%object-ref-unsigned-byte-64 fn +function-entry-point+))
           (format t "Entered function ~S with arguments ~:S.~%" fn (fetch-thread-function-arguments thread))
           (return))
         (when (not (eql fn prev-fn))
           (format t "Returning from function ~S to ~S with results ~:S.~%"
                   prev-fn fn (fetch-thread-return-values thread))
           (return))
         (format t "Current fn ~S  prev fn ~S.~%" fn prev-fn)
         (setf prev-fn fn))
       (when (> (incf iters) limit)
         (format t "Reached step limit of ~D instructions.~%" limit)
         (return)))))

(defun dump-thread-state (thread)
  (cond ((mezzano.supervisor:thread-full-save-p thread)
         (format t "Full-save state:~%")
         (format t " r15: ~8,'0X~%" (mezzano.supervisor:thread-state-r15 thread))
         (format t " r14: ~8,'0X~%" (mezzano.supervisor:thread-state-r14 thread))
         (format t " r13: ~8,'0X~%" (mezzano.supervisor:thread-state-r13 thread))
         (format t " r12: ~8,'0X~%" (mezzano.supervisor:thread-state-r12 thread))
         (format t " r11: ~8,'0X~%" (mezzano.supervisor:thread-state-r11 thread))
         (format t " r10: ~8,'0X~%" (mezzano.supervisor:thread-state-r10 thread))
         (format t "  r9: ~8,'0X~%" (mezzano.supervisor:thread-state-r9 thread))
         (format t "  r8: ~8,'0X~%" (mezzano.supervisor:thread-state-r8 thread))
         (format t " rdi: ~8,'0X~%" (mezzano.supervisor:thread-state-rdi thread))
         (format t " rsi: ~8,'0X~%" (mezzano.supervisor:thread-state-rsi thread))
         (format t " rbx: ~8,'0X~%" (mezzano.supervisor:thread-state-rbx thread))
         (format t " rdx: ~8,'0X~%" (mezzano.supervisor:thread-state-rdx thread))
         (format t " rcx: ~8,'0X~%" (mezzano.supervisor:thread-state-rcx thread))
         (format t " rax: ~8,'0X~%" (mezzano.supervisor:thread-state-rax thread))
         (format t " rbp: ~8,'0X~%" (mezzano.supervisor:thread-state-rbp thread))
         (format t " rip: ~8,'0X~%" (mezzano.supervisor:thread-state-rip thread))
         (format t "  cs: ~8,'0X~%" (mezzano.supervisor:thread-state-cs thread))
         (format t " rflags: ~8,'0X~%" (mezzano.supervisor:thread-state-rflags thread))
         (format t " rsp: ~8,'0X~%" (mezzano.supervisor:thread-state-rsp thread))
         (format t "  ss: ~8,'0X~%" (mezzano.supervisor:thread-state-ss thread)))
        (t
         (format t "Partial-save state:~%")
         (format t " rsp: ~8,'0X~%" (mezzano.supervisor:thread-state-rsp thread))
         (format t " rbp: ~8,'0X~%" (mezzano.supervisor:thread-state-rbp thread))
         (format t " rip: ~8,'0X~%" (sys.int::memref-unsigned-byte-64 (mezzano.supervisor:thread-state-rsp thread) 0))))
  (values))

(defun trace-execution (function)
  (let* ((stopped nil)
         (thread (mezzano.supervisor:make-thread
                  (lambda ()
                    (loop
                       (when stopped
                         (return))
                       (mezzano.supervisor:thread-yield))
                    (funcall function))))
         (instructions-stepped 0)
         (prev-fn nil))
    (mezzano.supervisor::stop-thread thread)
    (setf stopped t)
    (loop
       (when (and (zerop (mod (incf instructions-stepped) 1000))
                  (y-or-n-p "Thread has run for ~D instructions. Stop?" instructions-stepped))
         (mezzano.supervisor:terminate-thread thread)
         (mezzano.supervisor::resume-thread thread)
         (return))
       (when (eql (mezzano.supervisor:thread-state thread) :dead)
         (format t "Thread has died.~%")
         (return))
       (dump-thread-state thread)
       (safe-single-step-thread thread)
       (let* ((rip (mezzano.supervisor:thread-state-rip thread))
              (fn (return-address-to-function rip)))
         (when (and prev-fn
                    (not (eql fn prev-fn)))
           (cond ((eql rip (%object-ref-unsigned-byte-64 fn +function-entry-point+))
                  (format t "Entered function ~S with arguments ~:S.~%" fn (fetch-thread-function-arguments thread)))
                 (t
                  (format t "Returning from function ~S to ~S with results ~:S.~%"
                          prev-fn fn (fetch-thread-return-values thread)))))
         (setf prev-fn fn)))))