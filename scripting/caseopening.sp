#include <sourcemod>
#include <multicolors>
#include <caseopening>
#include <nexd>

#define PLUGIN_NEV	"Caseopening system"
#define PLUGIN_LERIAS	"(8_8)"
#define PLUGIN_AUTHOR	"Nexd"
#define PLUGIN_VERSION	"1.0.1023pre"
#define PLUGIN_URL	"https://github.com/KillStr3aK"

#define MAX_CASES 32
#define MAX_CASE_SPAWN 128
#define MAX_ITEMS 24
#define MAX_MODULES 64
#define MAX_GRADES 12
#pragma tabsize 0

enum Case {
	String:CaseName[32],
	String:Unique_ID[32],
	String:Model[PLATFORM_MAX_PATH],
	bool:bReqKey,
	mCaseID
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
	String:Grade[32],
	Float:Chance,
	ParentCase
}

enum Grades {
	String:g_uName[32],
	String:cColor[12],
	String:rColor[12],
	String:Sound[PLATFORM_MAX_PATH]
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

enum {
	OnStartOpening,
	OnCaseOpened,
	OnClientBanned,
	m_iForwards
}

int g_eCase[MAX_CASES][Case];
int g_eItem[MAX_CASES][MAX_ITEMS][Item];
int g_eGrade[MAX_GRADES][Grades];

int m_iCases = 1;
int m_iItems[MAX_CASES] = 0;
int m_iGrades = 0;

int m_iCacheCase[MAXPLAYERS+1];
int m_iPlayerID[MAXPLAYERS+1];
int PlayerInventory[MAXPLAYERS+1][MAX_CASES][Inventory];
int m_iSzam[MAXPLAYERS+1] = 0;
int m_iOpenedItem[MAXPLAYERS+1] = -1;

int m_iOpenProp[MAXPLAYERS+1] = -1;

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
char m_cPrefix[64];

enum {
	CEnum_Config,
	CEnum_Debug,
	CEnum_Drops,
	CEnum_Minplayer,
	CEnum_DropChance,
	CEnum_DropDelay,
	CEnum_PickUp,
	CEnum_CaseSpawn,
	CEnum_OffsetFloat,
	CEnum_ChatPrefix,
	CEnum_RotateCase,
	CEnum_PlayAnimation,
	CEnum_MustBeClose,
	CEnum_MustLookAt,
	CEnum_Distance,
	Count
}

Handle Forwards[m_iForwards] = INVALID_HANDLE;

Database g_DB;
ConVar g_cR[Count];

#include "case_modules/store_credits.sp"
#include "case_modules/store_database.sp" //Keep this here, and if you're adding new modules which is related to the store, dont include the module file above this one. You can comment out these modules if you're not using store at all.
#include "case_modules/store_playerskin.sp"
#include "case_modules/store_pets.sp"
#include "case_modules/store_trails.sp"
#include "case_modules/store_paintball.sp"
#include "case_modules/store_hats.sp"
#include "case_modules/store_aura.sp"
#include "case_modules/store_tracer.sp"
#include "case_modules/store_lasersight.sp"
#include "case_modules/store_grenadetrails.sp"
#include "case_modules/store_grenadeskin.sp"
#include "case_modules/store_arms.sp"
#include "case_modules/store_levelicons.sp"

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
	RegConsoleCmd("sm_cases", Command_Cases);

	RegAdminCmd("sm_refreshcases", Command_Refresh, ADMFLAG_ROOT);
	RegAdminCmd("sm_refreshid", Command_RefreshId, ADMFLAG_ROOT);
	RegAdminCmd("sm_loadinv", Command_Loadinv, ADMFLAG_ROOT);

	RegAdminCmd("sm_caseban", Command_BanPlayer, ADMFLAG_ROOT);
	RegAdminCmd("sm_drop", Command_Drop, ADMFLAG_ROOT);

	RegAdminCmd("sm_givekey", Command_GiveKey, ADMFLAG_ROOT);
	RegAdminCmd("sm_givecase", Command_GiveCase, ADMFLAG_ROOT);

	RegAdminCmd("sm_givekeyall", Command_GiveKeyAll, ADMFLAG_ROOT);
	RegAdminCmd("sm_givecaseall", Command_GiveCaseAll, ADMFLAG_ROOT);

	g_cR[CEnum_Config] = CreateConVar("case_database", "ladarendszer", "databases.cfg section name");
	g_cR[CEnum_Debug] = CreateConVar("case_debug", "0", "debug mode");
	g_cR[CEnum_Drops] = CreateConVar("case_drops", "1", "Endgame drops");

	g_cR[CEnum_Minplayer] = CreateConVar("case_drops_minplayer", "1", "Minimum player count for endgame drops", _, true, float(1), true, float(MaxClients));
	g_cR[CEnum_DropChance] = CreateConVar("case_drops_chance", "50", "Chance for the drop event to even happen ( 1 - 100 )", _, true, float(1), true, float(100));
	g_cR[CEnum_DropDelay] = CreateConVar("case_drops_delay", "6.5", "Delay for the drop event");

	g_cR[CEnum_PickUp] = CreateConVar("case_pickup", "1", "Enable case pickups");
	g_cR[CEnum_CaseSpawn] = CreateConVar("case_pickup_minplayer", "1", "Minimum players for cases to spawn");
	g_cR[CEnum_OffsetFloat] = CreateConVar("case_pickup_offset", "30.0");
	g_cR[CEnum_RotateCase] = CreateConVar("case_pickup_rotate", "1", "Rotate cases?");

	g_cR[CEnum_PlayAnimation] = CreateConVar("case_open_animation", "1", "Play the case open animation?");
	g_cR[CEnum_MustBeClose] = CreateConVar("case_open_close", "1", "Should the player stay close to the case?");
	g_cR[CEnum_Distance] = CreateConVar("case_open_close_distance", "100.0", "Distance between the player and the case (float)");
	g_cR[CEnum_MustLookAt] = CreateConVar("case_open_close_look", "0", "The player must look at the case?"); //Not works yet

	g_cR[CEnum_ChatPrefix] = CreateConVar("case_chat_prefix", "{default}[{lightred}Case-System{default}]", "Chat prefix for messages");

	HookEvent("round_start", Event_RoundStart);
	HookEvent("cs_intermission", Event_EndMatch);

	LoadTranslations("common.phrases");

	//Core included modules
	StoreCreditsOnPluginStart();
	StorePlayerSkinsOnPluginStart();
	StorePetOnPluginStart();
	StoreTrailOnPluginStart();
	StorePaintballOnPluginStart();
	StoreHatsOnPluginStart();
	StoreAuraOnPluginStart();
	StoreTracerOnPluginStart();
	StoreLaserSightOnPluginStart();
	StoreGrenadeTrailOnPluginStart();
	StoreGrenadeSkinOnPluginStart();
	StoreArmsOnPluginStart(); // requires https://forums.alliedmods.net/showthread.php?p=2467731
	StoreIconOnPluginStart(); // requires https://forums.alliedmods.net/showthread.php?t=319182
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Case_RegisterModule", Native_RegisterModule);

	CreateNative("Case_IsInventoryLoaded", Native_IsInventoryLoaded);
	CreateNative("Case_IsBanned", Native_IsBanned);

