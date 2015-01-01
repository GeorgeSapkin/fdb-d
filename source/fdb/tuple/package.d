module fdb.tuple;

import
    std.math,
    std.uuid;

public import
    fdb.tuple.future,
    fdb.tuple.packer,
    fdb.tuple.part,
    fdb.tuple.unpacker;

unittest
{
    // Combined null
    assert(pack(null).unpack!(typeof(null)) is null);

    // Combined byte array tests
    assert(pack(cast(ubyte[])[ 0xa0, 0x00, 0x0b ]).unpack!(ubyte[])
        == cast(ubyte[])[ 0xa0, 0x00, 0x0b ]);

    // Combined string tests
    assert(pack("Some usefull string").unpack!string
        == "Some usefull string");

    // Combined long tests
    assert(pack(-0x08_00_00_00_00_00_00_07).unpack!long
        == -0x08_00_00_00_00_00_00_07);
    assert(pack(-0x07_00_00_00_00_00_06).unpack!long
        == -0x07_00_00_00_00_00_06);
    assert(pack(-0x06_00_00_00_00_05).unpack!long
        == -0x06_00_00_00_00_05);
    assert(pack(-0x05_00_00_00_04).unpack!long
        == -0x05_00_00_00_04);
    assert(pack(-0x04_00_00_03).unpack!long
        == -0x04_00_00_03);
    assert(pack(-0x03_00_02).unpack!long
        == -0x03_00_02);
    assert(pack(-0x02_01).unpack!long
        == -0x02_01);
    assert(pack(-0x01).unpack!long
        == -0x01);

    assert(pack(0x00).unpack!long
        == 0x00);

    assert(pack(0x01).unpack!long
        == 0x01);
    assert(pack(0x02_01).unpack!long
        == 0x02_01);
    assert(pack(0x03_00_02).unpack!long
        == 0x03_00_02);
    assert(pack(0x04_00_00_03).unpack!long
        == 0x04_00_00_03);
    assert(pack(0x05_00_00_00_04).unpack!long
        == 0x05_00_00_00_04);
    assert(pack(0x06_00_00_00_00_05).unpack!long
        == 0x06_00_00_00_00_05);
    assert(pack(0x07_00_00_00_00_00_06).unpack!long
        == 0x07_00_00_00_00_00_06);
    assert(pack(0x08_00_00_00_00_00_00_07).unpack!long
        == 0x08_00_00_00_00_00_00_07);

    // Combined float tests
    assert(pack(float.nan).unpack!float.isNaN);
    assert(pack(-float.infinity).unpack!float   == -float.infinity);
    assert(pack(-float.max).unpack!float        == -float.max);
    assert(pack(-1.0f).unpack!float             == -1.0f);
    assert(pack(-float.min_normal).unpack!float == -float.min_normal);
    assert(pack(0.0f).unpack!float              ==  0.0f);
    assert(pack(float.min_normal).unpack!float  ==  float.min_normal);
    assert(pack(1.0f).unpack!float              ==  1.0f);
    assert(pack(float.max).unpack!float         ==  float.max);
    assert(pack(float.infinity).unpack!float    ==  float.infinity);

    // Combined double tests
    assert(pack(double.nan).unpack!double.isNaN);
    assert(pack(-double.infinity).unpack!double   == -double.infinity);
    assert(pack(-double.max).unpack!double        == -double.max);
    assert(pack(-1.0).unpack!double               == -1.0);
    assert(pack(-double.min_normal).unpack!double == -double.min_normal);
    assert(pack(0.0).unpack!double                ==  0.0);
    assert(pack(double.min_normal).unpack!double  ==  double.min_normal);
    assert(pack(1.0).unpack!double                ==  1.0);
    assert(pack(double.max).unpack!double         ==  double.max);
    assert(pack(double.infinity).unpack!double    ==  double.infinity);

    // Combined UUID tests
    assert(pack(sha1UUID("some value")).unpack!UUID
        == sha1UUID("some value"));
}
