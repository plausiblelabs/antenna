#!/usr/bin/python

import fileinput

TYPE_STANDARD_RULE = 0
TYPE_WILDCARD_RULE = 1
TYPE_EXCEPTION_RULE = 2

def process (line):
    rule = line.strip()
    
    # Skip empty lines
    if len(rule) == 0:
        return
    
    # Skip comments
    if rule.startswith("//"):
        return
    
    # Handle special rule types
    if rule.startswith("!"):
        type = TYPE_EXCEPTION_RULE
        rule = rule[1:]
    elif rule.startswith("*."):
        type = TYPE_WILDCARD_RULE
        rule = rule[2:]
    else:
        type = TYPE_STANDARD_RULE

    print "%s,%d" % (rule, type)

# Output standard header
print """\
%define lookup-function-name ANTTopLevelDomainTableLookup
%compare-lengths
%readonly-tables
%compare-strncmp
%struct-type
%pic

%global-table
%define string-pool-name ANTTopLevelDomainTableStringPool
%{
#include <stddef.h>
#include <string.h>
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wmissing-field-initializers"
%}
struct TLDRule {
    int name;
    int type;
};
%%\
"""

# Process input
for line in fileinput.input():
    process(line)


# Output standard footer
print """\
%%
#pragma clang diagnostic pop
"""