	CreateNative("Case_GiveCaseAmount", Native_GiveCase);
	CreateNative("Case_GiveKeyAmount", Native_GiveKey);

	Forwards[OnStartOpening] = CreateGlobalForward("Case_StartOpening", ET_Ignore, Param_Cell, Param_String);
	Forwards[OnCaseOpened] = CreateGlobalForward("Case_OnCaseOpened", ET_Ignore, Param_Cell, Param_String, Param_String);
	Forwards[OnClientBanned] = CreateGlobalForward("Case_OnClientBanned", ET_Ignore, Param_Cell, Param_Cell);
	
	return APLRes_Success;
}

public void OnMapStart()
{
	g_iMarker = PrecacheModel("sprites/blueglow1.vmt");
	OnMapStartLoadCasesFromFile();

	AddFileToDownloadsTable("sound/steelclouds/lada/case_unlock.wav");
	AddFileToDownloadsTable("sound/steelclouds/lada/lada.mp3");
	AddFileToDownloadsTable("sound/steelclouds/lada/porgetes.mp3");
	PrecacheSound("*/steelclouds/lada/case_unlock.wav", true);
	PrecacheSound("steelclouds/lada/lada.mp3", true);
	PrecacheSound("steelclouds/lada/porgetes.mp3", true);
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
				CPrintToChat(client, "%s Your inventory isn't fetched yet, please wait a bit.", m_cPrefix);
				OnClientPostAdminCheck(client);
			}
		} else {
			CPrintToChat(client, "%s \x07You can't access the menu while opening a case.", m_cPrefix);
		}
	} else {
		CPrintToChat(client, "%s \x07You have an active ban from the system.", m_cPrefix);
	}

	return Plugin_Handled;
}

public Action Command_GiveCase(int client, int args)
{
	if(args != 3)
	{
		CPrintToChat(client, "%s Usage: !givecase target caseid amount(1-100)", m_cPrefix);
		return Plugin_Handled;
	}

	char cArgs[3][MAX_NAME_LENGTH+1];
	GetCmdArg(1, cArgs[0], sizeof(cArgs[]));
	GetCmdArg(2, cArgs[1], sizeof(cArgs[]));
	GetCmdArg(3, cArgs[2], sizeof(cArgs[]));

	if(!view_as<Jatekos>(FindTarget(client, cArgs[0], true)).IsValid){
		CPrintToChat(client, "%s Invalid target", m_cPrefix);
		return Plugin_Handled;
	}

	if(!IsValidCase(StringToInt(cArgs[1])))
	{
		CPrintToChat(client, "%s Invalid case", m_cPrefix);
		return Plugin_Handled;
	}

	if(StringToInt(cArgs[2]) > 100 || StringToInt(cArgs[2]) <= 0)
	{
		CPrintToChat(client, "%s Invalid amount (%i)", m_cPrefix, StringToInt(cArgs[2]));
		return Plugin_Handled;
	}

	if(m_iPlayerID[FindTarget(client, cArgs[0], true)] <= 0)
	{
		CPrintToChat(client, "%s The targeted player haven't got ID", m_cPrefix);
		return Plugin_Handled;
	}

	if(!IsInventoryLoaded(view_as<Jatekos>(FindTarget(client, cArgs[0], true))))
	{
		CPrintToChat(client, "%s %N inventory isn't fetched", m_cPrefix, FindTarget(client, cArgs[0], true));
		return Plugin_Handled;
	}

	char Query[256];
	Format(Query, sizeof(Query), "INSERT INTO `case_inventory` (`ID`, `unique_id`, `type`, `caseid`) VALUES (NULL, '%i', 'case', '%i');", m_iPlayerID[FindTarget(client, cArgs[0], true)], StringToInt(cArgs[1]));
	
	for (int i = 0; i < StringToInt(cArgs[2]); ++i)
	{
		SQL_TQuery(g_DB, SQLHibaKereso, Query);
	}

	CPrintToChat(client, "%s You have given %N %i %s", m_cPrefix, FindTarget(client, cArgs[0], true), StringToInt(cArgs[2]), g_eCase[StringToInt(cArgs[1])][Name]);

	return Plugin_Handled;
}

public Action Command_GiveCaseAll(int client, int args)
{
	if(args != 2)
	{
		CPrintToChat(client, "%s Usage: !givecaseall caseid amount(1-100)", m_cPrefix);
		return Plugin_Handled;
	}

	char cArgs[2][MAX_NAME_LENGTH+1];
	GetCmdArg(1, cArgs[0], sizeof(cArgs[]));
	GetCmdArg(2, cArgs[1], sizeof(cArgs[]));

	if(!IsValidCase(StringToInt(cArgs[0])))
	{
		CPrintToChat(client, "%s Invalid case", m_cPrefix);
		return Plugin_Handled;
	}

	if(StringToInt(cArgs[0]) > 100 || StringToInt(cArgs[0]) <= 0)
	{
		CPrintToChat(client, "%s Invalid amount (%i)", m_cPrefix, StringToInt(cArgs[0]));
		return Plugin_Handled;
	}

	char Query[256];

	for (int k = 1; k <= MaxClients; ++k)
	{
		if(!IsValidClient(k)) continue;
		if(m_iPlayerID[k] <= 0) continue;
		if(!IsInventoryLoaded(view_as<Jatekos>(k))) continue;

		Format(Query, sizeof(Query), "INSERT INTO `case_inventory` (`ID`, `unique_id`, `type`, `caseid`) VALUES (NULL, '%i', 'case', '%i');", m_iPlayerID[k], StringToInt(cArgs[0]));
	
		for (int i = 0; i < StringToInt(cArgs[0]); ++i)
		{
			SQL_TQuery(g_DB, SQLHibaKereso, Query);
		}

		CPrintToChat(k, "%s You have given %N %i %s", m_cPrefix, k, StringToInt(cArgs[1]), g_eCase[StringToInt(cArgs[0])][Name]);
	}

	return Plugin_Handled;
}

public Action Command_GiveKeyAll(int client, int args)
{
	if(args != 2)
	{
		CPrintToChat(client, "%s Usage: !givekeyall caseid amount(1-100)", m_cPrefix);
		return Plugin_Handled;
	}

	char cArgs[2][MAX_NAME_LENGTH+1];
	GetCmdArg(1, cArgs[0], sizeof(cArgs[]));
	GetCmdArg(2, cArgs[1], sizeof(cArgs[]));

	if(!IsValidCase(StringToInt(cArgs[0])))
	{
		CPrintToChat(client, "%s Invalid case", m_cPrefix);
		return Plugin_Handled;
	}

	if(StringToInt(cArgs[0]) > 100 || StringToInt(cArgs[0]) <= 0)
	{
		CPrintToChat(client, "%s Invalid amount (%i)", m_cPrefix, StringToInt(cArgs[0]));
		return Plugin_Handled;
	}

	char Query[256];

	for (int k = 1; k <= MaxClients; ++k)
	{
		if(!IsValidClient(k)) continue;
		if(m_iPlayerID[k] <= 0) continue;
		if(!IsInventoryLoaded(view_as<Jatekos>(k))) continue;

		Format(Query, sizeof(Query), "INSERT INTO `case_inventory` (`ID`, `unique_id`, `type`, `caseid`) VALUES (NULL, '%i', 'key', '%i');", m_iPlayerID[k], StringToInt(cArgs[0]));
	
		for (int i = 0; i < StringToInt(cArgs[0]); ++i)
		{
			SQL_TQuery(g_DB, SQLHibaKereso, Query);
		}

		CPrintToChat(k, "%s You have given %N %i key for the %s", m_cPrefix, k, StringToInt(cArgs[1]), g_eCase[StringToInt(cArgs[0])][Name]);
	}

	return Plugin_Handled;
}

