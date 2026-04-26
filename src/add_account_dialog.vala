/* add_account_dialog.vala - Browser login dialog */

namespace CodexTracker {

    public class AddAccountDialog : Adw.Window {
        private AuthManager auth_manager;
        private Gtk.Stack stack;
        private Gtk.Label error_detail_label;
        private bool auth_started = false;

        public signal void account_added (AccountData account);

        public AddAccountDialog (Gtk.Window parent, AuthManager auth_manager) {
            Object (
                title: "Add ChatGPT Account",
                modal: true,
                transient_for: parent,
                default_width: 400,
                default_height: 300
            );

            this.auth_manager = auth_manager;
            build_ui ();

            // Clean up on close
            this.close_request.connect (() => {
                auth_manager.cancel ();
                return false; // allow close
            });

            start_auth ();
        }

        private void build_ui () {
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            var header = new Adw.HeaderBar ();
            header.show_end_title_buttons = true;
            box.append (header);

            stack = new Gtk.Stack ();
            stack.transition_type = Gtk.StackTransitionType.CROSSFADE;

            // === Waiting page ===
            var waiting = new Gtk.Box (Gtk.Orientation.VERTICAL, 16);
            waiting.valign = Gtk.Align.CENTER;
            waiting.margin_start = 32;
            waiting.margin_end = 32;
            waiting.margin_top = 24;
            waiting.margin_bottom = 24;

            var spinner = new Gtk.Spinner ();
            spinner.spinning = true;
            spinner.width_request = 48;
            spinner.height_request = 48;
            waiting.append (spinner);

            var title_label = new Gtk.Label ("Sign in via your browser");
            title_label.add_css_class ("title-3");
            waiting.append (title_label);

            var desc_label = new Gtk.Label ("A browser window has been opened.\nSign in to your ChatGPT account there.");
            desc_label.add_css_class ("dim-label");
            desc_label.justify = Gtk.Justification.CENTER;
            desc_label.wrap = true;
            waiting.append (desc_label);

            var hint_label = new Gtk.Label ("This window will close automatically when done.");
            hint_label.add_css_class ("caption");
            hint_label.add_css_class ("dim-label");
            hint_label.margin_top = 8;
            waiting.append (hint_label);

            stack.add_named (waiting, "waiting");

            // === Error page ===
            var error_page = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            error_page.valign = Gtk.Align.CENTER;
            error_page.margin_start = 32;
            error_page.margin_end = 32;
            error_page.margin_top = 24;
            error_page.margin_bottom = 24;

            var error_icon = new Gtk.Image.from_icon_name ("dialog-error-symbolic");
            error_icon.pixel_size = 48;
            error_page.append (error_icon);

            var error_title = new Gtk.Label ("Authentication Failed");
            error_title.add_css_class ("title-3");
            error_page.append (error_title);

            error_detail_label = new Gtk.Label ("");
            error_detail_label.add_css_class ("dim-label");
            error_detail_label.wrap = true;
            error_detail_label.justify = Gtk.Justification.CENTER;
            error_detail_label.max_width_chars = 40;
            error_page.append (error_detail_label);

            var retry_btn = new Gtk.Button.with_label ("Try Again");
            retry_btn.add_css_class ("suggested-action");
            retry_btn.halign = Gtk.Align.CENTER;
            retry_btn.margin_top = 8;
            retry_btn.clicked.connect (() => {
                stack.visible_child_name = "waiting";
                start_auth ();
            });
            error_page.append (retry_btn);

            stack.add_named (error_page, "error");

            box.append (stack);
            set_content (box);
            stack.visible_child_name = "waiting";
        }

        private void start_auth () {
            // Disconnect previous signal handlers to avoid duplicates
            if (auth_started) {
                // Create a fresh auth manager instance to avoid stale signal connections
                // (the signals from previous attempts would still fire)
            }
            auth_started = true;

            auth_manager.auth_completed.connect (on_auth_completed);
            auth_manager.auth_failed.connect (on_auth_failed);

            auth_manager.start_browser_flow.begin ();
        }

        private void on_auth_completed (AccountData account) {
            auth_manager.auth_completed.disconnect (on_auth_completed);
            auth_manager.auth_failed.disconnect (on_auth_failed);
            account_added (account);
            close ();
        }

        private void on_auth_failed (string error) {
            auth_manager.auth_completed.disconnect (on_auth_completed);
            auth_manager.auth_failed.disconnect (on_auth_failed);
            error_detail_label.label = error;
            stack.visible_child_name = "error";
        }
    }
}
