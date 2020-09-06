// Glue for combindings. Wraps some COM declarations up in D friendly format.
module combindings.glue;

import combindings.attributes;
import combindings.util;

import core.sys.windows.windows;

// Bunch of templates designed to reduce dependencies on all of Phobos. I don't need all of Phobos.
template Alias( alias A )
{
	alias Alias = A;
}

template AliasSeq( A... )
{
	alias AliasSeq = A;
}

template ModuleFromName( string strModuleName )
{
	mixin( "import " ~ strModuleName ~ "; alias ModuleFromName = Alias!( " ~ strModuleName ~ " );" );
}

alias TargetOf( T ) = T;
alias TargetOf( T : U*, U ) = U;
alias TargetOf( T : const( U ), U ) = const( TargetOf!U );

template PartialLeft( alias Template, LeftParams... )
{
	alias PartialLeft( Params... ) = Template!( LeftParams, Params );
}

template PartialRight( alias Template, RightParams... )
{
	alias PartialRight( Params... ) = Template!( Params, RightParams );
}

enum Matches( alias Left, alias Right ) = is( Left == Right );

template Filter( alias Test, Symbols... )
{
	string generate()
	{
		import std.array : join;

		string[] Indices;
		static foreach( Index; 0 .. Symbols.length )
		{
			static if( Test!( Symbols[ Index ] ) )
			{
				Indices ~= "Symbols[" ~ Index.stringof ~ "]";
			}
		}

		return "alias Filter = AliasSeq!( " ~ Indices.join( ", " ) ~ " );";
	}

	mixin( generate() );
}

string Glue( string ModuleName )()
{
	return Glue!( ModuleFromName!ModuleName );
}

