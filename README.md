# Hibiscus.nvim

> :hibiscus: Highly opinionated macros to elegantly write your neovim config.

Companion library for [tangerine](https://github.com/udayvir-singh/tangerine.nvim),
but it can also be used standalone.

<!-- ignore-line -->
![Neovim version](https://img.shields.io/badge/For_Neovim-0.8-dab?style=for-the-badge&logo=neovim&logoColor=dab)

## Rational

- :candy: Syntactic eye candy over hellscape of lua api
- :tanabata_tree: Provides missing features in both fennel and nvim api

# Installation

- Create file `plugin/0-tangerine.lua` to bootstrap hibiscus:

```lua
-- ~/.config/nvim/plugin/0-tangerine.lua

-- pick your plugin manager, default [standalone]
local pack = "tangerine" or "packer" or "paq"

local function bootstrap(url, ref)
	local name = url:gsub(".*/", "")
	local path = vim.fn.stdpath [[data]] .. "/site/pack/".. pack .. "/start/" .. name

	if vim.fn.isdirectory(path) == 0 then
		print(name .. ": installing in data dir...")

		vim.fn.system {"git", "clone", url, path}
		if ref then
			vim.fn.system {"git", "-C", path, "checkout", ref}
		end

		vim.cmd [[redraw]]
		print(name .. ": finished installing")
	end
end

-- for git head
bootstrap("https://github.com/udayvir-singh/hibiscus.nvim")

-- for stable version
bootstrap("https://github.com/udayvir-singh/hibiscus.nvim", "v1.5")
```

- Require a macro library at top of your modules:

```fennel
; require all macros
(require-macros :hibiscus.core)
(require-macros :hibiscus.vim)

; require specific macros (you can also rename them)
(import-macros {:fstring! f!} :hibiscus.core)
(import-macros {: map!}    :hibiscus.vim)
```

:tada: now start using these macros in your config

---

### Packer

You can use packer to manage hibiscus afterwards [use this if you haven't used `ref` option in bootstrap]:

```fennel
(require-macros :hibiscus.packer)

(packer-setup!)

(packer!
  (use! :udayvir-singh/hibiscus.nvim))
```

### Paq

```fennel
(local paq (require :paq))

(paq {
  :udayvir-singh/hibiscus.nvim
})
```

# Packer Macros

```fennel
(require-macros :hibiscus.packer)
```

#### packer-setup!

<pre lang="fennel"><code>(packer-setup! {opts?})
</pre></code>

Bootstraps packer and calls packer.init function with {opts?}.

#### packer!

<pre lang="fennel"><code>(packer! {...})
</pre></code>

Wrapper around packer.startup function, automatically adds packer to plugin list and syncs it.

#### use!

<pre lang="fennel"><code>(use! {name} {...opts})
</pre></code>

Much more lisp friendly wrapper over `packer.use` function.

##### Extra Options:

- `require` -- wrapper around `config`, loads string or list of module names.
- `depends` -- wrapper around `requires`, configures plugin dependencies with lisp friendly syntax.

##### Examples:

```fennel
(packer!
  (use! :udayvir-singh/hibiscus.nvim)

  (use! :plugin-foo
        :require ["path.mod1" "path.mod2"]) ; automatically requires these modules

  (use! :plugin-baz
        :depends [  ; define dependencies in same syntax as use!
          "example1"
          ["example2" :after "hibiscus.nvim" :require "xyz"]
        ]))
```

# Neovim Macros

```fennel
(require-macros :hibiscus.vim)
; or
(import-macros {: augroup!} :hibiscus.vim)
```

## keymaps

#### map!

<pre lang="fennel"><code>(map! {args} {lhs} {rhs} {desc?})
</pre></code>

Defines vim keymap for the given modes from {lhs} to {rhs}.

##### Arguments:

{args} can contain the following values:

```fennel
; modes |                   options                           |
[ nivcx  :remap :verbose :buffer :nowait :expr :unique :script ]
```

- `verbose`: opposite to `silent`
- `remap`: opposite to `noremap`

##### Examples:

```fennel
;; -------------------- ;;
;;      VIMSCRIPT       ;;
;; -------------------- ;;
(map! [n :buffer] :R "echo &rtp")
(map! [n :remap]  :P "<Plug>(some-function)")


;; -------------------- ;;
;;        FENNEL        ;;
;; -------------------- ;;
(map! [nv :expr] :j
      '(if (> vim.v.count 0) "j" "gj"))

(local greet #(print "Hello World!"))

(map! [n] :gH 'greet ; optionally quote to explicitly indicate a function
      "greets the world!")
```

## autocmds

#### augroup!

<pre lang="fennel"><code>(augroup! {name} {cmds})
</pre></code>

Defines autocmd group of {name} with {cmds} containing [args pattern cmd] chunks.

##### Arguments:

{args} can contain the following values:

```fennel
[ :nested :once :desc <desc> BufRead Filetype ...etc ]
```

##### Examples:

```fennel
;; -------------------- ;;
;;      VIMSCRIPT       ;;
;; -------------------- ;;
(augroup! :spell
  [[FileType] [markdown gitcommit] "setlocal spell"])

(augroup! :MkView
  [[BufWinLeave
    BufLeave
    BufWritePost
    BufHidden
    QuitPre :nested] ?* "silent! mkview!"]
  [[BufWinEnter] ?* "silent! loadview"])

(augroup! :buffer-local
  [[Event] '(buffer 0) "echo 'hello'"])


;; -------------------- ;;
;;        FENNEL        ;;
;; -------------------- ;;
(augroup! :highlight-yank
  [[TextYankPost :desc "highlights yanked region."]
   * #(vim.highlight.on_yank {:timeout 80})])

(local greet #(print "Hello World!"))

(augroup! :greet
  [[BufRead] *.sh '(print :HOLLA)]
  [[BufRead] *    'hello] ; remember to quote functions to indicate they are callbacks
```

## commands

#### command!

<pre lang="fennel"><code>(command! {args} {lhs} {rhs})
</pre></code>

Defines user command {lhs} to {rhs}.

##### Arguments:

{args} can contain the same opts as `nvim_create_user_command`:

```fennel
[
  :bar      <boolean>
  :bang     <boolean>
  :buffer   <boolean>
  :register <boolean>
  :range    (or <boolean> <string>)
  :addr     <string>
  :count    <string>
  :nargs    <string>
  :complete (or <string> <function>)
]
```

##### Examples:

```fennel
;; -------------------- ;;
;;      VIMSCRIPT       ;;
;; -------------------- ;;
(command! [:range "%"] :Strip "<line1>,<line2>s: \\+$::e")


;; -------------------- ;;
;;        FENNEL        ;;
;; -------------------- ;;
(fn greet [opts]
  (print :hello opts.args))

(command! [:nargs 1 :complete #["world"]] :Greet 'greet) ; quoting is optional in command! macro

(command! [:bang true] :Lhs #(print $.bang))
```

## misc

#### exec!

<pre lang="fennel"><code>(exec! {...})
</pre></code>

Converts function calls in {...} to valid `vim.cmd` calls.

##### Example:

```fennel
(exec!
  (set "nowrap")
  (hi! "link" "TSInclude" "Special"))
```

#### concat!

<pre lang="fennel"><code>(concat! {list} {sep})
</pre></code>

Concats strings in {list} with {sep} at compile time.

##### Examples:

```fennel
(concat! ["hello" "foo"] " ") ; -> "hello foo"

(concat! ["hello" "foo" var] " ") ; -> "hello foo" .. " " .. var
```

## vim options

#### set!

Works like command `:set`, sets vim option {name}.

```fennel
(set! nobackup)
(set! tabstop 4)

(each [_ opt (ipairs ["number" "rnu"])]
      (set! opt true))
```

#### setlocal!

Works like command `:setlocal`, sets local vim option {name}.

```fennel
(setlocal! filetype "md")
(setlocal! number)
```

#### setglobal!

Works like command `:setglobal`, sets global vim option {name} without changing the local value.

```fennel
(setglobal! wrap)
```

#### set+

Appends {val} to string-style option {name}.

```fennel
(set+ wildignore "*.foo")
```

#### set^

Prepends {val} to string-style option {name}.

```fennel
(set^ wildignore ["*.foo" "*.baz"])
```

#### rem!

Removes {val} from string-style option {name}.

```fennel
(rem! wildignore "*.baz")
```

#### color!

Sets vim colorscheme to {name}.

```fennel
(color! desert)
```

## variables

#### g!

Sets global variable {name} to {val}.

```fennel
(g! mapleader " ")
```

#### b!

Sets buffer scoped variable {name} to {val}.

```fennel
(b! gretting "Hello World!")
```

# Core Macros

```fennel
(require-macros :hibiscus.core)
; or
(import-macros {: fstring} :hibiscus.core)
```

## OOP

## class!

<pre lang="fennel"><code>(class! {name} {...})
</pre></code>

Defines a new class (object-oriented programming) with {name}.

An `init` method must be present in all classes and it should return the base table for class.

To create a instance of class, call `new` method on {name}.

##### Examples:

```fennel
;; -------------------- ;;
;;   DEFINING CLASSES   ;;
;; -------------------- ;;
(class! stack
  (method! init [list] list) ; arguments of new method are passed here

  (method! push [val]
    "inserts {val} into the stack."
    (table.insert self val)) ; self variable is accessible from all methods

  (metamethod! __tostring []
    "converts stack into a string."
    (table.concat self " ")))

(class! stack-stream
  (local state {:cursor 0})

  (method! init [stack]
    (set state.len (# stack)) ; private state
    {: stack})                ; public state

  (method! next []
    "returns next item from stream."
    (++ state.cursor)
    (assert (<= state.cursor state.len)
            "stack-stream: attempt to call next() on empty stream.")
    (. self.stack state.cursor)))


;; -------------------- ;;
;;         DEMO         ;;
;; -------------------- ;;
(local st (stack:new [:a :b])) ; new method should be called to create a instance
(st:push :c)
(print (tostring st)) ; > "a b c"

(local stream (stack-stream:new st))
(print (stream:next)) ; > "a"
(print (stream:next)) ; > "b"
```

#### method!

<pre lang="fennel"><code>(method! {name} {args} {...})
</pre></code>

Defines a method within the scope of class.

The `self` variable is accessible from the scope of every method.

##### Example:

```fennel
(class! foo
  (method! init [] {}) ; required for all classes

  (method! hello []
    (print "hello world!")))
```

#### metamethod!

<pre lang="fennel"><code>(metamethod! {name} {args} {...})
</pre></code>

Defines a metamethod within the scope of class.

The `self` variable is accessible from the scope of every metamethod.

See lua docs for list of valid metamethods.

##### Example:

```fennel
(class! foo
  (method! init [] {}) ; required for all classes

  (metamethod! __tostring []
    "example_string"))
```

#### instanceof?

<pre lang="fennel"><code>(instanceof? {val} {class})
</pre></code>

Checks if {val} is an instance of {class}.

##### Example:

```fennel
(class! foo
  (method! init [] {}))

(local x (foo:new))

(instanceof? x foo)  ; > true
(instanceof? {} foo) ; > false
```

## general

#### dump!

<pre lang="fennel"><code>(dump! {...})
</pre></code>

Pretty prints {...} into human readable form.

#### or=

<pre lang="fennel"><code>(or= {x} {...})
</pre></code>

Checks if {x} is equal to any one of {...}.

#### fstring!

<pre lang="fennel"><code>(fstring! {str})
</pre></code>

Wrapper around string.format, works like javascript's template literates.

- `${...}` is parsed as variable
- `$(...)` is parsed as fennel code

##### Examples:

```fennel
(local name "foo")
(fstring! "hello ${name}")

(fstring! "${name}: two + four is $(+ 2 4).")
```

#### enum!

<pre lang="fennel"><code>(enum! {name} ...)
</pre></code>

Defines enumerated values for names.

##### Example:

```fennel
(enum! A B C) ; A=1, B=2, C=3
```

#### time!

<pre lang="fennel"><code>(time! {label} ...)
</pre></code>

Prints execution time of {...} in milliseconds.

##### Example:

```fennel
(time! :add
  (+ 1 2)) ; add: [XXX]ms
```

## checking values

```fennel
(nil? {x})
```

> checks if value of {x} is nil.

```fennel
(empty? {x})
```

> checks if {x} :: [string or table] is empty.

```fennel
(boolean? {x})
```

> checks if {x} is of boolean type.

```fennel
(string? {x})
```

> checks if {x} is of string type.

```fennel
(number? {x})
```

> checks if {x} is of number type.

```fennel
(odd? {int})
```

> checks if {int} is of odd parity.

```fennel
(even? {int})
```

> checks if {int} is of even parity.

```fennel
(fn? {x})
```

> checks if {x} is of function type.

```fennel
(table? {x})
```

> checks if {x} is of table type.

```fennel
(seq? {tbl})
```

> checks if {tbl} is valid list / array.

## number

```fennel
(inc! {int})
```

> increments {int} by 1 and returns its value.

```fennel
(++ {var})
```

> increments variable {var} by 1 and returns its value.

```fennel
(dec! {int})
```

> decrements {int} by 1 and returns its value.

```fennel
(-- {var})
```

> decrements variable {var} by 1 and returns its value.

## string

```fennel
(append! {var} {str})
```

> appends {str} to variable {var}.

```fennel
(tappend! {tbl} {key} {str})
```

> appends {str} to {key} of table {tbl}.

```fennel
(prepend! {var} {str})
```

> prepends {str} to variable {var}.

```fennel
(tprepend! {tbl} {key} {str})
```

> prepends {str} to {key} of table {tbl}.

```fennel
(split! {str} {sep})
```

> splits {str} into a list at each {sep}.

## table

```fennel
(tmap! {tbl} {handler})
```

> maps values in {tbl} with {handler}.
>
> {handler} takes in (key, val) and returns a new value.

```fennel
(filter! {list} {handler})
```

> filters values in {list} with {handler}.
>
> {handler} takes in (val) and returns a boolean.

```fennel
(merge-list! {list1} {list2})
```

> merges all values of {list1} and {list2} together, and returns a new list.

```fennel
(merge-tbl! {tbl1} {tbl2})
```

> merges {tbl2} onto {tbl1}, and returns a new table.

```fennel
(merge! {tbl1} {tbl2})
```

> merges {tbl1} and {tbl2}, correctly appending lists.

```fennel
(vmerge! {var} {tbl})
```

> merges values of {tbl} onto variable {var}.

# End Credits

- [aniseed](https://github.com/Olical/aniseed): for introducing me to fennel
- [zest](https://github.com/tsbohc/zest.nvim): for inspiring `hibiscus.vim` macros
