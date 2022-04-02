# Hibiscus.nvim
> :hibiscus: Highly opinionated macros to elegantly write your neovim config.

Companion library for [tangerine](https://github.com/udayvir-singh/tangerine.nvim),
but it can also be used standalone.

## Rational
- :candy: Syntactic eye candy over hellscape of lua api
- :tanabata_tree: Provides missing features in both fennel and nvim api

# Installation
1. Create file `plugin/tangerine.lua` to bootstrap hibiscus:
```lua
-- ~/.config/nvim/plugin/tangerine.lua

-- pick your plugin manager, default [standalone]
local pack = "tangerine" or "packer" or "paq"

local function bootstrap (name, url, path)
	if vim.fn.empty(vim.fn.glob(path)) > 0 then
		print(name .. ": installing in data dir...")

		vim.fn.system {"git", "clone", url, path}

		vim.cmd [[redraw]]
		print(name .. ": finished installing")
	end
end

bootstrap (
	"hibiscus.nvim",
	"https://github.com/udayvir-singh/hibiscus.nvim",
	vim.fn.stdpath [[data]] .. "/site/pack/" .. pack .. "/start/hibiscus.nvim"
)
```

2. Call the `setup()` function:
```lua
-- NOTE: require before calling tangerine or your compiler

require [[hibiscus]].setup()
```

3. Require a macro library at top of your modules:
```fennel
; require all macros
(require-macros :hibiscus.core)
(require-macros :hibiscus.vim)

; require selected macros
(import-macros {: fstring} :hibiscus.core)
(import-macros {: map!}    :hibiscus.vim)
```

DONE: now start using these macros in your config

---

#### Packer
You can use packer to manage hibiscus afterwards:

```fennel
(local packer (require :packer))

(packer.startup (fn []
	(use :udayvir-singh/hibiscus.nvim)))
```

#### Paq
```fennel
(local paq (require :paq))

(paq {
	:udayvir-singh/hibiscus.nvim
})
```

# Neovim Macros
```fennel
(require-macros :hibiscus.vim)
; or
(import-macros {: augroup!} :hibiscus.vim)
```

## keymaps
#### map!
<pre lang="clojure"><code>(map! {args} {lhs} {rhs})
</pre></code>

Defines vim keymap for the given modes from {lhs} to {rhs}

##### Arguments:
{args} can contain the following values:
```clojure
; modes |                   options                           |
[ nivcx  :remap :verbose :buffer :nowait :expr :unique :script ]
```

NOTE:
- `verbose`: opposite to `silent`
- `remap`: opposite to `noremap`

##### Examples:
- For Vimscript:
```clojure
(map! [n :buffer] :R "echo &rtp")

(let [rhs ":echo hello"]
  (map! [nv :nowait] :lhs rhs))
```

- For Fennel Functions:
```clojure
(map! [nv :expr] :j
      '(if (> vim.v.count 0) "j" "gj"))

(fn greet []
  (print "Hello World!"))

(map! [n] :lhs 'greet) ; variables need to be quoted to indicate they are function

(map! [n] :lhs #(print "inline functions don't require quoting"))

```

## autocmds
#### augroup!
<pre lang="clojure"><code>(augroup! {name} {cmds})
</pre></code>

Defines autocmd group of {name} with {cmds} containing [groups pattern cmd] chunks.

##### Examples:
- For Vimscript:
```clojure
(local clj "clojure")

(augroup! :greet
  [[FileType]           clj           "echo hello"]
  [[BufRead BufNewFile] [*.clj *.fnl] "echo hello"])
```

- For Fennel Functions:
```clojure
(fn hello [] (print :hello))

(augroup! :greet
  [[BufRead] * 'hello] ; remember to quote functions
  [[BufRead] * #(print "HOLLA!")])
```

## commands
#### command!
<pre lang="clojure"><code>(command! {args} {lhs} {rhs})
</pre></code>

Defines user command {lhs} to {rhs}

##### Arguments:
{args} can contain the same opts as `:command`:
```fennel
[
  :bar      true
  :bang     true
  :buffer   true
  :register true
  :range    (or true <string>)
  :addr     <string>
  :count    <string>
  :nargs    <string>
  :complete <string>
]
```

##### RHS Parameters:
`:command` parameters like `<bang>` are translated by hibiscus into following table:
```fennel
{
  :bang  <boolean>
  :qargs <string>
  :count <number>
  :lines [<number> <number>]
}
```
They are passed as first argument to lua function, For example:
```clojure
(fn example [opts]
  (print opts.qargs))

(command! [:nargs "*"] :Lhs 'example)
```

##### Examples:
- For Vimscript:
```clojure
(command! [:nargs 1] :Lhs "echo 'hello ' . <q-args>")
```

- For Fennel Functions:
```clojure
(fn greet [opts]
  (print :hello opts.qargs))

(command! [:nargs 1] :Lhs 'greet) ; again remember to quote 

(command! [:bang true] :Lhs '(print opts.bang))
; or
(command! [:bang true] :Lhs (fn [opts] (print opts.bang)))
```

## misc
#### vlua
<pre lang="clojure"><code>(vlua {func})
</pre></code>

Wraps fennel {func} into valid vimscript cmd

##### Example:
```clojure
(local cmd (vlua some-func))

(print cmd) ; -> ":lua _G.hibiscus.store.func()"
```

#### exec
<pre lang="clojure"><code>(exec {cmds})
</pre></code>

Converts [cmd] chunks in {cmds} to valid vim.cmd call

##### Example:
```clojure
(exec [
  [:set "nowrap"]
  [:echo "hello" "world"]
])
```

#### concat
<pre lang="clojure"><code>(concat {list} {sep})
</pre></code>

Concats strings in {list} with {sep} at compile time

##### Examples:
```clojure
(concat ["hello" "foo"] " ") ; -> "hello foo"

(concat ["hello" "foo" var] " ") ; -> "hello foo" .. " " .. var
```

## vim options
#### set!
Works like command `:set`, sets vim option {name} to {val}
```clojure
(set! nobackup)
(set! tabstop 4)

(each [_ opt (ipairs ["number" "rnu"])]
      (set! opt true))
```

#### set+
Appends {val} to string-style option {name}

```clojure
(set+ wildignore "*.foo")
```

#### set^
Prepends {val} to string-style option {name}
```clojure
(set^ wildignore ["*.foo" "*.baz"])
```

#### rem!
Removes {val} from string-style option {name}

```clojure
(rem! wildignore "*.baz")
```

#### color!
Sets vim colorscheme to {name}

```clojure
(color! desert)
```

## variables
#### g!
Sets global variable {name} to {val}.

```clojure
(g! mapleader " ")
```

#### b!
Sets buffer scoped variable {name} to {val}.

```clojure
(b! gretting "Hello World!")
```

# Core Macros
```fennel
(require-macros :hibiscus.core)
; or
(import-macros {: fstring} :hibiscus.core)
```

## fstring
```clojure
(fstring {str})
```
> wrapper around string.format, works like javascript's template literates

##### Example:
```clojure
(let [name "foo"]
  (fstring "hello ${name}"))
```

## pretty print
```clojure
(dump {...})
```
> pretty prints {...} into human readable form

## general
```clojure
(or= {x} ...)
```
> checks if {x} is equal to any one of {...}

## checking
```clojure
(nil? {x})
```
> checks if value of {x} is nil

```clojure
(boolean? {x})
```
> checks if {x} is of boolean type

```clojure
(string? {x})
```
> checks if {x} is of string type

```clojure
(number? {x})
```
> checks if {x} is of number type

```clojure
(odd? {int})
```
> checks if {int} is of odd parity

```clojure
(even? {int})
```
> checks if {int} is of even parity

```clojure
(function? {x})
```
> checks if {x} is of function type

```clojure
(table? {x})
```
> checks if {x} is of table type

```clojure
(list? {tbl})
```
> checks if {tbl} is valid list / array

```clojure
(empty? {tbl})
```
> checks if {tbl} has length of 0

## unary operators
```clojure
(inc {int})
```
> increments {int} by 1 and returns its value

```clojure
(++ {var})
```
> increments variable {var} by 1 and returns its value

```clojure
(dec {int})
```
> decrements {int} by 1 and returns its value

```clojure
(-- {var})
```
> decrements variable {var} by 1 and returns its value

## string concat
```clojure
(append {var} {str})
```
> appends {str} to variable {var}

```clojure
(tappend {tbl} {key} {str})
```
> appends {str} to {key} of table {tbl}

```clojure
(prepend {var} {str})
```
> prepends {str} to variable {var}

```clojure
(tprepend {tbl} {key} {str})
```
> prepends {str} to {key} of table {tbl}

## table merging
```clojure
(merge-list {list1} {list2})
```
> merges all values of {list1} and {list2} together.

```clojure
(merge {tbl1} {tbl2})
```
> merges {tbl1} and {tbl2}, correctly appending lists

```clojure
(merge! {var} {tbl})
```
> merges values of {tbl} onto variable {var}

# End Credits
- [aniseed](https://github.com/Olical/aniseed): for introducing me to fennel
- [zest](https://github.com/tsbohc/zest.nvim): for inspiring `hibiscus.vim` macros
