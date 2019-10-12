#include <sourcemod>
#include <caseopening>
#include <nexd>

#define PLUGIN_NEV	"Caseopening system"
#define PLUGIN_LERIAS	"(8_8)"
#define PLUGIN_AUTHOR	"Nexd"
#define PLUGIN_VERSION	"1.0.1011"
#define PLUGIN_URL	"https://github.com/KillStr3aK"

#define MAX_CASES 10
#define MAX_CASE_SPAWN 10
#define MAX_ITEMS 16
#define MAX_MODULES 64
#pragma tabsize 0

enum Case {
	String:CaseName[32],
	String:Unique_ID[32],
	String:Model[PLATFORM_MAX_PATH],
	bool:bReqKey,
	CaseID
}

enum SpawnedCase {
	Float:fPosX,
	Float:fPosY,
	Float:fPosZ,
	bool:bSpawned,
	String:UniqueName[8],
	CaseId,
	ItemId,
	EntRef
}

enum Item {
	String:Name[32],
	String:Unique[32],
	String:Type[32],
	String:Value[32],
	String:Grade[10],
	Float:Chance,
	ParentCase
}

enum Inventory {
	Cases,
	Keys
}

enum Module_Handler
{
	String:mType[64],
	bool:ValueType,
	Handle:hPlugin,
	Function:fOpened
}

int g_eCase[MAX_CASES][Case];
int g_eItem[MAX_CASES][MAX_ITEMS][Item];
int m_iCases = 1;
int m_iItems[MAX_CASES] = 0;

int m_iCacheCase[MAXPLAYERS+1];
int m_iPlayerID[MAXPLAYERS+1];
int PlayerInventory[MAXPLAYERS+1][MAX_CASES][Inventory];
int m_iSzam[MAXPLAYERS+1] = 0;
int m_iOpenedItem[MAXPLAYERS+1] = -1;

int g_eTypeHandlers[MAX_MODULES][Module_Handler];
int g_iTypeHandlers = 0;

int g_iMarker = -1;
int g_eSpawnPositions[MAX_CASES][MAX_CASE_SPAWN][SpawnedCase];
int g_iLoadedCases[MAX_CASES] = 0;
int g_iSpawnedCases[MAX_CASES] = 0;

float m_fChance[MAXPLAYERS+1] = -1.0;
float m_fOffsetZ;

bool m_bOpening[MAXPLAYERS+1] = false;
bool m_bBanned[MAXPLAYERS+1] = false;
bool m_bLoaded[MAXPLAYERS+1][Inventory];

char m_cChanceDetails[128];
char m_cDropSound[PLATFORM_MAX_PATH];

enum {
	CEnum_Config,
	CEnum_Debug,
	CEnum_Drops,
	CEnum_Minplayer,
	CEnum_DropChance,
	CEnum_DropDelay,
	CEnum_DropSound,
	CEnum_PickUp,
	CEnum_CaseSpawn,
	CEnum_OffsetFloat,
	Count
}

Database g_DB;
ConVar g_cR[Count];

#include "case_modules/store_credits.sp"
#include "case_modules/store_database.sp" //Keep this here, and if you're adding new modules which is related to the store, dont include the module file above this one. You can comment out these modules if you're not using store at all.
#include "case_modules/store_playerskin.sp"
#include "case_modules/store_pets.sp"
#include "case_modules/store_trails.sp"
#include "case_modules/store_paintball.sp"
#include "case_modules/store_hats.sp"

#include "case_modules/vipsystem.sp" // https://github.com/KillStr3aK/csgo-vipsystem Comment this line out if you dont want to use it.

#pragma newdecls required;

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
	RegAdminCmd("sm_cases", Command_Cases, ADMFLAG_ROOT);
	RegAdminCmd("sm_refreshcases", Command_Refresh, ADMFLAG_ROOT);
	RegAdminCmd("sm_loadinv", Command_Loadinv, ADMFLAG_ROOT);

	RegAdminCmd("sm_caseban", Command_BanPlayer, ADMFLAG_ROOT);
	RegAdminCmd("sm_drop", Command_Drop, ADMFLAG_ROOT);

	g_cR[CEnum_Config] = CreateConVar("case_database", "ladarendszer", "databases.cfg section name");
	g_cR[CEnum_Debug] = CreateConVar("case_debug", "0", "debug mode");
	g_cR[CEnum_Drops] = CreateConVar("case_drops", "1", "Endgame drops");

	g_cR[CEnum_Minplayer] = CreateConVar("case_drops_minplayer", "1", "Minimum player count for endgame drops");
	g_cR[CEnum_DropChance] = CreateConVar("case_drops_chance", "50", "Chance for the drop event to even happen ( 1 - 100 )", _, true, float(1), true, float(100));
	g_cR[CEnum_DropDelay] = CreateConVar("case_drops_delay", "6.5", "Delay for the drop event");
	g_cR[CEnum_DropSound] = CreateConVar("case_drops_sound", "sound/steelclouds/lada/ladadrop.mp3", "Sound path for drop sound (not relative)");

	g_cR[CEnum_PickUp] = CreateConVar("case_pickup", "1", "Enable case pickups");
	g_cR[CEnum_CaseSpawn] = CreateConVar("case_pickup_minplayer", "1", "Minimum players for cases to spawn");
	g_cR[CEnum_OffsetFloat] = CreateConVar("case_pickup_offset", "30.0");

	HookEvent("round_start", Event_RoundStart);
	HookEvent("cs_intermission", Event_EndMatch);

	//Core included modules
	StoreCreditsOnPluginStart();
	StorePlayerSkinsOnPluginStart();
	StorePetOnPluginStart();
	StoreTrailOnPluginStart();
	StorePaintballOnPluginStart();
	StoreHatsOnPluginStart();
	VipSystemOnPluginStart();
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Case_RegisterModule", Native_RegisterModule);
	CreateNative("Case_IsInventoryLoaded", Native_IsInventoryLoaded);
	
	return APLRes_Success;
}

public void OnMapStart()
{
	if(g_cR[CEnum_PickUp].BoolValue)
	{
		for (int i = 1; i < m_iCases; ++i)
		{
			g_iLoadedCases[i] = 0;
		}

		g_iMarker = PrecacheModel("sprites/blueglow1.vmt");
	}

	OnMapStartLoadCasesFromFile();

	g_cR[CEnum_DropSound].GetString(m_cDropSound, sizeof(m_cDropSound));
	AddFileToDownloadsTable(m_cDropSound);

	ReplaceString(m_cDropSound, sizeof(m_cDropSound), "sound/", "");
	FakePrecacheSound(m_cDropSound);
}

public int Native_RegisterModule(Handle plugin, int params)
{
	if(g_iTypeHandlers == MAX_MODULES)
		return -1;
		
	char m_szType[32];
	GetNativeString(1, m_szType, sizeof(m_szType));
	int m_iHandler = Case_GetTypeHandler(m_szType);	
	int m_iModuleId = g_iTypeHandlers;
	
	if(m_iHandler != -1) m_iModuleId = m_iHandler;
	else g_iTypeHandlers++;
	
	g_eTypeHandlers[m_iModuleId][hPlugin] = plugin;
	g_eTypeHandlers[m_iModuleId][ValueType] = GetNativeCell(2);
	g_eTypeHandlers[m_iModuleId][fOpened] = GetNativeCell(3);
	strcopy(g_eTypeHandlers[m_iModuleId][mType], sizeof(m_szType), m_szType);

	return m_iModuleId;
}

