"""Group a Flow's top-level elements by type (Metadata API wants same-type elements together)."""
import sys
import xml.etree.ElementTree as ET

NS = "http://soap.sforce.com/2006/04/metadata"
ET.register_namespace("", NS)
for path in sys.argv[1:]:
    tree = ET.parse(path)
    root = tree.getroot()
    kids = list(root)
    order = []
    for k in kids:
        if k.tag not in order:
            order.append(k.tag)
    for k in kids:
        root.remove(k)
    for tag in order:
        for k in kids:
            if k.tag == tag:
                root.append(k)
    ET.indent(tree, "    ")
    tree.write(path, encoding="UTF-8", xml_declaration=True)
    print("sorted", path)
