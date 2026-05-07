/* account_card.vala - ExpanderRow Layout */

namespace CodexTracker {

    public class AccountRow : Adw.ExpanderRow {
        private Gtk.Button btn_refresh;
        private Gtk.Spinner spinner;

        private Adw.Avatar avatar;
        private Gtk.ProgressBar primary_bar;
        private Gtk.Label primary_pct;
        private Gtk.Box active_badge;
        private Gtk.Button btn_use;

        private Adw.ActionRow error_row;
        private Gtk.Label error_label;
        private Adw.ActionRow five_hour_usage_row;
        private Gtk.ProgressBar five_hour_bar;
        private Gtk.Label five_hour_pct;
        private Gtk.Label five_hour_reset;
        private Adw.ActionRow weekly_usage_row;
        private Gtk.ProgressBar weekly_bar;
        private Gtk.Label weekly_pct;
        private Gtk.Label weekly_reset;

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
            this.use_markup = true;

            // Prefix: Avatar
            avatar = new Adw.Avatar (40, "", true);
            add_prefix (avatar);

            // Suffix: Spinner + Progress Bar
            var suffix_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            suffix_box.valign = Gtk.Align.CENTER;

            spinner = new Gtk.Spinner ();
            suffix_box.append (spinner);

            // Active badge (hidden by default)
            active_badge = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
            active_badge.valign = Gtk.Align.CENTER;
            active_badge.visible = false;

            var active_icon = new Gtk.Image.from_icon_name ("object-select-symbolic");
            active_icon.pixel_size = 16;
            active_icon.add_css_class ("success");
            active_badge.append (active_icon);

            var active_label = new Gtk.Label ("Active");
            active_label.add_css_class ("caption");
            active_label.add_css_class ("success");
            active_badge.append (active_label);

            suffix_box.append (active_badge);

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

            five_hour_usage_row = create_usage_row (
                "5h usage",
                out five_hour_bar,
                out five_hour_pct,
                out five_hour_reset
            );
            add_row (five_hour_usage_row);

            weekly_usage_row = create_usage_row (
                "Weekly usage",
                out weekly_bar,
                out weekly_pct,
                out weekly_reset
            );
            add_row (weekly_usage_row);

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

            btn_use = new Gtk.Button.with_label ("Use in Codex");
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

        private Adw.ActionRow create_usage_row (
            string title,
            out Gtk.ProgressBar bar,
            out Gtk.Label pct,
            out Gtk.Label reset
        ) {
            var row = new Adw.ActionRow ();
            row.title = title;
            row.visible = false;

            var usage_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            usage_box.valign = Gtk.Align.CENTER;

            bar = new Gtk.ProgressBar ();
            bar.valign = Gtk.Align.CENTER;
            bar.width_request = 140;
            usage_box.append (bar);

            pct = new Gtk.Label ("0%");
            pct.width_chars = 4;
            pct.halign = Gtk.Align.END;
            usage_box.append (pct);

            reset = new Gtk.Label ("");
            reset.add_css_class ("caption");
            reset.width_chars = 16;
            reset.halign = Gtk.Align.START;
            usage_box.append (reset);

            row.add_suffix (usage_box);
            return row;
        }

