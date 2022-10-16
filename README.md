# Hibiscus.nvim
> :hibiscus: Highly opinionated macros to elegantly write your neovim config.

Companion library for [tangerine](https://github.com/udayvir-singh/tangerine.nvim),
but it can also be used standalone.

<!-- ignore-line -->
![Neovim version](https://img.shields.io/badge/For_Neovim-0.7-dab?style=for-the-badge&logo=neovim&logoColor=dab)

## Rational
- :candy: Syntactic eye candy over hellscape of lua api
- :tanabata_tree: Provides missing features in both fennel and nvim api

# Installation
- Create file `plugin/1-tangerine.lua` to bootstrap hibiscus:
```lua
-- ~/.config/nvim/plugin/tangerine.lua

-- pick your plugin manager, default [standalone]
local pack = "tangerine" or "packer" or "paq"

local function bootstrap (url)
	local name = url:gsub(".*/", "")
	local path = vim.fn.stdpath [[data]] .. "/site/pack/".. pack .. "/start/" .. name

	if vim.fn.isdirectory(path) == 0 then
		print(name .. ": installing in data dir...")

		vim.fn.system {"git", "clone", "--depth", "1", url, path}

		vim.cmd [[redraw]]
		print(name .. ": finished installing")
	end
end

bootstrap "https://github.com/udayvir-singh/hibiscus.nvim"
```

- Require a macro library at top of your modules:
```fennel
; require all macros
(require-macros :hibiscus.core)
(require-macros :hibiscus.vim)

; require selected macros
(import-macros {: fstring} :hibiscus.core)
(import-macros {: map!}    :hibiscus.vim)
```

:tada: now start using these macros in your config

---

#### Packer
You can use packer to manage hibiscus afterwards:

```fennel
(require-macros :hibiscus.packer)

(packer-setup)

(packer
  (use! :udayvir-singh/hibiscus.nvim))
```

#### Paq
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

#### packer-setup
<pre lang="clojure"><code>(packer-setup {opts?})
</pre></code>

Bootstraps packer and calls packer.init function with {opts?}.

#### packer
<pre lang="clojure"><code>(packer {...})
</pre></code>

Wrapper around packer.startup function, automatically adds packer to plugin list and syncs it.

#### use!
<pre lang="clojure"><code>(use! {name} {...})
</pre></code>

Much more lisp friendly wrapper over packer.use function.

##### Examples:
```clojure
(packer
  (use! :udayvir-singh/tangerine.nvim)

  (use! :udayvir-singh/hibiscus.nvim
        :requires ["udayvir-singh/tangerine.nvim"])

  (use! :some-plugin
        :module "path/module" ; automatically requires that module
        ...))
```

# Neovim Macros
```fennel
(require-macros :hibiscus.vim)
; or
(import-macros {: augroup!} :hibiscus.vim)
```

## keymaps
#### map!
<pre lang="clojure"><code>(map! {args} {lhs} {rhs} {desc?})
</pre></code>

Defines vim keymap for the given modes from {lhs} to {rhs}

##### Arguments:
{args} can contain the following values:
```clojure
; modes |                   options                           |
[ nivcx  :remap :verbose :buffer :nowait :expr :unique :script ]
```

- `verbose`: opposite to `silent`
- `remap`: opposite to `noremap`

##### Examples:
```clojure
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
<pre lang="clojure"><code>(augroup! {name} {cmds})
</pre></code>

Defines autocmd group of {name} with {cmds} containing [args pattern cmd] chunks

##### Arguments:
{args} can contain the following values:
```clojure
[ :nested :once :desc <desc> BufRead Filetype ...etc ]
```


##### Examples:
```clojure
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
<pre lang="clojure"><code>(command! {args} {lhs} {rhs})
</pre></code>

Defines user command {lhs} to {rhs}

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
```clojure
;; -------------------- ;;
;;      VIMSCRIPT       ;;
;; -------------------- ;;
(command! [:range "%"] :Strip "<line1>,<line2>s: \\+$::e")


;; -------------------- ;;
;;        FENNEL        ;;
;; -------------------- ;;
(fn greet [opts]
  (print :hello opts.args))

(command! [:nargs 1 :complete #["world"]] :Greet 'greet) ; quoting is optional

(command! [:bang true] :Lhs #(print $.bang))
```

## misc
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
Works like command `:set`, sets vim option {name}

```clojure
(set! nobackup)
(set! tabstop 4)

(each [_ opt (ipairs ["number" "rnu"])]
      (set! opt true))
```

#### setlocal!
Works like command `:setlocal`, sets local vim option {name}

```clojure
(setlocal! filetype "md")
(setlocal! number)
```

#### setglobal!
Works like command `:setglobal`, sets only the global vim option {name} without changing the local value

```clojure
(setglobal! wrap)
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

- `${...}` is parsed as variable
- `$(...)` is parsed as fennel code

##### Examples:
```clojure
(local name "foo")
(fstring "hello ${name}")

(fstring "${name}: two + four is $(+ 2 4).")
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

## checking values
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
(fn? {x})
```
> checks if {x} is of function type

```clojure
(table? {x})
```
> checks if {x} is of table type

```clojure
(seq? {tbl})
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
> merges all values of {list1} and {list2} together

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
