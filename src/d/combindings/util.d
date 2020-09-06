module combindings.util;

public import core.sys.windows.basetyps : WinGUID = GUID;
import core.sys.windows.windows;

import combindings.glue;
import combindings.attributes;

// Basic COM object helpers

void ReleaseAndNull( T : IUnknown )( ref T Obj )
{
	if( Obj !is null )
	{
		Obj.Release();
		Obj = null;
	}
}

IID IIDOf( T : IUnknown )() pure @safe nothrow
{
	import std.traits : hasUDA, getUDAs;
	// We totally prefer the @MIDL_INTERFACE attribute...
	static if( hasUDA!( T, MIDL_INTERFACE ) )
	{
		alias Interface = getUDAs!( T, MIDL_INTERFACE )[ 0 ];
		return Interface.iid;
	}
	// ...but fallback to the standard IID values defined by MS headers otherwise.
	// If you don't have those values defined in your COM modules, you're on your own.
	else
	{
		import std.traits : moduleName;
		
		mixin( "import " ~ moduleName!T ~ ";" );
		enum Compiles = __traits( compiles, mixin( "{ auto ptr = &IID_" ~ T.stringof ~ "; }" ) );
		static if( Compiles )
		{
			mixin( "return IID_" ~ T.stringof ~ ";" );
		}
		else
		{
			return InvalidGUID;
		}
	}
}

IID IIDOf( T : IUnknown )( ref T ObjPtr ) pure @safe nothrow
{
	return IIDOf!T;
}

IID* IIDPtrOf( T : IUnknown )() pure @safe nothrow
{
	import std.traits : hasUDA, getUDAs;
	// We totally prefer the @MIDL_INTERFACE attribute...
	static if( hasUDA!( T, MIDL_INTERFACE ) )
	{
		alias Interface = getUDAs!( T, MIDL_INTERFACE )[ 0 ];
		return &Interface.value;
	}
	// ...but fallback to the standard IID values defined by MS headers otherwise.
	// If you don't have those values defined in your COM modules, you're on your own.
	else
	{
		import std.traits : moduleName;
		
		mixin( "import " ~ moduleName!T ~ ";" );
		enum Compiles = __traits( compiles, mixin( "{ auto ptr = &IID_" ~ T.stringof ~ "; }" ) );
		static if( Compiles )
		{
			mixin( "return &IID_" ~ T.stringof ~ ";" );
		}
		else
		{
			return null;
		}
	}
}

auto IIDPtrOf( T : IUnknown )( ref T ObjPtr ) pure @safe nothrow
{
	return IIDPtrOf!T;
}

// Wrappers for IUnknown and IClassFactory
HRESULT QueryInterface( T : IUnknown, I : IUnknown )( ref T OutputObj )
{
	return ThisObj.QueryInterface( IIDPtrOf!T, cast(void**)&QueryObj );
}

HRESULT CreateInstance( T : IUnknown )( ref IClassFactory ThisObj, IUnknown UnkOuter, ref T OutputObj )
{
	return ThisObj.CreateInstance( UnkOuter, IIDPtrOf!T, cast(void**)&QueryObj );
}

// UUID/IID/CLSID helpers

enum InvalidGUID = to!WinGUID( "ffffffff-ffff-ffff-ffff-ffffffffffff" );

WinGUID to( T : const( WinGUID ) )( string s ) pure @safe nothrow { return to!WinGUID( s ); }

WinGUID to( T : WinGUID )( string s ) pure @safe nothrow
{
	if( s.length == 38 && s[ 0 ] == '{' && s[ 37 ] == '}' )
	{
		return to!WinGUID( s[ 1 .. 37 ] );
	}
	else if( s.length == 36 && s[ 8 ] == '-' && s[ 13 ] == '-' && s[ 18 ] == '-' && s[ 23 ] == '-' )
	{
		byte parse( char c )
		{
			// This is as BS as it looks. Thanks DMD, just infer the return type and be done with it
			// instead of int all the things...
			byte output = cast( byte )0xFF;
			if( c >= '0' && c <= '9' )
				output = cast( byte )( c - '0' );
			if( c >= 'A' && c <= 'F' )
				output = cast( byte )( 10 + ( cast( byte )c - 'A' ) );
			if( c >= 'a' && c <= 'f' )
				output = cast( byte )( 10 + ( cast( byte )c - 'a' ) );
			return output;
		}

		T extract( T )()
		{
			if( s[ 0 ] == '-' ) s = s[ 1 .. $ ];
			T high = cast( T )( parse( s[ 0 ] ) << 4 );
			T low = cast( T )( parse( s[ 1 ] ) );
			T val = high | low;
			s = s[ 2 .. $ ];
			return val;
		}

		WinGUID output;

		// Stored big endian
		output.Data1 = cast( DWORD )( ( extract!DWORD << 24 ) | ( extract!DWORD << 16 ) | ( extract!DWORD << 8 ) | extract!DWORD );
		output.Data2 = cast( WORD )(  ( extract!WORD  << 8  ) | extract!WORD );
		output.Data3 = cast( WORD )(  ( extract!WORD  << 8  ) | extract!WORD );
		foreach( Index; 0 .. 8 )
		{
			output.Data4[ Index ] = extract!BYTE;
		}

		return output;
	}
	else
	{
		return to!WinGUID( "ffffffff-ffff-ffff-ffff-ffffffffffff" );
	}
}
