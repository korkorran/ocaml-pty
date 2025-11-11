(* Déclarations des fonctions externes *)
external posix_openpt : unit -> Unix.file_descr = "ocaml_posix_openpt"
external grantpt : Unix.file_descr -> unit = "ocaml_grantpt"
external unlockpt : Unix.file_descr -> unit = "ocaml_unlockpt"
external ptsname : Unix.file_descr -> string = "ocaml_ptsname"
external get_fd_int : Unix.file_descr -> int = "ocaml_get_fd_int"

(* let () =
  let (master, slave_name) = create_pty () in
  Printf.printf "Maître (descripteur) : %d\n" (get_fd_int master);
  Unix.close master
*)
(* Fonction pour créer la paire maître/esclave 
let create_pty () =
  let master = posix_openpt () in
  grantpt master;
  unlockpt master;
  let slave_name = ptsname master in
  (master, slave_name) *)

(* Crée la paire maître/esclave *)
let create_pty () =
  let master = posix_openpt () in
  grantpt master;
  unlockpt master;
  let slave_name = ptsname master in
  (master, slave_name)

(* Fork et exécute une commande dans l'enfant *)
let fork_and_exec master slave_name command args =
  match Unix.fork () with
  | 0 -> (* Enfant *)
      let slave_fd = Unix.openfile slave_name [Unix.O_RDWR] 0o600 in
      Unix.dup2 slave_fd Unix.stdin;
      Unix.dup2 slave_fd Unix.stdout;
      Unix.dup2 slave_fd Unix.stderr;
      Unix.close slave_fd;
      Unix.close master;
      Unix.execvp command (Array.of_list (command :: args))
  | pid -> (* Parent *)
      pid

(* Lit la sortie du PTY *)
let read_pty master =
  let buf = Bytes.create 1024 in
  let n = Unix.read master buf 0 (Bytes.length buf) in
  Bytes.sub_string buf 0 n
