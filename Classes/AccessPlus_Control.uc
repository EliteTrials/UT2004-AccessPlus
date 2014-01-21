//==============================================================================
// AccessPlus_Control.uc Created @ 2006
// Coded by 'Marco' and 'Eliot van uytfanghe'
//==============================================================================
Class AccessPlus_Control Extends AccessControlIni
	Config(AccessPlus);

// Structures

struct sAdmins
{
	var string
		AdminNickName,
		AdminName,
		AdminPassword,
		AdminGuid,
		AdminPrivelages;
};

struct sTempBan
{
	var string
		BannedGuid,
		BannedPlayerName;

	var int
		BannedDays;
};

struct sAdminPriv
{
	var PlayerReplicationInfo
		Admin;

	var string
		BlockedCommands[100];

	var int
		NumBlckCmds;

	var bool
		bMasterAdmin;
};

struct sLoggedClientsType
{
	var string
		Names,
		ID,
		IP;
};

// Admins that are logged in
var array<sAdminPriv> AdminPriveleges;

var AccessPlus MyMutator;

var string
	MasterAdminTag,
	CoAdminTag;

var const color
	AdminTagColor,
	AdminNameColor;
	
var() config array<sAdmins> 				AdminGroup;
var() config array<sTempBan> 				TempBannedPlayers;
var() private globalconfig string 			GlobalAdminPW;
var() config array<sLoggedClientsType> 		ClientsLog;

function PostBeginPlay()
{
	Super.PostBeginPlay();
	CleanOutOldBans();
}

function bool IsAdmin(PlayerController P)
{
	return P.PlayerReplicationInfo.bAdmin;
}

function CleanOutOldBans() // Clear out old temp banned players.
{
	local int j,i,d;

	j = TempBannedPlayers.Length;
	if( j==0 ) Return;
	d = GetDayNumber();
	For( i=0; i<j; i++ )
	{
		if( TempBannedPlayers[i].BannedDays<=d )
		{
			TempBannedPlayers[i] = TempBannedPlayers[j-1];
			TempBannedPlayers.Length = j-1;
			j--;
		}
	}
}

function bool CanPerform(PlayerController P, string Action)
{
	// Standard Admin actions only performed by Admin
	return P.PlayerReplicationInfo.bAdmin;
}

final function TellGlobalPW( PlayerController Other )
{
	if( !MayExecute(Other,"MasterAdminCmd") ) Return;
	Other.ClientMessage("Current GlobalAdmin password is '"$GlobalAdminPW$"'");
}

final function SetGlobalPassword( PlayerController Other, string PW )
{
	if( !MayExecute(Other,"MasterAdminCmd") ) Return;
	Other.ClientMessage("Current GlobalAdmin password is now set to '"$PW$"'");
	GlobalAdminPW = PW;
	SaveConfig();
}

final function int GetDayNumber()
{
	local int Y,D;

	Y = Level.Year;
	D = Y/4;
	Y = Y-D;
	D*=366;
	D+=(Y*365);
	D+=Level.Month*30+Level.Day;
	Return D;
}

function KickBanPlayer2( PlayerController Banned, PlayerController Banner, optional int NumDays )
{
	local int i;

	if( NumDays==0 )
	{
		Log("Adding Global Ban for: "$Banned.GetPlayerIDHash()@Banned.PlayerReplicationInfo.PlayerName);
		BannedIDs[BannedIDs.Length] = Banned.GetPlayerIDHash()@Banned.PlayerReplicationInfo.PlayerName;
		Banned.ClientNetworkMessage("AC_Ban",Level.Game.GameReplicationInfo.AdminEmail);
		Level.Game.BroadcastHandler.Broadcast(Banned,Banned.PlayerReplicationInfo.PlayerName@"has been banned.");
	}
	else
	{
		i = TempBannedPlayers.Length;
		TempBannedPlayers.Length = i+1;
		TempBannedPlayers[i].BannedGuid = Banned.GetPlayerIDHash();
		TempBannedPlayers[i].BannedDays = GetDayNumber()+NumDays;
		TempBannedPlayers[i].BannedPlayerName = Banned.PlayerReplicationInfo.PlayerName;
		Banned.ClientNetworkMessage("You have been banned from this server by an admin for"@NumDays@Eval((NumDays==1),"day","days"),"If you do not think you deserve this ban, contact ["$Level.Game.GameReplicationInfo.AdminEmail$"]");
		Level.Game.BroadcastHandler.Broadcast(Banned,Banned.PlayerReplicationInfo.PlayerName@"has been banned for"@NumDays@Eval((NumDays==1),"day.","days."));
	}
	SaveConfig();

	if ( Banned.Pawn != None )
		Banned.Pawn.Destroy();
	Banned.Destroy();
}

