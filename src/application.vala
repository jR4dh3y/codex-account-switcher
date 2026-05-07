/* application.vala - Gtk.Application subclass */

namespace CodexTracker {

    public class Application : Adw.Application {
        public Application () {
            Gtk.Window.set_default_icon_name ("io.github.jR4dh3y.CodexAccountSwitcher");

            Object (
                application_id: "io.github.jR4dh3y.CodexAccountSwitcher",
                flags: ApplicationFlags.FLAGS_NONE
            );
        }

        protected override void activate () {
            var window = new MainWindow (this);
            window.present ();
        }
    }
}
