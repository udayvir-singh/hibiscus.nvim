(local M {})

;; -------------------- ;;
;;        UTILS         ;;
;; -------------------- ;;
(lambda ass [cond ...]
  "shorthand for assert-compile."
  `(assert-compile ,cond (.. "  " ,(sym :__name__) ": " ,...)))


;; -------------------- ;;
;;      FUNCTIONS       ;;
;; -------------------- ;;
(lambda M.fun [name args ...]
  "defines function 'name' and exports it to M."
  (local name-sym `(local ,(sym :__name__) ,(tostring name)))
  `(tset M ,(tostring name) (fn ,name ,args ,name-sym ,...)))

(lambda M.lun [name args ...]
  "defines lambda function 'name' and exports it to M."
  (local name-str (tostring name))
  (local name-sym `(local ,(sym :__name__) ,name-str))
  (local asrt [])
  (each [_ arg (ipairs args)]
    (if (and (not= "..." (tostring arg)) (not= "?" (string.sub (tostring arg) 1 1)))
        (table.insert asrt
          (ass `(not= ,arg nil) "Missing required argument '" (tostring arg) "'."))))
  `(tset M ,name-str
     (fn ,name ,args ,name-sym (do ,(unpack asrt)) ,...)))


;; -------------------- ;;
;;       CHECKING       ;;
;; -------------------- ;;
(lambda assert-real [v scope]
  "asserts if 'v' is not nil."
  (ass v "Missing required argument '" scope "'."))

(lambda assert-even [v scope]
  "asserts if 'v' is even."
  (ass `(= 0 (% ,v 2))
      "expected even number of arguments in '" scope "'."))

(lambda assert-list [v scope]
  "asserts if 'v' is a list."
  (ass `(list? ,v)
      "'" scope "' expected to be a function call."))

(lambda assert-sym [v scope]
  "asserts if 'v' is a symbol."
  (ass `(sym? ,v)
      "'" scope "' expected to be a symbol."))

(lambda assert-seq [v scope]
  "asserts if 'v' is a list."
  (ass `(vim.tbl_islist ,v)
      "'" scope "' expected to be a sequence."))

(lambda assert-fseq [v scope]
  "asserts if 'v' is a literal fennel sequence."
  (ass `(sequence? ,v)
      "'" scope "' expected to be a fennel sequence created by [] braces."))

(lambda assert-type [t v scope]
  "asserts if 'v' is of type 't'."
  (ass `(= ,t (type ,v))
      "'" scope "' expected to be of type " t "."))

(lambda M.check [c]
  (assert-compile (= 0 (% (length c) 2))
    "  hibiscus: check: expected even number of arguments.")
  (local asrt [])
  (for [i 1 (length c) 2]
    (let [x (. c i)
          y (. c (+ 1 i))]
      ; parse first argument
      (local [name val] (if (= :as (?. y 1 1))
                            [(. y 2) (. y 3)]
                            [nil y]))
      ; add assertion
      (local scope (if name (tostring name) (tostring val)))
      (table.insert asrt
        (match x
          :real (assert-real val scope)
          :even (assert-even val scope)
          :list (assert-list val scope)
          :sym  (assert-sym val scope)
          :seq  (assert-seq val scope)
          :fseq (assert-fseq val scope)
          _     (assert-type x val scope)))))
  :return
  `(do ,(unpack asrt)))


:return M
