"""Helpers for editing Lightning record pages: show or hide components on Part 2 (Keep and Grow) records."""
import re

PART2 = "{!Record.Part2_Demo__c}"


def crit(value):
    return (f"<criteria><leftValue>{PART2}</leftValue><operator>EQUAL</operator>"
            f"<rightValue>{value}</rightValue></criteria>")


def blocks(s):
    return list(re.finditer(r"        <itemInstances>\n            <componentInstance>(?:(?!</itemInstances>).)*?</itemInstances>\n", s, re.S))


def find(s, pred):
    return [m for m in blocks(s) if pred(m.group(0))]


def only_when(block, value):
    """Add 'Part2_Demo__c = value' to a component's visibility (ANDed with any existing rule)."""
    if PART2 in block:
        return block
    if "<visibilityRule>" not in block:
        rule = f"<visibilityRule>{crit(value)}</visibilityRule>"
        return block.replace("            </componentInstance>\n        </itemInstances>",
                             f"                {rule}\n            </componentInstance>\n        </itemInstances>")
    m = re.search(r"<visibilityRule>(.*?)</visibilityRule>", block, re.S)
    inner = m.group(1)
    n = inner.count("<criteria>") + 1
    bf = re.search(r"<booleanFilter>([^<]*)</booleanFilter>", inner)
    if bf:
        inner = inner.replace(bf.group(0), f"<booleanFilter>({bf.group(1)}) AND {n}</booleanFilter>")
    else:
        inner = f"<booleanFilter>{' AND '.join(str(k) for k in range(1, n + 1))}</booleanFilter>" + inner
    inner = inner + crit(value)
    return block[:m.start(1)] + inner + block[m.end(1):]


def component(name, identifier, props=(), visible_on_part2=True):
    p = "".join(f"<componentInstanceProperties><name>{k}</name><value>{v}</value></componentInstanceProperties>" for k, v in props)
    rule = f"<visibilityRule>{crit('true' if visible_on_part2 else 'false')}</visibilityRule>"
    return (f"        <itemInstances>\n            <componentInstance>\n                {p}\n"
            f"                <componentName>{name}</componentName>\n                <identifier>{identifier}</identifier>\n"
            f"                {rule}\n            </componentInstance>\n        </itemInstances>\n")
