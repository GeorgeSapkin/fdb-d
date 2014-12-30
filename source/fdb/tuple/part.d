module fdb.tuple.part;

import
    std.uuid,
    std.variant;

alias Part = Algebraic!(
    typeof(null),
    string,
    long,
    float,
    double,
    UUID);
