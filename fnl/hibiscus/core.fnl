(require-macros :hibiscus.utils)

(local M {})

;; -------------------- ;;
;;        UTILS         ;;
;; -------------------- ;;
(fn require-fennel []
  ; try to load fennel
  (var (ok out) (pcall require :tangerine.fennel))
  (if ok
    (set out (out.load))
    (set (ok out) (pcall require :fennel)))
  ; assert for fennel
  (assert-compile ok
    (.. "  hibiscus: module for \34fennel\34 not found.\n\n"
        "    * install fennel globally or install tangerine.nvim."))
  :return out)

(lambda set* [name val]
  "sets variable 'name' to 'val' and returns its value."
  `(do (set-forcibly! ,name ,val) ,name))

(lambda tset* [tbl key val]
  "sets 'key' in 'tbl' to 'val' and returns its value."
  `(do (tset ,tbl ,key ,val) (. ,tbl ,key)))


;; -------------------- ;;
;;       GENERAL        ;;
;; -------------------- ;;
(fun or= [x ...]
  "checks if 'x' is equal to any one of {...}"
  `(do
   (var out# false)
   (each [# v# (ipairs [,...])]
     (when (= ,x v#)
       (set out# true)
       (lua :break)))
   :return out#))

(lun enum! [name ...]
  "defines enumerated values for names."
  (local vals [])
  (each [i n (ipairs [name ...])]
    (check [:sym (as name n)])
    (table.insert vals i))
  '(local ,[name ...] ,vals))


;; -------------------- ;;
;;       FSTRING        ;;
;; -------------------- ;;
(lambda gen-ast [expr]
  "parses fennel 'expr' into ast."
  (local (ok out)
         (((. (require-fennel) :parser) expr "fstring")))
  :return out)

(lun fstring! [str]
  "wrapper around string.format, works like javascript's template literates."
  (check [:string str])
  (local args [])
  (each [xs (str:gmatch "$([({][^$]+[})])")]
    (if (xs:find "^{")
        (table.insert args (sym (xs:match "^{(.+)}$")))
        (table.insert args (gen-ast xs))))
  :return
  `(string.format ,(str:gsub "$[({][^$]+[})]" "%%s") ,(unpack args)))


;; -------------------- ;;
;;       CHECKING       ;;
;; -------------------- ;;
(fun nil? [x]
  "checks if value of 'x' is nil."
  `(= nil ,x))

(fun boolean? [x]
  "checks if 'x' is of boolean type."
  `(= :boolean (type ,x)))

(fun string? [x]
  "checks if 'x' is of string type."
  `(= :string (type ,x)))

(fun number? [x]
  "checks if 'x' is of number type."
  `(= :number (type ,x)))

(fun odd? [x]
  "checks if 'x' is mathematically of odd parity ;}"
  `(and ,(number? x) (= 1 (% ,x 2))))

(fun even? [x]
  "checks if 'x' is mathematically of even parity ;}"
  `(and ,(number? x) (= 0 (% ,x 2))))

(fun fn? [x]
  "checks if 'x' is of function type."
  `(= :function (type ,x)))

(fun table? [x]
  "checks if 'x' is of table type."
  `(= :table (type ,x)))

(fun seq? [tbl]
  "checks if 'tbl' is a valid list."
  `(vim.tbl_islist ,tbl))

(fun empty? [x]
  "checks if 'x' is empty."
  `(if ,(string? x)
        (= 0 (length ,x))
       ,(table? x)
        ((fn [t#] (each [# (pairs t#)] (lua "return false")) true) ,x)
        false))


;; -------------------- ;;
;;        NUMBER        ;;
;; -------------------- ;;
(lun inc! [int]
  "increments 'int' by 1."
  `(+ ,int 1))

(lun ++ [v]
  "increments variable 'v' by 1."
  (set* v (inc! v)))

(lun dec! [int]
  "decrements 'int' by 1."
  `(- ,int 1))

(lun -- [v]
  "decrements variable 'v' by 1."
  (set* v (dec! v)))


;; -------------------- ;;
;;        STRING        ;;
;; -------------------- ;;
(lun split! [str sep]
  "splits 'str' into a list at each 'sep'."
  '(do
   (local out# [])
   (each [x# (string.gmatch (.. ,str ,sep) (.. "(.-)" ,sep "+"))]
     (table.insert out# x#))
   :return out#))

(lun append! [v str]
  "appends 'str' to variable 'v'."
  (check [:sym (as var v)])
  (set* v (list `.. v str)))

(lun tappend! [tbl key str]
  "appends 'str' to 'key' of table 'tbl'."
  (tset* tbl key `(.. (or (. ,tbl ,key) "") ,str)))

(lun prepend! [v str]
  "prepends 'str' to variable 'v'."
  (check [:sym (as var v)])
  (set* v (list `.. str v)))

(lun tprepend! [tbl key str]
  "prepends 'str' to 'key' of table 'tbl'."
  (tset* tbl key `(.. ,str (or (. ,tbl ,key) ""))))


;; -------------------- ;;
;;        TABLE         ;;
;; -------------------- ;;
(lun tmap! [tbl handler]
  "maps values in table with 'handler'."
  '(let [out# {}
         fnc# ,handler]
     (each [key# val# (pairs ,tbl)]
       (tset out# key# (fnc# key# val#)))
     :return out#))

(lun filter! [lst handler]
  "filters values in list with 'handler'."
  '(let [out# []
         fnc# ,handler]
     (each [# val# (pairs ,lst)]
       (if (fnc# val#)
           (table.insert out# val#)))
     :return out#))

(lun merge-list! [list1 list2]
  "appends all values of 'list1' and 'list2' together."
  `(let [out# (vim.deepcopy ,list1)]
     (each [# val# (ipairs (vim.deepcopy ,list2))]
           (table.insert out# val#))
     :return out#))

(lun merge-tbl! [tbl1 tbl2]
  "merges 'tbl2' onto 'tbl1', returns a new table."
  `(do
   (fn mrg# [x# y#]
     (local out# (vim.deepcopy x#))
     (each [k# v# (pairs (vim.deepcopy y#))]
       (if (= :table (type v#) (type (. out# k#)))
           (tset out# k# (mrg# (. out# k#) v#))
           (tset out# k# v#)))
     :return out#)
   (mrg# ,tbl1 ,tbl2)))

(lun merge! [tbl1 tbl2]
  "merges 'tbl2' onto 'tbl1', correctly appending lists."
  `(if (and ,(seq? tbl1) ,(seq? tbl2))
       ,(merge-list! tbl1 tbl2)
       ,(merge-tbl! tbl1 tbl2)))

(lun vmerge! [v tbl]
  "merges 'tbl' onto variable 'v'."
  (check [:sym (as var v)])
  (set* v (M.merge! v tbl)))


;; -------------------- ;;
;;     PRETTY PRINT     ;;
;; -------------------- ;;
(fun dump! [...]
  "pretty prints {...} into human readable form."
  `(let [out# []]
     (if (?. _G.tangerine :api :serialize)
         (table.insert out# [(_G.tangerine.api.serialize ,...)])
         (each [# v# (ipairs [,...])]
           (table.insert out# [(vim.inspect v#)])))
     (vim.api.nvim_echo out# false [])))


:return M
