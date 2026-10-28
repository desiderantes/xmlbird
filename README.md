![xmlbird logo][xmlbird]

# XML Bird – XML parser

XML Bird is an XML parser for programs written in Vala or C.

    Author: Johan Mattsson
    License: LGPL v3
    Webpage: https://birdfont.org/xmlbird.php

## Building from Source

Install `valac`, `glib-2.0`, `meson`, and `ninja`.

Configure and build:

    meson setup build
    meson compile -C build

The default prefix is `/usr/local`, but you can customize it:

    meson setup build --prefix=/usr

Run tests and benchmarks:

    meson test -C build
    meson test -C build --benchmark

Install:

    ninja -C build install
    # or
    meson install -C build

Exampel usage:

    using B;

    // Print all tags and attributes in an XML document. 
    // Expected output:
    // tag1
    // tag2
    // attribute1
    public static int main (string[] arg) {
        Tag root;
        XmlParser parser;

        parser = new XmlParser ("""<tag1><tag2 attribute1=""/></tag1>""");	

        if (!parser.validate ()) {
            warning ("Invalid XML.");
            return 1;
        }

        root = parser.get_root_tag ();
        print_tags (root);

        return 0;
    }


    void print_tags (Tag tag) {
        print (tag.get_name ());
        print ("\n");
        print_attributes (tag);

        foreach (Tag t in tag) {
            print_tags (t);
        }
    }

    void print_attributes (Tag tag) {
        Attributes attributes = tag.get_attributes ();
        foreach (Attribute attribute in attributes) {
            print (attribute.get_name ());
            print ("\n");
        }
    }

## Hacking

Run the test suite and benchmarks:

    meson test -C build
    meson test -C build --benchmark

To enable the fuzzing target and run the fuzz tests:

    meson setup build -Dfuzzing=true
    meson test -C build --suite fuzz

To run continuous fuzzing with `radamsa`:

    ninja -C build fuzz

XML Bird is a part of the [Birdfont][birdfont] project.

[xmlbird]: https://birdfont.org/images/xmlbird-icon.png "XML Bird icon"
[birdfont]: https://birdfont.org/ "Birdfont – Font Editor"