function int PlayerIsBanned( string ID )
{
	local int j,i,d;

	j = TempBannedPlayers.Length;
	if( j==0 ) Return 0;
	d = GetDayNumber();
	For( i=0; i<j; i++ )
	{
		if( TempBannedPlayers[i].BannedGuid~=ID )
		{
			if( TempBannedPlayers[i].BannedDays<=d )
			{
				TempBannedPlayers[i] = TempBannedPlayers[j-1];
				TempBannedPlayers.Length = j-1;
				j--; // Old ban, clear it.
			}
			else Return TempBannedPlayers[i].BannedDays-d;
		}
	}
	Return 0;
}

event PreLogin(string Options,string Address,string PlayerID,out string Error,out string FailCode,bool bSpectator)
{
	local int i,j,y,w;
	local string S,S2,S3;

	BroadcastAdminMessage(,"PreLogin:"@Options);
	Log("Pre:"@Options);
	S3 = Level.Game.ParseOption( Options, "Name" );
	if( MyMutator.bBroadcastConnectingPlayerNames )
		S2 = LogPlayer(S3,PlayerID,Address);

	i = PlayerIsBanned(PlayerID);
	if( i>0 )
	{
		Error = "";
		While( i>=365 )
		{
			y++;
			i-=365;
		}
		While( i>=30 )
		{
			j++;
			i-=30;
		}
		While( i>=7 )
		{
			w++;
			i-=7;
		}
		S = "";
		if( y>0 )
			S = y@Eval((y==1),"year","years");
		if( j>0 )
		{
			if( S=="" )
				S = j@Eval((j==1),"month","months");
			else S = S$","@j@Eval((j==1),"month","months");
		}
		if( w>0 )
		{
			if( S=="" )
				S = w@Eval((w==1),"week","weeks");
			else S = S$","@w@Eval((w==1),"week","weeks");
		}
		if( i>0 )
		{
			if( S=="" )
				S = i@Eval((i==1),"day","days");
			else S = S$","@i@Eval((i==1),"day","days");
		}
		FailCode = "You are still banned for"@S;
		BroadcastAdminMessage(,S3@"["$PlayerID$"] Failed to login:"@FailCode);
		Return;
	}
	Super.PreLogin(Options,Address,PlayerID,Error,FailCode,bSpectator);
	if( Error!="" )
		BroadcastAdminMessage(,S3@"["$PlayerID$"] Failed to login:"@Error);
	else if( FailCode!="" )
		BroadcastAdminMessage(,S3@"["$PlayerID$"] Failed to login:"@FailCode);
	else
	{
		if( MyMutator.bBroadcastConnectingPlayerName )
		{
			if( Level.Game.IsA('CoopGame') )
				BroadcastAdminMessage(,"Pre:"@S3@"AKA:"@S2);
			else BroadcastAdminMessage("Pre:"@S3@"AKA:"@S2,"Pre:"@S3@"AKA:"@S2,S3@"is connecting to server.");
		}
	}
}

function string LogPlayer( string PlayerName, string PlayerID, string PlayerIP )
{
	local int i,j;

	PlayerName = StripTextFrom(PlayerName,",");
	PlayerName = StripTextFrom(PlayerName,Chr(34));
	i = InStr(PlayerIP,":");
	if( i!=-1 )
		PlayerIP = Left(PlayerIP,i);
	j = ClientsLog.Length;
	For( i=0; i<j; i++ )
	{
		if( ClientsLog[i].ID~=PlayerID )
		{
			ClientsLog[i].IP = PlayerIP;
			if( !NameIsThere(ClientsLog[i].Names,PlayerName) )
				ClientsLog[i].Names = ClientsLog[i].Names$","@PlayerName;
			SaveConfig();
			Return ClientsLog[i].Names;
		}
	}
	ClientsLog.Length = j+1;
	ClientsLog[j].ID = PlayerID;
	ClientsLog[j].IP = PlayerIP;
	ClientsLog[j].Names = PlayerName;
	SaveConfig();
	Return PlayerName;
}