public int Case_GetTypeHandler(char[] type)
{
	for(int i = 0; i < g_iTypeHandlers; i++)
	{
		if(strcmp(g_eTypeHandlers[i][mType], type) == 0) return i;
	}

	return -1;
}

public Action Command_Cases(int client, int args)
{
	if(!IsBanned(view_as<Jatekos>(client)))
	{
		if(!IsOpening(Jatekos(client)))
		{
			if(IsInventoryLoaded(Jatekos(client))) CaseMenu(Jatekos(client));
			else {
				PrintToChat(client, "Your inventory isn't fetched yet, please try it again later");
				LoadPlayerInventory(Jatekos(client));
			}
		} else {
			PrintToChat(client, " \x07You can't access the menu while opening a case.");
		}
	} else {
		PrintToChat(client, " \x07You have an active ban from the system.");
	}

	return Plugin_Handled;
}

public Action Command_Loadinv(int client, int args)
{
	LoadPlayerInventory(Jatekos(client));
}

public Action Command_Drop(int client, int args)
{
	Jatekos jatekos = view_as<Jatekos>(GetRandomPlayer());
	int caseid = GetRandomCase();
	Case_GiveCase(jatekos, caseid);
	char cPlayerName[MAX_NAME_LENGTH+1];
	jatekos.GetName(cPlayerName, sizeof(cPlayerName));
	PrintToChatAll("%s has got a %s as a drop!", cPlayerName, g_eCase[caseid][Name]);
	return Plugin_Continue;
}

public Action Command_BanPlayer(int client, int args)
{
	if(args != 1)
	{
		PrintToChat(client, "Usage: !caseban targetname");
		return Plugin_Handled;
	}

	char cArgs[MAX_NAME_LENGTH+1];
	GetCmdArg(1, cArgs, sizeof(cArgs));

	if (!view_as<Jatekos>(FindTarget(client, cArgs, true)).IsValid)
	{
		PrintToChat(client, "Invalid target", PREFIX);
		return Plugin_Handled;
	}

	Case_BanPlayer(view_as<Jatekos>(FindTarget(client, cArgs, true)));

	return Plugin_Handled;
}

public void Case_BanPlayer(Jatekos jatekos)
{
	char Query[1024];
	char cSteamID[20];
	char cPlayerName[MAX_NAME_LENGTH+1];

	jatekos.GetAuthId(AuthId_Steam2, cSteamID, sizeof(cSteamID));
	jatekos.GetName(cPlayerName, sizeof(cPlayerName));

	char cPlayerNameEscaped[MAX_NAME_LENGTH*2+16];
	SQL_EscapeString(g_DB, cPlayerName, cPlayerNameEscaped, sizeof(cPlayerNameEscaped));

	if(!IsBanned(jatekos))
	{
		Format(Query, sizeof(Query), "UPDATE `case_players` SET `banned` = 1, `playername` = '%s' WHERE `case_players`.`steamid` = '%s';", cPlayerNameEscaped, cSteamID);
		PrintToChatAll(" \x07%s has been banned from the caseopening system.", cPlayerName);

		m_bBanned[jatekos.index] = true;
	} else {
		Format(Query, sizeof(Query), "UPDATE `case_players` SET `banned` = 0, `playername` = '%s' WHERE `case_players`.`steamid` = '%s';", cPlayerNameEscaped, cSteamID);
		PrintToChatAll(" \x04%s has been unbanned from the caseopening system.", cPlayerName);

		m_bBanned[jatekos.index] = false;
	}

	SQL_TQuery(g_DB, SQLHibaKereso, Query);
}

public void OnClientPostAdminCheck(int client)
{
	if(!IsValidClient(client)) return;

	m_iCacheCase[client] = 0;
	m_iPlayerID[client] = 0;
	m_iSzam[client] = 0;
	m_iOpenedItem[client] = -1;
	m_fChance[client] = -1.0;
	m_bOpening[client] = false;
	m_bBanned[client] = false;

	for (int i = 1; i < m_iCases; ++i)
	{
		PlayerInventory[client][i][Cases] = 0;
		PlayerInventory[client][i][Keys] = 0;

		m_bLoaded[client][Cases] = false;
		m_bLoaded[client][Keys] = false;
	}

	char Query[256];
	char steamid[20];
	view_as<Jatekos>(client).GetAuthId(AuthId_Steam2, steamid, sizeof(steamid));
	Format(Query, sizeof(Query), "SELECT steamid, ID, banned FROM case_players WHERE steamid = '%s';", steamid);
	SQL_TQuery(g_DB, CheckPlayer, Query, view_as<Jatekos>(client));
}

public void CheckPlayer(Handle owner, Handle hndl, const char[] error, Jatekos jatekos)
{
	char cSteamID[20];
	while (SQL_FetchRow(hndl)) {
		SQL_FetchString(hndl, 0, cSteamID, sizeof(cSteamID));
		m_iPlayerID[jatekos.index] = SQL_FetchInt(hndl, 1);
		m_bBanned[jatekos.index] = view_as<bool>(SQL_FetchInt(hndl, 2));
	}

	if(StrEqual(cSteamID, empty))
	{
		char steamid[20];
		jatekos.GetAuthId(AuthId_Steam2, steamid, sizeof(steamid));

		char playername[MAX_NAME_LENGTH+1];
		jatekos.GetName(playername, sizeof(playername));

		char Query[256];
		Format(Query, sizeof(Query), "INSERT INTO `case_players` (`ID`, `playername`, `steamid`, `banned`) VALUES (NULL, '%s', '%s', '0');", playername, steamid);

		SQL_TQuery(g_DB, SQLHibaKereso, Query);
		LoadPlayerInventory(jatekos);
	} else {
		LoadPlayerInventory(jatekos);
	}
}

public void CaseMenu(Jatekos jatekos)
{
	Menu menu = CreateMenu(MainMenu);
	menu.SetTitle("Caseopening System\nYour ID: %i", m_iPlayerID[jatekos.index]);
	if(m_iPlayerID[jatekos.index] != 0) menu.AddItem("cases", "Cases");
	else menu.AddItem("", "Cases", ITEMDRAW_DISABLED);
	if(CheckCommandAccess(jatekos.index, "sm_rootflag", ADMFLAG_ROOT)) menu.AddItem("admin", "ADMIN");
	else menu.AddItem("", "ADMIN", ITEMDRAW_DISABLED);
	menu.Display(jatekos.index, MENU_TIME_FOREVER);
}

public int MainMenu(Menu menu, MenuAction mAction, int client, int item)
{
	if(mAction == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(item, info, sizeof(info));
		if(StrEqual(info, "cases"))
		{
			ListCases(Jatekos(client));
		} else if(StrEqual(info, "admin"))
		{
			Case_AdminMenu(view_as<Jatekos>(client), 1);
		}
	}
}

public void ListCases(Jatekos jatekos)
{
	Menu menu = CreateMenu(SelectCase);
	menu.SetTitle("Caseopening System - Cases");

	if(!StrEqual(g_eCase[1][CaseName], empty))
	{
		for (int i = 1; i < m_iCases; ++i)
		{
			if(g_eCase[i][CaseID] == 0) continue;
			menu.AddItem(g_eCase[i][Unique_ID], g_eCase[i][CaseName]);
		}
	} else {
		menu.AddItem("", "Currently there is no case at all.", ITEMDRAW_DISABLED);
	}

	menu.Display(jatekos.index, MENU_TIME_FOREVER);
}

