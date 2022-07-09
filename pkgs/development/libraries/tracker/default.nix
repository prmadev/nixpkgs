{ stdenv
, lib
, fetchurl
, gettext
, meson
, ninja
, pkg-config
, asciidoc
, gobject-introspection
, python3
, docbook-xsl-nons
, docbook_xml_dtd_45
, libxml2
, glib
, wrapGAppsNoGuiHook
, vala
, sqlite
, libxslt
, libstemmer
, gnome
, icu
, libuuid
, libsoup
, libsoup_3
, json-glib
, systemd
, dbus
}:

stdenv.mkDerivation rec {
  pname = "tracker";
  version = "3.3.1";

  outputs = [ "out" "dev" "devdoc" ];

  src = fetchurl {
    url = "mirror://gnome/sources/${pname}/${lib.versions.majorMinor version}/${pname}-${version}.tar.xz";
    sha256 = "Wtb1vJd4Hr9V7NaUfNSuf/QZJRZYDRC9g4Dx3UcZbtI=";
  };

  patches = [
    ./fix-test-order.patch
  ];

  postPatch = ''
    patchShebangs utils/data-generators/cc/generate
  '';

  nativeBuildInputs = [
    meson
    ninja
    vala
    pkg-config
    asciidoc
    gettext
    libxslt
    wrapGAppsNoGuiHook
    gobject-introspection
    docbook-xsl-nons
    docbook_xml_dtd_45
    python3 # for data-generators
    systemd # used for checks to install systemd user service
    dbus # used for checks and pkg-config to install dbus service/s
  ] ++ checkInputs; # gi is in the main meson.build and checked regardless of
                    # whether tests are enabled

  buildInputs = [
    glib
    libxml2
    sqlite
    icu
    libsoup
    libsoup_3
    libuuid
    json-glib
    libstemmer
  ];

  checkInputs = with python3.pkgs; [
    pygobject3
  ];

  mesonFlags = [
    "-Ddocs=true"
  ];

  doCheck = true;

  preCheck = ''
    # (tracker-store:6194): Tracker-CRITICAL **: 09:34:07.722: Cannot initialize database: Could not open sqlite3 database:'/homeless-shelter/.cache/tracker/meta.db': unable to open database file
    export HOME=$(mktemp -d)

    # Our gobject-introspection patches make the shared library paths absolute
    # in the GIR files. When running functional tests, the library is not yet installed,
    # though, so we need to replace the absolute path with a local one during build.
    # We are using a symlink that will be overridden during installation.
    mkdir -p $out/lib
    ln -s $PWD/src/libtracker-sparql/libtracker-sparql-3.0.so $out/lib/libtracker-sparql-3.0.so.0
  '';

  checkPhase = ''
    runHook preCheck

    dbus-run-session \
      --config-file=${dbus.daemon}/share/dbus-1/session.conf \
      meson test \
        --timeout-multiplier 2 \
        --print-errorlogs

    runHook postCheck
  '';

  postCheck = ''
    # Clean up out symlinks
    rm -r $out/lib
  '';

  passthru = {
    updateScript = gnome.updateScript {
      packageName = pname;
    };
  };

  meta = with lib; {
    homepage = "https://wiki.gnome.org/Projects/Tracker";
    description = "Desktop-neutral user information store, search tool and indexer";
    maintainers = teams.gnome.members;
    license = licenses.gpl2Plus;
    platforms = platforms.linux;
  };
}
