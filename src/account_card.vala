/* account_card.vala - Individual account card widget with progress bars */

namespace CodexTracker {

    public class AccountCard : Gtk.Box {
        private Gtk.Label label_name;
        private Gtk.Label label_email;
        private Gtk.Label label_plan;
        private Gtk.Label label_time;
        private Gtk.Label label_status_icon;
        private Gtk.Label label_error;
        private Gtk.Label label_overall;
        private Gtk.Box usage_box;
        private Gtk.Button btn_refresh;
        private Gtk.Spinner spinner;

        public AccountData account { get; private set; }
        public uint account_index { get; set; }

        public signal void refresh_requested (uint index);
        public signal void remove_requested (uint index);
        public signal void rename_requested (uint index);

        public AccountCard (AccountData account, uint index) {
            Object (
                orientation: Gtk.Orientation.VERTICAL,
                spacing: 0
            );

            this.account = account;
            this.account_index = index;

            build_ui ();
            update_display ();
        }

        private void build_ui () {
            add_css_class ("card");
            width_request = 280;

            // === Header: status + name + plan ===
            var header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            header.margin_start = 16;
            header.margin_end = 16;
            header.margin_top = 14;

            label_status_icon = new Gtk.Label ("○");
            label_status_icon.add_css_class ("status-icon");
            label_status_icon.valign = Gtk.Align.START;
            header.append (label_status_icon);

            var name_col = new Gtk.Box (Gtk.Orientation.VERTICAL, 2);
            name_col.hexpand = true;

            label_name = new Gtk.Label ("");
            label_name.add_css_class ("account-name");
            label_name.halign = Gtk.Align.START;
            label_name.ellipsize = Pango.EllipsizeMode.END;
            label_name.max_width_chars = 22;
            name_col.append (label_name);

            label_email = new Gtk.Label ("");
            label_email.add_css_class ("dim-label");
            label_email.add_css_class ("caption");
            label_email.halign = Gtk.Align.START;
            label_email.ellipsize = Pango.EllipsizeMode.END;
            label_email.max_width_chars = 26;
            name_col.append (label_email);

            header.append (name_col);

            label_plan = new Gtk.Label ("");
            label_plan.add_css_class ("plan-badge");
            label_plan.valign = Gtk.Align.START;
            header.append (label_plan);

            append (header);

            // === Overall status label ===
            label_overall = new Gtk.Label ("");
            label_overall.halign = Gtk.Align.START;
            label_overall.margin_start = 16;
            label_overall.margin_end = 16;
            label_overall.margin_top = 10;
            label_overall.add_css_class ("overall-status");
            append (label_overall);

            // === Usage bars section ===
            usage_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 10);
            usage_box.margin_start = 16;
            usage_box.margin_end = 16;
            usage_box.margin_top = 8;
            usage_box.margin_bottom = 6;
            append (usage_box);

            // Error label
            label_error = new Gtk.Label ("");
            label_error.add_css_class ("error-label");
            label_error.halign = Gtk.Align.START;
            label_error.wrap = true;
            label_error.margin_start = 16;
            label_error.margin_end = 16;
            label_error.visible = false;
            append (label_error);

            // Spinner
            spinner = new Gtk.Spinner ();
            spinner.visible = false;
            spinner.margin_top = 8;
            spinner.margin_bottom = 8;
            append (spinner);

            // Last checked
            label_time = new Gtk.Label ("");
            label_time.add_css_class ("dim-label");
            label_time.add_css_class ("caption");
            label_time.halign = Gtk.Align.START;
            label_time.margin_start = 16;
            label_time.margin_top = 4;
            label_time.margin_bottom = 8;
            append (label_time);

            // Separator + action buttons
            append (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));

            var btn_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            btn_row.homogeneous = true;

            btn_refresh = new Gtk.Button.from_icon_name ("view-refresh-symbolic");
            btn_refresh.tooltip_text = "Check usage";
            btn_refresh.add_css_class ("flat");
            btn_refresh.clicked.connect (() => refresh_requested (account_index));
            btn_row.append (btn_refresh);

            var btn_rename = new Gtk.Button.from_icon_name ("document-edit-symbolic");
            btn_rename.tooltip_text = "Rename";
            btn_rename.add_css_class ("flat");
            btn_rename.clicked.connect (() => rename_requested (account_index));
            btn_row.append (btn_rename);

            var btn_details = new Gtk.Button.from_icon_name ("dialog-information-symbolic");
            btn_details.tooltip_text = "Show raw API response";
            btn_details.add_css_class ("flat");
            btn_details.clicked.connect (show_details);
            btn_row.append (btn_details);

            var btn_remove = new Gtk.Button.from_icon_name ("user-trash-symbolic");
            btn_remove.tooltip_text = "Remove account";
            btn_remove.add_css_class ("flat");
            btn_remove.clicked.connect (() => remove_requested (account_index));
            btn_row.append (btn_remove);

