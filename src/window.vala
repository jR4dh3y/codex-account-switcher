/* window.vala - Main application window */

namespace CodexTracker {

    public class MainWindow : Adw.ApplicationWindow {
        private AccountStore store;
        private AuthManager auth_manager;
        private UsageChecker usage_checker;
        private Gtk.FlowBox flowbox;
        private Gtk.Stack main_stack;

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
            load_css ();
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
            btn_add.add_css_class ("suggested-action");
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
            empty_btn.add_css_class ("pill");
            empty_btn.clicked.connect (on_add_account);
            empty_box.append (empty_btn);

            var hint_label = new Gtk.Label ("Signs in via ChatGPT — no API key needed");
            hint_label.add_css_class ("dim-label");
            hint_label.add_css_class ("caption");
            empty_box.append (hint_label);

            empty.child = empty_box;
            main_stack.add_named (empty, "empty");

            // Cards view
            var scrolled = new Gtk.ScrolledWindow ();
            scrolled.vexpand = true;
            scrolled.hscrollbar_policy = Gtk.PolicyType.NEVER;

            flowbox = new Gtk.FlowBox ();
            flowbox.selection_mode = Gtk.SelectionMode.NONE;
            flowbox.homogeneous = false;
            flowbox.min_children_per_line = 1;
            flowbox.max_children_per_line = 4;
            flowbox.row_spacing = 4;
            flowbox.column_spacing = 4;
            flowbox.margin_start = 16;
            flowbox.margin_end = 16;
            flowbox.margin_top = 12;
            flowbox.margin_bottom = 16;

            scrolled.child = flowbox;
            main_stack.add_named (scrolled, "cards");

            box.append (main_stack);
            set_content (box);
        }

        private void load_css () {
            var css = new Gtk.CssProvider ();
            var css_data = """
                .account-name {
                    font-weight: 700;
                    font-size: 15px;
                }

                .error-label {
                    color: #c64600;
                    font-size: 12px;
                }

                /* Status dots */
                .status-icon { font-size: 20px; }
                .status-available { color: #2ec27e; }
                .status-low { color: #e5a50a; }
                .status-exhausted { color: #e01b24; }
                .status-error { color: #c64600; }
                .status-unknown { color: #9a9996; }

                /* Plan badges */
                .plan-badge {
                    font-size: 11px;
                    font-weight: 600;
                    padding: 2px 8px;
                    border-radius: 9999px;
                }
                .plan-free {
                    background: alpha(@accent_color, 0.15);
                    color: @accent_color;
                }
                .plan-plus {
                    background: alpha(#2ec27e, 0.15);
                    color: #2ec27e;
                }
                .plan-pro {
                    background: alpha(#e5a50a, 0.15);
                    color: #e5a50a;
                }
                .plan-team {
                    background: alpha(#3584e4, 0.15);
                    color: #3584e4;
                }

                /* Progress bars */
                progressbar trough {
                    min-height: 8px;
                    border-radius: 4px;
                }
                progressbar progress {
                    min-height: 8px;
                    border-radius: 4px;
                }
                .bar-available progress {
                    background: #2ec27e;
                }
                .bar-low progress {
                    background: #e5a50a;
                }
                .bar-exhausted progress {
                    background: #e01b24;
                }
                .bar-exhausted trough {
                    background: alpha(#e01b24, 0.15);
                }

                /* Overall status */
                .overall-status {
                    font-weight: 600;
                    font-size: 13px;
                }
                .overall-available { color: #2ec27e; }
                .overall-low { color: #e5a50a; }
                .overall-exhausted { color: #e01b24; }

                /* Percentage text */
                .pct-available { color: #2ec27e; font-weight: 600; }
                .pct-low { color: #e5a50a; font-weight: 600; }
                .pct-exhausted { color: #e01b24; font-weight: 600; }

                /* Reset countdown */
                .reset-label {
                    color: #9a9996;
                    font-style: italic;
                }

                /* Flow box children should not add extra padding */
                flowboxchild {
                    padding: 0;
                }
            """;
            css.load_from_data (css_data.data);
            Gtk.StyleContext.add_provider_for_display (
                Gdk.Display.get_default (),
                css,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );
        }

        private void populate_cards () {
            // Clear
            var child = flowbox.get_first_child ();
            while (child != null) {
                var next = child.get_next_sibling ();
                flowbox.remove (child);
                child = next;
            }

            if (store.accounts.length == 0) {
                main_stack.visible_child_name = "empty";
                return;
            }

            main_stack.visible_child_name = "cards";

            for (uint i = 0; i < store.accounts.length; i++) {
                var card = new AccountCard (store.accounts[i], i);
                card.refresh_requested.connect (on_refresh_single);
                card.remove_requested.connect (on_remove_account);
                card.rename_requested.connect (on_rename_account);
                flowbox.append (card);
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
            if (index >= store.accounts.length) return;

            var account = store.accounts[index];
            var child = flowbox.get_child_at_index ((int) index);
            if (child == null) return;

            var card = child.get_child () as AccountCard;
            if (card == null) return;

            card.set_loading (true);

            usage_checker.check_usage.begin (account, (obj, res) => {
                usage_checker.check_usage.end (res);
                card.update_display ();
                card.set_loading (false);
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
