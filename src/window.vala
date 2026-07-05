using Gtk;
using Singularity;
using Singularity.Widgets;

namespace Singularity.Apps {

    public class InstallerWindow : Singularity.Widgets.Window {

        private string mode;
        private string[] seq;
        private int wizard_count;
        private int current = 0;

        private Gtk.Stack stack;
        private StepIsland island;

        private string[] languages = {
            "English (United States)", "Italiano", "Espanol",
            "Francais", "Deutsch", "Portugues (Brasil)"
        };

        private string[] disk_name = {};
        private string[] disk_size = {};
        private string[] disk_dev = {};
        private string[] disk_icons = {};

        private string sel_language;
        private string sel_keyboard = "";
        private string sel_keyboard_id = "";
        private Gee.HashMap<string, string> kbd_labels;
        private int sel_disk = -1;
        private Gtk.Button[] disk_btns = {};
        private Gtk.Image[] disk_checks = {};
        private Label disk_warning;

        private EntryRow name_row;
        private EntryRow user_row;
        private PasswordRow pass_row;
        private PasswordRow confirm_row;
        private EntryRow host_row;
        private SwitchRow login_row;
        private PreferencesGroup account_group;
        private PreferencesGroup summary_group;
        private bool user_edited = false;

        private Singularity.Widgets.CircularProgress ring;
        private Label install_status;
        private Label install_hint;
        private double progress = 0.0;
        private int hint_idx = 0;
        private uint tick_id = 0;
        private uint hint_id = 0;
        private string[] hints = {
            "Sinty OS boots from an immutable, verified root.",
            "The desktop is built in-house on GTK4 and labwc.",
            "A bad update can never leave the system unbootable."
        };

        public InstallerWindow (Gtk.Application app, string mode) {
            base (app);
            this.mode = mode;
            this.flat = true;
            sel_language = languages[0];

            if (mode == "oobe") {
                seq = { "welcome", "keyboard", "account", "review", "progress", "done" };
                set_title ("Set up " + os_name ());
            } else {
                seq = { "welcome", "disk", "review", "progress", "done" };
                set_title ("Install " + os_name ());
            }
            wizard_count = seq.length - 2;
            set_default_size (940, 680);

            load_disks ();
            build_ui ();
            go_to (0);

            close_request.connect (() => { stop_timers (); return false; });
        }


        private string? os_release (string key) {
            try {
                string content;
                if (!FileUtils.get_contents ("/etc/os-release", out content)) return null;
                foreach (string line in content.split ("\n")) {
                    if (line.has_prefix (key + "=")) {
                        return line.substring (key.length + 1).replace ("\"", "").strip ();
                    }
                }
            } catch (Error e) { }
            return null;
        }

        private string os_name () {
            string? n = os_release ("PRETTY_NAME");
            if (n == null || n == "") n = os_release ("NAME");
            return (n == null || n == "") ? "Sinty OS" : n;
        }

        private string vendor_icon_name () {
            string? logo = os_release ("LOGO");
            string? id = os_release ("ID");
            var theme = Gtk.IconTheme.get_for_display (Gdk.Display.get_default ());
            if (logo != null && logo != "" && theme.has_icon (logo)) return logo;
            if (id != null && id != "" && theme.has_icon (id)) return id;
            if (theme.has_icon ("emblem-singularity")) return "emblem-singularity";
            return "computer-symbolic";
        }

        private string title_for (string name) {
            switch (name) {
                case "welcome":  return "Welcome";
                case "keyboard": return "Keyboard";
                case "disk":     return "Disk";
                case "account":  return "Account";
                case "review":   return "Review";
                default:         return name;
            }
        }


        private void build_ui () {
            stack = new Gtk.Stack ();
            stack.hexpand = true;
            stack.vexpand = true;
            stack.transition_type = StackTransitionType.SLIDE_LEFT_RIGHT;
            stack.transition_duration = 220;

            foreach (var name in seq) {
                stack.add_named (build_page (name), name);
            }

            string[] titles = {};
            for (int i = 0; i < wizard_count; i++) titles += title_for (seq[i]);

            var overlay = new Gtk.Overlay ();
            overlay.set_child (stack);

            var close = new Singularity.Widgets.IconButton ("window-close-symbolic", "Close");
            close.halign = Align.END;
            close.valign = Align.START;
            close.margin_top = 10;
            close.margin_end = 12;
            close.clicked.connect (() => this.close ());
            overlay.add_overlay (close);

            island = new StepIsland (titles);
            island.next_clicked.connect (on_next);
            island.back_clicked.connect (() => { if (current > 0) go_to (current - 1); });
            overlay.add_overlay (island);

            set_content (overlay);
        }

