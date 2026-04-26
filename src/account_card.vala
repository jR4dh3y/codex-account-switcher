/* account_card.vala - ExpanderRow Layout */

namespace CodexTracker {

    public class AccountRow : Adw.ExpanderRow {
        private Gtk.Button btn_refresh;
        private Gtk.Spinner spinner;

        private Adw.Avatar avatar;
        private Gtk.ProgressBar primary_bar;
        private Gtk.Label primary_pct;
        
        private Adw.ActionRow error_row;
        private Gtk.Label error_label;

        public AccountData account { get; private set; }
        public uint account_index { get; set; }

        public signal void refresh_requested (uint index);
        public signal void remove_requested (uint index);
        public signal void rename_requested (uint index);
        public signal void use_in_codex_requested (uint index);

        public AccountRow (AccountData account, uint index) {
            Object ();
            this.account = account;
            this.account_index = index;

            build_ui ();
            update_display ();
        }

        private void build_ui () {
            // Prefix: Avatar
            avatar = new Adw.Avatar (40, "", true);
            add_prefix (avatar);

            // Suffix: Spinner + Progress Bar
            var suffix_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            suffix_box.valign = Gtk.Align.CENTER;

            spinner = new Gtk.Spinner ();
            suffix_box.append (spinner);

            var progress_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            progress_box.valign = Gtk.Align.CENTER;
            
            primary_bar = new Gtk.ProgressBar ();
            primary_bar.valign = Gtk.Align.CENTER;
            primary_bar.width_request = 100;
            
            primary_pct = new Gtk.Label ("0%");
            primary_pct.width_chars = 4;
            primary_pct.halign = Gtk.Align.END;

            progress_box.append (primary_bar);
            progress_box.append (primary_pct);

            suffix_box.append (progress_box);
            add_suffix (suffix_box);

            // Error row (hidden by default)
            error_row = new Adw.ActionRow ();
            error_row.visible = false;
            
            error_label = new Gtk.Label ("");
            error_label.add_css_class ("error");
            error_label.halign = Gtk.Align.START;
            error_label.wrap = true;
            error_label.margin_top = 8;
            error_label.margin_bottom = 8;
            error_label.margin_start = 12;
            error_label.margin_end = 12;
            
            error_row.add_prefix (error_label);
            add_row (error_row);

            // Actions row (expandable part)
            var actions_row = new Adw.ActionRow ();
            actions_row.title = "Actions";
            
            var actions_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            actions_box.valign = Gtk.Align.CENTER;

            btn_refresh = new Gtk.Button.with_label ("Refresh");
            btn_refresh.clicked.connect (() => refresh_requested (account_index));
            actions_box.append (btn_refresh);

            var btn_rename = new Gtk.Button.with_label ("Rename");
            btn_rename.clicked.connect (() => rename_requested (account_index));
            actions_box.append (btn_rename);

            var btn_use = new Gtk.Button.with_label ("Use in Codex");
            btn_use.add_css_class ("suggested-action");
            btn_use.clicked.connect (() => use_in_codex_requested (account_index));
            actions_box.append (btn_use);
            
            var btn_details = new Gtk.Button.with_label ("API Response");
            btn_details.clicked.connect (show_details);
            actions_box.append (btn_details);

            var btn_remove = new Gtk.Button.with_label ("Remove");
            btn_remove.add_css_class ("destructive-action");
            btn_remove.clicked.connect (() => remove_requested (account_index));
            actions_box.append (btn_remove);

            actions_row.add_suffix (actions_box);
            add_row (actions_row);
        }

        public void update_display () {
            string display_name = account.label != "" ? account.label : "Account";
            this.title = display_name;
            if (avatar != null) {
                avatar.text = display_name;
            }
            
            // Subtitle string building
            string plan = account.plan_type;
            if (plan == "" || plan == "unknown")
                plan = "?";
            else
                plan = plan.substring (0, 1).up () + plan.substring (1);
            
            string sub = plan;
            if (account.email != "" && account.email != display_name) {
                sub = account.email + " • " + plan;
            }

            // Handle usage windows
            if (account.usage_windows.length > 0) {
                var primary = account.usage_windows[0];
                double fraction = primary.percent_left / 100.0;
                primary_bar.fraction = double.min (1.0, double.max (0.0, fraction));
                primary_pct.label = "%.0f%%".printf (primary.percent_left);

                string countdown = primary.get_reset_countdown ();
                if (countdown != "") {
                    string clean_reset = countdown;
                    if (clean_reset.has_prefix ("Resets ")) {
                        clean_reset = clean_reset.substring (7);
                    }
                    if (clean_reset.index_of ("Reset") == -1) {
                        sub += " • Resets " + clean_reset;
                    } else {
                        sub += " • " + clean_reset;
                    }
                }

                primary_bar.visible = true;
                primary_pct.visible = true;

                // Native styling for exhausted
                primary_bar.remove_css_class ("error");
                primary_pct.remove_css_class ("error");
                primary_bar.remove_css_class ("warning");
                primary_pct.remove_css_class ("warning");

                if (primary.percent_left <= 0) {
                    primary_bar.add_css_class ("error");
                    primary_pct.add_css_class ("error");
                } else if (primary.percent_left <= 20) {
                    primary_bar.add_css_class ("warning");
                    primary_pct.add_css_class ("warning");
                }
            } else {
                primary_bar.visible = false;
                primary_pct.visible = false;
            }

            this.subtitle = sub;

            // Error handling
            if (account.usage_status == "error" && account.error_message != "") {
                error_label.label = account.error_message;
                error_row.visible = true;
            } else {
                error_row.visible = false;
            }
        }

        public void set_loading (bool loading) {
            spinner.visible = loading;
            spinner.spinning = loading;
            if (loading) {
                btn_refresh.label = "Checking...";
                btn_refresh.sensitive = false;
            } else {
                btn_refresh.label = "Refresh";
                btn_refresh.sensitive = true;
            }
        }

        private void show_details () {
            var dialog = new Adw.MessageDialog (
                (Gtk.Window) get_root (),
                "Raw API Response",
                null
            );

            var text = account.usage_raw_json != ""
                ? account.usage_raw_json
                : "No data yet. Click refresh first.";

            var scrolled = new Gtk.ScrolledWindow ();
            scrolled.min_content_height = 250;
            scrolled.min_content_width = 450;

            var textview = new Gtk.TextView ();
            textview.buffer.text = text;
            textview.editable = false;
            textview.monospace = true;
            textview.wrap_mode = Gtk.WrapMode.WORD_CHAR;
            textview.margin_start = 8;
            textview.margin_end = 8;
            textview.margin_top = 8;
            textview.margin_bottom = 8;
            scrolled.child = textview;

            dialog.set_extra_child (scrolled);
            dialog.add_response ("close", "Close");
            dialog.present ();
        }
    }
}
