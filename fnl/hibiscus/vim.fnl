(import-macros {
  : or=
  : ++
  : inc
  : odd?
  : even?
  : string?
  : tappend
} :hibiscus.core)

(local M {})

;; -------------------- ;;
;;        UTILS         ;;
;; -------------------- ;;
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

(lambda dolist [lst]
  "unpacks 'lst' and wrap it within do block."
  `(do ,(unpack lst)))

(lambda parse-sym [xs]
  "parses symbol 'xs' converts it to string if not a variable."
  (if (or (in-scope? xs) (not (sym? xs)))
      (do xs)
      (tostring xs)))

(lambda parse-list [sx]
  "parses symbols present in sequence 'sx'."
  (if (sequence? sx)
      (vim.tbl_map parse-sym sx)
      (parse-sym sx)))


;; -------------------- ;;
;;       HELPERS        ;;
;; -------------------- ;;
(lambda func? [x]
  "checks if 'x' is function definition."
  (let [ref (?. x 1 1)]
    (or= ref :fn :hashfn :lambda :partial)))

(lambda quote? [x]
  "checks if 'x' is quoted value."
  (let [ref (?. x 1 1)]
    (= ref :quote)))

(lambda parse-cmd [xs ...]
  "parses command 'xs', wrapping it in function if quoted."
  (if (quote? xs)
      (let [ref (. xs 2)]
        (if (list? ref) `(fn [] ,ref) ref))
      :else xs))


;; -------------------- ;;
;;       GENERAL        ;;
;; -------------------- ;;
(lmd concat [lst sep]
  "smartly concats all strings in 'lst' with 'sep'."
  (var out [])
  (var idx 1)
  (each [i v (ipairs lst)]
    ; ignore separator at end
    (local sep
           (if (< i (# lst)) sep ""))
    ; concat string
    (if (string? v)
        (tappend out idx (.. v sep))
        :else
        (do (tset out (++ idx) `(.. ,v ,sep))
            (++ idx))))
  :return 
  (if (= idx 1)
      (unpack out)
      (list `.. (unpack out))))

(lmd exec [cmds]
  "wraps [cmd] chunks in 'cmds' within vim.cmd block."
  (local out [])
  (each [_ cmd (ipairs cmds)]
        (table.insert out `(vim.cmd ,(concat cmd " "))))
  (table.insert out true)
  :return
  (dolist out))


;; -------------------- ;;
;;       MAPPINGS       ;;
;; -------------------- ;;
(lambda parse-map-args [args]
  "parses map 'args' into (modes opts) chunk."
  (let [modes []
        opts  {:silent true}]
    ; parse modes
    (each [mode (string.gmatch (tostring (table.remove args 1)) ".")]
      (table.insert modes mode))
    ; parse options
    (each [_ key (ipairs args)]
      (if (= key :verbose)
          (tset opts :silent false)
          (tset opts key true)))
    :return
    (values modes opts)))

(lmd map! [args lhs rhs]
  "defines vim keymap for modes in 'args'."
  (assert-compile (. args 1)
    "map: missing required argument 'mode'." args)
  (local (modes opts) (parse-map-args args))
  :return
  `(vim.keymap.set ,modes ,lhs ,(parse-cmd rhs) ,opts))


;; -------------------- ;;
;;       AUTOCMDS       ;;
;; -------------------- ;;
(lambda parse-callback [cmd]
  "parses cmd into valid (name callback) chunk for opts in lua api."
  (if (or (func? cmd) (quote? cmd))
      (values :callback (parse-cmd cmd))
      (values :command  (do cmd))))

(lambda autocmd [id [events pattern cmd]]
  "defines autocmd for group of 'id'."
  ;; parse events
  (local opts {:once false :nested false})
  (each [i e (ipairs events)]
    (when (or= e :once :nested)
      (tset opts e true)
      (table.remove events i)))
  (local events (parse-list events))
  ;; parse patterns
  (local pattern
    (if (sequence? pattern) (parse-list pattern) (parse-sym pattern)))
  ;; parse callback
  (local (name val) (parse-callback cmd))
  :return
  `(vim.api.nvim_create_autocmd ,events {:once ,opts.once :nested ,opts.nested :group ,id :pattern ,pattern ,name ,val}))

(lmd augroup! [name ...]
  "defines augroup with 'name' and {...} containing [[groups] pat cmd] chunks."
  (assert-compile
    (string? name)
    (.. "  augroup: invalid name " (view name)) name)
  ;; define augroup
  (local id  (gensym :augid))
  (local out [])
  (table.insert out `(local ,id (vim.api.nvim_create_augroup ,name {:clear true})))
  ;; define autocmds
  (each [_ au (ipairs [...])]
    (assert-compile
      (sequence? au)
      (.. "  augroup: autocmds expected to be a sequence, got " (view au)) au)
    (table.insert out (autocmd id au)))
  :return
  (dolist out))


;; -------------------- ;;
;;       COMMANDS       ;;
;; -------------------- ;;
(lambda parse-command-args [args]
  "converts list of 'args' into table of valid command-opts."
  (assert-compile
    (even? (# args))
    "  command: expected even number of values in args." args)
  (local out {:force true})
  (each [idx val (ipairs args)]
    (if (odd? idx)
        (tset out val (. args (inc idx)))))
  :return out)

(lmd command! [args lhs rhs]
  "defines a user command from 'lhs' and 'rhs'."
  `(vim.api.nvim_create_user_command ,lhs ,(parse-cmd rhs) ,(parse-command-args args)))


;; -------------------- ;;
;;       OPTIONS        ;;
;; -------------------- ;;
(lmd set! [name ?val]
  "sets vim option 'name', optionally taking 'val'."
  (local name (parse-sym name))
  (if (not= nil ?val)
      `(tset vim.opt ,name ,?val)
      (string? name)
      (if (= :no (string.sub name 1 2))
          `(tset vim.opt ,(string.sub name 3) false)
          `(tset vim.opt ,name true))
      ; else at runtime
      `(if (= :no (string.sub ,name 1 2))
           (tset vim.opt (string.sub ,name 3) false)
           (tset vim.opt ,name true))))

(lmd set+ [name val]
  "appends 'val' to vim option 'name'."
  `(: (. vim.opt ,(parse-sym name)) :append ,val))

(lmd set^ [name val]
  "prepends 'val' to vim option 'name'."
  `(: (. vim.opt ,(parse-sym name)) :prepend ,val))

(lmd rem! [name val]
  "removes 'val' from vim option 'name'."
  `(: (. vim.opt ,(parse-sym name)) :remove ,val))

(lmd color! [name]
  "sets vim colorscheme to 'name'."
  (exec [[:colorscheme (parse-sym name)]]))


;; -------------------- ;;
;;      VARIABLES       ;;
;; -------------------- ;;
(lmd g! [name val]
  "sets global variable 'name' to 'val'."
  `(tset vim.g ,(parse-sym name) ,val))

(lmd b! [name val]
  "sets buffer scoped variable 'name' to 'val'."
  `(tset vim.b ,(parse-sym name) ,val))


:return M
