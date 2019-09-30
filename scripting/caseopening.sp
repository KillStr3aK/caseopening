#include <sourcemod>
#include <nexd>

#define PLUGIN_NEV	"Caseopening system"
#define PLUGIN_LERIAS	"(8_8)"
#define PLUGIN_AUTHOR	"Nexd"
#define PLUGIN_VERSION	"1.0.0917"
#define PLUGIN_URL	"https://github.com/KillStr3aK"

#define MAX_CASES 10
#define MAX_ITEMS 16
#pragma tabsize 0

enum Case {
	String:CaseName[32],
	String:Unique_ID[32],
	CaseID
}

enum Item {
	String:Name[32],
	String:Type[20],
	String:Value[32],
	String:Grade[10],
	Float:Chance,
	ParentCase
}

enum Inventory {
	Cases,
	Keys
}

int g_eCase[MAX_CASES][Case];
int g_eItem[MAX_CASES][MAX_ITEMS][Item];
int m_iCases = 1;
int m_iItems[MAX_CASES] = 0;

int m_iCacheCase[MAXPLAYERS+1];
int m_iPlayerID[MAXPLAYERS+1];
int PlayerInventory[MAXPLAYERS+1][MAX_CASES][Inventory];

enum {
	CEnum_Config,
	Count
}

Database g_DB;
ConVar g_cR[Count];

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

	g_cR[CEnum_Config] = CreateConVar("case_database", "ladarendszer", "databases.cfg section name");
}

public Action Command_Cases(int client, int args)
{
	CaseMenu(Jatekos(client));
}

public Action Command_Loadinv(int client, int args)
{
	LoadPlayerInventory(Jatekos(client));
}

public void OnClientPostAdminCheck(int client)
{
	if(!IsValidClient(client)) return;

	m_iCacheCase[client] = 0;
	m_iPlayerID[client] = 0;
	for (int i = 1; i < m_iCases; ++i)
	{
		PlayerInventory[client][i][Cases] = 0;
		PlayerInventory[client][i][Keys] = 0;
	}

	char Query[256];
	char steamid[20];
	view_as<Jatekos>(client).GetAuthId(AuthId_Steam2, steamid, sizeof(steamid));
	Format(Query, sizeof(Query), "SELECT steamid, ID FROM case_players WHERE steamid = '%s';", steamid);
	SQL_TQuery(g_DB, CheckPlayer, Query, view_as<Jatekos>(client));
}

public void CheckPlayer(Handle owner, Handle hndl, const char[] error, Jatekos jatekos)
{
	char cSteamID[20];
	while (SQL_FetchRow(hndl)) {
		SQL_FetchString(hndl, 0, cSteamID, sizeof(cSteamID));
		m_iPlayerID[jatekos.index] = SQL_FetchInt(hndl, 1);
	}

	if(StrEqual(cSteamID, empty))
	{
		char steamid[20];
		jatekos.GetAuthId(AuthId_Steam2, steamid, sizeof(steamid));

		char playername[MAX_NAME_LENGTH+1];
		jatekos.GetName(playername, sizeof(playername));

		char Query[256];
		Format(Query, sizeof(Query), "INSERT INTO `case_players` (`ID`, `playername`, `steamid`) VALUES (NULL, '%s', '%s');", playername, steamid);

		SQL_TQuery(g_DB, SQLHibaKereso, Query);
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
	menu.Display(jatekos.index, 60);
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

	menu.Display(jatekos.index, 60);
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
			CaseDetailsMenu(Jatekos(client), m_iCacheCase[client]);
			for (int i = 0; i < m_iItems[GetCaseIdFromUnique(cUID)]; ++i)
			{
				if(g_eItem[m_iCacheCase[client]][i][ParentCase] != GetCaseIdFromUnique(cUID)) continue;
				PrintToChat(client, "\x04%i \x07%s \x10%s \x5%s \x0E%s \x0C%f \x0B%i \x09%i", g_eItem[m_iCacheCase[client]][i][ParentCase], g_eItem[m_iCacheCase[client]][i][Name], g_eItem[m_iCacheCase[client]][i][Type], g_eItem[m_iCacheCase[client]][i][Value], g_eItem[m_iCacheCase[client]][i][Grade], g_eItem[m_iCacheCase[client]][i][Chance], PlayerInventory[client][i][Cases], PlayerInventory[client][i][Keys]);
			}
		} else {
			PrintToChat(client, "-1");
		}
	}
}

