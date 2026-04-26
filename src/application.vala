/* application.vala - Gtk.Application subclass */

namespace CodexTracker {

    public class Application : Adw.Application {
        public Application () {
            Object (
                application_id: "io.github.jR4dh3y.CodexMultiAccountSwitcher",
                flags: ApplicationFlags.FLAGS_NONE
            );
        }

        protected override void activate () {
            var window = new MainWindow (this);
            window.present ();
        }
    }
}
