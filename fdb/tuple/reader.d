module fdb.tuple.reader;

import
    std.exception,
    std.traits;

class Reader {
    ubyte[] bytes;
    @property auto length() const {
        return bytes.length;
    }

    ulong _position;
    @property auto position() {
        return _position;
    }
    @property void position(const ulong pos) {
        enforce(pos < length);
        _position = pos;
    }

    this(ubyte[] bytes) {
        this.bytes = bytes;
    }

    auto read(const ulong len) {
        auto newPos = position + len;
        enforce(newPos < length);
        scope (exit) position = newPos;
        return bytes[position..newPos];
    }

    auto read(N)() if(isNumeric!N) {
        auto newPos = position + N.sizeof;
        enforce(newPos <= bytes.length);
        scope (exit) position = newPos;
        return *(cast(N*)&bytes[position]);
    }

    auto read(N : string)() {
        enforce(position < bytes.length);

        auto newPos = position;
        char[] chars;

        do chars ~= cast(char)bytes[newPos];
        while (bytes[newPos] != 0
            && ++newPos < bytes.length);

        position = newPos + 1;
        return chars.to!string;
    }
}