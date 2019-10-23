public void StoreGrenadeSkinOnPluginStart()
{
	Case_RegisterModule("store.grenadeskin", false, GrenadeSkinOpened);
}

public void GrenadeSkinOpened(Jatekos jatekos, char[] grenadeskin)
{
	char authid[20];
	jatekos.GetAuthId(AuthId_Steam2, authid, sizeof(authid));
	if (StrContains(authid, "STEAM_") != -1) strcopy(authid, sizeof(authid), authid[8]);

	char Query[1024];
	Format(Query, sizeof(Query), "SELECT id FROM store_players WHERE authid = '%s'", authid);

	DataPack things = new DataPack();
	things.WriteString("grenadeskin");
	things.WriteString(grenadeskin)

	SQL_TQuery(g_DB, GiveStoreItemForSteamId, Query, things);
}