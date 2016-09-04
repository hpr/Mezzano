;;;; Copyright (c) 2011-2016 Henry Harrington <henry.harrington@gmail.com>
;;;; This code is licensed under the MIT license.

(in-package :asdf)

(defsystem "lispos"
  :description "Lisp operating system."
  :version "0"
  :author "Henry Harrington <henry.harrington@gmail.com>"
  :licence "MIT"
  :depends-on (#:nibbles #:cl-ppcre #:iterate
               #:alexandria)
  :serial t
  :components ((:file "compiler/cross")
               (:file "system/data-types")
               (:file "system/parse")
               (:file "system/backquote")
               (:file "compiler/compiler")
               (:file "compiler/environment")
               (:file "compiler/cross-compile")
               (:file "compiler/cross-boot")
               (:file "compiler/lap")
               (:file "compiler/lap-x86")
               (:file "compiler/lap-arm64")
               (:file "compiler/ast")
               (:file "compiler/ast-generator")
               (:file "compiler/keyword-arguments")
               (:file "compiler/simplify-arguments")
               (:file "compiler/pass1")
               (:file "compiler/inline")
               (:file "compiler/lift")
               (:file "compiler/simplify")
               (:file "compiler/constprop")
               (:file "compiler/kill-temps")
               (:file "compiler/value-aware-lowering")
               (:file "compiler/lower-environment")
               (:file "compiler/lower-special-bindings")
               (:file "compiler/simplify-control-flow")
               (:file "compiler/codegen-x86-64")
               (:file "compiler/branch-tension")
               (:file "compiler/builtins-x86-64/builtins")
               (:file "compiler/builtins-x86-64/array")
               (:file "compiler/builtins-x86-64/character")
               (:file "compiler/builtins-x86-64/cons")
               (:file "compiler/builtins-x86-64/memory")
               (:file "compiler/builtins-x86-64/misc")
               (:file "compiler/builtins-x86-64/numbers")
               (:file "compiler/builtins-x86-64/objects")
               (:file "compiler/builtins-x86-64/unwind")
               (:file "tools/build-unicode")
               (:file "tools/build-pci-ids")
               (:file "tools/cold-generator")
               (:file "tools/cold-generator-x86-64")
               (:file "tools/cold-generator-arm64")))
