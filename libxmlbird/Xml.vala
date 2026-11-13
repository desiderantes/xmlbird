/*
    Copyright (C) 2014 Johan Mattsson

    This library is free software; you can redistribute it and/or modify 
    it under the terms of the GNU Lesser General Public License as 
    published by the Free Software Foundation; either version 3 of the 
    License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful, but 
    WITHOUT ANY WARRANTY; without even the implied warranty of 
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU 
    Lesser General Public License for more details.
*/

namespace B {

/** 
 * XML parser
 * 
 * XML parser written in Vala.
 * 
 * Example:
 * {{{
 * 
 * using B;
 * 
 * // Print all tags and attributes in an XML document. 
 * // Expected output:
 * // tag1
 * // tag2
 * // attribute1
 * public static int main (string[] arg) {
 * 	Tag root;
 * 	XmlParser parser;
 * 
 * 	parser = new XmlParser ("""<tag1><tag2 attribute1=""/></tag1>""");	
 * 
 * 	if (!parser.validate ()) {
 * 		warning ("Invalid XML.");
 * 		return 1;
 * 	}
 * 
 * 	root = parser.get_root_tag ();
 * 	print_tags (root);
 * 
 * 	return 0;
 * }
 * 
 * 
 * void print_tags (Tag tag) {
 * 	print (tag.get_name ());
 * 	print ("\n");
 * 	print_attributes (tag);
 * 
 * 	foreach (Tag t in tag) {
 * 		print_tags (t);
 * 	}
 * }
 * 
 * void print_attributes (Tag tag) {
 * 	Attributes attributes = tag.get_attributes ();
 * 	foreach (Attribute attribute in attributes) {
 * 		print (attribute.get_name ());
 * 		print ("\n");
 * 	}
 * }
 * 
 * }}}
 * 
 */
public class XmlParser : GLib.Object {
	Tag root;
	XmlData data;
	string input;
	bool error;
	
	/** 
	 * Create a new xml parser. 
	 * @param data valid xml data
	 */
	public XmlParser (string data) {
		this.input = data;
		this.data = new XmlData (data, data.length);		
		reparse ();
	}
		
	/** 
	 * Determine if the document can be parsed.
	 * @return true if the xml document is valid xml.
	 */
	public bool validate () {
		bool valid;
		
		if (this.data.error) {
			error = true;
			return false;
		} 
		
		reparse ();

		if (error) {
			return false;
		}
		
		valid = validate_tags (root);
			
		reparse ();
		return valid;
	}
	
	bool validate_tags (Tag tag) {
		Attributes attributes = tag.get_attributes ();
		
		foreach (Attribute a in attributes) {
			if (error || tag.has_failed () || a.get_name_length () == 0) {
				return false;
			}
		}
		
		foreach (Tag t in tag) {
			if (error || t.has_failed () || tag.has_failed ()) {
				return false;
			}
			
			if (!validate_tags (t)) {
				return false;
			}
		}

		if (tag.has_failed ()) {
			return false;
		}
				
		return true;		
	}
	
	/** 
	 * Obtain the root tag.
	 * @return the root tag. 
	 */
	public Tag get_root_tag () {
		reparse ();
		return root;
	}
	
	/** 
	 * Reset the parser and start from the beginning of the XML document. 
	 */
	internal void reparse () {
		int root_index;
		Tag container;
		XmlString content;
		XmlString empty;
		
		error = false;
		empty = new XmlString ("", 0);
		
		root_index = find_root_tag ();
		if (root_index == -1) {
			GLib.debug ("XML error: No root tag found.");
			error = true;
			root = new Tag.empty ();
		} else {
			content = data.substring (root_index);
			container = new Tag (empty, empty, content, data);
			root = container.get_next_tag ();
			
			if (container.has_failed ()) {
				error = true;
			}
		}
	}
	
