using GLib;

namespace Singularity.Apps {

    public static int main (string[] args) {
        Intl.setlocale (GLib.LocaleCategory.ALL, "");

        string mode = "install";
        string[] filtered = {};
        foreach (var a in args) {
            if (a == "--oobe") mode = "oobe";
            else filtered += a;
        }

        var app = new InstallerApp (mode);
        return app.run (filtered);
    }
}
