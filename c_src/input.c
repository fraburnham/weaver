// https://www.erlang.org/doc/apps/erts/erl_nif.html
// https://www.erlang.org/doc/system/nif.html
// https://linux.die.net/man/2/select

#include <stdio.h>
#include <sys/select.h>
#include <unistd.h>
#include <wchar.h>

#include "input.h"

ERL_NIF_TERM attempt_read(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[]) {
  fd_set read_fds; // set of file descriptors to select over
  struct timeval timeout;

  // 50ms
  timeout.tv_sec = 0;
  timeout.tv_usec = 50000;

  // create fd set
  FD_ZERO(&read_fds);
  FD_SET(STDIN_FILENO, &read_fds);

  switch (select(1, &read_fds, NULL, NULL, &timeout)) {
  case -1:
    return enif_make_atom(env, "error");
  case 0:
    return enif_make_atom(env, "timeout");
  default:
    return enif_make_tuple2(env, enif_make_atom(env, "ok"),
                            enif_make_int(env, getwchar()));
  }
}

// I wonder if this should try to read all available chars and pass them back...