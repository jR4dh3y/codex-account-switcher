/* window.vala - Main application window */

namespace CodexTracker {

    public class MainWindow : Adw.ApplicationWindow {
        private AccountStore store;
        private AuthManager auth_manager;
        private UsageChecker usage_checker;
        private Adw.PreferencesGroup pref_group;
        private Gtk.Box content_box;
        private Gtk.Stack main_stack;
        private Adw.ToastOverlay toast_overlay;
        private AccountRow[] account_rows;

        public MainWindow (Gtk.Application app) {
            Object (
                application: app,
                title: "Codex Account Switcher",
                default_width: 960,
                default_height: 540
            );

            store = new AccountStore ();
            auth_manager = new AuthManager ();
            usage_checker = new UsageChecker (auth_manager);

            store.load ();
            build_ui ();
            populate_cards ();
        }

        private void build_ui () {
            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            // Header bar
            var headerbar = new Adw.HeaderBar ();
            headerbar.show_title = true;
            headerbar.decoration_layout = "";
            var title = new Adw.WindowTitle ("Codex Account Switcher", "%u accounts".printf (store.accounts.length));
            headerbar.title_widget = title;

            // Add account button
            var btn_add = new Gtk.Button.from_icon_name ("list-add-symbolic");
            btn_add.tooltip_text = "Add ChatGPT account";
            btn_add.clicked.connect (on_add_account);
            headerbar.pack_start (btn_add);

            // Refresh all button
            var btn_refresh = new Gtk.Button.with_label ("Check All");
            btn_refresh.add_css_class ("flat");
            btn_refresh.tooltip_text = "Check usage for all accounts";
            btn_refresh.clicked.connect (on_refresh_all);
            headerbar.pack_end (btn_refresh);

            box.append (headerbar);

            // Main stack
            main_stack = new Gtk.Stack ();
            main_stack.transition_type = Gtk.StackTransitionType.CROSSFADE;
            main_stack.vexpand = true;

            // Empty state
            var empty = new Adw.StatusPage ();
            empty.icon_name = "system-users-symbolic";
            empty.title = "No Accounts";
            empty.description = "Add your ChatGPT accounts to monitor Codex usage across all of them.";
            empty.vexpand = true;

            var empty_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
            empty_box.halign = Gtk.Align.CENTER;

            var empty_btn = new Gtk.Button.with_label ("Add Account");
            empty_btn.add_css_class ("suggested-action");
            empty_btn.clicked.connect (on_add_account);
            empty_box.append (empty_btn);

            var hint_label = new Gtk.Label ("Signs in via ChatGPT — no API key needed");
            hint_label.add_css_class ("dim-label");
            hint_label.add_css_class ("caption");
            empty_box.append (hint_label);

            empty.child = empty_box;
            main_stack.add_named (empty, "empty");

            // Scrolled view with wider clamp (not PreferencesPage which caps at ~600px)
            var scrolled = new Gtk.ScrolledWindow ();
            scrolled.vexpand = true;
            scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;

            var clamp = new Adw.Clamp ();
            clamp.maximum_size = 1200;
            clamp.tightening_threshold = 800;
            clamp.margin_top = 12;
            clamp.margin_bottom = 12;
            clamp.margin_start = 12;
            clamp.margin_end = 12;

            // Container box for the preferences group
            content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            content_box.valign = Gtk.Align.START;
            clamp.child = content_box;
            scrolled.child = clamp;
            main_stack.add_named (scrolled, "cards");

            box.append (main_stack);

            toast_overlay = new Adw.ToastOverlay ();
            toast_overlay.child = box;
            set_content (toast_overlay);
        }

        private void populate_cards () {
            // Clear existing group
            if (pref_group != null) {
                content_box.remove (pref_group);
            }
            pref_group = new Adw.PreferencesGroup ();
            content_box.append (pref_group);

            account_rows = new AccountRow[store.accounts.length];

            if (store.accounts.length == 0) {
                main_stack.visible_child_name = "empty";
                return;
            }

            main_stack.visible_child_name = "cards";

            for (uint i = 0; i < store.accounts.length; i++) {
                var row = new AccountRow (store.accounts[i], i);
                row.refresh_requested.connect (on_refresh_single);
                row.remove_requested.connect (on_remove_account);
                row.rename_requested.connect (on_rename_account);
                row.use_in_codex_requested.connect (on_use_in_codex);
                pref_group.add (row);
                account_rows[i] = row;
            }

            refresh_active_indicators ();
        }

        private void refresh_active_indicators () {
            string? active_id = AccountStore.get_active_codex_account_id ();
            for (uint i = 0; i < account_rows.length; i++) {
                var row = account_rows[i];
                bool is_active = active_id != null && row.account.account_id == active_id;
                row.set_active (is_active);
            }
        }

        private void on_add_account () {
            var dialog = new AddAccountDialog (this, auth_manager);
            dialog.account_added.connect ((account) => {
                store.add_account (account);
                populate_cards ();
            });
            dialog.present ();
        }

