#include <sourcemod>
#include <nexd>
#include <caseopening>

#define PLUGIN_NEV	"Case natives example"
#define PLUGIN_LERIAS	"examples"
#define PLUGIN_AUTHOR	"Nexd"
#define PLUGIN_VERSION	"1.0"
#define PLUGIN_URL	"https://github.com/KillStr3aK"
#pragma tabsize 0

public Plugin myinfo = 
{
	name = PLUGIN_NEV,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_LERIAS,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_testcase", Command_TestCase);
}

public Action Command_TestCase(int client, int args)
{
	if(!Case_IsBanned(Jatekos(client)) && Case_IsInventoryLoaded(Jatekos(client)))
	{
		Case_GiveCaseAmount(Jatekos(client), 1, GetRandomInt(1, 6));
		Case_GiveKeyAmount(Jatekos(client), 2, GetRandomInt(3, 9));
	}
}