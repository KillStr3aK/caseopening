#include <sourcemod>
#include <nexd>

#define PLUGIN_NEV	"Caseopening system"
#define PLUGIN_LERIAS	"(8_8)"
#define PLUGIN_AUTHOR	"Nexd"
#define PLUGIN_VERSION	"1.0.1010"
#define PLUGIN_URL	"https://github.com/KillStr3aK"

#define MAX_CASES 10
#define MAX_ITEMS 16
#pragma tabsize 0

enum Case {
	String:CaseName[32],
	String:Unique_ID[32],
	bool:bReqKey,
	CaseID
}

enum Item {
	String:Name[32],
	String:Unique[32],
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
int m_iSzam[MAXPLAYERS+1] = 0;
int m_iOpenedItem[MAXPLAYERS+1] = -1;

float m_fChance[MAXPLAYERS+1] = -1.0;

bool m_bOpening[MAXPLAYERS+1] = false;

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
	if(!IsOpening(Jatekos(client))) CaseMenu(Jatekos(client));
	else PrintToChat(client, "\x04You can't access the menu while opening a case.");
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
	m_iSzam[client] = 0;
	m_iOpenedItem[client] = -1;
	m_fChance[client] = -1.0;
	m_bOpening[client] = false;

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
			CaseDetailsMenu(Jatekos(client), m_iCacheCase[client]);
			for (int i = 0; i < m_iItems[GetCaseIdFromUnique(cUID)]; ++i)
			{
				if(g_eItem[m_iCacheCase[client]][i][ParentCase] != GetCaseIdFromUnique(cUID)) continue;
				PrintToChat(client, "\x04%i \x07%s \x10%s \x5%s \x0E%s \x0C%f \x0B%i \x09%i \x03%s", g_eItem[m_iCacheCase[client]][i][ParentCase], g_eItem[m_iCacheCase[client]][i][Name], g_eItem[m_iCacheCase[client]][i][Type], g_eItem[m_iCacheCase[client]][i][Value], g_eItem[m_iCacheCase[client]][i][Grade], g_eItem[m_iCacheCase[client]][i][Chance], PlayerInventory[client][m_iCacheCase[client]][Cases], PlayerInventory[client][m_iCacheCase[client]][Keys], g_eCase[m_iCacheCase[client]][bReqKey]?"yes":"no");
			}
		} else {
			PrintToChat(client, "-1");
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
			PrintToChat(jatekos.index, "Something happend, Please contact the server owner or the plugin author. \x04ERRCODE: fOpenCase(%i-%i-%i)", m_iOpenedItem[jatekos.index], m_iCacheCase[jatekos.index], m_iPlayerID[jatekos.index]);
			return Plugin_Stop;
		}
	}

	char cPlayerName[MAX_NAME_LENGTH+1];
	jatekos.GetName(cPlayerName, sizeof(cPlayerName));

	int randomszam = GetRandomInt(0, m_iItems[m_iCacheCase[jatekos.index]]);

	if (m_iSzam[jatekos.index] >= 100 && m_fChance[jatekos.index] > -1.0)
	{
		m_iSzam[jatekos.index] = 0;
		PrintHintText(jatekos.index, "<span class='fontSize-xl'><big><u><b><font color='#00CCFF'>›› <font color='%s'>%s</font> ‹‹</font></b></u></big></span>", g_eItem[m_iCacheCase[jatekos.index]][m_iOpenedItem[jatekos.index]][Grade], g_eItem[m_iCacheCase[jatekos.index]][m_iOpenedItem[jatekos.index]][Name]);
		PrintToChat(jatekos.index, "%s \x04%s \x01has opened a case and found: %s item chance: %f player chance: %f", PREFIX, cPlayerName, g_eItem[m_iCacheCase[jatekos.index]][m_iOpenedItem[jatekos.index]][Name], g_eItem[m_iCacheCase[jatekos.index]][m_iOpenedItem[jatekos.index]][Chance], m_fChance[jatekos.index]);
		PrintToChat(jatekos.index, "highest: %f lowest: %f", GetHighestItemChance(m_iCacheCase[jatekos.index]), GetLowestItemChance(m_iCacheCase[jatekos.index]));
		
		m_fChance[jatekos.index] = -1.0;
		m_iOpenedItem[jatekos.index] = -1;
		m_bOpening[jatekos.index] = false;
		return Plugin_Stop;
	}

	if(!StrEqual(g_eItem[m_iCacheCase[jatekos.index]][randomszam][Name], empty))
		PrintHintText(jatekos.index, "<span class='fontSize-xl'><big><u><b><font color='#00CCFF'>›› <font color='%s'>%s</font> ‹‹</font></b></u></big></span>", g_eItem[m_iCacheCase[jatekos.index]][randomszam][Grade], g_eItem[m_iCacheCase[jatekos.index]][randomszam][Name]);

	m_iSzam[jatekos.index]++;			
	return Plugin_Continue;
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
	delete pack;
}

public void GetPlayerKeys(Handle owner, Handle hndl, const char[] error, DataPack pack)
{
	ResetPack(pack);
	
	PlayerInventory[view_as<Jatekos>(pack.ReadCell()).index][pack.ReadCell()][Keys] = SQL_GetRowCount(hndl);
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

stock float GetHighestItemChance(int caseid)
{
	float chance = 2.0;
	for (int i = 0; i < m_iItems[caseid]; ++i)
	{
		if(g_eItem[caseid][i][ParentCase] != caseid) continue;

		if(g_eItem[caseid][i][Chance] > chance)
			chance = g_eItem[caseid][i][Chance];
	}

	if(chance > 1.0) chance = 1.0;

	return chance;
}

stock float GetLowestItemChance(int caseid)
{
	float chance = -2.0;
	for (int i = 0; i < m_iItems[caseid]; ++i)
	{
		if(g_eItem[caseid][i][ParentCase] != caseid) continue;

		if(g_eItem[caseid][i][Chance] < chance)
			chance = g_eItem[caseid][i][Chance];
	}

	if(chance < 0.0) chance = 0.0;

	return chance;
}

stock bool IsOpening(Jatekos jatekos)
{
	return m_bOpening[jatekos.index];
}