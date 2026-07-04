;;; mail.el --- mu4e mail (Studium Emacs) -*- lexical-binding: t; -*-

(defvar my/mail-user-config
  (expand-file-name "lisp/custom/mail-user.el" user-emacs-directory)
  "Optional per-user mu4e contexts, bookmarks, and SMTP overrides.")

(defun my/mu4e-ready-p ()
  "Return non-nil when local mail store and mu index are available."
  (let ((maildir (expand-file-name "~/Mail"))
        (mu-bin (or mu4e-mu-binary (executable-find "mu"))))
    (and mu-bin
         (file-directory-p maildir)
         (zerop (call-process mu-bin nil nil nil "info")))))

(defun my/mu4e-setup-instructions ()
  "Return mu4e setup steps for the current machine."
  (cond
   ((not (executable-find "msmtp"))
    "1. Install msmtp (pacman -S msmtp)\n2. Configure ~/.msmtprc")
   ((not (file-directory-p (expand-file-name "~/Mail")))
    "1. Create ~/Mail and ~/.mbsyncrc\n2. Run: mbsync -a && mu init && mu index\n3. Copy lisp/custom/mail-user.el.example to mail-user.el")
   ((not (my/mu4e-ready-p))
    "Maildir exists but mu index is missing.\nRun: mu init && mu index")
   (t nil)))

(defun my/mu4e-launch ()
  "Launch mu4e or show setup instructions when mail is not configured."
  (interactive)
  (if-let ((steps (my/mu4e-setup-instructions)))
      (with-current-buffer (get-buffer-create "*mu4e-setup*")
        (erase-buffer)
        (insert "mu4e is not configured yet.\n\n")
        (insert steps)
        (insert "\n\nSee lisp/custom/mail-user.el.example for account templates.\n")
        (pop-to-buffer (current-buffer)))
    (call-interactively #'mu4e)))

(use-package mu4e
  :ensure nil
  :defer t
  :commands (mu4e mu4e-compose-new my/mu4e-launch)
  :init
  (setq mu4e-mu-binary (executable-find "mu"))
  :config

  (setq mu4e-maildir "~/Mail"
        mu4e-get-mail-command "mbsync -a"
        mu4e-update-interval 300
        mu4e-change-filenames-when-moving t
        mu4e-attachment-dir "~/Downloads"
        mu4e-compose-format-flowed t
        mu4e-view-show-images t
        mu4e-view-show-addresses t)

  (setq message-send-mail-function 'message-send-mail-with-sendmail
        send-mail-function 'message-send-mail-with-sendmail
        sendmail-program (executable-find "msmtp")
        message-sendmail-extra-arguments '("--read-envelope-from")
        message-sendmail-f-is-evil t
        mail-specify-envelope-from t
        mail-envelope-from 'header)

  (setq mu4e-sent-messages-behavior 'sent)

  (setq mu4e-bookmarks
        '(("flag:unread AND NOT flag:trashed" "Unread messages"   ?u)
          ("date:today..now"                  "Today's messages"  ?t)
          ("flag:flagged"                     "Flagged messages"  ?f)
          ("size:5M.."                        "Big messages"      ?b)))

  (when (file-exists-p my/mail-user-config)
    (load my/mail-user-config nil t))

  (setq mu4e-headers-thread-enable t
        mu4e-headers-show-threads t
        mu4e-headers-include-related t)

  (defun mu4e-compose-mailto (url)
    "Compose from mailto: URL."
    (require 'url-parse)
    (let* ((parsed  (url-generic-parse-url url))
           (to      (url-filename parsed))
           (query   (url-target parsed))
           (headers (when query (url-parse-query-string query))))
      (mu4e-compose-new)
      (message-goto-to)
      (insert to)
      (when-let ((subject (cadr (assoc "subject" headers))))
        (message-goto-subject)
        (insert (url-unhex-string subject)))
      (when-let ((body (cadr (assoc "body" headers))))
        (message-goto-body)
        (insert (url-unhex-string body)))))

  (setq mu4e-compose-complete-addresses nil)

  (setq mu4e-split-view 'horizontal
        mu4e-headers-visible-lines 20)

  ;; Kill message buffer after sending
  (setq message-kill-buffer-on-exit t)

  (defun mu4e-debug-msmtp ()
    "Debug current mail sending settings."
    (interactive)
    (message "sendmail-program: %s" sendmail-program)
    (message "user-mail-address: %s" user-mail-address)
    (message "message-sendmail-extra-arguments: %s"
             message-sendmail-extra-arguments)))

;; (define-key my-leader-map (kbd "o m") #'mu4e)
;; (define-key my-leader-map (kbd "y m") #'mu4e-org-mode)

(provide 'mail)
