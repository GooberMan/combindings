COM Bindings
Thin glue and utility layer to make working with COM objects way more
convenient.

The goal of this library is compatibility and convenience, in that order. As
such, it supports preservation of COM attributes as much as is reasonably
possible; and uses those attributes to generate wrapper functionality.

To apply these bindings to your own COM definitions:

import combindings;
mixin( Glue!"my.module.name" );

Perhaps one day I'll parse .idl/.h files and autogenerate the bindings,
but for now it's a by-hand process. All this library does is make life way
more convenient once you have valid COM definitions.

Released under a CC0 license since public domain is a mess internationally.
This is designed to facilitate development with COM, nothing more, so the
only corporation that should be credited with anything is whoever published
the COM interfaces you're going to use. Go wild.