public int SelectCase(Menu menu, MenuAction mAction, int client, int item)
{
	if(mAction == MenuAction_Select)
	{
		char cUID[32];
		menu.GetItem(item, cUID, sizeof(cUID));

		if(GetCaseIdFromUnique(cUID) != -1)
		{
			m_iCacheCase[client] = GetCaseIdFromUnique(cUID);
			if(VerifyCaseItems(m_iCacheCase[client]) != -1) CaseDetailsMenu(Jatekos(client), m_iCacheCase[client]);
			else PrintToChat(client, "Something happend, Please contact the server owner or the plugin author. \x07ERRCODE: SelectCase.VerifyCaseItems(%i-%i-%i)", m_iCacheCase[client], -1, m_iPlayerID[client]);
			for (int i = 0; i < m_iItems[GetCaseIdFromUnique(cUID)]; ++i)
			{
				if(g_eItem[m_iCacheCase[client]][i][ParentCase] != GetCaseIdFromUnique(cUID)) continue;
				if(g_cR[CEnum_Debug].BoolValue) PrintToChat(client, "\x04%i \x07%s \x10%s \x5%s \x0E%s \x0C%f \x0B%i \x09%i \x03%s", g_eItem[m_iCacheCase[client]][i][ParentCase], g_eItem[m_iCacheCase[client]][i][Name], g_eItem[m_iCacheCase[client]][i][Type], g_eItem[m_iCacheCase[client]][i][Value], g_eItem[m_iCacheCase[client]][i][Grade], g_eItem[m_iCacheCase[client]][i][Chance], PlayerInventory[client][m_iCacheCase[client]][Cases], PlayerInventory[client][m_iCacheCase[client]][Keys], g_eCase[m_iCacheCase[client]][bReqKey]?"yes":"no");
			}
		} else {
			if(g_cR[CEnum_Debug].BoolValue) PrintToChat(client, "-1");
		}
	}
}

stock void CaseDetailsMenu(Jatekos jatekos, int caseid)
{
	char cLine[128];
	char cKeyAmount[64];
	Menu menu = CreateMenu(CaseDetails);
	Format(cKeyAmount, sizeof(cKeyAmount), "\nYou've got %i keys for this case", PlayerInventory[jatekos.index][caseid][Keys]);
	menu.SetTitle("Caseopening System - Case details\nCase: %s%s", g_eCase[caseid][CaseName], (g_eCase[caseid][bReqKey]?cKeyAmount:empty));
	Format(cLine, sizeof(cLine), "Require key: %s", g_eCase[caseid][bReqKey]?"YES":"NO");
	menu.AddItem("", cLine, ITEMDRAW_DISABLED);
	/*Format(cLine, sizeof(cLine), "This case contains the following items:");
	menu.AddItem("", cLine, ITEMDRAW_DISABLED);
	for (int i = 0; i < m_iItems[caseid]; ++i)
	{
		menu.AddItem("", g_eItem[m_iCacheCase[jatekos.index]][i][Name], ITEMDRAW_DISABLED);
	}*/
	menu.AddItem("", "", ITEMDRAW_SPACER);
	if(PlayerInventory[jatekos.index][caseid][Cases] >= 1 && PlayerInventory[jatekos.index][caseid][Keys] >= 1) menu.AddItem("open", "Open case");
	else menu.AddItem("", "Open case", ITEMDRAW_DISABLED);
	menu.AddItem("", "", ITEMDRAW_SPACER);
	menu.AddItem("back", "Back");
	menu.ExitButton = false;
    menu.Pagination = MENU_NO_PAGINATION;
	menu.Display(jatekos.index, MENU_TIME_FOREVER);
}

public int CaseDetails(Menu menu, MenuAction mAction, int client, int item)
{
	if(mAction == MenuAction_Select)
	{
		char info[10];
		menu.GetItem(item, info, sizeof(info));

		if(StrEqual(info, "open"))
		{
			ConfirmationMenu(view_as<Jatekos>(client), m_iCacheCase[client]);
		} else if(StrEqual(info, "back"))
		{
			ListCases(view_as<Jatekos>(client));
		}
	}
}

public void ConfirmationMenu(Jatekos jatekos, int caseid)
{
	Menu menu = CreateMenu(ConfirmationCallback);
	menu.SetTitle("Are you sure you want to open the %s?%s", g_eCase[caseid][CaseName], g_eCase[caseid][bReqKey]?"\nYou'll use a key!":empty);
	menu.AddItem("yes", "Yes");
	menu.AddItem("no", "No");
	menu.AddItem("", "", ITEMDRAW_SPACER);
	menu.AddItem("back", "Back");
	menu.ExitButton = false;
    menu.Pagination = MENU_NO_PAGINATION;
	menu.Display(jatekos.index, MENU_TIME_FOREVER);
}

public int ConfirmationCallback(Menu menu, MenuAction mAction, int client, int item)
{
	if(mAction == MenuAction_Select)
	{
		char info[10];
		menu.GetItem(item, info, sizeof(info));
		if(StrEqual(info, "yes"))
		{
			Pre_OpenCase(view_as<Jatekos>(client));
		} else if(StrEqual(info, "no"))
		{
			ListCases(view_as<Jatekos>(client));
		} else if(StrEqual(info, "back"))
		{
			CaseDetailsMenu(view_as<Jatekos>(client), m_iCacheCase[client]);
		}
	}
}

public void OnGameFrame()
{
	for (int i = 1; i < m_iCases; ++i)
	{
		if(g_iLoadedCases[i] < 0) g_iLoadedCases[i] = 0;
	}
}

public void Pre_OpenCase(Jatekos jatekos)
{
	if(!(m_iItems[m_iCacheCase[jatekos.index]] > 0))
	{
		PrintToChat(jatekos.index, "This case haven't got any item yet.");
		return;
	}

	m_iSzam[jatekos.index] = 0;
	m_bOpening[jatekos.index] = true;
	ManagePlayerInventory(jatekos);
	CreateTimer(0.1, OpenCase, jatekos, TIMER_REPEAT);
}

