//==============================================================================
// AccessPlus.uc Created @ 2006 - 2014(Polishment)
// Coded by 'Marco' and 'Eliot van uytfanghe'
//==============================================================================
class AccessPlus extends Mutator
	config(AccessPlus);

const Version = "2.00 Pre-Release";

struct sMapActors
{
	var string
		ActorClass,
		MapName;

	var vector Location;
	var rotator Rotation;
};

struct ClientListType
{
	var string
		IP,
		Name;
};

struct SocketDataPacketType
{
	var string
		PlayerIP,
		PlayerName,
		ConnectionState,
		DLFile;

	var int
		TextChannels,
		ActorChannels,
		FileChannels,
		OtherChannels;
};

struct sReplaceMapPrefix
{
	var string
		SearchPrefix,
		NewPrefix;
};

struct sMapName
{
	var bool
		bColorMapName,
		bUseFadingColors,
		bReplaceMapPrefixs;

	var color MapNameColors[2];		// Fade 0 to 1, use 0 if bUseFadingColors == False
	var array<sReplaceMapPrefix> MapPrefixs;
};

struct sServerName
{
	var bool
		bColorServerName,
		bNoFadingColors;

	var color ServerNameColors[2];
	var string ServerNameForNoFadingColors;
};

var AccessPlus_Control Control;
var UTServerAdminSpectator WebAdmin;

var int OldDLersCount;
var array<string> OldDownloaders;

// Used to reset the AccessControlClass when mutator is taken off
var string OldAccessControlClass;
var string CurrentMapName;
var string NewMapName;
var string NewServerName;

// config

var() config sMapName MapNameSettings;
var() config sServerName ServerNameSettings;

var() config bool
	bBroadcastServerDownloads,
	bBroadcastDownloadingFileName,
	bBroadcastConnectingPlayerNames,
	bBroadcastConnectingPlayerName;

var() config array<sMapActors> MapActors;

// Initialize Mutator
function PreBeginPlay()
{
	// If this mutator was added as a server actor then we have to register ourself.
	// if( !bUserAdded )
	// {
	// 	if( Level.Game.BaseMutator == none )
	// 	{
	// 		Level.Game.BaseMutator = self;
	// 	}
	// 	else
	// 	{
	// 		NextMutator = Level.Game.BaseMutator;
	// 		Level.Game.BaseMutator = self;
	// 	}
	// 	bUserAdded = true;
	// }

	Log( "", Name );
	Log( "================================================", Name );
	Log( "=========="     $Name@Version$      "===========", Name );
	Log( "================================================", Name );
	Log( "", Name );

	ScanServerPackages();

 	if( AccessPlus_Control(Level.Game.AccessControl) != None )
 	{
 		Warn("An AccessControl was found, destroying!");
 		Level.Game.AccessControl.Destroy();
 	}

 	Level.Game.AccessControl = Spawn( Class'AccessPlus_Control', Level.Game );
}

function PostBeginPlay()
{
	if( AccessPlus_Control(Level.Game.AccessControl) != None )
	{
		Control = AccessPlus_Control(Level.Game.AccessControl);
		Control.MyMutator = Self;

 		CurrentMapName = string( Outer.Name );

		if( ServerNameSettings.bColorServerName )
			NewServerName = ConvertStringToColoredString( Class'GameReplicationInfo'.Default.ServerName, ServerNameSettings.ServerNameColors );
		else if( ServerNameSettings.bNoFadingColors )
			NewServerName = ReplacePriorityColors( ServerNameSettings.ServerNameForNoFadingColors );

		if( bBroadcastServerDownloads )
			SetTimer( 3, True );

		LoadMapActors();
	}
	else
	{
		Log( "AccessPlus_Control is none!", Name );
		Destroy();
		return;
	}
}

final protected function LoadMapActors()
{
	local int CurMapActor, NumMapActors;
	local class<Actor> SpawnActor;

	NumMapActors = MapActors.Length;
	if( NumMapActors == 0 )
		return;

	for( CurMapActor = 0; CurMapActor < NumMapActors; ++ CurMapActor )
	{
		if( MapActors[CurMapActor].MapName ~= CurrentMapName )
		{
			SpawnActor = Class<Actor>(DynamicLoadObject( MapActors[CurMapActor].ActorClass, Class'Class', False ));
			if( SpawnActor == None )
				continue;

			Spawn( SpawnActor, Level, 'MapActor', MapActors[CurMapActor].Location, MapActors[CurMapActor].Rotation );
		}
	}
}

