// https://www.erlang.org/doc/apps/erts/erl_nif.html
// https://www.erlang.org/doc/system/nif.html
// https://andrealeopardi.com/posts/using-c-from-elixir-with-nifs/
// https://linux.die.net/man/3/tcsetattr

#include <fcntl.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/select.h>
#include <sys/stat.h>
#include <termios.h>
#include <unistd.h>

#include "erl_nif.h"

bool c_cc_to_erl_array(ErlNifEnv *env, struct termios *config,
                       ERL_NIF_TERM arr[]) {
  for (int i = 0; i < NCCS; i++) {
    arr[i] = enif_make_uint(env, config->c_cc[i]);
  }

  return true;
}

static ERL_NIF_TERM get_flag_values(ErlNifEnv *env, int argc,
                                    const ERL_NIF_TERM argv[]) {
  const char *names[] = {
      "VEOF",      "VEOL",   "VERASE",  "VINTR",     "VKILL",     "VMIN",
      "VQUIT",     "VSTART", "VSTOP",   "VSUSP",     "VTIME",     "BRKINT",
      "ICRNL",     "IGNBRK", "IGNCR",   "IGNPAR",    "INLCR",     "INPCK",
      "ISTRIP",    "IXANY",  "IXOFF",   "IXON",      "PARMRK",    "OPOST",
      "ONLCR",     "OCRNL",  "ONOCR",   "ONLRET",    "OFDEL",     "OFILL",
      "NLDLY",     "CRDLY",  "TABDLY",  "BSDLY",     "VTDLY",     "FFDLY",
      "B0",        "B50",    "B75",     "B110",      "B134",      "B150",
      "B200",      "B300",   "B600",    "B1200",     "B1800",     "B2400",
      "B4800",     "B9600",  "B19200",  "B38400",    "CSIZE",     "CSTOPB",
      "CREAD",     "PARENB", "PARODD",  "HUPCL",     "CLOCAL",    "ECHO",
      "ECHOE",     "ECHOK",  "ECHONL",  "ICANON",    "IEXTEN",    "ISIG",
      "NOFLSH",    "TOSTOP", "TCSANOW", "TCSADRAIN", "TCSAFLUSH", "TCIFLUSH",
      "TCIOFLUSH", "TCIOFF", "TCION",   "TCOOFF",    "TCOON"};
  int values[] = {
      VEOF,      VEOL,     VERASE,    VINTR,  VKILL,  VMIN,    VQUIT,
      VSTART,    VSTOP,    VSUSP,     VTIME,  BRKINT, ICRNL,   IGNBRK,
      IGNCR,     IGNPAR,   INLCR,     INPCK,  ISTRIP, IXANY,   IXOFF,
      IXON,      PARMRK,   OPOST,     ONLCR,  OCRNL,  ONOCR,   ONLRET,
      OFDEL,     OFILL,    NLDLY,     CRDLY,  TABDLY, BSDLY,   VTDLY,
      FFDLY,     B0,       B50,       B75,    B110,   B134,    B150,
      B200,      B300,     B600,      B1200,  B1800,  B2400,   B4800,
      B9600,     B19200,   B38400,    CSIZE,  CSTOPB, CREAD,   PARENB,
      PARODD,    HUPCL,    CLOCAL,    ECHO,   ECHOE,  ECHOK,   ECHONL,
      ICANON,    IEXTEN,   ISIG,      NOFLSH, TOSTOP, TCSANOW, TCSADRAIN,
      TCSAFLUSH, TCIFLUSH, TCIOFLUSH, TCIOFF, TCION,  TCOOFF,  TCOON};
  int len = sizeof(values) / sizeof(values[0]);

  ERL_NIF_TERM flag_map = enif_make_new_map(env);

  for (int i = 0; i < len; i++) {
    if (!enif_make_map_put(env, flag_map, enif_make_atom(env, names[i]),
                           enif_make_uint(env, values[i]), &flag_map)) {
      return enif_make_badarg(env);
    }
  }

  return flag_map;
}

