(* opty_simple.ml *)
external posix_openpt : unit -> Unix.file_descr = "ocaml_posix_openpt"
external grantpt : Unix.file_descr -> unit = "ocaml_grantpt"
external unlockpt : Unix.file_descr -> unit = "ocaml_unlockpt"
external ptsname : Unix.file_descr -> string = "ocaml_ptsname"
external isatty : Unix.file_descr -> bool = "ocaml_isatty"
external set_controlling_tty : Unix.file_descr -> unit = "ocaml_set_controlling_tty"
external disable_echo : Unix.file_descr -> unit = "ocaml_disable_echo"

let contains s1 s2 =
    let re = Str.regexp_string s2
    in
        try ignore (Str.search_forward re s1 0); true
        with Not_found -> false


let () =
  let master = posix_openpt () in
  grantpt master;
  unlockpt master;
  let slave_name = ptsname master in
  match Unix.fork () with
  | 0 -> (* Processus enfant : esclave *)
      let slave_fd = Unix.openfile slave_name [Unix.O_RDWR] 0o600 in
      if not (isatty slave_fd) then (
        prerr_endline "Erreur : slave_fd n'est pas un terminal";
        exit 1
      );
      disable_echo slave_fd;
      ignore (Unix.setsid ());
      (try set_controlling_tty slave_fd
       with Failure msg ->
         prerr_endline ("Erreur : " ^ msg);
         exit 1);
      Unix.dup2 slave_fd Unix.stdin;
      Unix.dup2 slave_fd Unix.stdout;
      Unix.dup2 slave_fd Unix.stderr;
      Unix.close slave_fd;
      Unix.close master;

      (* Liste des commandes à exécuter *)
      let commands = ["ls -l"; "git log --oneline -5"; "pwd"] in
      let execute_command cmd =
        let ic, oc = Unix.open_process cmd in
        let buf = Bytes.create 1024 in
        let rec read_output () =
          let n = input ic buf 0 (Bytes.length buf) in
          if n > 0 then (
            ignore (Unix.write Unix.stdout buf 0 n);
            read_output ()
          )
        in
        read_output ();
        ignore (Unix.close_process (ic, oc))
      in
      List.iter execute_command commands;
      (* Envoie un message de fin *)
      let end_msg = "__END_OF_OUTPUT__\n" in
      ignore (Unix.write Unix.stdout (Bytes.of_string end_msg) 0 (String.length end_msg));
      exit 0
  | pid -> (* Processus parent : maître *)
      ignore pid;
      let buf = Bytes.create 1024 in
      let output = Buffer.create 1024 in
      let end_msg = "__END_OF_OUTPUT__" in
      let rec loop () =
        let ready_fds, _, _ = Unix.select [master] [] [] 1.0 in
        if List.exists (fun fd -> fd == master) ready_fds then (
          let m = Unix.read master buf 0 (Bytes.length buf) in
          if m > 0 then (
            let str = Bytes.sub_string buf 0 m in
            Buffer.add_string output str;
            (* ignore (Unix.write Unix.stdout buf 0 m);
             Vérifie si le message de fin est présent *)
            if contains str end_msg then (
              Unix.close master;
              let result = Buffer.contents output in
              Printf.printf "\nRésultat final :\n%s\n" result;
            ) else (
              loop ()
            )
          ) else (
            loop ()
          )
        ) else (
          loop ()
        )
      in
      try
        loop ();
      with e ->
        Unix.close master;
        prerr_endline ("Erreur dans la boucle : " ^ Printexc.to_string e);
        exit 1