stock void CaseDetailsMenu(Jatekos jatekos, int caseid)
{
	char cLine[128];
	Menu menu = CreateMenu(CaseDetails);
	menu.SetTitle("Caseopening System - Case details\nYou've got %i keys for this case", PlayerInventory[jatekos.index][caseid][Keys]);
	Format(cLine, sizeof(cLine), "Case name: %s", g_eCase[caseid][CaseName]);
	menu.AddItem("", cLine, ITEMDRAW_DISABLED);
	Format(cLine, sizeof(cLine), "Require key: YES");
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
	menu.Display(jatekos.index, 60);
}

public int CaseDetails(Menu menu, MenuAction mAction, int client, int item)
{
	if(mAction == MenuAction_Select)
	{
		char info[10];
		menu.GetItem(item, info, sizeof(info));

		if(StrEqual(info, "open"))
		{
			PrintToChat(client, "Not done yet");
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
 		 PRIMARY KEY (`ID`), \
  		 UNIQUE KEY `unique_name` (`unique_name`)  \
  		 ) ENGINE = InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8 COLLATE=utf8_bin;");

	SQL_TQuery(g_DB, SQLHibaKereso, createTableQuery);

	Format(createTableQuery, sizeof(createTableQuery), 
		"CREATE TABLE IF NOT EXISTS `case_items` ( \
 		`ID` bigint(20) NOT NULL AUTO_INCREMENT, \
  		`name` varchar(32) COLLATE utf8_bin NOT NULL, \
  		`uname` varchar(32) COLLATE utf8_bin NOT NULL, \
  		`type` varchar(20) COLLATE utf8_bin NOT NULL, \
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
		g_eCase[m_iCases][CaseID] = SQL_FetchInt(hndl, 3);

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
		SQL_FetchString(hndl, 3, g_eItem[caseid][m_iItems[caseid]][Type], 20);
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
		SQL_TQuery(g_DB, GetPlayerCases, Query, jatekos);
	}

	for (int i = 1; i < m_iCases; ++i)
	{
		m_iCacheCase[jatekos.index] = i;
		Format(Query, sizeof(Query), "SELECT * FROM case_inventory WHERE unique_id = '%i' AND type = 'key' AND caseid = '%i';", m_iPlayerID[jatekos.index], m_iCacheCase[jatekos.index]);
		SQL_TQuery(g_DB, GetPlayerKeys, Query, jatekos);
	}
}

public void GetPlayerCases(Handle owner, Handle hndl, const char[] error, Jatekos jatekos)
{
	PlayerInventory[jatekos.index][m_iCacheCase[jatekos.index]][Cases] = SQL_GetRowCount(hndl);
	//PrintToChat(jatekos.index, "%i %i", SQL_GetRowCount(hndl), PlayerInventory[jatekos.index][m_iCacheCase[jatekos.index]][Cases]);
}

public void GetPlayerKeys(Handle owner, Handle hndl, const char[] error, Jatekos jatekos)
{
	PlayerInventory[jatekos.index][m_iCacheCase[jatekos.index]][Keys] = SQL_GetRowCount(hndl);
	//PrintToChat(jatekos.index, "%i %i", SQL_GetRowCount(hndl), PlayerInventory[jatekos.index][m_iCacheCase[jatekos.index]][Keys]);
}

public void CasesReset()
{
	for (int i = 1; i < m_iCases; ++i)
	{
		m_iItems[i] = 0;
	}

	m_iCases = 1;
}

public void SQLHibaKereso(Handle owner, Handle hndl, const char[] error, any data) {
	if (!StrEqual(error, ""))
		LogError(error);
}

stock int GetCaseIdFromUnique(char[] unique)
{
	for (int i = 0; i < m_iCases; ++i)
	{
		if(StrEqual(g_eCase[i][Unique_ID], unique))
			return g_eCase[i][CaseID];
	}

	return -1;
}