.POSIX:
.SUFFIXES:

include config.mk

# flags for compiling
DWLCPPFLAGS = -Iproto.h -I. -DWLR_USE_UNSTABLE -D_POSIX_C_SOURCE=200809L \
	-DVERSION=\"$(VERSION)\" $(XWAYLAND)
DWLDEVCFLAGS = -g -Wpedantic -Wall -Wextra -Wdeclaration-after-statement \
	-Wno-unused-parameter -Wshadow -Wunused-macros -Werror=strict-prototypes \
	-Werror=implicit -Werror=return-type -Werror=incompatible-pointer-types \
	-Wfloat-conversion

# CFLAGS / LDFLAGS
PKGS      = wlroots-0.19 wayland-server xkbcommon libinput $(XLIBS)
DWLCFLAGS = `$(PKG_CONFIG) --cflags $(PKGS)` $(DWLCPPFLAGS) $(DWLDEVCFLAGS) $(CFLAGS)
LDLIBS    = `$(PKG_CONFIG) --libs $(PKGS)` -lm $(LIBS)

#file location
PROTODIR  = proto.xml
WAYLAND_PROTOCOLS = $(shell $(PKG_CONFIG) --variable=pkgdatadir wayland-protocols)
proto := enum-header!$(WAYLAND_PROTOCOLS)/staging/cursor-shape/cursor-shape-v1.xml \
	enum-header!$(WAYLAND_PROTOCOLS)/unstable/pointer-constraints/pointer-constraints-unstable-v1.xml \
	enum-header!$(PROTODIR)/wlr-layer-shell-unstable-v1.xml server-header!$(PROTODIR)/wlr-output-power-management-unstable-v1.xml \
	server-header!$(WAYLAND_PROTOCOLS)/stable/xdg-shell/xdg-shell.xml

proto.xml  := $(subst client-header!,,$(proto))
proto.xml  := $(subst server-header!,,$(proto.xml))
proto.xml  := $(subst enum-header!,,$(proto.xml))
proto.xml  := $(subst private-code!,,$(proto.xml))
proto.xml  := $(subst public-code!,,$(proto.xml))
proto.h    := $(notdir $(proto.xml))
proto.h    := $(proto.h:.xml=-protocol.h)
proto.h    := $(addprefix $(PROTODIR:.xml=.h)/, $(proto.h))

all: dwl
dwl: src/dwl.o src/util.o
	$(CC) $^ $(DWLCFLAGS) $(LDFLAGS) $(LDLIBS) -o $@
src/dwl.o: $(proto.h) src/dwl.c src/client.h config.h config.mk
src/util.o: src/util.c src/util.h

# wayland-scanner is a tool which generates C headers and rigging for Wayland
# protocols, which are specified in XML. wlroots requires you to rig these up
# to your build system yourself and provide them in the include path.
WAYLAND_SCANNER   = `$(PKG_CONFIG) --variable=wayland_scanner wayland-scanner`

$(proto.h): proto.h
	$(eval temp := $(notdir $@))
	$(eval temp := $(temp:-protocol.h=.xml))
	$(eval temp := $(filter %$(temp), $(proto)))
	$(eval temp := $(subst !, , $(temp)))
	$(WAYLAND_SCANNER) $(temp) $@
proto.h:
	mkdir -p proto.h

config.h:
	cp config.def.h $@
clean:
	rm -rf dwl *.o *-protocol.h proto.h

dist: clean
	mkdir -p dwl-$(VERSION)
	cp -R LICENSE* Makefile CHANGELOG.md README.md client.h config.def.h \
		config.mk protocols dwl.1 dwl.c util.c util.h dwl.desktop \
		dwl-$(VERSION)
	tar -caf dwl-$(VERSION).tar.gz dwl-$(VERSION)
	rm -rf dwl-$(VERSION)

install: dwl
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	cp -f dwl $(DESTDIR)$(PREFIX)/bin
	chmod 755 $(DESTDIR)$(PREFIX)/bin/dwl
	mkdir -p $(DESTDIR)$(MANDIR)/man1
	cp -f dwl.1 $(DESTDIR)$(MANDIR)/man1
	chmod 644 $(DESTDIR)$(MANDIR)/man1/dwl.1
	mkdir -p $(DESTDIR)$(DATADIR)/wayland-sessions
	cp -f dwl.desktop $(DESTDIR)$(DATADIR)/wayland-sessions/dwl.desktop
	chmod 644 $(DESTDIR)$(DATADIR)/wayland-sessions/dwl.desktop
uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/dwl $(DESTDIR)$(MANDIR)/man1/dwl.1 \
		$(DESTDIR)$(DATADIR)/wayland-sessions/dwl.desktop

.SUFFIXES: .c .o
.c.o:
	$(CC) $(CPPFLAGS) $(DWLCFLAGS) -o $@ -c $<