	int find_root_tag () {
		int index = 0;
		int prev_index = 0;
		int modifier = 0;
		unichar c;
		
		while (true) {
			prev_index = index;
			if (!data.get_next_ascii_char (ref index, out c)) {
				break;
			}
			
			if (c == '<') {
				modifier = index;
				if (!data.get_next_ascii_char (ref modifier, out c)) {
					break;
				}
				if (c == '?') {
					int end_pi = data.index_of ("?>", modifier);
					if (end_pi == -1) {
						return -1;
					}
					index = end_pi + 2;
				} else if (c == '!') {
					if (data.substring (index).has_prefix ("!--")) {
						int end_comment = data.index_of ("-->", index + 3);
						if (end_comment == -1) {
							return -1;
						}
						index = end_comment + 3;
					} else if (data.substring (index).has_prefix ("![CDATA[")) {
						int end_cdata = data.index_of ("]]>", index + 8);
						if (end_cdata == -1) {
							return -1;
						}
						index = end_cdata + 3;
					} else {
						bool in_brackets = false;
						bool in_quote = false;
						unichar quote_char = '\0';
						int decl_idx = modifier;
						unichar dc;
						bool closed = false;
						while (data.get_next_ascii_char (ref decl_idx, out dc)) {
							if (in_quote) {
								if (dc == quote_char) {
									in_quote = false;
								}
							} else if (dc == '"' || dc == '\'') {
								in_quote = true;
								quote_char = dc;
							} else if (dc == '[') {
								in_brackets = true;
							} else if (dc == ']') {
								in_brackets = false;
							} else if (dc == '>' && !in_brackets) {
								closed = true;
								break;
							}
						}
						if (!closed) {
							return -1;
						}
						index = decl_idx;
					}
				} else if (c != '[') {
					return prev_index;
				}
			}
		}
		
		return -1;
	}

	/**
	 * Replace escaped character with plain text characters. 
	 * &amp; will be replaced with & etc.
	 */
	public static string decode (string s) {
		int len = s.length;
		if (len == 0) {
			return "";
		}

		unowned uint8[] bytes = s.data;
		var sb = new StringBuilder.sized (len);
		int start = 0;

		for (int i = 0; i < len; i++) {
			if (bytes[i] == '&') {
				string? replacement = null;
				int entity_len = 0;

				if (i + 6 <= len && Posix.memcmp (&bytes[i], "&quot;", 6) == 0) {
					replacement = "\"";
					entity_len = 6;
				} else if (i + 6 <= len && Posix.memcmp (&bytes[i], "&apos;", 6) == 0) {
					replacement = "'";
					entity_len = 6;
				} else if (i + 4 <= len && Posix.memcmp (&bytes[i], "&lt;", 4) == 0) {
					replacement = "<";
					entity_len = 4;
				} else if (i + 4 <= len && Posix.memcmp (&bytes[i], "&gt;", 4) == 0) {
					replacement = ">";
					entity_len = 4;
				} else if (i + 5 <= len && Posix.memcmp (&bytes[i], "&amp;", 5) == 0) {
					replacement = "&";
					entity_len = 5;
				}

				if (replacement != null) {
					if (i > start) {
						sb.append_len ((string) (&bytes[start]), i - start);
					}
					sb.append ((!) replacement);
					i += entity_len - 1;
					start = i + 1;
				}
			}
		}

		if (start < len) {
			sb.append_len ((string) (&bytes[start]), len - start);
		}

		return sb.str;
	}

	/**
	 * Replace ", ' < > and & with encoded characters.
	 */
	public static string encode (string s) {
		int len = s.length;
		if (len == 0) {
			return "";
		}

		unowned uint8[] bytes = s.data;
		var sb = new StringBuilder.sized (len);
		int start = 0;

		for (int i = 0; i < len; i++) {
			string? entity = null;
			switch (bytes[i]) {
			case '&':
				entity = "&amp;";
				break;
			case '"':
				entity = "&quot;";
				break;
			case '\'':
				entity = "&apos;";
				break;
			case '<':
				entity = "&lt;";
				break;
			case '>':
				entity = "&gt;";
				break;
			}

			if (entity != null) {
				if (i > start) {
					sb.append_len ((string) (&bytes[start]), i - start);
				}
				sb.append ((!) entity);
				start = i + 1;
			}
		}

		if (start < len) {
			sb.append_len ((string) (&bytes[start]), len - start);
		}

		return sb.str;
	}

}

}
