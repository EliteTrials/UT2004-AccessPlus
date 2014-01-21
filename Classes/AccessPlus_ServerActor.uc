class AccessPlus_ServerActor extends Info;

function PreBeginPlay()
{
	Level.Game.AddMutator( string(class'AccessPlus'), true );
	Destroy();
}
