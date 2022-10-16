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

(fn M.packer-setup [opts]
  "bootstraps and setups config of packer with 'opts'."
  `(do ,(bootstrap)
       ((. (require :packer) :init) ,(or opts {}))))


;; -------------------- ;;
;;       STARTUP        ;;
;; -------------------- ;;
(fn M.packer [...]
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
  (local out [name])
  (each [idx val (ipairs opts)]
    (local next-val (. opts (+ idx 1)))
    (if (odd? idx)
        (tset out val next-val)))
  ; parse module option
  (when out.module
    (tset out :config `(fn [] (require ,out.module) ,(and out.config `(,out.config))))
    (tset out :module nil))
  :return out)

(lambda M.use! [name ...]
  "syntactic sugar over packer's use function."
  (assert-compile
    (string? name)
    (.. "  packer-use: invalid name " (view name)) name)
  (assert-compile
    (even? (# [...]))
    (.. "  packer-use: error in :" name ", opts must contain even number of key-value pairs."))
  :return
  `(use ,(parse-conf name [...])))


:return M