        private Gtk.Widget build_page (string name) {
            switch (name) {
                case "welcome":  return page_welcome ();
                case "keyboard": return page_keyboard ();
                case "disk":     return page_disk ();
                case "account":  return page_account ();
                case "review":   return page_summary ();
                case "progress": return page_install ();
                case "done":     return page_done ();
                default:         return new Box (Orientation.VERTICAL, 0);
            }
        }

        private Gtk.Widget shell_page (Gtk.Box col, bool center) {
            col.halign = Align.CENTER;
            col.set_size_request (560, -1);
            col.margin_top = 48;
            col.margin_bottom = 120;
            if (center) col.valign = Align.CENTER;
            var scroll = new ScrolledWindow ();
            scroll.hscrollbar_policy = PolicyType.NEVER;
            scroll.hexpand = true;
            scroll.vexpand = true;
            scroll.set_child (col);
            return scroll;
        }

        private Gtk.Box page_header (string title, string subtitle) {
            var box = new Box (Orientation.VERTICAL, 6);
            box.halign = Align.CENTER;
            box.margin_bottom = 6;
            var t = new Label (title);
            t.add_css_class ("title-1");
            box.append (t);
            if (subtitle != "") {
                var s = new Label (subtitle);
                s.add_css_class ("dim-label");
                s.wrap = true;
                s.justify = Justification.CENTER;
                box.append (s);
            }
            return box;
        }


        private Gtk.Widget page_welcome () {
            var col = new Box (Orientation.VERTICAL, 18);

            var logo = new Image.from_icon_name (vendor_icon_name ());
            logo.pixel_size = 96;
            logo.halign = Align.CENTER;
            logo.add_css_class ("accent-color");
            col.append (logo);

            string sub = mode == "oobe"
                ? "Let's get this computer ready for you. It only takes a moment."
                : "This assistant will install the system on this computer.";
            col.append (page_header ("Welcome to " + os_name (), sub));

            var g = new PreferencesGroup ();
            var lang_row = new SelectionRow ("Language", languages, sel_language);
            lang_row.selected.connect ((v) => { sel_language = v; });
            g.add_row (lang_row);
            col.append (g);

            return shell_page (col, true);
        }

        private Gtk.Widget page_keyboard () {
            var col = new Box (Orientation.VERTICAL, 16);
            col.append (page_header ("Keyboard layout",
                "Pick your layout, grouped by language, and try it in the test field."));

            var g = new PreferencesGroup ();

            var list = new Singularity.Widgets.SectionedList ();
            list.margin_top = 6;
            list.margin_bottom = 6;
            list.margin_start = 6;
            list.margin_end = 6;
            kbd_labels = KbdLayouts.populate (list);
            list.selected.connect ((id) => {
                sel_keyboard_id = id;
                sel_keyboard = kbd_labels.has_key (id) ? kbd_labels.get (id) : id;
                refresh_island ();
            });
            g.add_row (list);
            var wrap = list.get_parent () as Gtk.ListBoxRow;
            if (wrap != null) { wrap.activatable = false; wrap.selectable = false; }

            var test_row = new EntryRow ("Test area");
            g.add_row (test_row);

            col.append (g);
            return shell_page (col, false);
        }

        private Gtk.Widget page_disk () {
            var col = new Box (Orientation.VERTICAL, 18);
            col.append (page_header ("Where to install",
                "Sinty OS installs a verified, read-only system image and uses the entire disk. The disk you choose will be completely erased."));

            var fb = new FlowBox ();
            fb.selection_mode = SelectionMode.NONE;
            fb.homogeneous = true;
            fb.column_spacing = 14;
            fb.row_spacing = 14;
            fb.halign = Align.CENTER;
            fb.max_children_per_line = 3;
            for (int i = 0; i < disk_name.length; i++) fb.append (make_disk_card (i));
            col.append (fb);

            disk_warning = new Label ("");
            disk_warning.add_css_class ("dim-label");
            disk_warning.add_css_class ("caption");
            disk_warning.halign = Align.CENTER;
            disk_warning.visible = false;
            col.append (disk_warning);

            return shell_page (col, false);
        }