public Action OpenCase(Handle timer, Jatekos jatekos)
{
	if(!jatekos.IsValid)
		return Plugin_Stop;

	if(m_fChance[jatekos.index] == -1.0) m_fChance[jatekos.index] = GetRandomFloat(GetLowestItemChance(m_iCacheCase[jatekos.index]), GetHighestItemChance(m_iCacheCase[jatekos.index]));
	if(m_iOpenedItem[jatekos.index] == -1)
	{
		if(GetItemFromCase(jatekos, m_iCacheCase[jatekos.index]) != -1) m_iOpenedItem[jatekos.index] = GetItemFromCase(jatekos, m_iCacheCase[jatekos.index]);
		else {
			ManagePlayerInventory(jatekos, false);
			PrintToChat(jatekos.index, "Something happend, Please contact the server owner or the plugin author. \x07ERRCODE: fOpenCase.GetItemFromCase(%i-%i-%i)", m_iOpenedItem[jatekos.index], m_iCacheCase[jatekos.index], m_iPlayerID[jatekos.index]);
			return Plugin_Stop;
		}
	}

	int randomszam = GetRandomInt(0, m_iItems[m_iCacheCase[jatekos.index]]);

	if (m_iSzam[jatekos.index] >= 100 && m_fChance[jatekos.index] > -1.0)
	{
		char cPlayerName[MAX_NAME_LENGTH+1];
		jatekos.GetName(cPlayerName, sizeof(cPlayerName));

		if(ProcessItem(jatekos, m_iCacheCase[jatekos.index], g_eItem[m_iCacheCase[jatekos.index]][m_iOpenedItem[jatekos.index]][Type], g_eItem[m_iCacheCase[jatekos.index]][m_iOpenedItem[jatekos.index]][Value]) != -1)
		{
			PrintHintText(jatekos.index, "<span class='fontSize-xl'><big><u><b><font color='#00CCFF'>›› <font color='%s'>%s</font> ‹‹</font></b></u></big></span>", g_eItem[m_iCacheCase[jatekos.index]][m_iOpenedItem[jatekos.index]][Grade], g_eItem[m_iCacheCase[jatekos.index]][m_iOpenedItem[jatekos.index]][Name]);
			if(g_cR[CEnum_Debug].BoolValue) Format(m_cChanceDetails, sizeof(m_cChanceDetails), "item chance: %f player chance: %f");
			PrintToChat(jatekos.index, "%s \x04%s \x01has opened a case and found: %s", PREFIX, cPlayerName, g_eItem[m_iCacheCase[jatekos.index]][m_iOpenedItem[jatekos.index]][Name], g_eItem[m_iCacheCase[jatekos.index]][m_iOpenedItem[jatekos.index]][Chance], m_fChance[jatekos.index], (g_cR[CEnum_Debug].BoolValue?m_cChanceDetails:empty));
			if(g_cR[CEnum_Debug].BoolValue) PrintToChat(jatekos.index, "highest: %f lowest: %f", GetHighestItemChance(m_iCacheCase[jatekos.index]), GetLowestItemChance(m_iCacheCase[jatekos.index]));
		} else {
			ManagePlayerInventory(jatekos, false);
			PrintToChat(jatekos.index, "Something happend while we tried to process your item, Please contact the server owner or the plugin author. \x07ERRCODE: fOpenCase.ProcessItem(%i-%i-%i-%i)", m_iOpenedItem[jatekos.index], m_iCacheCase[jatekos.index], m_iPlayerID[jatekos.index], -1);
		}
		
		m_fChance[jatekos.index] = -1.0;
		m_iSzam[jatekos.index] = 0;
		m_iOpenedItem[jatekos.index] = -1;
		m_bOpening[jatekos.index] = false;
		return Plugin_Stop;
	}

	if(!StrEqual(g_eItem[m_iCacheCase[jatekos.index]][randomszam][Name], empty))
		PrintHintText(jatekos.index, "<span class='fontSize-xl'><big><u><b><font color='#00CCFF'>›› <font color='%s'>%s</font> ‹‹</font></b></u></big></span>", g_eItem[m_iCacheCase[jatekos.index]][randomszam][Grade], g_eItem[m_iCacheCase[jatekos.index]][randomszam][Name]);

	m_iSzam[jatekos.index]++;			
	return Plugin_Continue;
}

public int ProcessItem(Jatekos jatekos, int caseid, char[] type, char[] value)
{
	if(Case_GetTypeHandler(type) != -1)
	{
		Call_StartFunction(g_eTypeHandlers[Case_GetTypeHandler(type)][hPlugin], g_eTypeHandlers[Case_GetTypeHandler(type)][fOpened]);
		Call_PushCell(jatekos);
		if(g_eTypeHandlers[Case_GetTypeHandler(type)][ValueType]) Call_PushCell(StringToInt(value));
		else Call_PushString(value);
		Call_Finish();
		return 1;
	} else {
		PrintToChat(jatekos.index, "Something happend, there is no module for the item you have opened, Please contact the server owner or the plugin author. \x07ERRCODE: fProcessItem(%i-%i-%s)", Case_GetTypeHandler(type), m_iPlayerID[jatekos.index], type);
	}

	return -1;
}

public int GetItemFromCase(Jatekos jatekos, int caseid)
{
	int m_iItem = 0;
	for (int i = 0; i < m_iItems[caseid]; ++i)
	{
		if(g_eItem[caseid][i][ParentCase] != caseid) continue;

		if(g_eItem[caseid][i][Chance] >= m_fChance[jatekos.index]){
			if(g_eItem[caseid][i][Chance] < g_eItem[caseid][m_iItem][Chance])
				m_iItem = GetItemFromUnique(caseid, g_eItem[caseid][i][Unique]);
		}
	}

	return m_iItem;
}

stock void ManagePlayerInventory(Jatekos jatekos, bool del = true)
{
	if(!jatekos.IsValid) return;

	char Query[1024];

	if(del)
	{
		Format(Query, sizeof(Query), "DELETE FROM case_inventory WHERE unique_id = '%i' AND type = 'case' AND caseid = '%i' LIMIT 1", m_iPlayerID[jatekos.index], m_iCacheCase[jatekos.index]);
		SQL_TQuery(g_DB, SQLHibaKereso, Query);

		if(g_eCase[m_iCacheCase[jatekos.index]][bReqKey]) {
			Format(Query, sizeof(Query), "DELETE FROM case_inventory WHERE unique_id = '%i' AND type = 'key' AND caseid = '%i' LIMIT 1", m_iPlayerID[jatekos.index], m_iCacheCase[jatekos.index]);
			SQL_TQuery(g_DB, SQLHibaKereso, Query);
		}
	} else if(!del){
		Format(Query, sizeof(Query), "INSERT INTO `case_inventory` (`ID`, `unique_id`, `type`, `caseid`) VALUES (NULL, '%i', 'case', '%i');", m_iPlayerID[jatekos.index], m_iCacheCase[jatekos.index]);
		SQL_TQuery(g_DB, SQLHibaKereso, Query);

		if(g_eCase[m_iCacheCase[jatekos.index]][bReqKey]) {
			Format(Query, sizeof(Query), "INSERT INTO `case_inventory` (`ID`, `unique_id`, `type`, `caseid`) VALUES (NULL, '%i', 'key', '%i');", m_iPlayerID[jatekos.index], m_iCacheCase[jatekos.index]);
			SQL_TQuery(g_DB, SQLHibaKereso, Query);
		}
	}
}

public Action Event_EndMatch(Event event, const char[] name, bool dontBroadcast) 
{
	if(GetInGameClientCount() >= g_cR[CEnum_Minplayer].IntValue)
	{
		if(GetRandomInt(0, 100) <= g_cR[CEnum_DropChance].IntValue)
		{
			CreateTimer(g_cR[CEnum_DropDelay].FloatValue, Case_DropEvent, view_as<Jatekos>(GetRandomPlayer()), TIMER_FLAG_NO_MAPCHANGE);
		} else {
			PrintToChatAll("There will be no drop for now.");
		}
	} else {
		PrintToChatAll("There is not enough player for a case drop.");
	}
}

public Action Case_DropEvent(Handle timer, Jatekos jatekos)
{
	int caseid = GetRandomCase();
	Case_GiveCase(jatekos, caseid);
	PrintToChatAll("%s has got a %s as a drop!", jatekos.index, g_eCase[caseid][Name]);
	PlaySoundToClient(jatekos, m_cDropSound);
	return Plugin_Continue;
}

