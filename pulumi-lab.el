;;; pulumi-lab.el --- Pulumi Infrastructure as Code with Hy support -*- lexical-binding: t; -*-

;; Copyright (C) 2025 aygp-dr

;; Author: aygp-dr
;; Version: 0.1.0
;; Package-Requires: ((emacs "30.1") (org "9.6") (python "0.28") (lsp-mode "8.0") (company "0.10") (flycheck "32") (projectile "2.5") (hy-mode "1.0"))
;; Keywords: pulumi, hy, python, infrastructure, babel, lsp
;; URL: https://github.com/aygp-dr/pulumi-lab

;;; Commentary:
;; 
;; Comprehensive Emacs configuration for Pulumi Infrastructure as Code
;; development with Hy (Lisp for Python). Provides:
;;
;; - Org-babel integration for Python and Hy
;; - LSP support with pylsp and hy-mode
;; - Pulumi-specific snippets and commands
;; - Project management and workflow automation
;; - LocalStack integration
;; - Policy as Code editing support
;;
;; Installation:
;; 
;; For Emacs 30+, add MELPA to your package archives if not already present:
;;   (require 'package)
;;   (add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
;;   (package-initialize)
;;
;; Then install:
;;   M-x package-refresh-contents
;;   M-x package-install RET pulumi-lab RET
;;
;; Or use use-package:
;;   (use-package pulumi-lab
;;     :ensure t
;;     :hook ((python-mode org-mode hy-mode) . pulumi-lab-enable-for-project))

;;; Code:

(require 'package)
(require 'org)
(require 'ob)
(require 'ob-python nil t)

;; Ensure MELPA is available
(unless (assoc "melpa" package-archives)
  (add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t))

;; Auto-install missing packages
(defun pulumi-lab-ensure-packages ()
  "Ensure required packages are installed."
  (interactive)
  (package-refresh-contents)
  (dolist (pkg '(python lsp-mode company flycheck projectile hy-mode))
    (unless (package-installed-p pkg)
      (condition-case err
          (package-install pkg)
        (error (message "Failed to install %s: %s" pkg err))))))

;; Load packages with graceful fallback
(require 'python nil t)
(require 'lsp-mode nil t)
(require 'company nil t)
(require 'flycheck nil t)
(require 'projectile nil t)
(require 'hy-mode nil t)

;;; Configuration Variables

(defgroup pulumi-lab nil
  "Pulumi Infrastructure as Code with Hy support."
  :group 'development
  :prefix "pulumi-lab-")

(defcustom pulumi-lab-python-command "python3"
  "Python command to use for Pulumi operations."
  :type 'string
  :group 'pulumi-lab)

(defcustom pulumi-lab-hy-command "hy"
  "Hy command to use for Hy code execution."
  :type 'string
  :group 'pulumi-lab)

(defcustom pulumi-lab-venv-name ".venv"
  "Name of the virtual environment directory."
  :type 'string
  :group 'pulumi-lab)

(defcustom pulumi-lab-localstack-endpoint "http://localhost:4566"
  "LocalStack endpoint for local AWS services."
  :type 'string
  :group 'pulumi-lab)

(defcustom pulumi-lab-experiments-dir "experiments"
  "Directory containing Pulumi experiments."
  :type 'string
  :group 'pulumi-lab)

;;; Core Functions

(defun pulumi-lab-project-root ()
  "Find the root directory of the Pulumi lab project."
  (or (locate-dominating-file default-directory "pulumi-lab.el")
      (locate-dominating-file default-directory "Pulumi.yaml")
      (locate-dominating-file default-directory "pyproject.toml")
      default-directory))

(defun pulumi-lab-venv-path ()
  "Get the path to the project's virtual environment."
  (expand-file-name pulumi-lab-venv-name (pulumi-lab-project-root)))

(defun pulumi-lab-activate-venv ()
  "Activate the project's virtual environment."
  (interactive)
  (let ((venv-path (pulumi-lab-venv-path)))
    (when (file-directory-p venv-path)
      (setenv "VIRTUAL_ENV" venv-path)
      (setenv "PATH" (concat (expand-file-name "bin" venv-path) 
                            path-separator (getenv "PATH")))
      (setq python-shell-interpreter 
            (expand-file-name "bin/python" venv-path))
      (message "Activated virtual environment: %s" venv-path))))

(defun pulumi-lab-setup-environment ()
  "Setup Pulumi lab development environment."
  (interactive)
  (let ((project-root (pulumi-lab-project-root)))
    (setenv "PULUMI_BACKEND_URL" "file://~/.pulumi")
    (setenv "AWS_ENDPOINT_URL" pulumi-lab-localstack-endpoint)
    (setenv "AWS_ACCESS_KEY_ID" "test")
    (setenv "AWS_SECRET_ACCESS_KEY" "test")
    (setenv "AWS_DEFAULT_REGION" "us-east-1")
    (pulumi-lab-activate-venv)
    (message "Pulumi lab environment configured")))

;;; Org-babel Configuration

(defun pulumi-lab-configure-babel ()
  "Configure org-babel for Pulumi lab."
  (org-babel-do-load-languages
   'org-babel-load-languages
   '((python . t)
     (shell . t)
     (emacs-lisp . t)))
  
  ;; Only load hy if available
  (when (featurep 'hy-mode)
    (add-to-list 'org-babel-load-languages '(hy . t)))
  
  ;; Don't ask for confirmation when executing code blocks
  (setq org-confirm-babel-evaluate nil)
  
  ;; Trust local variables without prompting
  (setq enable-local-variables :all)
  (setq enable-local-eval t)
  
  ;; Mark common org-babel variables as safe
  (put 'org-babel-python-command 'safe-local-variable #'stringp)
  (put 'org-confirm-babel-evaluate 'safe-local-variable #'booleanp)
  (put 'org-src-fontify-natively 'safe-local-variable #'booleanp)
  (put 'org-src-tab-acts-natively 'safe-local-variable #'booleanp)
  (put 'org-edit-src-content-indentation 'safe-local-variable #'integerp)
  
  ;; Set default headers
  (setq org-babel-default-header-args:python
        '((:session . "pulumi-lab")
          (:results . "output")
          (:exports . "both")
          (:cache . "no")))
  
  (setq org-babel-default-header-args:hy
        '((:session . "pulumi-lab-hy")
          (:results . "output")
          (:exports . "both")
          (:cache . "no")))
  
  ;; Custom source block templates
  (add-to-list 'org-structure-template-alist '("spy" . "src python"))
  (add-to-list 'org-structure-template-alist '("shy" . "src hy"))
  (add-to-list 'org-structure-template-alist '("sbash" . "src bash"))
  (add-to-list 'org-structure-template-alist '("spulumi" . "src python :session pulumi :results output")))

;; Custom execution function for Hy code blocks
(defun org-babel-execute:hy (body params)
  "Execute Hy code in BODY with PARAMS."
  (let* ((session (cdr (assq :session params)))
         (result-type (cdr (assq :result-type params)))
         (full-body (org-babel-expand-body:generic body params))
         (tmp-file (org-babel-temp-file "hy-")))
    (with-temp-file tmp-file
      (insert full-body))
    (org-babel-eval (format "%s %s" pulumi-lab-hy-command tmp-file) "")))

;;; LSP Configuration

(defun pulumi-lab-configure-lsp ()
  "Configure LSP for Python and Hy development."
  (when (featurep 'lsp-mode)
    ;; Python LSP configuration
    (setq lsp-pylsp-plugins-pycodestyle-enabled nil)
    (setq lsp-pylsp-plugins-mccabe-enabled nil)
    (setq lsp-pylsp-plugins-pyflakes-enabled t)
    (setq lsp-pylsp-plugins-pylint-enabled t)
    (setq lsp-pylsp-plugins-autopep8-enabled t)
    (setq lsp-pylsp-plugins-yapf-enabled nil)
    (setq lsp-pylsp-plugins-black-enabled t)
    
    ;; Add Pulumi imports to Python path
    (add-to-list 'lsp-pylsp-plugins-jedi-environment-extra-paths
                 (expand-file-name "lib/python3.11/site-packages" 
                                  (pulumi-lab-venv-path)))
    
    ;; Configure LSP for project files
    (add-hook 'python-mode-hook
              (lambda ()
                (when (string-match-p "pulumi-lab" (buffer-file-name))
                  (pulumi-lab-activate-venv)
                  (lsp))))
    
    ;; Configure company for better completions
    (when (featurep 'company)
      (setq company-minimum-prefix-length 1)
      (setq company-idle-delay 0.2))))

;;; Pulumi Commands

(defun pulumi-lab-run-command (command &optional dir)
  "Run Pulumi COMMAND in DIR (or current experiment directory)."
  (interactive "sCommand: ")
  (let* ((default-directory (or dir (pulumi-lab-current-experiment-dir)))
         (compilation-buffer-name-function
          (lambda (mode) (format "*Pulumi %s*" command))))
    (compile (format "pulumi %s" command))))

(defun pulumi-lab-current-experiment-dir ()
  "Get the current experiment directory."
  (or (locate-dominating-file default-directory "Pulumi.yaml")
      (expand-file-name pulumi-lab-experiments-dir (pulumi-lab-project-root))))

(defun pulumi-lab-preview ()
  "Run pulumi preview in current experiment."
  (interactive)
  (pulumi-lab-run-command "preview"))

(defun pulumi-lab-up ()
  "Run pulumi up in current experiment."
  (interactive)
  (pulumi-lab-run-command "up"))

(defun pulumi-lab-destroy ()
  "Run pulumi destroy in current experiment."
  (interactive)
  (when (y-or-n-p "Really destroy infrastructure? ")
    (pulumi-lab-run-command "destroy")))

(defun pulumi-lab-stack-output ()
  "Show current stack outputs."
  (interactive)
  (pulumi-lab-run-command "stack output"))

(defun pulumi-lab-logs ()
  "Show stack logs."
  (interactive)
  (pulumi-lab-run-command "logs -f"))

;;; LocalStack Integration

(defun pulumi-lab-localstack-start ()
  "Start LocalStack for local AWS development."
  (interactive)
  (let ((default-directory (pulumi-lab-project-root)))
    (async-shell-command "make localstack-start" "*LocalStack*")))

(defun pulumi-lab-localstack-stop ()
  "Stop LocalStack."
  (interactive)
  (let ((default-directory (pulumi-lab-project-root)))
    (async-shell-command "make localstack-stop" "*LocalStack*")))

(defun pulumi-lab-localstack-status ()
  "Check LocalStack status."
  (interactive)
  (shell-command "docker ps | grep localstack"))

;;; Experiment Management

(defun pulumi-lab-list-experiments ()
  "List available Pulumi experiments."
  (interactive)
  (let ((experiments-dir (expand-file-name pulumi-lab-experiments-dir 
                                          (pulumi-lab-project-root))))
    (when (file-directory-p experiments-dir)
      (directory-files experiments-dir nil "^[0-9]"))))

(defun pulumi-lab-open-experiment (experiment)
  "Open a Pulumi EXPERIMENT directory."
  (interactive 
   (list (completing-read "Experiment: " 
                         (pulumi-lab-list-experiments))))
  (let ((exp-dir (expand-file-name 
                  (concat pulumi-lab-experiments-dir "/" experiment)
                  (pulumi-lab-project-root))))
    (find-file exp-dir)))

(defun pulumi-lab-create-experiment (name description)
  "Create a new Pulumi experiment with NAME and DESCRIPTION."
  (interactive "sExperiment name: \nsDescription: ")
  (let* ((project-root (pulumi-lab-project-root))
         (experiments-dir (expand-file-name pulumi-lab-experiments-dir project-root))
         (existing-experiments (pulumi-lab-list-experiments))
         (next-number (1+ (length existing-experiments)))
         (exp-name (format "%03d-%s" next-number name))
         (exp-dir (expand-file-name exp-name experiments-dir)))
    
    (make-directory exp-dir t)
    
    ;; Create Pulumi.yaml
    (with-temp-file (expand-file-name "Pulumi.yaml" exp-dir)
      (insert (format "name: %s
description: %s
runtime: python
template:
  config:
    pulumi:template: python
" exp-name description)))
    
    ;; Create __main__.py template
    (with-temp-file (expand-file-name "__main__.py" exp-dir)
      (insert "\"\"\"
Pulumi Infrastructure as Code
Experiment: " exp-name "
Description: " description "
\"\"\"

import pulumi

# Configuration
config = pulumi.Config()

# Resources go here

# Exports
pulumi.export(\"status\", \"created\")
"))
    
    ;; Create __main__.hy template
    (with-temp-file (expand-file-name "__main__.hy" exp-dir)
      (insert ";; Pulumi Infrastructure as Code in Hy
;; Experiment: " exp-name "
;; Description: " description "

(import pulumi)

;; Configuration
(setv config (pulumi.Config))

;; Resources go here

;; Exports
(pulumi.export \"status\" \"created\")
"))
    
    (message "Created experiment: %s" exp-dir)
    (find-file exp-dir)))

;;; Snippets and Templates

(defun pulumi-lab-insert-resource-template (resource-type)
  "Insert a template for RESOURCE-TYPE."
  (interactive 
   (list (completing-read "Resource type: "
                         '("aws.s3.BucketV2" "aws.ec2.Instance" 
                           "aws.lambda.Function" "aws.iam.Role"
                           "aws.vpc.Vpc" "github.Repository"))))
  (let ((template 
         (pcase resource-type
           ("aws.s3.BucketV2"
            "bucket = aws.s3.BucketV2(\"my-bucket\",\n    tags={\"Environment\": \"dev\"})")
           ("aws.ec2.Instance"
            "instance = aws.ec2.Instance(\"my-instance\",\n    instance_type=\"t3.micro\",\n    ami=\"ami-12345\")")
           ("aws.lambda.Function"
            "function = aws.lambda.Function(\"my-function\",\n    runtime=\"python3.9\",\n    handler=\"index.handler\",\n    code=pulumi.AssetArchive({\".\":\"./src\"}))")
           ("aws.iam.Role"
            "role = aws.iam.Role(\"my-role\",\n    assume_role_policy=json.dumps({\n        \"Version\": \"2012-10-17\",\n        \"Statement\": [{\n            \"Effect\": \"Allow\",\n            \"Principal\": {\"Service\": \"ec2.amazonaws.com\"},\n            \"Action\": \"sts:AssumeRole\"\n        }]\n    }))")
           ("aws.vpc.Vpc"
            "vpc = aws.ec2.Vpc(\"my-vpc\",\n    cidr_block=\"10.0.0.0/16\",\n    enable_dns_hostnames=True)")
           ("github.Repository"
            "repo = github.Repository(\"my-repo\",\n    description=\"Created with Pulumi\",\n    visibility=\"private\")")
           (_ ""))))
    (insert template)))

;;; Project Utilities

(defun pulumi-lab-run-tests ()
  "Run project tests."
  (interactive)
  (let ((default-directory (pulumi-lab-project-root)))
    (compile "python -m pytest")))

(defun pulumi-lab-format-code ()
  "Format Python code with black."
  (interactive)
  (let ((default-directory (pulumi-lab-project-root)))
    (shell-command "black .")))

(defun pulumi-lab-lint-code ()
  "Lint code with ruff."
  (interactive)
  (let ((default-directory (pulumi-lab-project-root)))
    (compile "ruff check .")))

(defun pulumi-lab-type-check ()
  "Run type checking with mypy."
  (interactive)
  (let ((default-directory (pulumi-lab-project-root)))
    (compile "mypy .")))

;;; Policy as Code Support

(defun pulumi-lab-validate-policy ()
  "Validate Pulumi policies."
  (interactive)
  (let ((default-directory (pulumi-lab-current-experiment-dir)))
    (compile "pulumi policy validate")))

(defun pulumi-lab-run-policy-pack ()
  "Run policy pack against current stack."
  (interactive)
  (let ((default-directory (pulumi-lab-current-experiment-dir)))
    (compile "pulumi up --policy-pack ../policy-pack")))

;;; Keybindings

(defvar pulumi-lab-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c p p") 'pulumi-lab-preview)
    (define-key map (kbd "C-c p u") 'pulumi-lab-up)
    (define-key map (kbd "C-c p d") 'pulumi-lab-destroy)
    (define-key map (kbd "C-c p o") 'pulumi-lab-stack-output)
    (define-key map (kbd "C-c p l") 'pulumi-lab-logs)
    (define-key map (kbd "C-c p e") 'pulumi-lab-open-experiment)
    (define-key map (kbd "C-c p n") 'pulumi-lab-create-experiment)
    (define-key map (kbd "C-c p i") 'pulumi-lab-insert-resource-template)
    (define-key map (kbd "C-c p s") 'pulumi-lab-setup-environment)
    (define-key map (kbd "C-c l s") 'pulumi-lab-localstack-start)
    (define-key map (kbd "C-c l t") 'pulumi-lab-localstack-stop)
    (define-key map (kbd "C-c l ?") 'pulumi-lab-localstack-status)
    map)
  "Keymap for Pulumi Lab mode.")

;;; Minor Mode

;;;###autoload
(define-minor-mode pulumi-lab-mode
  "Minor mode for Pulumi Infrastructure as Code development."
  :lighter " Pulumi"
  :keymap pulumi-lab-mode-map
  (when pulumi-lab-mode
    (pulumi-lab-configure-babel)
    (pulumi-lab-configure-lsp)
    (pulumi-lab-setup-environment)))

;;;###autoload
(defun pulumi-lab-enable-for-project ()
  "Enable Pulumi Lab mode if in a Pulumi lab project."
  (when (pulumi-lab-project-root)
    (pulumi-lab-mode 1)))

;; Auto-enable for Python and Hy files in Pulumi projects
(add-hook 'python-mode-hook 'pulumi-lab-enable-for-project)
(add-hook 'hy-mode-hook 'pulumi-lab-enable-for-project)
(add-hook 'org-mode-hook 'pulumi-lab-enable-for-project)

;;; Hy Mode Integration

(with-eval-after-load 'hy-mode
  (defun pulumi-lab-hy-setup ()
    "Setup Hy mode for Pulumi development."
    (setq-local inferior-lisp-program pulumi-lab-hy-command)
    (when (featurep 'company)
      (setq-local company-backends 
                  '((company-files company-keywords company-dabbrev-code)))))
  
  (add-hook 'hy-mode-hook 'pulumi-lab-hy-setup))

;;; Flycheck Integration

(with-eval-after-load 'flycheck
  (flycheck-add-mode 'python-pylint 'python-mode)
  (flycheck-add-mode 'python-pycompile 'python-mode))

;;; Company Integration

(with-eval-after-load 'company
  (defun pulumi-lab-company-setup ()
    "Setup company mode for Pulumi development."
    (setq-local company-backends
                '((company-lsp company-files company-keywords company-dabbrev-code))))
  
  (add-hook 'python-mode-hook 'pulumi-lab-company-setup))

;;; Projectile Integration

(with-eval-after-load 'projectile
  (add-to-list 'projectile-project-root-files "Pulumi.yaml")
  (add-to-list 'projectile-project-root-files "pulumi-lab.el"))

(provide 'pulumi-lab)

;;; pulumi-lab.el ends here
