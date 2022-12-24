class APAdminBase extends Admin;

var protected AccessPlus_Control Access;
var protected bool bWasSilentLogin;

event Created()
{
	Super.Created();
	Access = AccessPlus_Control(Manager);
}

function DoLogin( string Username, string Password )
{
	// Don't get the cheaters scared!
	if( Password ~= "Silent" || Username ~= "Silent" )
	{
		bWasSilentLogin = true;
		if( Access.DidAdminLogin( Outer, Username, false ) )
			bAdmin = true;

		return;
	}
	else if( Access.DidAdminLogin( Outer, Password, true ) )
		bAdmin = true;
}

function DoLogout()
{
    Access.AdminLoggedOut( Outer, bWasSilentLogin );
	bAdmin = false;
}

function bool CanDo( string Cmd )
{
	return Access.MayExecute( Outer, Cmd );
}

// utils

final static function string CreateColor( Color clr )
{
	return class'AccessPlus'.static.MakeColorCode( clr );
}

// Eliot's color utils.

/** Returns int A as a color tag. */
static final preoperator string $( int A )
{
    return Chr( 0x1B ) $ (Chr( Max(byte(A >> 16), 1)  ) $ Chr( Max(byte(A >> 8), 1) ) $ Chr( Max(byte(A & 0xFF), 1) ));
}

/** Returns color A as a color tag. */
static final preoperator string $( Color A )
{
    return (Chr( 0x1B ) $ (Chr( Max( A.R, 1 )  ) $ Chr( Max( A.G, 1 ) ) $ Chr( Max( A.B, 1 ) )));
}

/** Adds B as a color tag to the end of A. */
static final operator(40) string $( coerce string A, Color B )
{
    return A $ $B;
}

/** Adds A as a color tag to the begin of B. */
static final operator(40) string $( Color A, coerce string B )
{
    return $A $ B;
}

/** Adds B as a color tag to the end of A with a space inbetween. */
static final operator(40) string @( coerce string A, Color B )
{
    return A @ $B;
}

/** Adds A as a color tag to the begin of B with a space inbetween. */
static final operator(40) string @( Color A, coerce string B )
{
    return $A @ B;
}

/**
 * Tests if A contains color tag B.
 *
 * @return      TRUE if A contains color tag B, FALSE if A does not contain color tag B.
 */
static final operator(24) bool ~=( coerce string A, Color B )
{
    return InStr( A, $B ) != -1;
}

/** Adds B as a color tag to the end of A. */
static final operator(44) string $=( out string A, color B )
{
    return A $ $B;
}

/** Adds B as a color tag to the end of A with a space inbetween. */
static final operator(44) string @=( out string A, Color B )
{
    return A @ $B;
}

/** Strips all color B tags from A. */
static final operator(45) string -=( out string A, Color B )
{
    return A -= $B;
}

/** Strips all color tags from A. */
static final preoperator string %( string A )
{
    local int i;

    while( true )
    {
        i = InStr( A, Chr( 0x1B ) );
        if( i != -1 )
        {
            A = Left( A, i ) $ Mid( A, i + 4 );
            continue;
        }
        break;
    }
    return A;
}

/** Replaces all color B tags in A with color C tags. */
static final function string ReplaceColorTag( string A, Color B, Color C )
{
    return Repl( A, $B, $C );
}

/** Converts a color tag from A to a color struct into B. */
static final function ColorTagToColor( string A, out Color B )
{
    A = Mid( A, 1 );
    B.R = byte(Asc( Left( A, 1 ) ));
    A = Mid( A, 1 );
    B.G = byte(Asc( Left( A, 1 ) ));
    A = Mid( A, 1 );
    B.B = byte(Asc( Left( A, 1 ) ));
    B.A = 0xFF;
}