public void Case_GiveCase(Jatekos jatekos, int caseid)
{
	char Query[1024];
	if(caseid < 1) caseid = 1;
	Format(Query, sizeof(Query), "INSERT INTO `case_inventory` (`ID`, `unique_id`, `type`, `caseid`) VALUES (NULL, '%i', 'case', '%i');", m_iPlayerID[jatekos.index], caseid);
	SQL_TQuery(g_DB, SQLHibaKereso, Query);
}

public void PlaySoundToClient(Jatekos jatekos, char[] sound)
{
	EmitSoundToClient(jatekos.index, sound);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(g_cR[CEnum_PickUp].BoolValue)
	{
		if(GetInGameClientCount() >= g_cR[CEnum_CaseSpawn].IntValue)
		{
			Case_SpawnCases();
		} else {
			PrintToChatAll("There is not enough player to spawn cases");
		}
	}
}

public Action Command_Refresh(int client, int args)
{
	SQL_LoadCases();
}

public void OnConfigsExecuted()
{
	char cError[255];
	char cDatabase[32];
	g_cR[CEnum_Config].GetString(cDatabase, sizeof(cDatabase));
	g_DB = SQL_Connect(cDatabase, true, cError, sizeof(cError));
	SQL_SetCharset(g_DB, "utf8");
	
	char createTableQuery[4096];
	Format(createTableQuery, sizeof(createTableQuery), 
		"CREATE TABLE IF NOT EXISTS `case_cases` ( \
 		`ID` bigint(20) NOT NULL AUTO_INCREMENT, \
  		`casename` varchar(32) COLLATE utf8_bin NOT NULL, \
  		`unique_name` varchar(32) COLLATE utf8_bin NOT NULL, \
  		`case_id` int(20) NOT NULL, \
  		`req_key` int(20) NOT NULL, \
  		`model` varchar(255) COLLATE utf8_bin NOT NULL, \
 		 PRIMARY KEY (`ID`), \
  		 UNIQUE KEY `unique_name` (`unique_name`)  \
  		 ) ENGINE = InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8 COLLATE=utf8_bin;");

	SQL_TQuery(g_DB, SQLHibaKereso, createTableQuery);

	Format(createTableQuery, sizeof(createTableQuery), 
		"CREATE TABLE IF NOT EXISTS `case_items` ( \
 		`ID` bigint(20) NOT NULL AUTO_INCREMENT, \
  		`name` varchar(32) COLLATE utf8_bin NOT NULL, \
  		`uname` varchar(32) COLLATE utf8_bin NOT NULL, \
  		`type` varchar(32) COLLATE utf8_bin NOT NULL, \
  		`value` varchar(32) NOT NULL, \
  		`case_id` int(20) NOT NULL, \
  		`grade` varchar(10) NOT NULL, \
  		`chance` float(20) NOT NULL, \
 		 PRIMARY KEY (`ID`), \
  		 UNIQUE KEY `uname` (`uname`)  \
  		 ) ENGINE = InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8 COLLATE=utf8_bin;");

	SQL_TQuery(g_DB, SQLHibaKereso, createTableQuery);

	Format(createTableQuery, sizeof(createTableQuery), 
		"CREATE TABLE IF NOT EXISTS `case_players` ( \
 		`ID` bigint(20) NOT NULL AUTO_INCREMENT, \
  		`playername` varchar(32) COLLATE utf8_bin NOT NULL, \
  		`steamid` varchar(20) COLLATE utf8_bin NOT NULL, \
  		`banned` int(20) NOT NULL, \
 		 PRIMARY KEY (`ID`), \
  		 UNIQUE KEY `steamid` (`steamid`)  \
  		 ) ENGINE = InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8 COLLATE=utf8_bin;");

	SQL_TQuery(g_DB, SQLHibaKereso, createTableQuery);

	Format(createTableQuery, sizeof(createTableQuery), 
		"CREATE TABLE IF NOT EXISTS `case_inventory` ( \
 		`ID` bigint(20) NOT NULL AUTO_INCREMENT, \
  		`unique_id` varchar(32) COLLATE utf8_bin NOT NULL, \
  		`type` varchar(10) COLLATE utf8_bin NOT NULL, \
  		`caseid` int(20) NOT NULL, \
 		 PRIMARY KEY (`ID`) \
  		 ) ENGINE = InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8 COLLATE=utf8_bin;");

	SQL_TQuery(g_DB, SQLHibaKereso, createTableQuery);

	SQL_LoadCases();

	m_fOffsetZ = g_cR[CEnum_OffsetFloat].FloatValue;
}

public void SQL_LoadCases()
{
	CasesReset();

	char Query[256];
	Format(Query, sizeof(Query), "SELECT * FROM case_cases;");
	SQL_TQuery(g_DB, GetCasesFromDB, Query);
}

public void GetCasesFromDB(Handle owner, Handle hndl, const char[] error, any data)
{
	char Query[256];
	while (SQL_FetchRow(hndl)) {
		SQL_FetchString(hndl, 1, g_eCase[m_iCases][CaseName], 32);
		SQL_FetchString(hndl, 2, g_eCase[m_iCases][Unique_ID], 32);
		if(g_cR[CEnum_PickUp].BoolValue) SQL_FetchString(hndl, 5, g_eCase[m_iCases][Model], PLATFORM_MAX_PATH);
		g_eCase[m_iCases][CaseID] = SQL_FetchInt(hndl, 3);
		g_eCase[m_iCases][bReqKey] = view_as<bool>(SQL_FetchInt(hndl, 4));

		if(view_as<int>(g_eCase[m_iCases][bReqKey]) > 1 && view_as<int>(g_eCase[m_iCases][bReqKey]) < 0)
		{
			g_eCase[m_iCases][bReqKey] = false;
		}

		if(!(g_eCase[m_iCases][CaseID] >= 0)) continue;
		Format(Query, sizeof(Query), "SELECT * FROM case_items WHERE case_id = '%i';", g_eCase[m_iCases][CaseID]);
		SQL_TQuery(g_DB, GetItemsFromDB, Query, g_eCase[m_iCases][CaseID]);

		m_iCases++;
	}
}

public void GetItemsFromDB(Handle owner, Handle hndl, const char[] error, int caseid)
{
	while (SQL_FetchRow(hndl)) {
		SQL_FetchString(hndl, 1, g_eItem[caseid][m_iItems[caseid]][Name], 32);
		SQL_FetchString(hndl, 2, g_eItem[caseid][m_iItems[caseid]][Unique], 32);
		SQL_FetchString(hndl, 3, g_eItem[caseid][m_iItems[caseid]][Type], 32);
		SQL_FetchString(hndl, 4, g_eItem[caseid][m_iItems[caseid]][Value], 32);
		SQL_FetchString(hndl, 6, g_eItem[caseid][m_iItems[caseid]][Grade], 10);
		g_eItem[caseid][m_iItems[caseid]][ParentCase] = SQL_FetchInt(hndl, 5);
		g_eItem[caseid][m_iItems[caseid]][Chance] = SQL_FetchFloat(hndl, 7);

		m_iItems[caseid]++;
	}
}

