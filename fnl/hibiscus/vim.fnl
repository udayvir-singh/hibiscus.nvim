(require-macros :hibiscus.utils)
(require-macros :hibiscus.core)

(local M {})

;; -------------------- ;;
;;        UTILS         ;;
;; -------------------- ;;
(lambda func? [x]
  "checks if 'x' is function definition."
  (let [ref (?. x 1 1)]
    (or= ref :λ :fn :hashfn :lambda :partial)))

(lambda quote? [x]
  "checks if 'x' is quoted value."
  (if (table? x)
      (let [ref (?. x 1 1)]
        (= ref :quote))
      false))

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
  out)


;; -------------------- ;;
;;        CONCAT        ;;
;; -------------------- ;;
(lun concat! [sep ...]
  "smartly concats all strings in '...' with 'sep'."
  (check [:string sep])
  ; collect stack
  (local vargs [...])
  (local stack [])
  (each [i v (ipairs vargs)]
    (if (and (list? v) (= ".." (tostring (. v 1))))
        (each [_ v* (ipairs (do (table.remove v 1) v))]
          (table.insert stack v*))
        (table.insert stack v))
    (if (< i (length vargs))
        (table.insert stack sep)))
  ; generate body
  (local out [])
  (var cur "")
  (lambda push-cur []
    (if (not= "" cur)
        (table.insert out cur))
    (set cur ""))
  (each [_ v (ipairs stack)]
    (if (string? v)
        (append! cur v)
        (do (push-cur)
            (table.insert out v))))
  (push-cur)

  (if (= (length out) 1)
      (unpack out)
      (list `.. (unpack out))))


;; -------------------- ;;
;;         EXEC         ;;
;; -------------------- ;;
(lambda parse-exec [sep lst]
  (local out [])
  (each [_ x (ipairs lst)]
    (if (string? x)
        (table.insert out (.. "'" (x:gsub "'" "\\'") "'"))
        (quote? x)
        (table.insert out (. x 2))
        (list? x)
        (let [name (tostring (table.remove x 1))
              args (parse-exec "," x)]
          (table.insert out `(.. ,name "(" ,args ")")))
        (table.insert out (tostring x))))
  (concat! sep (unpack out)))

(lun exec! [command ...]
  "translates commands written in fennel to vim.cmd calls."
  (local commands [command ...])
  (local out  [])
  (each [_ cmd (ipairs commands)]
    (check [:fseq cmd])
    (local head (tostring (table.remove cmd 1)))
    (table.insert out
      `(vim.cmd ,(concat! " " head (parse-exec " " cmd)))))
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

    (values modes opts)))

(lun map! [args lhs rhs ?desc]
  "defines vim keymap for modes in 'args'."
  (check [:fseq   args
          :real   (as mode (. args 1))
          :string (as description (or ?desc ""))])
  (local (modes opts) (parse-map-args args))
  (set opts.desc ?desc)

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

  `(vim.api.nvim_create_autocmd ,events ,opts))

(lun augroup! [name ...]
  "defines augroup with 'name' and '...' containing [[groups] pat cmd] chunks."
  (check [:string name])
  ; define augroup
  (local id  (gensym :augid))
  (local out [])
  (table.insert out `(local ,id (vim.api.nvim_create_augroup ,name {:clear true})))
  ; define autocmds
  (each [_ au (ipairs [...])]
    (check [:fseq (as autocmd au)
            :fseq (as events (. au 1))
            :real (as pattern (. au 2))
            :real (as command (. au 3))])
    (table.insert out (autocmd id au)))

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
  out)

(lun command! [args lhs rhs]
  "defines a user command from 'lhs' and 'rhs'."
  (check [:even (as args (length args))])
  (local args (parse-command-args args))
  (if (= nil args.buffer)
    `(vim.api.nvim_create_user_command ,lhs ,(parse-cmd rhs) ,args)
    (let [buffer args.buffer]
      (set args.buffer nil)
      `(vim.api.nvim_buf_create_user_command ,buffer ,lhs ,(parse-cmd rhs) ,args))))


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
          (= :! (string.sub name -1 -1))
          `(tset ,method ,(string.sub name 1 -2) (not (. vim.o ,(string.sub name 1 -2))))
          `(tset ,method ,name true))
      ; else compute at runtime
      `(if (= :no (string.sub ,name 1 2))
           (tset ,method (string.sub ,name 3) false)
           (= :! (string.sub ,name -1 -1))
           (tset ,method (string.sub ,name 1 -2) (not (. vim.o (string.sub ,name 1 -2))))
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
  (check [:string name])
  `(vim.cmd ,(.. "colorscheme " name)))


;; -------------------- ;;
;;      VARIABLES       ;;
;; -------------------- ;;
(lun g! [name val]
  "sets global variable 'name' to 'val'."
  `(tset vim.g ,(parse-sym name) ,val))

(lun b! [name val]
  "sets buffer scoped variable 'name' to 'val'."
  `(tset vim.b ,(parse-sym name) ,val))


M
