all: writer

writer: writer.c
	@# See https://www.gnu.org/software/make/manual/html_node/Echoing.html
	@if [ -z "${CROSS_COMPILE:=}" ]; then \
		printf "\$$CROSS_COMPILE is not set\n"; \
	else \
		printf "\$$CROSS_COMPILE is set to '%s'\n" "${CROSS_COMPILE}"; \
	fi
	${CROSS_COMPILE}gcc writer.c -o writer

clean:
	rm -f writer
	rm -f *.o