public void LoadPlayerInventory(Jatekos jatekos)
{
	char Query[256];
	for (int i = 1; i < m_iCases; ++i)
	{
		m_iCacheCase[jatekos.index] = i;
		Format(Query, sizeof(Query), "SELECT * FROM case_inventory WHERE unique_id = '%i' AND type = 'case' AND caseid = '%i';", m_iPlayerID[jatekos.index], m_iCacheCase[jatekos.index]);
		DataPack things = new DataPack();
		things.WriteCell(view_as<Jatekos>(jatekos));
		things.WriteCell(m_iCacheCase[jatekos.index]);
		SQL_TQuery(g_DB, GetPlayerCases, Query, things);
	}

	for (int i = 1; i < m_iCases; ++i)
	{
		m_iCacheCase[jatekos.index] = i;
		Format(Query, sizeof(Query), "SELECT * FROM case_inventory WHERE unique_id = '%i' AND type = 'key' AND caseid = '%i';", m_iPlayerID[jatekos.index], m_iCacheCase[jatekos.index]);
		DataPack things = new DataPack();
		things.WriteCell(view_as<Jatekos>(jatekos));
		things.WriteCell(m_iCacheCase[jatekos.index]);
		SQL_TQuery(g_DB, GetPlayerKeys, Query, things);
	}
}

public void GetPlayerCases(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	ResetPack(pack);
	
	PlayerInventory[view_as<Jatekos>(pack.ReadCell()).index][pack.ReadCell()][Cases] = SQL_GetRowCount(hndl);

	ResetPack(pack);

	m_bLoaded[pack.ReadCell()][Cases] = true;
	delete pack;
}

public void GetPlayerKeys(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	ResetPack(pack);
	
	PlayerInventory[view_as<Jatekos>(pack.ReadCell()).index][pack.ReadCell()][Keys] = SQL_GetRowCount(hndl);

	ResetPack(pack);

	m_bLoaded[pack.ReadCell()][Keys] = true;
	delete pack;
}

public void CasesReset()
{
	for (int i = 1; i < m_iCases; ++i)
	{
		m_iItems[i] = 0;
	}

	m_iCases = 1;
}

public int Case_SpawnCases()
{
	if(g_cR[CEnum_PickUp].BoolValue)
	{
		for (int i = 1; i < m_iCases; ++i)
		{
			for (int k = 0; k < g_iLoadedCases[i]; ++k)
			{
				SpawnCase(i, k);
			}
		}
	}
}

public void SpawnCase(int caseid, int id) {
	int m_iCaseEnt = CreateEntityByName("prop_dynamic_override");

	if (m_iCaseEnt == -1)
		return;

	if(!IsModelPrecached(g_eCase[caseid][Model])) PrecacheModel(g_eCase[caseid][Model], true);
	SetEntityModel(m_iCaseEnt, g_eCase[caseid][Model]);

	char cUniqueName[8];
	char preid[2][8];
	IntToString(caseid, preid[0], sizeof(preid[]));
	IntToString(id, preid[1], sizeof(preid[]));
	Format(cUniqueName, sizeof(cUniqueName), "%i_%i", preid[0], preid[1]);
	SetEntPropString(m_iCaseEnt, Prop_Data, "m_iName", cUniqueName);
	Format(g_eSpawnPositions[caseid][id][UniqueName], 32, cUniqueName);

	DispatchSpawn(m_iCaseEnt);
	float fPos[3];
	fPos[0] = g_eSpawnPositions[caseid][id][fPosX];
	fPos[1] = g_eSpawnPositions[caseid][id][fPosY];
	fPos[2] = g_eSpawnPositions[caseid][id][fPosZ];
	fPos[2] += m_fOffsetZ;

	TeleportEntity(m_iCaseEnt, fPos, NULL_VECTOR, NULL_VECTOR);
	fPos[2] -= m_fOffsetZ;
	
	int m_iRotator = CreateEntityByName("func_rotating");
	DispatchKeyValueVector(m_iRotator, "origin", fPos);
	DispatchKeyValue(m_iRotator, "targetname", "Item");
	DispatchKeyValue(m_iRotator, "maxspeed", "200");
	DispatchKeyValue(m_iRotator, "friction", "0");
	DispatchKeyValue(m_iRotator, "dmg", "0");
	DispatchKeyValue(m_iRotator, "solid", "0");
	DispatchKeyValue(m_iRotator, "spawnflags", "64");
	DispatchSpawn(m_iRotator);
	
	SetVariantString("!activator");
	AcceptEntityInput(m_iCaseEnt, "SetParent", m_iRotator, m_iRotator);
	AcceptEntityInput(m_iRotator, "Start");
	
	SetEntPropEnt(m_iCaseEnt, Prop_Send, "m_hEffectEntity", m_iRotator);
	
	HookSingleEntityOutput(m_iCaseEnt, "OnStartTouch", Case_OnStartTouch);
	
	CaseTrigger(fPos, caseid, cUniqueName);
	g_eSpawnPositions[caseid][id][EntRef] = EntIndexToEntRef(m_iCaseEnt);
	g_eSpawnPositions[caseid][id][ItemId] = id;
	
	g_eSpawnPositions[caseid][id][bSpawned] = true;
	g_iSpawnedCases[caseid]++;
}

public void Case_OnStartTouch(const char[] output, int caller, int activator, float delay)
{
	if(g_cR[CEnum_PickUp].BoolValue)
	{
		Jatekos jatekos = view_as<Jatekos>(activator);
		if(!jatekos.IsValid) return;

		char cItemId[8];
		GetEntPropString(caller, Prop_Data, "m_iName", cItemId, sizeof(cItemId));

		int m_iCaseItemId[2];
		m_iCaseItemId[0] = GetSpawnedCaseIdFromUnique(cItemId);
		m_iCaseItemId[1] = GetSpawnedItemIdFromUnique(cItemId);

		if (m_iCaseItemId[1] == -1)
			return;

		AcceptEntityInput(caller, "kill");
		if(m_iCaseItemId[0] == 0 && m_iCaseItemId[1] == 0 && g_iLoadedCases[m_iCaseItemId[0]] == 0 && g_iSpawnedCases[m_iCaseItemId[0]] == 0) PrintToChat(activator, "Something happend while we tried to process your item, Please contact the server owner or the plugin author. \x07ERRCODE: CaseTrigger.Case_OnStartTouch(%i-%i-%i-%i-%i)", m_iCaseItemId[0], m_iCaseItemId[1], m_iCases, g_iLoadedCases[m_iCaseItemId[0]], g_iSpawnedCases[m_iCaseItemId[0]]);
		g_eSpawnPositions[m_iCaseItemId[0]][m_iCaseItemId[1]][bSpawned] = false;
				
		AcceptEntityInput(EntRefToEntIndex(g_eSpawnPositions[m_iCaseItemId[0]][m_iCaseItemId[1]][EntRef]), "kill");
		g_iSpawnedCases[m_iCaseItemId[0]]--;

		Case_GiveCase(jatekos, m_iCaseItemId[0]);
				
		char cPlayerName[MAX_NAME_LENGTH+1];
		jatekos.GetName(cPlayerName, sizeof(cPlayerName));
		PrintToChatAll("%s has picked up a %s!", cPlayerName, g_eCase[m_iCaseItemId[0]][Name]);
	}
}

