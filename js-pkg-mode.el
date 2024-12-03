;;; js-pkg-mode --- minor mode for working with npm projects

;; Version: 1.0.0
;; Author: Ovi Stoica <ovidiu.stoica1094@gmail.com>
;; Url: https://github.com/ovistoica/js-pkg-mode
;; Keywords: convenience, project, javascript, package-manager
;; Package-Requires: ((emacs "24.1"))

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;; This package allows you to easily work with javascript projects.It provides
;; a minor mode for convenient interactive use of API with a mode-specific
;; command keymap.
;;
;; | command                       | keymap       | description                         |
;; |-------------------------------|--------------|-------------------------------------|
;; | js-pkg-init                   | <kbd>n</kbd> | Initialize new project              |
;; | js-pkg-install                | <kbd>i</kbd> | Install all project dependencies    |
;; | js-pkg-install-save           | <kbd>s</kbd> | Add new project dependency          |
;; | js-pkg-install-save-dev       | <kbd>d</kbd> | Add new project dev dependency      |
;; | js-pkg-uninstall              | <kbd>u</kbd> | Remove project dependency           |
;; | js-pkg-list                   | <kbd>l</kbd> | List installed project dependencies |
;; | js-pkg-run                    | <kbd>r</kbd> | Run project script                  |
;; | js-pkg-visit-project-file     | <kbd>v</kbd> | Visit project package.json file     |
;; |                               | <kbd>?</kbd> | Display keymap commands             |

;;; Credit:

;; This package began as a fork of the npm-mode package, and its repository
;; history has been preserved.  Many thanks to Allen Gooch for his contribution.
;; https://github.com/mojochao/npm-mode repo.


;;; Code:

(require 'json)
(require 'project)

(defgroup js-pkg nil
  "Customization group for js-pkg."
  :group 'tools)

(defvar js-pkg--project-file-name "package.json"
  "The name of npm project files.")

(defcustom js-pkg-package-manager-type 'npm
  "Package manager to use (npm, yarn, pnpm, or bun).
It is automatically infered based on the lockfile but you can overwrite."
  :type '(choice (const npm)
                 (const yarn)
                 (const pnpm)
                 (const bun))
  :group 'js-pkg)


(defvar js-pkg--modeline-name " npm"
  "Name of npm mode modeline name.")

(defun js-pkg--ensure-npm-module ()
  "Asserts that you're currently inside an npm module."
  (js-pkg--project-file))

(defun js-pkg--project-file ()
  "Return path to the project file, or nil.
If project file exists in the current working directory, or a
parent directory recursively, return its path.  Otherwise, return
nil."
  (let ((dir (locate-dominating-file default-directory js-pkg--project-file-name)))
    (unless dir
      (error (concat "Error: cannot find " js-pkg--project-file-name)))
    (concat dir js-pkg--project-file-name)))


(defun js-pkg--lock-file ()
  "Return path to the package lock file, or nil."
  (let* ((dir (locate-dominating-file default-directory js-pkg--project-file-name))
         (lock-files '("package-lock.json" "deno.lock" "yarn.lock" "pnpm-lock.yaml" "bun.lock")))
    (when dir
      (cl-find-if (lambda (file)
                    (file-exists-p (concat dir file)))
                  lock-files))))

(defun js-pkg-lockfile->package-manager (lock-file)
  "Given LOCK-FILE type, output package-manager used in the project."
  (cond
   ((string= lock-file "package-lock.json") 'npm)
   ((string= lock-file "yarn.lock") 'yarn)
   ((string= lock-file "pnpm-lock.yaml") 'pnpm)
   ((string= lock-file "bun.lock") 'bun)
   ((string= lock-file "deno.lock") 'deno)))


(defun js-pkg-package-manager ()
  "Get the package manager for the current buffer."
  (js-pkg-lockfile->package-manager (js-pkg--lock-file)))


(defun js-pkg--get-project-property (prop)
  "Get the given PROP from the current project file."
  (let* ((project-file (js-pkg--project-file))
         (json-object-type 'hash-table)
         (json-contents (with-temp-buffer
                          (insert-file-contents project-file)
                          (buffer-string)))
         (json-hash (json-read-from-string json-contents))
         (value (gethash prop json-hash))
         (commands (list)))
    (cond ((hash-table-p value)
           (maphash (lambda (key value)
                      (setq commands
                            (append commands
                                    (list (list key (format "%s %s" "npm" key))))
                            ))
                    value)
           commands)
          (t value))))

(defun js-pkg--get-project-scripts ()
  "Get a list of project scripts."
  (js-pkg--get-project-property "scripts"))

(defun js-pkg--get-project-dependencies ()
  "Get a list of project dependencies."
  (js-pkg--get-project-property "dependencies"))

(defun js-pkg--exec-process (cmd &optional comint)
  "Execute a process running CMD.
Optional argument COMINT when non-nil runs the command in comint mode."
  (let* ((pm-type (symbol-name js-pkg-package-manager-type))
         (compilation-buffer-name-function
          (lambda (mode)
            (format "*%s:%s - %s*"
                    pm-type
                    (js-pkg--get-project-property "name")
                    cmd))))
    (message (concat "Running " cmd))
    (compile cmd comint)))

(defun js-pkg-npm-clean ()
  "Run the `npm list' command."
  (interactive)
  (let ((dir (concat (file-name-directory (js-pkg--ensure-npm-module)) "node_modules")))
    (if (file-directory-p dir)
        (when (yes-or-no-p (format "Are you sure you wish to delete %s?" dir))
          (js-pkg--exec-process (format "rm -rf %s" dir)))
      (message (format "%s has already been cleaned" dir)))))

(defun js-pkg-init ()
  "Initialize a new javascript project.  Prompt for package manager choice."
  (interactive)
  (let* ((pm-choices '(("npm" . npm)
                       ("yarn" . yarn)
                       ("pnpm" . pnpm)
                       ("bun" . bun)
                       ("deno" . deno)))
         (choice (completing-read "Choose package manager: " pm-choices nil t))
         (pm-symbol (cdr (assoc choice pm-choices))))
    (setq js-pkg-package-manager-type pm-symbol)
    (js-pkg--exec-process (format "%s init" (symbol-name pm-symbol)))))

(defun js-pkg-install ()
  "Run the install command."
  (interactive)
  (let ((pm-name (symbol-name js-pkg-package-manager-type)))
    (js-pkg--exec-process (format "%s install" pm-name))))

(defun js-pkg-install-save (dep)
  "Install and save DEP as a dependency."
  (interactive "sEnter package name: ")
  (let* ((pm-name (symbol-name js-pkg-package-manager-type))
         (cmd (pcase pm-name
                ("npm" (format "npm install %s --save" dep))
                ("yarn" (format "yarn add %s" dep))
                ("pnpm" (format "pnpm add %s" dep))
                ("bun" (format "bun add %s" dep)))))
    (js-pkg--exec-process cmd)))

(defun js-pkg-install-save-dev (dep)
  "Install and save DEP as a dev dependency."
  (interactive "sEnter package name: ")
  (let* ((pm-name (symbol-name js-pkg-package-manager-type))
         (cmd (pcase pm-name
                ("npm" (format "npm install %s --save-dev" dep))
                ("yarn" (format "yarn add %s --dev" dep))
                ("pnpm" (format "pnpm add -D %s" dep))
                ("bun" (format "bun add -d %s" dep)))))
    (js-pkg--exec-process cmd)))

(defun js-pkg-uninstall ()
  "Uninstall a dependency."
  (interactive)
  (let* ((pm-name (symbol-name js-pkg-package-manager-type))
         (dep (completing-read "Uninstall dependency: " (js-pkg--get-project-dependencies)))
         (cmd (pcase pm-name
                ("npm" (format "npm uninstall %s" dep))
                ("yarn" (format "yarn remove %s" dep))
                ("pnpm" (format "pnpm remove %s" dep))
                ("bun" (format "bun remove %s" dep)))))
    (js-pkg--exec-process cmd)))

(defun js-pkg-list ()
  "List installed dependencies."
  (interactive)
  (let* ((pm-name (symbol-name js-pkg-package-manager-type))
         (cmd (pcase pm-name
                ("npm" "npm list --depth=0")
                ("yarn" "yarn list --depth=0")
                ("pnpm" "pnpm list --depth=0")
                ("bun" "bun pm ls"))))
    (js-pkg--exec-process cmd)))


(defun npm-run--read-command ()
  "Prompt user to select a script from package.json scripts.
Returns the selected script name as a string."
  (completing-read "Run script: " (js-pkg--get-project-scripts)))


(defun js-pkg-run (script &optional comint)
  "Run the package manager's run command on a project script.
SCRIPT is the npm script to run.
Optional argument COMINT when non-nil runs the command in comint mode."
  (interactive
   (list (npm-run--read-command)
         (consp current-prefix-arg)))
  (let ((pm-name (symbol-name js-pkg-package-manager-type)))
    (js-pkg--exec-process
     (format "%s run %s" pm-name script)
     comint)))

(defun js-pkg-visit-project-file ()
  "Visit the project file."
  (interactive)
  (find-file (js-pkg--project-file)))

(defgroup js-pkg nil
  "Customization group for js-pkg."
  :group 'convenience)

(defcustom js-pkg-command-prefix "C-c n"
  "Prefix for js-pkg."
  :type 'key-sequence
  :group 'js-pkg)

(defvar js-pkg-command-keymap
  (let ((map (make-sparse-keymap)))
    (define-key map "n" 'js-pkg-init)
    (define-key map "i" 'js-pkg-install)
    (define-key map "s" 'js-pkg-install-save)
    (define-key map "d" 'js-pkg-install-save-dev)
    (define-key map "u" 'js-pkg-uninstall)
    (define-key map "l" 'js-pkg-list)
    (define-key map "r" 'js-pkg-run)
    (define-key map "v" 'js-pkg-visit-project-file)
    map)
  "Keymap for js-pkg commands.")

(defvar js-pkg-keymap
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd js-pkg-command-prefix) js-pkg-command-keymap)
    map)
  "Keymap for `js-pkg'.")

;;;###autoload
(define-minor-mode js-pkg-mode
  "Minor mode for working with javascript projects."
  :lighter js-pkg--modeline-name
  :keymap js-pkg-keymap
  :group 'js-pkg
  (when js-pkg-mode
    (setq js-pkg-package-manager-type
          (js-pkg-package-manager))))

;;;###autoload
(define-globalized-minor-mode node-package-global-mode
  js-pkg-mode
  js-pkg-mode)

(provide 'js-pkg)
;;; js-pkg-mode.el ends here