        private Gtk.Widget make_disk_card (int i) {
            var btn = new Button ();
            btn.add_css_class ("disk-card");
            btn.set_size_request (170, 170);

            var box = new Box (Orientation.VERTICAL, 8);
            box.margin_top = 14;
            box.margin_bottom = 12;
            box.margin_start = 12;
            box.margin_end = 12;

            var img = new Image ();
            img.pixel_size = 56;
            img.halign = Align.CENTER;
            img.set_from_icon_name (icon_or ({ disk_icons[i] }, "drive-harddisk"));
            box.append (img);

            var name_lbl = new Label (disk_name[i]);
            name_lbl.halign = Align.CENTER;
            name_lbl.ellipsize = Pango.EllipsizeMode.END;
            name_lbl.max_width_chars = 14;
            box.append (name_lbl);

            var size_lbl = new Label (disk_size[i]);
            size_lbl.add_css_class ("dim-label");
            size_lbl.add_css_class ("caption");
            size_lbl.halign = Align.CENTER;
            box.append (size_lbl);

            btn.set_child (box);

            var check = new Image.from_icon_name ("object-select-symbolic");
            check.halign = Align.END;
            check.valign = Align.START;
            check.margin_top = 8;
            check.margin_end = 8;
            check.add_css_class ("accent-color");
            check.visible = false;

            var ov = new Overlay ();
            ov.set_child (btn);
            ov.add_overlay (check);

            btn.clicked.connect (() => select_disk (i));
            disk_btns += btn;
            disk_checks += check;

            var fbi = new FlowBoxChild ();
            fbi.add_css_class ("disk-card-child");
            fbi.focusable = false;
            fbi.set_child (ov);
            return fbi;
        }

        private void select_disk (int idx) {
            sel_disk = idx;
            for (int i = 0; i < disk_btns.length; i++) {
                if (i == idx) disk_btns[i].add_css_class ("selected");
                else disk_btns[i].remove_css_class ("selected");
                disk_checks[i].visible = (i == idx);
            }
            disk_warning.label = "All data on %s will be permanently erased.".printf (disk_name[idx]);
            disk_warning.visible = true;
            refresh_island ();
        }

        private Gtk.Widget page_account () {
            var col = new Box (Orientation.VERTICAL, 18);
            col.append (page_header ("Create your account",
                "This is the user you will sign in with."));

            account_group = new PreferencesGroup ("Account", "");
            name_row = new EntryRow ("Full name");
            user_row = new EntryRow ("Username");
            bool pin = Singularity.Runtime.is_sinty_os ();
            pass_row = new PasswordRow (pin ? "PIN" : "Password");
            confirm_row = new PasswordRow (pin ? "Confirm PIN" : "Confirm password");
            account_group.add_row (name_row);
            account_group.add_row (user_row);
            account_group.add_row (pass_row);
            account_group.add_row (confirm_row);
            col.append (account_group);

            var sys_group = new PreferencesGroup ("System");
            host_row = new EntryRow ("Computer name");
            host_row.text = "sinty";
            login_row = new SwitchRow (pin ? "Require my PIN to log in" : "Require my password to log in", null, true);
            sys_group.add_row (host_row);
            sys_group.add_row (login_row);
            col.append (sys_group);

            name_row.entry_changed.connect (() => {
                if (!user_edited) user_row.text = slugify (name_row.text);
                validate_account ();
            });
            user_row.entry_changed.connect (() => {
                user_edited = user_row.text != "";
                validate_account ();
            });
            pass_row.entry_changed.connect (validate_account);
            confirm_row.entry_changed.connect (validate_account);

            return shell_page (col, false);
        }

        private string slugify (string s) {
            var sb = new StringBuilder ();
            string lower = s.down ();
            int idx = 0;
            unichar c;
            while (lower.get_next_char (ref idx, out c)) {
                if (c.isalnum ()) sb.append_unichar (c);
            }
            return sb.str;
        }

        private bool account_valid () {
            return user_row != null
                && user_row.text.strip () != ""
                && pass_row.text != ""
                && pass_row.text == confirm_row.text;
        }

