;;; guix-config.el -*- lexical-binding: t; -*-

(when (and (executable-find "guix")
           (file-directory-p (expand-file-name "~/.config/guix/current")))
  (use-package geiser
    :ensure t)

  (use-package geiser-guile
    :ensure t
    :config
    (setq geiser-guile-binary "guix"
          geiser-guile-extra-arguments '("repl")
          geiser-guile-case-sensitive-p t))

  (use-package guix
    :ensure t
    :init
    (let* ((guix-root (expand-file-name "~/.config/guix/current"))
           (share-dir (concat guix-root "/share/guile/site/3.0"))
           (lib-dir   (concat guix-root "/lib/guile/3.0/site-ccache")))
      (setq guix-state-directory "/var/guix"
            guix-user-profiles-directory "~/.guix-profile"
            guix-config-guile-program (concat guix-root "/bin/guix")
            guix-scheme-directory share-dir
            guix-config-guix-scheme-directory share-dir
            guix-config-scheme-compiled-directory lib-dir
            guix-config-guix-scheme-compiled-directory lib-dir))
    :config
    (add-to-list 'exec-path (expand-file-name "~/.config/guix/current/bin"))))

(provide 'guix-config)