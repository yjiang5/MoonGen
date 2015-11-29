DIR=utils
lib:
	gcc -I /usr/include/lua5.1 -o $(DIR)/snmpc.so $(DIR)/snmpc.c -lsnmp -llua5.1 -Wall -fPIC -shared
clean: 
	rm -f $(DIR)/snmpc.so

