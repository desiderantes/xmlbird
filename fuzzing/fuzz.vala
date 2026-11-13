namespace B {

void add_tag (StringBuilder content, XmlElement tag) {
	if (tag.get_namespace () != "") {
		content.append (tag.get_namespace ());
		content.append (":");
	}
	content.append (tag.get_name ());
	content.append (" ");
	tag.get_parent ();
	tag.is_leaf ();
	
	foreach (Attribute a in tag.get_attributes ()) {
		if (a.get_namespace () != "") {
			content.append (a.get_namespace ());
			content.append (":");
		}
		content.append (a.get_name ());
		content.append (" ");
		content.append (a.get_content ());
		content.append (" ");
	}
	
	bool has_children = false;
	var it = tag.iterator ();
	if (it.next ()) {
		has_children = true;
	}
	
	if (!has_children && tag.get_content () != "") {
		content.append (tag.get_content ());
		content.append (" ");
	}
	
	foreach (XmlElement t in tag) {
		add_tag (content, t);
	}
}

void walk_raw_tag (StringBuilder content, Tag tag) {
	if (tag.get_namespace () != "") {
		content.append (tag.get_namespace ());
		content.append (":");
	}
	content.append (tag.get_name ());
	content.append (" ");

	foreach (Attribute a in tag.get_attributes ()) {
		if (a.get_namespace () != "") {
			content.append (a.get_namespace ());
			content.append (":");
		}
		content.append (a.get_name ());
		content.append (" ");
		content.append (a.get_content ());
		content.append (" ");
	}

	bool has_children = false;
	foreach (Tag t in tag) {
		has_children = true;
		walk_raw_tag (content, t);
	}

	if (!has_children && tag.get_content () != "") {
		content.append (tag.get_content ());
		content.append (" ");
	}
}

int main (string[] args) {
	if (args.length < 2) {
		stderr.printf (@"Usage: $(args[0]) FILE_NAME\n");
		return 1;
	}
	
	for (int i = 1; i < args.length; i++) {
		string filename = args[i];
		string xml;
		
		if (args.length > 2) {
			stdout.printf ("%s\n", filename);
		}
		
		try {
			FileUtils.get_contents (filename, out xml);
		} catch (FileError e) {
			stderr.printf ("Failed to read %s: %s\n", filename, e.message);
			return 1;
		}

		XmlParser.decode (xml);
		XmlParser.decode (XmlParser.encode (xml));

		var raw_parser = new XmlParser (xml);
		raw_parser.validate ();
		var raw_root = raw_parser.get_root_tag ();
		var raw_content = new StringBuilder ();
		walk_raw_tag (raw_content, raw_root);
		var tree_from_tag = new XmlTree.for_tag (raw_root);
		tree_from_tag.to_string ();
		
		var parser = new XmlTree (xml);
		var unvalidated_root = parser.get_root ();
		unvalidated_root.remove_child (new XmlElement.empty ());
		parser.to_string ();

		if (parser.validate ()) {
			var root = parser.get_root ();
			var content = new StringBuilder ();
			add_tag (content, root);

			root.set_attribute ("data-fuzzed", "1 & 2");
			root.has_attribute ("data-fuzzed");
			root.get_attribute ("data-fuzzed");
			root.remove_attribute ("data-fuzzed");

			root.set_attribute ("attr", "a < b", "ns");
			root.has_attribute ("attr", "ns");
			root.get_attribute ("attr", "ns");
			root.remove_attribute ("attr", "ns");

			string serialized = parser.to_string ();
			XmlParser.decode (serialized);
			var reparsed = new XmlTree (serialized);
			if (reparsed.validate ()) {
				var reparsed_root = reparsed.get_root ();
				var to_remove = new List<XmlElement> ();
				foreach (XmlElement child in reparsed_root) {
					if (child.get_namespace () == "sodipodi") {
						to_remove.append (child);
					}
				}
				foreach (XmlElement child in to_remove) {
					child.remove ();
				}
				reparsed.to_string ();
			}
		}
	}
	
	return 0;
}

}
