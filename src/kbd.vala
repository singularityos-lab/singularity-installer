using Gee;

namespace Singularity.Apps {

    public class KbdLayouts : Object {

        private class Entry : Object {
            public string id;
            public string label;
            public Entry (string id, string label) { this.id = id; this.label = label; }
        }

        public static HashMap<string, string> populate (Singularity.Widgets.SectionedList list) {
            var labels = new HashMap<string, string> ();
            var iso = load_iso ();
            var groups = new HashMap<string, ArrayList<Entry>> ();
            var lang_order = new ArrayList<string> ();

            Xml.Doc* doc = Xml.Parser.parse_file ("/usr/share/X11/xkb/rules/evdev.xml");
            if (doc == null) return labels;

            Xml.Node* root = doc->get_root_element ();
            Xml.Node* layout_list = (root != null) ? find_child (root, "layoutList") : null;
            if (layout_list != null) {
                for (Xml.Node* lay = layout_list->children; lay != null; lay = lay->next) {
                    if (lay->type != Xml.ElementType.ELEMENT_NODE || lay->name != "layout") continue;
                    Xml.Node* ci = find_child (lay, "configItem");
                    if (ci == null) continue;

                    string name = child_text (ci, "name");
                    string desc = child_text (ci, "description");
                    if (name == "") continue;

                    string iso_code = "";
                    Xml.Node* ll = find_child (ci, "languageList");
                    if (ll != null) iso_code = child_text (ll, "iso639Id");

                    string lang = (iso_code != "" && iso.has_key (iso_code)) ? iso.get (iso_code) : desc;

                    if (!groups.has_key (lang)) {
                        groups.set (lang, new ArrayList<Entry> ());
                        lang_order.add (lang);
                    }
                    var g = groups.get (lang);
                    g.add (new Entry (name, desc));

                    Xml.Node* vl = find_child (lay, "variantList");
                    if (vl != null) {
                        for (Xml.Node* v = vl->children; v != null; v = v->next) {
                            if (v->type != Xml.ElementType.ELEMENT_NODE || v->name != "variant") continue;
                            Xml.Node* vci = find_child (v, "configItem");
                            if (vci == null) continue;
                            string vname = child_text (vci, "name");
                            string vdesc = child_text (vci, "description");
                            if (vname == "") continue;
                            g.add (new Entry (name + "+" + vname, vdesc));
                        }
                    }
                }
            }
            delete doc;

            lang_order.sort ((a, b) => a.collate (b));
            foreach (var lang in lang_order) {
                list.add_section (lang);
                foreach (var e in groups.get (lang)) {
                    list.add_item (e.id, e.label);
                    labels.set (e.id, e.label);
                }
            }
            return labels;
        }

        private static HashMap<string, string> load_iso () {
            var map = new HashMap<string, string> ();
            try {
                var parser = new Json.Parser ();
                parser.load_from_file ("/usr/share/iso-codes/json/iso_639-3.json");
                var obj = parser.get_root ().get_object ();
                var arr = obj.get_array_member ("639-3");
                arr.foreach_element ((a, i, node) => {
                    var o = node.get_object ();
                    string nm = o.has_member ("name") ? o.get_string_member ("name") : "";
                    if (nm == "") return;
                    if (o.has_member ("alpha_3")) map.set (o.get_string_member ("alpha_3"), nm);
                    if (o.has_member ("alpha_2")) map.set (o.get_string_member ("alpha_2"), nm);
                });
            } catch (Error e) { }
            return map;
        }

        private static Xml.Node* find_child (Xml.Node* parent, string name) {
            for (Xml.Node* n = parent->children; n != null; n = n->next) {
                if (n->type == Xml.ElementType.ELEMENT_NODE && n->name == name) return n;
            }
            return null;
        }

        private static string child_text (Xml.Node* parent, string name) {
            Xml.Node* c = find_child (parent, name);
            if (c == null) return "";
            string? t = c->get_content ();
            return (t == null) ? "" : t.strip ();
        }
    }
}
