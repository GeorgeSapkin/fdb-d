module fdb.helpers;

import std.conv;

import fdb.fdb_c;

auto message(fdb_error_t err) {
    return fdb_get_error(err).to!string;
}