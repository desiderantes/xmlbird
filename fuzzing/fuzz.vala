namespace B {

void add_tag (StringBuilder content, XmlElement tag) {
	content.append (tag.get_name ());
	content.append (" ");
	
	foreach (Attribute a in tag.get_attributes ()) {
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
		
		var parser = new XmlTree (xml);
		if (parser.validate ()) {
			var root = parser.get_root ();
			var content = new StringBuilder ();
			add_tag (content, root);
		}
	}
	
	return 0;
}

}