function string StripTextFrom( string ToStrip, string From )
{
	local int i;

	i = InStr(ToStrip,From);
	While( i!=-1 )
	{
		ToStrip = Left(ToStrip,i)$Mid(ToStrip,i+1);
		i = InStr(ToStrip,From);
	}
	Return ToStrip;
}

function bool NameIsThere( string PLNames, string PLName )
{
	local int i;

	i = InStr(PLNames,",");
	While( i!=-1 )
	{
		if( PLName~=Left(PLNames,i) )
			Return True;
		PLNames = Mid(PLNames,i+2);
		i = InStr(PLNames,",");
	}
	Return (PLNames~=PLName);
}

function bool DidAdminLogin( PlayerController Other, string Password, bool bBroadcast )
{
	local string ID,s;
	local int i,j,jx;

	// Is Global-Admin?
	if( Password != "" && Password ~= GlobalAdminPW )
	{
		// Add this player(other) to the current logged admins list.
		jx = AdminPriveleges.Length;
		AdminPriveleges.Length = jx+1;
		AdminPriveleges[jx].Admin = Other.PlayerReplicationInfo;
		AdminPriveleges[jx].bMasterAdmin = True;

		Other.PlayerReplicationInfo.bAdmin = True;
		if( bBroadcast )
			Level.Game.Broadcast( Self, GetAdminLoginMessage( Other.PlayerReplicationInfo )@"logged in as administrator." );

		return True;
	}

	ID = Other.GetPlayerIDHash();
	j = AdminGroup.Length;
	For( i=0; i<j; i++ )
	{
		if( AdminGroup[i].AdminGuid==ID || (AdminGroup[i].AdminPassword!="" && AdminGroup[i].AdminPassword~=Password) )
		{
			// Add this player(other) to the current logged admins list.
			jx = AdminPriveleges.Length;
			AdminPriveleges.Length = jx+1;
			AdminPriveleges[jx].Admin = Other.PlayerReplicationInfo;

			s = AdminGroup[i].AdminPrivelages;
			j = InStr(S,",");
			While( j!=-1 )
			{
				AdminPriveleges[jx].BlockedCommands[AdminPriveleges[jx].NumBlckCmds] = Left(S,j);
				AdminPriveleges[jx].NumBlckCmds++;
				S = Mid(S,j+1);
				j = InStr(S,",");
			}
			if( S!="" )
			{
				AdminPriveleges[jx].BlockedCommands[AdminPriveleges[jx].NumBlckCmds] = S;
				AdminPriveleges[jx].NumBlckCmds++;
			}

			Other.PlayerReplicationInfo.bAdmin = True;
			if( bBroadcast )
				Level.Game.Broadcast( Self, GetAdminLoginMessage( Other.PlayerReplicationInfo )@"logged in as"@AdminGroup[i].AdminName$"." );

			return True;
		}
	}
}

Function string GetAdminLoginMessage( PlayerReplicationInfo PRI )
{
	local int CurAdmin, MaxAdmin;

	MaxAdmin = AdminPriveleges.Length;
	for( CurAdmin = 0; CurAdmin < MaxAdmin; CurAdmin ++ )
	{
		if( AdminPriveleges[CurAdmin].Admin == PRI )
		{
			if( AdminPriveleges[CurAdmin].bMasterAdmin )
				return MyMutator.MakeColorCode( AdminTagColor )$MasterAdminTag$MyMutator.MakeColorCode( AdminNameColor )@PRI.PlayerName;
			else return MyMutator.MakeColorCode( AdminTagColor )$CoAdminTag$MyMutator.MakeColorCode( AdminNameColor )@PRI.PlayerName;
		}
	}
	return "";
}