        public void update_display () {
            string display_name = account.label != "" ? account.label : "Account";
            this.title = "%s  %s".printf (
                Markup.escape_text (display_name),
                get_plan_markup ()
            );
            if (avatar != null) {
                avatar.text = display_name;
            }
            
            // Subtitle string building
            string sub = account.email != "" && account.email != display_name ? account.email : "";

            bool has_paid_usage_summary = false;
            if (is_plus_or_pro_plan ()) {
                UsageWindow? five_hour = find_usage_window_by_seconds (5 * 60 * 60);
                UsageWindow? weekly = find_usage_window_by_seconds (7 * 24 * 60 * 60);

                if (five_hour != null) {
                    sub = append_subtitle_part (sub, "5h %.0f%% left".printf (five_hour.percent_left));
                    has_paid_usage_summary = true;
                }

                if (weekly != null) {
                    sub = append_subtitle_part (sub, "Weekly %.0f%% left".printf (weekly.percent_left));
                    has_paid_usage_summary = true;
                }
            }

            // Handle usage windows
            if (account.usage_windows.length > 0) {
                var primary = get_header_usage_window ();
                double fraction = primary.percent_left / 100.0;
                primary_bar.fraction = double.min (1.0, double.max (0.0, fraction));
                primary_pct.label = "%.0f%%".printf (primary.percent_left);

                string countdown = primary.get_reset_countdown ();
                if (countdown != "" && !has_paid_usage_summary) {
                    string clean_reset = countdown;
                    if (clean_reset.has_prefix ("Resets ")) {
                        clean_reset = clean_reset.substring (7);
                    }
                    if (clean_reset.index_of ("Reset") == -1) {
                        sub = append_subtitle_part (sub, "Resets " + clean_reset);
                    } else {
                        sub = append_subtitle_part (sub, clean_reset);
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

            update_paid_usage_rows ();

            this.subtitle = sub;

            // Error handling
            if (account.usage_status == "error" && account.error_message != "") {
                error_label.label = account.error_message;
                error_row.visible = true;
            } else {
                error_row.visible = false;
            }
        }

        private void update_paid_usage_rows () {
            bool show_paid_windows = is_plus_or_pro_plan ();
            UsageWindow? five_hour = find_usage_window_by_seconds (5 * 60 * 60);
            UsageWindow? weekly = find_usage_window_by_seconds (7 * 24 * 60 * 60);

            five_hour_usage_row.visible = show_paid_windows && five_hour != null;
            weekly_usage_row.visible = show_paid_windows && weekly != null;

            if (five_hour != null)
                update_usage_row (five_hour_bar, five_hour_pct, five_hour_reset, five_hour);
            if (weekly != null)
                update_usage_row (weekly_bar, weekly_pct, weekly_reset, weekly);
        }

        private UsageWindow get_header_usage_window () {
            if (is_plus_or_pro_plan ()) {
                UsageWindow? five_hour = find_usage_window_by_seconds (5 * 60 * 60);
                if (five_hour != null)
                    return five_hour;
            }

            return account.usage_windows[0];
        }

        private UsageWindow? find_usage_window_by_seconds (int target_seconds) {
            for (uint i = 0; i < account.usage_windows.length; i++) {
                var window = account.usage_windows[i];
                int diff = window.limit_window_seconds - target_seconds;
                if (diff < 0)
                    diff = -diff;

                if (diff <= 60)
                    return window;
            }

            return null;
        }

        private string append_subtitle_part (string subtitle, string part) {
            if (subtitle == "")
                return part;

            return subtitle + " • " + part;
        }

        private string get_plan_markup () {
            string plan = normalize_plan_type ();
            string color = get_plan_color (plan);
            return "<span foreground=\"%s\">%s</span>".printf (
                color,
                Markup.escape_text (plan)
            );
        }

        private string normalize_plan_type () {
            string plan = account.plan_type.strip ();
            if (plan == "" || plan.down () == "unknown")
                return "?";

            return plan.substring (0, 1).up () + plan.substring (1).down ();
        }

        private string get_plan_color (string normalized_plan) {
            switch (normalized_plan.down ()) {
                case "free":
                    return "#8e8e93";
                case "go":
                    return "#2e7d32";
                case "plus":
                    return "#1c71d8";
                case "pro":
                    return "#9141ac";
                default:
                    return "#8e8e93";
            }
        }

        private bool is_plus_or_pro_plan () {
            string plan = account.plan_type.down ();
            return plan == "plus"
                || plan == "pro"
                || plan.index_of ("plus") >= 0
                || plan.index_of ("pro") >= 0;
        }

        private void update_usage_row (
            Gtk.ProgressBar bar,
            Gtk.Label pct,
            Gtk.Label reset,
            UsageWindow window
        ) {
            double fraction = window.percent_left / 100.0;
            bar.fraction = double.min (1.0, double.max (0.0, fraction));
            pct.label = "%.0f%%".printf (window.percent_left);
            reset.label = clean_reset_label (window.get_reset_countdown ());

            bar.remove_css_class ("error");
            pct.remove_css_class ("error");
            bar.remove_css_class ("warning");
            pct.remove_css_class ("warning");

            if (window.percent_left <= 0) {
                bar.add_css_class ("error");
                pct.add_css_class ("error");
            } else if (window.percent_left <= 20) {
                bar.add_css_class ("warning");
                pct.add_css_class ("warning");
            }
        }

        private string clean_reset_label (string countdown) {
            if (countdown == "")
                return "";

            if (countdown.has_prefix ("Resets "))
                return countdown.substring (7);

            return countdown;
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

        public void set_active (bool active) {
            active_badge.visible = active;
            if (active) {
                btn_use.label = "Active";
                btn_use.sensitive = false;
                btn_use.remove_css_class ("suggested-action");
            } else {
                btn_use.label = "Use in Codex";
                btn_use.sensitive = true;
                btn_use.add_css_class ("suggested-action");
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
