module fdb.tuple;

public import
    fdb.tuple.future,
    fdb.tuple.packer,
    fdb.tuple.part,
    fdb.tuple.unpacker;

unittest
{
    import std.conv;
    import fdb.tuple.tupletype;

    // Packer tests
    assert(pack(-0x08_00_00_00_00_00_00_07)
        == cast(ubyte[])[ TupleType.IntNeg8, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08 ]);
    assert(pack(-0x07_00_00_00_00_00_06)
        == cast(ubyte[])[ TupleType.IntNeg7, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07 ]);
    assert(pack(-0x06_00_00_00_00_05)
        == cast(ubyte[])[ TupleType.IntNeg6, 0x05, 0x00, 0x00, 0x00, 0x00, 0x06 ]);
    assert(pack(-0x05_00_00_00_04)
        == cast(ubyte[])[ TupleType.IntNeg5, 0x04, 0x00, 0x00, 0x00, 0x05 ]);
    assert(pack(-0x04_00_00_03)
        == cast(ubyte[])[ TupleType.IntNeg4, 0x03, 0x00, 0x00, 0x04 ]);
    assert(pack(-0x03_00_02)
        == cast(ubyte[])[ TupleType.IntNeg3, 0x02, 0x00, 0x03 ]);
    assert(pack(-0x02_01)
        == cast(ubyte[])[ TupleType.IntNeg2, 0x01, 0x02 ]);
    assert(pack(-0x01)
        == cast(ubyte[])[ TupleType.IntNeg1, 0x01 ]);

    assert(pack(0x00)
        == cast(ubyte[])[ TupleType.IntZero ]);

    assert(pack(0x01)
        == cast(ubyte[])[ TupleType.IntPos1, 0x01 ]);
    assert(pack(0x02_01)
        == cast(ubyte[])[ TupleType.IntPos2, 0x01, 0x02 ]);
    assert(pack(0x03_00_02)
        == cast(ubyte[])[ TupleType.IntPos3, 0x02, 0x00, 0x03 ]);
    assert(pack(0x04_00_00_03)
        == cast(ubyte[])[ TupleType.IntPos4, 0x03, 0x00, 0x00, 0x04 ]);
    assert(pack(0x05_00_00_00_04)
        == cast(ubyte[])[ TupleType.IntPos5, 0x04, 0x00, 0x00, 0x00, 0x05 ]);
    assert(pack(0x06_00_00_00_00_05)
        == cast(ubyte[])[ TupleType.IntPos6, 0x05, 0x00, 0x00, 0x00, 0x00, 0x06 ]);
    assert(pack(0x07_00_00_00_00_00_06)
        == cast(ubyte[])[ TupleType.IntPos7, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07 ]);
    assert(pack(0x08_00_00_00_00_00_00_07)
        == cast(ubyte[])[ TupleType.IntPos8, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08 ]);

    // Unpacker tests
    assert(unpack(cast(ubyte[])[ TupleType.IntNeg8, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08 ])[0].get!long
        == -0x08_00_00_00_00_00_00_07);
    assert(unpack(cast(ubyte[])[ TupleType.IntNeg7, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07 ])[0].get!long
        == -0x07_00_00_00_00_00_06);
    assert(unpack(cast(ubyte[])[ TupleType.IntNeg6, 0x05, 0x00, 0x00, 0x00, 0x00, 0x06 ])[0].get!long
        == -0x06_00_00_00_00_05);
    assert(unpack(cast(ubyte[])[ TupleType.IntNeg5, 0x04, 0x00, 0x00, 0x00, 0x05 ])[0].get!long
        == -0x05_00_00_00_04);
    assert(unpack(cast(ubyte[])[ TupleType.IntNeg4, 0x03, 0x00, 0x00, 0x04 ])[0].get!long
        == -0x04_00_00_03);
    assert(unpack(cast(ubyte[])[ TupleType.IntNeg3, 0x02, 0x00, 0x03 ])[0].get!long
        == -0x03_00_02);
    assert(unpack(cast(ubyte[])[ TupleType.IntNeg2, 0x01, 0x02 ])[0].get!long
        == -0x02_01);
    assert(unpack(cast(ubyte[])[ TupleType.IntNeg1, 0x01 ])[0].get!long
        == -0x01);

    assert(unpack(cast(ubyte[])[ TupleType.IntZero ])[0].get!long
        == 0x00);

    assert(unpack(cast(ubyte[])[ TupleType.IntPos1, 0x01 ])[0].get!long
        == 0x01);
    assert(unpack(cast(ubyte[])[ TupleType.IntPos2, 0x01, 0x02 ])[0].get!long
        == 0x02_01);
    assert(unpack(cast(ubyte[])[ TupleType.IntPos3, 0x02, 0x00, 0x03 ])[0].get!long
        == 0x03_00_02);
    assert(unpack(cast(ubyte[])[ TupleType.IntPos4, 0x03, 0x00, 0x00, 0x04 ])[0].get!long
        == 0x04_00_00_03);
    assert(unpack(cast(ubyte[])[ TupleType.IntPos5, 0x04, 0x00, 0x00, 0x00, 0x05 ])[0].get!long
        == 0x05_00_00_00_04);
    assert(unpack(cast(ubyte[])[ TupleType.IntPos6, 0x05, 0x00, 0x00, 0x00, 0x00, 0x06 ])[0].get!long
        == 0x06_00_00_00_00_05);
    assert(unpack(cast(ubyte[])[ TupleType.IntPos7, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07 ])[0].get!long
        == 0x07_00_00_00_00_00_06);
    assert(unpack(cast(ubyte[])[ TupleType.IntPos8, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x08 ])[0].get!long
        == 0x08_00_00_00_00_00_00_07);

    // Combined tests
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
}