public int CaseTrigger(float pos[3], int caseid, char[] name)
{
	float fMiddle[3];
	int iEnt = CreateEntityByName("trigger_multiple");
	
	DispatchKeyValue(iEnt, "spawnflags", "64");
	char sItemName[8];
	Format(sItemName, sizeof(sItemName), "%s", name);
	DispatchKeyValue(iEnt, "targetname", sItemName);
	DispatchKeyValue(iEnt, "wait", "0");
	
	DispatchSpawn(iEnt);
	ActivateEntity(iEnt);
	SetEntProp(iEnt, Prop_Data, "m_spawnflags", 64);
	
	TeleportEntity(iEnt, pos, NULL_VECTOR, NULL_VECTOR);
	SetEntityModel(iEnt, g_eCase[g_iLoadedCases[caseid]][Model]);
	
	float fMins[3];
	float fMaxs[3];
	
	fMins[0] = 30.0;
	fMins[1] = 30.0;
	fMins[2] = 30.0;
	fMaxs[0] = 30.0;
	fMaxs[1] = 30.0;
	fMaxs[2] = 30.0;
	fMins[0] = fMins[0] - fMiddle[0];
	if (fMins[0] > 0.0) fMins[0] *= -1.0;
	fMins[1] = fMins[1] - fMiddle[1];
	if (fMins[1] > 0.0) fMins[1] *= -1.0;
	fMins[2] = fMins[2] - fMiddle[2];
	if (fMins[2] > 0.0) fMins[2] *= -1.0;
	fMaxs[0] = fMaxs[0] - fMiddle[0];
	if (fMaxs[0] < 0.0) fMaxs[0] *= -1.0;
	fMaxs[1] = fMaxs[1] - fMiddle[1];
	if (fMaxs[1] < 0.0) fMaxs[1] *= -1.0;
	fMaxs[2] = fMaxs[2] - fMiddle[2];
	if (fMaxs[2] < 0.0) fMaxs[2] *= -1.0;
	
	SetEntPropVector(iEnt, Prop_Send, "m_vecMins", fMins);
	SetEntPropVector(iEnt, Prop_Send, "m_vecMaxs", fMaxs);
	SetEntProp(iEnt, Prop_Send, "m_nSolidType", 2);
	
	int iEffects = GetEntProp(iEnt, Prop_Send, "m_fEffects");
	iEffects |= 32;
	SetEntProp(iEnt, Prop_Send, "m_fEffects", iEffects);
	
	HookSingleEntityOutput(iEnt, "OnStartTouch", Case_OnStartTouch);
}

public void LoadCasesFromFile()
{
	if(g_cR[CEnum_PickUp].BoolValue)
	{
		char sRawMap[PLATFORM_MAX_PATH];
		char sMap[64];
		GetCurrentMap(sRawMap, sizeof(sRawMap));
		RemoveMapPath(sRawMap, sMap, sizeof(sMap));
		
		char sPath[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, sPath, sizeof(sPath), "configs/case_spawns/%s.txt", sMap);
		
		Handle hFile = OpenFile(sPath, "r");
		
		char sBuffer[512];
		char m_sLoadedData[4][32];
		int m_iCaseIdCache = 1;
		
		if (hFile != INVALID_HANDLE)
		{
			while (ReadFileLine(hFile, sBuffer, sizeof(sBuffer)))
			{
				ExplodeString(sBuffer, ";", m_sLoadedData, sizeof(m_sLoadedData[]), sizeof(m_sLoadedData[]) / 8);
				m_iCaseIdCache = StringToInt(m_sLoadedData[0]);

				g_eSpawnPositions[m_iCaseIdCache][g_iLoadedCases[m_iCaseIdCache]][CaseId] = m_iCaseIdCache;
				g_eSpawnPositions[m_iCaseIdCache][g_iLoadedCases[m_iCaseIdCache]][fPosX] = StringToFloat(m_sLoadedData[1]);
				g_eSpawnPositions[m_iCaseIdCache][g_iLoadedCases[m_iCaseIdCache]][fPosY] = StringToFloat(m_sLoadedData[2]);
				g_eSpawnPositions[m_iCaseIdCache][g_iLoadedCases[m_iCaseIdCache]][fPosZ] = StringToFloat(m_sLoadedData[3]);
				
				g_iLoadedCases[m_iCaseIdCache]++;
			}
			
			CloseHandle(hFile);
		}
	}
}

public void OnMapStartLoadCasesFromFile()
{
	char Path[512];
	BuildPath(Path_SM, Path, sizeof(Path), "configs/case_spawns");
	if (!DirExists(Path))
		CreateDirectory(Path, 0777);
	
	for (int i = 1; i < m_iCases; ++i)
	{
		for (int k = 0; k < g_iLoadedCases[i]; k++) {
			g_eSpawnPositions[i][g_iLoadedCases[i]][CaseId] = 0;
			g_eSpawnPositions[i][g_iLoadedCases[k]][fPosX] = -1.0;
			g_eSpawnPositions[i][g_iLoadedCases[k]][fPosY] = -1.0;
			g_eSpawnPositions[i][g_iLoadedCases[k]][fPosZ] = -1.0;
			g_eSpawnPositions[i][g_iLoadedCases[k]][bSpawned] = false;
		}
	}

	LoadCasesFromFile();
}

public void SaveCasesToFile()
{
	if(g_cR[CEnum_PickUp].BoolValue)
	{
		char sRawMap[PLATFORM_MAX_PATH];
		char sMap[64];
		GetCurrentMap(sRawMap, sizeof(sRawMap));
		RemoveMapPath(sRawMap, sMap, sizeof(sMap));
		
		CreateDirectory("configs/case_spawns", 511);
		
		char cSpawnFilePath[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, cSpawnFilePath, sizeof(cSpawnFilePath), "configs/case_spawns/%s.txt", sMap);
		
		Handle hFile = OpenFile(cSpawnFilePath, "w");
		
		if (hFile != INVALID_HANDLE)
		{
			for (int i = 1; i < m_iCases; ++i)
			{
				for (int k = 0; k < g_iLoadedCases[i]; k++) {
					WriteFileLine(hFile, "%i;%.2f;%.2f;%.2f;", i, g_eSpawnPositions[i][k][fPosX], g_eSpawnPositions[i][k][fPosY], g_eSpawnPositions[i][k][fPosZ]);
				}
			}

			CloseHandle(hFile);
		}
	}
}

public void Case_PlaceCase(Jatekos jatekos, bool vision, int caseid)
{
	if(g_cR[CEnum_PickUp].BoolValue)
	{
		float fPos[3];
		if (vision) {
			float fAng[3];
			GetClientEyePosition(jatekos.index, fPos);
			GetClientEyeAngles(jatekos.index, fAng);
			TR_TraceRayFilter(fPos, fAng, MASK_PLAYERSOLID, RayType_Infinite, SpawnLight, jatekos.index);
			TR_GetEndPosition(fPos);
		} else
			GetClientAbsOrigin(jatekos.index, fPos);
		
		TE_SetupGlowSprite(fPos, g_iMarker, 10.0, 1.0, 235);
		TE_SendToAll();
		
		g_iLoadedCases[caseid]++;
		g_eSpawnPositions[caseid][g_iLoadedCases[caseid]][fPosX] = fPos[0];
		g_eSpawnPositions[caseid][g_iLoadedCases[caseid]][fPosY] = fPos[1];
		g_eSpawnPositions[caseid][g_iLoadedCases[caseid]][fPosZ] = fPos[2];
		
		PrintToChat(jatekos.index, "You have placed a new case! <%i>:<%.2f>:<%.2f>:<%.2f>", caseid, fPos[0], fPos[1], fPos[2]);
		SaveCasesToFile();
	}
}

