//==============================================================================
// AccessPlus_Control.uc Created @ 2006
// Coded by 'Marco' and 'Eliot van uytfanghe'
//==============================================================================
class AccessPlus_Control extends APControlBase;

struct sAdminAccount
{
	var string
		AdminNickName,
		AdminName,
		AdminPassword,
		AdminGuid,
		AdminPrivileges;
};

struct sTempBan
{
	var string
		BannedGuid,
		BannedPlayerName;

	var int
		BannedDays;
};

struct sActiveAdmin
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

var const string MasterAdminTag;
var const Color AdminTagColor, AdminNameColor;

/** List of logged in admins. FIXME: Name */
var protected array<sActiveAdmin> 			ActiveAdmins;

/** List of admin accounts. */
var() config array<sAdminAccount> 			AdminGroup;

/** List of banned players. */
var() config array<sTempBan> 				TempBannedPlayers;

var localized string LoggedInMessage, LoggedOutMessage;

/**
 * Logs of all players that have connected to this server in its lifetime.
 * Holds all known names, IPs and GUIDs of players.
 */
var config array<sLoggedClientsType> 		ClientsLog;

var AccessPlus MyMutator;

event PreBeginPlay()
{
	super.PreBeginPlay();
	CleanOutOldBans();
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

// FIXME: Why is this overwriting.
function bool CanPerform(PlayerController P, string Action)
{
	// Standard Admin actions only performed by Admin
	return IsAdmin(P);
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

function bool DidAdminLogin( PlayerController Other, string Password, bool bBroadcast )
{
	local string ID,s;
	local int i,j,jx;

	// Is Global-Admin?
	if( Password != "" && Password ~= GetMasterAdminPassword() )
	{
		// Add this player(other) to the current logged admins list.
		jx = ActiveAdmins.Length;
		ActiveAdmins.Length = jx+1;
		ActiveAdmins[jx].Admin = Other.PlayerReplicationInfo;
		ActiveAdmins[jx].bMasterAdmin = True;

		Other.PlayerReplicationInfo.bAdmin = True;
		if( bBroadcast )
			Level.Game.Broadcast( Self, GetAdminLoginMessage( Other.PlayerReplicationInfo ) );

		return True;
	}

	ID = Other.GetPlayerIDHash();
	j = AdminGroup.Length;
	For( i=0; i<j; i++ )
	{
		if( AdminGroup[i].AdminGuid==ID || (AdminGroup[i].AdminPassword!="" && AdminGroup[i].AdminPassword~=Password) )
		{
			// Add this player(other) to the current logged admins list.
			jx = ActiveAdmins.Length;
			ActiveAdmins.Length = jx+1;
			ActiveAdmins[jx].Admin = Other.PlayerReplicationInfo;

			s = AdminGroup[i].AdminPrivileges;
			j = InStr(S,",");
			While( j!=-1 )
			{
				ActiveAdmins[jx].BlockedCommands[ActiveAdmins[jx].NumBlckCmds] = Left(S,j);
				ActiveAdmins[jx].NumBlckCmds++;
				S = Mid(S,j+1);
				j = InStr(S,",");
			}
			if( S!="" )
			{
				ActiveAdmins[jx].BlockedCommands[ActiveAdmins[jx].NumBlckCmds] = S;
				ActiveAdmins[jx].NumBlckCmds++;
			}

			Other.PlayerReplicationInfo.bAdmin = True;
			if( bBroadcast )
				Level.Game.Broadcast( Self, GetAdminLoginMessage( Other.PlayerReplicationInfo, AdminGroup[i].AdminName ) );

			return True;
		}
	}
}

Function string GetAdminLoginMessage( PlayerReplicationInfo PRI, optional string adminName )
{
	local string s;

	if( adminName == "" )
	{
		adminName = MasterAdminTag;
	}
	s = Repl(Repl(LoggedInMessage,
			"%t", MyMutator.MakeColorCode(AdminTagColor)$adminName),
			"%o", MyMutator.MakeColorCode(AdminNameColor)$PRI.PlayerName);
	return  s;
}

function AdminLoggedOut( PlayerController admin, bool beSilent )
{
	if( !beSilent )
	{
		Level.Game.Broadcast( self, GetAdminLogoutMessage( admin.PlayerReplicationInfo ) );
	}
	RemoveAdminPriv( admin );
}

function string GetAdminLogoutMessage( PlayerReplicationInfo PRI, optional string adminName )
{
	local string sex, s;

	if( PRI.bIsFemale )
		sex = "her";
	else sex = "his";

	if( adminName == "" )
	{
		adminName = MasterAdminTag;
	}
	s = Repl(Repl(Repl(LoggedOutMessage,
			"%t", MyMutator.MakeColorCode(AdminTagColor)$adminName),
			"%o", MyMutator.MakeColorCode(AdminNameColor)$PRI.PlayerName),
			"%s", sex);
	return  s;
}

function bool MayExecute( PlayerController Other, string Cmd )
{
	local int i,j,x;

	j = ActiveAdmins.Length;
	For( i=0; i<j; i++ )
	{
		if( ActiveAdmins[i].Admin!=None && ActiveAdmins[i].Admin==Other.PlayerReplicationInfo )
		{
			if( ActiveAdmins[i].bMasterAdmin )
				Return True;
			else if( Cmd~="MasterAdminCmd" )
			{
				Other.ClientMessage("You need to be logged in as master administrator to execute this command");
				Return False;
			}
			else if( ActiveAdmins[i].BlockedCommands[0]=="All" )
			{
				Other.ClientMessage("You are currently unable to execute any admin commands");
				Return False;
			}
			For( x=0; x<ActiveAdmins[i].NumBlckCmds; x++ )
			{
				if( ActiveAdmins[i].BlockedCommands[x]~=Cmd )
				{
					Other.ClientMessage("You don't have enough privileges to execute command '"$Cmd$"'");
					Return false;
				}
			}
			Return True;
		}
	}
	Other.ClientMessage("You don't have any privileges at all, please relogin as admin");
	Return false;
}

function RemoveAdminPriv( PlayerController Other )
{
	local int i,j;

	j = ActiveAdmins.Length;
	For( i=0; i<j; i++ )
	{
		if( ActiveAdmins[i].Admin==None || ActiveAdmins[i].Admin==Other.PlayerReplicationInfo )
		{
			ActiveAdmins[i] = ActiveAdmins[j-1];
			ActiveAdmins.Length = j-1;
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
	MasterAdminTag="Admin"

	AdminTagColor=(R=255,G=0,B=0,A=255)
	AdminNameColor=(R=255,G=255,B=255,A=255)

	LoggedInMessage="%t %o logged in as administrator."
	LoggedOutMessage="%t %o gave up %s administrator abilities."
}