Function string GetAdminLogoutMessage( PlayerReplicationInfo PRI )
{
	local int CurAdmin, MaxAdmin;
	local string Sex;

	if( PRI.bIsFemale )
		Sex = "her";
	else Sex = "his";

	MaxAdmin = AdminPriveleges.Length;
	for( CurAdmin = 0; CurAdmin < MaxAdmin; CurAdmin ++ )
	{
		if( AdminPriveleges[CurAdmin].Admin == PRI )
		{
			if( AdminPriveleges[CurAdmin].bMasterAdmin )
				return MyMutator.MakeColorCode( AdminTagColor )$MasterAdminTag$MyMutator.MakeColorCode( AdminNameColor )@PRI.PlayerName@"gave up"@Sex@"administrator abilities";
			else return MyMutator.MakeColorCode( AdminTagColor )$CoAdminTag$MyMutator.MakeColorCode( AdminNameColor )@PRI.PlayerName@"gave up"@Sex@"administrator abilities";
		}
	}
	return "";
}

function bool MayExecute( PlayerController Other, string Cmd )
{
	local int i,j,x;

	j = AdminPriveleges.Length;
	For( i=0; i<j; i++ )
	{
		if( AdminPriveleges[i].Admin!=None && AdminPriveleges[i].Admin==Other.PlayerReplicationInfo )
		{
			if( AdminPriveleges[i].bMasterAdmin )
				Return True;
			else if( Cmd~="MasterAdminCmd" )
			{
				Other.ClientMessage("You need to be logged in as global administrator to execute this command");
				Return False;
			}
			else if( AdminPriveleges[i].BlockedCommands[0]=="All" )
			{
				Other.ClientMessage("You are currently unable to execute any admin commands");
				Return False;
			}
			For( x=0; x<AdminPriveleges[i].NumBlckCmds; x++ )
			{
				if( AdminPriveleges[i].BlockedCommands[x]~=Cmd )
				{
					Other.ClientMessage("You don't have enough priveleges to execute command '"$Cmd$"'");
					Return false;
				}
			}
			Return True;
		}
	}
	Other.ClientMessage("You don't have any priveleges at all, please relogin as admin");
	Return false;
}

function RemoveAdminPriv( PlayerController Other )
{
	local int i,j;

	j = AdminPriveleges.Length;
	For( i=0; i<j; i++ )
	{
		if( AdminPriveleges[i].Admin==None || AdminPriveleges[i].Admin==Other.PlayerReplicationInfo )
		{
			AdminPriveleges[i] = AdminPriveleges[j-1];
			AdminPriveleges.Length = j-1;
			j--;
		}
	}
	Other.PlayerReplicationInfo.bAdmin = False;
}

function BroadcastAdminMessage( optional string Msg, optional string WebAMessage, optional string NormalMsg )
{
	local Controller C;

	for( C = Level.ControllerList; C != None; C = C.NextController )
	{
		if( C.IsA('PlayerController') && C != MyMutator.WebAdmin )
		{
			if( C.PlayerReplicationInfo != None && C.PlayerReplicationInfo.bAdmin && Msg!="" )
				PlayerController(C).ClientMessage(Msg);
			else if( NormalMsg!="" )
				PlayerController(C).ClientMessage(NormalMsg);
		}
	}
}

function string FindNameByIP( string IPToFind )
{
	local int i;
	local array<string> S;

	For( i=0; i<ClientsLog.Length; i++ )
	{
		if( ClientsLog[i].IP==IPToFind )
		{
			if( InStr(ClientsLog[i].Names,",")==-1 )
				Return ClientsLog[i].Names;
			Split(ClientsLog[i].Names,",",S);
			i = S.Length-1;
			Return S[i];
		}
	}
	Return "Unknown";
}

DefaultProperties
{
	AdminClass=Class'AccessPlus_Admin'

	// Admin related
	MasterAdminTag="Global-Admin"
	CoAdminTag="Co-Admin"

	AdminTagColor=(R=200,G=200,B=0,A=255)
	AdminNameColor=(R=255,G=255,B=255,A=255)
}
