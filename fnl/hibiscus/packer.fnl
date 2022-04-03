(import-macros {: odd? : even?} :hibiscus.core)

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
       (tset _G :packer_bootstrap
             (vim.fn.system [:git :clone "--depth" "1" ,url ,path]))
       (vim.cmd :redraw)
       (print "packer.nvim: installed"))))

(fn M.packer-setup [opts]
  "bootstraps and setups config of packer with 'opts'."
  `(do ,(bootstrap)
       ((. (require :packer) :init) ,(or opts {}))))


;; -------------------- ;;
;;       STARTUP        ;;
;; -------------------- ;;
(lambda M.packer [...]
  "syntactic sugar over packer's startup function."
  (local packer `(require :packer))
  `((. ,packer :startup)
    (lambda [(unquote (sym :use))]
      (use :wbthomason/packer.nvim)
      (do ,...)
      (if _G.packer_bootstrap
          ((. ,packer :sync))))))


;; -------------------- ;;
;;         USE          ;;
;; -------------------- ;;
(lambda parse-conf [name opts]
  "parses 'name' and list of 'opts' into valid packer.use args."
  (assert (even? (# opts))
          (.. "packer-use: error in " name " opts must contain even number of key-value pairs."))
  (local out [name])
  (each [idx val (ipairs opts)]
    (local nval (. opts (+ idx 1)))
    (if (odd? idx)
        (match val
          :module (tset out :config `#(require ,nval))
          _       (tset out val nval))))
  :return out)


(lambda M.use! [name ...]
  "syntactic sugar over packer's use function."
  `(use ,(parse-conf name [...])))


:return M
