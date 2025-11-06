let () = print_endline "Hello, World!"

(*
let file_descr_to_int fd = Obj.magic fd


let () =
  let (master, slave_name) = Ocaml_pty.Pty.create_pty () in
  Printf.printf "Maître : %d\n" (file_descr_to_int master);
  Printf.printf "Esclave : %s\n" slave_name;
  (* Ferme le descripteur du maître quand tu as fini *)
  Unix.close master *)


(* Lit toute la sortie du PTY jusqu'à ce qu'il soit fermé *)
let read_all_from_pty master =
  let buf = Bytes.create 1024 in
  let output = Buffer.create 16 in
  let rec loop () =
    try
      let n = Unix.read master buf 0 (Bytes.length buf) in
      if n > 0 then (
        Buffer.add_subbytes output buf 0 n;
        loop ()
      )
    with Unix.Unix_error (Unix.EBADF, _, _) -> () (* PTY fermé *)
  in
  loop ();
  Buffer.contents output

(* Exemple : Exécuter "ls -l"
let () =
  let (master, slave_name) = Ocaml_pty.Pty.create_pty () in
  let _ = Ocaml_pty.Pty.fork_and_exec master slave_name "ls" ["-l"] in
  (* Attendre la fin de la commande et lire la sortie *)
  let output = Ocaml_pty.Pty.read_pty master in
  Printf.printf "Sortie de 'ls -l' :\n%s\n" output;
  Unix.close master *)

(* Exemple : Exécuter "ls -l" et lire toute la sortie *)
let () =
  let (master, slave_name) = Ocaml_pty.Pty.create_pty () in
  let _ = Ocaml_pty.Pty.fork_and_exec master slave_name "ls" ["-l"] in
  (* Lire toute la sortie *)
  let output = read_all_from_pty master in
  (* Attendre que l'enfant se termine *)
  let _ = Unix.waitpid [] (-1) in
  Printf.printf "Sortie complète de 'ls -l' :\n%s\n" output;
  Unix.close master