public Action Command_GiveKey(int client, int args)
{
	if(args != 3)
	{
		CPrintToChat(client, "%s Usage: !givecase target caseid amount(1-100)", m_cPrefix);
		return Plugin_Handled;
	}

	char cArgs[3][MAX_NAME_LENGTH+1];
	GetCmdArg(1, cArgs[0], sizeof(cArgs[]));
	GetCmdArg(2, cArgs[1], sizeof(cArgs[]));
	GetCmdArg(3, cArgs[2], sizeof(cArgs[]));

	if(!view_as<Jatekos>(FindTarget(client, cArgs[0], true)).IsValid){
		CPrintToChat(client, "%s Invalid target", m_cPrefix);
		return Plugin_Handled;
	}

	if(!IsValidCase(StringToInt(cArgs[1])))
	{
		CPrintToChat(client, "%s Invalid case", m_cPrefix);
		return Plugin_Handled;
	}

	if(StringToInt(cArgs[2]) > 100 || StringToInt(cArgs[2]) <= 0)
	{
		CPrintToChat(client, "%s Invalid amount (%i)", m_cPrefix, StringToInt(cArgs[2]));
		return Plugin_Handled;
	}

	if(m_iPlayerID[FindTarget(client, cArgs[0], true)] <= 0)
	{
		CPrintToChat(client, "%s The targeted player haven't got ID", m_cPrefix);
		return Plugin_Handled;
	}

	if(!IsInventoryLoaded(view_as<Jatekos>(FindTarget(client, cArgs[0], true))))
	{
		CPrintToChat(client, "%s %N inventory isn't fetched", m_cPrefix, FindTarget(client, cArgs[0], true));
		return Plugin_Handled;
	}

	char Query[256];
	Format(Query, sizeof(Query), "INSERT INTO `case_inventory` (`ID`, `unique_id`, `type`, `caseid`) VALUES (NULL, '%i', 'key', '%i');", m_iPlayerID[FindTarget(client, cArgs[0], true)], StringToInt(cArgs[1]));
	
	for (int i = 0; i < StringToInt(cArgs[2]); ++i)
	{
		SQL_TQuery(g_DB, SQLHibaKereso, Query);
	}

	CPrintToChat(client, "%s You have given %N %i key for the %s", m_cPrefix, FindTarget(client, cArgs[0], true), StringToInt(cArgs[2]), g_eCase[StringToInt(cArgs[1])][Name]);

	return Plugin_Handled;
}

public Action Command_Loadinv(int client, int args)
{
	if(args != 1){
		LoadPlayerInventory(Jatekos(client));
		CPrintToChat(client, "%s Your inventory has been fetched.", m_cPrefix);
	} else {
		char cArgs[MAX_NAME_LENGTH+1];
		GetCmdArg(1, cArgs, sizeof(cArgs));
		if(view_as<Jatekos>(FindTarget(client, cArgs, true)).IsValid)
		{
			LoadPlayerInventory(view_as<Jatekos>(FindTarget(client, cArgs, true)));
			CPrintToChat(client, "%s %N's inventory has been fetched.", m_cPrefix, FindTarget(client, cArgs, true));
			CPrintToChat(FindTarget(client, cArgs, true), "%s Your inventory has been fetched by an admin.", m_cPrefix);
		} else {
			CPrintToChat(client, "%s Invalid target.", m_cPrefix);
		}
	}

	return Plugin_Handled;
}

public Action Command_Drop(int client, int args)
{
	int random = GetRandomCasePlayer();
	if(IsValidClient(random))
	{
		int caseid = GetRandomCase();
		if(caseid != -1)
		{
			if(!IsInventoryLoaded(Jatekos(random))) LoadPlayerInventory(Jatekos(random));

			Case_GiveCase(Jatekos(random), caseid);
			CPrintToChatAll("%s \x04%N \x01has got a \x0B%s \x01as a drop!", m_cPrefix, random, g_eCase[caseid][Name]);
			PlaySoundToClient(Jatekos(random), "ui/item_drop_personal.wav");
		} else {
			CPrintToChat(client, "%s Something happend, Please contact the server owner or the plugin author. \x07ERRCODE: Command_Drop.GetRandomCase(%i)", m_cPrefix, caseid);
		}
	} else {
		CPrintToChat(client, "%s Something happend, Please contact the server owner or the plugin author. \x07ERRCODE: Command_Drop.GetRandomCasePlayer(%i)", m_cPrefix, random);
	}

	return Plugin_Handled;
}

public Action Command_BanPlayer(int client, int args)
{
	if(args != 1)
	{
		CPrintToChat(client, "%s Usage: !caseban targetname", m_cPrefix);
		return Plugin_Handled;
	}

	char cArgs[MAX_NAME_LENGTH+1];
	GetCmdArg(1, cArgs, sizeof(cArgs));

	if (!view_as<Jatekos>(FindTarget(client, cArgs, true)).IsValid)
	{
		CPrintToChat(client, "%s Invalid target", m_cPrefix);
		return Plugin_Handled;
	}

	Case_BanPlayer(view_as<Jatekos>(FindTarget(client, cArgs, true)));
	Call_StartForward(Forwards[OnCaseOpened]);
	Call_PushCell(client);
	Call_PushCell(FindTarget(client, cArgs, true));
	Call_Finish();

	return Plugin_Handled;
}