        private void on_refresh_all () {
            for (uint i = 0; i < store.accounts.length; i++) {
                on_refresh_single (i);
            }
        }

        private void on_refresh_single (uint index) {
            if (index >= store.accounts.length || index >= account_rows.length) return;

            var account = store.accounts[index];
            var row = account_rows[index];

            row.set_loading (true);

            usage_checker.check_usage.begin (account, (obj, res) => {
                usage_checker.check_usage.end (res);
                row.update_display ();
                row.set_loading (false);
                store.save ();
            });
        }

        private void on_use_in_codex (uint index) {
            if (index >= store.accounts.length) return;

            var account = store.accounts[index];
            var dialog = new Adw.MessageDialog (this, "Switch Codex Account?", null);
            dialog.body = "This will set \"%s\" as the active account in Codex CLI.\n\nAny running Codex session will need to be restarted.".printf (account.label);
            dialog.add_response ("cancel", "Cancel");
            dialog.add_response ("switch", "Switch Account");
            dialog.set_response_appearance ("switch", Adw.ResponseAppearance.SUGGESTED);
            dialog.response.connect ((response) => {
                if (response == "switch") {
                    write_codex_auth (account);
                }
            });
            dialog.present ();
        }

        private void write_codex_auth (AccountData account) {
            string codex_dir = Path.build_filename (Environment.get_home_dir (), ".codex");
            string auth_file = Path.build_filename (codex_dir, "auth.json");

            try {
                DirUtils.create_with_parents (codex_dir, 0700);

                // Build the auth.json in the format Codex CLI expects
                var tokens_obj = new Json.Object ();
                tokens_obj.set_string_member ("id_token", account.id_token);
                tokens_obj.set_string_member ("access_token", account.access_token);
                tokens_obj.set_string_member ("refresh_token", account.refresh_token);
                tokens_obj.set_string_member ("account_id", account.account_id);

                var root_obj = new Json.Object ();
                root_obj.set_string_member ("auth_mode", "chatgpt");
                root_obj.set_null_member ("OPENAI_API_KEY");

                var tokens_node = new Json.Node (Json.NodeType.OBJECT);
                tokens_node.set_object (tokens_obj);
                root_obj.set_member ("tokens", tokens_node);

                var now = new DateTime.now_utc ();
                root_obj.set_string_member ("last_refresh", now.format_iso8601 ());

                var root_node = new Json.Node (Json.NodeType.OBJECT);
                root_node.set_object (root_obj);

                var gen = new Json.Generator ();
                gen.set_root (root_node);
                gen.pretty = true;
                gen.to_file (auth_file);
                FileUtils.chmod (auth_file, 0600);

                // Update active indicators
                refresh_active_indicators ();

                // Show success toast
                var toast = new Adw.Toast ("Switched Codex to %s".printf (account.label));
                toast.timeout = 3;
                show_toast (toast);

            } catch (Error e) {
                var err_dialog = new Adw.MessageDialog (this, "Error", null);
                err_dialog.body = "Failed to write auth.json: %s".printf (e.message);
                err_dialog.add_response ("ok", "OK");
                err_dialog.present ();
            }
        }

        private void show_toast (Adw.Toast toast) {
            toast_overlay.add_toast (toast);
        }

        private void on_remove_account (uint index) {
            if (index >= store.accounts.length) return;

            var account = store.accounts[index];
            var dialog = new Adw.MessageDialog (this, "Remove Account?", null);
            dialog.body = "Remove \"%s\" from tracking?\nYou can always re-add it later.".printf (account.label);
            dialog.add_response ("cancel", "Cancel");
            dialog.add_response ("remove", "Remove");
            dialog.set_response_appearance ("remove", Adw.ResponseAppearance.DESTRUCTIVE);
            dialog.response.connect ((response) => {
                if (response == "remove") {
                    store.remove_account (index);
                    populate_cards ();
                }
            });
            dialog.present ();
        }

        private void on_rename_account (uint index) {
            if (index >= store.accounts.length) return;

            var account = store.accounts[index];
            var dialog = new Adw.MessageDialog (this, "Rename Account", null);
            dialog.body = "Enter a label for this account:";

            var entry = new Gtk.Entry ();
            entry.text = account.label;
            entry.placeholder_text = "e.g. Work, Personal, Side project";
            entry.margin_start = 12;
            entry.margin_end = 12;
            dialog.set_extra_child (entry);

            dialog.add_response ("cancel", "Cancel");
            dialog.add_response ("rename", "Rename");
            dialog.set_response_appearance ("rename", Adw.ResponseAppearance.SUGGESTED);

            dialog.response.connect ((response) => {
                if (response == "rename" && entry.text.strip () != "") {
                    account.label = entry.text.strip ();
                    store.save ();
                    populate_cards ();
                }
            });
            dialog.present ();
        }
    }
}