        private void validate_account () {
            if (confirm_row.text != "" && pass_row.text != confirm_row.text)
                account_group.description = Singularity.Runtime.is_sinty_os ()
                    ? "The PINs do not match." : "The passwords do not match.";
            else
                account_group.description = "";
            refresh_island ();
        }

        private Gtk.Widget page_summary () {
            var col = new Box (Orientation.VERTICAL, 18);
            col.append (page_header ("Review",
                "Confirm everything is right, then continue."));

            summary_group = new PreferencesGroup ();
            col.append (summary_group);

            var note = new Label ("This is a demo: it runs a simulation and changes nothing on this machine.");
            note.add_css_class ("dim-label");
            note.add_css_class ("caption");
            note.wrap = true;
            note.justify = Justification.CENTER;
            note.visible = !applying_real ();
            col.append (note);

            return shell_page (col, false);
        }

        private void build_summary () {
            summary_group.clear ();
            if (mode == "oobe") {
                string user = user_row.text.strip ();
                if (user == "") user = "(not set)";
                summary_group.add_row (new ActionRow ("Language", sel_language,
                    icon_or ({ "preferences-desktop-locale-symbolic" }, "dialog-information-symbolic")));
                summary_group.add_row (new ActionRow ("Keyboard",
                    sel_keyboard == "" ? "(default)" : sel_keyboard,
                    icon_or ({ "input-keyboard-symbolic" }, "emblem-system-symbolic")));
                summary_group.add_row (new ActionRow ("User", user,
                    icon_or ({ "avatar-default-symbolic", "system-users-symbolic" }, "user-home-symbolic")));
                summary_group.add_row (new ActionRow ("Computer name", host_row.text,
                    icon_or ({ "computer-symbolic" }, "network-server-symbolic")));
                summary_group.add_row (new ActionRow ("Login",
                    login_row.active ? "Password required" : "Automatic",
                    icon_or ({ "system-lock-screen-symbolic" }, "dialog-password-symbolic")));
            } else {
                string disk = sel_disk >= 0
                    ? "%s (%s)  will be erased".printf (disk_name[sel_disk], disk_size[sel_disk])
                    : "(none)";
                summary_group.add_row (new ActionRow ("Language", sel_language,
                    icon_or ({ "preferences-desktop-locale-symbolic" }, "dialog-information-symbolic")));
                summary_group.add_row (new ActionRow ("Disk", disk,
                    icon_or ({ "drive-harddisk-symbolic" }, "drive-harddisk-symbolic")));
            }
        }

        private string icon_or (string[] candidates, string fallback) {
            var t = Gtk.IconTheme.get_for_display (Gdk.Display.get_default ());
            foreach (var c in candidates) if (t.has_icon (c)) return c;
            return fallback;
        }

        private Gtk.Widget page_install () {
            var col = new Box (Orientation.VERTICAL, 22);
            col.halign = Align.CENTER;
            col.valign = Align.CENTER;
            col.set_size_request (560, -1);

            ring = new Singularity.Widgets.CircularProgress (148);
            ring.add_css_class ("accent-color");
            ring.halign = Align.CENTER;
            ring.fraction = 0.0;
            ring.label = "0%";
            col.append (ring);

            install_status = new Label ("Getting ready");
            install_status.add_css_class ("title-2");
            col.append (install_status);

            install_hint = new Label (hints[0]);
            install_hint.add_css_class ("dim-label");
            install_hint.wrap = true;
            install_hint.justify = Justification.CENTER;
            col.append (install_hint);

            return col;
        }

        private Gtk.Widget page_done () {
            var page = new Singularity.Widgets.StatusPage ();
            page.icon_name = "object-select-symbolic";
            if (mode == "oobe") {
                string user = user_row != null ? user_row.text.strip () : "";
                page.title = user != "" ? "You're all set, %s".printf (user) : "You're all set";
                page.description = "Your account is ready. Enjoy your new system.";
            } else {
                page.title = os_name () + " is ready";
                page.description = "Installation finished. Restart and remove the install media to boot into your new system.";
            }

            var actions = new Box (Orientation.HORIZONTAL, 10);
            actions.halign = Align.CENTER;
            actions.margin_top = 8;
            var primary = new Button.with_label (mode == "oobe" ? "Start using " + os_name () : "Restart now");
            primary.add_css_class ("suggested-action");
            primary.clicked.connect (() => this.close ());
            actions.append (primary);
            page.child = actions;

            return page;
        }


