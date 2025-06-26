# $Id: Makefile,v 1.12 2025/03/14 00:35:59 minmin Exp $

DDNS_SRC = ddns-add

DDNS_TARGET = ddns-del ddns-zone ddns-backup ddns-hosts

TARGET = ${DDNS_TARGET}

LN     = ln -f -s
RM     = rm -f

all: ${TARGET}

${TARGET}: 
	${LN} ${DDNS_SRC} $@

clean:
	${RM} ${TARGET}
