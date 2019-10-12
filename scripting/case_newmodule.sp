#include <sourcemod>
#include <nexd>
#include <caseopening>

#define PLUGIN_NEV	"Caseopening system new module template"
#define PLUGIN_LERIAS	"Template for a new module"
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
	Case_RegisterModule("module.type", false, OnTypeOpened);
}

public void OnTypeOpened(Jatekos jatekos, char[] value)
{
	PrintToChat(jatekos.index, "You have opened %s", value);
}