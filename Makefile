ERL_INCLUDE_PATH="/home/fraburnham/.asdf/installs/erlang/29.0.4/usr/include"

all: priv/term.so

priv/term.so: c_src/term.c
	gcc -fPIC -I$(ERL_INCLUDE_PATH) -shared -Wl,-undefined -Wl,dynamic_lookup -o priv/term.so c_src/term.c