/**
 * CountDownloaders, returns the amount of players that are currently downloading a file from the server(not redirect)
 * SLOW
 ** .:..:
 */
final function int CountDownloaders()
{
	local FileChannel FC;
	local int i;

	ForEach AllObjects( Class'FileChannel', FC )
		i ++;

	return i;
}

/**
 * GetSocketsCon
 * SLOW
 ** .:..:
 */
final function GetSocketsCon( out array<AccessPlus.SocketDataPacketType> Sockets )
{
	local NetConnection N;
	local int i,j,ii,Te,Fi,Ac,Ot,CNum;
	local array<string> S,C;
	local string IP,PLName,PLType,SIP,FileName;
	local array<ClientListType> LIST;

	ForEach AllObjects(Class'NetConnection',N)
	{
		if( N.Actor!=None )
		{
			LIST.Length = i+1;
			LIST[i].IP = N.Actor.GetPlayerNetworkAddress();
			LIST[i].Name = N.Actor.PlayerReplicationInfo.PlayerName;
			i++;
		}
	}
	Split(ConsoleCommand("Sockets",False)," Client ",S);
	For( i=1; i<S.Length; i++ )
	{
		ii = InStr(S[i]," ");
		SIP = Left(S[i],ii);
		S[i] = Mid(S[i],ii+1);
		ii = InStr(S[i]," ");
		IP = Left(S[i],ii);
		S[i] = Mid(S[i],ii+1);
		if( S[i]=="" )
			Continue; // Bad result...
		Split(S[i],"  Channel ",C);
		Te = 0;
		Ac = 0;
		Fi = 0;
		Ot = 0;
		FileName = "";
		For( j=1; j<C.Length; j++ )
		{
			ii = InStr(C[j],": ");
			C[j] = Mid(C[j],ii+2);
			if( Left(C[j],4)~="Text" )
				Te++;
			else if( Left(C[j],5)~="Actor" )
				Ac++;
			else if( Left(C[j],4)~="File" )
			{
				Fi++;
				if( FileName=="" )
				{
					FileName = Mid(C[j],6);
					ii = InStr(FileName,"',");
					FileName = Left(FileName,ii);
					ii = InStr(FileName,"/");
					While( ii!=-1 )
					{
						FileName = Mid(FileName,ii+1);
						ii = InStr(FileName,"/");
					}
				}
			}
			else Ot++;
		}
		PLName = "Unknown";
		if( Ac>0 ) // Active client
		{
			PLType = "Active";
			For( ii=0; ii<LIST.Length; ii++ )
			{
				if( LIST[ii].IP==IP )
				{
					PLName = LIST[ii].Name;
					Break;
				}
			}
		}
		else
		{
			if( Fi>0 )
				PLType = "Downloader";
			else PLType = "Inactive";

			if( bBroadcastConnectingPlayerName )
				PLName = Control.FindNameByIP(SIP);
		}
		Sockets.Length = CNum+1;
		Sockets[CNum].PlayerIP = IP;
		Sockets[CNum].PlayerName = PLName;
		Sockets[CNum].ConnectionState = PLType;
		Sockets[CNum].DLFile = FileName;
		Sockets[CNum].TextChannels = Te;
		Sockets[CNum].ActorChannels = Ac;
		Sockets[CNum].FileChannels = Fi;
		Sockets[CNum].OtherChannels = Ot;
		CNum++;
	}
}

/**
 * Checks whether someone is downloading directly from the server
 * then broadcasts the player that is downloading the file plus the filename(optional)
 *
 * Revision:
 ** .:..:
 ** Eliot
 */
