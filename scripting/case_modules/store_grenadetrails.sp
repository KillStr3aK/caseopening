public void StoreGrenadeTrailOnPluginStart()
{
	Case_RegisterModule("store.grenadetrail", false, GrenadeTrailOpened);
}

public void GrenadeTrailOpened(Jatekos jatekos, char[] grenadetrail)
{
	char authid[20];
	GetLegacyAuthString(jatekos.index, authid, sizeof(authid));

	char Query[1024];
	Format(Query, sizeof(Query), "SELECT id FROM store_players WHERE authid = '%s'", authid);

	DataPack things = new DataPack();
	things.WriteString("grenadetrail");
	things.WriteString(grenadetrail)

	SQL_TQuery(g_DB, GiveStoreItemForSteamId, Query, things);
}