string Glue( alias Symbol )()
{
	import std.traits : hasUDA;
	import std.array : join;

	struct CTFEStringBuilderHackForSpeed
	{
		this( size_t InitialLength )
		{
			output.length = InitialLength;
		}

		void Add( string s )
		{
			if( pos + s.length > output.length )
			{
				output.length = output.length * 2;
			}
			output[ pos .. pos + s.length ] = s[ 0 .. $ ];
			pos += s.length;
		}

		void AddLine( string s )
		{
			Add( s );
			AddBlankLine();
		}

		void AddBlankLine()
		{
			Add( "\n" );
		}

		auto opCast( T : string )() { return cast(string)output[ 0 .. pos ]; }

		private char[]		output;
		private size_t		pos;
	}

	CTFEStringBuilderHackForSpeed builder = CTFEStringBuilderHackForSpeed( 1024 * 1024 );

	builder.AddLine( "// Enumeration aliases so you can just copy/paste code from wherever" );
	builder.AddBlankLine();

	foreach( Identifier; __traits( allMembers, Symbol ) )
	{
		alias ThisSymbol = __traits( getMember, Symbol, Identifier );
		static if( is( ThisSymbol Underlying == enum ) )
		{
			builder.AddLine( "// " ~ Identifier ~ " aliases" );
			foreach( EnumMember; __traits( allMembers, ThisSymbol ) )
			{
				builder.AddLine( "alias " ~ EnumMember ~ " = " ~ Identifier ~ "." ~ EnumMember ~ ";" );
			}
			builder.AddBlankLine();
			// Not actually necessary, derp
			//static if( hasUDA!( ThisSymbol, DEFINE_ENUM_FLAG_OPERATORS ) )
			//{
			//	builder.AddLine( "auto opBinary( string op )( " ~ Identifier ~ " lhs, " ~ Identifier ~ " rhs ) if( op == \"|\" || op == \"&\" || op == \"^\" )" );
			//	builder.AddLine( "{" );
			//	builder.AddLine( "\tmixin( \"return lhs \" ~ op ~ \" rhs; \" );" );
			//	builder.AddLine( "}" );
			//	builder.AddBlankLine();
			//}
		}
	}

	builder.AddLine( "// Function wrappers for a more D-like experience" );
	builder.AddBlankLine();

	void AddFunctionToBuilder( string Identifier, string InterfaceAccess, string ReturnType, string[] Params, string[] Stubs )
	{
		builder.AddLine( ReturnType ~ " " ~ Identifier ~ "( ComType : IUnknown )( " ~ Stubs.join( ", " ) ~ " )"  );
		if( ReturnType != "void" )
		{
			builder.AddLine( "\t{ import combindings.util : IIDPtrOf; return " ~ InterfaceAccess ~ Identifier ~ "( " ~ Params.join( ", " ) ~ " ); }" );
		}
		else
		{
			builder.AddLine( "\t{ import combindings.util : IIDPtrOf; " ~ InterfaceAccess ~ Identifier ~ "( " ~ Params.join( ", " ) ~ " ); }" );
		}
		builder.AddBlankLine();
	}

	alias IsComOutPtr = PartialLeft!( Matches, _COM_Outptr_ );
	alias IsComOutOptPtr = PartialLeft!( Matches, _COM_Outptr_opt_ );

	void ScrapeFunctions( alias CurrentScope )()
	{
		static if( is( CurrentScope == interface ) )
		{
			builder.AddLine( "HRESULT QueryInterface( T )( " ~ CurrentScope.stringof ~ " ThisObj, ref T QueryObj )" );
			builder.AddLine( "\t{ import combindings.util : IIDPtrOf; return ThisObj.QueryInterface( IIDPtrOf!T, cast(void**)&QueryObj ); }" );
			builder.AddBlankLine();
		}

		foreach( Identifier; __traits( allMembers, CurrentScope ) )
		{
			static if( is( __traits( getMember, CurrentScope, Identifier ) == interface ) )
			{
				alias NextInterface = __traits( getMember, CurrentScope, Identifier );
				builder.AddLine( "// Interface " ~ NextInterface.stringof );
				ScrapeFunctions!NextInterface;
			}
			else
			{
				alias TheseOverloads = __traits( getOverloads, CurrentScope, Identifier );
				static if( TheseOverloads.length > 0 )
				{
					static foreach( OverloadIndex; 0 .. TheseOverloads.length )
					{
						static if( is( typeof( TheseOverloads[ OverloadIndex ] ) Params == __parameters )
								&& Params.length > 0
								&& is( typeof( TheseOverloads[ OverloadIndex ] ) Return == return ) )
						{
							alias FinalParam = Params[ $ - 1 .. $ ];
							alias ComOut = Filter!( IsComOutPtr, __traits( getAttributes, FinalParam ) );
							alias ComOutOpt = Filter!( IsComOutOptPtr, __traits( getAttributes, FinalParam ) );

							static if( ComOut.length > 0 || ComOutOpt.length > 0 )
							{
								static if( is( Params[ $ - 2 ] == REFIID ) )
								{
									string[] ParamNames;
									string[] StubParams;
									string InterfaceAccess;

									static if( is( CurrentScope == interface ) )
									{
										StubParams ~= CurrentScope.stringof ~ " ThisObj";
										InterfaceAccess = "ThisObj.";
									}

									static foreach( ParamIndex; 0 .. Params.length - 2 )
									{
										ParamNames ~= __traits( identifier, Params[ ParamIndex .. ParamIndex + 1 ] );
										StubParams ~= Params[ ParamIndex ].stringof ~ " " ~ __traits( identifier, Params[ ParamIndex .. ParamIndex + 1 ] );
									}
									ParamNames ~= "IIDPtrOf!ComType";

									if( ComOutOpt.length > 0 )
									{
										AddFunctionToBuilder( Identifier, InterfaceAccess, Return.stringof, ParamNames ~ "null", StubParams );
									}

									ParamNames ~= "cast(void**)(&" ~ __traits( identifier, Params[ $ - 1 .. $ ] ) ~ ")";
									StubParams ~= "ref ComType " ~ __traits( identifier, Params[ $ - 1 .. $ ] );
					
									AddFunctionToBuilder( Identifier, InterfaceAccess, Return.stringof, ParamNames, StubParams );
								}
							}
						}
					}
				}
			}
		}
	}

	ScrapeFunctions!Symbol;

	return cast(string)builder;
}
