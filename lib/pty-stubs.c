#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <caml/mlvalues.h>
#include <caml/memory.h>
#include <caml/alloc.h>
#include <caml/fail.h>

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

CAMLprim value ocaml_get_fd_int(value fd) {
    return Val_int(Int_val(fd));
}