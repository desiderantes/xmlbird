using B;

public static int main (string[] arg) {
	B.Test t;
	
	t = new B.Test ("""<test1><inside attr="a" /></test1>""");
	t.test ("test1 inside attr a");

	t = new B.Test ("""<nesting><nested><nested><inside/></nested></nested></nesting>""");
	t.test ("nesting nested nested inside");

	t = new B.Test ("""<nesting><closed /><inside /></nesting>""");
	t.test ("nesting closed inside");
	
	t = new B.Test ("""<a><!-- Comment --><b /></a>""");
	t.test ("a b");

	t = new B.Test ("""<root><quote>"<a attr="b" />"</quote></root>""");
	t.test ("root quote a attr b");

	t = new B.Test ("""<single/>""");
	t.test ("single");

	t = new B.Test ("""<single_space />""");
	t.test ("single_space");
	
	string needs_encoding = "\"'<>&";
	string encoded = XmlParser.encode (needs_encoding);
	string decoded = XmlParser.decode (encoded);

	if (needs_encoding != decoded) {
		print (@"Xml encoding failed:$needs_encoding != $decoded\n");
		assert (false);
	} else {
		print (@"Xml encoding passed: $needs_encoding == $decoded\n");
	}
	
	t = new B.Test ("<svg><g id=\"one\" ><g><g></g><g /></g></g></svg>");
	t.test ("svg g id one g g g");

	test_comments_and_declarations ();
	test_attribute_mutation ();
	test_tree_mutation ();
	test_serialization ();

	if (arg.length > 1) {
		test_svg_file (arg[1]);
	}

	return 0;
}

void test_comments_and_declarations () {
	var p1 = new XmlTree ("""<?xml version="1.0" encoding="UTF-8"?>
<!-- comment with <fake> tag inside -->
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg viewBox="0 0 10 10"><!-- <ignored/> --><g id="ok"/></svg>""");
	assert (p1.validate ());
	var r1 = p1.get_root ();
	assert (r1.get_name () == "svg");
	assert (r1.get_attribute ("viewBox") == "0 0 10 10");
	int child_count = 0;
	foreach (XmlElement child in r1) {
		assert (child.get_name () == "g");
		assert (child.get_attribute ("id") == "ok");
		child_count++;
	}
	assert (child_count == 1);

	var p2 = new XmlTree ("""<!DOCTYPE svg [ <!ELEMENT svg ANY> ]><svg/>""");
	assert (p2.validate ());
	assert (p2.get_root ().get_name () == "svg");

	var p3 = new XmlTree ("""<!-- unclosed comment <svg/>""");
	assert (!p3.validate ());
	assert (p3.to_string () == "");

	var p4 = new XmlTree ("""<svg xmlns:="http://example.com"/>""");
	assert (!p4.validate ());

	var p5 = new XmlTree ("""<svg :="x"/>""");
	assert (!p5.validate ());

	// Comments containing matching/nested tags without whitespace
	var p6 = new XmlTree ("""<a><!--<a>--></a>""");
	assert (p6.validate ());
	assert (p6.get_root ().get_name () == "a");

	var p7 = new XmlTree ("""<a><!--</a>--><b/></a>""");
	assert (p7.validate ());
	int p7_children = 0;
	foreach (XmlElement child in p7.get_root ()) {
		assert (child.get_name () == "b");
		p7_children++;
	}
	assert (p7_children == 1);

	test_malformed_angle_brackets ();
}

