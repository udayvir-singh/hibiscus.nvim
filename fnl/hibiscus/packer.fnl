(require-macros :hibiscus.utils)
(require-macros :hibiscus.core)

(local M {})

;; -------------------- ;;
;;        SETUP         ;;
;; -------------------- ;;
(lambda bootstrap []
  "installs packer in data dir if not already installed."
  (let [url  "https://github.com/wbthomason/packer.nvim"
        path (.. (vim.fn.stdpath :data) "/site/pack/packer/start/packer.nvim") ]
    `(when (= 0 (vim.fn.isdirectory ,path))
       (print "packer.nvim: installing in data dir...")
       (and (vim.fn.system [:git :clone "--depth" "1" ,url ,path])
            (tset _G :packer_bootstrap true))
       (vim.cmd :redraw)
       (vim.cmd "packadd packer.nvim")
       (print "packer.nvim: installed"))))

(fun packer-setup! [opts]
  "bootstraps and setups config of packer with 'opts'."
  `(do ,(bootstrap)
       ((. (require :packer) :init) ,(or opts {}))))


;; -------------------- ;;
;;       STARTUP        ;;
;; -------------------- ;;
(fun packer! [...]
  "syntactic sugar over packer's startup function."
  (local packer `(require :packer))
  `((. ,packer :startup)
    (lambda [(unquote (sym :use))]
      (use :wbthomason/packer.nvim)
      (do ,...)
      (if (= true _G.packer_bootstrap)
          ((. ,packer :sync))))))


;; -------------------- ;;
;;         USE          ;;
;; -------------------- ;;
(lambda parse-conf [name opts]
  "parses 'name' and list of 'opts' into valid packer.use args."
  (local __name__ "use!")
  (local out [name])
  ;; convert opts into table
  (each [idx val (ipairs opts)]
    (local next-val (. opts (+ idx 1)))
    (if (odd? idx)
        (tset out val next-val)))
  ;; parse require option
  (when out.require
    ; normalize opts
    (if (string? out.require)
        (set out.require [out.require]))
    (check [:seq (as require out.require)])
    ; create config handler
    (local handler
      (if (= 1 (length out.require))
          `(require ,(. out.require 1))
          `(each [# x# (ipairs ,out.require)] (require x#))))
    (set out.config
      `(fn [] ,handler ,(and out.config `(,out.config))))
    (set out.require nil))
  ;; parse depends option
  (when out.depends
    (if (not out.requires)
        (set out.requires []))
    (each [_ dep (ipairs out.depends)]
      (if (table? dep)
          (table.insert out.requires (parse-conf (table.remove dep 1) dep))
          (table.insert out.requires dep)))
    (set out.depends nil))
  out)

(lun use! [name ...]
  "syntactic sugar over packer's use function."
  (check [:string name
          :even   (as options (length [...]))])

  `(use ,(parse-conf name [...])))


M
