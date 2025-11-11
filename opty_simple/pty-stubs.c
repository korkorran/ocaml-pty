#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <caml/mlvalues.h>
#include <caml/memory.h>
#include <caml/alloc.h>
#include <caml/fail.h>
#include <termios.h>

/* Ouvre un PTY maître */
CAMLprim value ocaml_posix_openpt(value unit) {
    int master = posix_openpt(O_RDWR | O_NOCTTY);
    if (master < 0)
        caml_failwith("posix_openpt failed");
    return Val_int(master);
}

/* Accorde les permissions sur le PTY */
CAMLprim value ocaml_grantpt(value master_fd) {
    if (grantpt(Int_val(master_fd)) < 0)
        caml_failwith("grantpt failed");
    return Val_unit;
}

/* Déverrouille le PTY */
CAMLprim value ocaml_unlockpt(value master_fd) {
    if (unlockpt(Int_val(master_fd)) < 0)
        caml_failwith("unlockpt failed");
    return Val_unit;
}

/* Récupère le nom du PTY esclave */
CAMLprim value ocaml_ptsname(value master_fd) {
    char *slave_name = ptsname(Int_val(master_fd));
    if (!slave_name)
        caml_failwith("ptsname failed");
    return caml_copy_string(slave_name);
}

/* Vérifie si le descripteur est un terminal */
CAMLprim value ocaml_isatty(value fd) {
    return Val_bool(isatty(Int_val(fd)));
}

/* Définit le groupe de processus pour le terminal */
CAMLprim value ocaml_tcsetpgrp(value fd, value pid) {
    if (tcsetpgrp(Int_val(fd), Int_val(pid)) < 0)
        caml_failwith("tcsetpgrp failed");
    return Val_unit;
}

/* Définit le terminal contrôlant pour le processus actuel */
CAMLprim value ocaml_set_controlling_tty(value fd) {
    if (ioctl(Int_val(fd), TIOCSCTTY, 0) < 0) {
        caml_failwith("ioctl TIOCSCTTY failed");
    }
    return Val_unit;
}


/* Désactive l'écho sur le descripteur de fichier */
CAMLprim value ocaml_disable_echo(value fd) {
    struct termios term;
    if (tcgetattr(Int_val(fd), &term) < 0) {
        caml_failwith("tcgetattr failed");
    }
    term.c_lflag &= ~(ECHO | ECHONL); /* Désactive l'écho */
    if (tcsetattr(Int_val(fd), TCSANOW, &term) < 0) {
        caml_failwith("tcsetattr failed");
    }
    return Val_unit;
}

/*
CAMLprim value ocaml_get_fd_int(value fd) {
    return Val_int(Int_val(fd));
}
*/