ERL_INCLUDE_PATH ?= "$(HOME)/.asdf/installs/erlang/29.0.4/usr/include"

all: priv/term.so

priv/term.so: c_src/term.c c_src/input.c
	gcc -fPIC -I$(ERL_INCLUDE_PATH) -shared -Wl,-undefined -Wl,dynamic_lookup -o priv/term.so c_src/input.c c_src/term.c