function Timer()
{
	local int c,i,j;
	local array<SocketDataPacketType> S;
	local bool bFounded;
	local string Msg;

	c = CountDownloaders();
	if( c == OldDLersCount )
		return;

	if( bBroadcastDownloadingFileName )
	{
		if( c==0 )
		{
			Level.Game.Broadcast(Self,"Note: All server downloaders are gone now.");
			Log("All downloaders finished now",Name);
			SetTimer(3,True);
			if( bBroadcastDownloadingFileName )
				OldDownloaders.Length = 0;
			OldDLersCount = 0;
			Return;
		}
		else if( OldDLersCount==0 )
			SetTimer(1,True);
		GetSocketsCon(S);
		For( i=0; i<S.Length; i++ ) // Broadcast only changed downloads
		{
			if( S[i].FileChannels==0 || S[i].DLFile=="" )
			{
				S.Remove(i,1);
				i--;
			}
		}
		For( i=0; i<OldDownloaders.Length; i++ )
		{
			bFounded = False;
			For( j=0; j<S.Length; j++ )
			{
				if( S[j].PlayerIP==OldDownloaders[i] )
				{
					bFounded = True;
					Break;
				}
			}
			if( !bFounded )
			{
				OldDownloaders.Remove(i,1);
				i--;
			}
			else S.Remove(j,1);
		}
		For( i=0; i<S.Length; i++ )
		{
			Msg = "Lag alert:"@S[i].PlayerName@"is downloading"@S[i].DLFile@"off server, lag may occur!";
			Log(Msg,Name);
			Level.Game.Broadcast(Self,Msg);
			OldDownloaders[OldDownloaders.Length] = S[i].PlayerIP;
		}
	}
	else if( OldDLersCount<c )
	{
		Level.Game.Broadcast(Self,"Lag alert: a client is downloading off server, lag may occur!");
		if( OldDLersCount==0 )
			SetTimer(1,True);
	}
	else if( c==0 )
	{
		Level.Game.Broadcast(Self,"Note: All server downloaders are gone.");
		SetTimer(3,True);
		if( bBroadcastDownloadingFileName )
			OldDownloaders.Length = 0;
	}
	OldDLersCount = c;
}

/**
 * Avoids admins from putting this into the ServerPackages list
 * because this is a server-side mutator and private it is recommend this doesn't get downloaded by clients
 ** .:..:
 */
final private function ScanServerPackages() // Force a security scan that noob admins don't put me on serverpackages!
{
	local int i;
	local bool bChan;
	local GameEngine GE;

	For( i=0; i<Class'GameEngine'.Default.ServerPackages.Length; i++ )
	{
		if( Class'GameEngine'.Default.ServerPackages[i]~="AccessPlus" )
		{
			Class'GameEngine'.Default.ServerPackages.Remove(i,1);
			bChan = True;
		}
	}
	if( !bChan ) Return;
	Warn("AccessPlus was found in serverpackages!");
	Class'GameEngine'.Static.StaticSaveConfig();
	ForEach AllObjects(Class'GameEngine',GE)
	{
		GE.ServerPackages = Class'GameEngine'.Default.ServerPackages;
		GE.SaveConfig();
	}
}

// from GameInfo, but tweaked
final static function string MakeColorCode( color NewColor )
{
	// Text colours use 1 as 0.
	if(NewColor.R == 0)
		NewColor.R = 1;
	else if(NewColor.R == 10)
		NewColor.R = 11;
	else if(NewColor.R == 127)
		NewColor.R = 128;

	if(NewColor.G == 0)
		NewColor.G = 1;
	else if(NewColor.G == 10)
		NewColor.G = 11;
	else if(NewColor.G == 127)
		NewColor.G = 128;

	if(NewColor.B == 0)
		NewColor.B = 1;
	else if(NewColor.B == 10)
		NewColor.B = 11;
	else if(NewColor.B == 127)
		NewColor.B = 128;

	return Chr(0x1B)$Chr(NewColor.R)$Chr(NewColor.G)$Chr(NewColor.B);
}

final static function string ConvertStringToColoredString( string StringToConvert, color FadeColors[2] )
{
	local vector A, B, NewColor;
	local string ConvertedString;
	local int StringLength, SavedStringLength;
	local color OldColor;

	// Turn color 0 into vector
	A.X = FadeColors[1].R;
	A.Y = FadeColors[1].G;
	A.Z = FadeColors[1].B;

	// Turn color 1 into vector
	B.X = FadeColors[0].R;
	B.Y = FadeColors[0].G;
	B.Z = FadeColors[0].B;

	// Check length and alpha fade speed
	StringLength = Len( StringToConvert );
	SavedStringLength = StringLength;

	// Add alpha fading
	while( StringLength > 0 )
	{
		if( Left( StringToConvert, 1 ) == " " )
			ConvertedString $= " ";
		else if( Left( StringToConvert, 1 ) == "'" )
			ConvertedString $= "'";
		else
		{
			NewColor = A*(1.f-float(StringLength)/float(SavedStringLength))+B*(float(StringLength)/float(SavedStringLength));
			FadeColors[1].R = NewColor.X;
			FadeColors[1].G = NewColor.Y;
			FadeColors[1].B = NewColor.Z;
			if( OldColor == FadeColors[1] )
				ConvertedString $= Left( StringToConvert, 1 );
			else
			{
				ConvertedString $= MakeColorCode( FadeColors[1] )$Left( StringToConvert, 1 );
				OldColor = FadeColors[1];
			}
		}
		StringToConvert = Mid( StringToConvert, 1 );
		StringLength --;
	}
	return ConvertedString;
}

