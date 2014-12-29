module fdb.tuple.part;

import
    std.uuid,
    std.variant;

alias Part = Algebraic!(long, string, float, double, UUID);