        private void on_next () {
            if (current < wizard_count) go_to (current + 1);
        }

        private void go_to (int index) {
            current = index;
            string name = seq[index];
            bool wizard = index < wizard_count;
            island.visible = wizard;
            if (wizard) island.step = index;

            if (name == "review") build_summary ();

            stack.set_visible_child_name (name);
            refresh_island ();

            if (name == "progress") start_apply ();
        }

        private void refresh_island () {
            string name = seq[current];
            island.back_visible = current >= 1 && current < wizard_count;
            if (name == "welcome") island.next_label = "Get started";
            else if (name == "review") island.next_label = (mode == "oobe") ? "Finish setup" : "Install Sinty OS";
            else island.next_label = "Next";
            island.next_enabled = step_valid (name);
        }

        private bool step_valid (string name) {
            if (name == "disk") return sel_disk >= 0;
            if (name == "account") return account_valid ();
            return true;
        }


        private string locale_for (string lang) {
            if (lang.has_prefix ("Italiano")) return "it_IT.UTF-8";
            if (lang.has_prefix ("Espanol")) return "es_ES.UTF-8";
            if (lang.has_prefix ("Francais")) return "fr_FR.UTF-8";
            if (lang.has_prefix ("Deutsch")) return "de_DE.UTF-8";
            if (lang.has_prefix ("Portugues")) return "pt_BR.UTF-8";
            return "en_US.UTF-8";
        }

        private string keymap_for (string id) {
            if (id == "") return "us";
            int plus = id.index_of ("+");
            return plus > 0 ? id.substring (0, plus) : id;
        }

        private void run_firstboot_if_real () {
            if (mode != "oobe") return;
            if (GLib.Environment.get_variable ("ATOM_OOBE_APPLY") != "1") return;
            try {
                var launcher = new GLib.SubprocessLauncher (
                    SubprocessFlags.STDIN_PIPE | SubprocessFlags.STDERR_MERGE);
                launcher.setenv ("OOBE_USERNAME", user_row.text.strip (), true);
                launcher.setenv ("OOBE_FULLNAME", name_row.text.strip (), true);
                launcher.setenv ("OOBE_HOSTNAME", host_row.text.strip (), true);
                launcher.setenv ("OOBE_LOCALE", locale_for (sel_language), true);
                launcher.setenv ("OOBE_KEYMAP", keymap_for (sel_keyboard_id), true);
                launcher.setenv ("OOBE_AUTOLOGIN", login_row.active ? "0" : "1", true);
                var proc = launcher.spawnv ({ "atom-firstboot" });
                proc.communicate_utf8 (pass_row.text, null, null, null);
            } catch (Error e) {
                warning ("firstboot backend failed: %s", e.message);
            }
        }

        private bool install_apply_real () {
            return GLib.Environment.get_variable ("ATOM_INSTALL_APPLY") == "1";
        }

        private bool applying_real () {
            return mode == "oobe"
                ? GLib.Environment.get_variable ("ATOM_OOBE_APPLY") == "1"
                : install_apply_real ();
        }

        private string read_first_line (string path) {
            try {
                string c;
                if (FileUtils.get_contents (path, out c)) {
                    int nl = c.index_of ("\n");
                    return (nl >= 0 ? c.substring (0, nl) : c).strip ();
                }
            } catch (Error e) { }
            return "";
        }

