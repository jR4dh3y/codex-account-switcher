/* window.vala - Main application window */

namespace CodexTracker {

    public class MainWindow : Adw.ApplicationWindow {
        private AccountStore store;
        private AuthManager auth_manager;
        private UsageChecker usage_checker;
        private Adw.PreferencesPage pref_page;
        private Adw.PreferencesGroup pref_group;
        private Gtk.Stack main_stack;
        private AccountRow[] account_rows;

        public MainWindow (Gtk.Application app) {
            Object (
                application: app,
                title: "Codex Tracker",
                default_width: 820,
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
            var title = new Adw.WindowTitle ("Codex Tracker", "%u accounts".printf (store.accounts.length));
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

            // Preferences Page
            pref_page = new Adw.PreferencesPage ();
            main_stack.add_named (pref_page, "cards");

            box.append (main_stack);
            set_content (box);
        }

        private void populate_cards () {
            if (pref_group != null) {
                pref_page.remove (pref_group);
            }
            pref_group = new Adw.PreferencesGroup ();
            pref_page.add (pref_group);
            
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
                pref_group.add (row);
                account_rows[i] = row;
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
