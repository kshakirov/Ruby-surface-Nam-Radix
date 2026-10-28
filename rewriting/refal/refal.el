;;; refal.el --- Simple Refal-5lambda mode -*- lexical-binding: t; -*-

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Lightweight editing support for Refal-5lambda: highlighting, indentation,
;; and compile/run commands.  No external Emacs packages are required.

;;; Code:

(require 'compile)

(defgroup refal nil
  "Editing Refal-5lambda programs."
  :group 'languages)

(defcustom refal-indent-offset 2
  "Number of spaces used for one nesting level."
  :type 'integer
  :group 'refal)

(defcustom refal-compiler-command nil
  "Path to the Refal compiler, or nil to find `rlc' automatically."
  :type '(choice (const :tag "Find rlc automatically" nil) file)
  :group 'refal)

(defvar refal-mode-syntax-table
  (let ((table (make-syntax-table)))
    (modify-syntax-entry ?/ ". 124b" table)
    (modify-syntax-entry ?* ". 23" table)
    (modify-syntax-entry ?\n "> b" table)
    (modify-syntax-entry ?' "\"" table)
    (modify-syntax-entry ?{ "(}" table)
    (modify-syntax-entry ?} "){" table)
    (modify-syntax-entry ?< "(>" table)
    (modify-syntax-entry ?> ")<" table)
    table)
  "Syntax table for `refal-mode'.")

(defconst refal-font-lock-keywords
  `((,(regexp-opt '("ENTRY" "EXTERN" "FORWARD" "INCLUDE" "DRIVE"
                    "INLINE" "SPEC") 'symbols)
     . font-lock-keyword-face)
    ("\\$[[:upper:]][[:upper:][:digit:]-]*" . font-lock-keyword-face)
    ("\\_<[ste]\\.[[:alnum:]_-]+\\_>" . font-lock-variable-name-face)
    ("^[[:space:]]*\\([[:alpha:]_][[:alnum:]_-]*\\)[[:space:]]*{"
     1 font-lock-function-name-face))
  "Font-lock rules for Refal-5lambda.")

(defun refal-indent-line ()
  "Indent the current line relative to its enclosing bracket."
  (interactive)
  (let ((column (current-column))
        (old-indent (current-indentation))
        indent)
    (save-excursion
      (back-to-indentation)
      (let* ((state (syntax-ppss))
             (opener (nth 1 state)))
        (setq indent
              (cond
               ((or (nth 3 state) (nth 4 state)) old-indent)
               ((not opener) 0)
               ((looking-at-p "[]})>]")
                (save-excursion (goto-char opener) (current-indentation)))
               (t
                (save-excursion (goto-char opener)
                                (+ (current-indentation) refal-indent-offset)))))))
    (indent-line-to indent)
    (when (> column old-indent)
      (move-to-column (+ indent (- column old-indent))))))

(defun refal--compiler ()
  "Return the Refal compiler path or signal a helpful error."
  (or refal-compiler-command
      (executable-find "rlc")
      (let ((local (expand-file-name "~/.local/share/refal-5-lambda/bin/rlc")))
        (when (file-executable-p local) local))
      (user-error "Cannot find rlc; customize `refal-compiler-command'")))

(defun refal--source-file ()
  "Save and return the current Refal source file."
  (unless buffer-file-name
    (user-error "Save this buffer to a .ref file first"))
  (save-buffer)
  buffer-file-name)

(defun refal-compile ()
  "Compile the current Refal file using `rlc'."
  (interactive)
  (let* ((file (refal--source-file))
         (default-directory (file-name-directory file))
         (command (format "%s %s"
                          (shell-quote-argument (refal--compiler))
                          (shell-quote-argument (file-name-nondirectory file)))))
    (compilation-start command 'compilation-mode)))

(defun refal-compile-and-run ()
  "Compile the current Refal file, then run the resulting executable."
  (interactive)
  (let* ((file (refal--source-file))
         (default-directory (file-name-directory file))
         (source (file-name-nondirectory file))
         (program (concat "./" (file-name-sans-extension source)))
         (command (format "%s %s && %s"
                          (shell-quote-argument (refal--compiler))
                          (shell-quote-argument source)
                          (shell-quote-argument program))))
    (compilation-start command 'compilation-mode)))

(defvar refal-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-c") #'refal-compile)
    (define-key map (kbd "C-c C-r") #'refal-compile-and-run)
    map)
  "Keymap for `refal-mode'.")

;;;###autoload
(define-derived-mode refal-mode prog-mode "Refal"
  "Major mode for Refal-5lambda source files."
  :syntax-table refal-mode-syntax-table
  (setq-local font-lock-defaults '(refal-font-lock-keywords))
  (setq-local indent-line-function #'refal-indent-line)
  (setq-local comment-start "/* ")
  (setq-local comment-end " */"))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.ref\\'" . refal-mode))

(provide 'refal)

;;; refal.el ends here
