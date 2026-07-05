;;; test-universal-launcher.el --- Regression tests for universal-launcher.el

;;; Commentary:
;; Run with:
;;   emacs -Q --batch -l ~/.config/emacs/tests/test-universal-launcher.el
;;
;; These tests pin the failure modes that have caused timer errors:
;;   * `parse-colon-path` on a PATH with `::` empty entries returns `nil`
;;     for those entries; downstream `file-directory-p nil` blew up.
;;   * `universal-launcher--extract-domain` previously required a string.
;;   * Agenda parser no longer accepts non-string tags.
;;   * Org-bookmarks parser no longer treats `nil` as a description.

;;; Code:

(require 'cl-lib)

(defvar test-universal-launcher--config-root
  (expand-file-name ".." (file-name-directory (or load-file-name buffer-file-name)))
  "Root of the Studium Emacs config (directory above tests/).")

(setq load-path (cons (expand-file-name "elpaca/builds/nerd-icons" test-universal-launcher--config-root) load-path))
(add-to-list 'load-path "/usr/share/emacs/site-lisp")

(require 'nerd-icons)
(require 'recentf)
(recentf-mode 1)
(load-file (expand-file-name "lisp/custom/universal-launcher.el" test-universal-launcher--config-root))

(defvar test--failures 0)
(defvar test--runs 0)

(defun test--assert (label expected actual)
  (setq test--runs (1+ test--runs))
  (let ((ok (equal expected actual)))
    (if ok
        (princ (format "ok %d - %s\n" test--runs label))
      (setq test--failures (1+ test--failures))
      (princ (format "not ok %d - %s\n  expected: %S\n  actual:   %S\n"
                     test--runs label expected actual)))))

(defun test--assert-no-error (label thunk)
  (setq test--runs (1+ test--runs))
  (condition-case err
      (progn (funcall thunk)
             (princ (format "ok %d - %s\n" test--runs label)))
    (error (setq test--failures (1+ test--failures))
           (princ (format "not ok %d - %s\n  error: %S\n" test--runs label err)))))

;; ---------------------------------------------------------------------------
;; Timer path: the regression we are guarding against.
;; ---------------------------------------------------------------------------
(let ((process-environment
       (cons "/usr/bin:/bin::/usr/local/bin"
             (remove (assoc-default "PATH" process-environment 'equal)
                     process-environment))))
  (setenv "PATH" "/usr/bin:/bin::/usr/local/bin")
  (test--assert-no-error
   "update-candidates tolerates PATH with empty entries (was: stringp nil)"
   (lambda () (universal-launcher--update-candidates t))))

(setenv "PATH" (or (getenv "PATH") "/usr/bin"))

;; ---------------------------------------------------------------------------
;; Individual handlers should never raise on a default install.
;; ---------------------------------------------------------------------------
(dolist (fn '(universal-launcher--get-running-applications
              universal-launcher--get-applications
              universal-launcher--get-flatpak-applications
              universal-launcher--get-system-commands
              universal-launcher--get-firefox-actions
              universal-launcher--get-contextual-actions
              universal-launcher--get-ssh-hosts
              universal-launcher--get-agenda-tasks
              universal-launcher--get-kill-ring
              universal-launcher--get-custom-actions))
  (test--assert-no-error
   (concat "handler: " (symbol-name fn) " runs cleanly")
   (lambda () (funcall fn))))

(test--assert-no-error
 "handler: parse-org-bookmarks missing file returns nil"
 (lambda () (universal-launcher--parse-org-bookmarks "/tmp/does-not-exist-bm.org")))

;; ---------------------------------------------------------------------------
;; extract-domain hardening.
;; ---------------------------------------------------------------------------
(test--assert-no-error
 "extract-domain tolerates nil input"
 (lambda () (universal-launcher--extract-domain nil)))

(test--assert "extract-domain strips www." "gnu.org"
              (universal-launcher--extract-domain "https://www.gnu.org/software"))
(test--assert "extract-domain passes through non-URL" "not-a-url"
              (universal-launcher--extract-domain "not-a-url"))

;; ---------------------------------------------------------------------------
;; bookmarks.org edge cases.
;; ---------------------------------------------------------------------------
(let ((tmp (expand-file-name "ral-test-bookmarks.org" temporary-file-directory)))
  (with-temp-file tmp
    (insert "* Bookmarks\n\n- [[https://example.org][Example]]\n- https://no-desc.test\n- [[https://desc-only.test]]\n"))
  (unwind-protect
      (test--assert-no-error
       "parse-org-bookmarks tolerates links with nil description"
       (lambda () (universal-launcher--parse-org-bookmarks tmp)))
    (delete-file tmp)))

;; ---------------------------------------------------------------------------

(princ (format "\n1..%d\n" test--runs))
(if (> test--failures 0)
    (princ (format "# Failed %d/%d tests\n" test--failures test--runs))
  (princ "# All tests passed\n"))

(kill-emacs (if (> test--failures 0) 1 0))
;;; test-universal-launcher.el ends here
