external posix_openpt : unit -> Unix.file_descr = "ocaml_posix_openpt"
external grantpt : Unix.file_descr -> unit = "ocaml_grantpt"
external unlockpt : Unix.file_descr -> unit = "ocaml_unlockpt"
external ptsname : Unix.file_descr -> string = "ocaml_ptsname"
(* external tcsetpgrp : Unix.file_descr -> int -> unit = "ocaml_tcsetpgrp" *)
external isatty : Unix.file_descr -> bool = "ocaml_isatty"
external set_controlling_tty : Unix.file_descr -> unit = "ocaml_set_controlling_tty"
external disable_echo : Unix.file_descr -> unit = "ocaml_disable_echo"

let () =
  (* Capture SIGINT pour nettoyer les ressources *)
  Sys.set_signal Sys.sigint (Sys.Signal_handle (fun _ ->
    print_endline "\nFermeture du pseudo-terminal...";
    exit 0
  ));

  (* Ouvre le PTY maître *)
  let master = posix_openpt () in
  grantpt master;
  unlockpt master;
  let slave_name = ptsname master in

  match Unix.fork () with
  | 0 -> (* Processus enfant : esclave *)
      let slave_fd = Unix.openfile slave_name [Unix.O_RDWR] 0o600 in
      (* Vérifie que slave_fd est un terminal *)
    if not (isatty slave_fd) then (
      prerr_endline "Erreur : slave_fd n'est pas un terminal";
      exit 1
    );
    (* Désactive l'écho sur le PTY esclave *)
    disable_echo slave_fd;
    (* Crée une nouvelle session et dissocie le processus du terminal parent *)
    ignore (Unix.setsid ());
    (* Associe le PTY esclave comme terminal contrôlant *)
    (try set_controlling_tty slave_fd
     with Failure msg ->
       prerr_endline ("Erreur : " ^ msg);
       exit 1);
      (* Redirige stdin, stdout, stderr vers le PTY esclave *)
      Unix.dup2 slave_fd Unix.stdin;
      Unix.dup2 slave_fd Unix.stdout;
      Unix.dup2 slave_fd Unix.stderr;
      Unix.close slave_fd;
      Unix.close master;
      (* Lance un shell *)
      Unix.execvp "/bin/sh" [|"/bin/sh"; "--noediting"|]
      (* Si execvp échoue : 
      prerr_endline "Erreur : impossible de lancer /bin/sh";
      exit 1 *)

  | pid -> (* Processus parent : maître *)
      ignore pid;
      let buf = Bytes.create 1024 in
      let rec loop () =
        (* Utilise select pour surveiller stdin et master *)
        let ready_fds, _, _ = Unix.select [Unix.stdin; master] [] [] (-1.) in
        List.iter (fun fd ->
          if fd == Unix.stdin then (
            (* Lit depuis stdin et écrit vers master *)
            let n = Unix.read Unix.stdin buf 0 (Bytes.length buf) in
            if n > 0 then ignore (Unix.write master buf 0 n)
          ) else if fd == master then (
            (* Lit depuis master et écrit vers stdout *)
            let m = Unix.read master buf 0 (Bytes.length buf) in
            if m > 0 then ignore (Unix.write Unix.stdout buf 0 m)
          )
        ) ready_fds;
        loop ()
      in
      (* Capture les exceptions pour fermer proprement master *)
      try loop ()
      with e ->
        Unix.close master;
        prerr_endline ("Erreur dans la boucle : " ^ Printexc.to_string e);
        exit 1