public void Case_BanPlayer(Jatekos jatekos)
{
	char Query[256];
	char cSteamID[20];
	char cPlayerName[MAX_NAME_LENGTH+1];

	jatekos.GetAuthId(AuthId_Steam2, cSteamID, sizeof(cSteamID));
	jatekos.GetName(cPlayerName, sizeof(cPlayerName));

	char cPlayerNameEscaped[MAX_NAME_LENGTH*2+16];
	SQL_EscapeString(g_DB, cPlayerName, cPlayerNameEscaped, sizeof(cPlayerNameEscaped));

	if(!IsBanned(jatekos))
	{
		Format(Query, sizeof(Query), "UPDATE `case_players` SET `banned` = 1, `playername` = '%s' WHERE `case_players`.`steamid` = '%s';", cPlayerNameEscaped, cSteamID);
		CPrintToChatAll("%s \x07%s has been banned from the caseopening system.", m_cPrefix, cPlayerName);

		m_bBanned[jatekos.index] = true;
	} else {
		Format(Query, sizeof(Query), "UPDATE `case_players` SET `banned` = 0, `playername` = '%s' WHERE `case_players`.`steamid` = '%s';", cPlayerNameEscaped, cSteamID);
		CPrintToChatAll("%s \x04%s has been unbanned from the caseopening system.", m_cPrefix, cPlayerName);

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
	m_iOpenProp[client] = -1;

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

public Action Command_RefreshId(int client, int args)
{
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
	}

	LoadPlayerInventory(jatekos);
}

public void CaseMenu(Jatekos jatekos)
{
	Menu menu = CreateMenu(MainMenu);
	menu.SetTitle("Caseopening System\nYour ID: %i", m_iPlayerID[jatekos.index]);
	if(m_iPlayerID[jatekos.index] != 0) menu.AddItem("cases", "Cases");
	else menu.AddItem("", "Cases", ITEMDRAW_DISABLED);
	if(CheckCommandAccess(jatekos.index, "sm_rootflag", ADMFLAG_ROOT)) menu.AddItem("admin", "ADMIN");
	else menu.AddItem("", "ADMIN", ITEMDRAW_DISABLED);
	menu.AddItem("", "", ITEMDRAW_SPACER);
	menu.AddItem("ver", "Version");
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
			LoadPlayerInventory(view_as<Jatekos>(client));
			ListCases(Jatekos(client));
		} else if(StrEqual(info, "admin"))
		{
			Case_AdminMenu(view_as<Jatekos>(client), 1);
		} else if(StrEqual(info, "ver"))
		{
			Case_VersionMenu(Jatekos(client));
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
			if(g_eCase[i][mCaseID] == 0) continue;
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
			else CPrintToChat(client, "%s Something happend, Please contact the server owner or the plugin author. \x07ERRCODE: SelectCase.VerifyCaseItems(%i-%i-%i)", m_cPrefix, m_iCacheCase[client], -1, m_iPlayerID[client]);
			for (int i = 0; i < m_iItems[GetCaseIdFromUnique(cUID)]; ++i)
			{
				if(g_eItem[m_iCacheCase[client]][i][ParentCase] != GetCaseIdFromUnique(cUID)) continue;
				if(g_cR[CEnum_Debug].BoolValue) CPrintToChat(client, "%s \x04%i \x07%s \x10%s \x5%s \x0E%s \x0C%f \x0B%i \x09%i \x03%s", m_cPrefix, g_eItem[m_iCacheCase[client]][i][ParentCase], g_eItem[m_iCacheCase[client]][i][Name], g_eItem[m_iCacheCase[client]][i][Type], g_eItem[m_iCacheCase[client]][i][Value], g_eItem[m_iCacheCase[client]][i][Grade], g_eItem[m_iCacheCase[client]][i][Chance], PlayerInventory[client][m_iCacheCase[client]][Cases], PlayerInventory[client][m_iCacheCase[client]][Keys], g_eCase[m_iCacheCase[client]][bReqKey]?"yes":"no");
			}
		} else {
			if(g_cR[CEnum_Debug].BoolValue) CPrintToChat(client, "%s -1", m_cPrefix);
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
	if(g_eCase[caseid][bReqKey]){
		if(PlayerInventory[jatekos.index][caseid][Cases] >= 1 && PlayerInventory[jatekos.index][caseid][Keys] >= 1) menu.AddItem("open", "Open case");
	} else if(PlayerInventory[jatekos.index][caseid][Cases] >= 1){
		if(PlayerInventory[jatekos.index][caseid][Cases] >= 1) menu.AddItem("open", "Open case");
	}
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

public void Case_VersionMenu(Jatekos jatekos)
{
	Menu menu = CreateMenu(VersionCallback);
	menu.SetTitle("Caseopening System - Version\n%s\nContributors:", PLUGIN_VERSION);
	menu.AddItem("nexd", "KillStr3aK ( Nexd )");
	menu.Display(jatekos.index, MENU_TIME_FOREVER);
}

public int VersionCallback(Menu menu, MenuAction mAction, int client, int item)
{
	if(mAction == MenuAction_Select)
	{
		char info[10];
		menu.GetItem(item, info, sizeof(info));
		if(StrEqual(info, "nexd")){
			CPrintToChat(client, "%s \x10%s\n\x0B%s", m_cPrefix, "https://steamcommunity.com/id/yvaacs/", "https://github.com/KillStr3aK");
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
		CPrintToChat(jatekos.index, "%s Something happend, Please contact the server owner or the plugin author. \x07ERRCODE: Pre_OpenCase.m_iItems(%i)", m_cPrefix, m_iCacheCase[jatekos.index]);
		return;
	}

	if(g_cR[CEnum_PlayAnimation].BoolValue)
	{
		if(IsPlayerAlive(jatekos.index))
		{
			if(IsClientIsOnGround(jatekos.index) && !IsClientCrouching(jatekos.index)){
				if(!StrEqual(g_eCase[m_iCacheCase[jatekos.index]][Model], empty)) CaseOpenAnimation(jatekos, m_iCacheCase[jatekos.index]);
				else CPrintToChat(jatekos.index, "%s Something happend, Please contact the server owner or the plugin author. \x07ERRCODE: Pre_OpenCase.CaseOpenAnimation(%i-%i-%s)", m_cPrefix, m_iCacheCase[jatekos.index], m_iPlayerID[jatekos.index], g_eCase[m_iCacheCase[jatekos.index]][Model]);
			} else CPrintToChat(jatekos.index, "%s You must stand on the ground to open a case.", m_cPrefix);
		} else if(!IsPlayerAlive(jatekos.index))
		{
			StartTimer(jatekos, false);
		}
	} else {
		StartTimer(jatekos, false);
	}

	Call_StartForward(Forwards[OnStartOpening]);
	Call_PushCell(jatekos.index);
	Call_PushString(g_eCase[m_iCacheCase[jatekos.index]][Model]);
	Call_Finish();
}

public Action OpenSound(Handle timer, Jatekos jatekos)
{
	if(!m_bOpening[jatekos.index]) return Plugin_Stop;
	if(g_cR[CEnum_MustBeClose].BoolValue)
	{
		if(GetEntitiesDistance(jatekos.index, m_iOpenProp[jatekos.index]) <= g_cR[CEnum_Distance].FloatValue)
		{
			if(g_cR[CEnum_MustLookAt].BoolValue)
			{
				if(IsClientLookingAtCase(jatekos))
				{
					PlaySoundToClient(jatekos, "steelclouds/lada/porgetes.mp3");
				}
			} else {
				PlaySoundToClient(jatekos, "steelclouds/lada/porgetes.mp3");
			}
		}
	} else {
		PlaySoundToClient(jatekos, "steelclouds/lada/porgetes.mp3");
	}

	return Plugin_Continue;
}

public Action DelayOpenSound(Handle timer, Jatekos jatekos)
{
	CreateTimer(0.25, OpenSound, jatekos, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void CaseOpenAnimation(Jatekos jatekos, int caseid)
{
	int prop = CreateEntityByName("prop_dynamic_override");
	if (IsValidEntity(prop) && prop != -1)
	{
		float fPos[3], fAng[3];
		jatekos.GetAbsOrigin(fPos);
		jatekos.GetEyeAngle(fAng);
	    DispatchKeyValue(prop, "model", g_eCase[caseid][Model]);
	    ActivateEntity(prop);
	    DispatchSpawn(prop);

	    fPos[0] = fPos[0]+(50*(Sine(DegToRad(fAng[0]))));
	    fPos[1] = fPos[1]+(50*(Sine(DegToRad(fAng[1]))));
	    fAng[0] = 0.0;
	    fAng[1] += 90;

	    TeleportEntity(prop, fPos, fAng, NULL_VECTOR);

	    PlaySoundToClient(jatekos, "ui/panorama/case_drop_01.wav");
	    SetVariantString("fall");
	    AcceptEntityInput(prop, "SetAnimation");
	    AcceptEntityInput(prop, "Enable");

	    HookSingleEntityOutput(prop, "OnAnimationDone", Case_OnAnimationDone, true);

	    m_iOpenProp[jatekos.index] = prop;
	}
}

public void Case_OnAnimationDone(const char[] output, int caller, int activator, float delay) 
{
	if(IsValidEntity(caller))
	{
		SetVariantString("open");
		AcceptEntityInput(caller, "SetAnimation");
		PlaySoundToClient(view_as<Jatekos>(GetPlayerFromOpenEntity(caller)), "steelclouds/lada/case_unlock");
		CreateTimer(2.0, DelayOpenCase, view_as<Jatekos>(GetPlayerFromOpenEntity(caller)), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action DelayOpenCase(Handle timer, Jatekos jatekos)
{
	StartTimer(jatekos, true);
	PlaySoundToClient(jatekos, "ui/csgo_ui_crate_open.wav");
}

public void StartTimer(Jatekos jatekos, bool delay)
{
	m_bOpening[jatekos.index] = true;
	m_iSzam[jatekos.index] = 0;

	ManagePlayerInventory(jatekos);

	if(delay) CreateTimer(0.35, DelayOpenSound, jatekos);
	else CreateTimer(0.2, OpenSound, jatekos, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(0.1, OpenCase, jatekos, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action KillProp(Handle timer, Jatekos jatekos)
{
	if(IsValidEntity(m_iOpenProp[jatekos.index])) RemovePlayerCaseProp(m_iOpenProp[jatekos.index]);
}

public void RemovePlayerCaseProp(int prop)
{
	AcceptEntityInput(prop, "kill");
	m_iOpenProp[GetPlayerFromOpenEntity(prop)] = -1;
}

public Action OpenCase(Handle timer, Jatekos jatekos)
{
	if(!jatekos.IsValid || !m_bOpening[jatekos.index])
		return Plugin_Stop;

	if(m_fChance[jatekos.index] == -1.0) m_fChance[jatekos.index] = GetRandomFloat(GetLowestItemChance(m_iCacheCase[jatekos.index]), GetHighestItemChance(m_iCacheCase[jatekos.index]));
	if(m_iOpenedItem[jatekos.index] == -1)
	{
		if(GetItemFromCase(jatekos, m_iCacheCase[jatekos.index]) != -1) m_iOpenedItem[jatekos.index] = GetItemFromCase(jatekos, m_iCacheCase[jatekos.index]);
		else {
			ManagePlayerInventory(jatekos, false);
			CPrintToChat(jatekos.index, "%s Something happend, Please contact the server owner or the plugin author. \x07ERRCODE: fOpenCase.GetItemFromCase(%i-%i-%i)", m_cPrefix, m_iOpenedItem[jatekos.index], m_iCacheCase[jatekos.index], m_iPlayerID[jatekos.index]);
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
			if(GetGrade(g_eItem[m_iCacheCase[jatekos.index]][m_iOpenedItem[jatekos.index]][Grade]) != -1)
			{
				if(g_cR[CEnum_PlayAnimation].BoolValue)
				{
					if(IsPlayerAlive(jatekos.index))
					{
						if(g_cR[CEnum_MustBeClose].BoolValue)
						{
							if(IsPlayerAlive(jatekos.index) && GetEntitiesDistance(jatekos.index, m_iOpenProp[jatekos.index]) <= g_cR[CEnum_Distance].FloatValue){
								if(g_cR[CEnum_MustLookAt].BoolValue)
								{
									if(IsClientLookingAtCase(jatekos)) PrintHintText(jatekos.index, "<span class='fontSize-xl'><big><u><b><font color='#00CCFF'>›› <font color='%s'>%s</font> ‹‹</font></b></u></big></span>", g_eGrade[GetGrade(g_eItem[m_iCacheCase[jatekos.index]][m_iOpenedItem[jatekos.index]][Grade])][rColor], g_eItem[m_iCacheCase[jatekos.index]][m_iOpenedItem[jatekos.index]][Name]);
								} else PrintHintText(jatekos.index, "<span class='fontSize-xl'><big><u><b><font color='#00CCFF'>›› <font color='%s'>%s</font> ‹‹</font></b></u></big></span>", g_eGrade[GetGrade(g_eItem[m_iCacheCase[jatekos.index]][m_iOpenedItem[jatekos.index]][Grade])][rColor], g_eItem[m_iCacheCase[jatekos.index]][m_iOpenedItem[jatekos.index]][Name]);
							}
						} else {
							PrintHintText(jatekos.index, "<span class='fontSize-xl'><big><u><b><font color='#00CCFF'>›› <font color='%s'>%s</font> ‹‹</font></b></u></big></span>", g_eGrade[GetGrade(g_eItem[m_iCacheCase[jatekos.index]][m_iOpenedItem[jatekos.index]][Grade])][rColor], g_eItem[m_iCacheCase[jatekos.index]][m_iOpenedItem[jatekos.index]][Name]);
						}
					} else {
						PrintHintText(jatekos.index, "<span class='fontSize-xl'><big><u><b><font color='#00CCFF'>›› <font color='%s'>%s</font> ‹‹</font></b></u></big></span>", g_eGrade[GetGrade(g_eItem[m_iCacheCase[jatekos.index]][m_iOpenedItem[jatekos.index]][Grade])][rColor], g_eItem[m_iCacheCase[jatekos.index]][m_iOpenedItem[jatekos.index]][Name]);
					}
				} else {
					PrintHintText(jatekos.index, "<span class='fontSize-xl'><big><u><b><font color='#00CCFF'>›› <font color='%s'>%s</font> ‹‹</font></b></u></big></span>", g_eGrade[GetGrade(g_eItem[m_iCacheCase[jatekos.index]][m_iOpenedItem[jatekos.index]][Grade])][rColor], g_eItem[m_iCacheCase[jatekos.index]][m_iOpenedItem[jatekos.index]][Name]);
				}
			} else {
				CPrintToChat(jatekos.index, "%s Something happend while we tried to get the item grade. Please contact the server owner or the plugin author. \x07ERRCODE: fOpenCase.ProcessItem.GetGrade(%i-%i-%i-%i)", m_cPrefix, m_iOpenedItem[jatekos.index], m_iCacheCase[jatekos.index], m_iPlayerID[jatekos.index], GetGrade(g_eItem[m_iCacheCase[jatekos.index]][m_iOpenedItem[jatekos.index]][Grade]));
				ManagePlayerInventory(jatekos, false);
			}
			if(g_cR[CEnum_Debug].BoolValue) Format(m_cChanceDetails, sizeof(m_cChanceDetails), "item chance: %f player chance: %f", g_eItem[m_iCacheCase[jatekos.index]][m_iOpenedItem[jatekos.index]][Chance], m_fChance[jatekos.index]);
			CPrintToChatAll("%s \x04%s \x01has opened a case and found: %s%s", m_cPrefix, cPlayerName, g_eGrade[GetGrade(g_eItem[m_iCacheCase[jatekos.index]][m_iOpenedItem[jatekos.index]][Grade])][cColor], g_eItem[m_iCacheCase[jatekos.index]][m_iOpenedItem[jatekos.index]][Name], g_eItem[m_iCacheCase[jatekos.index]][m_iOpenedItem[jatekos.index]][Chance], m_fChance[jatekos.index], (g_cR[CEnum_Debug].BoolValue?m_cChanceDetails:empty));
			if(!StrEqual(g_eGrade[GetGrade(g_eItem[m_iCacheCase[jatekos.index]][m_iOpenedItem[jatekos.index]][Grade])][Sound], empty)) PlayOpenSound(jatekos, g_eGrade[GetGrade(g_eItem[m_iCacheCase[jatekos.index]][m_iOpenedItem[jatekos.index]][Grade])][Sound]);
			if(g_cR[CEnum_Debug].BoolValue) CPrintToChat(jatekos.index, "%s highest: %f lowest: %f", m_cPrefix, GetHighestItemChance(m_iCacheCase[jatekos.index]), GetLowestItemChance(m_iCacheCase[jatekos.index]));

			Call_StartForward(Forwards[OnCaseOpened]);
			Call_PushCell(jatekos.index);
			Call_PushString(g_eItem[m_iCacheCase[jatekos.index]][m_iOpenedItem[jatekos.index]][Type]);
			Call_PushString(g_eItem[m_iCacheCase[jatekos.index]][m_iOpenedItem[jatekos.index]][Value]);
			Call_Finish();
		} else {
			ManagePlayerInventory(jatekos, false);
			CPrintToChat(jatekos.index, "%s Something happend while we tried to process your item, Please contact the server owner or the plugin author. \x07ERRCODE: fOpenCase.ProcessItem(%i-%i-%i-%i)", m_cPrefix, m_iOpenedItem[jatekos.index], m_iCacheCase[jatekos.index], m_iPlayerID[jatekos.index], -1);
		}
		
		m_fChance[jatekos.index] = -1.0;
		m_iSzam[jatekos.index] = 0;
		m_iOpenedItem[jatekos.index] = -1;
		m_bOpening[jatekos.index] = false;

		CreateTimer(1.5, KillProp, jatekos);
		return Plugin_Stop;
	}

	if(!StrEqual(g_eItem[m_iCacheCase[jatekos.index]][randomszam][Name], empty)) {
		if(GetGrade(g_eItem[m_iCacheCase[jatekos.index]][randomszam][Grade]) != -1) {
			if(g_cR[CEnum_PlayAnimation].BoolValue)
			{
				if(IsPlayerAlive(jatekos.index))
				{
					if(g_cR[CEnum_MustBeClose].BoolValue)
					{
						if(GetEntitiesDistance(jatekos.index, m_iOpenProp[jatekos.index]) <= g_cR[CEnum_Distance].FloatValue){
							if(g_cR[CEnum_MustLookAt].BoolValue)
							{
								if(IsClientLookingAtCase(jatekos))
								{
									PrintHintText(jatekos.index, "<span class='fontSize-xl'><big><u><b><font color='#00CCFF'>›› <font color='%s'>%s</font> ‹‹</font></b></u></big></span>", g_eGrade[GetGrade(g_eItem[m_iCacheCase[jatekos.index]][randomszam][Grade])][rColor], g_eItem[m_iCacheCase[jatekos.index]][randomszam][Name]);
								}
							} else {
								PrintHintText(jatekos.index, "<span class='fontSize-xl'><big><u><b><font color='#00CCFF'>›› <font color='%s'>%s</font> ‹‹</font></b></u></big></span>", g_eGrade[GetGrade(g_eItem[m_iCacheCase[jatekos.index]][randomszam][Grade])][rColor], g_eItem[m_iCacheCase[jatekos.index]][randomszam][Name]);
							}
						}
					} else {
						PrintHintText(jatekos.index, "<span class='fontSize-xl'><big><u><b><font color='#00CCFF'>›› <font color='%s'>%s</font> ‹‹</font></b></u></big></span>", g_eGrade[GetGrade(g_eItem[m_iCacheCase[jatekos.index]][randomszam][Grade])][rColor], g_eItem[m_iCacheCase[jatekos.index]][randomszam][Name]);
					}
				} else {
					PrintHintText(jatekos.index, "<span class='fontSize-xl'><big><u><b><font color='#00CCFF'>›› <font color='%s'>%s</font> ‹‹</font></b></u></big></span>", g_eGrade[GetGrade(g_eItem[m_iCacheCase[jatekos.index]][randomszam][Grade])][rColor], g_eItem[m_iCacheCase[jatekos.index]][randomszam][Name]);
				}
			} else {
				PrintHintText(jatekos.index, "<span class='fontSize-xl'><big><u><b><font color='#00CCFF'>›› <font color='%s'>%s</font> ‹‹</font></b></u></big></span>", g_eGrade[GetGrade(g_eItem[m_iCacheCase[jatekos.index]][randomszam][Grade])][rColor], g_eItem[m_iCacheCase[jatekos.index]][randomszam][Name]);
			}
		} else {
			CPrintToChat(jatekos.index, "%s Something happend while we tried to get the item grade. Please contact the server owner or the plugin author. \x07ERRCODE: fOpenCase.GetGrade(%i-%i-%i-%i)", m_cPrefix, randomszam, m_iCacheCase[jatekos.index], m_iPlayerID[jatekos.index], GetGrade(g_eItem[m_iCacheCase[jatekos.index]][randomszam][Grade]));
			ManagePlayerInventory(jatekos, false);

			m_fChance[jatekos.index] = -1.0;
			m_iSzam[jatekos.index] = 0;
			m_iOpenedItem[jatekos.index] = -1;
			m_bOpening[jatekos.index] = false;

			CreateTimer(1.5, KillProp, jatekos);
			return Plugin_Stop;
		}
	}

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
		CPrintToChat(jatekos.index, "%s Something happend, there is no module for the item you have opened, Please contact the server owner or the plugin author. \x07ERRCODE: fProcessItem(%i-%i-%s)", m_cPrefix, Case_GetTypeHandler(type), m_iPlayerID[jatekos.index], type);
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

	char Query[256];

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
			CreateTimer(g_cR[CEnum_DropDelay].FloatValue, Case_DropEvent, view_as<Jatekos>(GetRandomCasePlayer()), TIMER_FLAG_NO_MAPCHANGE);
		} else {
			CPrintToChatAll("%s There will be no drop for now.", m_cPrefix);
		}
	} else {
		CPrintToChatAll("%s There is not enough player for a case drop.", m_cPrefix);
	}
}

public Action Case_DropEvent(Handle timer, Jatekos jatekos)
{
	if(jatekos.IsValid)
	{
		int caseid = GetRandomCase();
		if(caseid != -1)
		{
			Case_GiveCase(jatekos, caseid);
			CPrintToChatAll("%s \x04%N \x01has got a \x0B%s \x01as a drop!", m_cPrefix, jatekos.index, g_eCase[caseid][Name]);
			PlaySoundToClient(jatekos, "ui/item_drop_personal.wav");
		} else {
			CPrintToChat(jatekos.index, "%s Something happend, Please contact the server owner or the plugin author. \x07ERRCODE: Case_DropEvent.GetRandomCase(%i)", m_cPrefix, caseid);
		}
	} else {
		CPrintToChatAll("%s Something happend, Please contact the server owner or the plugin author. \x07ERRCODE: Case_DropEvent.GetRandomCasePlayer(%i)", m_cPrefix, jatekos.index);
	}

	return Plugin_Continue;
}

public void Case_GiveCase(Jatekos jatekos, int caseid)
{
	char Query[256];
	if(caseid < 1) caseid = 1;
	Format(Query, sizeof(Query), "INSERT INTO `case_inventory` (`ID`, `unique_id`, `type`, `caseid`) VALUES (NULL, '%i', 'case', '%i');", m_iPlayerID[jatekos.index], caseid);
	SQL_TQuery(g_DB, SQLHibaKereso, Query);
}

public void PlaySoundToClient(Jatekos jatekos, char[] sound)
{
	PlayOpenSound(jatekos, sound);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(g_cR[CEnum_PickUp].BoolValue)
	{
		if(GetInGameClientCount() >= g_cR[CEnum_CaseSpawn].IntValue)
		{
			Case_SpawnCases();
		} else {
			CPrintToChatAll("%s There is not enough player to spawn cases", m_cPrefix);
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
  		`grade` varchar(32) NOT NULL, \
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

	Format(createTableQuery, sizeof(createTableQuery), 
		"CREATE TABLE IF NOT EXISTS `case_grades` ( \
 		`ID` bigint(20) NOT NULL AUTO_INCREMENT, \
  		`unique_id` varchar(32) COLLATE utf8_bin NOT NULL, \
  		`chatcolor` varchar(12) COLLATE utf8_bin NOT NULL, \
  		`rollcolor` varchar(12) COLLATE utf8_bin NOT NULL, \
  		`sound` varchar(255) COLLATE utf8_bin NOT NULL, \
 		 PRIMARY KEY (`ID`), \
 		 UNIQUE KEY `unique_id` (`unique_id`)  \
  		 ) ENGINE = InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8 COLLATE=utf8_bin;");

	SQL_TQuery(g_DB, SQLHibaKereso, createTableQuery);

	SQL_LoadCases();

	m_fOffsetZ = g_cR[CEnum_OffsetFloat].FloatValue;
	g_cR[CEnum_ChatPrefix].GetString(m_cPrefix, sizeof(m_cPrefix));

	for (int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidClient(i)) continue;

		OnClientPostAdminCheck(i);
	}
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
		g_eCase[m_iCases][mCaseID] = SQL_FetchInt(hndl, 3);
		g_eCase[m_iCases][bReqKey] = view_as<bool>(SQL_FetchInt(hndl, 4));

		if(view_as<int>(g_eCase[m_iCases][bReqKey]) > 1 && view_as<int>(g_eCase[m_iCases][bReqKey]) < 0)
		{
			g_eCase[m_iCases][bReqKey] = false;
		}

		if(!(g_eCase[m_iCases][mCaseID] >= 0)) continue;
		Format(Query, sizeof(Query), "SELECT * FROM case_items WHERE case_id = '%i';", g_eCase[m_iCases][mCaseID]);
		SQL_TQuery(g_DB, GetItemsFromDB, Query, g_eCase[m_iCases][mCaseID]);

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
		SQL_FetchString(hndl, 6, g_eItem[caseid][m_iItems[caseid]][Grade], 32);
		g_eItem[caseid][m_iItems[caseid]][ParentCase] = SQL_FetchInt(hndl, 5);
		g_eItem[caseid][m_iItems[caseid]][Chance] = SQL_FetchFloat(hndl, 7);

		m_iItems[caseid]++;
	}

	char Query[256];
	Format(Query, sizeof(Query), "SELECT * FROM case_grades;");
	SQL_TQuery(g_DB, GetGradesFromDB, Query);
}

public void GetGradesFromDB(Handle owner, Handle hndl, const char[] error, any data)
{
	while (SQL_FetchRow(hndl)) {
		if(m_iGrades == MAX_GRADES) return;
		SQL_FetchString(hndl, 1, g_eGrade[m_iGrades][g_uName], 32);
		SQL_FetchString(hndl, 2, g_eGrade[m_iGrades][cColor], 12);
		SQL_FetchString(hndl, 3, g_eGrade[m_iGrades][rColor], 12);
		SQL_FetchString(hndl, 4, g_eGrade[m_iGrades][Sound], PLATFORM_MAX_PATH);

		m_iGrades++;
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
	m_iGrades = 0;
}

public int Case_SpawnCases()
{
	OnMapStartLoadCasesFromFile();

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
	
	if(g_cR[CEnum_RotateCase].BoolValue)
	{
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
	}
	
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
		if(m_iCaseItemId[0] == 0 && m_iCaseItemId[1] == 0 && g_iLoadedCases[m_iCaseItemId[0]] == 0 && g_iSpawnedCases[m_iCaseItemId[0]] == 0) CPrintToChat(activator, "%s Something happend while we tried to process your request, Please contact the server owner or the plugin author. \x07ERRCODE: CaseTrigger.Case_OnStartTouch(%i-%i-%i-%i-%i)", m_cPrefix, m_iCaseItemId[0], m_iCaseItemId[1], m_iCases, g_iLoadedCases[m_iCaseItemId[0]], g_iSpawnedCases[m_iCaseItemId[0]]);
		g_eSpawnPositions[m_iCaseItemId[0]][m_iCaseItemId[1]][bSpawned] = false;
				
		AcceptEntityInput(EntRefToEntIndex(g_eSpawnPositions[m_iCaseItemId[0]][m_iCaseItemId[1]][EntRef]), "kill");
		g_iSpawnedCases[m_iCaseItemId[0]]--;

		Case_GiveCase(jatekos, m_iCaseItemId[0]);
				
		char cPlayerName[MAX_NAME_LENGTH+1];
		jatekos.GetName(cPlayerName, sizeof(cPlayerName));
		CPrintToChatAll("%s %s has picked up a %s!", m_cPrefix, cPlayerName, g_eCase[m_iCaseItemId[0]][Name]);
		PlaySoundToClient(jatekos, "steelclouds/lada/lada.mp3");
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

public void PlayOpenSound(Jatekos jatekos, char[] sound)
{
	ClientCommand(jatekos.index, "play %s", sound);
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
				ExplodeString(sBuffer, ";", m_sLoadedData, sizeof(m_sLoadedData[]) / 8, sizeof(m_sLoadedData[]));
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

	if(g_cR[CEnum_PickUp].BoolValue)
	{
		for (int i = 1; i < m_iCases; ++i)
		{
			g_iLoadedCases[i] = 0;
		}
	}
	
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
		
		g_eSpawnPositions[caseid][g_iLoadedCases[caseid]][fPosX] = fPos[0];
		g_eSpawnPositions[caseid][g_iLoadedCases[caseid]][fPosY] = fPos[1];
		g_eSpawnPositions[caseid][g_iLoadedCases[caseid]][fPosZ] = fPos[2];
		g_iLoadedCases[caseid]++;
		
		CPrintToChat(jatekos.index, "%s You have placed a new case! <%i>:<%.2f>:<%.2f>:<%.2f>", m_cPrefix, caseid, fPos[0], fPos[1], fPos[2]);
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
			if(g_eCase[i][mCaseID] == 0) continue;
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
			if(g_cR[CEnum_Debug].BoolValue) CPrintToChat(client, "%s -1", m_cPrefix);
		}
	}
}

public void fPlaceCase_DeleteLast(Jatekos jatekos, int caseid) {
	g_iLoadedCases[caseid]--;
	CPrintToChat(jatekos.index, "%s You have deleted the previous placed case. (total: %i).", m_cPrefix, g_iLoadedCases[caseid]);
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

public int Native_IsBanned(Handle plugin, int params)
{
	return IsBanned(GetNativeCell(1));
}

public void SQLHibaKereso(Handle owner, Handle hndl, const char[] error, any data) {
	if (!StrEqual(error, ""))
		LogError(error);
}

public int Native_GiveCase(Handle plugin, int params)
{
	if(!view_as<Jatekos>(GetNativeCell(1)).IsValid) return ThrowNativeError(SP_ERROR_NATIVE, "Invalid target (%i)", view_as<Jatekos>(GetNativeCell(1)).index);
	if(!IsValidCase(GetNativeCell(2))) return ThrowNativeError(SP_ERROR_NATIVE, "Invalid case id (%i)", GetNativeCell(2));
	if(GetNativeCell(3) > 100 || GetNativeCell(3) <= 0) return ThrowNativeError(SP_ERROR_NATIVE, "Invalid amount (%i)", GetNativeCell(3));
	if(m_iPlayerID[view_as<Jatekos>(GetNativeCell(1)).index] <= 0) return ThrowNativeError(SP_ERROR_NATIVE, "The targeted player haven't got ID (%i)", view_as<Jatekos>(GetNativeCell(1)).index);
	if(!IsInventoryLoaded(view_as<Jatekos>(GetNativeCell(1)))) return ThrowNativeError(SP_ERROR_NATIVE, "The targeted player inventory isn't fetched (%i)", view_as<Jatekos>(GetNativeCell(1)).index);

	char Query[256];
	Format(Query, sizeof(Query), "INSERT INTO `case_inventory` (`ID`, `unique_id`, `type`, `caseid`) VALUES (NULL, '%i', 'case', '%i');", m_iPlayerID[view_as<Jatekos>(GetNativeCell(1)).index], GetNativeCell(2));
	
	for (int i = 0; i < GetNativeCell(3); ++i)
	{
		SQL_TQuery(g_DB, SQLHibaKereso, Query);
	}

	return 1;
}

public int Native_GiveKey(Handle plugin, int params)
{
	if(!view_as<Jatekos>(GetNativeCell(1)).IsValid) return ThrowNativeError(SP_ERROR_NATIVE, "Invalid target (%i)", view_as<Jatekos>(GetNativeCell(1)).index);
	if(!IsValidCase(GetNativeCell(2))) return ThrowNativeError(SP_ERROR_NATIVE, "Invalid case id (%i)", GetNativeCell(2));
	if(GetNativeCell(3) > 100 || GetNativeCell(3) <= 0) return ThrowNativeError(SP_ERROR_NATIVE, "Invalid amount (%i)", GetNativeCell(3));
	if(m_iPlayerID[view_as<Jatekos>(GetNativeCell(1)).index] <= 0) return ThrowNativeError(SP_ERROR_NATIVE, "The targeted player haven't got ID (%i)", view_as<Jatekos>(GetNativeCell(1)).index);
	if(!IsInventoryLoaded(view_as<Jatekos>(GetNativeCell(1)))) return ThrowNativeError(SP_ERROR_NATIVE, "The targeted player inventory isn't fetched (%i)", view_as<Jatekos>(GetNativeCell(1)).index);

	char Query[256];
	Format(Query, sizeof(Query), "INSERT INTO `case_inventory` (`ID`, `unique_id`, `type`, `caseid`) VALUES (NULL, '%i', 'key', '%i');", m_iPlayerID[view_as<Jatekos>(GetNativeCell(1)).index], GetNativeCell(2));
	
	for (int i = 0; i < GetNativeCell(3); ++i)
	{
		SQL_TQuery(g_DB, SQLHibaKereso, Query);
	}

	return 1;
}

stock int GetCaseIdFromUnique(char[] unique)
{
	for (int i = 1; i < m_iCases; ++i)
	{
		if(StrEqual(g_eCase[i][Unique_ID], unique))
			return g_eCase[i][mCaseID];
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

stock int GetRandomCasePlayer()
{
	int[] jatekosok = new int[MaxClients+1];
	int jatekosszam = 0;

	for(int i = 1; i <= MaxClients; i++)
	{
	    if(!IsValidClient(i)) continue;
	    if(IsBanned(view_as<Jatekos>(i))) continue;

		jatekosok[jatekosszam++] = i;
	}

	if(jatekosszam > 0) return jatekosok[GetRandomInt(0, jatekosszam - 1)];

	return -1;
}

stock int GetGrade(char[] grade)
{
	for (int i = 0; i < m_iGrades; ++i)
	{
		if(StrEqual(g_eGrade[i][g_uName], grade)) return i;
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

	if(chance == 1.0) chance = 0.00000001;

	return chance;
}

stock int GetRandomCase()
{
	int cases[MAX_CASES+1];
	int casecount = 0;

	for(int i = 1; i <= m_iCases; i++)
	{
	    if(!IsValidCase(i)) continue;

	    cases[casecount++] = GetCaseIdFromUnique(g_eCase[i][Unique_ID]);
	}

	if(casecount > 0) return cases[GetRandomInt(0, casecount - 1)];

	return -1;
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

stock bool IsValidCase(int caseid)
{
	if(!StrEqual(g_eCase[caseid][Name], empty) && !StrEqual(g_eCase[caseid][Unique_ID], empty) && g_eCase[caseid][mCaseID] > 0 && caseid > 0 && caseid < MAX_CASES) return true;

	return false;
}

stock bool IsBanned(Jatekos jatekos)
{
	return m_bBanned[jatekos.index];
}

stock bool IsClientLookingAtCase(Jatekos jatekos)
{
	if(GetClientAimTarget(jatekos.index, false) == m_iOpenProp[jatekos.index]) return true;
	return false;
}

stock bool IsInventoryLoaded(Jatekos jatekos)
{
	return (m_bLoaded[jatekos.index][Cases] && m_bLoaded[jatekos.index][Keys] && m_iPlayerID[jatekos.index] > 0);
}

public bool SpawnLight(int entity, int mask, any data) {
	if (entity == data) return false;

	return true;
}

stock int GetPlayerFromOpenEntity(int entity)
{
	for (int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidClient(i)) continue;

		if(m_iOpenProp[i] == entity) return i;
	}

	return -1;
}