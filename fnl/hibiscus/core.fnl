(local M {})

;; -------------------- ;;
;;        FENNEL        ;;
;; -------------------- ;;
(fn fennel []
  ; require fennel
  (var (ok out) (pcall require :tangerine.fennel))
  (if ok
    (set out (out.load))
    (set (ok out) (pcall require :fennel)))
  ; assert
  (assert-compile ok
    (.. "  hibiscus: module for \34fennel\34 not found.\n\n"
        "    * install fennel globally or install tangerine.nvim."))
  :return out)


;; -------------------- ;;
;;        UTILS         ;;
;; -------------------- ;;
(macro fun [name ...]
  "defines function 'name' and exports it to M."
  `(tset M ,(tostring name) (fn ,name ,...)))

(macro lmd [name args ...]
  "defines lambda function 'name' and exports it to M."
  (local asrt [])
  (each [_ arg (ipairs args)]
    (if (not= "?" (string.sub (tostring arg) 1 1))
        (table.insert asrt
          `(assert-compile (not= ,arg nil)
                           (.. "  " ,(tostring name) ": Missing required argument '" ,(tostring arg) "'.") ,arg))))
  `(tset M ,(tostring name)
           (fn ,name ,args (do ,(unpack asrt)) ,...)))

(lambda set- [name val]
  "sets variable 'name' to 'val' and returns its value."
  `(do (set-forcibly! ,name ,val)
       :return ,name))

(lambda tset- [tbl key val]
  "sets 'key' in 'tbl' to 'val' and returns its value."
  `(do (tset ,tbl ,key ,val)
       :return (. ,tbl ,key)))


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


;; -------------------- ;;
;;       FSTRING        ;;
;; -------------------- ;;
(lmd ast [expr]
  "parses fennel 'expr' into ast."
  (local (ok out)
         (((. (fennel) :parser) expr "fstring")))
  :return out)

(lmd fstring [str]
  "wrapper around string.format, works like javascript's template literates."
  (local args [])
  (each [xs (str:gmatch "$([({][^$]+[})])")]
    (if (xs:find "^{")
        (table.insert args (sym (xs:match "^{(.+)}$")))
        (table.insert args (ast xs))))
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

(fun empty? [tbl]
  "checks if 'tbl' is empty."
  `(and ,(table? tbl)
        (= 0 (length ,tbl))))


;; -------------------- ;;
;;        NUMBER        ;;
;; -------------------- ;;
(lmd inc [int]
  "increments 'int' by 1."
  `(+ ,int 1))

(lmd ++ [v]
  "increments variable 'v' by 1."
  (set- v (inc v)))

(lmd dec [int]
  "decrements 'int' by 1."
  `(- ,int 1))

(lmd -- [v]
  "decrements variable 'v' by 1."
  (set- v (dec v)))


;; -------------------- ;;
;;        STRING        ;;
;; -------------------- ;;
(lmd append [v str]
  "appends 'str' to variable 'v'."
  (set- v (list `.. v str)))

(lmd tappend [tbl key str]
  "appends 'str' to 'key' of table 'tbl'."
  (tset- tbl key `(.. (or (. ,tbl ,key) "") ,str)))

(lmd prepend [v str]
  "prepends 'str' to variable 'v'."
  (set- v (list `.. str v)))

(lmd tprepend [tbl key str]
  "prepends 'str' to 'key' of table 'tbl'."
  (tset- tbl key `(.. ,str (or (. ,tbl ,key) ""))))


;; -------------------- ;;
;;        TABLE         ;;
;; -------------------- ;;
(lmd merge-list [list1 list2]
  "merges all values of 'list1' and 'list2' together."
  `(let [out# []]
     (each [# v# (ipairs ,list1)]
           (table.insert out# v#))
     (each [# v# (ipairs ,list2)]
           (table.insert out# v#))
     :return out#))

(lmd merge [tbl1 tbl2]
  "merges 'tbl2' onto 'tbl1', correctly appending lists."
  `(if (and ,(seq? tbl1) ,(seq? tbl2))
       ,(merge-list tbl1 tbl2)
       :else
       (vim.tbl_deep_extend "force" ,tbl1 ,tbl2)))

(lmd merge! [v tbl]
  "merges 'tbl' onto variable 'v'."
  (set- v (M.merge v tbl)))


;; -------------------- ;;
;;     PRETTY PRINT     ;;
;; -------------------- ;;
(fun dump [...]
  "pretty prints {...} into human readable form."
  `(let [out# []]
     (if (?. _G.tangerine :api :serialize)
         (table.insert out# [(_G.tangerine.api.serialize ,...)])
         (each [# v# (ipairs [,...])]
           (table.insert out# [(vim.inspect v#)])))
     (vim.api.nvim_echo out# false [])))


:return M
