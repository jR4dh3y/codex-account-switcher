/* application.vala - Gtk.Application subclass */

namespace CodexTracker {

    public class Application : Adw.Application {
        public Application () {
            Object (
                application_id: "com.github.codex-tracker",
                flags: ApplicationFlags.FLAGS_NONE
            );
        }

        protected override void activate () {
            var window = new MainWindow (this);
            window.present ();
        }
    }
}