            append (btn_row);
        }

        public void update_display () {
            // Name
            label_name.label = account.label != "" ? account.label : "Account";

            // Email
            if (account.email != "" && account.email != account.label) {
                label_email.label = account.email;
                label_email.visible = true;
            } else {
                label_email.visible = false;
            }

            // Plan badge
            string plan = account.plan_type;
            if (plan == "" || plan == "unknown")
                plan = "?";
            else
                plan = plan.substring (0, 1).up () + plan.substring (1);
            label_plan.label = plan;

            label_plan.remove_css_class ("plan-free");
            label_plan.remove_css_class ("plan-plus");
            label_plan.remove_css_class ("plan-pro");
            label_plan.remove_css_class ("plan-team");

            switch (account.plan_type) {
                case "free": label_plan.add_css_class ("plan-free"); break;
                case "plus": label_plan.add_css_class ("plan-plus"); break;
                case "pro": label_plan.add_css_class ("plan-pro"); break;
                case "team": label_plan.add_css_class ("plan-team"); break;
                default: label_plan.add_css_class ("plan-free"); break;
            }

            // Status icon
            update_status_icon ();

            // Overall status text
            update_overall_label ();

            // Usage progress bars
            rebuild_usage_bars ();

            // Error
            if (account.usage_status == "error" && account.error_message != "") {
                label_error.label = "⚠ " + account.error_message;
                label_error.visible = true;
            } else {
                label_error.visible = false;
            }

            // Last checked
            if (account.last_checked != "never")
                label_time.label = "Checked at %s".printf (account.last_checked);
            else
                label_time.label = "";
        }

        private void update_overall_label () {
            switch (account.usage_status) {
                case "available":
                    label_overall.label = "✓ Codex Available";
                    label_overall.remove_css_class ("overall-exhausted");
                    label_overall.remove_css_class ("overall-low");
                    label_overall.add_css_class ("overall-available");
                    label_overall.visible = true;
                    break;
                case "low":
                    label_overall.label = "⚡ Running Low";
                    label_overall.remove_css_class ("overall-available");
                    label_overall.remove_css_class ("overall-exhausted");
                    label_overall.add_css_class ("overall-low");
                    label_overall.visible = true;
                    break;
                case "exhausted":
                    label_overall.label = "✗ Limit Reached";
                    label_overall.remove_css_class ("overall-available");
                    label_overall.remove_css_class ("overall-low");
                    label_overall.add_css_class ("overall-exhausted");
                    label_overall.visible = true;
                    break;
                case "error":
                    label_overall.visible = false;
                    break;
                default:
                    label_overall.label = "Click ↻ to check usage";
                    label_overall.remove_css_class ("overall-available");
                    label_overall.remove_css_class ("overall-low");
                    label_overall.remove_css_class ("overall-exhausted");
                    label_overall.visible = true;
                    break;
            }
        }

        private void update_status_icon () {
            string[] classes = { "status-available", "status-low", "status-exhausted", "status-error", "status-unknown" };
            foreach (var cls in classes)
                label_status_icon.remove_css_class (cls);

            switch (account.usage_status) {
                case "available":
                    label_status_icon.label = "●";
                    label_status_icon.add_css_class ("status-available");
                    break;
                case "low":
                    label_status_icon.label = "●";
                    label_status_icon.add_css_class ("status-low");
                    break;
                case "exhausted":
                    label_status_icon.label = "●";
                    label_status_icon.add_css_class ("status-exhausted");
                    break;
                case "error":
                    label_status_icon.label = "●";
                    label_status_icon.add_css_class ("status-error");
                    break;
                default:
                    label_status_icon.label = "○";
                    label_status_icon.add_css_class ("status-unknown");
                    break;
            }
        }

        private void rebuild_usage_bars () {
            // Clear existing
            var child = usage_box.get_first_child ();
            while (child != null) {
                var next = child.get_next_sibling ();
                usage_box.remove (child);
                child = next;
            }

            if (account.usage_windows.length == 0)
                return;

            for (uint i = 0; i < account.usage_windows.length; i++) {
                var w = account.usage_windows[i];
                usage_box.append (build_usage_row (w));
            }
        }

        private Gtk.Widget build_usage_row (UsageWindow w) {
            var row = new Gtk.Box (Gtk.Orientation.VERTICAL, 4);

            // Top label: window name + percentage
            var top_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);

            // Combine name with window duration
            string display_name = w.name;
            string dur = w.get_window_duration ();
            if (dur != "")
                display_name += " (%s)".printf (dur);

            var name_label = new Gtk.Label (display_name);
            name_label.add_css_class ("caption");
            name_label.add_css_class ("dim-label");
            name_label.halign = Gtk.Align.START;
            name_label.hexpand = true;
            top_row.append (name_label);

            var pct_label = new Gtk.Label ("%.0f%% left".printf (w.percent_left));
            pct_label.add_css_class ("caption");

            // Color the percentage text
            if (w.percent_left <= 0)
                pct_label.add_css_class ("pct-exhausted");
            else if (w.percent_left <= 20)
                pct_label.add_css_class ("pct-low");
            else
                pct_label.add_css_class ("pct-available");

            top_row.append (pct_label);
            row.append (top_row);

            // Progress bar
            var bar = new Gtk.ProgressBar ();
            double fraction = w.percent_left / 100.0;
            bar.fraction = double.min (1.0, double.max (0.0, fraction));

            if (w.percent_left <= 0)
                bar.add_css_class ("bar-exhausted");
            else if (w.percent_left <= 20)
                bar.add_css_class ("bar-low");
            else
                bar.add_css_class ("bar-available");

            row.append (bar);

            // Reset countdown
            string reset_str = w.get_reset_countdown ();
            if (reset_str != "") {
                var reset_label = new Gtk.Label (reset_str);
                reset_label.add_css_class ("caption");
                reset_label.add_css_class ("reset-label");
                reset_label.halign = Gtk.Align.END;
                row.append (reset_label);
            }

            return row;
        }

        public void set_loading (bool loading) {
            spinner.visible = loading;
            spinner.spinning = loading;
            btn_refresh.sensitive = !loading;
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
