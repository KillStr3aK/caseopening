public void StoreHatsOnPluginStart()
{
	Case_RegisterModule("store.hats", false, HatsOpened);
}

public void HatsOpened(Jatekos jatekos, char[] hats)
{
	char authid[20];
	GetLegacyAuthString(jatekos.index, authid, sizeof(authid));

	char Query[1024];
	Format(Query, sizeof(Query), "SELECT id FROM store_players WHERE authid = '%s'", authid);

	DataPack things = new DataPack();
	things.WriteString("hats");
	things.WriteString(hats)

	SQL_TQuery(g_DB, GiveStoreItemForSteamId, Query, things);
}