public void Case_AdminMenu(Jatekos jatekos, int menuid)
{
	if(menuid == 0)
	{
		char cNewLine[64];
		
		Panel panel = CreatePanel();
		Format(cNewLine, sizeof(cNewLine), "Cases - Admin\nSelected case: %s", g_eCase[m_iCacheCase[jatekos.index]][Name])
		SetPanelTitle(panel, cNewLine);
		DrawPanelText(panel, "");
		Format(cNewLine, sizeof(cNewLine), "Place case (%i)", g_iLoadedCases[m_iCacheCase[jatekos.index]]);
		DrawPanelItem(panel, cNewLine);
		Format(cNewLine, sizeof(cNewLine), "Place case (%i) [AIM]", g_iLoadedCases[m_iCacheCase[jatekos.index]]);
		DrawPanelItem(panel, cNewLine);
		DrawPanelItem(panel, "Delete last placed case");
		DrawPanelText(panel, "");
		DrawPanelItem(panel, "Spawn points");
		DrawPanelItem(panel, "Exit");
		SendPanelToClient(panel, jatekos.index, fPlaceCase, 30);
		
		CloseHandle(panel);
	} else if(menuid == 1)
	{
		fPlaceCase_ListCases(jatekos);
	}
}

public int fPlaceCase(Handle menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		if (item == 1) {
			Case_PlaceCase(Jatekos(client), false, m_iCacheCase[client]);
			Case_AdminMenu(Jatekos(client), 0);
		} else if (item == 2) {
			Case_PlaceCase(Jatekos(client), true, m_iCacheCase[client]);
			Case_AdminMenu(Jatekos(client), 0);
		} else if (item == 3) {
			fPlaceCase_DeleteLast(view_as<Jatekos>(client), m_iCacheCase[client]);
			Case_AdminMenu(Jatekos(client), 0);
		} else if (item == 4) {
			fPlaceCase_ShowSpawns();
			Case_AdminMenu(Jatekos(client), 0);
		}
	}
}

public void fPlaceCase_ListCases(Jatekos jatekos)
{
	Menu menu = CreateMenu(fPlaceCase_SelectCases);
	menu.SetTitle("Select a case to work with");

	if(!StrEqual(g_eCase[1][CaseName], empty))
	{
		for (int i = 1; i < m_iCases; ++i)
		{
			if(g_eCase[i][CaseID] == 0) continue;
			menu.AddItem(g_eCase[i][Unique_ID], g_eCase[i][CaseName]);
		}
	} else {
		menu.AddItem("", "Currently there is no case at all.", ITEMDRAW_DISABLED);
	}

	menu.Display(jatekos.index, MENU_TIME_FOREVER);
}

public int fPlaceCase_SelectCases(Menu menu, MenuAction mAction, int client, int item)
{
	if(mAction == MenuAction_Select)
	{
		char cUID[32];
		menu.GetItem(item, cUID, sizeof(cUID));

		if(GetCaseIdFromUnique(cUID) != -1)
		{
			m_iCacheCase[client] = GetCaseIdFromUnique(cUID);
			Case_AdminMenu(Jatekos(client), 0);
		} else {
			if(g_cR[CEnum_Debug].BoolValue) PrintToChat(client, "-1");
		}
	}
}

public void fPlaceCase_DeleteLast(Jatekos jatekos, int caseid) {
	g_iLoadedCases[caseid]--;
	PrintToChat(jatekos.index, "You have deleted the previous placed case. (total: %i).", g_iLoadedCases);
	SaveCasesToFile();
}

public void fPlaceCase_ShowSpawns() {
	for (int i = 1; i < m_iCases; ++i)
	{
		for (int k = 0; k < g_iLoadedCases[i]; k++) {
			float pos[3];
			pos[0] = g_eSpawnPositions[i][k][fPosX];
			pos[1] = g_eSpawnPositions[i][k][fPosY];
			pos[2] = g_eSpawnPositions[i][k][fPosZ];
			TE_SetupGlowSprite(pos, g_iMarker, 10.0, 1.0, 235);
			TE_SendToAll();
		}
	}
}

public int Native_IsInventoryLoaded(Handle plugin, int params)
{
	return IsInventoryLoaded(GetNativeCell(1));
}

public void SQLHibaKereso(Handle owner, Handle hndl, const char[] error, any data) {
	if (!StrEqual(error, ""))
		LogError(error);
}

stock int GetCaseIdFromUnique(char[] unique)
{
	for (int i = 1; i < m_iCases; ++i)
	{
		if(StrEqual(g_eCase[i][Unique_ID], unique))
			return g_eCase[i][CaseID];
	}

	return -1;
}

stock int GetItemFromUnique(int caseid, char[] unique)
{
	for (int i = 0; i < m_iItems[caseid]; ++i)
	{
		if(g_eItem[caseid][i][ParentCase] != caseid) continue;

		if(StrEqual(g_eItem[caseid][i][Unique], unique))
			return i;
	}

	return -1;
}

stock int GetSpawnedCaseIdFromUnique(char[] unique)
{
	for (int i = 1; i < m_iCases; ++i)
	{
		for (int k = 0; k < g_iLoadedCases[i]; ++k)
		{
			if(StrEqual(g_eSpawnPositions[i][k][UniqueName], unique))
				return g_eSpawnPositions[i][k][CaseId];
		}
	}

	return -1;
}

stock int GetSpawnedItemIdFromUnique(char[] unique)
{
	for (int i = 1; i < m_iCases; ++i)
	{
		for (int k = 0; k < g_iLoadedCases[i]; ++k)
		{
			if(StrEqual(g_eSpawnPositions[i][k][UniqueName], unique))
				return g_eSpawnPositions[i][k][ItemId];
		}
	}

	return -1;
}

stock float GetHighestItemChance(int caseid)
{
	float chance = 0.0;
	for (int i = 0; i < m_iItems[caseid]; ++i)
	{
		if(g_eItem[caseid][i][ParentCase] != caseid) continue;

		if(g_eItem[caseid][i][Chance] > chance)
			chance = g_eItem[caseid][i][Chance];
	}

	if(chance == 0.0) chance = 1.0;

	return chance;
}

stock float GetLowestItemChance(int caseid)
{
	float chance = 1.0;
	for (int i = 0; i < m_iItems[caseid]; ++i)
	{
		if(g_eItem[caseid][i][ParentCase] != caseid) continue;

		if(g_eItem[caseid][i][Chance] < chance)
			chance = g_eItem[caseid][i][Chance];
	}

	if(chance == 1.0) chance = 0.0;

	return chance;
}

stock int GetRandomCase()
{
	return GetRandomInt(1, m_iCases);
}

stock int VerifyCaseItems(int caseid)
{
	for (int i = 0; i < m_iItems[caseid]; ++i)
	{
		if(g_eItem[caseid][i][ParentCase] != caseid) continue;

		if(Case_GetTypeHandler(g_eItem[caseid][i][Type]) == -1) return -1
	}

	return 1;
}

stock bool IsOpening(Jatekos jatekos)
{
	return m_bOpening[jatekos.index];
}

stock bool IsBanned(Jatekos jatekos)
{
	return m_bBanned[jatekos.index];
}

stock bool IsInventoryLoaded(Jatekos jatekos)
{
	return (m_bLoaded[jatekos.index][Cases] && m_bLoaded[jatekos.index][Keys] && m_iPlayerID[jatekos.index] > 0);
}

public bool SpawnLight(int entity, int mask, any data) {
	if (entity == data) return false;

	return true;
}