void test_malformed_angle_brackets () {
	var lt_run = new StringBuilder ();
	for (int i = 0; i < 20000; i++) {
		lt_run.append_c ('<');
	}

	var p1 = new XmlTree (lt_run.str + "r><P");
	assert (!p1.validate ());

	var p2 = new XmlTree ("<a>" + lt_run.str + "r><P");
	assert (!p2.validate ());

	var nested_unclosed = new StringBuilder ("<a>");
	for (int i = 0; i < 5000; i++) {
		nested_unclosed.append ("<a ");
	}
	nested_unclosed.append ("></a>");
	var p3 = new XmlTree (nested_unclosed.str);
	assert (!p3.validate ());

	assert (!(new XmlTree ("<a><")).validate ());
	assert (!(new XmlTree ("<a><!--")).validate ());
	assert (!(new XmlTree ("<a><b<c/></a>")).validate ());
	assert (!(new XmlTree ("<a=\"1\"/>")).validate ());
	assert (!(new XmlTree ("<a><b></a>")).validate ());
	assert (!(new XmlTree ("<a><b><c attr x=\"1\"/></a>")).validate ());
	assert (!(new XmlTree ("<a b=\"unclosed")).validate ());

	// Single-quoted attributes containing angle brackets
	var sq = new XmlTree ("""<a x='1>2<3' y="4>5<6">ok</a>""");
	assert (sq.validate ());
	assert (sq.get_root ().get_attribute ("x") == "1>2<3");
	assert (sq.get_root ().get_attribute ("y") == "4>5<6");
	assert (sq.get_root ().get_content () == "ok");

	// Deeply nested valid XML (must complete linearly without O(D^2) slowdown)
	var deep_valid = new StringBuilder ();
	for (int i = 0; i < 600; i++) {
		deep_valid.append ("<a>");
	}
	for (int i = 0; i < 600; i++) {
		deep_valid.append ("</a>");
	}
	var deep_tree = new XmlTree (deep_valid.str);
	assert (deep_tree.validate ());

	// Excessively deep nesting (> MAX_DEPTH) must fail cleanly without stack overflow
	var too_deep = new StringBuilder ();
	for (int i = 0; i < 2500; i++) {
		too_deep.append ("<a>");
	}
	for (int i = 0; i < 2500; i++) {
		too_deep.append ("</a>");
	}
	assert (!(new XmlTree (too_deep.str)).validate ());
}

void test_attribute_mutation () {
	var tree = new XmlTree ("""<svg viewBox="0 0 100 100"><path/><g id="layer1" inkscape:label="Layer 1"/></svg>""");
	assert (tree.validate ());
	var root = tree.get_root ();

	// Case preservation
	assert (root.has_attribute ("viewBox"));
	assert (!root.has_attribute ("viewbox"));
	assert (root.get_attribute ("viewBox") == "0 0 100 100");
	assert (root.get_attribute ("viewbox") == null);

	root.set_attribute ("viewBox", "0 0 200 200");
	assert (root.get_attribute ("viewBox") == "0 0 200 200");

	XmlElement? path_el = null;
	XmlElement? g_el = null;
	foreach (XmlElement child in root) {
		if (child.get_name () == "path") {
			path_el = child;
		} else if (child.get_name () == "g") {
			g_el = child;
		}
	}
	assert (path_el != null);
	assert (g_el != null);

	// Setting attributes on an element whose attributes were initially empty
	var p = (!) path_el;
	assert (!p.has_attribute ("d"));
	p.set_attribute ("d", "M 0 0 L 10 10");
	p.set_attribute ("stroke", "black");
	assert (p.has_attribute ("d"));
	assert (p.get_attribute ("d") == "M 0 0 L 10 10");
	assert (p.get_attribute ("stroke") == "black");

	// Removing attributes and verifying Attributes iterator reflects updates
	assert (p.remove_attribute ("d"));
	assert (!p.remove_attribute ("d"));
	assert (!p.has_attribute ("d"));
	assert (p.get_attribute ("d") == null);
	int attr_count = 0;
	foreach (Attribute a in p.get_attributes ()) {
		assert (a.get_name () == "stroke");
		attr_count++;
	}
	assert (attr_count == 1);
	assert (p.remove_attribute ("stroke"));
	attr_count = 0;
	foreach (Attribute a in p.get_attributes ()) {
		if (a.get_name () != "") {
			attr_count++;
		}
	}
	assert (attr_count == 0);

	// Namespaced attributes
	var g = (!) g_el;
	assert (g.has_attribute ("label", "inkscape"));
	assert (!g.has_attribute ("label"));
	assert (g.get_attribute ("label", "inkscape") == "Layer 1");
	g.set_attribute ("label", "Main Layer", "inkscape");
	assert (g.get_attribute ("label", "inkscape") == "Main Layer");
	assert (g.remove_attribute ("label", "inkscape"));
	assert (!g.has_attribute ("label", "inkscape"));
	assert (g.get_attribute ("id") == "layer1");
}

