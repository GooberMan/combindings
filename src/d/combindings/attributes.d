module combindings.attributes;

import combindings.util;
import core.sys.windows.windows;

// UDAs! Replace IDL definitions with actual useful code objects
struct MemberCountDecl( alias Member )
{
	static ref inout auto Count( T )( ref inout T obj )
	{
		return obj.Member;
	}
}

alias _Field_size_bytes_full_	= MemberCountDecl;
alias _Field_size_full_			= MemberCountDecl;
alias _Field_size_full_opt_		= MemberCountDecl;
alias _Field_size_				= MemberCountDecl;
alias _In_reads_				= MemberCountDecl;

struct _In_ { }
struct _In_opt_ { }
struct _Inout_ { }
struct _Inout_opt_ { }
struct _Out_ { }
struct _Out_opt_ { }
struct _COM_Outptr_ { }
struct _COM_Outptr_opt_ { }

struct MIDL_INTERFACE( string u )
{
	import core.sys.windows.windows : IID;

	enum uuid = u;
	enum guid = u.to!WinGUID;
	alias clsid = guid;
	alias iid = guid;

	__gshared IID value = guid;
}

struct DEFINE_ENUM_FLAG_OPERATORS { }
