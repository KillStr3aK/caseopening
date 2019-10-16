public void StoreGrenadeSkinOnPluginStart()
{
	Case_RegisterModule("store.grenadeskin", false, GrenadeSkinOpened);
}

public void GrenadeSkinOpened(Jatekos jatekos, char[] grenadeskin)
{
	char authid[20];
	GetLegacyAuthString(jatekos.index, authid, sizeof(authid));

	char Query[1024];
	Format(Query, sizeof(Query), "SELECT id FROM store_players WHERE authid = '%s'", authid);

	DataPack things = new DataPack();
	things.WriteString("grenadeskin");
	things.WriteString(grenadeskin)

	SQL_TQuery(g_DB, GiveStoreItemForSteamId, Query, things);
}