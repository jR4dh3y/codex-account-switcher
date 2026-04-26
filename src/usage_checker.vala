/* usage_checker.vala - Check Codex usage via ChatGPT backend API */

namespace CodexTracker {

    private const string USAGE_URL = "https://chatgpt.com/backend-api/wham/usage";

    public class UsageChecker : Object {
        private Soup.Session session;
        private AuthManager auth_manager;

        public UsageChecker (AuthManager auth_manager) {
            this.auth_manager = auth_manager;
            session = new Soup.Session ();
        }

        public async bool check_usage (AccountData account) {
            try {
                var msg = new Soup.Message ("GET", USAGE_URL);
                msg.request_headers.append ("Authorization", "Bearer %s".printf (account.access_token));
                msg.request_headers.append ("User-Agent", "codex-multi-account-switcher/0.1");

                if (account.account_id != "")
                    msg.request_headers.append ("ChatGPT-Account-Id", account.account_id);

                var response_bytes = yield session.send_and_read_async (msg, Priority.DEFAULT, null);
                var response_str = (string) response_bytes.get_data ();

                if (msg.status_code == 401 || msg.status_code == 403) {
                    bool refreshed = yield auth_manager.refresh_token (account);
                    if (refreshed) {
                        return yield check_usage (account);
                    }
                    account.usage_status = "error";
                    account.error_message = "Session expired. Remove and re-add account.";
                    account.last_checked = get_timestamp ();
                    return false;
                }

                if (msg.status_code != 200) {
                    account.usage_status = "error";
                    account.error_message = "HTTP %u".printf (msg.status_code);
                    account.usage_raw_json = response_str;
                    account.last_checked = get_timestamp ();
                    return false;
                }

                account.usage_raw_json = response_str;
                parse_usage_response (account, response_str);
                account.last_checked = get_timestamp ();
                return true;

            } catch (Error e) {
                account.usage_status = "error";
                account.error_message = e.message;
                account.last_checked = get_timestamp ();
                return false;
            }
        }

        private void parse_usage_response (AccountData account, string json_str) {
            account.usage_windows = new GenericArray<UsageWindow> ();

            try {
                var parser = new Json.Parser ();
                parser.load_from_data (json_str);

                var root = parser.get_root ();
                if (root == null) {
                    account.usage_status = "available";
                    return;
                }

                var obj = root.get_object ();

                // Extract top-level info
                if (obj.has_member ("plan_type"))
                    account.plan_type = obj.get_string_member ("plan_type");
                if (obj.has_member ("email"))
                    account.email = obj.get_string_member ("email");

                // Parse rate_limit object — this is the real structure!
                // {
                //   "rate_limit": {
                //     "allowed": true,
                //     "limit_reached": false,
                //     "primary_window": {
                //       "used_percent": 100,
                //       "limit_window_seconds": 604800,
                //       "reset_after_seconds": 330486,
                //       "reset_at": 1777536586
                //     },
                //     "secondary_window": null
                //   }
                // }

                if (obj.has_member ("rate_limit")) {
                    var rl_node = obj.get_member ("rate_limit");
                    if (rl_node != null && rl_node.get_node_type () == Json.NodeType.OBJECT) {
                        var rl = rl_node.get_object ();

                        if (rl.has_member ("allowed"))
                            account.is_allowed = rl.get_boolean_member ("allowed");
                        if (rl.has_member ("limit_reached"))
                            account.limit_reached = rl.get_boolean_member ("limit_reached");

                        // Primary window
                        if (rl.has_member ("primary_window")) {
                            var pw_node = rl.get_member ("primary_window");
                            if (pw_node != null && pw_node.get_node_type () == Json.NodeType.OBJECT) {
                                var w = parse_rate_window ("Primary", pw_node.get_object ());
                                account.usage_windows.add (w);
                            }
                        }

                        // Secondary window
                        if (rl.has_member ("secondary_window")) {
                            var sw_node = rl.get_member ("secondary_window");
                            if (sw_node != null && sw_node.get_node_type () == Json.NodeType.OBJECT) {
                                var w = parse_rate_window ("Secondary", sw_node.get_object ());
                                account.usage_windows.add (w);
                            }
                        }
                    }
                }

                // Parse additional_rate_limits array
                if (obj.has_member ("additional_rate_limits")) {
                    var arl_node = obj.get_member ("additional_rate_limits");
                    if (arl_node != null && arl_node.get_node_type () == Json.NodeType.ARRAY) {
                        var arr = arl_node.get_array ();
                        for (uint i = 0; i < arr.get_length (); i++) {
                            var elem = arr.get_element (i);
                            if (elem.get_node_type () == Json.NodeType.OBJECT) {
                                var limit_obj = elem.get_object ();
                                string feat_name = "Extra";
                                if (limit_obj.has_member ("metered_feature"))
                                    feat_name = limit_obj.get_string_member ("metered_feature");
                                var w = parse_rate_window (feat_name, limit_obj);
                                account.usage_windows.add (w);
                            }
                        }
                    }
                }

                // Parse code_review_rate_limit
                if (obj.has_member ("code_review_rate_limit")) {
                    var cr_node = obj.get_member ("code_review_rate_limit");
                    if (cr_node != null && cr_node.get_node_type () == Json.NodeType.OBJECT) {
                        var w = parse_rate_window ("Code Review", cr_node.get_object ());
                        account.usage_windows.add (w);
                    }
                }

                // Determine overall status
                if (account.limit_reached || !account.is_allowed) {
                    account.usage_status = "exhausted";
                } else {
                    // Check all windows
                    bool any_low = false;
                    for (uint i = 0; i < account.usage_windows.length; i++) {
                        var w = account.usage_windows[i];
                        if (w.percent_left <= 0) {
                            account.usage_status = "exhausted";
                            account.error_message = "";
                            return;
                        } else if (w.percent_left <= 20) {
                            any_low = true;
                        }
                    }
                    account.usage_status = any_low ? "low" : "available";
                }

                account.error_message = "";

            } catch (Error e) {
                warning ("Failed to parse usage: %s", e.message);
                account.usage_status = "error";
                account.error_message = "Parse error: %s".printf (e.message);
            }
        }

        private UsageWindow parse_rate_window (string name, Json.Object obj) {
            var w = new UsageWindow ();
            w.name = name;

            if (obj.has_member ("used_percent"))
                w.used_percent = obj.get_double_member ("used_percent");

            if (obj.has_member ("limit_window_seconds"))
                w.limit_window_seconds = (int) obj.get_int_member ("limit_window_seconds");

            if (obj.has_member ("reset_after_seconds"))
                w.reset_after_seconds = (int) obj.get_int_member ("reset_after_seconds");

            if (obj.has_member ("reset_at"))
                w.reset_at_epoch = obj.get_int_member ("reset_at");

            return w;
        }

        private string get_timestamp () {
            var now = new DateTime.now_local ();
            return now.format ("%H:%M:%S");
        }
    }
}
