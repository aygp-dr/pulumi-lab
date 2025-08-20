;;; publish-readme.el --- Publish README.org to README.md using Emacs
;;; Commentary:
;;; This script converts README.org files to README.md automatically
;;; Compatible with uv for Python project management

;;; Code:

(require 'ox-md)
(require 'org)

(defun pulumi-lab-publish-readme (org-file)
  "Publish ORG-FILE to README.md in the same directory."
  (let ((default-directory (file-name-directory org-file))
        (md-file (concat (file-name-sans-extension org-file) ".md")))
    
    ;; Load the org file
    (with-temp-buffer
      (insert-file-contents org-file)
      (org-mode)
      
      ;; Configure org export settings
      (let ((org-export-with-toc t)
            (org-export-with-section-numbers nil)
            (org-export-with-author t)
            (org-export-with-date t)
            (org-export-with-title t)
            (org-md-headline-style 'atx)
            (org-export-preserve-breaks nil))
        
        ;; Export to markdown
        (org-export-to-file 'md md-file)))
    
    (message "Published %s to %s" org-file md-file)))

(defun pulumi-lab-publish-all-readmes ()
  "Find and publish all README.org files in the project."
  (let ((project-root (locate-dominating-file default-directory ".git")))
    (when project-root
      (let ((readme-files (directory-files-recursively 
                          project-root 
                          "README\\.org$")))
        (dolist (readme readme-files)
          (pulumi-lab-publish-readme readme))
        (message "Published %d README files" (length readme-files))))))

(defun pulumi-lab-setup-auto-publish ()
  "Set up automatic README publishing on save."
  (add-hook 'after-save-hook
            (lambda ()
              (when (and (string-match-p "README\\.org$" (buffer-file-name))
                         (string-match-p "pulumi-lab" (buffer-file-name)))
                (pulumi-lab-publish-readme (buffer-file-name))))))

;; If running in batch mode, publish all README files
(when noninteractive
  (let ((project-root (or (getenv "PROJECT_ROOT") 
                         default-directory)))
    (setq default-directory project-root)
    (pulumi-lab-publish-all-readmes)))

(provide 'publish-readme)
;;; publish-readme.el ends here