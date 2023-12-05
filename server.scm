#!/usr/bin/env sh
exec guile --no-auto-compile -s "$0" "$@"
!#

(use-modules
 (ice-9 popen)
 (ice-9 binary-ports)
 (ice-9 textual-ports)

 (web server)
 (web request)
 (web response)
 (web uri)
)

(define %webroot
  (let* ((cmd-line (command-line))
         (script   (car cmd-line))
         (args     (cdr cmd-line)))
    (if (= 1 (length args))
        (car args)
        (begin
          (format (current-error-port) "\
Usage: ~a PATH

where PATH is the webserver root
"
                  script)
          (quit 1)))))

(define (path-join components)
   (string-join components file-name-separator-string))

(define (shell prog . args)
  (let* ((port (apply open-pipe* OPEN_READ prog args))
         (output (get-string-all port)))
    (close-pipe port)
    output))

(define (mime-type path)
  (string->symbol
   (string-trim-right
    (shell "xdg-mime" "query" "filetype" path)
    #\newline)))

(define (request-path-components request)
  (split-and-decode-uri-path (uri-path (request-uri request))))

(define (construct-resource-path request)
  (path-join (apply list %webroot (request-path-components request))))

(define (resolve-resource-path path)
  (if (access? path R_OK)
      (case (stat:type (stat path))
        ((regular)
         (canonicalize-path path))
        ((directory)
         (resolve-resource-path
          (path-join (list path "index.html"))))
        (else 'error-filetype))
      'error-unreadable))

(define (not-found request)
  (values (build-response #:code 404)
          (string-append "Resource not found: "
                         (uri->string (request-uri request)))))

(define (request-handler request body)
  (let ((path (resolve-resource-path
               (construct-resource-path request))))
    (case path
      ((error-filetype error-unreadable)
       (not-found request))
      (else
       (values `((content-type
                  . ,(list (mime-type path))))
               (call-with-input-file path get-bytevector-all))))))

(run-server request-handler)

;;; Local Variables:
;;; mode: scheme
;;; End:

;;; server.scm ends here
