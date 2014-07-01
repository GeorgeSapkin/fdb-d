module fdb.tuple.writer;

import
    std.string,
    std.traits;

class Writer {
    ubyte[] bytes;
    @property auto length() const {
        return bytes.length;
    }

    this() {}
    this(const ulong length) {
        bytes.length = length;
    }

    void write(N)(const N value) if(isNumeric!N) {
        bytes ~= (cast(ubyte*)&value)[0..N.sizeof];
    }

    void write(const ubyte[] value) {
        bytes ~= value;
    }

    void write(const string value) {
        bytes ~= cast(ubyte[])(value.toStringz[0..value.length + 1]);
    }
}