static ERL_NIF_TERM set_config(ErlNifEnv *env, int argc,
                               const ERL_NIF_TERM argv[]) {
  struct termios config;
  ERL_NIF_TERM c_iflag, c_oflag, c_cflag, c_lflag, c_cc;
  ERL_NIF_TERM config_map = argv[0];
  if (!enif_is_map(env, config_map)) {
    return enif_make_badarg(env);
  }

  enif_get_map_value(env, config_map, enif_make_atom(env, "c_iflag"), &c_iflag);
  enif_get_uint(env, c_iflag, &config.c_iflag);

  enif_get_map_value(env, config_map, enif_make_atom(env, "c_oflag"), &c_oflag);
  enif_get_uint(env, c_oflag, &config.c_oflag);

  enif_get_map_value(env, config_map, enif_make_atom(env, "c_cflag"), &c_cflag);
  enif_get_uint(env, c_cflag, &config.c_cflag);

  enif_get_map_value(env, config_map, enif_make_atom(env, "c_lflag"), &c_lflag);
  enif_get_uint(env, c_lflag, &config.c_lflag);

  enif_get_map_value(env, config_map, enif_make_atom(env, "c_cc"), &c_cc);
  ERL_NIF_TERM el;
  uint uel;
  for (int i = 0; i < NCCS; i++) {
    enif_get_list_cell(env, c_cc, &el, &c_cc);
    enif_get_uint(env, el, &uel);
    config.c_cc[i] = uel;
  }

  int term = open("/dev/tty", O_RDWR);
  if (term == -1) {
    return enif_make_tuple(
        env, 2, enif_make_atom(env, "error"),
        enif_make_string(env, "Failed to open /dev/tty", ERL_NIF_UTF8));
  }

  if (tcsetattr(term, TCSAFLUSH, &config) != 0) {
    return enif_make_tuple(
        env, 2, enif_make_atom(env, "error"),
        enif_make_string(env, "tcsetattr failed", ERL_NIF_UTF8));
  }

  return enif_make_atom(env, "ok");
}

static ERL_NIF_TERM get_config(ErlNifEnv *env, int argc,
                               const ERL_NIF_TERM argv[]) {
  int term = open("/dev/tty", O_RDWR);
  if (term == -1) {
    return enif_make_tuple(
        env, 2, enif_make_atom(env, "error"),
        enif_make_string(env, "Failed to open /dev/tty", ERL_NIF_UTF8));
  }

  struct termios config;
  if (tcgetattr(term, &config) != 0) {
    return enif_make_tuple(
        env, 2, enif_make_atom(env, "error"),
        enif_make_string(env, "tcgetattr failed", ERL_NIF_UTF8));
  }

  ERL_NIF_TERM config_map = enif_make_new_map(env);
  ERL_NIF_TERM c_cc[NCCS];
  c_cc_to_erl_array(env, &config, c_cc);

  enif_make_map_put(env, config_map, enif_make_atom(env, "c_iflag"),
                    enif_make_uint(env, config.c_iflag), &config_map);
  enif_make_map_put(env, config_map, enif_make_atom(env, "c_oflag"),
                    enif_make_uint(env, config.c_oflag), &config_map);
  enif_make_map_put(env, config_map, enif_make_atom(env, "c_cflag"),
                    enif_make_uint(env, config.c_cflag), &config_map);
  enif_make_map_put(env, config_map, enif_make_atom(env, "c_lflag"),
                    enif_make_uint(env, config.c_lflag), &config_map);
  enif_make_map_put(env, config_map, enif_make_atom(env, "c_cc"),
                    enif_make_list_from_array(env, c_cc, NCCS), &config_map);

  return enif_make_tuple(env, 2, enif_make_atom(env, "ok"), config_map);
}

static ErlNifFunc nif_funcs[] = {{"get_flag_values", 0, get_flag_values},
                                 {"set_config", 1, set_config},
                                 {"get_config", 0, get_config}};

ERL_NIF_INIT(Elixir.Weaver.TUI.Term, nif_funcs, NULL, NULL, NULL, NULL)

// gcc -fPIC -I/home/fraburnham/.asdf/installs/erlang/29.0.4/usr/include
// -dynamiclib -undefined dynamic_lookup -o term.so term.c ^ I have a feeling
// that is for mac