        private void load_disks () {
            if (!install_apply_real ()) {
                disk_name  = { "Samsung SSD 980 PRO", "WDC WD10EZEX", "SanDisk Ultra USB" };
                disk_size  = { "512 GB", "1.0 TB", "32 GB" };
                disk_dev   = { "/dev/nvme0n1", "/dev/sda", "/dev/sdb" };
                disk_icons = { "drive-harddisk-solidstate", "drive-harddisk", "drive-removable-media-usb" };
                return;
            }
            try {
                var dir = Dir.open ("/sys/block", 0);
                string[] names = {};
                string? e;
                while ((e = dir.read_name ()) != null) names += e;
                foreach (var dev in names) {
                    if (dev.has_prefix ("loop") || dev.has_prefix ("ram") || dev.has_prefix ("sr")
                        || dev.has_prefix ("zram") || dev.has_prefix ("dm-") || dev.has_prefix ("md")) continue;
                    string b = "/sys/block/" + dev;
                    int64 sectors = int64.parse (read_first_line (b + "/size"));
                    if (sectors <= 0) continue;
                    string model = read_first_line (b + "/device/model");
                    string rot = read_first_line (b + "/queue/rotational");
                    string rm = read_first_line (b + "/removable");
                    disk_dev   += "/dev/" + dev;
                    disk_name  += model != "" ? model : dev;
                    disk_size  += GLib.format_size (sectors * 512);
                    disk_icons += rm == "1" ? "drive-removable-media-usb"
                                  : rot == "0" ? "drive-harddisk-solidstate" : "drive-harddisk";
                }
            } catch (Error err) {
                warning ("disk scan: %s", err.message);
            }
        }

        private void start_apply () {
            progress = 0.0;
            hint_idx = 0;
            ring.fraction = 0.0;
            ring.label = "0%";
            set_stage (0.0);

            hint_id = Timeout.add (3400, () => {
                hint_idx = (hint_idx + 1) % hints.length;
                install_hint.label = hints[hint_idx];
                return true;
            });

            if (mode == "oobe") {
                run_firstboot_if_real ();
                simulate_progress ();
            } else if (install_apply_real ()) {
                run_install_real ();
            } else {
                simulate_progress ();
            }
        }

        private void simulate_progress () {
            int done_idx = seq.length - 1;
            tick_id = Timeout.add (50, () => {
                progress += 0.0035;
                if (progress >= 1.0) {
                    progress = 1.0;
                    ring.fraction = 1.0;
                    ring.label = "100%";
                    set_stage (1.0);
                    tick_id = 0;
                    Timeout.add (800, () => { go_to (done_idx); return false; });
                    return false;
                }
                ring.fraction = progress;
                ring.label = "%d%%".printf ((int) (progress * 100));
                set_stage (progress);
                return true;
            });
        }

        private void run_install_real () {
            if (sel_disk < 0) { install_status.label = "No disk selected"; return; }
            install_status.label = "Installing " + os_name ();
            progress = 0.05;
            ring.fraction = progress;
            tick_id = Timeout.add (120, () => {
                if (progress < 0.9) {
                    progress += 0.01;
                    ring.fraction = progress;
                    ring.label = "%d%%".printf ((int) (progress * 100));
                }
                return true;
            });
            try {
                var proc = new Subprocess (SubprocessFlags.STDERR_MERGE,
                    "atom-install", disk_dev[sel_disk], null);
                proc.wait_async.begin (null, (o, r) => {
                    bool ok = false;
                    try { proc.wait_async.end (r); ok = proc.get_successful (); } catch (Error e) {}
                    if (tick_id != 0) { Source.remove (tick_id); tick_id = 0; }
                    if (ok) {
                        ring.fraction = 1.0;
                        ring.label = "100%";
                        install_status.label = "Finishing up";
                        Timeout.add (700, () => { go_to (seq.length - 1); return false; });
                    } else {
                        install_status.label = "Installation failed";
                    }
                });
            } catch (Error e) {
                if (tick_id != 0) { Source.remove (tick_id); tick_id = 0; }
                install_status.label = "Installation failed";
                warning ("atom-install: %s", e.message);
            }
        }

        private void set_stage (double p) {
            string s;
            if (mode == "oobe") {
                if (p < 0.30)      s = "Creating your account";
                else if (p < 0.65) s = "Applying region and keyboard";
                else if (p < 0.90) s = "Configuring the session";
                else               s = "Finishing up";
            } else {
                if (p < 0.12)      s = "Preparing the disk";
                else if (p < 0.30) s = "Creating partitions";
                else if (p < 0.62) s = "Copying system files";
                else if (p < 0.80) s = "Installing the bootloader";
                else if (p < 0.94) s = "Applying your settings";
                else               s = "Finishing up";
            }
            if (install_status.label != s) install_status.label = s;
        }

        private void stop_timers () {
            if (tick_id != 0) { Source.remove (tick_id); tick_id = 0; }
            if (hint_id != 0) { Source.remove (hint_id); hint_id = 0; }
        }
    }
}
