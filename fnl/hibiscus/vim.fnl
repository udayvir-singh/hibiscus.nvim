(require-macros :hibiscus.utils)
(require-macros :hibiscus.core)

(local M {})

;; -------------------- ;;
;;        UTILS         ;;
;; -------------------- ;;
(lambda func? [x]
  "checks if 'x' is function definition."
  (let [ref (?. x 1 1)]
    (or= ref :fn :hashfn :lambda :partial)))

(lambda quote? [x]
  "checks if 'x' is quoted value."
  (let [ref (?. x 1 1)]
    (= ref :quote)))

(lambda dolist [lst]
  "unpacks 'lst' and wrap it within do block."
  `(do ,(unpack lst)))

(lambda parse-sym [xs]
  "parses symbol 'xs' converts it to string if not a variable."
  (if (or (in-scope? xs) (not (sym? xs)))
      (do xs)
      (tostring xs)))

(lambda parse-list [sq]
  "parses symbols present in sequence 'sq'."
  (vim.tbl_map parse-sym sq))

(lambda parse-cmd [xs ...]
  "parses command 'xs', wrapping it in function if quoted."
  (if (quote? xs)
      (let [ref (. xs 2)]
        (if (list? ref) `(fn [] ,ref) ref))
      :else xs))

(lambda list-remove [lst idxs]
  "remove values on 'idxs' from 'lst'."
  (local out [])
  (each [_ idx (ipairs idxs)]
    (tset lst idx nil))
  (each [_ val (pairs lst)]
    (table.insert out val))
  :return out)


;; -------------------- ;;
;;       GENERAL        ;;
;; -------------------- ;;
(lun concat! [lst sep]
  "smartly concats all strings in 'lst' with 'sep'."
  (check [:seq lst :string sep])
  (var out [])
  (var len 1)
  (each [i v (ipairs lst)]
    ; ignore separator at end
    (local sep (if (< i (# lst)) sep ""))
    ; concat string
    (if (string? v)
        (tappend! out len (.. v sep))
        :else
        (do (tset out (++ len) `(.. ,v ,sep))
            (++ len))))
  :return
  (if (= len 1)
      (unpack out)
      (list `.. (unpack out))))

(lun exec! [cmds]
  "wraps [cmd] chunks in 'cmds' within vim.cmd block."
  (check [:seq cmds])
  (local out [])
  (each [_ cmd (ipairs cmds)]
        (table.insert out `(vim.cmd ,(concat! cmd " "))))
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

(lun map! [args lhs rhs ?desc]
  "defines vim keymap for modes in 'args'."
  (check [:real   (as mode (. args 1))
          :string (as description (or ?desc ""))])
  (local (modes opts) (parse-map-args args))
  (set opts.desc ?desc)
  :return
  `(vim.keymap.set ,modes ,lhs ,(parse-cmd rhs) ,opts))


;; -------------------- ;;
;;       AUTOCMDS       ;;
;; -------------------- ;;
(lambda parse-pattern [opts pattern]
  (if ; parse buffer pattern
      (and (quote? pattern)
           (= (?. pattern 2 1 1) :buffer))
      (tset opts :buffer (or (?. pattern 2 2) 0))
      ; parse list of patterns
      (sequence? pattern)
      (tset opts :pattern (parse-list pattern))
      ; parse single pattern
      (tset opts :pattern (parse-sym pattern))))

(lambda parse-callback [opts cmd]
  (if (or (func? cmd) (quote? cmd))
      (tset opts :callback (parse-cmd cmd))
      (tset opts :command  cmd)))

(lambda autocmd [id [events pattern cmd]]
  "defines autocmd for group of 'id'."
  ; parse opts
  (local opts {:group id})
  (parse-pattern  opts pattern)
  (parse-callback opts cmd)
  ; parse events
  (local rem [])
  (each [i e (ipairs events)]
    (when (or= e :once :nested)
      (tset opts e true)
      (table.insert rem i))
    (when (= e :desc)
      (local desc (. events (inc! i)))
      (assert-compile (= :string (type desc))
        "  missing argument to desc option in augroup!." events)
      (tset opts :desc desc)
      (table.insert rem i)
      (table.insert rem (inc! i))))
  (local events (parse-list (list-remove events rem)))
  :return
  `(vim.api.nvim_create_autocmd ,events ,opts))

(lun augroup! [name ...]
  "defines augroup with 'name' and {...} containing [[groups] pat cmd] chunks."
  (check [:string name])
  ; define augroup
  (local id  (gensym :augid))
  (local out [])
  (table.insert out `(local ,id (vim.api.nvim_create_augroup ,name {:clear true})))
  ; define autocmds
  (each [_ au (ipairs [...])]
    (check [:seq (as autocmd au)])
    (table.insert out (autocmd id au)))
  :return
  (dolist out))


;; -------------------- ;;
;;       COMMANDS       ;;
;; -------------------- ;;
(lambda parse-command-args [args]
  "converts list of 'args' into table of valid command-opts."
  (local out {:force true})
  (each [idx val (ipairs args)]
    (if (odd? idx)
        (tset out val (. args (inc! idx)))))
  :return out)

(lun command! [args lhs rhs]
  "defines a user command from 'lhs' and 'rhs'."
  (check [:even (as args (# args))])
  `(vim.api.nvim_create_user_command ,lhs ,(parse-cmd rhs) ,(parse-command-args args)))


;; -------------------- ;;
;;       OPTIONS        ;;
;; -------------------- ;;
(lambda option-setter [method name ?val]
  "sets vim 'option' name on 'method'."
  (local name (parse-sym name))
  (if (not= nil ?val)
      `(tset ,method ,name ,?val)
      (string? name)
      (if (= :no (string.sub name 1 2))
          `(tset ,method ,(string.sub name 3) false)
          `(tset ,method ,name true))
      ; else compute at runtime
      `(if (= :no (string.sub ,name 1 2))
           (tset ,method (string.sub ,name 3) false)
           (tset ,method ,name true))))

(lun set! [name ?val]
  "sets vim option 'name'."
  (option-setter 'vim.opt name ?val))

(lun setlocal! [name ?val]
  "sets local vim option 'name'."
  (option-setter 'vim.opt_local name ?val))

(lun setglobal! [name ?val]
  "sets global vim option 'name' without changing the local value."
  (option-setter 'vim.opt_global name ?val))

(lun set+ [name val]
  "appends 'val' to vim option 'name'."
  `(: (. vim.opt ,(parse-sym name)) :append ,val))

(lun set^ [name val]
  "prepends 'val' to vim option 'name'."
  `(: (. vim.opt ,(parse-sym name)) :prepend ,val))

(lun rem! [name val]
  "removes 'val' from vim option 'name'."
  `(: (. vim.opt ,(parse-sym name)) :remove ,val))

(lun color! [name]
  "sets vim colorscheme to 'name'."
  (exec! [[:colorscheme (parse-sym name)]]))


;; -------------------- ;;
;;      VARIABLES       ;;
;; -------------------- ;;
(lun g! [name val]
  "sets global variable 'name' to 'val'."
  `(tset vim.g ,(parse-sym name) ,val))

(lun b! [name val]
  "sets buffer scoped variable 'name' to 'val'."
  `(tset vim.b ,(parse-sym name) ,val))


:return M
