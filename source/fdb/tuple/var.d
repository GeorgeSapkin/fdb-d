module fdb.tuple.var;

import
	std.conv,
	std.exception,
	std.string,
	std.traits,
	std.typecons;

import
	fdb.tuple.tupletype;

alias FDBTuple = FDBVariant[];

struct FDBVariant
{
	const TupleType type;
	const shared ubyte[] slice;

	@property auto size()
	{
		if (type.isFDBIntegral)
			return type.FDBsizeof;
		else
		{
			auto size = (cast(char[])slice).indexOf(0, 0);
			return (size > 0) ? cast(ulong)size + 1 : 0;
		}
	}

	auto static create(B)(
		const TupleType type,
		B               slice) pure
	{
		if (type.isFDBIntegral)
			enforce(type.FDBsizeof == slice.length);
		return FDBVariant(type, slice);
	}

	auto static create(B)(
		const TupleType type,
		B               buffer,
		const ulong     offset) pure
	{
		if (type.isFDBIntegral)
		{
			auto size = type.FDBsizeof;
			enforce(offset + size <= buffer.length);
			return FDBVariant(type, buffer[offset .. offset + size]);
		}
		return FDBVariant(type, buffer[offset .. $]);
	}

	auto isTypeOf(T)() const
	{
		static if (is(T == long))
			return type.isFDBIntegral;
		else static if (is(T == string))
			return type == TupleType.Utf8 || type == TupleType.Bytes;
		else
			static assert(0, "Type " ~ T.to!string ~ " is not supported");
	}

	auto get(T)() const
	{
		enforce(isTypeOf!T);
		static if (is(T == long))
			return getInt;
		else static if (is(T == string))
			return getStr;
		else
			static assert(0, "Type " ~ T.to!string ~ " is not supported");
	}

	private auto getInt() const
	{
	    long value;
	    ubyte shift;
	    ulong pos;

	    const auto bits = type.FDBsizeof * 8;
	    while (shift < bits)
	    {
	        value |= slice[pos] << shift;
	        // TODO: use one counter?
	        ++pos;
	        shift += 8;
	    }
	    if (type < TupleType.IntBase)
	    	value = -value;
	    return value;
	}

	private auto getStr() const
	{
	    auto chars = (cast(char[])slice);
	    auto size = chars.indexOf(0, 0);
	    if (size > 0)
	    	chars = chars[0..size];
	    return chars.to!string;
	}
}

alias variant = FDBVariant.create;
