class APControlBase extends AccessControlIni;

final function string GetGamePassword()
{
	return ConsoleCommand("get Engine.AccessControl GamePassword");
}

final function string GetAdminPassword()
{
	return ConsoleCommand("get Engine.AccessControl AdminPassword");
}

function bool SetAdminPassword( string newPassword )
{
	ConsoleCommand("set Engine.AccessControl AdminPassword" @ newPassword);
	SaveConfig();
	return GetAdminPassword() == newPassword;
}

final function string GetMasterAdminName()
{
	return ConsoleCommand("get Engine.AccessControl AdminName");
}

final function SetMasterAdminName( string newName )
{
	ConsoleCommand("set Engine.AccessControl AdminName" @ newName);
}

final function string GetMasterAdminpassword()
{
	return GetAdminPassword();
}

final function SetMasterAdminPassword( string newPassword )
{
	SetAdminPassword( newPassword );
}

function bool IsAdmin( PlayerController player )
{
	if( player == none )
		return false;

	return player.PlayerReplicationInfo.bAdmin;
}

// Utils

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