void test_tree_mutation () {
	var tree = new XmlTree ("""<svg><sodipodi:namedview id="base"/><defs><linearGradient id="lg"/></defs><g id="keep"/></svg>""");
	assert (tree.validate ());
	var root = tree.get_root ();

	XmlElement? namedview = null;
	XmlElement? defs = null;
	XmlElement? lg = null;
	foreach (XmlElement child in root) {
		if (child.get_namespace () == "sodipodi" && child.get_name () == "namedview") {
			namedview = child;
		} else if (child.get_name () == "defs") {
			defs = child;
			foreach (XmlElement sub in child) {
				lg = sub;
			}
		}
	}
	assert (namedview != null);
	assert (defs != null);
	assert (lg != null);

	// Remove via element.remove()
	((!) namedview).remove ();
	assert (((!) namedview).get_parent () == null);
	// Idempotent second remove
	((!) namedview).remove ();

	// Removing the sole child clears inner XML so it serializes as self-closing <defs/>
	assert (((!) defs).remove_child ((!) lg));
	assert (!((!) defs).remove_child ((!) lg));
	assert (((!) defs).is_leaf ());
	assert (((!) defs).to_string () == "<defs/>");

	assert (tree.to_string () == """<svg><defs/><g id="keep"/></svg>""");
}

void test_serialization () {
	var tree = new XmlTree ("""<svg viewBox="0 0 10 10"><ns:item/><text>hello</text></svg>""");
	assert (tree.validate ());
	var root = tree.get_root ();

	foreach (XmlElement child in root) {
		if (child.get_name () == "item") {
			child.set_attribute ("label", "A & \"B\" <C>", "ns");
		}
	}

	var sb = new StringBuilder ();
	root.write_to (sb);
	string serialized = sb.str;
	assert (serialized == tree.to_string ());
	assert (serialized == """<svg viewBox="0 0 10 10"><ns:item ns:label="A &amp; &quot;B&quot; &lt;C&gt;"/><text>hello</text></svg>""");

	var reparsed = new XmlTree (serialized);
	assert (reparsed.validate ());

	// Non-UTF-8 bytes must not abort in encode/decode/to_string
	uint8[] raw_bytes = { 'a', '&', 0xff, '<', 'b', 0 };
	unowned string non_utf8 = (string) raw_bytes;
	string enc_raw = XmlParser.encode (non_utf8);
	assert (XmlParser.decode (enc_raw) == non_utf8);
}

void test_svg_file (string path) {
	string svg;
	try {
		FileUtils.get_contents (path, out svg);
	} catch (FileError e) {
		assert_not_reached ();
	}

	var tree = new XmlTree (svg);
	assert (tree.validate ());
	var root = tree.get_root ();
	assert (root.get_name () == "svg");
	assert (root.get_attribute ("viewBox") == "0 0 744.09448819 1052.3622047");

	var to_remove = new List<XmlElement> ();
	foreach (XmlElement child in root) {
		if (child.get_namespace () == "sodipodi" || child.get_name () == "metadata") {
			to_remove.append (child);
		}
	}
	assert (to_remove.length () == 2);
	foreach (XmlElement child in to_remove) {
		child.remove ();
	}

	string out_xml = tree.to_string ();
	assert (!out_xml.contains ("sodipodi:namedview"));
	assert (!out_xml.contains ("<metadata"));
	assert (out_xml.contains ("viewBox=\"0 0 744.09448819 1052.3622047\""));

	var reparsed = new XmlTree (out_xml);
	assert (reparsed.validate ());
	assert (reparsed.get_root ().get_attribute ("viewBox") == "0 0 744.09448819 1052.3622047");
}
