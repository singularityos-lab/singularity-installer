using Gtk;
using Singularity;

namespace Singularity.Apps {

    public class InstallerApp : Singularity.Application {

        private InstallerWindow? win = null;
        private string mode;

        public InstallerApp (string mode) {
            Object (application_id: "dev.sinty.installer",
                    flags: ApplicationFlags.FLAGS_NONE);
            this.mode = mode;
        }

        protected override void activate () {
            if (win == null) {
                win = new InstallerWindow (this, mode);
                win.close_request.connect (() => { win = null; return false; });
            }
            win.present ();
        }
    }
}
