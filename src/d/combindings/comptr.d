module combindings.comptr;

import combindings.glue;
import core.sys.windows.windows;

// Similar implementation to WRL ComPtr
// https://docs.microsoft.com/en-us/cpp/cppcx/wrl/comptr-class?view=vs-2019

struct ComPtr( T : IUnknown, bool bStrong = true )
{
	alias InterfaceType = T;
	enum StrongRef = bStrong;

	~this()
	{
		ptr_.ReleaseAndNull;
	}

	this( InterfaceType obj )
	{
		ptr_ = obj;
		InternalAddRef();
	}

	this( ref ComPtr obj )
	{
		ptr_ = obj.ptr_;
		InternalAddRef();
	}

	this( bool bNewStrong )( ref ComPtr!( InterfaceType, bNewStrong ) obj )
	{
		static if( bStrong )
		{
			static assert( bNewStrong, "Attempting to upgrade weak reference to strong, this is not supported." );
		}
		ptr_ = obj.ptr_;
		InternalAddRef();
	}

	this( NewType, bool bNewStrong )( ref ComPtr!( NewType, bNewStrong ) obj )
	{
		static if( bStrong )
		{
			static assert( bNewStrong, "Attempting to upgrade weak reference to strong, this is not supported." );
		}
		QueryInterface( obj.ptr_, ptr_ );
		InternalAddRef();
	}

	auto As( NewType )()
	{
		return ComPtr!NewType( this );
	}

	auto AsWeak( NewType )()
	{
		return ComPtr!( NewType, false )( this );
	}

	bool Valid() const					{ return _ptr !is null; }

	static if( StrongRef )
	{
		auto Release()					{ return ptr_.ReleaseAndNull(); }
		package void InternalAddRef()	{ if( Valid() ) ptr_.AddRef; }
	}
	else
	{
		auto Release()					{ _ptr = null; return 0; }
		package void InternalAddRef()	{ }
	}

	package InterfaceType ptr_;
	alias ptr_ this;
}

alias ComPtrWeak = PartialRight!( ComPtr, false );
