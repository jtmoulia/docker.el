;;; docker-utils.el --- Random utilities  -*- lexical-binding: t -*-

;; Author: Philippe Vaucher <philippe.vaucher@gmail.com>

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

;;; Code:

(require 'dash)
(require 'tramp)
(require 'tablist)
(require 'transient)

(defun docker-utils-get-marked-items ()
  "Get the marked items data from `tabulated-list-entries'."
  (save-excursion
    (goto-char (point-min))
    (let ((selection ()))
      (while (not (eobp))
        (when (not (null (tablist-get-mark-state)))
          (setq selection (-snoc selection (cons (tabulated-list-get-id) (tabulated-list-get-entry)))))
        (forward-line))
      selection)))

(defun docker-utils-get-marked-items-ids ()
  "Get the id part of `docker-utils-get-marked-items'."
  (-map #'car (docker-utils-get-marked-items)))

(defun docker-utils-run-action-on-selection (action args items)
  "Run \"docker-compose ACTION ARGS\" for all ITEMS."
  (interactive (list
                (-last-item (s-split "-" (symbol-name current-transient-command)))
                (transient-args current-transient-command)
                (docker-utils-get-marked-items-ids)))
  (--each items
    (docker-run-docker action args it))
  (tablist-revert))

(defun docker-utils-select-if-empty (&optional arg)
  "Select current row is selection is empty.
ARG is unused here, but is required by `add-function'."
  (save-excursion
    (when (null (docker-utils-get-marked-items))
      (tablist-put-mark))))

(defun docker-utils-pop-to-buffer (name)
  "Like `pop-to-buffer', but suffix NAME with the host if on a remote host."
  (pop-to-buffer
   (if (file-remote-p default-directory)
       (with-parsed-tramp-file-name default-directory nil (concat name " - " host))
     name)))

(defmacro docker-utils-define-transient-select-if-empty (name &body)
  `(define-transient-command ,name ()
     ,body
     (interactive)
     (docker-utils-select-if-empty)
     (transient-setup ',name)))

(defmacro docker-utils-with-buffer (name &rest body)
  "Wrapper around `with-current-buffer'.
Execute BODY in a buffer named with the help of NAME."
  (declare (indent defun))
  `(with-current-buffer (generate-new-buffer (format "* docker - %s *" ,name))
     (setq buffer-read-only nil)
     (erase-buffer)
     ,@body
     (setq buffer-read-only t)
     (goto-char (point-min))
     (pop-to-buffer (current-buffer))))

(defun docker-utils-unit-multiplier (str)
  "Return the correct multiplier for STR."
  (expt 1024 (-elem-index str '("B" "KB" "MB" "GB" "TB" "PB" "EB"))))

(defun docker-utils-human-size-to-bytes (str)
  "Parse STR and return size in bytes."
  (let* ((parts (s-match "^\\([0-9\\.]+\\)\\([A-Z]+\\)?$" str))
         (value (string-to-number (-second-item parts)))
         (multiplier (docker-utils-unit-multiplier (-third-item parts))))
    (* value multiplier)))

(provide 'docker-utils)

;;; docker-utils.el ends here
