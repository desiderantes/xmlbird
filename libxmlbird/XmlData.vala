/*
    Copyright (C) 2015 Johan Mattsson

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

internal class XmlData : XmlString {
	const int MAX_DEPTH = 2048;

	struct OpenTagEntry {
		public int token_index;
		public int name_start;
		public int name_length;
	}

	int* start_tags;
	int* close_tags;
	int tags_capacity;
	int tags_size;
	
	internal bool error = false;
	
	const char FIRST_BIT = 1 << 7;

	public XmlData (char* data, int length) {
		base (data, length);

		start_tags = null;
		close_tags = null;
		tags_capacity = 0;
		tags_size = 0;
		
		index_tags ();
	}
	
	~XmlData () {
		if (start_tags != null) {
			delete start_tags;
			start_tags = null;
		}
		if (close_tags != null) {
			delete close_tags;
			close_tags = null;
		}
	}
	
	public int get_index (XmlString start) {
		int offset = (int) ((size_t) start.data - (size_t) data);
		return offset;
	}
	
	public int find_closing_tag (int open_lt_offset) {
		int lower = 0;
		int upper = tags_size - 1;

		while (lower <= upper) {
			int i = lower + (upper - lower) / 2;
			int pos = start_tags[i];
			if (pos == open_lt_offset) {
				return close_tags[i];
			} else if (pos < open_lt_offset) {
				lower = i + 1;
			} else {
				upper = i - 1;
			}
		}

		return -1;
	}

	void index_tags () {
		int i = 0;
		char* d = data;
		var stack = new OpenTagEntry[64];
		int depth = 0;

		while (i < length) {
			if (d[i] != '<') {
				i++;
				continue;
			}

			int lt_pos = i;
			i++;
			if (i >= length) {
				add_tag (lt_pos, -1);
				break;
			}

			if (i + 3 <= length && d[i] == '!' && d[i + 1] == '-' && d[i + 2] == '-') {
				int comment_end = index_of ("-->", i + 3);
				if (comment_end == -1) {
					error = true;
					return;
				}
				i = comment_end + 3;
				continue;
			}

			if (depth == 0 && d[i] == '?') {
				int end_pi = index_of ("?>", i + 1);
				if (end_pi == -1) {
					return;
				}
				i = end_pi + 2;
				continue;
			}

			if (d[i] == '!') {
				if (depth == 0 && i + 8 <= length && Posix.strncmp ((string) (d + i), "![CDATA[", 8) == 0) {
					int end_cdata = index_of ("]]>", i + 8);
					if (end_cdata == -1) {
						return;
					}
					i = end_cdata + 3;
					continue;
				}

				if (depth == 0) {
					bool in_brackets = false;
					bool in_quote = false;
					char quote_char = '\0';
					int j = i + 1;
					bool closed = false;
					while (j < length) {
						char dc = d[j];
						if ((int) (dc & FIRST_BIT) == 0) {
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
								j++;
								break;
							}
						}
						j++;
					}
					if (!closed) {
						return;
					}
					i = j;
					continue;
				} else {
					int j = i + 1;
					while (j < length && d[j] != '>' && d[j] != '<') {
						j++;
					}
					if (j >= length || d[j] == '<') {
						return;
					}
					i = j + 1;
					continue;
				}
			}

			if (depth == 0 && d[i] == '[') {
				i++;
				continue;
			}

			bool is_closing = false;
			if (d[i] == '/') {
				is_closing = true;
				i++;
			}

			int name_start = i;
			while (i < length) {
				char c = d[i];
				if ((int) (c & FIRST_BIT) == 0) {
					if (c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '>' || c == '/') {
						break;
					}
					if (c == '<' || c == '=' || c == '"' || c == '\'') {
						return;
					}
				}
				i++;
			}

			int name_len = i - name_start;
			if (i >= length || name_len == 0) {
				return;
			}

			int j = i;
			bool found_gt = false;
			while (j < length) {
				char c = d[j];
				if ((int) (c & FIRST_BIT) == 0) {
					if (c == '>') {
						found_gt = true;
						break;
					}
					if (c == '<') {
						return;
					}
					if (c == '"' || c == '\'') {
						char q = c;
						j++;
						while (j < length && d[j] != q) {
							j++;
						}
						if (j >= length) {
							GLib.debug ("XML error: No end quote.");
							error = true;
							return;
						}
					}
				}
				j++;
			}

			if (!found_gt) {
				return;
			}

			int gt_pos = j;

			if (is_closing) {
				for (int w = i; w < gt_pos; w++) {
					char wc = d[w];
					if (!(wc == ' ' || wc == '\t' || wc == '\n' || wc == '\r')) {
						return;
					}
				}
				if (depth == 0) {
					return;
				}
				OpenTagEntry top = stack[depth - 1];
				if (top.name_length == name_len &&
					Posix.memcmp (d + top.name_start, d + name_start, name_len) == 0) {
					close_tags[top.token_index] = lt_pos;
					depth--;
				} else {
					return;
				}
			} else {
				bool self_closing = false;
				int k = gt_pos - 1;
				while (k >= name_start) {
					char c = d[k];
					if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
						k--;
						continue;
					}
					if (c == '/') {
						self_closing = true;
					}
					break;
				}

				int token_idx = tags_size;
				if (!add_tag (lt_pos, -1)) {
					return;
				}

				if (!self_closing) {
					if (depth >= MAX_DEPTH) {
						GLib.debug ("XML error: Maximum nesting depth exceeded.");
						error = true;
						return;
					}
					if (depth == stack.length) {
						stack.resize (stack.length * 2);
					}
					stack[depth] = OpenTagEntry () {
						token_index = token_idx,
						name_start = name_start,
						name_length = name_len
					};
					depth++;
				}
			}

			i = gt_pos + 1;
		}
	}
	
	bool add_tag (int index, int close_index) {
		if (unlikely (tags_size == tags_capacity)) {
			if (!increase_capacity ()) {
				return false;
			}
		}
		
		start_tags[tags_size] = index;
		close_tags[tags_size] = close_index;
		tags_size++;
		return true;
	}

	bool increase_capacity () {
		int new_capacity;
		if (tags_capacity == 0) {
			new_capacity = 512;
		} else if (tags_capacity <= int.MAX / 2) {
			new_capacity = tags_capacity * 2;
		} else {
			GLib.warning ("Can not allocate xml data buffer.");
			error = true;
			return false;
		}

		int* new_starts = (int*) try_malloc (new_capacity * sizeof (int));
		int* new_closes = (int*) try_malloc (new_capacity * sizeof (int));
		
		if (unlikely (new_starts == null || new_closes == null)) {
			if (new_starts != null) {
				delete new_starts;
			}
			if (new_closes != null) {
				delete new_closes;
			}
			tags_capacity = 0;
			
			if (start_tags != null) {
				delete start_tags;
				start_tags = null;
			}
			if (close_tags != null) {
				delete close_tags;
				close_tags = null;
			}
			tags_size = 0;
			error = true;

			GLib.warning ("Can not allocate xml data buffer.");
			
			return false;
		}
		
		if (tags_size > 0) {
			Posix.memcpy (new_starts, start_tags, tags_size * sizeof (int));
			Posix.memcpy (new_closes, close_tags, tags_size * sizeof (int));
		}
		
		if (start_tags != null) {
			delete start_tags;
		}
		if (close_tags != null) {
			delete close_tags;
		}
		
		start_tags = new_starts;
		close_tags = new_closes;
		tags_capacity = new_capacity;
		
		return true;
	}
}

}