// Eliot
function bool CheckReplacement( Actor Other, out byte bSuperRelevant )
{
	if( Other.IsA('UTServerAdminSpectator') )
	{
		WebAdmin = UTServerAdminSpectator(Other);
		return True;
	}
	else if( Other.IsA('PlayerController') )
	{
		PostLogin( PlayerController(Other) );
		return True;
	}
	return True;
}

function PostLogin( PlayerController PC )
{
}

// Eliot
function GetServerDetails( out GameInfo.ServerResponseLine ServerState )
{
	local int CurPrefix, MaxPrefix;

	Super.GetServerDetails(ServerState);
	Level.Game.AddServerDetail( ServerState, "AccessPlus", "Version:"@Version );

	if( Len( NewMapName ) == 0 )
	{
		NewMapName = Level.Game.StripColor( ServerState.MapName );
 		if( MapNameSettings.bReplaceMapPrefixs && MapNameSettings.MapPrefixs.Length > 0 )
		{
			MaxPrefix = MapNameSettings.MapPrefixs.Length;
			for( CurPrefix = 0; CurPrefix < MaxPrefix; CurPrefix ++ )
			{
				if( MapNameSettings.MapPrefixs[CurPrefix].SearchPrefix == Level.Game.MapPrefix )
				{
					NewMapName = MapNameSettings.MapPrefixs[CurPrefix].NewPrefix$Mid( NewMapName, InStr( NewMapName, "-" ) ) ;
					break;
				}
			}
		}

		if( MapNameSettings.bColorMapName )
		{
			if( MapNameSettings.bUseFadingColors )
				NewMapName = ConvertStringToColoredString( NewMapName, MapNameSettings.MapNameColors );
			else NewMapName = MakeColorCode( MapNameSettings.MapNameColors[0] )$NewMapName;
		}
	}

	if( Len( NewMapName ) > 0 )
		ServerState.MapName = NewMapName;

	if( Len( NewServerName ) > 0 )
		ServerState.ServerName = NewServerName;
}

//==============================================================================
// Looks up in OriginalStr for color codes like {255,255,255} and replace it with the real color codes
// Replace the following:
// {GAME} = Current voted game name
// {R,G,B} = Add color tag in desired color
// {MAP} = Map title
// {FILE} = Map file name
function string ReplacePriorityColors( string OrginalStr, optional string GameName )
{
	local int i,j;
	local string S,F,M;
	local Color C;

	While( True )
	{
		i = InStr(OrginalStr,"{");
		if( i==-1 )
			Return F$OrginalStr;
		F = F$Left(OrginalStr,i);
		S = Mid(OrginalStr,i+1);
		j = InStr(S,"}");
		if( j==-1 )
			OrginalStr = S;
		else
		{
			OrginalStr = Mid(S,j+1);
			S = Left(S,j);
			if( S~="GAME" )
				F = F$GameName;
			else if( S~="MAP" )
				F = F$Level.Title;
			else if( S~="File" )
			{
				M = string(Self);
				M = Left(M,InStr(M,"."));
				F = F$M;
			}
			else
			{
				C.R = 0;
				C.G = 0;
				C.B = 0;
				i = InStr(S,",");
				if( i==-1 )
					C.R = byte(S);
				else
				{
					C.R = byte(Left(S,i));
					S = Mid(S,i+1);
					i = InStr(S,",");
					if( i==-1 )
						C.G = byte(S);
					else
					{
						C.G = byte(Left(S,i));
						C.B = byte(Mid(S,i+1));
					}
				}
				F = F$Level.Game.MakeColorCode(C);
			}
		}
	}
}

DefaultProperties
{
	bBroadcastServerDownloads=True
	bBroadcastDownloadingFileName=True
	bBroadcastConnectingPlayerNames=True
	bBroadcastConnectingPlayerName=True

	MapNameSettings=(bColorMapName=True,bUseFadingColors=True,bReplaceMapPrefixs=False,MapNameColors[0]=(R=255,G=0,B=0,A=255),MapNameColors[1]=(R=0,G=255,B=0,A=255))
	ServerNameSettings=(bColorServerName=True,ServerNameColors[0]=(R=0,G=0,B=255,A=255),ServerNameColors[1]=(R=255,G=0,B=0,A=255))
}