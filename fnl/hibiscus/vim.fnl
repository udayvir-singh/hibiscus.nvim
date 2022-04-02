(import-macros {
  : ++
  : or=
  : string?
  : odd?
  : even?
  : append
  : tappend
  : fstring
} :hibiscus.core)

(local M {})

;; -------------------- ;;
;;        UTILS         ;;
;; -------------------- ;;
(macro lmd [name ...]
  "defines lambda function 'name' and exports it to M."
  `(tset M ,(tostring name) (lambda ,name ,...)))

(lambda dolist [lst]
  "unpacks 'lst' and wrap it within do block."
  `(do ,(unpack lst)))

(lambda parse-sym [xs]
  "parses symbol 'xs' converts it to string if not a variable."
  (if (or (in-scope? xs) (list? xs)) 
      (do xs)
      (tostring xs)))


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
;;         VLUA         ;;
;; -------------------- ;;
(lambda func? [x]
  "checks if 'x' is function definition."
  (let [ref (?. x 1 1)]
    (or= ref :fn :hashfn :lambda :partial)))

(lambda quote? [x]
  "checks if 'x' is quoted value."
  (let [ref (?. x 1 1)]
    (= ref :quote)))

(lambda unquote- [x]
  "unquotes 'x' wrapping it within a function if required."
  (local ref (. x 2))
  (if (list? ref) 
      (quote (fn [,(sym :opts)] ,ref))
      (do ref)))

(lambda gen-id []
  "generates random id for vlua functions."
  (string.gsub "func_xxxxxxxx" "x"
               #(string.format "%x" (math.random 16))))

(lambda vlua [func args ?expr]
  "wraps lua 'func' into valid vim cmd, returns (pre cmd) chunks."
  (local id   (gen-id))
  (local call (if ?expr "v:lua." ":lua "))
  (values
    (list `tset `_G.hibiscus.store id func)
    (fstring "${call}_G.hibiscus.store.${id}${args}")))

(lambda parse-cmd [xs ...]
  "parses command 'xs', wrapping it with vlua if required."
  (if (func?  xs) (vlua ...)
      (quote? xs) (vlua (unquote- xs) ...)
      :else
      (values nil xs)))

(lambda M.vlua [func ?args]
  "wraps vlua's return value in do block for user."
  `(do ,(vlua func (.. "(" (or ?args "") ")"))))


;; -------------------- ;;
;;       MAPPINGS       ;;
;; -------------------- ;;
(lambda parse-map-args [args]
  "parses map 'args' into (modes opts buf) chunk."
  (assert (. args 1) 
          "map: missing required argument 'mode'.")
  (let [modes (tostring (table.remove args 1))
        opts  {:noremap true :silent true}]
    (var buf false)
    (each [_ key (ipairs args)]
      (match key
        :buffer  (set buf true)
        :remap   (tset opts :noremap false)
        :verbose (tset opts :silent false)
        _        (tset opts key true)))
    :return
    {: modes : opts : buf}))

(lmd map! [args lhs rhs]
  "defines vim keymap for modes in 'args'."
  (local out [])
  (let [(pre cmd) (if (vim.tbl_contains args :expr) (parse-cmd rhs "()" true) (parse-cmd rhs "()<CR>"))
        args      (parse-map-args args)]
    (table.insert out pre)
    :mapping
    (each [mode (string.gmatch args.modes ".")]
      (table.insert out
        (if args.buf
            (list `vim.api.nvim_buf_set_keymap 0 mode lhs cmd args.opts)
            (list `vim.api.nvim_set_keymap       mode lhs cmd args.opts))))
    :return
    (dolist out)))


;; -------------------- ;;
;;       AUTOCMDS       ;;
;; -------------------- ;;
(lambda parse-pat [pat]
  "parses augroup pattern 'pat' into a valid string."
  (if (sequence? pat)
      (concat (vim.tbl_map parse-sym pat) ",")
      (parse-sym pat)))

(lambda parse-autocmd [[groups pattern cmd]]
  "converts given args into valid autocmd command."
  (let [groups    (table.concat (vim.tbl_map tostring groups) ",")
        pattern   (parse-pat pattern)
        (pre cmd) (parse-cmd cmd "()")]
    :return
    (values pre [:au groups pattern cmd])))

(lmd augroup! [name ...]
  "defines augroup with 'name' and {...} containing [[groups] pat cmd] chunks."
  (local setup [])
  (local cmds [
    [:augroup name]
    [:au!]
    [:augroup "END"]
  ])
  :autocmd
  (each [_ au (ipairs [...])]
    (local (pre cmd) (parse-autocmd au))
    (table.insert setup pre)
    (table.insert cmds (# cmds) cmd))
  :return
  (list `do
    (dolist setup)
    (exec cmds)))


;; -------------------- ;;
;;       COMMANDS       ;;
;; -------------------- ;;
(local cmd-opts 
  "{
     bang  = ('<bang>' == '!'),
     lines = {<line1>, <line2>},
     count = <count>,
     qargs = <q-args>
  }"
)

(lambda parse-command-args [args]
  "converts list of 'args' into string of valid command-opts."
  (assert (even? (# args))
          "command: expected even number of values in args.")
  (var out "")
  (each [idx val (ipairs args)]
    (if 
      ; parse keys
      (odd? idx)
      (append out (.. "-" val))
      ; parse values
      (= true val)
      (append out " ")
      :else
      (append out (.. "=" val " "))))  
  :return out)

(lmd command! [args lhs rhs]
  "defines a user command from 'lhs' and 'rhs'."
  (let [(pre cmd) (parse-cmd rhs (cmd-opts:gsub "\n +" " ") false)
        options   (parse-command-args args)]
    :return
    `(do ,pre ,(exec [[:command! options lhs cmd]]))))


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
      ; else do at runtime
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
