#!/usr/bin/env hy
;; Simple GitHub API test for CI
;; Lists public repositories for a user

(import os)
(import sys)
(import json)

(try
  (import urllib.request [urlopen Request])
  (except [ImportError]
    (print "urllib not available")
    (sys.exit 1)))

(defn test-github-api []
  "Test GitHub API by fetching public repos"
  (setv github-user "pulumi")  ; Test with Pulumi org
  (setv api-url f"https://api.github.com/users/{github-user}/repos?per_page=3")
  
  (print f"Testing GitHub API: {api-url}")
  
  (try
    ;; Create request with headers
    (setv request (Request api-url))
    (.add-header request "Accept" "application/vnd.github.v3+json")
    (.add-header request "User-Agent" "Pulumi-Lab-CI")
    
    ;; Make request
    (setv response (urlopen request :timeout 10))
    (setv data (json.loads (.decode (.read response))))
    
    ;; Display results
    (print f"✅ Successfully fetched {(len data)} repositories:")
    (for [repo data]
      (print f"  - {(get repo \"name\")}: {(get repo \"description\" \"No description\")[:50]}"))
    
    0  ; Success
    
    (except [Exception e]
      (print f"❌ API test failed: {e}")
      1)))  ; Failure

;; Run test
(sys.exit (test-github-api))