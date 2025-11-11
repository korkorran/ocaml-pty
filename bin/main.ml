external posix_openpt : unit -> Unix.file_descr = "ocaml_posix_openpt"
external grantpt : Unix.file_descr -> unit = "ocaml_grantpt"
external unlockpt : Unix.file_descr -> unit = "ocaml_unlockpt"
external ptsname : Unix.file_descr -> string = "ocaml_ptsname"
(*external get_fd_int : Unix.file_descr -> int = "ocaml_get_fd_int"*)

open Lwt
open Lwt_unix

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


let rec interactive_loop master =
  Lwt_io.read_line Lwt_io.stdin >>= fun input ->
  let input_with_newline = input ^ "\n" in
  Lwt_cstruct.write master (Cstruct.of_string input_with_newline) >>= fun _ ->
  let buf = Bytes.create 1024 in
  let cstruct_buf = Cstruct.of_bytes buf in
  Lwt_cstruct.read master cstruct_buf >>= fun n ->
  if n > 0 then
    Lwt_io.write_from_exactly Lwt_io.stdout buf 0 n
  else
    Lwt.return_unit
  >>= fun () ->
  interactive_loop master

let () =
  let master = posix_openpt () in
  let slave_name = ptsname master in
  (* Configurer le PTY *)
  grantpt master;
  unlockpt master;
  (* Forker et exécuter le shell *)
  let pid = fork_and_exec master slave_name "/bin/zsh" ["-i"] in
  (* Attendre la fin de l'enfant en arrière-plan *)
  Lwt.async (fun () ->
    let _ = Unix.waitpid [] pid in
    Lwt.return_unit
  );
  (* Démarrer la boucle interactive *)
  Lwt_main.run (interactive_loop (of_unix_file_descr master))