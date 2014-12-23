module fdb.tuple;

public import
    fdb.tuple.future,
    fdb.tuple.packer,
    fdb.tuple.part,
    fdb.tuple.unpacker;

unittest
{
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
