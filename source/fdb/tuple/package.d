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
    // Combined long tests
    assert(pack(-0x08_00_00_00_00_00_00_07).unpack[0].get!long
        == -0x08_00_00_00_00_00_00_07);
    assert(pack(-0x07_00_00_00_00_00_06).unpack[0].get!long
        == -0x07_00_00_00_00_00_06);
    assert(pack(-0x06_00_00_00_00_05).unpack[0].get!long
        == -0x06_00_00_00_00_05);
    assert(pack(-0x05_00_00_00_04).unpack[0].get!long
        == -0x05_00_00_00_04);
    assert(pack(-0x04_00_00_03).unpack[0].get!long
        == -0x04_00_00_03);
    assert(pack(-0x03_00_02).unpack[0].get!long
        == -0x03_00_02);
    assert(pack(-0x02_01).unpack[0].get!long
        == -0x02_01);
    assert(pack(-0x01).unpack[0].get!long
        == -0x01);

    assert(pack(0x00).unpack[0].get!long
        == 0x00);

    assert(pack(0x01).unpack[0].get!long
        == 0x01);
    assert(pack(0x02_01).unpack[0].get!long
        == 0x02_01);
    assert(pack(0x03_00_02).unpack[0].get!long
        == 0x03_00_02);
    assert(pack(0x04_00_00_03).unpack[0].get!long
        == 0x04_00_00_03);
    assert(pack(0x05_00_00_00_04).unpack[0].get!long
        == 0x05_00_00_00_04);
    assert(pack(0x06_00_00_00_00_05).unpack[0].get!long
        == 0x06_00_00_00_00_05);
    assert(pack(0x07_00_00_00_00_00_06).unpack[0].get!long
        == 0x07_00_00_00_00_00_06);
    assert(pack(0x08_00_00_00_00_00_00_07).unpack[0].get!long
        == 0x08_00_00_00_00_00_00_07);

    // Combined float tests
    assert(pack(float.nan).unpack[0].get!float.isNaN);
    assert(pack(-float.infinity).unpack[0].get!float   == -float.infinity);
    assert(pack(-float.max).unpack[0].get!float        == -float.max);
    assert(pack(-1.0f).unpack[0].get!float             == -1.0f);
    assert(pack(-float.min_normal).unpack[0].get!float == -float.min_normal);
    assert(pack(0.0f).unpack[0].get!float              ==  0.0f);
    assert(pack(float.min_normal).unpack[0].get!float  ==  float.min_normal);
    assert(pack(1.0f).unpack[0].get!float              ==  1.0f);
    assert(pack(float.max).unpack[0].get!float         ==  float.max);
    assert(pack(float.infinity).unpack[0].get!float    ==  float.infinity);

    // Combined double tests
    assert(pack(double.nan).unpack[0].get!double.isNaN);
    assert(pack(-double.infinity).unpack[0].get!double   == -double.infinity);
    assert(pack(-double.max).unpack[0].get!double        == -double.max);
    assert(pack(-1.0).unpack[0].get!double               == -1.0);
    assert(pack(-double.min_normal).unpack[0].get!double == -double.min_normal);
    assert(pack(0.0).unpack[0].get!double                ==  0.0);
    assert(pack(double.min_normal).unpack[0].get!double  ==  double.min_normal);
    assert(pack(1.0).unpack[0].get!double                ==  1.0);
    assert(pack(double.max).unpack[0].get!double         ==  double.max);
    assert(pack(double.infinity).unpack[0].get!double    ==  double.infinity);

    // Combined UUID tests
    assert(pack(sha1UUID("some value")).unpack[0].get!UUID
        == sha1UUID("some value"));
}
